"""블렌더(화면 없이)로 트리포 3D 모델을 찍어 게임용 그림으로 만든다.

쓰는 법: blender -b -P tools/tripo_render.py -- <out/tripo 폴더> [칸 크기 px=256]
- model.glb: 여덟 방향에서 찍은 돌려 보기 한 장(render/turn.png). 어느 쪽이 앞인지 확인용.
- anim*.glb: 동작마다 12장을 찍어 가로로 이어 붙인 그림(render/<동작>_<방향>.png).
바탕은 투명, 카메라는 원근 없는 직교 카메라로 판을 내려다보는 각도.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SOURCE = Path(ARGS[0]) if ARGS else Path("out/tripo")
CELL = int(ARGS[1]) if len(ARGS) > 1 else 256
FRAMES = 12
ELEVATION = math.radians(16.0)
## 카메라를 돌리는 각도. 90도가 정면이고, 55도는 오른쪽을 보는 비스듬한 앞모습.
FACING = 55.0


def reset() -> None:
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.samples = 24
	scene.cycles.use_denoising = False
	scene.cycles.device = "CPU"
	scene.render.film_transparent = True
	scene.render.resolution_x = CELL
	scene.render.resolution_y = CELL
	scene.render.resolution_percentage = 100
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGBA"
	scene.view_settings.view_transform = "Standard"
	world = bpy.data.worlds.new("World")
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
	world.node_tree.nodes["Background"].inputs[1].default_value = 1.15
	scene.world = world
	sun = bpy.data.lights.new("Sun", "SUN")
	sun.energy = 2.4
	sun.angle = math.radians(12)
	lamp = bpy.data.objects.new("Sun", sun)
	lamp.rotation_euler = (math.radians(50), 0, math.radians(35))
	scene.collection.objects.link(lamp)


def bounds():
	"""지금 자세에서 모델이 차지하는 상자. 뼈대로 움직인 뒤의 실제 점 위치로 잰다(8개에 1개꼴로 본다)."""
	low = Vector((1e9, 1e9, 1e9))
	high = Vector((-1e9, -1e9, -1e9))
	depsgraph = bpy.context.evaluated_depsgraph_get()
	for obj in bpy.context.scene.objects:
		if obj.type != "MESH":
			continue
		evaluated = obj.evaluated_get(depsgraph)
		mesh = evaluated.to_mesh()
		matrix = evaluated.matrix_world
		for index in range(0, len(mesh.vertices), 8):
			point = matrix @ mesh.vertices[index].co
			low = Vector((min(low.x, point.x), min(low.y, point.y), min(low.z, point.z)))
			high = Vector((max(high.x, point.x), max(high.y, point.y), max(high.z, point.z)))
		evaluated.to_mesh_clear()
	return low, high


def make_camera(low: Vector, high: Vector):
	data = bpy.data.cameras.new("Cam")
	data.type = "ORTHO"
	size = high - low
	# 동작 중에 팔·무기가 나가도 잘리지 않게 넉넉히 잡는다.
	# 키의 1.6배를 한 칸으로 잡는다: 발은 칸 위에서 80% 지점, 머리는 20% 지점에 온다(게임이 이 비율로 그린다).
	data.ortho_scale = size.z * 1.6
	camera = bpy.data.objects.new("Cam", data)
	bpy.context.scene.collection.objects.link(camera)
	bpy.context.scene.camera = camera
	pivot = bpy.data.objects.new("Pivot", None)
	pivot.location = Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, low.z + size.z * 0.5))
	bpy.context.scene.collection.objects.link(pivot)
	camera.parent = pivot
	distance = size.z * 6.0
	camera.location = (0, -distance * math.cos(ELEVATION), distance * math.sin(ELEVATION))
	camera.rotation_euler = (math.pi * 0.5 - ELEVATION, 0, 0)
	return pivot


def cloud(skinned_only: bool) -> list:
	"""지금 장면의 모델 점들을 (가운데·바닥 기준, 키를 1로 맞춰) 돌려준다. 약 1500개만 고른다."""
	points = []
	depsgraph = bpy.context.evaluated_depsgraph_get()
	for obj in bpy.context.scene.objects:
		if obj.type != "MESH" or obj.hide_render:
			continue
		if skinned_only and not any(modifier.type == "ARMATURE" for modifier in obj.modifiers):
			continue
		evaluated = obj.evaluated_get(depsgraph)
		mesh = evaluated.to_mesh()
		step = max(1, len(mesh.vertices) // 1500)
		for index in range(0, len(mesh.vertices), step):
			points.append(evaluated.matrix_world @ mesh.vertices[index].co)
		evaluated.to_mesh_clear()
	if not points:
		return []
	low_z = min(point.z for point in points)
	high_z = max(point.z for point in points)
	mid_x = (min(point.x for point in points) + max(point.x for point in points)) * 0.5
	mid_y = (min(point.y for point in points) + max(point.y for point in points)) * 0.5
	scale = 1.0 / max(high_z - low_z, 1e-6)
	return [Vector(((point.x - mid_x) * scale, (point.y - mid_y) * scale, (point.z - low_z) * scale)) for point in points]


def front_angle(rigs: list, original: list) -> float:
	"""정면에서 찍으려면 카메라를 몇 도 돌려야 하는지 돌려준다.
	뼈대를 넣으면 모델이 저마다 다른 쪽으로 돌아가 있다. 원래 모델(앞이 90도 쪽으로 정해져 있음)의 점들과
	뼈대 모델의 기본 자세 점들을 3도씩 돌려 가며 겹쳐 보고, 가장 잘 겹치는 각도만큼 돌아갔다고 본다."""
	from mathutils import kdtree
	if not original:
		return math.radians(90.0)
	for rig in rigs:
		rig.data.pose_position = "REST"
	bpy.context.view_layer.update()
	posed = cloud(True)
	for rig in rigs:
		rig.data.pose_position = "POSE"
	bpy.context.view_layer.update()
	if not posed:
		return math.radians(90.0)
	tree = kdtree.KDTree(len(original))
	for index, point in enumerate(original):
		tree.insert(point, index)
	tree.balance()
	sample = posed[::3]
	best = (1e9, 0.0)
	for degrees in range(0, 360, 3):
		turn = math.radians(degrees)
		cos_t, sin_t = math.cos(turn), math.sin(turn)
		total = 0.0
		for point in sample:
			# 뼈대 모델의 점을 -각도만큼 되돌려 원래 모델에 겹쳐 본다.
			back = Vector((point.x * cos_t + point.y * sin_t, -point.x * sin_t + point.y * cos_t, point.z))
			total += tree.find(back)[2]
		if total < best[0]:
			best = (total, turn)
	print("RENDER 앞 방향: 원래 모델보다", round(math.degrees(best[1])), "도 돌아가 있음 (어긋남 %.4f)" % (best[0] / len(sample)))
	return math.radians(90.0) + best[1]


def _boxed(pixels, mask, side: int = 48):
	"""그림에서 캐릭터가 차지한 상자만 잘라 side×side로 줄인다(가장 가까운 점 고르기)."""
	import numpy as np
	rows = np.where(mask.any(axis=1))[0]
	cols = np.where(mask.any(axis=0))[0]
	if len(rows) == 0:
		return None, None
	pick_rows = np.linspace(rows[0], rows[-1], side).astype(int)
	pick_cols = np.linspace(cols[0], cols[-1], side).astype(int)
	return pixels[pick_rows][:, pick_cols, :3], mask[pick_rows][:, pick_cols]


def best_view(pivot, folder: Path) -> float:
	"""모델을 10도씩 돌려 가며 작게 찍어 보고, 주문할 때 넣은 그림(input.png)과 가장 닮은 각도를 돌려준다.
	트리포 모델은 앞이 어느 쪽인지 저마다 달라서, 원래 그림과 같은 방향에서 찍으려면 이렇게 찾아야 한다."""
	import numpy as np
	source = folder / "input.png"
	if not source.exists():
		return math.radians(55.0)
	image = bpy.data.images.load(str(source))
	width, height = image.size
	wanted = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
	bpy.data.images.remove(image)
	target, target_mask = _boxed(wanted, wanted[:, :, :3].min(axis=2) < 0.9)
	if target is None:
		return math.radians(55.0)
	scene = bpy.context.scene
	saved = (scene.render.resolution_x, scene.render.resolution_y, scene.cycles.samples)
	scene.render.resolution_x = 96
	scene.render.resolution_y = 96
	scene.cycles.samples = 6
	best = (1e9, 55.0)
	for degrees in range(0, 360, 10):
		pivot.rotation_euler = (0, 0, math.radians(degrees))
		path = folder / "render" / "probe.png"
		shoot(path)
		shot = bpy.data.images.load(str(path))
		pixels = np.array(shot.pixels[:], dtype=np.float32).reshape(96, 96, 4)
		bpy.data.images.remove(shot)
		view, view_mask = _boxed(pixels, pixels[:, :, 3] > 0.3)
		if view is None:
			continue
		both = target_mask & view_mask
		outline = 1.0 - both.sum() / max((target_mask | view_mask).sum(), 1)
		color = float(np.abs(view[both] - target[both]).mean()) if both.any() else 1.0
		score = outline + color * 2.0
		if score < best[0]:
			best = (score, float(degrees))
	(folder / "render" / "probe.png").unlink(missing_ok=True)
	scene.render.resolution_x, scene.render.resolution_y, scene.cycles.samples = saved
	print("RENDER 원래 그림과 가장 닮은 각도:", best[1], "(점수 %.3f)" % best[0])
	return math.radians(best[1])


def calibrate(camera, folder: Path) -> None:
	"""한 장을 찍어 보고, 실제로 그려진 모습이 칸 가운데에 키 62.5%로 오도록 카메라를 옮기고 맞춘다.
	(뼈대가 든 모델은 블렌더가 알려 주는 크기가 실제와 달라서, 찍힌 그림으로 직접 잰다.)"""
	import numpy as np
	path = folder / "calibrate.png"
	shoot(path)
	image = bpy.data.images.load(str(path))
	alpha = np.array(image.pixels[:], dtype=np.float32).reshape(CELL, CELL, 4)[:, :, 3] > 0.2
	bpy.data.images.remove(image)
	path.unlink()
	rows = np.where(alpha.any(axis=1))[0]
	cols = np.where(alpha.any(axis=0))[0]
	if len(rows) == 0:
		return
	unit = camera.data.ortho_scale / CELL
	# 블렌더 그림의 줄은 아래에서 위로 센다.
	shift_x = ((cols[0] + cols[-1]) * 0.5 - CELL * 0.5) * unit
	shift_y = ((rows[0] + rows[-1]) * 0.5 - CELL * 0.5) * unit
	camera.location = camera.location + camera.matrix_basis.to_3x3() @ Vector((shift_x, shift_y, 0.0))
	camera.data.ortho_scale = (rows[-1] - rows[0] + 1) * unit / 0.625
	print("RENDER 맞춤: 키", round((rows[-1] - rows[0] + 1) * unit, 3), "옮김", round(shift_x, 3), round(shift_y, 3))


def shoot(path: Path) -> None:
	bpy.context.scene.render.filepath = str(path)
	bpy.ops.render.render(write_still=True)


def join(paths: list, target: Path) -> None:
	"""찍은 그림들을 가로로 이어 붙인다(블렌더 안의 그림 기능만 쓴다)."""
	import numpy as np
	sheet = np.zeros((CELL, CELL * len(paths), 4), dtype=np.float32)
	for index, path in enumerate(paths):
		image = bpy.data.images.load(str(path))
		pixels = np.array(image.pixels[:], dtype=np.float32).reshape(CELL, CELL, 4)
		sheet[:, index * CELL:(index + 1) * CELL, :] = pixels
		bpy.data.images.remove(image)
	out = bpy.data.images.new("sheet", CELL * len(paths), CELL, alpha=True)
	out.pixels = sheet.ravel()
	out.filepath_raw = str(target)
	out.file_format = "PNG"
	out.save()
	bpy.data.images.remove(out)
	for path in paths:
		path.unlink()


def render_folder(folder: Path) -> None:
	out = folder / "render"
	out.mkdir(exist_ok=True)
	model = folder / "model.glb"
	original = []
	view_angle = math.radians(55.0)
	if model.exists():
		reset()
		bpy.ops.import_scene.gltf(filepath=str(model))
		original = cloud(False)
		low, high = bounds()
		print("RENDER", folder.name, "모델 크기", [round(v, 3) for v in (high - low)])
		pivot = make_camera(low, high)
		view_angle = best_view(pivot, folder)
		shots = []
		for step in range(8):
			pivot.rotation_euler = (0, 0, math.radians(step * 45))
			path = out / ("turn_%d.png" % step)
			shoot(path)
			shots.append(path)
		join(shots, out / "turn.png")
	for anim in sorted(folder.glob("anim*.glb")):
		reset()
		bpy.ops.import_scene.gltf(filepath=str(anim))
		scene = bpy.context.scene
		rigs = [obj for obj in scene.objects if obj.type == "ARMATURE"]
		actions = list(bpy.data.actions)
		print("RENDER", folder.name, anim.name, "뼈대", len(rigs), "동작", [(a.name, tuple(a.frame_range)) for a in actions])
		idle = [action for action in actions if action.name.lower().startswith("idle")] or actions
		for rig in rigs:
			if rig.animation_data is None:
				rig.animation_data_create()
			rig.animation_data.action = idle[0]
		scene.frame_set(int(idle[0].frame_range[0]))
		low, high = bounds()
		print("RENDER", folder.name, "동작 모델 크기", [round(v, 3) for v in (high - low)])
		pivot = make_camera(low, high)
		# 정면에서 35도 돌린 방향으로 놓고, 가만히 선 자세로 카메라를 맞춘다. 한 번은 대충, 한 번은 정확히.
		pivot.rotation_euler = (0, 0, view_angle + front_angle(rigs, original) - math.radians(90.0))
		scene.camera.data.ortho_scale *= 1.5
		calibrate(scene.camera, out)
		calibrate(scene.camera, out)
		for action in actions:
			for rig in rigs:
				if rig.animation_data is None:
					rig.animation_data_create()
				for track in rig.animation_data.nla_tracks:
					track.mute = True
				rig.animation_data.action = action
			start, end = action.frame_range
			label = "".join(ch if ch.isalnum() else "_" for ch in action.name.lower())[:24]
			kind = action.name.split("_")[0].lower()
			# 정면에서 35도 돌린 비스듬한 앞모습 한 방향만 찍는다(반대 방향은 게임이 뒤집어 그린다).
			shots = []
			for index in range(FRAMES):
				scene.frame_set(int(round(start + (end - start) * index / FRAMES)))
				path = out / ("%s_%02d.png" % (label, index))
				shoot(path)
				shots.append(path)
			join(shots, out / ("%s_%s.png" % (folder.name, kind)))

for item in sorted(SOURCE.iterdir()):
	if item.is_dir():
		try:
			render_folder(item)
		except Exception as error:  # 한 모델이 실패해도 나머지는 찍는다.
			print("RENDER 실패", item.name, error)

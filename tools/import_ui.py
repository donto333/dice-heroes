"""Codex가 자홍색 바탕에 그린 UI 부품(버튼·판·리본·아이콘)을 게임용 PNG로 넣는다.

쓰는 법: python3 tools/import_ui.py <Codex 결과 폴더(out)/ui>
- 이름 앞머리로 종류를 나눈다: btn_/sq_/round_ 버튼, win_/card_ 틀, ribbon_ 리본, ic_ 아이콘, 그 밖은 낱개 부품.
- win_·card_·slot_ 틀은 안쪽 단색을 투명하게 뚫어 '테두리만' 남긴다(안쪽 색은 게임이 원하는 색으로 칠한다).
- 틀마다 몸통 바깥으로 튀어나온 장식 길이(outset)와 테 두께(border)를 재서 assets/ui_kit/meta.json에 적는다.
- ic_ 아이콘은 assets/ui_icons/에 'ic_'를 뗀 이름으로 넣는다.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_standees  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
KIT = ROOT / "assets" / "ui_kit"
ICONS = ROOT / "assets" / "ui_icons"
## 종류별 저장 크기(긴 변 또는 높이, px)
SIZES = {"btn": ("h", 150), "sq": ("h", 170), "round": ("h", 170), "win": ("w", 640), "card": ("h", 150),
	"ribbon": ("h", 130), "ic": ("h", 176), "slot": ("h", 170)}
OTHER = ("h", 150)


def cut_full(path: Path) -> Image.Image:
	"""자홍 바탕을 지우고 그림에 꼭 맞게 자른다(크기는 그대로)."""
	import_standees.HEIGHT = 100000
	image = Image.open(path)
	saved = import_standees.HEIGHT
	# cut()은 HEIGHT로 줄이므로 원본 높이를 넣어 크기를 유지한다.
	import_standees.HEIGHT = image.size[1]
	result = import_standees.cut(path)
	import_standees.HEIGHT = saved
	return result


def fit(image: Image.Image, rule) -> Image.Image:
	axis, pixels = rule
	scale = pixels / (image.size[1] if axis == "h" else image.size[0])
	return image.resize((max(1, round(image.size[0] * scale)), max(1, round(image.size[1] * scale))), Image.LANCZOS)


def hollow(image: Image.Image):
	"""가운데에서 이어진 단색 안쪽을 투명하게 뚫는다. (뚫은 그림, 안쪽 상자)를 돌려준다."""
	data = np.asarray(image).astype(np.float32)
	rgb = data[..., :3]
	h, w = data.shape[:2]
	patch = rgb[h // 2 - 6:h // 2 + 6, w // 2 - 6:w // 2 + 6].reshape(-1, 3)
	base = np.median(patch, axis=0)
	dist = np.sqrt(((rgb - base) ** 2).sum(axis=2))
	labels, _ = ndimage.label(dist < 46.0)
	inside = labels == labels[h // 2, w // 2]
	inside = ndimage.binary_fill_holes(inside)
	soft = ndimage.gaussian_filter(inside.astype(np.float32), 1.2)
	data[..., 3] = data[..., 3] * (1.0 - np.clip((soft - 0.25) / 0.6, 0.0, 1.0))
	rows = np.where(inside.any(axis=1))[0]
	cols = np.where(inside.any(axis=0))[0]
	box = [int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1]
	return Image.fromarray(data.astype(np.uint8), "RGBA"), box


def body_box(image: Image.Image, box):
	"""장식을 뺀 틀 몸통의 바깥 상자: 안쪽 상자에서 바깥으로 가며 불투명한 줄이 70% 넘게 이어지는 곳까지."""
	alpha = np.asarray(image.getchannel("A")) > 40
	h, w = alpha.shape
	x0, y0, x1, y1 = box
	span_x = slice(x0 + (x1 - x0) // 5, x1 - (x1 - x0) // 5)
	span_y = slice(y0 + (y1 - y0) // 5, y1 - (y1 - y0) // 5)
	# 가운데 장식을 피하려고 양옆 1/4 지점의 줄만 본다.
	left_cols = slice(x0 + (x1 - x0) // 8, x0 + (x1 - x0) // 4)
	top = y0
	while top > 0 and alpha[top - 1, left_cols].mean() > 0.7:
		top -= 1
	bottom = y1
	while bottom < h and alpha[bottom, left_cols].mean() > 0.7:
		bottom += 1
	left = x0
	while left > 0 and alpha[span_y, left - 1].mean() > 0.7:
		left -= 1
	right = x1
	while right < w and alpha[span_y, right].mean() > 0.7:
		right += 1
	del span_x
	return [left, top, right, bottom]


def main():
	source = Path(sys.argv[1])
	KIT.mkdir(parents=True, exist_ok=True)
	meta_path = KIT / "meta.json"
	meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
	count = 0
	for path in sorted(source.glob("*.png")):
		name = path.stem
		kind = name.split("_")[0]
		if kind not in SIZES and not name.startswith(("close", "back", "tab", "toggle", "inset", "capsule", "nameplate",
				"rail", "portrait", "bubble", "bar", "badge")):
			continue
		image = cut_full(path)
		if kind == "ic":
			fit(image, SIZES["ic"]).save(ICONS / (name[3:] + ".png"), optimize=True)
			count += 1
			continue
		image = fit(image, SIZES.get(kind, OTHER))
		entry = {"w": image.size[0], "h": image.size[1]}
		if kind in ("win", "card", "slot") or name in ("rail_plate", "portrait_ring", "bar_frame", "inset_dark", "capsule_dark", "bubble"):
			keep = name in ("inset_dark", "capsule_dark", "bubble")
			hollowed, inner = hollow(image)
			outer = body_box(hollowed, inner)
			if not keep:
				image = hollowed
			entry["inner"] = inner
			entry["outer"] = outer
		image.save(KIT / (name + ".png"), optimize=True)
		meta[name] = entry
		count += 1
	meta_path.write_text(json.dumps(meta, indent="\t", sort_keys=True))
	print("넣은 UI 부품:", count)


if __name__ == "__main__":
	main()

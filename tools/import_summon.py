"""소환 연출 그림 넣기: Codex가 그린 codex_work/out/summon 그림을 assets/ui_summon으로 줄여 넣는다.

쓰는 법: python tools/import_summon.py <out/summon 폴더>

- bg_*.png: 바탕 그림. 1280×720으로 맞춰 jpg로 저장한다.
- 그 밖(die_*, card_back_*, card_front_*, badge_new): 자홍 바탕을 지우고 물체만 잘라 줄인다.
- card_front_*: 가운데 그림 창(자홍으로 비워 둔 자리)의 위치를 재서 meta.json에 적는다(틀 크기에 대한 비율 [왼쪽, 위, 오른쪽, 아래]).
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui_summon"
# 이름 앞머리 → 긴 변 크기
SIZES = {"die_": 420, "card_back_": 512, "card_front_": 512, "badge_": 256}


def cut_magenta(image: Image.Image) -> Image.Image:
	"""자홍(#FF00FF)에 가까울수록 투명하게 하고, 가장자리에 남은 자홍 물을 뺀다."""
	pixels = np.asarray(image.convert("RGB")).astype(np.float32)
	red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
	# 자홍다움: 빨강·파랑은 크고 초록은 작다.
	keyness = np.clip((np.minimum(red, blue) - green) / 255.0, 0.0, 1.0)
	alpha = np.clip(1.0 - (keyness - 0.25) / 0.35, 0.0, 1.0)
	# 남은 자홍 물 빼기: 빨강·파랑을 초록 쪽으로 누른다.
	spill = np.clip(np.minimum(red, blue) - green, 0.0, None) * (alpha < 1.0)
	red = red - spill
	blue = blue - spill
	result = np.dstack([red, green, blue, alpha * 255.0]).clip(0, 255).astype(np.uint8)
	return Image.fromarray(result, "RGBA")


def crop_to_body(image: Image.Image) -> Image.Image:
	alpha = np.asarray(image)[..., 3]
	rows = np.where(alpha.max(axis=1) > 40)[0]
	columns = np.where(alpha.max(axis=0) > 40)[0]
	return image.crop((int(columns[0]), int(rows[0]), int(columns[-1]) + 1, int(rows[-1]) + 1))


def window_of(image: Image.Image) -> list:
	"""카드 틀 가운데의 투명한 창. 창 가운데쯤에서 네 방향으로 투명한 데까지 넓혀 잰다."""
	alpha = np.asarray(image)[..., 3]
	tall, wide = alpha.shape
	center_x, center_y = wide // 2, int(tall * 0.4)
	clear_row = alpha[center_y] < 128
	clear_column = alpha[:, center_x] < 128
	left = center_x
	while left > 0 and clear_row[left - 1]:
		left -= 1
	right = center_x
	while right < wide - 1 and clear_row[right + 1]:
		right += 1
	top = center_y
	while top > 0 and clear_column[top - 1]:
		top -= 1
	bottom = center_y
	while bottom < tall - 1 and clear_column[bottom + 1]:
		bottom += 1
	# 초상화가 틀 밑으로 조금 들어가게 2픽셀씩 넓힌다.
	return [round(max(0, left - 2) / wide, 4), round(max(0, top - 2) / tall, 4), round(min(wide, right + 3) / wide, 4), round(min(tall, bottom + 3) / tall, 4)]


def main() -> None:
	source = Path(sys.argv[1])
	OUT.mkdir(parents=True, exist_ok=True)
	meta = {}
	for path in sorted(source.glob("*.png")):
		name = path.stem
		image = Image.open(path)
		if name.startswith("bg_"):
			# 16:9로 가운데를 잘라 1280×720.
			wide, tall = image.size
			target = 16.0 / 9.0
			if wide / tall > target:
				new_wide = int(tall * target)
				image = image.crop(((wide - new_wide) // 2, 0, (wide - new_wide) // 2 + new_wide, tall))
			else:
				new_tall = int(wide / target)
				image = image.crop((0, (tall - new_tall) // 2, wide, (tall - new_tall) // 2 + new_tall))
			image.convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / f"{name}.jpg", quality=88)
			print(name, "바탕", image.size)
			continue
		limit = next((size for head, size in SIZES.items() if name.startswith(head)), 384)
		body = crop_to_body(cut_magenta(image))
		scale = limit / max(body.size)
		body = body.resize((max(1, round(body.size[0] * scale)), max(1, round(body.size[1] * scale))), Image.LANCZOS)
		if name.startswith("card_front_"):
			meta[name] = window_of(body)
		body.save(OUT / f"{name}.png", optimize=True)
		print(name, body.size, meta.get(name, ""))
	(OUT / "meta.json").write_text(json.dumps(meta, indent="\t", sort_keys=True) + "\n")


if __name__ == "__main__":
	main()

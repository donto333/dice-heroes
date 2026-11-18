"""주사위 꾸미기 그림 넣기: Codex가 그린 codex_work/out/dice 그림을 assets/dice/<스킨>_<눈>.png로 넣는다.

쓰는 법: python tools/import_dice.py <out/dice 폴더>

받는 그림(둘 중 하나):
- <스킨 id>.png : 주사위 6개를 3칸×2줄로 고르게 놓은 한 장. 왼쪽 위부터 눈 1·2·3, 아랫줄 4·5·6.
- <스킨 id>_<눈>.png : 주사위 하나씩 따로 그린 그림.
바탕은 자홍(#FF00FF) 또는 초록(#00FF00) 단색. 왼쪽 위 귀퉁이 색으로 어느 쪽인지 알아낸다.
주사위만 잘라 기존 흰·금 주사위와 같은 180×200 크기로 맞춘다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "dice"
SIZE = (180, 200)


def cut_background(image: Image.Image) -> Image.Image:
	"""자홍이나 초록 바탕을 투명하게 하고 가장자리에 남은 바탕색 물을 뺀다."""
	pixels = np.asarray(image.convert("RGB")).astype(np.float32)
	red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
	corner = pixels[:8, :8].reshape(-1, 3).mean(axis=0)
	if corner[1] > corner[0] and corner[1] > corner[2]:
		# 초록 바탕: 초록이 빨강·파랑보다 클수록 바탕.
		keyness = np.clip((green - np.maximum(red, blue)) / 255.0, 0.0, 1.0)
		alpha = np.clip(1.0 - (keyness - 0.25) / 0.35, 0.0, 1.0)
		spill = np.clip(green - np.maximum(red, blue), 0.0, None) * (alpha < 1.0)
		green = green - spill
	else:
		# 자홍 바탕: 빨강·파랑은 크고 초록은 작을수록 바탕.
		keyness = np.clip((np.minimum(red, blue) - green) / 255.0, 0.0, 1.0)
		alpha = np.clip(1.0 - (keyness - 0.25) / 0.35, 0.0, 1.0)
		spill = np.clip(np.minimum(red, blue) - green, 0.0, None) * (alpha < 1.0)
		red = red - spill
		blue = blue - spill
	result = np.dstack([red, green, blue, alpha * 255.0]).clip(0, 255).astype(np.uint8)
	return Image.fromarray(result, "RGBA")


def crop_to_body(image: Image.Image) -> Image.Image:
	alpha = np.asarray(image)[..., 3]
	rows = np.where(alpha.max(axis=1) > 40)[0]
	columns = np.where(alpha.max(axis=0) > 40)[0]
	if rows.size == 0 or columns.size == 0:
		raise ValueError("주사위를 찾지 못했어요")
	return image.crop((int(columns[0]), int(rows[0]), int(columns[-1]) + 1, int(rows[-1]) + 1))


def save_die(image: Image.Image, skin: str, value: int) -> None:
	body = crop_to_body(image).resize(SIZE, Image.LANCZOS)
	path = OUT / ("%s_%d.png" % (skin, value))
	body.save(path, optimize=True)
	print("넣음:", path.name)


def main() -> None:
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	source = Path(sys.argv[1])
	done: set = set()
	for path in sorted(source.glob("*.png")):
		stem = path.stem
		parts = stem.rsplit("_", 1)
		if len(parts) == 2 and parts[1].isdigit():
			skin, value = parts[0], int(parts[1])
			save_die(cut_background(Image.open(path)), skin, value)
			done.add(skin)
			continue
		if stem in done:
			continue
		# 3칸×2줄 한 장: 칸마다 나눠 자른다.
		sheet = cut_background(Image.open(path))
		width, height = sheet.size
		for index in range(6):
			column, row = index % 3, index // 3
			cell = sheet.crop((column * width // 3, row * height // 2, (column + 1) * width // 3, (row + 1) * height // 2))
			save_die(cell, stem, index + 1)


if __name__ == "__main__":
	main()

"""어빌리티 아이콘 넣기: ChatGPT가 그린 4칸×3줄 아이콘 판(자홍 바탕)을 잘라 assets/ability_icons/<어빌리티 id>.png로 넣는다.

쓰는 법: python tools/import_ability_icons.py <판 폴더>

- 판 이름은 sheet1.png ~ sheet4.png. 판마다 data/abilities.json 순서대로 12개씩(sheet1 = 1~12번째 ...).
- 메달 12개를 덩어리로 찾아(칸 격자가 고르지 않아도 됨) 위 줄부터 왼쪽→오른쪽 순서로 번호를 매긴다.
- 자홍을 지우고 메달만 잘라 256×256으로 맞춘다.
"""
import json
import sys
from pathlib import Path

import numpy as np
from scipy import ndimage
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ability_icons"
SIZE = 256


def cut_magenta(image: Image.Image) -> Image.Image:
	pixels = np.asarray(image.convert("RGB")).astype(np.float32)
	red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
	keyness = np.clip((np.minimum(red, blue) - green) / 255.0, 0.0, 1.0)
	alpha = np.clip(1.0 - (keyness - 0.25) / 0.35, 0.0, 1.0)
	spill = np.clip(np.minimum(red, blue) - green, 0.0, None) * (alpha < 1.0)
	result = np.dstack([red - spill, green, blue - spill, alpha * 255.0]).clip(0, 255).astype(np.uint8)
	return Image.fromarray(result, "RGBA")


def crop_square(image: Image.Image) -> Image.Image:
	alpha = np.asarray(image)[..., 3]
	rows = np.where(alpha.max(axis=1) > 128)[0]
	columns = np.where(alpha.max(axis=0) > 128)[0]
	left, top, right, bottom = int(columns[0]), int(rows[0]), int(columns[-1]) + 1, int(rows[-1]) + 1
	side = max(right - left, bottom - top)
	cx, cy = (left + right) / 2.0, (top + bottom) / 2.0
	box = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))
	square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
	square.paste(image.crop(box), (0, 0))
	return square


def main() -> None:
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	source = Path(sys.argv[1])
	ids = list(json.loads((ROOT / "data" / "abilities.json").read_text(encoding="utf-8"))["abilities"].keys())
	OUT.mkdir(parents=True, exist_ok=True)
	for sheet_index in range(4):
		path = source / ("sheet%d.png" % (sheet_index + 1))
		if not path.exists():
			continue
		sheet = cut_magenta(Image.open(path))
		alpha = np.asarray(sheet)[..., 3] > 128
		labels, count = ndimage.label(ndimage.binary_closing(alpha, iterations=3))
		boxes = ndimage.find_objects(labels)
		sizes = ndimage.sum(alpha, labels, range(1, count + 1))
		biggest = sorted(range(count), key=lambda i: -sizes[i])[:12]
		medals = [boxes[i] for i in biggest]
		# 줄 나누기: 세로 가운데로 정렬한 뒤 메달 높이의 절반보다 크게 벌어지면 다음 줄.
		medals.sort(key=lambda b: (b[0].start + b[0].stop) / 2)
		rows: list = []
		for box in medals:
			centre = (box[0].start + box[0].stop) / 2
			if rows and abs(centre - rows[-1][0]) < (box[0].stop - box[0].start) / 2:
				rows[-1][1].append(box)
			else:
				rows.append([centre, [box]])
		ordered = []
		for _, row in rows:
			ordered += sorted(row, key=lambda b: b[1].start)
		for cell, box in enumerate(ordered):
			number = sheet_index * 12 + cell
			if number >= len(ids):
				break
			part = sheet.crop((box[1].start, box[0].start, box[1].stop, box[0].stop))
			icon = crop_square(part).resize((SIZE, SIZE), Image.LANCZOS)
			icon.save(OUT / (ids[number] + ".png"), optimize=True)
			print("넣음:", ids[number])


if __name__ == "__main__":
	main()

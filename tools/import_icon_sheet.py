"""아이콘 판 넣기: 자홍 바탕에 메달 여러 개를 그린 판 한 장을 잘라 아이콘 파일로 넣는다.

쓰는 법: python tools/import_icon_sheet.py <판.png> <넣을 폴더> <이름1,이름2,...> [크기=256]
- 메달을 덩어리로 찾아(격자가 고르지 않아도 됨) 위 줄부터 왼쪽→오른쪽 순서로 이름을 붙인다.
- 자홍을 지우고 메달만 정사각형으로 잘라 <크기>로 맞춘다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent


def cut_magenta(image: Image.Image) -> Image.Image:
	pixels = np.asarray(image.convert("RGB")).astype(np.float32)
	red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
	keyness = np.clip((np.minimum(red, blue) - green) / 255.0, 0.0, 1.0)
	alpha = np.clip(1.0 - (keyness - 0.25) / 0.35, 0.0, 1.0)
	spill = np.clip(np.minimum(red, blue) - green, 0.0, None) * (alpha < 1.0)
	return Image.fromarray(np.dstack([red - spill, green, blue - spill, alpha * 255.0]).clip(0, 255).astype(np.uint8), "RGBA")


def crop_square(image: Image.Image) -> Image.Image:
	alpha = np.asarray(image)[..., 3]
	rows = np.where(alpha.max(axis=1) > 128)[0]
	cols = np.where(alpha.max(axis=0) > 128)[0]
	left, top, right, bottom = int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1
	side = max(right - left, bottom - top)
	square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
	square.paste(image.crop((left, top, right, bottom)), ((side - (right - left)) // 2, (side - (bottom - top)) // 2))
	return square


def ordered_blobs(sheet: Image.Image, count: int) -> list:
	alpha = np.asarray(sheet)[..., 3] > 128
	labels, found = ndimage.label(alpha)
	boxes = ndimage.find_objects(labels)
	sizes = ndimage.sum(alpha, labels, range(1, found + 1))
	medals = [boxes[i] for i in sorted(range(found), key=lambda i: -sizes[i])[:count]]
	medals.sort(key=lambda b: (b[0].start + b[0].stop) / 2)
	rows: list = []
	for box in medals:
		centre = (box[0].start + box[0].stop) / 2
		if rows and abs(centre - rows[-1][0]) < (box[0].stop - box[0].start) / 2:
			rows[-1][1].append(box)
		else:
			rows.append([centre, [box]])
	result = []
	for _, row in rows:
		result += sorted(row, key=lambda b: b[1].start)
	return result


def main() -> None:
	if len(sys.argv) < 4:
		print(__doc__)
		sys.exit(1)
	sheet = cut_magenta(Image.open(sys.argv[1]))
	out = ROOT / sys.argv[2]
	out.mkdir(parents=True, exist_ok=True)
	names = sys.argv[3].split(",")
	size = int(sys.argv[4]) if len(sys.argv) > 4 else 256
	for name, box in zip(names, ordered_blobs(sheet, len(names))):
		part = sheet.crop((box[1].start, box[0].start, box[1].stop, box[0].stop))
		crop_square(part).resize((size, size), Image.LANCZOS).save(out / (name + ".png"), optimize=True)
		print("넣음:", name)


if __name__ == "__main__":
	main()

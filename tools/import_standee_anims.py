"""트리포 모형 동작 그림(블렌더 결과 render/<id>_<동작>.png, 6칸×2줄)을 게임용으로 넣는다.

쓰는 법: python tools/import_standee_anims.py <tripo-out 폴더들...>
- 칸마다 발(가장 아래 불투명 점)을 같은 높이(칸의 81.25%)에 맞춘다. 걸을 때 땅으로 꺼지거나 뜨지 않게.
- 256색으로 줄여 assets/standees_anim/<id>_<동작>.png로 저장한다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
FOOT = 0.8125
COLUMNS = 6


def _foot(alpha) -> int:
	"""발 높이: 불투명 점이 칸 너비의 1.5% 넘게 모인 가장 아래 줄(늘어진 끈·꼬리 끝 같은 가는 것은 무시)."""
	counts = alpha.sum(axis=1)
	rows = np.where(counts >= max(3, alpha.shape[1] * 0.015))[0]
	if len(rows) == 0:
		rows = np.where(counts > 0)[0]
	return int(rows[-1]) if len(rows) else -1


def ground(sheet: Image.Image) -> Image.Image:
	"""칸마다 발을 땅선에 맞춘다. 전체는 중간값을 땅선에 두고, 칸마다 걸음에 따른 오르내림은 칸 1.5%까지만 남긴다."""
	cell = sheet.width // COLUMNS
	rows = sheet.height // cell
	boxes = []
	feet = []
	for row in range(rows):
		for column in range(COLUMNS):
			box = (column * cell, row * cell, (column + 1) * cell, (row + 1) * cell)
			boxes.append(box)
			feet.append(_foot(np.array(sheet.crop(box))[:, :, 3] > 40))
	valid = [f for f in feet if f >= 0]
	base = float(np.median(valid)) if valid else cell * FOOT
	limit = cell * 0.015
	line = int(round(cell * FOOT))
	out = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
	for box, foot in zip(boxes, feet):
		if foot < 0:
			continue
		frame = sheet.crop(box)
		bob = max(-limit, min(limit, foot - base))
		shift = int(round(line + bob - foot))
		moved = Image.new("RGBA", frame.size, (0, 0, 0, 0))
		moved.paste(frame, (0, shift), frame)
		out.paste(moved, box[:2])
	return out


def main() -> None:
	target = ROOT / "assets" / "standees_anim"
	count = 0
	for folder in sys.argv[1:]:
		for path in sorted(Path(folder).rglob("render/*_*.png")):
			name, kind = path.stem.rsplit("_", 1)
			if kind not in ("idle", "walk") or name.startswith(("turn", "probe")):
				continue
			sheet = ground(Image.open(path).convert("RGBA"))
			sheet.quantize(256, method=Image.Quantize.FASTOCTREE).save(target / f"{name}_{kind}.png", optimize=True)
			count += 1
			print("넣음", name, kind)
	print("모두", count, "장")


if __name__ == "__main__":
	main()

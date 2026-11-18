"""영상(클링 등)으로 만든 영웅 동작을 판 위 말 그림으로 넣는다.

쓰는 법: python tools/import_video_standee.py <영상.mp4> <영웅 id> <동작> <처음 장면> <끝 장면> [키 비율]
예: python tools/import_video_standee.py kling.mp4 gumiho walk 1 36
- 영상을 장면별로 뜯고, 인공지능 배경 지우기(rembg, isnet-anime)로 인물만 남긴다.
  (pip install "rembg[cpu]" 필요. 단색 바탕 영상이면 더 깨끗하다.)
- 장면 범위 안에서 고르게 12장을 골라 6칸×2줄(칸 384) 그림으로 만든다.
- 떨림 방지: 크기·가운데·발 높이를 장면마다 따로 재지 않고, 범위 전체에 걸쳐 부드럽게 이은 값(2차 곡선)으로 맞춘다.
- 키 비율(기본 0.66)은 칸 높이에 대한 인물 전체(꼬리 포함) 높이. 발은 칸의 81.25% 땅선에 둔다.
- 결과는 256색으로 줄여 assets/standees_anim/<id>_<동작>.png로 저장한다.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CELL = 384
COLUMNS = 6
FRAMES = 12
FOOT = 0.8125


def _cut(video: str, first: int, last: int) -> list:
	from rembg import new_session, remove
	work = Path(tempfile.mkdtemp())
	subprocess.run(["ffmpeg", "-v", "error", "-i", video, str(work / "%03d.png")], check=True)
	picks = np.linspace(first, last, FRAMES).round().astype(int)
	session = new_session("isnet-anime")
	frames = []
	for number in picks:
		image = remove(Image.open(work / ("%03d.png" % number)), session=session).convert("RGBA")
		alpha = np.array(image)[:, :, 3]
		alpha[alpha < 30] = 0
		image.putalpha(Image.fromarray(alpha))
		frames.append(image)
	return frames


def _smooth(values) -> np.ndarray:
	x = np.arange(len(values))
	return np.polyval(np.polyfit(x, values, 2), x)


def build(frames: list, height_ratio: float) -> Image.Image:
	boxes = []
	for image in frames:
		ys, xs = np.nonzero(np.array(image)[:, :, 3] > 128)
		boxes.append((xs.min(), ys.min(), xs.max(), ys.max()))
	heights = _smooth([b[3] - b[1] for b in boxes])
	bottoms = _smooth([b[3] for b in boxes])
	centers = _smooth([(b[0] + b[2]) / 2 for b in boxes])
	target = CELL * height_ratio
	# 가장 넓은 장면도 칸 안에 들어가게 줄인다.
	shrink = min(1.0, min((CELL / 2 - 4) / max(1.0, max(c - b[0], b[2] - c) * target / h) for b, c, h in zip(boxes, centers, heights)))
	sheet = Image.new("RGBA", (CELL * COLUMNS, CELL * (FRAMES // COLUMNS)), (0, 0, 0, 0))
	for index, image in enumerate(frames):
		scale = target / heights[index] * shrink
		big = image.resize((max(1, int(image.width * scale)), max(1, int(image.height * scale))), Image.LANCZOS)
		cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
		cell.paste(big, (int(round(CELL / 2 - centers[index] * scale)), int(round(CELL * FOOT - bottoms[index] * scale))), big)
		sheet.paste(cell, ((index % COLUMNS) * CELL, (index // COLUMNS) * CELL))
	return sheet


def main() -> None:
	if len(sys.argv) < 6:
		print(__doc__)
		sys.exit(1)
	video, hero, kind, first, last = sys.argv[1:6]
	ratio = float(sys.argv[6]) if len(sys.argv) > 6 else 0.66
	sheet = build(_cut(video, int(first), int(last)), ratio)
	out = ROOT / "assets" / "standees_anim" / ("%s_%s.png" % (hero, kind))
	sheet.quantize(256, method=Image.Quantize.FASTOCTREE).save(out, optimize=True)
	print("넣음:", out.name)


if __name__ == "__main__":
	main()

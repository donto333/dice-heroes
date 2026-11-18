"""★★★ 스킬 장면 그림 넣기: Codex가 그린 자홍 바탕 그림을 assets/cutins/<영웅 id>.png로 넣는다.

쓰는 법: python tools/import_cutins.py <그림 폴더>
- 파일 이름은 <영웅 id>.png (예: lubu.png). 바탕(자홍 #FF00FF, 분홍 옷이면 초록 #00FF00 — 귀퉁이 색으로 저절로 고름)을 지우고 사람만 잘라 긴 변 512로 맞춘다.
- 아래쪽은 띠에 잘려 들어가므로 정사각형으로 맞출 때 아래를 기준으로 붙인다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "cutins"
SIDE = 512


def cut_magenta(image: Image.Image) -> Image.Image:
	pixels = np.asarray(image.convert("RGB")).astype(np.float32)
	red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
	keyness = np.clip((np.minimum(red, blue) - green) / 255.0, 0.0, 1.0)
	alpha = np.clip(1.0 - (keyness - 0.25) / 0.35, 0.0, 1.0)
	spill = np.clip(np.minimum(red, blue) - green, 0.0, None) * (alpha < 1.0)
	return Image.fromarray(np.dstack([red - spill, green, blue - spill, alpha * 255.0]).clip(0, 255).astype(np.uint8), "RGBA")


def cut_green(image: Image.Image) -> Image.Image:
	pixels = np.asarray(image.convert("RGB")).astype(np.float32)
	red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
	keyness = np.clip((green - np.maximum(red, blue)) / 255.0, 0.0, 1.0)
	alpha = np.clip(1.0 - (keyness - 0.25) / 0.35, 0.0, 1.0)
	spill = np.clip(green - np.maximum(red, blue), 0.0, None) * (alpha < 1.0)
	return Image.fromarray(np.dstack([red, green - spill, blue, alpha * 255.0]).clip(0, 255).astype(np.uint8), "RGBA")


def cut_background(image: Image.Image) -> Image.Image:
	"""귀퉁이 색이 초록이면 초록 바탕, 아니면 자홍 바탕으로 지운다."""
	red, green, blue = image.convert("RGB").getpixel((2, 2))
	if green > 180 and red < 120 and blue < 120:
		return cut_green(image)
	return cut_magenta(image)


def main() -> None:
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	OUT.mkdir(parents=True, exist_ok=True)
	for path in sorted(Path(sys.argv[1]).glob("*.png")):
		art = cut_background(Image.open(path))
		alpha = np.asarray(art)[..., 3]
		rows = np.where(alpha.max(axis=1) > 40)[0]
		cols = np.where(alpha.max(axis=0) > 40)[0]
		art = art.crop((int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1))
		side = max(art.size)
		square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
		square.paste(art, ((side - art.size[0]) // 2, side - art.size[1]))
		square.resize((SIDE, SIDE), Image.LANCZOS).save(OUT / path.name, optimize=True)
		print("넣음:", path.name)


if __name__ == "__main__":
	main()

"""UI 부품 판 넣기(2026-11-19, A 스타일 다시 그리기): 자홍 바탕에 부품 여러 개를 그린 판 한 장을 잘라 넣는다.

쓰는 법: python tools/import_ui_sheet.py <판.png> <넣을 폴더> <이름1:크기,이름2:크기,...>
- 부품을 덩어리로 찾아 위 줄부터 왼쪽→오른쪽 순서로 이름을 붙인다.
- 크기 적는 법
  - `h128`: 높이를 128로 맞추고 비율은 그대로(PillSkin처럼 높이에 맞춰 그리는 부품).
  - `178x64@1.1/0.5`: 왼쪽 끝 1.1·오른쪽 끝 0.5(짧은 변에 대한 비율)를 그대로 둔다(없으면 0.6).
  - `178x64`: 정확히 이 크기로. 짧은 쪽에 맞춰 줄인 뒤, 남는 쪽은 양 끝 장식을 그대로 두고 가운데만 늘리거나 줄인다
    (NinePatch처럼 그림 픽셀 여백으로 그리는 부품은 예전 그림과 같은 크기여야 코드의 여백 값이 맞는다).
- 이름 앞에 `-`를 붙이면 그 덩어리는 건너뛴다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_icon_sheet import ordered_blobs  # noqa: E402
from scipy import ndimage  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent


def cut_magenta(image: Image.Image) -> Image.Image:
	"""바깥과 이어진 자홍만 지운다(보라 버튼처럼 자홍에 가까운 색이 부품 안에 있어도 남는다)."""
	pixels = np.asarray(image.convert("RGB")).astype(np.float32)
	red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
	core = (red > 190) & (blue > 190) & (green < 110)
	labels, _ = ndimage.label(core)
	edge_ids = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
	background = np.isin(labels, list(edge_ids))
	band = ndimage.binary_dilation(background, iterations=3) & ~background
	keyness = np.clip((np.minimum(red, blue) - green) / 255.0, 0.0, 1.0)
	alpha = np.ones_like(red)
	alpha[background] = 0.0
	soft = np.clip(1.0 - (keyness - 0.25) / 0.35, 0.0, 1.0)
	alpha[band] = soft[band]
	spill = np.clip(np.minimum(red, blue) - green, 0.0, None) * ((alpha < 1.0) & band)
	return Image.fromarray(np.dstack([red - spill, green, blue - spill, alpha * 255.0]).clip(0, 255).astype(np.uint8), "RGBA")


def trim(image: Image.Image) -> Image.Image:
	alpha = np.asarray(image)[..., 3]
	rows = np.where(alpha.max(axis=1) > 40)[0]
	cols = np.where(alpha.max(axis=0) > 40)[0]
	return image.crop((int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1))


def stretch_axis(image: Image.Image, target: int, axis: int, cap: float, cap_end: float = -1.0) -> Image.Image:
	"""한 방향(axis 0=가로, 1=세로)으로 양 끝(짧은 변에 대한 비율 cap·cap_end)은 그대로 두고 가운데만 늘리거나 줄인다."""
	width, height = image.size
	length = width if axis == 0 else height
	other = height if axis == 0 else width
	if cap_end < 0.0:
		cap_end = cap
	if length == target:
		return image
	end = int(round(min(other * cap, length * 0.6, target * 0.6)))
	end2 = int(round(min(other * cap_end, length - end - 1, target - end - 1)))
	middle = max(target - end - end2, 1)
	out = Image.new("RGBA", (target, height) if axis == 0 else (width, target), (0, 0, 0, 0))
	if axis == 0:
		out.paste(image.crop((0, 0, end, height)), (0, 0))
		out.paste(image.crop((end, 0, width - end2, height)).resize((middle, height), Image.LANCZOS), (end, 0))
		out.paste(image.crop((width - end2, 0, width, height)), (end + middle, 0))
	else:
		out.paste(image.crop((0, 0, width, end)), (0, 0))
		out.paste(image.crop((0, end, width, height - end2)).resize((width, middle), Image.LANCZOS), (0, end))
		out.paste(image.crop((0, height - end2, width, height)), (0, end + middle))
	return out


def fit(image: Image.Image, spec: str) -> Image.Image:
	if spec.startswith("h"):
		target_h = int(spec[1:])
		scale = target_h / image.height
		return image.resize((max(1, round(image.width * scale)), target_h), Image.LANCZOS)
	caps = (0.6, 0.6)
	if "@" in spec:
		spec, cap_text = spec.split("@")
		caps = tuple(float(v) for v in cap_text.split("/"))
	target_w, target_h = (int(v) for v in spec.split("x"))
	# 짧은 쪽(비율이 덜 줄어드는 쪽)에 맞춰 같은 비율로 줄인 뒤 다른 쪽을 가운데만 늘림
	ratio_w = target_w / image.width
	ratio_h = target_h / image.height
	if image.width >= image.height:
		scale = ratio_h
		resized = image.resize((max(1, round(image.width * scale)), target_h), Image.LANCZOS)
		return stretch_axis(resized, target_w, 0, caps[0], caps[-1])
	scale = ratio_w
	resized = image.resize((target_w, max(1, round(image.height * scale))), Image.LANCZOS)
	return stretch_axis(resized, target_h, 1, 0.6)


def main() -> None:
	if len(sys.argv) < 4:
		print(__doc__)
		sys.exit(1)
	sheet = cut_magenta(Image.open(sys.argv[1]))
	out = ROOT / sys.argv[2]
	out.mkdir(parents=True, exist_ok=True)
	entries = [item.split(":") for item in sys.argv[3].split(",")]
	for (name, spec), box in zip(entries, ordered_blobs(sheet, len(entries))):
		if name.startswith("-"):
			continue
		part = trim(sheet.crop((box[1].start, box[0].start, box[1].stop, box[0].stop)))
		result = fit(part, spec)
		result.save(out / (name + ".png"), optimize=True)
		print("넣음:", name, part.size, "→", result.size)


if __name__ == "__main__":
	main()

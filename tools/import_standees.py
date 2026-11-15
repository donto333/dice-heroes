"""Codex가 자홍색(#FF00FF) 바탕에 그린 캐릭터 입체 모형에서 바탕을 지우고 게임용 PNG로 넣는다.

쓰는 법: python3 tools/import_standees.py <Codex 결과 폴더(out)/standees> [저장할 폴더 이름=standees]
- 가장자리에서 이어진 자홍색만 바탕으로 본다(옷의 보라·분홍은 지워지지 않는다).
- 경계는 부드럽게 다듬고 자홍 물을 뺀 뒤, 그림에 꼭 맞게 잘라 높이 320px PNG로 저장한다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
HEIGHT = 320


def cut(path: Path) -> Image.Image:
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    magenta = np.clip(np.minimum(r, b) - g, 0.0, 1.0)
    # 바탕 후보: 자홍이 뚜렷한 점. 그중 그림 가장자리와 이어진 덩어리만 진짜 바탕이다.
    candidate = magenta > 0.45
    labels, _ = ndimage.label(candidate)
    border = np.unique(np.concatenate([labels[0, :], labels[-1, :], labels[:, 0], labels[:, -1]]))
    background = np.isin(labels, border[border > 0])
    # 팔과 몸 사이처럼 갇힌 바탕: 아주 순수한 자홍(바탕색 그대로)인 덩어리도 지운다.
    pure = (r > 0.85) & (b > 0.85) & (g < 0.25)
    pure_labels, count = ndimage.label(pure)
    if count > 0:
        sizes = ndimage.sum(pure, pure_labels, index=np.arange(1, count + 1))
        for index, size in enumerate(sizes, start=1):
            if size >= 60:
                background |= ndimage.binary_dilation(pure_labels == index, iterations=2) & candidate
    alpha = np.where(background, 0.0, 1.0).astype(np.float32)
    # 경계 2픽셀: 자홍 정도에 따라 반투명하게, 자홍 물 빼기
    near = ndimage.binary_dilation(background, iterations=2) & ~background
    alpha = np.where(near, np.clip(1.0 - (magenta - 0.1) / 0.4, 0.0, 1.0), alpha)
    alpha = ndimage.gaussian_filter(alpha, 0.6) * (~background)
    spill = np.where(near | (ndimage.binary_dilation(background, iterations=4) & ~background), magenta, 0.0)
    out = np.dstack([np.clip(r - spill, 0, 1), g, np.clip(b - spill, 0, 1), alpha])
    image = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
    box = image.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    if box:
        image = image.crop(box)
    width = max(1, round(image.size[0] * HEIGHT / image.size[1]))
    return image.resize((width, HEIGHT), Image.LANCZOS)


def main():
    source = Path(sys.argv[1])
    out_dir = ROOT / "assets" / (sys.argv[2] if len(sys.argv) > 2 else "standees")
    out_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    for path in sorted(source.glob("*.png")):
        cut(path).save(out_dir / path.name, optimize=True)
        count += 1
    print("넣은 모형:", count)


if __name__ == "__main__":
    main()

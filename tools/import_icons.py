"""Codex가 자홍색(#FF00FF) 바탕에 그린 아이콘에서 바탕을 지우고 게임용 PNG로 넣는다.

쓰는 법: python3 tools/import_icons.py <Codex 결과 폴더(out)/icons>
- 자홍색에 가까운 점은 투명하게, 가장자리의 자홍 물은 빼고(디스필), 그림에 꼭 맞게 잘라
  정사각 160px PNG로 assets/ui_icons/<이름>.png에 저장한다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui_icons"
SIZE = 160


def cut(path: Path) -> Image.Image:
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # 자홍 정도: 빨강·파랑이 둘 다 초록보다 얼마나 큰가(0~1). 바탕은 1에 가깝다.
    magenta = np.clip(np.minimum(r, b) - g, 0.0, 1.0)
    alpha = np.clip(1.0 - (magenta - 0.25) / 0.45, 0.0, 1.0)
    # 가장자리에 남은 자홍 물 빼기: 빨강·파랑을 초록 쪽으로 끌어내린다.
    spill = np.clip(np.minimum(r, b) - g, 0.0, 1.0)
    edge = alpha < 0.999
    r2 = np.where(edge, r - spill, r - spill * 0.6)
    b2 = np.where(edge, b - spill, b - spill * 0.6)
    out = np.dstack([np.clip(r2, 0, 1), g, np.clip(b2, 0, 1), alpha])
    image = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
    box = image.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    if box:
        image = image.crop(box)
    side = max(image.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(image, ((side - image.size[0]) // 2, (side - image.size[1]) // 2))
    return square.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    source = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    count = 0
    for path in sorted(source.glob("*.png")):
        cut(path).save(OUT / path.name, optimize=True)
        count += 1
    print("넣은 아이콘:", count)


if __name__ == "__main__":
    main()

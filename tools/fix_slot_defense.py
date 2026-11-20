#!/usr/bin/env python3
"""공격 자리의 빨간 띠를 파랗게 바꿔 방어 자리의 비어 있는 띠 안에 넣는다."""

from colorsys import hsv_to_rgb, rgb_to_hsv
from pathlib import Path

from PIL import Image


def main() -> None:
    art_dir = Path(__file__).resolve().parents[1] / "assets" / "ui_menu"
    attack = Image.open(art_dir / "slot_attack.png").convert("RGBA")
    defense_path = art_dir / "slot_defense.png"
    defense = Image.open(defense_path).convert("RGBA")
    if attack.size != defense.size:
        raise ValueError("공격·방어 자리 그림의 크기가 다릅니다.")

    # 원본(257×320)의 위 띠 안에서만 채운다. 방어 틀의 금테와 보석 픽셀은 그대로 둔다.
    for y in range(7, 62):
        for x in range(18, 239):
            if defense.getpixel((x, y))[3] >= 128:
                continue
            red, green, blue, alpha = attack.getpixel((x, y))
            if alpha < 128:
                continue
            hue, saturation, value = rgb_to_hsv(red / 255, green / 255, blue / 255)
            if 0.09 <= hue <= 0.93:
                continue
            color = hsv_to_rgb(0.605, 0.84 * saturation, value)
            defense.putpixel((x, y), (*[round(channel * 255) for channel in color], 255))
    defense.save(defense_path)


if __name__ == "__main__":
    main()

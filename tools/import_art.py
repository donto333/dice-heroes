"""Codex가 그린 큰 PNG를 게임용 JPG로 줄여 넣는다.

쓰는 법: python3 tools/import_art.py <Codex 결과 폴더(out)>
- out/ui/*.png       → assets/art/ui/*.jpg      (세로 그림 720px 폭, 정사각 512px, 가로 768px 폭)
- out/chapters/*.png → assets/art/chapters/*.jpg (768px 폭)
- out/cards/*.png    → assets/art/cards/*.jpg   (320px)
- out/enemies/*.png  → assets/enemies/*.jpg     (256px)
원본 PNG는 저장소에 넣지 않는다(게임 용량을 줄이려고).
"""
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TARGETS = {
    "ui": (ROOT / "assets" / "art" / "ui", None),
    "chapters": (ROOT / "assets" / "art" / "chapters", 768),
    "cards": (ROOT / "assets" / "art" / "cards", 320),
    "enemies": (ROOT / "assets" / "enemies", 256),
    "relics": (ROOT / "assets" / "art" / "relics", 256),
}


def target_width(image: Image.Image, fixed):
    if fixed:
        return fixed
    w, h = image.size
    if h > w * 1.1:
        return 720  # 세로 그림(타이틀·로딩·로비·소환·화면 바탕)
    if w > h * 1.1:
        return 768  # 가로 그림(전투 바탕·랭크전)
    return 512


def main():
    source = Path(sys.argv[1])
    count = 0
    for folder, (out_dir, fixed) in TARGETS.items():
        for path in sorted((source / folder).glob("*.png")):
            image = Image.open(path).convert("RGB")
            width = target_width(image, fixed)
            height = round(image.size[1] * width / image.size[0])
            out_dir.mkdir(parents=True, exist_ok=True)
            image.resize((width, height), Image.LANCZOS).save(out_dir / (path.stem + ".jpg"), quality=86, optimize=True)
            count += 1
    print("넣은 그림:", count)


if __name__ == "__main__":
    main()

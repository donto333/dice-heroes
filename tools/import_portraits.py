"""ChatGPT로 만든 2x2 캐릭터 일러스트 묶음을 잘라 게임용 초상화로 만든다.

쓰는 법: python3 tools/import_portraits.py 묶음그림.jpg 왼위id 오른위id 왼아래id 오른아래id
- 칸 사이 경계선을 피해 네 칸으로 자르고 256x256으로 줄인다.
- 결과: assets/portraits/<id>.jpg
"""
import sys
from pathlib import Path
from PIL import Image

SIZE = 256
OUT = Path(__file__).resolve().parent.parent / "assets" / "portraits"


def main():
    path, ids = sys.argv[1], sys.argv[2:6]
    image = Image.open(path).convert("RGB")
    w, h = image.size
    half_w, half_h = w // 2, h // 2
    m = 6  # 칸 사이 경계선 피하기
    boxes = [
        (m, m, half_w - m, half_h - m),
        (half_w + m, m, w - m, half_h - m),
        (m, half_h + m, half_w - m, h - m),
        (half_w + m, half_h + m, w - m, h - m),
    ]
    OUT.mkdir(parents=True, exist_ok=True)
    for cid, box in zip(ids, boxes):
        if cid == "-":
            continue
        cell = image.crop(box).resize((SIZE, SIZE), Image.LANCZOS)
        cell.save(OUT / f"{cid}.jpg", quality=88)
        print("저장:", OUT / f"{cid}.jpg")


if __name__ == "__main__":
    main()

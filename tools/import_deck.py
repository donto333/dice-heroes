"""Codex가 그린 카드 편성 부품(주문서 codex_work/job_deck.md)을 게임용 그림으로 넣는다.

쓰는 법: python3 tools/import_deck.py <Codex 결과 폴더(out/deck)>
- 자홍 바탕(#FF00FF)을 지우고 그림에 꼭 맞게 자른 뒤 줄여 assets/ui_menu/deck_<이름>.png로 넣는다.
- 빈 카드 자리 slot_empty_1~3, 덱 줄 판 row_frame_1~3, 보유 카드 판 owned_frame.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_ui  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui_menu"
## 저장 크기: (기준 축, px). 화면에 보이는 크기의 약 2배.
SIZES = {
	"slot_empty_1": ("h", 224), "slot_empty_2": ("h", 224), "slot_empty_3": ("h", 224),
	"row_frame_1": ("h", 150), "row_frame_2": ("h", 150), "row_frame_3": ("h", 150),
	"owned_frame": ("w", 300),
}


def main() -> None:
	source = Path(sys.argv[1])
	for path in sorted(source.glob("*.png")):
		rule = SIZES.get(path.stem)
		if rule is None:
			continue
		image = import_ui.fit(import_ui.cut_full(path), rule)
		image.save(OUT / f"deck_{path.stem}.png", optimize=True)
		print(f"deck_{path.stem}.png", image.size)


if __name__ == "__main__":
	main()

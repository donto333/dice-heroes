"""Codex가 그린 새 로비 부품(주문서 job16)을 게임용 그림으로 넣는다.

쓰는 법: python3 tools/import_lobby.py <Codex 결과 폴더(out/lobby)>
- 자홍 바탕(#FF00FF)을 지우고 그림에 꼭 맞게 자른 뒤 크기를 줄여 assets/ui_lobby/에 PNG로 넣는다.
- 바탕 그림(lobby_sky.jpg)은 1920×1080 JPG로 줄인다.
- ic_ 아이콘은 assets/ui_lobby/에 그대로 둔다(로비 전용, 이름 앞 ic_ 유지).
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_ui  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui_lobby"
## 저장 크기: (기준 축, px). 화면에서 보이는 크기의 약 2배(선명하게).
SIZES = {
	"tile_rank": ("w", 760), "tile_adventure": ("w", 460), "tile_white": ("w", 420), "tile_navy": ("w", 320),
	"plate_profile": ("h", 120), "plate_currency": ("h", 96), "btn_plus": ("h", 96), "btn_sys": ("h", 120),
	"strip_event": ("h", 80), "dock_bottom": ("h", 160), "bar_task": ("h", 96),
}
ICON_SIZE = ("h", 192)


def main() -> None:
	source = Path(sys.argv[1])
	OUT.mkdir(parents=True, exist_ok=True)
	for path in sorted(source.iterdir()):
		stem = path.stem
		if stem == "lobby_sky":
			image = Image.open(path).convert("RGB").resize((1920, 1080), Image.LANCZOS)
			image.save(OUT / "lobby_sky.jpg", quality=86)
			print("lobby_sky.jpg", image.size)
			continue
		if path.suffix.lower() != ".png":
			continue
		rule = SIZES.get(stem, ICON_SIZE if stem.startswith("ic_") else ("h", 150))
		image = import_ui.fit(import_ui.cut_full(path), rule)
		image.save(OUT / f"{stem}.png", optimize=True)
		print(f"{stem}.png", image.size)


if __name__ == "__main__":
	main()

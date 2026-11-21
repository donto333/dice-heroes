"""게임 기본 글꼴에서 대전 시안의 좁고 굵은 글자 모양을 만든다."""
from pathlib import Path

from fontTools.misc.roundTools import otRound
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

FONT_DIR = Path(__file__).resolve().parents[1] / "assets/fonts"


def build_hud_font():
    font = TTFont(FONT_DIR / "DiceHeroes-Black.ttf", recalcTimestamp=False)
    glyphs = font.getGlyphSet()
    outlines = {}
    korean = {name for code, name in font.getBestCmap().items() if 0xAC00 <= code <= 0xD7A3}
    for name in font.getGlyphOrder():
        # 한글은 내부 여백을 살리고, 영문 역할명과 숫자는 조금 더 좁힌다.
        width = 0.94 if name in korean else 0.90
        pen = TTGlyphPen(None)
        drawing = DecomposingRecordingPen(glyphs)
        glyphs[name].draw(drawing)
        drawing.replay(TransformPen(pen, (width, 0, 0, 1, 0, 0)))
        outlines[name] = pen.glyph()
        advance, bearing = font["hmtx"][name]
        font["hmtx"][name] = (otRound(advance * width), otRound(bearing * width))
    for name, outline in outlines.items():
        font["glyf"][name] = outline
    family = "Dice Heroes Citadel"
    names = font["name"]
    for key, value in {1: family, 2: "Black", 3: "DiceHeroesCitadel-Black-1",
                       4: family + " Black", 6: "DiceHeroesCitadel-Black",
                       16: family, 17: "Black"}.items():
        names.removeNames(nameID=key)
        names.setName(value, key, 3, 1, 0x409)
    font["OS/2"].usWidthClass = 4
    font["OS/2"].recalcAvgCharWidth(font)
    font.save(FONT_DIR / "DiceHeroes-Citadel.ttf")


if __name__ == "__main__":
    build_hud_font()

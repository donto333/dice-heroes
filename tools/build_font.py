"""게임 전용 글꼴(DiceHeroes-Black.ttf)을 만든다.

게임 글에 실제로 쓰는 글자만 골라 담아서 파일을 작게 만든다.
바탕 글꼴은 노토 산스 Black(가장 굵은 굵기, SIL OFL 라이선스)이다.
- 영어·베트남어 등 라틴 글자: 노토 산스(Noto Sans) Black
- 한글과 그 밖의 기호: 노토 산스 KR(Noto Sans KR) Black
- 나중에 일본어·중국어 번역이 들어오면 SOURCES에 JP·SC를 더하면 된다.

바탕 글꼴 받기(npm이 있으면 됨):
    python tools/build_font.py --fetch
글꼴 만들기:
    python tools/build_font.py
번역 글이 바뀌면 다시 돌리기만 하면 빠진 글자가 들어간다.
"""
import glob
import io
import json
import os
import subprocess
import sys
import tarfile

from fontTools import subset
from fontTools.merge import Merger
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, ".font_src")  # 저장소에는 안 올림(.gitignore)
OUT = os.path.join(ROOT, "assets", "fonts", "DiceHeroes-Black.ttf")
CHARS_OUT = os.path.join(ROOT, "assets", "fonts", "DiceHeroes-Black.chars.txt")
WEIGHT = "900"

# 앞에 있는 글꼴이 먼저다. 같은 글자가 여러 글꼴에 있으면 앞의 것을 쓴다.
SOURCES = [
    ("@fontsource/noto-sans", ["latin", "latin-ext", "vietnamese"]),
    ("@fontsource/noto-sans-kr", None),  # None = 모든 조각
]

# 번역 전이라도 늘 담아 두는 글자: 영어·베트남어 전체와 자주 쓰는 기호.
VIETNAMESE = (
    "ÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÝàáâãèéêìíòóôõùúýĂăĐđĨĩŨũƠơƯư"
    "ẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪừỬửỮữỰựỲỳỴỵỶỷỸỹ"
)
ALWAYS = (
    "".join(chr(c) for c in range(0x20, 0x7F))
    + "".join(chr(c) for c in range(0xA0, 0x100))
    + VIETNAMESE
    + "·×÷…→←↑↓↔●○■□◆◇★☆♥✓✔「」『』【】〈〉《》、。！？（）：；～‘’“”•–—"
)

# 게임 글이 들어 있는 파일들. 번역 파일(data/i18n/)이 생기면 함께 읽는다.
TEXT_GLOBS = ["scripts/**/*.gd", "data/**/*.json", "data/**/*.csv", "scenes/**/*.tscn"]


def fetch() -> None:
    """npm에서 노토 글꼴 조각(woff2)을 받아 .font_src에 푼다."""
    os.makedirs(SRC_DIR, exist_ok=True)
    for package, _ in SOURCES:
        tgz = subprocess.check_output(["npm", "pack", "-s", package], cwd=SRC_DIR, text=True).strip().splitlines()[-1]
        name = package.split("/")[-1]
        with tarfile.open(os.path.join(SRC_DIR, tgz)) as tar:
            for member in tar.getmembers():
                if member.name.endswith(f"-{WEIGHT}-normal.woff2"):
                    data = tar.extractfile(member).read()
                    os.makedirs(os.path.join(SRC_DIR, name), exist_ok=True)
                    with open(os.path.join(SRC_DIR, name, os.path.basename(member.name)), "wb") as f:
                        f.write(data)
        os.remove(os.path.join(SRC_DIR, tgz))
    print("바탕 글꼴 받음:", SRC_DIR)


def used_chars() -> set:
    chars = set(ALWAYS)
    for pattern in TEXT_GLOBS:
        for path in glob.glob(os.path.join(ROOT, pattern), recursive=True):
            with open(path, encoding="utf-8") as f:
                chars.update(ch for ch in f.read() if ord(ch) > 0x1F)
    chars.discard("﻿")
    return chars


def source_files() -> list:
    files = []
    for package, parts in SOURCES:
        name = package.split("/")[-1]
        found = sorted(glob.glob(os.path.join(SRC_DIR, name, f"*-{WEIGHT}-normal.woff2")))
        if parts is not None:
            found = [p for p in found if any(os.path.basename(p) == f"{name}-{part}-{WEIGHT}-normal.woff2" for part in parts)]
        if not found:
            sys.exit(f"바탕 글꼴이 없다: {name}. 먼저 --fetch로 받는다.")
        files.extend(found)
    return files


def build() -> None:
    wanted = used_chars()
    left = set(wanted)
    pieces = []
    for path in source_files():
        font = TTFont(path)
        cmap = font.getBestCmap()
        take = {ch for ch in left if ord(ch) in cmap}
        if not take:
            continue
        options = subset.Options()
        # 조각마다 표 구성이 달라 합칠 수 없는 표(세로쓰기·글자 짝 간격 등)는 뺀다.
        options.layout_features = []
        options.drop_tables += ["vhea", "vmtx", "BASE", "STAT", "GDEF", "GPOS", "GSUB", "prep", "gasp", "DSIG"]
        options.notdef_outline = True
        options.name_IDs = ["*"]
        options.hinting = False
        options.flavor = None
        sub = subset.Subsetter(options)
        sub.populate(unicodes=[ord(c) for c in take])
        sub.subset(font)
        buf = io.BytesIO()
        font.flavor = None
        font.save(buf)
        buf.seek(0)
        pieces.append(buf)
        left -= take

    merged = Merger().merge(pieces)
    # 이름 정보
    names = merged["name"]
    for record in list(names.names):
        if record.nameID in (1, 3, 4, 6, 16, 17):
            names.removeNames(nameID=record.nameID)
    names.setName("DiceHeroes", 1, 3, 1, 0x409)
    names.setName("DiceHeroes Black", 4, 3, 1, 0x409)
    names.setName("DiceHeroes-Black", 6, 3, 1, 0x409)
    names.setName("DiceHeroes-Black-" + str(len(wanted)), 3, 3, 1, 0x409)
    merged.save(OUT)

    missing = sorted(ch for ch in left if ch.isprintable() and not ch.isspace())
    with open(CHARS_OUT, "w", encoding="utf-8") as f:
        f.write("".join(sorted(wanted - left)))
    size = os.path.getsize(OUT) // 1024
    print(f"글꼴 만듦: {OUT} ({len(wanted) - len(left)}자, {size}KB)")
    if missing:
        print("바탕 글꼴에도 없는 글자(노토 산스 KR 보조 글꼴로 메워짐):", "".join(missing))


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    else:
        build()

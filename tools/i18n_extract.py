"""번역할 한국어 글을 모아 번역 파일(data/i18n/<언어>.json)에 채울 자리를 만든다.

- 화면 코드(scripts/)의 따옴표 글과 data/의 json 글 중 한글이 든 것을 모은다.
- 이미 번역한 글은 그대로 두고, 새 글은 빈 번역("")으로 더한다. 빈 번역은 한국어로 보인다.
- 코드에서 더는 쓰지 않는 글은 "_unused"로 옮기지 않고 그냥 남겨 둔다(지워도 된다).
- 빠진 개수를 언어마다 알려 준다.

    python tools/i18n_extract.py            # 번역 파일 갱신
    python tools/i18n_extract.py --missing en > missing.txt   # 번역이 빈 글만 뽑기
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ["en", "vi"]
HANGUL = re.compile("[가-힣]")
# 화면에 안 나오는 글(개발용 기록·음성 대사 원문)은 뺀다. 음성 대사는 소리가 한국어라 자막 번역은 나중에.
SKIP_DATA = {"voice_lines.json", "voice_extra.json", "voice_i18n.json"}
SKIP_KEYS = {"_comment", "comment", "note_dev", "voice_name", "voice", "tags"}
SKIP_CALL = re.compile(r"\b(push_error|push_warning|print|printerr|prints|assert)\s*\(")
STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def _unescape(text: str) -> str:
    return text.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8") if "\\" in text else text


def _strip_comment(line: str) -> str:
    """따옴표 밖의 # 뒤(주석)를 지운다."""
    inside = False
    escaped = False
    for i, ch in enumerate(line):
        if escaped:
            escaped = False
        elif ch == "\\":
            escaped = True
        elif ch == '"':
            inside = not inside
        elif ch == "#" and not inside:
            return line[:i]
    return line


def from_scripts() -> list:
    found = []
    for path in sorted(glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True)):
        for line in open(path, encoding="utf-8"):
            code = _strip_comment(line)
            if SKIP_CALL.search(code):
                continue
            for match in STRING.finditer(code):
                raw = match.group(1)
                if HANGUL.search(raw):
                    try:
                        found.append(_unescape(raw))
                    except UnicodeDecodeError:
                        found.append(raw)
    return found


def from_data() -> list:
    found = []

    def walk(node, key=None):
        if isinstance(node, dict):
            for k, v in node.items():
                if k not in SKIP_KEYS:
                    walk(v, k)
        elif isinstance(node, list):
            for v in node:
                walk(v, key)
        elif isinstance(node, str) and HANGUL.search(node):
            found.append(node)

    for path in sorted(glob.glob(os.path.join(ROOT, "data", "**", "*.json"), recursive=True)):
        if os.path.basename(path) in SKIP_DATA or os.sep + "i18n" + os.sep in path:
            continue
        walk(json.load(open(path, encoding="utf-8")))
    # 음성 파일 중 화면에 나오는 것: 안내 음성 이름(설정).
    extra = json.load(open(os.path.join(ROOT, "data", "voice_extra.json"), encoding="utf-8"))
    found.extend(str(item.get("label", "")) for item in extra.get("announcers", []) if item.get("label"))
    # 로비 말풍선에 나오는 영웅 대기 대사(번역은 data/voice_i18n.json에서 채운다).
    lines = json.load(open(os.path.join(ROOT, "data", "voice_lines.json"), encoding="utf-8"))
    found.extend(str(hero["lines"].get("idle", "")) for hero in lines.get("heroes", {}).values())
    return found


def collect() -> list:
    seen = {}
    for text in from_scripts() + from_data():
        for part in text.split("\n"):
            part = part.strip()
            if part and HANGUL.search(part):
                seen.setdefault(part, True)
    return list(seen)


def main() -> None:
    sources = collect()
    os.makedirs(os.path.join(ROOT, "data", "i18n"), exist_ok=True)
    if "--missing" in sys.argv:
        lang = sys.argv[sys.argv.index("--missing") + 1]
        table = json.load(open(os.path.join(ROOT, "data", "i18n", f"{lang}.json"), encoding="utf-8"))
        for text in sources:
            if not table.get(text):
                print(text)
        return
    for lang in LANGS:
        path = os.path.join(ROOT, "data", "i18n", f"{lang}.json")
        table = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
        for text in sources:
            table.setdefault(text, "")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(table, f, ensure_ascii=False, indent=1)
            f.write("\n")
        empty = sum(1 for text in sources if not table.get(text))
        print(f"{lang}: 글 {len(sources)}개 중 번역 없음 {empty}개")


if __name__ == "__main__":
    main()

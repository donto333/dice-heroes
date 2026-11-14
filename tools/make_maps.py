"""120칸 안팎의 큰 맵 3종을 만든다. (초원의 길 · 사막의 길 · 설원의 성채)

실행: python3 tools/make_maps.py  →  data/board.json, data/boards/desert.json, data/boards/frost.json

배치 규칙 (가로 10칸, 줄마다 방향이 바뀌는 지그재그):
- 보통 줄(P): 10칸.
- 갈림길 묶음(F): 두 줄을 쓴다. 갈림길 칸 하나에서 A길(8칸, 짧고 위험)과 B길(9칸, 길고 안전)로 나뉘었다가
  거점 칸 하나에서 다시 만난다. 모두 19칸.
- 줄 순서: P P F P P F P F P  →  60 + 57 = 117칸, 출발에서 골까지 가장 짧은 길은 약 90칸.
칸 내용은 맵마다 정한 비율로 고르되, 같은 맵은 언제 만들어도 똑같이 나오도록 씨앗(seed)을 고정한다.
"""
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAIN_LENGTH = 93   # 갈림길 길을 뺀 큰길 칸 수 (출발~골 가장 짧은 길)
LANE_LENGTH = 8    # 갈림길 한 갈래의 칸 수
FORKS = 3


# ---------------------------------------------------------------- 경로 모양
# 각 모양 함수는 큰길 좌표 목록(한 칸씩 이어진)을 돌려준다. 칸은 가로·세로·대각선으로 이웃해야 한다.

def _walk(points, direction, steps):
    x, y = points[-1]
    dx, dy = direction
    for _ in range(steps):
        x += dx
        y += dy
        points.append((x, y))


def shape_uturn():
    """유턴형: 긴 가로줄을 달리다 끝에서 세로로 3칸 내려와 반대로 달린다."""
    points = [(0, 0)]
    direction = 1
    while len(points) < MAIN_LENGTH:
        _walk(points, (direction, 0), 24)
        _walk(points, (0, 1), 4)
        direction *= -1
    return points[:MAIN_LENGTH]


def shape_pyramid():
    """피라미드형: 아래 넓은 줄에서 시작해 위로 갈수록 줄이 짧아지고, 줄 사이는 대각선 계단."""
    points = [(0, 0)]
    width = 32
    direction = 1
    while len(points) < MAIN_LENGTH:
        _walk(points, (direction, 0), width - 1)
        # 다음 줄은 양쪽이 3칸씩 좁다. 대각선으로 3칸 올라가며 안쪽으로 들어간다.
        _walk(points, (-direction, -1), 4)
        width -= 8
        direction *= -1
        if width < 4:
            break
    points = points[:MAIN_LENGTH]
    return points


def shape_spiral():
    """나선형: 바깥 둘레에서 안쪽으로 감아 들어가 한가운데가 골."""
    points = [(0, 0)]
    sides = [(1, 0), (0, 1), (-1, 0), (0, -1)]
    lengths = [16, 16, 16, 13, 13, 10, 10, 7, 7, 4]
    for index, length in enumerate(lengths):
        if len(points) >= MAIN_LENGTH:
            break
        _walk(points, sides[index % 4], length)
    return points[:MAIN_LENGTH]


def shape_straight():
    """직선형: 오른쪽으로 쭉 가면서 완만하게 위아래로 물결친다."""
    points = [(0, 0)]
    up = True
    while len(points) < MAIN_LENGTH:
        _walk(points, (1, 0), 14)
        _walk(points, (1, -1 if up else 1), 3)
        up = not up
    return points[:MAIN_LENGTH]


def shape_stairs():
    """계단형: 오른쪽으로 11칸 가고 아래로 3칸 내려가기를 되풀이하는 큰 계단."""
    points = [(0, 0)]
    while len(points) < MAIN_LENGTH:
        _walk(points, (1, 0), 11)
        _walk(points, (0, 1), 3)
    return points[:MAIN_LENGTH]


def shape_mountain():
    """산맥형: 평지를 달리다 대각선으로 봉우리를 오르고 내려온다. 봉우리 높이가 조금씩 다르다."""
    points = [(0, 0)]
    peaks = [5, 7, 4, 6, 5, 7]
    index = 0
    while len(points) < MAIN_LENGTH:
        _walk(points, (1, 0), 11)
        height = peaks[index % len(peaks)]
        _walk(points, (1, -1), height)
        _walk(points, (1, 0), 2)
        _walk(points, (1, 1), height)
        index += 1
    return points[:MAIN_LENGTH]


def shape_vertical():
    """세로 S자형: 아래로 15칸, 오른쪽 5칸, 위로 15칸을 되풀이하며 오른쪽으로 간다."""
    points = [(0, 0)]
    direction = 1
    while len(points) < MAIN_LENGTH:
        _walk(points, (0, direction), 15)
        _walk(points, (1, 0), 5)
        direction *= -1
    return points[:MAIN_LENGTH]


def shape_twin_rings():
    """쌍고리형: 왼쪽 고리를 한 바퀴 돌고 가운데 다리를 건너 오른쪽 고리를 돌아 안쪽에서 끝난다(8자처럼)."""
    points = [(12, 0)]
    for direction, steps in [((-1, 0), 12), ((0, 1), 12), ((1, 0), 12), ((0, -1), 9),
                             ((1, 0), 4), ((0, -1), 3), ((1, 0), 12), ((0, 1), 12), ((-1, 0), 12), ((0, -1), 7)]:
        _walk(points, direction, steps)
    return points[:MAIN_LENGTH]


SHAPES = {
    "uturn": shape_uturn, "pyramid": shape_pyramid, "spiral": shape_spiral, "straight": shape_straight,
    "stairs": shape_stairs, "mountain": shape_mountain, "vertical": shape_vertical, "twin_rings": shape_twin_rings,
}


# ---------------------------------------------------------------- 갈림길(마름모) 넣기

def _find_fork_windows(points):
    """큰길에서 곧게 뻗은 구간을 골라 갈림길 마름모를 넣을 자리 3곳을 정한다.
    마름모: 갈림길 칸 p[i] → 위쪽 갈래(LANE_LENGTH칸)와 아래쪽 갈래 → 거점 칸 p[i+LANE_LENGTH+1].
    두 갈래는 큰길에서 한 칸 옆으로 비켜 간다. 가운데 큰길 칸은 없앤다."""
    used = set(points)
    windows = []
    taken = set()
    span = LANE_LENGTH + 1
    targets = [int(len(points) * f) for f in (0.22, 0.5, 0.75)]
    for target in targets:
        found = None
        for offset in range(0, len(points)):
            for i in (target + offset, target - offset):
                if i < 3 or i + span >= len(points) - 3:
                    continue
                seg = points[i:i + span + 1]
                dx = seg[1][0] - seg[0][0]
                dy = seg[1][1] - seg[0][1]
                straight = all(seg[k + 1][0] - seg[k][0] == dx and seg[k + 1][1] - seg[k][1] == dy for k in range(span))
                if not straight or (dx != 0 and dy != 0):
                    continue
                perp = (-dy, dx)
                lanes = []
                ok = True
                for sign in (1, -1):
                    lane = [(p[0] + perp[0] * sign, p[1] + perp[1] * sign) for p in seg[1:-1]]
                    for c in lane:
                        if c in used or c in taken:
                            ok = False
                        # 옆 칸까지 비어 있어야 다른 길과 붙어 보이지 않는다.
                        outer = (c[0] + perp[0] * sign, c[1] + perp[1] * sign)
                        if outer in used:
                            ok = False
                    lanes.append(lane)
                if any(abs(i - w[0]) < span + 4 for w in windows):
                    ok = False
                if ok:
                    found = (i, lanes)
                    break
            if found:
                break
        if found is None:
            raise SystemExit("갈림길 자리를 찾지 못함")
        windows.append(found)
        for lane in found[1]:
            taken.update(lane)
    windows.sort()
    return windows


def make_board(theme):
    rng = random.Random(theme["seed"])
    points = SHAPES[theme["shape"]]()
    windows = _find_fork_windows(points)
    nodes = []

    def add(xy, kind="normal"):
        node = {"id": len(nodes), "type": kind, "x": xy[0], "y": xy[1], "next": []}
        nodes.append(node)
        return node

    def link(a, b):
        a["next"].append(b["id"])

    main_path = []
    lanes = []
    window_starts = {w[0]: w for w in windows}
    previous = None
    i = 0
    while i < len(points):
        if i in window_starts:
            _, (lane_up, lane_down) = window_starts[i]
            fork = add(points[i], "fork")
            if previous is not None:
                link(previous, fork)
            lane_a = [add(c) for c in lane_up]
            lane_b = [add(c) for c in lane_down]
            merge = add(points[i + LANE_LENGTH + 1], "checkpoint")
            link(fork, lane_a[0])
            link(fork, lane_b[0])
            for a, b in zip(lane_a, lane_a[1:]):
                link(a, b)
            for a, b in zip(lane_b, lane_b[1:]):
                link(a, b)
            link(lane_a[-1], merge)
            link(lane_b[-1], merge)
            main_path.extend([fork, merge])
            lanes.append((lane_a, lane_b, fork, merge))
            previous = merge
            i += LANE_LENGTH + 2
            continue
        node = add(points[i])
        if previous is not None:
            link(previous, node)
        previous = node
        main_path.append(node)
        i += 1
    # 좌표를 0부터 시작하게 옮긴다.
    min_x = min(n["x"] for n in nodes)
    min_y = min(n["y"] for n in nodes)
    for n in nodes:
        n["x"] -= min_x
        n["y"] -= min_y
    start = main_path[0]
    goal = main_path[-1]
    start["type"] = "start"
    goal["type"] = "goal"
    goal["name"] = theme["boss"]
    goal["dice"] = 4

    # 큰길 내용: 거점은 10칸 안팎마다, 키퍼는 7~9칸마다, 나머지는 비율대로.
    total = len(main_path)
    since_checkpoint = 0
    since_keeper = 0
    for position, node in enumerate(main_path):
        if node["type"] != "normal":
            if node["type"] == "checkpoint":
                since_checkpoint = 0
            continue
        progress = position / total
        since_checkpoint += 1
        since_keeper += 1
        if position < 2 or position > total - 3:
            node["type"] = "random" if position == total - 2 else "normal"
            continue
        if since_checkpoint >= 9:
            node["type"] = "checkpoint"
            since_checkpoint = 0
            continue
        if since_keeper >= rng.randint(7, 9):
            _make_keeper(node, theme, progress, rng, ambush_rate=theme["ambush_rate"])
            since_keeper = 0
            continue
        _fill(node, theme["weights"], theme, rng)

    # 갈림길: 위쪽 갈래(A)는 위험(키퍼·판정), 아래쪽 갈래(B)는 안전(보물·행운).
    for number, (lane_a, lane_b, fork, merge) in enumerate(lanes):
        routes = theme["routes"][number % len(theme["routes"])]
        progress = main_path.index(fork) / total
        for k, node in enumerate(lane_a):
            if k in (2, 5):
                _make_keeper(node, theme, min(1.0, progress + 0.15), rng, ambush_rate=theme["ambush_rate"])
            else:
                _fill(node, theme["risky"], theme, rng)
        for node in lane_b:
            _fill(node, theme["safe"], theme, rng)
        lane_a[0]["route"] = routes[0]
        lane_b[0]["route"] = routes[1]

    # 속성 칸 4개를 큰길에 고르게 둔다.
    plain = [n for n in main_path if n["type"] in ("normal", "random")]
    for k, attr in enumerate(["영웅", "위인", "신화", "근현대"]):
        spot = plain[int(len(plain) * (k + 0.5) / 4)]
        spot["type"] = "attr"
        spot["attr"] = attr
        spot.pop("hidden", None)

    return {
        "_comment": theme["comment"],
        "name": theme["name"],
        "shape": theme["shape_name"],
        "theme": theme["colors"],
        "start": start["id"],
        "nodes": nodes,
        "random_pool": theme["random_pool"],
    }


def _make_keeper(node, theme, progress, rng, ambush_rate):
    dice = 2 if progress < 0.3 else 3
    if rng.random() < ambush_rate:
        node["type"] = "ambush"
        node["name"] = rng.choice(theme["ambushers"])
    else:
        node["type"] = "battle"
        node["name"] = rng.choice(theme["keepers"])
    node["dice"] = dice


def _fill(node, weights, theme, rng):
    kinds = list(weights.keys())
    kind = rng.choices(kinds, weights=[weights[k] for k in kinds])[0]
    node["type"] = kind
    if kind == "random" and rng.random() < 0.35:
        node["hidden"] = True
    if kind == "forward":
        node["amount"] = rng.choice([3, 4])


COMMON_POOL = [
    {"weight": 3, "tile": {"type": "treasure"}},
    {"weight": 2, "tile": {"type": "luck"}},
    {"weight": 2, "tile": {"type": "curse"}},
    {"weight": 1, "tile": {"type": "forward", "amount": 3}},
    {"weight": 1, "tile": {"type": "prison"}},
    {"weight": 1, "tile": {"type": "fate"}},
    {"weight": 2, "tile": {"type": "warp"}},
]

THEMES = [
    {
        "file": "data/board.json", "seed": 101, "name": "초원의 길", "boss": "메두사",
        "shape": "uturn", "shape_name": "유턴형",
        "comment": "초원 맵(약 120칸, 유턴형). 고르게 섞인 기본 맵. tools/make_maps.py로 만든다.",
        "colors": {"terrain": "grass", "bg": "24452e", "line": "9fe0a8"},
        "keepers": ["들개 무리", "굶주린 늑대", "산적", "멧돼지", "석상 병사", "늪의 큰뱀", "외눈 거인"],
        "ambushers": ["산적 두목", "숲의 그림자", "독수리 떼"],
        "ambush_rate": 0.3,
        "weights": {"normal": 3, "random": 4, "treasure": 2, "luck": 2, "curse": 1, "forward": 1, "fate": 1, "prison": 0.5},
        "risky": {"random": 3, "fate": 2, "curse": 1, "forward": 2, "normal": 1},
        "safe": {"treasure": 3, "luck": 2, "random": 2, "normal": 2},
        "routes": [["험한 길 (짧고 전투 많음)", "보물 길 (길지만 안전)"], ["늪지대 (짧고 위험)", "꽃밭 길 (행운)"], ["절벽 길 (짧음)", "강변 길 (보물)"]],
        "random_pool": COMMON_POOL,
    },
    {
        "file": "data/boards/desert.json", "seed": 202, "name": "사막의 길", "boss": "스핑크스",
        "shape": "pyramid", "shape_name": "피라미드형",
        "comment": "사막 맵(약 120칸, 피라미드형). 판정과 보물이 많다. tools/make_maps.py로 만든다.",
        "colors": {"terrain": "desert", "bg": "5a4220", "line": "e0b46a"},
        "keepers": ["사막 전갈", "미라 병사", "모래 벌레", "도굴꾼", "독사 떼", "황금 골렘"],
        "ambushers": ["모래 도적단", "사막 늑대", "사자 석상"],
        "ambush_rate": 0.3,
        "weights": {"normal": 2, "random": 4, "treasure": 3, "luck": 1, "fate": 2, "curse": 1, "forward": 1, "prison": 0.5},
        "risky": {"fate": 3, "random": 2, "forward": 2, "curse": 1},
        "safe": {"treasure": 3, "luck": 2, "random": 2, "normal": 1},
        "routes": [["모래폭풍 길 (판정 많음)", "오아시스 길 (행운)"], ["피라미드 안 (짧고 위험)", "낙타 길 (보물)"], ["유사 지대 (짧음)", "바위 그늘 길 (안전)"]],
        "random_pool": [
            {"weight": 3, "tile": {"type": "treasure"}},
            {"weight": 2, "tile": {"type": "luck"}},
            {"weight": 2, "tile": {"type": "fate"}},
            {"weight": 1, "tile": {"type": "curse"}},
            {"weight": 1, "tile": {"type": "forward", "amount": 3}},
            {"weight": 1, "tile": {"type": "battle", "name": "모래 벌레", "dice": 2}},
            {"weight": 1, "tile": {"type": "prison"}},
            {"weight": 2, "tile": {"type": "warp"}},
        ],
    },
    {
        "file": "data/boards/frost.json", "seed": 303, "name": "설원의 성채", "boss": "서리 거인",
        "shape": "spiral", "shape_name": "나선형",
        "comment": "설원 맵(약 120칸, 나선형). 습격이 많아 DEFENSE가 중요하다. tools/make_maps.py로 만든다.",
        "colors": {"terrain": "snow", "bg": "1f4a6e", "line": "a8d8ff"},
        "keepers": ["얼음 정령", "성채 수비대", "설원 곰", "얼음 골렘", "서리 늑대"],
        "ambushers": ["설인", "눈늑대", "서리 기사", "빙결 마법사", "얼음 거미", "눈사태 정령"],
        "ambush_rate": 0.6,
        "weights": {"normal": 3, "random": 4, "treasure": 2, "luck": 2, "curse": 1.5, "forward": 1, "prison": 0.4, "fate": 0.5},
        "risky": {"random": 2, "forward": 3, "curse": 1, "normal": 1},
        "safe": {"treasure": 3, "luck": 2, "random": 2, "normal": 1},
        "routes": [["얼음 다리 (짧고 습격)", "성벽 아래 길 (보물)"], ["빙하 틈 (짧음)", "눈 덮인 숲 (안전)"], ["얼어붙은 호수 (짧음)", "성채 회랑 (보물)"]],
        "random_pool": [
            {"weight": 2, "tile": {"type": "treasure"}},
            {"weight": 2, "tile": {"type": "luck"}},
            {"weight": 2, "tile": {"type": "ambush", "name": "눈보라 늑대", "dice": 3}},
            {"weight": 1, "tile": {"type": "curse"}},
            {"weight": 2, "tile": {"type": "forward", "amount": 3}},
            {"weight": 2, "tile": {"type": "warp"}},
        ],
    },
    {
        "file": "data/boards/river.json", "seed": 404, "name": "강변의 길", "boss": "히드라",
        "shape": "straight", "shape_name": "직선형",
        "comment": "강변 맵(약 120칸, 직선형). 전진·행운이 많아 빠르지만 저주와 판정도 있다. tools/make_maps.py로 만든다.",
        "colors": {"terrain": "river", "bg": "1d4a4a", "line": "8fe8e0"},
        "keepers": ["강도떼", "물뱀", "늪 악어", "다리 지기", "강의 거인"],
        "ambushers": ["물귀신", "갈대숲 도적", "거대 개구리"],
        "ambush_rate": 0.35,
        "weights": {"normal": 3, "random": 4, "forward": 2, "luck": 2, "treasure": 2, "curse": 1.5, "fate": 1, "prison": 0.4},
        "risky": {"random": 2, "fate": 2, "forward": 2, "curse": 1},
        "safe": {"treasure": 3, "luck": 2, "random": 2, "normal": 1},
        "routes": [["급류 길 (짧고 위험)", "둑길 (안전)"], ["나룻배 (판정)", "다리 길 (보물)"], ["폭포 옆 (위험)", "갈대밭 길 (행운)"]],
        "random_pool": COMMON_POOL,
    },
    {
        "file": "data/boards/ruins.json", "seed": 505, "name": "고대 유적", "boss": "고대 골렘",
        "shape": "stairs", "shape_name": "계단형",
        "comment": "유적 맵(약 120칸, 계단형). 보물과 함정(저주·감옥)이 함께 많다. tools/make_maps.py로 만든다.",
        "colors": {"terrain": "ruins", "bg": "3d3a33", "line": "d9cfa8"},
        "keepers": ["돌 수호병", "해골 병사", "도굴꾼 두목", "석상 사자", "고대 거미"],
        "ambushers": ["함정 화살", "무너지는 천장", "유령 병사"],
        "ambush_rate": 0.35,
        "weights": {"normal": 2, "random": 4, "treasure": 3, "curse": 2, "prison": 1, "luck": 1, "fate": 1, "forward": 1},
        "risky": {"random": 2, "curse": 2, "fate": 2, "treasure": 1},
        "safe": {"treasure": 3, "luck": 2, "random": 2, "normal": 1},
        "routes": [["무너진 회랑 (짧고 위험)", "기둥 사이 길 (안전)"], ["지하 묘실 (보물·함정)", "정원 길 (행운)"], ["낡은 다리 (짧음)", "벽화 복도 (보물)"]],
        "random_pool": COMMON_POOL,
    },
    {
        "file": "data/boards/volcano.json", "seed": 606, "name": "화산 산맥", "boss": "불사조",
        "shape": "mountain", "shape_name": "산맥형",
        "comment": "화산 맵(약 120칸, 산맥형). 키퍼가 강하고 전진 칸이 많다. tools/make_maps.py로 만든다.",
        "colors": {"terrain": "volcano", "bg": "4a1f1a", "line": "ff9a6a"},
        "keepers": ["용암 도마뱀", "불꽃 정령", "화산 골렘", "재의 기사", "화염 박쥐"],
        "ambushers": ["불꽃 늑대", "용암 뱀", "화산탄"],
        "ambush_rate": 0.3,
        "weights": {"normal": 3, "random": 4, "forward": 2, "treasure": 2, "luck": 1, "curse": 1.5, "fate": 1.5, "prison": 0.3},
        "risky": {"forward": 3, "fate": 2, "random": 2, "curse": 1},
        "safe": {"treasure": 3, "luck": 2, "random": 2, "normal": 1},
        "routes": [["용암 길 (짧고 위험)", "식은 바위 길 (안전)"], ["분화구 가장자리 (짧음)", "온천 길 (행운)"], ["불꽃 다리 (위험)", "동굴 길 (보물)"]],
        "random_pool": COMMON_POOL,
    },
    {
        "file": "data/boards/forest.json", "seed": 707, "name": "깊은 숲", "boss": "고목 정령",
        "shape": "vertical", "shape_name": "세로 S자형",
        "comment": "숲 맵(약 120칸, 세로 S자형). 숨은 칸과 행운이 많다. tools/make_maps.py로 만든다.",
        "colors": {"terrain": "forest", "bg": "1a3a22", "line": "b6f0a0"},
        "keepers": ["숲 곰", "가시덩굴 괴물", "산적", "멧돼지 무리", "버섯 거인"],
        "ambushers": ["숲의 그림자", "늑대 무리", "독거미"],
        "ambush_rate": 0.35,
        "weights": {"normal": 2, "random": 6, "luck": 2, "treasure": 2, "curse": 1, "forward": 1, "fate": 1, "prison": 0.4},
        "risky": {"random": 3, "curse": 1, "fate": 2, "forward": 1},
        "safe": {"luck": 3, "treasure": 2, "random": 2, "normal": 1},
        "routes": [["가시덤불 길 (짧고 위험)", "오솔길 (안전)"], ["늪지 (판정)", "꽃 피는 길 (행운)"], ["안개 계곡 (짧음)", "샘물 길 (보물)"]],
        "random_pool": COMMON_POOL,
    },
    {
        "file": "data/boards/sky.json", "seed": 808, "name": "하늘 섬", "boss": "천둥새",
        "shape": "twin_rings", "shape_name": "쌍고리형",
        "comment": "하늘 맵(약 120칸, 쌍고리형). 판정과 전진이 많아 변화가 크다. tools/make_maps.py로 만든다.",
        "colors": {"terrain": "sky", "bg": "23366b", "line": "c8d8ff"},
        "keepers": ["구름 정령", "바람 기사", "하피", "번개 정령", "하늘 고래"],
        "ambushers": ["돌풍", "독수리 떼", "구름 도적"],
        "ambush_rate": 0.3,
        "weights": {"normal": 3, "random": 4, "fate": 2, "forward": 2, "luck": 2, "treasure": 2, "curse": 1, "prison": 0.3},
        "risky": {"fate": 3, "forward": 2, "random": 2},
        "safe": {"treasure": 3, "luck": 2, "random": 2, "normal": 1},
        "routes": [["구름 다리 (짧고 위험)", "섬 가장자리 (안전)"], ["돌풍 길 (판정)", "무지개 길 (행운)"], ["번개 구름 (위험)", "정원 섬 (보물)"]],
        "random_pool": COMMON_POOL,
    },
]


def save(path, board):
    lines = ["{"]
    keys = list(board.keys())
    for i, key in enumerate(keys):
        end = "," if i < len(keys) - 1 else ""
        value = board[key]
        if isinstance(value, list):
            lines.append("  %s: [" % json.dumps(key))
            for j, item in enumerate(value):
                lines.append("    " + json.dumps(item, ensure_ascii=False) + ("," if j < len(value) - 1 else ""))
            lines.append("  ]" + end)
        else:
            lines.append("  %s: %s%s" % (json.dumps(key), json.dumps(value, ensure_ascii=False), end))
    lines.append("}")
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")


def shortest(board):
    nodes = {n["id"]: n for n in board["nodes"]}
    goal = [n["id"] for n in board["nodes"] if n["type"] == "goal"][0]
    from collections import deque
    dist = {board["start"]: 0}
    queue = deque([board["start"]])
    while queue:
        cur = queue.popleft()
        for nxt in nodes[cur]["next"]:
            if nxt not in dist:
                dist[nxt] = dist[cur] + 1
                queue.append(nxt)
    return dist[goal]


if __name__ == "__main__":
    for theme in THEMES:
        board = make_board(theme)
        save(theme["file"], board)
        counts = {}
        for n in board["nodes"]:
            counts[n["type"]] = counts.get(n["type"], 0) + 1
        w = max(n["x"] for n in board["nodes"]) + 1
        h = max(n["y"] for n in board["nodes"]) + 1
        print(theme["name"], theme["shape_name"], len(board["nodes"]), "칸, 가로", w, "세로", h, "가장 짧은 길", shortest(board))

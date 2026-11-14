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
WIDTH = 10
LAYOUT = ["P", "P", "F", "P", "P", "F", "P", "F", "P"]


def make_board(theme):
    rng = random.Random(theme["seed"])
    nodes = []

    def add(x, y, kind="normal"):
        node = {"id": len(nodes), "type": kind, "x": x, "y": y, "next": []}
        nodes.append(node)
        return node

    def link(a, b):
        a["next"].append(b["id"])

    # 1) 자리와 연결만 먼저 만든다.
    main_path = []  # 갈림길 길을 뺀 큰길 칸 순서 (내용 정하기에 씀)
    lanes = []      # [(A길 칸들, B길 칸들, 갈림길 칸, 거점 칸)]
    y = 0
    direction = 1
    previous = None
    for index, block in enumerate(LAYOUT):
        xs = list(range(WIDTH)) if direction == 1 else list(range(WIDTH - 1, -1, -1))
        if block == "P":
            row = []
            for x in xs:
                node = add(x, y)
                if previous is not None:
                    link(previous, node)
                previous = node
                row.append(node)
            main_path.extend(row)
            y += 1
        else:
            # 갈림길 칸은 이 줄의 첫 칸. A길은 같은 줄, B길은 아래 줄. 거점은 아래 줄 끝.
            fork = add(xs[0], y, "fork")
            link(previous, fork)
            lane_a = [add(x, y) for x in xs[1:-1]]
            lane_b = [add(x, y + 1) for x in xs[:-1]]
            merge = add(xs[-1], y + 1, "checkpoint")
            link(fork, lane_a[0])
            link(fork, lane_b[0])
            for a, b in zip(lane_a, lane_a[1:]):
                link(a, b)
            for a, b in zip(lane_b, lane_b[1:]):
                link(a, b)
            link(lane_a[-1], merge)
            link(lane_b[-1], merge)
            main_path.append(fork)
            main_path.append(merge)
            lanes.append((lane_a, lane_b, fork, merge))
            previous = merge
            y += 2
        direction *= -1
    start = main_path[0]
    goal = main_path[-1]
    start["type"] = "start"
    goal["type"] = "goal"
    goal["name"] = theme["boss"]
    goal["dice"] = 4

    # 2) 큰길 내용: 거점은 10칸 안팎마다, 키퍼는 7~9칸마다, 나머지는 비율대로.
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

    # 3) 갈림길 길: A길은 짧고 위험(키퍼·판정), B길은 길고 안전(보물·행운).
    for number, (lane_a, lane_b, fork, merge) in enumerate(lanes):
        routes = theme["routes"][number % len(theme["routes"])]
        progress = main_path.index(fork) / total
        for i, node in enumerate(lane_a):
            if i in (2, 5):
                _make_keeper(node, theme, min(1.0, progress + 0.15), rng, ambush_rate=theme["ambush_rate"])
            else:
                _fill(node, theme["risky"], theme, rng)
        for node in lane_b:
            _fill(node, theme["safe"], theme, rng)
        lane_a[0]["route"] = routes[0]
        lane_b[0]["route"] = routes[1]

    # 4) 속성 칸 4개를 큰길에 고르게 둔다.
    plain = [n for n in main_path if n["type"] in ("normal", "random")]
    for i, attr in enumerate(["영웅", "위인", "신화", "근현대"]):
        spot = plain[int(len(plain) * (i + 0.5) / 4)]
        spot["type"] = "attr"
        spot["attr"] = attr
        spot.pop("hidden", None)

    return {
        "_comment": theme["comment"],
        "name": theme["name"],
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
]

THEMES = [
    {
        "file": "data/board.json", "seed": 101, "name": "초원의 길", "boss": "메두사",
        "comment": "초원 맵(약 120칸). 고르게 섞인 기본 맵. tools/make_maps.py로 만든다.",
        "colors": {"bg": "24452e", "line": "9fe0a8"},
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
        "comment": "사막 맵(약 120칸). 판정과 보물이 많다. tools/make_maps.py로 만든다.",
        "colors": {"bg": "5a4220", "line": "e0b46a"},
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
        ],
    },
    {
        "file": "data/boards/frost.json", "seed": 303, "name": "설원의 성채", "boss": "서리 거인",
        "comment": "설원 맵(약 120칸). 습격이 많아 DEFENSE가 중요하다. tools/make_maps.py로 만든다.",
        "colors": {"bg": "1f4a6e", "line": "a8d8ff"},
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
        ],
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
        print(theme["name"], len(board["nodes"]), "칸, 가장 짧은 길", shortest(board), counts)

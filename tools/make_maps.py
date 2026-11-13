"""새 맵 파일을 만든다. 칸 배치(좌표)는 코드로 정하고, 칸 내용만 맵마다 다르게 적는다.

실행: python3 tools/make_maps.py  →  data/boards/desert.json, data/boards/frost.json
배치: 1줄 →, 2줄 ←, 3줄 갈림길(두 갈래가 3·4줄로 나란히 →), 합류 거점, 5줄 ←, 6줄 → 골.
"""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "data" / "boards"


def build(spec):
    # 좌표 순서: 첫 줄(0~6) → 둘째 줄(6~0) → 갈림길 (0,2)
    #   A갈래: (1,2)~(6,2)  B갈래: (0,3)~(5,3)  합류: (6,3)
    #   다섯째 줄 (6,4)~(0,4) → 여섯째 줄 (0,5)~(5,5) 골
    coords = [(x, 0) for x in range(7)] + [(x, 1) for x in range(6, -1, -1)]
    fork = (0, 2)
    lane_a = [(x, 2) for x in range(1, 7)]
    lane_b = [(x, 3) for x in range(0, 6)]
    merge = (6, 3)
    tail = [(x, 4) for x in range(6, -1, -1)] + [(x, 5) for x in range(0, 6)]
    tiles = spec["tiles"]
    assert len(tiles["head"]) == 14 and len(tiles["a"]) == 6 and len(tiles["b"]) == 6 and len(tiles["tail"]) == 13, spec["name"]
    nodes = []
    next_id = 0

    def add(tile, xy):
        nonlocal next_id
        node = {"id": next_id}
        node.update(tile)
        node["x"], node["y"] = xy
        node["next"] = []
        nodes.append(node)
        next_id += 1
        return node

    head_nodes = [add(t, xy) for t, xy in zip(tiles["head"], coords)]
    fork_node = add({"type": "fork"}, fork)
    a_nodes = [add(t, xy) for t, xy in zip(tiles["a"], lane_a)]
    b_nodes = [add(t, xy) for t, xy in zip(tiles["b"], lane_b)]
    merge_node = add({"type": "checkpoint"}, merge)
    tail_nodes = [add(t, xy) for t, xy in zip(tiles["tail"], tail)]
    a_nodes[0]["route"] = spec["route_a"]
    b_nodes[0]["route"] = spec["route_b"]

    def chain(seq):
        for first, second in zip(seq, seq[1:]):
            first["next"].append(second["id"])

    chain(head_nodes + [fork_node])
    fork_node["next"] = [a_nodes[0]["id"], b_nodes[0]["id"]]
    chain(a_nodes + [merge_node])
    chain(b_nodes + [merge_node])
    chain([merge_node] + tail_nodes)
    for node in nodes:
        if node["type"] == "warp":
            node["to"] = node.pop("to_index")
    return {
        "_comment": spec["comment"],
        "name": spec["name"],
        "theme": spec["theme"],
        "start": 0,
        "nodes": nodes,
        "random_pool": spec["random_pool"],
    }


def T(kind, **extra):
    tile = {"type": kind}
    tile.update(extra)
    return tile


DESERT = {
    "name": "사막의 길",
    "comment": "사막 맵. 판정과 보물이 많고, 골은 스핑크스가 지킨다. tools/make_maps.py로 만든다.",
    "theme": {"bg": "5a4220", "line": "e0b46a"},
    "route_a": "오아시스 길 (행운과 회복)",
    "route_b": "모래폭풍 길 (판정 많음, 보물 큼)",
    "tiles": {
        "head": [
            T("start"), T("normal"), T("random"), T("attr", attr="근현대"), T("treasure"),
            T("battle", name="사막 전갈", dice=2), T("random"),
            T("luck"), T("fate"), T("ambush", name="모래 도적단", dice=3), T("checkpoint"),
            T("random", hidden=True), T("attr", attr="위인"), T("random"),
        ],
        "a": [T("luck"), T("treasure"), T("random", hidden=True), T("luck"), T("ambush", name="사막 늑대", dice=3), T("normal")],
        "b": [T("fate"), T("treasure"), T("fate"), T("random", hidden=True), T("treasure"), T("forward", amount=3)],
        "tail": [
            T("attr", attr="신화"), T("battle", name="미라 병사", dice=3), T("random"), T("curse"), T("checkpoint"),
            T("random", hidden=True), T("ambush", name="사자 석상", dice=3),
            T("random"), T("prison"), T("luck"), T("fate"), T("random"), T("goal", name="스핑크스", dice=4),
        ],
    },
    "random_pool": [
        {"weight": 3, "tile": {"type": "treasure"}},
        {"weight": 2, "tile": {"type": "luck"}},
        {"weight": 2, "tile": {"type": "fate"}},
        {"weight": 1, "tile": {"type": "curse"}},
        {"weight": 1, "tile": {"type": "forward", "amount": 3}},
        {"weight": 1, "tile": {"type": "battle", "name": "모래 벌레", "dice": 2}},
        {"weight": 1, "tile": {"type": "prison"}},
    ],
}

FROST = {
    "name": "설원의 성채",
    "comment": "설원 맵. 습격이 많아 DEFENSE가 중요하고, 골은 서리 거인이 지킨다. tools/make_maps.py로 만든다.",
    "theme": {"bg": "1f4a6e", "line": "a8d8ff"},
    "route_a": "얼음 다리 (짧은 대신 습격)",
    "route_b": "성벽 아래 길 (안전, 보물)",
    "tiles": {
        "head": [
            T("start"), T("random"), T("attr", attr="신화"), T("ambush", name="눈늑대", dice=2), T("random"),
            T("luck"), T("battle", name="얼음 정령", dice=2),
            T("random"), T("curse"), T("ambush", name="설인", dice=3), T("checkpoint"),
            T("random", hidden=True), T("attr", attr="영웅"), T("treasure"),
        ],
        "a": [T("ambush", name="얼음 거미", dice=3), T("forward", amount=4), T("random", hidden=True), T("ambush", name="눈사태 정령", dice=3), T("forward", amount=3), T("normal")],
        "b": [T("treasure"), T("luck"), T("random"), T("treasure"), T("prison"), T("treasure")],
        "tail": [
            T("battle", name="성채 수비대", dice=3), T("random"), T("attr", attr="근현대"), T("ambush", name="서리 기사", dice=3), T("checkpoint"),
            T("random", hidden=True), T("curse"),
            T("random"), T("luck"), T("ambush", name="빙결 마법사", dice=3), T("fate"), T("random"), T("goal", name="서리 거인", dice=4),
        ],
    },
    "random_pool": [
        {"weight": 2, "tile": {"type": "treasure"}},
        {"weight": 2, "tile": {"type": "luck"}},
        {"weight": 2, "tile": {"type": "ambush", "name": "눈보라 늑대", "dice": 3}},
        {"weight": 1, "tile": {"type": "curse"}},
        {"weight": 1, "tile": {"type": "prison"}},
        {"weight": 1, "tile": {"type": "forward", "amount": 3}},
    ],
}


def save(name, board):
    OUT.mkdir(parents=True, exist_ok=True)
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
    (OUT / name).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("저장:", OUT / name, len(board["nodes"]), "칸")


if __name__ == "__main__":
    save("desert.json", build(DESERT))
    save("frost.json", build(FROST))

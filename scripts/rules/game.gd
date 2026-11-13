extends RefCounted
## 규칙 엔진. 화면과 무관하게 한 판을 진행한다.
## 주사위는 roll_dice()에서만 굴린다. 7단계에서 이 파일의 로직을 서버로 옮긴다.
##
## 한 턴의 순서:
##   begin_turn() → (play_card / use_ability, 각 1회까지) → roll_move()
##   → (갈림길이면 choose_path()를 길이 정해질 때까지) → end_turn()
##
## 보드는 칸(node)과 다음 칸(next) 연결로 이뤄진다. next가 2개 이상이면 갈림길이다.
## 말이 지나온 길은 trail에 쌓아 두고, 뒤로 물러날 때는 그 길을 거꾸로 되짚는다.

const SLOTS := ["attack", "defense", "support"]
const SLOT_LABELS := {"attack": "ATTACK", "defense": "DEFENSE", "support": "SUPPORT"}
const POINT_LIMIT := 6
const MAX_ROUNDS := 20
const HAND_LIMIT := 3
const START_HAND := 3
const MAX_BATTLE_DICE := 6
const ATTR_BONUS := 2
const MAX_MESSAGES := 60
const CHASE_STEPS := 3
const COUNTER_STEPS := 3

## 지속 효과로 그대로 쌓이는 종류. _apply_effect()에서 같은 이름으로 저장한다.
const TIMED_EFFECTS := [
	"atk_dice", "def_dice", "atk_bonus", "def_bonus",
	"move_dice", "enemy_dice_minus", "chase", "counter",
]

var rng := RandomNumberGenerator.new()
## id → 칸. random 칸은 setup()에서 실제 효과로 바뀐다.
var nodes: Dictionary = {}
var start_id := 0
## id → 가장 가까운 골까지 남은 칸 수
var dist_to_goal: Dictionary = {}
## 숨겨진 칸 중 이미 밟혀서 드러난 칸 id
var revealed: Dictionary = {}
var cards: Dictionary = {}
var abilities: Dictionary = {}
var characters: Dictionary = {}
## 이동 주사위 눈의 비율. "1"은 주사위 1개일 때, "2"는 2개 이상일 때.
var move_weights: Dictionary = {}

var players: Array = []
var current := 0
var round_number := 1
var map_attr := ""
## -1 진행 중, 0 또는 1 승자, 2 무승부
var winner := -1
var messages: Array = []
## 화면이 연출에 쓰는 사건 기록. take_events()로 가져가면 비워진다.
## kind: "pos"(말이 한 칸 이동), "move"(이동 주사위), "battle"(전투), "fate"(운명의 판정)
var events: Array = []
## 갈림길에서 길을 골라야 할 때 채워진다. {"options": [칸 id...], "steps": 남은 칸 수}
var pending_choice: Dictionary = {}

var card_played := false
var ability_used := false
var moved := false


## data: GameData.load_all()의 결과.
## parties: [{"name": 이름, "attack": id, "defense": id, "support": id}, ...] 두 개.
func setup(data: Dictionary, parties: Array, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	cards = data.get("cards", {})
	abilities = data.get("abilities", {})
	move_weights = data.get("rules", {}).get("move_dice_weights", {})
	characters = {}
	for character in data.get("characters", []):
		characters[character["id"]] = character
	_load_board(data.get("board", {}))

	players = []
	for party in parties:
		players.append({
			"name": party["name"],
			"slots": {
				"attack": party["attack"],
				"defense": party["defense"],
				"support": party["support"],
			},
			"pos": start_id,
			"trail": [start_id],
			"hand": [],
			"gauge": {"attack": 0, "defense": 0, "support": 0},
			"skip": 0,
			"effects": [],
			"cursed": false,
			"charm": false,
		})
	current = 0
	round_number = 1
	map_attr = ""
	winner = -1
	messages = []
	events = []
	pending_choice = {}
	revealed = {}
	for index in players.size():
		for i in START_HAND:
			_draw_card(index, false)
	say("게임 시작! 먼저 골에 들어가면 승리합니다.")


func _load_board(board: Dictionary) -> void:
	nodes = {}
	start_id = int(board.get("start", 0))
	for raw in board.get("nodes", []):
		var node: Dictionary = raw.duplicate(true)
		node["id"] = int(node["id"])
		var next_ids: Array = []
		for next_id in node.get("next", []):
			next_ids.append(int(next_id))
		node["next"] = next_ids
		nodes[node["id"]] = node
	# random 칸에 이번 판의 효과를 정한다.
	var pool: Array = board.get("random_pool", [])
	var ids := nodes.keys()
	ids.sort()
	for id in ids:
		var node: Dictionary = nodes[id]
		if node["type"] == "random" and not pool.is_empty():
			var picked: Dictionary = _pick_weighted(pool)
			for key in picked:
				node[key] = picked[key]
	_compute_distances()


func _pick_weighted(pool: Array) -> Dictionary:
	var total := 0
	for entry in pool:
		total += int(entry.get("weight", 1))
	var roll := rng.randi_range(1, max(total, 1))
	for entry in pool:
		roll -= int(entry.get("weight", 1))
		if roll <= 0:
			return entry["tile"].duplicate(true)
	return pool[0]["tile"].duplicate(true)


## 골에서 거꾸로 거리를 잰다. 골이 여러 개면 가장 가까운 골 기준이다.
func _compute_distances() -> void:
	dist_to_goal = {}
	var incoming := {}
	var frontier: Array = []
	for id in nodes:
		incoming[id] = []
	for id in nodes:
		for next_id in nodes[id]["next"]:
			if incoming.has(next_id):
				incoming[next_id].append(id)
		if nodes[id]["type"] == "goal":
			dist_to_goal[id] = 0
			frontier.append(id)
	while not frontier.is_empty():
		var id: int = frontier.pop_front()
		for prev_id in incoming[id]:
			if not dist_to_goal.has(prev_id):
				dist_to_goal[prev_id] = int(dist_to_goal[id]) + 1
				frontier.append(prev_id)


# ---------------------------------------------------------------- 조회

func node_of(id: int) -> Dictionary:
	return nodes.get(id, {})


func distance_of(player_index: int) -> int:
	return int(dist_to_goal.get(int(players[player_index]["pos"]), 999))


func is_hidden(id: int) -> bool:
	return bool(node_of(id).get("hidden", false)) and not revealed.has(id)


func char_of(player_index: int, slot: String) -> Dictionary:
	return characters[players[player_index]["slots"][slot]]


func ability_of(player_index: int, slot: String) -> Dictionary:
	return abilities.get(char_of(player_index, slot).get("ability", ""), {})


func party_points(player_index: int) -> int:
	var total := 0
	for slot in SLOTS:
		total += int(char_of(player_index, slot)["grade"])
	return total


func effect_sum(player_index: int, key: String) -> int:
	var total := 0
	for effect in players[player_index]["effects"]:
		if effect["key"] == key:
			total += int(effect["amount"])
	return total


func can_act() -> bool:
	return winner < 0 and not moved


func awaiting_choice() -> bool:
	return not pending_choice.is_empty()


func can_use_ability(slot: String) -> bool:
	if not can_act() or ability_used:
		return false
	if ability_of(current, slot).is_empty():
		return false
	return int(players[current]["gauge"][slot]) >= 100


func can_play_card(hand_index: int) -> bool:
	if not can_act() or card_played:
		return false
	return hand_index >= 0 and hand_index < players[current]["hand"].size()


# ---------------------------------------------------------------- 주사위

## 게임의 모든 주사위는 여기서만 굴린다.
func roll_dice(count: int) -> Array:
	var rolls: Array = []
	for i in max(count, 0):
		rolls.append(rng.randi_range(1, 6))
	return rolls


## 눈마다 나올 비율을 정한 주사위. weights는 눈 1~6의 비율 6개. 비어 있으면 보통 주사위.
func roll_weighted_dice(count: int, weights: Array) -> Array:
	if weights.size() != 6:
		return roll_dice(count)
	var total := 0
	for weight in weights:
		total += int(weight)
	var rolls: Array = []
	for i in max(count, 0):
		var pick := rng.randi_range(1, max(total, 1))
		var face := 6
		for index in 6:
			pick -= int(weights[index])
			if pick <= 0:
				face = index + 1
				break
		rolls.append(face)
	return rolls


## 이동 주사위 개수에 맞는 눈 비율.
func move_weights_for(count: int) -> Array:
	return move_weights.get("1" if count <= 1 else "2", [])


func _sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total


# ---------------------------------------------------------------- 턴 진행

## 턴을 시작한다. 쉬는 턴이면 false를 돌려주며, 이때는 바로 end_turn()을 부른다.
func begin_turn() -> bool:
	card_played = false
	ability_used = false
	moved = false
	pending_choice = {}
	var player: Dictionary = players[current]

	var remaining: Array = []
	for effect in player["effects"]:
		effect["turns"] = int(effect["turns"]) - 1
		if int(effect["turns"]) > 0:
			remaining.append(effect)
	player["effects"] = remaining

	if int(player["skip"]) > 0:
		player["skip"] = int(player["skip"]) - 1
		say("%s: 이번 턴은 쉽니다." % player["name"])
		moved = true
		return false

	var support: Dictionary = char_of(current, "support")
	var intellect := int(support["intellect"])
	if map_attr == "위인" and support["category"] == "위인":
		intellect += ATTR_BONUS
	_add_gauge(current, 10 + 5 * intellect)
	return true


func use_ability(slot: String) -> bool:
	if not can_use_ability(slot):
		return false
	var ability: Dictionary = ability_of(current, slot)
	players[current]["gauge"][slot] = 0
	ability_used = true
	say("%s: %s의 어빌리티 [%s] 발동" % [
		players[current]["name"], char_of(current, slot)["name"], ability["name"]])
	_apply_effect(ability["effect"], current)
	return true


func play_card(hand_index: int) -> bool:
	if not can_play_card(hand_index):
		return false
	var hand: Array = players[current]["hand"]
	var card: Dictionary = cards[hand[hand_index]]
	hand.remove_at(hand_index)
	card_played = true
	say("%s: 카드 [%s] 사용" % [players[current]["name"], card["name"]])
	_apply_effect(card["effect"], current)
	return true


## 이동 주사위를 굴리고 걸어간다. 갈림길에 닿으면 멈추고 pending_choice를 채운다.
## 길이 다 정해지면 도착한 칸의 효과와 전투까지 처리한다.
func roll_move() -> void:
	if not can_act():
		return
	moved = true
	var player: Dictionary = players[current]
	var mover: Dictionary = char_of(current, "attack")

	var total := 0
	var rolls: Array = []
	var fixed := effect_sum(current, "move_fixed")
	if fixed > 0:
		total = fixed
		say("%s: 이동 %d칸 (고정)" % [player["name"], total])
	else:
		var count: int = max(1, int(mover["move"]) + effect_sum(current, "move_dice"))
		rolls = roll_weighted_dice(count, move_weights_for(count))
		total = _sum(rolls)
		say("%s: 이동 주사위 %s → %d칸" % [player["name"], str(rolls), total])
	var bonus := 0
	if map_attr == "근현대" and mover["category"] == "근현대":
		bonus = ATTR_BONUS
		total += bonus
		say("  맵 속성 보너스로 %d칸 더 이동" % ATTR_BONUS)
	_event({"kind": "move", "player": current, "rolls": rolls, "total": total, "bonus": bonus})

	if _walk(current, total, true):
		_resolve_tile(0)


## 갈림길에서 길을 고른다. option_index는 pending_choice["options"]의 순번이다.
func choose_path(option_index: int) -> bool:
	if pending_choice.is_empty():
		return false
	var options: Array = pending_choice["options"]
	if option_index < 0 or option_index >= options.size():
		return false
	var steps := int(pending_choice["steps"])
	pending_choice = {}
	say("  %s: %s(으)로 갑니다." % [players[current]["name"], route_name(int(options[option_index]))])
	_step(current, int(options[option_index]))
	if _walk(current, steps - 1, true):
		_resolve_tile(0)
	return true


## 갈림길에서 보여 줄 길 이름.
func route_name(id: int) -> String:
	return str(node_of(id).get("route", "%d번 칸 쪽 길" % id))


## AI나 자동 이동이 고르는 길: 골까지 가장 가까운 길. 같으면 앞의 길.
func best_option(options: Array) -> int:
	var best := 0
	for index in options.size():
		if int(dist_to_goal.get(int(options[index]), 999)) < int(dist_to_goal.get(int(options[best]), 999)):
			best = index
	return best


func end_turn() -> void:
	if winner >= 0 or awaiting_choice():
		return
	current = 1 - current
	if current == 0:
		round_number += 1
		if round_number > MAX_ROUNDS:
			_finish_by_position()


func _finish_by_position() -> void:
	var first := distance_of(0)
	var second := distance_of(1)
	if first < second:
		winner = 0
	elif second < first:
		winner = 1
	else:
		winner = 2
	if winner == 2:
		say("%d턴이 끝났습니다. 골까지 거리가 같아 무승부!" % MAX_ROUNDS)
	else:
		say("%d턴이 끝났습니다. 골에 더 가까운 %s 승리!" % [MAX_ROUNDS, players[winner]["name"]])


# ---------------------------------------------------------------- 말 이동

## steps칸 걸어간다. interactive면 갈림길에서 멈추고 false를 돌려준다.
## 자동 이동(전진 칸, 추격)은 갈림길에서 골에 가까운 길을 고른다. 골에 닿으면 남은 칸은 버린다.
func _walk(player_index: int, steps: int, interactive: bool) -> bool:
	var remaining := steps
	while remaining > 0:
		var here: Dictionary = node_of(int(players[player_index]["pos"]))
		if here.get("type", "") == "goal":
			return true
		var options: Array = here.get("next", [])
		if options.is_empty():
			return true
		var chosen := 0
		if options.size() > 1:
			if interactive:
				pending_choice = {"options": options.duplicate(), "steps": remaining}
				return false
			chosen = best_option(options)
		_step(player_index, int(options[chosen]))
		remaining -= 1
	return true


func _step(player_index: int, to: int) -> void:
	var player: Dictionary = players[player_index]
	player["trail"].append(to)
	player["pos"] = to
	_event({"kind": "pos", "player": player_index, "to": to})


## 지나온 길을 따라 steps칸 물러난다.
func _move_back(player_index: int, steps: int) -> void:
	var trail: Array = players[player_index]["trail"]
	for i in steps:
		if trail.size() <= 1:
			return
		trail.pop_back()
		_arrive_back(player_index)


## 지나온 길을 따라 직전 거점까지 돌아간다. 거점 위에 있으면 그 이전 거점으로 간다.
func _return_to_checkpoint(player_index: int) -> void:
	var trail: Array = players[player_index]["trail"]
	if trail.size() <= 1:
		return
	trail.pop_back()
	_arrive_back(player_index)
	while trail.size() > 1 and node_of(int(trail.back())).get("type", "") != "checkpoint":
		trail.pop_back()
		_arrive_back(player_index)


func _arrive_back(player_index: int) -> void:
	var to := int(players[player_index]["trail"].back())
	players[player_index]["pos"] = to
	_event({"kind": "pos", "player": player_index, "to": to})


# ---------------------------------------------------------------- 칸 효과

func _resolve_tile(depth: int) -> void:
	var player: Dictionary = players[current]
	var opponent: Dictionary = players[1 - current]
	var pos := int(player["pos"])

	# 상대가 있는 칸에 도착하면 먼저 대전. 출발 칸과 골에서는 싸우지 않는다.
	var here_type: String = node_of(pos).get("type", "")
	if here_type != "start" and here_type != "goal" and int(opponent["pos"]) == pos:
		if not _battle_players():
			return
		pos = int(player["pos"])

	var tile: Dictionary = node_of(pos)
	if is_hidden(pos):
		revealed[pos] = true
		say("  숨겨진 칸이 드러났습니다!")
	match tile.get("type", ""):
		"attr":
			map_attr = tile["attr"]
			say("  맵 속성이 [%s](으)로 바뀌었습니다." % map_attr)
		"battle":
			if _battle_keeper(int(tile["dice"]), tile["name"]):
				_draw_card(current, true)
		"treasure":
			say("  보물 칸!")
			_draw_card(current, true)
		"forward":
			if depth < 3:
				var amount := int(tile["amount"])
				say("  전진 칸! %d칸 더 나아갑니다." % amount)
				_walk(current, amount, false)
				_resolve_tile(depth + 1)
		"warp":
			var to := int(tile["to"])
			say("  워프! %d번 칸으로 이동합니다." % to)
			_step(current, to)
		"luck":
			_add_gauge(current, 25)
			say("  행운 칸! 게이지 +25%")
		"curse":
			if _consume_charm(current):
				say("  저주 칸이지만 부적이 막아 줬습니다.")
			else:
				player["cursed"] = true
				say("  저주! 다음 전투에서 주사위가 1개 줄어듭니다.")
		"prison":
			if _consume_charm(current):
				say("  감옥 칸이지만 부적이 막아 줬습니다.")
			else:
				player["skip"] = int(player["skip"]) + 1
				say("  감옥! 다음 턴을 쉽니다.")
		"fate":
			_resolve_fate()
		"goal":
			say("  골 앞의 수호자 [%s] 등장!" % tile["name"])
			if _battle_keeper(int(tile["dice"]), tile["name"]):
				winner = current
				say("%s 골인! 승리!" % player["name"])


func _resolve_fate() -> void:
	if _consume_charm(current):
		say("  운명의 판정이지만 부적이 막아 줬습니다.")
		return
	var rolls := roll_dice(2)
	var diff: int = abs(int(rolls[0]) - int(rolls[1]))
	var outcome := "무사 통과"
	if diff >= 3:
		outcome = "직전 거점으로"
	elif diff > 0:
		outcome = "%d칸 후퇴" % diff
	_event({"kind": "fate", "player": current, "rolls": rolls, "text": outcome})
	say("  운명의 판정 %s: %s" % [str(rolls), outcome])
	if diff >= 3:
		_return_to_checkpoint(current)
	elif diff > 0:
		_move_back(current, diff)


# ---------------------------------------------------------------- 전투

## 주사위 전투 한 번. 비기면 다시 굴리고, 10번 연속 비기면 방어 쪽이 이긴다.
func resolve_battle(attack_dice: int, defense_dice: int, attack_bonus: int, defense_bonus: int) -> Dictionary:
	var attack_count: int = clamp(attack_dice, 1, MAX_BATTLE_DICE)
	var defense_count: int = clamp(defense_dice, 1, MAX_BATTLE_DICE)
	var result := {}
	for attempt in 10:
		var attack_rolls := roll_dice(attack_count)
		var defense_rolls := roll_dice(defense_count)
		var attack_total := _sum(attack_rolls) + attack_bonus
		var defense_total := _sum(defense_rolls) + defense_bonus
		result = {
			"attack_rolls": attack_rolls,
			"defense_rolls": defense_rolls,
			"attack_total": attack_total,
			"defense_total": defense_total,
			"attacker_won": attack_total > defense_total,
		}
		if attack_total != defense_total:
			break
	return result


func _attack_dice(player_index: int) -> int:
	var count := int(char_of(player_index, "attack")["attack"])
	count += effect_sum(player_index, "atk_dice")
	count -= effect_sum(1 - player_index, "enemy_dice_minus")
	if players[player_index]["cursed"]:
		count -= 1
		players[player_index]["cursed"] = false
	return count


func _defense_dice(player_index: int) -> int:
	var count := int(char_of(player_index, "defense")["defense"])
	count += effect_sum(player_index, "def_dice")
	count -= effect_sum(1 - player_index, "enemy_dice_minus")
	if players[player_index]["cursed"]:
		count -= 1
		players[player_index]["cursed"] = false
	return count


func _attack_bonus(player_index: int) -> int:
	var bonus := effect_sum(player_index, "atk_bonus")
	if map_attr == "영웅" and char_of(player_index, "attack")["category"] == "영웅":
		bonus += ATTR_BONUS
	return bonus


func _defense_bonus(player_index: int) -> int:
	var bonus := effect_sum(player_index, "def_bonus")
	if map_attr == "신화" and char_of(player_index, "defense")["category"] == "신화":
		bonus += ATTR_BONUS
	return bonus


## 현재 플레이어가 상대를 공격한다. 공격 쪽이 이기면 true.
func _battle_players() -> bool:
	var player: Dictionary = players[current]
	var opponent: Dictionary = players[1 - current]
	var attacker: Dictionary = char_of(current, "attack")
	var defender: Dictionary = char_of(1 - current, "defense")
	say("  전투! %s(공격) vs %s(방어)" % [attacker["name"], defender["name"]])
	var result := resolve_battle(
		_attack_dice(current), _defense_dice(1 - current),
		_attack_bonus(current), _defense_bonus(1 - current))
	_say_battle(result)
	_battle_event(attacker["name"], defender["name"], result)
	if result["attacker_won"]:
		say("  %s 승리! %s은(는) 직전 거점으로 돌아갑니다." % [player["name"], opponent["name"]])
		_return_to_checkpoint(1 - current)
		if effect_sum(current, "chase") > 0:
			say("  추격! %d칸 더 전진합니다." % CHASE_STEPS)
			_walk(current, CHASE_STEPS, false)
		return true
	say("  %s 방어 성공! %s은(는) 직전 거점으로 돌아갑니다." % [opponent["name"], player["name"]])
	_return_to_checkpoint(current)
	if effect_sum(1 - current, "counter") > 0:
		say("  반격! %d칸 더 물러납니다." % COUNTER_STEPS)
		_move_back(current, COUNTER_STEPS)
	return false


## 현재 플레이어가 칸을 지키는 키퍼를 공격한다. 이기면 true.
func _battle_keeper(keeper_dice: int, keeper_name: String) -> bool:
	var player: Dictionary = players[current]
	var attacker: Dictionary = char_of(current, "attack")
	say("  전투! %s vs 키퍼 [%s]" % [attacker["name"], keeper_name])
	var result := resolve_battle(
		_attack_dice(current), keeper_dice - effect_sum(current, "enemy_dice_minus"),
		_attack_bonus(current), 0)
	_say_battle(result)
	_battle_event(attacker["name"], keeper_name, result)
	if result["attacker_won"]:
		say("  %s 승리!" % player["name"])
		return true
	say("  패배... %s은(는) 직전 거점으로 돌아갑니다." % player["name"])
	_return_to_checkpoint(current)
	return false


func _say_battle(result: Dictionary) -> void:
	say("  공격 %s = %d  /  방어 %s = %d" % [
		str(result["attack_rolls"]), int(result["attack_total"]),
		str(result["defense_rolls"]), int(result["defense_total"])])


func _battle_event(attacker_name: String, defender_name: String, result: Dictionary) -> void:
	_event({
		"kind": "battle",
		"player": current,
		"attacker": attacker_name,
		"defender": defender_name,
		"attack_rolls": result["attack_rolls"],
		"defense_rolls": result["defense_rolls"],
		"attack_total": result["attack_total"],
		"defense_total": result["defense_total"],
		"won": result["attacker_won"],
	})


# ---------------------------------------------------------------- 효과

func _apply_effect(effect: Dictionary, player_index: int) -> void:
	var player: Dictionary = players[player_index]
	var opponent_index := 1 - player_index
	var opponent: Dictionary = players[opponent_index]
	var kind: String = effect.get("type", "")
	var amount := int(effect.get("amount", 0))
	var turns := int(effect.get("turns", 1))

	if kind in TIMED_EFFECTS:
		_add_effect(player_index, kind, amount, turns)
		return
	match kind:
		"move_fixed":
			_add_effect(player_index, "move_fixed", amount, 1)
		"gauge_team":
			_add_gauge(player_index, amount)
		"gauge_enemy":
			_add_gauge(opponent_index, amount)
		"draw_card":
			_draw_card(player_index, true)
		"skip_enemy":
			if _consume_charm(opponent_index):
				say("  %s의 부적이 막아 냈습니다." % opponent["name"])
			else:
				opponent["skip"] = int(opponent["skip"]) + amount
		"cure":
			player["cursed"] = false
			player["skip"] = 0
		"charm":
			player["charm"] = true
		"set_attr":
			map_attr = char_of(player_index, "attack")["category"]
			say("  맵 속성이 [%s](으)로 바뀌었습니다." % map_attr)
		_:
			push_warning("알 수 없는 효과: %s" % kind)


func _add_effect(player_index: int, key: String, amount: int, turns: int) -> void:
	players[player_index]["effects"].append({"key": key, "amount": amount, "turns": turns})


func _add_gauge(player_index: int, amount: int) -> void:
	var gauge: Dictionary = players[player_index]["gauge"]
	for slot in SLOTS:
		gauge[slot] = clamp(int(gauge[slot]) + amount, 0, 100)


func _consume_charm(player_index: int) -> bool:
	if players[player_index]["charm"]:
		players[player_index]["charm"] = false
		return true
	return false


func _draw_card(player_index: int, announce: bool) -> void:
	var hand: Array = players[player_index]["hand"]
	if hand.size() >= HAND_LIMIT or cards.is_empty():
		if announce:
			say("  손이 가득 차서 카드를 받지 못했습니다.")
		return
	var ids: Array = cards.keys()
	var card_id: String = ids[rng.randi_range(0, ids.size() - 1)]
	hand.append(card_id)
	if announce:
		say("  %s: 카드 [%s] 획득" % [players[player_index]["name"], cards[card_id]["name"]])


func _event(data: Dictionary) -> void:
	events.append(data)


## 쌓인 사건을 꺼내고 비운다. 화면 쪽에서 부른다.
func take_events() -> Array:
	var taken := events
	events = []
	return taken


func say(text: String) -> void:
	messages.append(text)
	if messages.size() > MAX_MESSAGES:
		messages.pop_front()

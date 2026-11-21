extends RefCounted
## 규칙 엔진. 화면과 무관하게 한 판을 진행한다.
## 주사위는 roll_dice()에서만 굴린다. 7단계에서 이 파일의 로직을 서버로 옮긴다.
##
## 한 턴의 순서:
##   begin_turn() → (play_card / use_ability, 각 1회까지) → roll_move()
##   → (갈림길이나 상대를 지나칠 때 choose_path()로 고르기) → end_turn()
##
## 보드는 칸(node)과 다음 칸(next) 연결로 이뤄진다. next가 2개 이상이면 갈림길이다.
## 말이 지나온 길은 trail에 쌓아 두고, 뒤로 물러날 때는 그 길을 거꾸로 되짚는다.

const SLOTS := ["attack", "defense", "support"]
const SLOT_LABELS := {"attack": "ATTACK", "defense": "DEFENSE", "support": "SUPPORT"}
## 소환 포인트 한도의 기본값. 실제 한도는 플레이어 레벨에 따라 달라진다(point_limit_at).
const POINT_LIMIT := 6
## 턴 제한 기본값. 실제 값은 data/rules.json의 max_rounds.
const MAX_ROUNDS := 50
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
	"move_plus", "move_best", "retry",
	# 2026-11-17 어빌리티 개편으로 더한 지속 효과
	"crit",          # 공격 주사위에 6이 나오면 하나마다 amount 더함
	"atk_floor",     # 공격 주사위 눈이 amount보다 작으면 amount로 올림
	"def_floor",     # 방어 주사위 눈이 amount보다 작으면 amount로 올림
	"move_floor",    # 이동 주사위 눈이 amount보다 작으면 amount로 올림
	"drain",         # 상대 말과 싸워 이기면 상대 게이지를 amount% 빼앗음
	"gauge_boost",   # 턴마다 차는 게이지 amount% 더
	"stand_ground",  # 거점으로 돌아갈 일이 생기면 한 번 막음(쓰면 없어짐)
]

var rng := RandomNumberGenerator.new()
## id → 칸. random 칸은 setup()에서 실제 효과로 바뀐다.
var nodes: Dictionary = {}
var start_id := 0
## id → 가장 가까운 골까지 남은 칸 수
var dist_to_goal: Dictionary = {}
## 숨겨진 칸 중 이미 밟혀서 드러난 칸 id
var revealed: Dictionary = {}
## 갈림길 안쪽 칸(두 갈래 길). 누군가 지나가기 전까지 안개에 가려 칸 종류·적이 보이지 않는다(화면 표시용).
var fog: Dictionary = {}
## 안개가 걷힌 칸(누군가 밟고 지나간 칸)
var fog_open: Dictionary = {}
var branch_fog := true
var cards: Dictionary = {}
var abilities: Dictionary = {}
var characters: Dictionary = {}
## 이동 주사위 눈의 비율. "1"은 주사위 1개일 때, "2"는 2개 이상일 때.
var move_weights: Dictionary = {}
## 주사위 컨트롤: {"chance": 성공 확률(%), "low": 눈 비율, "high": 눈 비율}
var dice_control: Dictionary = {}
## 따라잡기: 상대보다 catchup_gap칸 이상 뒤처진 쪽의 이동 주사위 눈 비율
var catchup_gap := 0
var catchup_weights: Dictionary = {}
## 길잡이 첫 판 행운(2026-11-20): 이 플레이어가 뒤처져 있으면 주사위 큰 눈이 잘 나온다. -1이면 없음.
var lucky_player := -1
var tutorial_luck: Dictionary = {}

var players: Array = []
## 수호자를 쓰러뜨린 말. 거리 판정이면 -1.
var winning_player := -1
var fought_on_move := false
var first_player := 0
var current := 0
var round_number := 1
var map_attr := ""
## -1 진행 중, 0 짝수 팀 승리, 1 홀수 팀 승리, 2 무승부
var winner := -1
var messages: Array = []
## 화면이 연출에 쓰는 사건 기록. take_events()로 가져가면 비워진다.
## kind: "pos"(말이 한 칸 이동), "move"(이동 주사위), "battle"(전투), "fate"(운명의 판정)
var events: Array = []
## 고르기가 필요할 때 채워진다.
##   갈림길: {"kind": "path", "options": [칸 id...], "steps": 남은 칸 수}
##   상대를 지나칠 때: {"kind": "fight", "options": [0 싸운다, 1 지나간다], "steps": 남은 칸 수}
var pending_choice: Dictionary = {}
## 덫이 놓인 칸 id → 덫을 놓은 플레이어
var traps: Dictionary = {}
## 관문(강제 전투 칸): 플레이어마다 이미 뚫은 관문 {칸 번호: true}, 진 횟수 {칸 번호: 횟수}
var gates_cleared: Array = [{}, {}]
var gate_fails: Array = [{}, {}]
## 카드로 세운 문지기(2026-11-19, ★★★ 카드 '분신 문지기'). 칸 번호 → {owner, hero, name, dice, bonus}.
## 주인의 ATTACK 영웅 모습·공격 주사위·레벨 보너스를 그대로 가진다. 주인이 아닌 쪽이 밟으면 멈춰 싸워야 한다.
var wardens: Dictionary = {}
## 관문에서 한 번 질 때마다 그 관문지기의 주사위가 이만큼 줄어든다(끝없이 막히지 않게).
var gate_weaken := 1
## 골의 수호자 주사위가 줄어드는 한계
var goal_min_dice := 3
## 후공 보정으로 둘째 플레이어가 받는 첫 게이지
var second_player_gauge := 0
## 더블(이동 주사위 2개 이상이 모두 같은 눈)이면 차는 어빌리티 게이지(%)
var double_gauge := 0
## 게이지 수치. data/rules.json에서 읽는다.
var gauge_base := 10
var gauge_per_intellect := 5
var start_gauge_per_intellect := 0
## 맵 이름과 색(화면용)
var board_name := ""
var board_shape := ""
## 맵의 특징 한 줄("판정과 보물이 많다")
var board_feature := ""
var board_theme: Dictionary = {}
## 영웅 레벨에 따른 전투 합계 보너스. 칸 순번 = 레벨 - 1. data/rules.json의 level_battle_bonus.
var level_battle_bonus: Array = []
## 영웅 레벨에 따른 스킬 충전 속도 보너스(%). 그 영웅 자리의 게이지만 더 빨리 찬다. data/rules.json의 level_gauge_bonus.
var level_gauge_bonus: Array = []
## 턴 제한
var max_rounds := MAX_ROUNDS

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
	dice_control = data.get("rules", {}).get("dice_control", {})
	catchup_gap = int(data.get("rules", {}).get("catchup_gap", 0))
	catchup_weights = data.get("rules", {}).get("catchup_move_weights", {})
	tutorial_luck = data.get("rules", {}).get("tutorial_luck", {})
	var rules: Dictionary = data.get("rules", {})
	second_player_gauge = int(rules.get("second_player_gauge", 0))
	double_gauge = int(rules.get("double_gauge", 0))
	gate_weaken = int(rules.get("gate_weaken", 1))
	branch_fog = bool(rules.get("branch_fog", true))
	goal_min_dice = int(rules.get("goal_min_dice", 3))
	gauge_base = int(rules.get("gauge_base", 10))
	gauge_per_intellect = int(rules.get("gauge_per_intellect", 5))
	start_gauge_per_intellect = int(rules.get("start_gauge_per_intellect", 0))
	level_battle_bonus = rules.get("level_battle_bonus", [])
	level_gauge_bonus = rules.get("level_gauge_bonus", [])
	max_rounds = int(rules.get("max_rounds", MAX_ROUNDS))
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
			## 자리별 영웅 레벨. 없으면 1.
			"levels": (party.get("levels", {}) as Dictionary).duplicate(),
			"pos": start_id,
			"trail": [start_id],
			"hand": [],
			## 카드 덱(2026-11-18): 이 플레이어는 덱의 카드만 뽑는다. 비어 있으면 모든 카드에서 뽑는다.
			## draw_pile은 섞어 둔 남은 카드. 다 쓰면 덱을 다시 섞는다.
			"deck": _valid_deck(party.get("deck", [])),
			"draw_pile": [],
			"gauge": {"attack": 0, "defense": 0, "support": 0},
			## 게이지가 가득 차서 넘친 양. 100이 모이면 카드 1장이 된다.
			"overflow": 0,
			"skip": 0,
			"effects": [],
			"cursed": false,
			"charm": false,
			## 장착한 유물의 효과 {atk_bonus, turns, gauge, charm}. 없으면 {}.
			"relic": (party.get("relic", {}) as Dictionary).duplicate(),
		})
	first_player = rng.randi_range(0, 1) if is_team_match() else 0
	current = first_player
	round_number = 1
	map_attr = ""
	winner = -1
	winning_player = -1
	fought_on_move = false
	messages = []
	events = []
	pending_choice = {}
	revealed = {}
	_setup_fog()
	traps = {}
	gates_cleared = []
	gate_fails = []
	wardens = {}
	for index in players.size():
		gates_cleared.append({})
		gate_fails.append({})
		for i in START_HAND:
			_draw_card(index, false)
	# 지력이 높은 SUPPORT는 게이지를 채운 채로 시작한다.
	for index in players.size():
		_add_gauge(index, start_gauge_per_intellect * int(char_of(index, "support")["intellect"]))
	# 먼저 하는 쪽이 유리하므로 나중에 하는 쪽은 게이지를 채워 두고 시작한다.
	if players.size() > 1 and second_player_gauge > 0:
		for index in range(1 - first_player, players.size(), 2):
			_add_gauge(index, second_player_gauge)
	# 시너지: 파티 구성 보너스(양쪽 모두)
	for index in players.size():
		var categories: Array = []
		for slot in SLOTS:
			categories.append(str(char_of(index, slot).get("category", "")))
		var bonus: Dictionary = synergy_of(rules.get("synergy", {}), categories)
		if int(bonus.get("gauge", 0)) > 0:
			_add_gauge(index, int(bonus["gauge"]))
		if bool(bonus.get("charm", false)):
			players[index]["charm"] = true
		if not bonus.is_empty():
			say("%s: 시너지 [%s] %s" % [players[index]["name"], bonus.get("name", ""), bonus.get("text", "")])
	# 유물: 시작 보너스
	for index in players.size():
		var relic: Dictionary = players[index]["relic"]
		if int(relic.get("atk_bonus", 0)) > 0:
			players[index]["effects"].append({"key": "atk_bonus", "amount": int(relic["atk_bonus"]), "turns": int(relic.get("turns", 1))})
		if int(relic.get("gauge", 0)) > 0:
			_add_gauge(index, int(relic["gauge"]))
		if bool(relic.get("charm", false)):
			players[index]["charm"] = true
		if not relic.is_empty():
			say("%s: 유물의 힘을 받고 시작합니다." % players[index]["name"])
	say("게임 시작! 먼저 골에 들어가면 승리합니다.")


func _load_board(board: Dictionary) -> void:
	board_name = str(board.get("name", ""))
	board_feature = str(board.get("feature", ""))
	board_shape = str(board.get("shape", ""))
	board_theme = board.get("theme", {})
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


## 갈림길에서 갈라진 두 길의 칸을 안개 칸으로 정한다: 갈림길(다음 칸이 2개 이상)의 각 갈래를 따라가다
## 여러 길이 다시 모이는 칸(들어오는 길이 2개 이상) 바로 앞까지.
func _setup_fog() -> void:
	fog = {}
	fog_open = {}
	if not branch_fog:
		return
	var incoming := {}
	for id in nodes:
		for next_id in nodes[id].get("next", []):
			incoming[int(next_id)] = int(incoming.get(int(next_id), 0)) + 1
	for id in nodes:
		var options: Array = nodes[id].get("next", [])
		if options.size() < 2:
			continue
		for option in options:
			var walk := int(option)
			var guard := 0
			while nodes.has(walk) and int(incoming.get(walk, 0)) < 2 and guard < 200:
				if str(nodes[walk].get("type", "")) in ["goal", "gate", "start"]:
					break
				fog[walk] = true
				var after: Array = nodes[walk].get("next", [])
				if after.size() != 1:
					break
				walk = int(after[0])
				guard += 1


## 안개에 가려진 칸인가(아직 아무도 지나가지 않은 갈림길 안쪽 칸)
func is_fogged(id: int) -> bool:
	return fog.has(id) and not fog_open.has(id)


func is_hidden(id: int) -> bool:
	return bool(node_of(id).get("hidden", false)) and not revealed.has(id)


func char_of(player_index: int, slot: String) -> Dictionary:
	return characters[players[player_index]["slots"][slot]]


func ability_of(player_index: int, slot: String) -> Dictionary:
	return abilities.get(char_of(player_index, slot).get("ability", ""), {})


## 플레이어 레벨에 따른 소환 포인트 한도(data/rules.json의 point_limits: 그 레벨부터 그 한도).
static func point_limit_at(rules: Dictionary, level: int) -> int:
	var limit := POINT_LIMIT
	var best_level := -1
	for step in rules.get("point_limits", []):
		var from_level := int(step.get("level", 1))
		if level >= from_level and from_level > best_level:
			best_level = from_level
			limit = int(step.get("limit", POINT_LIMIT))
	return limit


## 한도가 다음에 늘어나는 단계({"level", "limit"}). 더 없으면 빈 사전.
static func next_point_step(rules: Dictionary, level: int) -> Dictionary:
	var found := {}
	for step in rules.get("point_limits", []):
		var from_level := int(step.get("level", 1))
		if from_level > level and (found.is_empty() or from_level < int(found["level"])):
			found = step
	return found


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


## 같은 종류 지속 효과 중 가장 큰 값(최소 눈처럼 더하면 안 되는 것).
func effect_max(player_index: int, key: String) -> int:
	var best := 0
	for effect in players[player_index]["effects"]:
		if effect["key"] == key:
			best = maxi(best, int(effect["amount"]))
	return best


func can_act() -> bool:
	return winner < 0 and not moved


func awaiting_choice() -> bool:
	return not pending_choice.is_empty()


## 지금 고르기의 종류. "path" 또는 "fight". 고를 게 없으면 "".
func choice_kind() -> String:
	if pending_choice.is_empty():
		return ""
	return str(pending_choice.get("kind", "path"))


## 고르기 버튼에 쓸 이름.
func choice_label(option_index: int) -> String:
	if choice_kind() == "target":
		return str(players[int(pending_choice["options"][option_index])]["name"])
	if choice_kind() == "fight":
		return "싸운다" if option_index == 0 else "지나간다"
	return route_name(int(pending_choice["options"][option_index]))


## 각 갈래의 첫 칸부터 다시 만나는 칸까지. 만나는 곳이 없으면 다음 선택이나 길의 끝에서 멈춘다.
func choice_routes() -> Dictionary:
	if choice_kind() != "path":
		return {}
	var fork := int(players[current]["pos"])
	var paths: Array = []
	for option in pending_choice["options"]:
		var path: Array[int] = []
		var id := int(option)
		while id != fork and nodes.has(id) and id not in path:
			path.append(id)
			var tile: Dictionary = nodes[id]
			var next: Array = tile["next"]
			if next.size() != 1 or tile["type"] == "goal":
				break
			id = int(next[0])
		paths.append(path)
	for id in paths[0]:
		if paths.all(func(path): return id in path):
			for path in paths:
				path.resize(path.find(id) + 1)
			return {"paths": paths, "joined": true}
	return {"paths": paths, "joined": false}


func can_use_ability(slot: String) -> bool:
	if not can_act() or ability_used:
		return false
	if effect_sum(current, "sealed") > 0:
		return false
	if ability_of(current, slot).is_empty():
		return false
	return int(players[current]["gauge"][slot]) >= 100


func can_play_card(hand_index: int) -> bool:
	if not can_act() or card_played:
		return false
	if effect_sum(current, "card_sealed") > 0:
		return false
	if hand_index < 0 or hand_index >= players[current]["hand"].size():
		return false
	return card_condition_met(cards[players[current]["hand"][hand_index]])


## 카드에 붙은 사용 조건을 지금 만족하는지. 조건이 없는 카드는 늘 true.
## "comeback"(역전의 첫걸음): 상대보다 gap칸 이상 뒤처져 있어야 한다(골까지 남은 거리 기준).
func card_condition_met(card: Dictionary) -> bool:
	var effect: Dictionary = card.get("effect", {})
	if str(effect.get("type", "")) == "comeback":
		return behind_by(current) >= int(effect.get("gap", 10))
	return true


## player_index가 상대보다 뒤처진 칸 수. 앞서 있으면 음수.
func is_team_match() -> bool:
	return players.size() == 4


## 방해 카드는 골에 가장 가까운 적에게 적용한다. 같은 거리면 앞 순번이 대상이다.
func leading_enemy(player_index: int) -> int:
	var leader := 1 - player_index % 2
	for index in range(leader + 2, players.size(), 2):
		if distance_of(index) < distance_of(leader):
			leader = index
	return leader


func enemies_here(player_index: int) -> Array:
	var enemies := []
	for index in range(1 - player_index % 2, players.size(), 2):
		if players[index]["pos"] == players[player_index]["pos"]:
			enemies.append(index)
	return enemies


func behind_by(player_index: int) -> int:
	return distance_of(player_index) - distance_of(leading_enemy(player_index))


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
## catching_up이 true면(많이 뒤처진 쪽) 큰 눈이 더 잘 나오는 비율을 쓴다.
func move_weights_for(count: int, catching_up: bool = false) -> Array:
	var key := "1" if count <= 1 else "2"
	if catching_up and catchup_weights.has(key):
		return catchup_weights[key]
	return move_weights.get(key, [])


## 주사위 컨트롤이 이번에 성공하는지(확률). 규칙의 난수로 정한다.
func _control_succeeds() -> bool:
	var chance := int(dice_control.get("chance", 0))
	return chance > 0 and rng.randi_range(1, 100) <= chance


## 길잡이 첫 판 행운: 이 플레이어가 행운 대상이고 상대보다 골에서 멀리 있으면 true.
func is_lucky(player_index: int) -> bool:
	return lucky_player >= 0 and player_index == lucky_player and behind_by(player_index) > 0


## 따라잡기: player_index가 상대보다 catchup_gap칸 이상 뒤처져 있는지. (catchup_gap이 0이면 쓰지 않는다)
func is_catching_up(player_index: int) -> bool:
	return catchup_gap > 0 and behind_by(player_index) >= catchup_gap


func _sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total


# ---------------------------------------------------------------- 턴 진행

## 턴을 시작한다. 쉬는 턴이면 false를 돌려주며, 이때는 바로 end_turn()을 부른다.
func begin_turn() -> bool:
	fought_on_move = false
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
	var gain := gauge_base + gauge_per_intellect * intellect
	var boost := effect_sum(current, "gauge_boost")
	if boost > 0:
		gain += int(gain * boost / 100.0)
	_gain_turn_gauge(current, gain)
	return true


func use_ability(slot: String) -> bool:
	if not can_use_ability(slot):
		return false
	var ability: Dictionary = ability_of(current, slot)
	ability_used = true
	say("%s: %s의 어빌리티 [%s] 발동" % [
		players[current]["name"], char_of(current, slot)["name"], ability["name"]])
	# 화면이 "누가 어떤 어빌리티를 썼는지" 보여 줄 수 있게 사건으로 남긴다.
	_event({"kind": "ability", "player": current, "slot": slot, "hero": str(char_of(current, slot)["name"]),
		"name": str(ability["name"]), "text": str(ability.get("text", ""))})
	_apply_effect(ability["effect"], current)
	# 효과를 먼저 걸고 나서 쓴 자리 게이지를 비운다. 우리 팀 게이지를 채우거나 빼앗는 어빌리티가
	# 방금 쓴 자기 게이지까지 다시 채우지 않게(2026-11-18 전수 검사에서 찾음).
	players[current]["gauge"][slot] = 0
	return true


func play_card(hand_index: int) -> bool:
	if not can_play_card(hand_index):
		return false
	var hand: Array = players[current]["hand"]
	var card_id := str(hand[hand_index])
	var card: Dictionary = cards[card_id]
	hand.remove_at(hand_index)
	card_played = true
	say("%s: 카드 [%s] 사용" % [players[current]["name"], card["name"]])
	_event({"kind": "card", "player": current, "id": card_id, "name": str(card["name"]), "text": str(card.get("text", ""))})
	_apply_effect(card["effect"], current)
	return true


## 이동 주사위를 굴리고 걸어간다. 갈림길에 닿으면 멈추고 pending_choice를 채운다.
## 길이 다 정해지면 도착한 칸의 효과와 전투까지 처리한다.
## aim: 주사위 컨트롤로 노리는 쪽. ""(그냥 굴림), "low"(낮게), "high"(높게).
## 노리면 dice_control.chance% 확률로 성공해 그쪽 눈이 잘 나온다. 실패하면 보통 굴림과 같다.
## 세 영웅의 분류로 시너지를 정한다. table은 data/rules.json의 synergy. 없으면 {}.
static func synergy_of(table: Dictionary, categories: Array) -> Dictionary:
	if categories.size() != 3 or categories.has(""):
		return {}
	if categories[0] == categories[1] and categories[1] == categories[2]:
		return table.get("same", {})
	if categories[0] != categories[1] and categories[1] != categories[2] and categories[0] != categories[2]:
		return table.get("different", {})
	return {}


## 더블인가: 주사위가 2개 이상이고 눈이 모두 같다.
static func is_double(rolls: Array) -> bool:
	if rolls.size() < 2:
		return false
	for value in rolls:
		if int(value) != int(rolls[0]):
			return false
	return true


func roll_move(aim: String = "") -> void:
	if not can_act():
		return
	moved = true
	var player: Dictionary = players[current]
	var mover: Dictionary = char_of(current, "attack")

	var total := 0
	var rolls: Array = []
	var catching_up := false
	var controlled := false
	var fixed := effect_sum(current, "move_fixed")
	if fixed > 0:
		total = fixed
		say("%s: 이동 %d칸 (고정)" % [player["name"], total])
	else:
		var count: int = max(1, int(mover["move"]) + effect_sum(current, "move_dice"))
		# 따라잡기: 많이 뒤처진 쪽은 큰 눈이 더 잘 나온다.
		catching_up = is_catching_up(current)
		if catching_up:
			say("  따라잡기! %d칸 이상 뒤처져 있어 큰 눈이 잘 나옵니다." % catchup_gap)
		var weights: Array = move_weights_for(count, catching_up)
		if aim == "low" or aim == "high":
			controlled = _control_succeeds()
			if controlled:
				var table: Dictionary = dice_control.get(aim, {})
				weights = table.get("1" if count <= 1 else "2", weights)
				say("  주사위 컨트롤 성공! %s 눈이 잘 나옵니다." % ("낮은" if aim == "low" else "높은"))
			else:
				say("  주사위 컨트롤 실패. 보통으로 굴립니다.")
		if is_lucky(current):
			weights = tutorial_luck.get("move", {}).get("1" if count <= 1 else "2", weights)
		rolls = roll_weighted_dice(count, weights)
		if effect_sum(current, "move_best") > 0:
			var again := roll_weighted_dice(count, weights)
			say("  길잡이 별: %s와 %s 중 큰 쪽" % [str(rolls), str(again)])
			if _sum(again) > _sum(rolls):
				rolls = again
		var move_floor := effect_max(current, "move_floor")
		if move_floor > 0:
			rolls = _raise_floor(rolls, move_floor)
		total = _sum(rolls)
		say("%s: 이동 주사위 %s → %d칸" % [player["name"], str(rolls), total])
	var bonus := effect_sum(current, "move_plus")
	if bonus > 0:
		total += bonus
		say("  %d칸 더 이동" % bonus)
	if map_attr == "근현대" and mover["category"] == "근현대":
		bonus += ATTR_BONUS
		total += ATTR_BONUS
		say("  맵 속성 보너스로 %d칸 더 이동" % ATTR_BONUS)
	var doubled := is_double(rolls) and double_gauge > 0
	if doubled:
		_add_gauge(current, double_gauge)
		say("  더블! 어빌리티 게이지 +%d%%" % double_gauge)
	_event({"kind": "move", "player": current, "rolls": rolls, "total": total, "bonus": bonus, "catchup": catching_up,
		"aim": aim if not rolls.is_empty() else "", "controlled": controlled, "double": doubled})

	_continue_walk(total)


## 고르기에 답한다. option_index는 pending_choice["options"]의 순번이다.
## 갈림길이면 그 길로 가고, 상대를 지나칠 때면 0은 싸우기, 1은 그냥 지나가기다.
func choose_path(option_index: int) -> bool:
	if pending_choice.is_empty():
		return false
	var options: Array = pending_choice["options"]
	if option_index < 0 or option_index >= options.size():
		return false
	var kind := choice_kind()
	var steps := int(pending_choice["steps"])
	var depth := int(pending_choice.get("depth", 0))
	pending_choice = {}
	if kind == "target":
		if _battle_players(int(options[option_index])):
			if steps > 0:
				_continue_walk(steps)
			else:
				_resolve_tile(depth)
		return true
	if kind == "fight":
		if option_index == 1:
			say("  %s: 싸우지 않고 지나갑니다." % players[current]["name"])
			_continue_walk(steps)
		elif _choose_enemy(steps):
			return true
		elif _battle_players():
			# 이기면 남은 칸을 마저 간다. 지면 거점으로 돌아가 이동이 끝난다.
			_continue_walk(steps)
		return true
	say("  %s: %s(으)로 갑니다." % [players[current]["name"], route_name(int(options[option_index]))])
	_step(current, int(options[option_index]))
	if steps - 1 > 0 and _can_fight_passing(current):
		pending_choice = {"kind": "fight", "options": [0, 1], "steps": steps - 1}
		return true
	_continue_walk(steps - 1)
	return true


## 남은 칸을 걸어가고, 길이 다 정해지면 도착한 칸을 처리한다.
func _choose_enemy(steps: int, depth: int = 0) -> bool:
	var targets := enemies_here(current)
	if targets.size() < 2:
		return false
	pending_choice = {"kind": "target", "options": targets, "steps": steps, "depth": depth}
	return true


func _continue_walk(steps: int) -> void:
	if _walk(current, steps, true):
		_resolve_tile(0)


## 지나가는 칸에 상대가 있어서 싸울 수 있는지. 출발 칸과 골에서는 싸우지 않는다.
func _can_fight_passing(player_index: int) -> bool:
	var pos := int(players[player_index]["pos"])
	if (is_team_match() and fought_on_move) or enemies_here(player_index).is_empty():
		return false
	var kind: String = node_of(pos).get("type", "")
	return kind != "start" and kind != "goal"


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
	current = (current + 1) % players.size()
	if current == first_player:
		round_number += 1
		if round_number > max_rounds:
			_finish_by_position()


func _finish_by_position() -> void:
	var blue := [distance_of(0)]
	var red := [distance_of(1)]
	if is_team_match():
		blue.append(distance_of(2))
		red.append(distance_of(3))
	blue.sort()
	red.sort()
	winner = 2
	for index in blue.size():
		if blue[index] != red[index]:
			winner = 0 if blue[index] < red[index] else 1
			break
	if winner == 2:
		say("%d턴이 끝났습니다. 골까지 거리가 같아 무승부!" % max_rounds)
	else:
		say("%d턴이 끝났습니다. 골에 더 가까운 %s 승리!" % [max_rounds, players[winner]["name"]])


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
				pending_choice = {"kind": "path", "options": options.duplicate(), "steps": remaining}
				return false
			chosen = best_option(options)
		_step(player_index, int(options[chosen]))
		remaining -= 1
		# 관문: 아직 뚫지 못했으면 지나갈 수 없다. 여기서 멈추고 싸운다(남은 칸은 버린다).
		if gate_blocks(player_index, int(players[player_index]["pos"])):
			return true
		# 상대가 세운 문지기: 멈춰서 싸운다. 저절로 가는 이동(추격·날기)이면 바로 싸운다.
		if warden_blocks(player_index, int(players[player_index]["pos"])):
			if not interactive and player_index == current:
				_battle_warden(int(players[player_index]["pos"]))
			return true
		# 가는 길에 상대를 지나치면 싸울지 고른다. 마지막 칸이면 도착해서 싸운다.
		if interactive and remaining > 0 and _can_fight_passing(player_index):
			pending_choice = {"kind": "fight", "options": [0, 1], "steps": remaining}
			return false
	return true


## 이 칸에 이 플레이어를 막는(상대가 세운) 문지기가 있는가
func warden_blocks(player_index: int, pos: int) -> bool:
	return wardens.has(pos) and int(wardens[pos]["owner"]) % 2 != player_index % 2


## 문지기를 세울 칸: 상대 앞으로 amount칸(골에 가까운 길). 출발·골·관문·다른 문지기 칸은 피해 한 칸씩 당긴다.
func warden_spot(owner_index: int, amount: int) -> int:
	var target_index := leading_enemy(owner_index)
	var pos := int(players[target_index]["pos"])
	var path: Array = []
	for i in amount:
		var options: Array = node_of(pos).get("next", [])
		if options.is_empty() or str(node_of(pos).get("type", "")) == "goal":
			break
		pos = int(options[best_option(options)] if options.size() > 1 else options[0])
		path.append(pos)
	for index in range(path.size() - 1, -1, -1):
		var spot := int(path[index])
		var kind := str(node_of(spot).get("type", ""))
		if kind in ["start", "goal", "gate"]:
			continue
		if wardens.has(spot) and int(wardens[spot]["owner"]) != owner_index:
			continue
		return spot
	return -1


## 문지기 주사위와 보너스: 주인 ATTACK 영웅의 공격 주사위·레벨 보너스, 맵 속성이 영웅이고 영웅 분류면 +2.
func warden_power(pos: int) -> Dictionary:
	var warden: Dictionary = wardens[pos]
	var hero: Dictionary = characters.get(str(warden["hero"]), {})
	var bonus := int(warden["bonus"])
	if map_attr == "영웅" and str(hero.get("category", "")) == "영웅":
		bonus += ATTR_BONUS
	return {"dice": maxi(1, int(warden["dice"])), "bonus": bonus}


## 현재 플레이어가 문지기를 공격한다. 이기면 문지기가 사라지고 true. 지면 거점으로, 문지기 주사위 1개 줄어듦.
func _battle_warden(pos: int) -> bool:
	var player: Dictionary = players[current]
	var warden: Dictionary = wardens[pos]
	var attacker: Dictionary = char_of(current, "attack")
	var power := warden_power(pos)
	say("  문지기 [%s]이(가) 길을 막습니다!" % warden["name"])
	var attack_dice := _attack_dice(current)
	var defense_dice := int(power["dice"]) - effect_sum(current, "enemy_dice_minus")
	var attack_mods := _attack_mods(current)
	var result := resolve_battle(attack_dice, defense_dice, _attack_bonus(current), int(power["bonus"]), attack_mods)
	if not result["attacker_won"] and _consume_effect(current, "retry"):
		_say_battle(result)
		say("  재도전! 한 번 더 굴립니다.")
		result = resolve_battle(attack_dice, defense_dice, _attack_bonus(current), int(power["bonus"]), attack_mods)
	_say_battle(result)
	_battle_event(attacker["name"], str(warden["name"]), result, "warden", int(warden["owner"]))
	if result["attacker_won"]:
		wardens.erase(pos)
		say("  %s 승리! 문지기가 사라졌습니다." % player["name"])
		_event({"kind": "warden", "player": int(warden["owner"]), "pos": pos, "hero": str(warden["hero"]), "gone": true})
		_chase_after_win()
		return true
	warden["dice"] = maxi(1, int(warden["dice"]) - gate_weaken)
	say("  패배... %s은(는) 직전 거점으로 돌아갑니다." % player["name"])
	_return_to_checkpoint(current)
	return false


## 이 플레이어가 아직 뚫지 못한 관문인가
func gate_blocks(player_index: int, pos: int) -> bool:
	return str(node_of(pos).get("type", "")) == "gate" and not gates_cleared[player_index].has(pos)


## 이 플레이어가 그 관문에서 상대할 주사위 수. 질 때마다 줄고 1개 밑으로는 안 내려간다.
func gate_dice_for(player_index: int, pos: int) -> int:
	return maxi(1, int(node_of(pos).get("dice", 1)) - gate_weaken * int(gate_fails[player_index].get(pos, 0)))


func _step(player_index: int, to: int) -> void:
	var player: Dictionary = players[player_index]
	player["trail"].append(to)
	player["pos"] = to
	# 밟고 지나간 갈림길 칸은 안개가 걷힌다.
	if fog.has(to):
		fog_open[to] = true
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
	if _consume_effect(player_index, "stand_ground"):
		say("  %s: 버텨 냈습니다! 거점으로 돌아가지 않습니다." % players[player_index]["name"])
		_event({"kind": "stand_ground", "player": player_index})
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
	var pos := int(player["pos"])

	# 상대가 있는 칸에 도착하면 먼저 대전. 출발 칸과 골에서는 싸우지 않는다.
	if _can_fight_passing(current):
		if _choose_enemy(0, depth):
			return
		if not _battle_players():
			return
		pos = int(player["pos"])

	if warden_blocks(current, pos):
		if not _battle_warden(pos):
			return
		pos = int(player["pos"])

	if traps.has(pos) and int(traps[pos]) % 2 != current % 2:
		traps.erase(pos)
		if _consume_charm(current):
			say("  덫이 있었지만 부적이 막아 줬습니다.")
		else:
			player["skip"] = int(player["skip"]) + 1
			say("  덫에 걸렸습니다! 다음 턴을 쉽니다.")
			_tile_event("prison", "덫! 다음 턴 쉬기", false)

	var tile: Dictionary = node_of(pos)
	if is_hidden(pos):
		revealed[pos] = true
		say("  숨겨진 칸이 드러났습니다!")
	match tile.get("type", ""):
		"attr":
			map_attr = tile["attr"]
			say("  맵 속성이 [%s](으)로 바뀌었습니다." % map_attr)
			_tile_event("attr", "맵 속성: %s" % map_attr, true)
		"battle":
			if _battle_keeper(int(tile["dice"]), tile["name"]):
				_draw_card(current, true)
		"gate":
			if gate_blocks(current, pos):
				var gate_dice := gate_dice_for(current, pos)
				say("  관문! [%s]을(를) 이겨야 지나갈 수 있습니다." % tile["name"])
				_tile_event("battle", "관문! 강제 전투", false)
				if _battle_keeper(gate_dice, tile["name"]):
					gates_cleared[current][pos] = true
					say("  관문을 뚫었습니다! 이제 이 관문은 그냥 지나갑니다.")
					_draw_card(current, true)
				else:
					gate_fails[current][pos] = int(gate_fails[current].get(pos, 0)) + 1
					say("  관문지기가 지쳤습니다. 다음에는 주사위가 줄어듭니다.")
		"ambush":
			say("  습격! [%s]이(가) 덤벼듭니다." % tile["name"])
			if _battle_ambush(int(tile["dice"]), tile["name"]):
				_draw_card(current, true)
		"treasure":
			say("  보물 칸!")
			_tile_event("treasure", "보물! 카드 획득", true)
			_draw_card(current, true)
		"forward":
			# 전진으로 날아가 내린 칸이 또 전진 칸이어도 다시 날아가지 않는다(연달아 이동 금지, 2026-11-19).
			# 맵 만들 때도 전진 칸끼리 5칸 안에 두지 않지만(tools/make_maps.py), 무작위 칸이 전진이 될 수 있어 규칙에서도 막는다.
			if depth == 0:
				var amount := int(tile["amount"])
				say("  전진 칸! %d칸 더 나아갑니다." % amount)
				_tile_event("forward", "전진! %d칸 더" % amount, true)
				_walk(current, amount, false)
				_resolve_tile(depth + 1)
			else:
				say("  전진 칸이지만 연달아 나아가지는 않습니다.")
		"warp":
			var to := int(tile["to"])
			say("  워프! %d번 칸으로 이동합니다." % to)
			_tile_event("warp", "워프!", true)
			_step(current, to)
		"luck":
			_add_gauge(current, 25)
			say("  행운 칸! 게이지 +25%")
			_tile_event("luck", "행운! 게이지 +25%", true)
		"curse":
			if _consume_charm(current):
				say("  저주 칸이지만 부적이 막아 줬습니다.")
			else:
				player["cursed"] = true
				say("  저주! 다음 전투에서 주사위가 1개 줄어듭니다.")
				_tile_event("curse", "저주! 다음 전투 주사위 -1", false)
		"prison":
			if _consume_charm(current):
				say("  감옥 칸이지만 부적이 막아 줬습니다.")
			else:
				player["skip"] = int(player["skip"]) + 1
				say("  감옥! 다음 턴을 쉽니다.")
				_tile_event("prison", "감옥! 다음 턴 쉬기", false)
		"fate":
			_resolve_fate()
		"goal":
			say("  골 앞의 수호자 [%s] 등장!" % tile["name"])
			# 수호자도 질 때마다 조금씩 지친다(goal_min_dice개 밑으로는 안 내려간다).
			var goal_dice := maxi(mini(goal_min_dice, int(tile["dice"])), int(tile["dice"]) - gate_weaken * int(gate_fails[current].get(pos, 0)))
			if _battle_keeper(goal_dice, tile["name"]):
				winning_player = current
				winner = current % 2
				say("%s 골인! 승리!" % player["name"])
			else:
				gate_fails[current][pos] = int(gate_fails[current].get(pos, 0)) + 1
				say("  수호자가 조금 지쳤습니다.")


## 화면에 크게 알릴 칸 효과. good이면 좋은 일(밝은 색), 아니면 나쁜 일.
func _tile_event(kind: String, text: String, good: bool) -> void:
	_event({"kind": "tile", "player": current, "tile": kind, "text": text, "good": good})


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
## 주사위 count개 합의 분포. 결과[합] = 경우의 수 (주사위를 굴리지 않고 셈만 한다)
static func sum_distribution(count: int) -> Array:
	var ways: Array = [1]
	for die in count:
		var next: Array = []
		next.resize(ways.size() + 6)
		next.fill(0)
		for total in ways.size():
			for face in range(1, 7):
				next[total + face] += int(ways[total])
		ways = next
	return ways


## 공격 쪽이 이길 확률(0~1). 비기면 다시 굴리므로 비긴 경우는 빼고 센다.
static func win_chance(attack_dice: int, defense_dice: int, attack_bonus: int, defense_bonus: int) -> float:
	var attack: Array = sum_distribution(clampi(attack_dice, 1, MAX_BATTLE_DICE))
	var defense: Array = sum_distribution(clampi(defense_dice, 1, MAX_BATTLE_DICE))
	var wins := 0.0
	var losses := 0.0
	for a in attack.size():
		for d in defense.size():
			var ways := float(int(attack[a]) * int(defense[d]))
			if a + attack_bonus > d + defense_bonus:
				wins += ways
			elif a + attack_bonus < d + defense_bonus:
				losses += ways
	if wins + losses <= 0.0:
		return 0.5
	return wins / (wins + losses)


## attack_mods·defense_mods: 어빌리티가 바꾸는 굴림. {"floor": 최소 눈, "six": 6 하나마다 더할 값}
func resolve_battle(attack_dice: int, defense_dice: int, attack_bonus: int, defense_bonus: int,
		attack_mods: Dictionary = {}, defense_mods: Dictionary = {}) -> Dictionary:
	var attack_count: int = clamp(attack_dice, 1, MAX_BATTLE_DICE)
	var defense_count: int = clamp(defense_dice, 1, MAX_BATTLE_DICE)
	var result := {}
	for attempt in 10:
		var attack_rolls := _raise_floor(_battle_roll(attack_count, attack_mods), int(attack_mods.get("floor", 0)))
		var defense_rolls := _raise_floor(_battle_roll(defense_count, defense_mods), int(defense_mods.get("floor", 0)))
		var attack_total := _sum(attack_rolls) + attack_bonus + _six_bonus(attack_rolls, int(attack_mods.get("six", 0)))
		var defense_total := _sum(defense_rolls) + defense_bonus + _six_bonus(defense_rolls, int(defense_mods.get("six", 0)))
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


## 주사위 눈을 floor 밑으로는 안 내려가게 올린다.
static func _raise_floor(rolls: Array, floor_value: int) -> Array:
	if floor_value <= 1:
		return rolls
	var raised: Array = []
	for value in rolls:
		raised.append(maxi(int(value), mini(floor_value, 6)))
	return raised


static func _six_bonus(rolls: Array, per_six: int) -> int:
	if per_six <= 0:
		return 0
	return rolls.count(6) * per_six


## 이 플레이어가 공격할 때 굴림을 바꾸는 효과
func _attack_mods(player_index: int) -> Dictionary:
	return {"floor": effect_max(player_index, "atk_floor"), "six": effect_sum(player_index, "crit"), "lucky": is_lucky(player_index)}


## 이 플레이어가 막을 때 굴림을 바꾸는 효과
func _defense_mods(player_index: int) -> Dictionary:
	return {"floor": effect_max(player_index, "def_floor"), "lucky": is_lucky(player_index)}


## 전투 주사위: 길잡이 첫 판 행운이면 큰 눈이 잘 나오는 비율로 굴린다.
func _battle_roll(count: int, mods: Dictionary) -> Array:
	if bool(mods.get("lucky", false)):
		return roll_weighted_dice(count, tutorial_luck.get("battle", []))
	return roll_dice(count)


func _attack_dice(player_index: int, opponent: int = -1) -> int:
	var count := int(char_of(player_index, "attack")["attack"])
	count += effect_sum(player_index, "atk_dice")
	count -= effect_sum(leading_enemy(player_index) if opponent < 0 else opponent, "enemy_dice_minus")
	if players[player_index]["cursed"]:
		count -= 1
		players[player_index]["cursed"] = false
	return count


func _defense_dice(player_index: int, opponent: int = -1) -> int:
	var count := int(char_of(player_index, "defense")["defense"])
	count += effect_sum(player_index, "def_dice")
	count -= effect_sum(leading_enemy(player_index) if opponent < 0 else opponent, "enemy_dice_minus")
	if players[player_index]["cursed"]:
		count -= 1
		players[player_index]["cursed"] = false
	return count


## 자리의 영웅 레벨 보너스. 레벨 2면 +1처럼 전투 합계에 더한다.
func level_bonus(player_index: int, slot: String) -> int:
	var level := int(players[player_index].get("levels", {}).get(slot, 1))
	if level_battle_bonus.is_empty():
		return 0
	var index := clampi(level - 1, 0, level_battle_bonus.size() - 1)
	return int(level_battle_bonus[index])


## 자리의 영웅 레벨에 따른 스킬 충전 속도 보너스(%). 레벨 3이면 +20%처럼 턴마다 차는 양에 곱해 더한다.
func level_gauge_percent(player_index: int, slot: String) -> int:
	if level_gauge_bonus.is_empty():
		return 0
	var level := int(players[player_index].get("levels", {}).get(slot, 1))
	return int(level_gauge_bonus[clampi(level - 1, 0, level_gauge_bonus.size() - 1)])


func _attack_bonus(player_index: int) -> int:
	var bonus := effect_sum(player_index, "atk_bonus") + level_bonus(player_index, "attack")
	if map_attr == "영웅" and char_of(player_index, "attack")["category"] == "영웅":
		bonus += ATTR_BONUS
	return bonus


func _defense_bonus(player_index: int) -> int:
	var bonus := effect_sum(player_index, "def_bonus") + level_bonus(player_index, "defense")
	if map_attr == "신화" and char_of(player_index, "defense")["category"] == "신화":
		bonus += ATTR_BONUS
	return bonus


## 현재 플레이어가 상대를 공격한다. 공격 쪽이 이기면 true.
func _battle_players(target: int = -1) -> bool:
	if target < 0:
		target = int(enemies_here(current)[0])
	fought_on_move = true
	var player: Dictionary = players[current]
	var opponent: Dictionary = players[target]
	var attacker: Dictionary = char_of(current, "attack")
	var defender: Dictionary = char_of(target, "defense")
	say("  전투! %s(공격) vs %s(방어)" % [attacker["name"], defender["name"]])
	var attack_dice := _attack_dice(current, target)
	var defense_dice := _defense_dice(target, current)
	var attack_mods := _attack_mods(current)
	var defense_mods := _defense_mods(target)
	var result := resolve_battle(
		attack_dice, defense_dice, _attack_bonus(current), _defense_bonus(target), attack_mods, defense_mods)
	if not result["attacker_won"] and _consume_effect(current, "retry"):
		_say_battle(result)
		say("  재도전! 한 번 더 굴립니다.")
		result = resolve_battle(
			attack_dice, defense_dice, _attack_bonus(current), _defense_bonus(target), attack_mods, defense_mods)
	_say_battle(result)
	_battle_event(attacker["name"], defender["name"], result, "player", target)
	_drain_after_battle(current if result["attacker_won"] else target, target if result["attacker_won"] else current)
	if result["attacker_won"]:
		say("  %s 승리! %s은(는) 직전 거점으로 돌아갑니다." % [player["name"], opponent["name"]])
		_return_to_checkpoint(target)
		_chase_after_win()
		return true
	say("  %s 방어 성공! %s은(는) 직전 거점으로 돌아갑니다." % [opponent["name"], player["name"]])
	_return_to_checkpoint(current)
	if effect_sum(target, "counter") > 0:
		say("  반격! %d칸 더 물러납니다." % COUNTER_STEPS)
		_move_back(current, COUNTER_STEPS)
	return false


## 역전의 첫걸음 카드의 전투: 카드를 쓴 쪽의 ATTACK과 상대의 DEFENSE가 겨룬다.
## 이겨도 져도 아무도 거점으로 돌아가지 않는다. 이기면 true (이동은 부른 쪽에서 한다).
func _battle_comeback(player_index: int) -> bool:
	var attacker: Dictionary = char_of(player_index, "attack")
	var defender: Dictionary = char_of(leading_enemy(player_index), "defense")
	say("  전투! %s(공격) vs %s(방어)" % [attacker["name"], defender["name"]])
	var result := resolve_battle(_attack_dice(player_index), _defense_dice(leading_enemy(player_index), player_index),
		_attack_bonus(player_index), _defense_bonus(leading_enemy(player_index)), _attack_mods(player_index), _defense_mods(leading_enemy(player_index)))
	_say_battle(result)
	_battle_event(attacker["name"], defender["name"], result, "card")
	return bool(result["attacker_won"])


## 현재 플레이어가 칸을 지키는 키퍼를 공격한다. 이기면 true.
func _battle_keeper(keeper_dice: int, keeper_name: String) -> bool:
	var player: Dictionary = players[current]
	var attacker: Dictionary = char_of(current, "attack")
	say("  전투! %s vs 키퍼 [%s]" % [attacker["name"], keeper_name])
	var attack_dice := _attack_dice(current)
	var defense_dice := keeper_dice - effect_sum(current, "enemy_dice_minus")
	var attack_mods := _attack_mods(current)
	var result := resolve_battle(attack_dice, defense_dice, _attack_bonus(current), 0, attack_mods)
	if not result["attacker_won"] and _consume_effect(current, "retry"):
		_say_battle(result)
		say("  재도전! 한 번 더 굴립니다.")
		result = resolve_battle(attack_dice, defense_dice, _attack_bonus(current), 0, attack_mods)
	_say_battle(result)
	_battle_event(attacker["name"], keeper_name, result, "keeper")
	if result["attacker_won"]:
		say("  %s 승리!" % player["name"])
		_chase_after_win()
		return true
	say("  패배... %s은(는) 직전 거점으로 돌아갑니다." % player["name"])
	_return_to_checkpoint(current)
	return false


## 몬스터가 현재 플레이어를 공격한다. 몬스터 주사위 대 내 DEFENSE 캐릭터의 방어 주사위.
## 막으면 true, 뚫리면 직전 거점으로 돌아간다.
func _battle_ambush(monster_dice: int, monster_name: String) -> bool:
	var player: Dictionary = players[current]
	var defender: Dictionary = char_of(current, "defense")
	say("  전투! 몬스터 [%s] vs %s(방어)" % [monster_name, defender["name"]])
	var attack_dice := monster_dice - effect_sum(current, "enemy_dice_minus")
	var defense_dice := _defense_dice(current)
	var defense_bonus := _defense_bonus(current)
	var defense_mods := _defense_mods(current)
	var result := resolve_battle(attack_dice, defense_dice, 0, defense_bonus, {}, defense_mods)
	if result["attacker_won"] and _consume_effect(current, "retry"):
		_say_battle(result)
		say("  재도전! 한 번 더 굴립니다.")
		result = resolve_battle(attack_dice, defense_dice, 0, defense_bonus, {}, defense_mods)
	_say_battle(result)
	_battle_event(monster_name, defender["name"], result, "ambush")
	if not result["attacker_won"]:
		say("  %s 방어 성공!" % player["name"])
		_chase_after_win()
		return true
	say("  막지 못했습니다... %s은(는) 직전 거점으로 돌아갑니다." % player["name"])
	_return_to_checkpoint(current)
	return false


func _say_battle(result: Dictionary) -> void:
	say("  공격 %s = %d  /  방어 %s = %d" % [
		str(result["attack_rolls"]), int(result["attack_total"]),
		str(result["defense_rolls"]), int(result["defense_total"])])


## target: "player"(상대 말과 싸움), "keeper"(키퍼를 공격), "warden"(카드로 세운 문지기를 공격), "ambush"(몬스터의 습격을 막음), "card"(역전의 첫걸음 카드, 지는 쪽이 거점으로 가지 않음)
func _battle_event(attacker_name: String, defender_name: String, result: Dictionary, target: String, opponent: int = -1) -> void:
	_event({
		"kind": "battle",
		"target": target,
		"opponent": leading_enemy(current) if opponent < 0 else opponent,
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
	var opponent_index := leading_enemy(player_index)
	var opponent: Dictionary = players[opponent_index]
	var kind: String = effect.get("type", "")
	var amount := int(effect.get("amount", 0))
	var turns := int(effect.get("turns", 1))

	if kind in TIMED_EFFECTS:
		_add_effect(player_index, kind, amount, turns)
		return
	match kind:
		"multi":
			for part in effect.get("effects", []):
				_apply_effect(part, player_index)
		"move_fixed":
			_add_effect(player_index, "move_fixed", amount, 1)
		"gauge_team":
			_add_gauge(player_index, amount)
		"gauge_enemy":
			_add_gauge(opponent_index, amount)
		"draw_card":
			for i in max(amount, 1):
				_draw_card(player_index, true)
		"enemy_move_dice":
			# 상대의 다음 이동까지 남도록 2턴으로 건다.
			if _consume_charm(opponent_index):
				say("  %s의 부적이 막아 냈습니다." % opponent["name"])
			else:
				_add_effect(opponent_index, "move_dice", amount, 2)
		"trap":
			# amount개: 지금 칸부터 지나온 길을 따라 뒤로 하나씩
			var trail: Array = player["trail"]
			for i in mini(max(amount, 1), trail.size()):
				var spot := int(trail[trail.size() - 1 - i])
				traps[spot] = player_index
				say("  %d번 칸에 덫을 숨겨 두었습니다." % spot)
		"swap":
			_swap_positions(player_index)
		"comeback":
			# 역전의 첫걸음: 상대와 전투. 이기면 나는 앞으로, 상대는 뒤로. 지면 아무 일도 없다.
			if _battle_comeback(player_index):
				say("  역전! %s은(는) %d칸 앞으로, %s은(는) %d칸 뒤로 갑니다." % [player["name"], amount, opponent["name"], amount])
				_walk(player_index, amount, false)
				_move_back(opponent_index, amount)
			else:
				say("  역전 실패. 자리는 그대로입니다.")
		"discard_enemy":
			var their_hand: Array = opponent["hand"]
			if their_hand.is_empty():
				say("  %s의 손에 카드가 없습니다." % opponent["name"])
			elif _consume_charm(opponent_index):
				say("  %s의 부적이 막아 냈습니다." % opponent["name"])
			else:
				var lost: String = their_hand.pop_at(rng.randi_range(0, their_hand.size() - 1))
				say("  %s의 카드 [%s]이(가) 사라졌습니다." % [opponent["name"], cards[lost]["name"]])
		"steal_card":
			var their_cards: Array = opponent["hand"]
			if their_cards.is_empty() or player["hand"].size() >= HAND_LIMIT:
				say("  훔칠 카드가 없습니다.")
			else:
				var taken: String = their_cards.pop_at(rng.randi_range(0, their_cards.size() - 1))
				player["hand"].append(taken)
				say("  %s의 카드 [%s]을(를) 훔쳤습니다." % [opponent["name"], cards[taken]["name"]])
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
		"advance":
			say("  %d칸 앞으로 날아갑니다!" % amount)
			_walk(player_index, amount, false)
		"push_enemy":
			if _consume_charm(opponent_index):
				say("  %s의 부적이 막아 냈습니다." % opponent["name"])
			else:
				say("  %s을(를) %d칸 밀어냅니다!" % [opponent["name"], amount])
				_move_back(opponent_index, amount)
		"steal_gauge":
			_steal_gauge(player_index, amount)
		"enemy_seal":
			# 상대의 다음 차례까지 남도록 2턴으로 건다.
			if _consume_charm(opponent_index):
				say("  %s의 부적이 막아 냈습니다." % opponent["name"])
			else:
				_add_effect(opponent_index, "sealed", 1, 2)
				say("  %s은(는) 다음 차례에 어빌리티를 쓸 수 없습니다." % opponent["name"])
		"enemy_card_seal":
			if _consume_charm(opponent_index):
				say("  %s의 부적이 막아 냈습니다." % opponent["name"])
			else:
				_add_effect(opponent_index, "card_sealed", 1, 2)
				say("  %s은(는) 다음 차례에 카드를 쓸 수 없습니다." % opponent["name"])
		"warden":
			var spot := warden_spot(player_index, maxi(amount, 1))
			if spot < 0:
				say("  문지기를 세울 자리가 없습니다.")
			else:
				# 한 사람이 세운 문지기는 하나만: 예전 것은 사라진다.
				for old_spot in wardens.keys():
					if int(wardens[old_spot]["owner"]) == player_index:
						wardens.erase(old_spot)
				var hero: Dictionary = char_of(player_index, "attack")
				wardens[spot] = {"owner": player_index, "hero": str(hero["id"]), "name": str(hero["name"]),
					"dice": int(hero["attack"]), "bonus": level_bonus(player_index, "attack")}
				say("  %d번 칸에 문지기 [%s](공격 주사위 %d개)이(가) 섰습니다!" % [spot, hero["name"], int(hero["attack"])])
				_event({"kind": "warden", "player": player_index, "pos": spot, "hero": str(hero["id"]), "gone": false})
		"random_one":
			var choices: Array = effect.get("effects", [])
			if not choices.is_empty():
				var picked: Dictionary = choices[rng.randi_range(0, choices.size() - 1)]
				say("  뚝딱! [%s]" % str(picked.get("label", "")))
				_apply_effect(picked, player_index)
		_:
			push_warning("알 수 없는 효과: %s" % kind)


## 추격 효과(이기면 3칸 더 전진): 상대 말·관문지기·전투 칸 적·습격 몬스터 어느 전투든 이기면 적용(2026-11-18 사용자 결정).
## 골의 수호자를 이겨 판이 끝났으면 움직이지 않는다.
func _chase_after_win() -> void:
	if winner >= 0 or effect_sum(current, "chase") <= 0:
		return
	if str(node_of(int(players[current]["pos"])).get("type", "")) == "goal":
		return
	say("  추격! %d칸 더 전진합니다." % CHASE_STEPS)
	_walk(current, CHASE_STEPS, false)


## 상대 팀 게이지를 amount%만큼 빼앗아 우리 팀에 더한다(세 자리 평균으로 셈).
func _steal_gauge(player_index: int, amount: int, opponent_index: int = -1) -> void:
	if opponent_index < 0:
		opponent_index = leading_enemy(player_index)
	var gauge: Dictionary = players[opponent_index]["gauge"]
	var have := 0
	for slot in SLOTS:
		have += int(gauge[slot])
	var taken := mini(amount, int(have / float(SLOTS.size())))
	if taken <= 0:
		say("  빼앗을 게이지가 없습니다.")
		return
	_add_gauge(opponent_index, -taken)
	_add_gauge(player_index, taken)
	say("  %s의 게이지 %d%%를 빼앗았습니다." % [players[opponent_index]["name"], taken])


## 상대 말과 싸워 이긴 쪽에 흡수 효과가 있으면 게이지를 빼앗는다.
func _drain_after_battle(winner_index: int, loser_index: int) -> void:
	var amount := effect_sum(winner_index, "drain")
	if amount > 0:
		_steal_gauge(winner_index, amount, loser_index)


## 두 말의 자리와 지나온 길을 서로 바꾼다.
func _swap_positions(player_index: int) -> void:
	var me: Dictionary = players[player_index]
	var target := leading_enemy(player_index)
	var other: Dictionary = players[target]
	var my_trail: Array = me["trail"]
	me["trail"] = other["trail"]
	other["trail"] = my_trail
	me["pos"] = int(me["trail"].back())
	other["pos"] = int(other["trail"].back())
	_event({"kind": "pos", "player": player_index, "to": me["pos"]})
	_event({"kind": "pos", "player": target, "to": other["pos"]})
	say("  운명이 뒤바뀌었습니다! 두 말의 자리가 바뀝니다.")


## 지속 효과 하나를 써서 없앤다. 있었으면 true.
func _consume_effect(player_index: int, key: String) -> bool:
	var effects: Array = players[player_index]["effects"]
	for index in effects.size():
		if effects[index]["key"] == key:
			effects.remove_at(index)
			return true
	return false


func _add_effect(player_index: int, key: String, amount: int, turns: int) -> void:
	players[player_index]["effects"].append({"key": key, "amount": amount, "turns": turns})


## 턴마다 차는 게이지. 어빌리티는 한 턴에 하나만 쓸 수 있어서 게이지가 가득 차 넘치기 쉽다.
## 넘친 양(세 자리 평균)을 모아 두었다가 100이 되면 카드 1장으로 바꾼다. 지력이 높을수록 이득이다.
func _gain_turn_gauge(player_index: int, amount: int) -> void:
	var player: Dictionary = players[player_index]
	var gauge: Dictionary = player["gauge"]
	var spilled := 0
	for slot in SLOTS:
		# 영웅 레벨이 높은 자리는 게이지가 조금 더 빨리 찬다(강화 효과).
		# 영웅마다 어빌리티 충전 속도가 조금씩 다르다(characters.json의 charge, %).
		var percent := level_gauge_percent(player_index, slot) + int(char_of(player_index, slot).get("charge", 0))
		var gain := maxi(0, amount + int(amount * percent / 100.0))
		spilled += maxi(0, int(gauge[slot]) + gain - 100)
		gauge[slot] = clamp(int(gauge[slot]) + gain, 0, 100)
	player["overflow"] = int(player["overflow"]) + int(float(spilled) / float(SLOTS.size()))
	if int(player["overflow"]) >= 100 and player["hand"].size() < HAND_LIMIT:
		player["overflow"] = int(player["overflow"]) - 100
		say("  %s: 넘친 게이지가 모여 카드가 됩니다." % player["name"])
		_draw_card(player_index, true)
	player["overflow"] = mini(int(player["overflow"]), 100)


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
	var card_id := _next_card(player_index)
	hand.append(card_id)
	if announce:
		say("  %s: 카드 [%s] 획득" % [players[player_index]["name"], cards[card_id]["name"]])


## 다음에 뽑을 카드. 덱이 있으면 섞어 둔 더미 맨 위, 없으면 모든 카드 중 무작위.
func _next_card(player_index: int) -> String:
	var deck: Array = players[player_index].get("deck", [])
	if deck.is_empty():
		var ids: Array = cards.keys()
		return str(ids[rng.randi_range(0, ids.size() - 1)])
	var pile: Array = players[player_index]["draw_pile"]
	if pile.is_empty():
		pile.append_array(deck)
		# 섞기(피셔-예이츠). 규칙 코드의 rng만 쓴다.
		for i in range(pile.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var keep = pile[i]
			pile[i] = pile[j]
			pile[j] = keep
	return str(pile.pop_back())


## 덱에서 없는 카드를 거른다.
func _valid_deck(deck) -> Array:
	var result: Array = []
	if deck is Array:
		for id in deck:
			if cards.has(str(id)):
				result.append(str(id))
	return result


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

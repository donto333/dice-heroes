extends SceneTree
## 화면 없이 도는 자동 검사. CI에서 `godot --headless --script res://tests/run_tests.gd`로 실행한다.
## 하나라도 실패하면 종료 코드 1로 끝나 빌드가 멈춘다.

const GameData := preload("res://scripts/game_data.gd")
const Game := preload("res://scripts/rules/game.gd")
const AI := preload("res://scripts/rules/ai.gd")
const Profile := preload("res://scripts/rules/profile.gd")
# 화면 코드는 실행하지 않지만, 문법 오류를 잡으려고 불러 둔다.
const MainScreen := preload("res://scripts/main.gd")
const MatchScreen := preload("res://scripts/screens/match_screen.gd")
const LobbyScreen := preload("res://scripts/screens/lobby_screen.gd")
const ShopScreen := preload("res://scripts/screens/shop_screen.gd")
const HeroesScreen := preload("res://scripts/screens/heroes_screen.gd")
const SaveStore := preload("res://scripts/save_store.gd")
const HelpScreen := preload("res://scripts/screens/help_screen.gd")
const Music := preload("res://scripts/ui/music.gd")
const BoardView := preload("res://scripts/ui/board_view.gd")
const DiceView := preload("res://scripts/ui/dice_view.gd")
const BattleOverlay := preload("res://scripts/ui/battle_overlay.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
const PartySelect := preload("res://scripts/ui/party_select.gd")
const TurnBanner := preload("res://scripts/ui/turn_banner.gd")
const ResultOverlay := preload("res://scripts/ui/result_overlay.gd")

const CATEGORIES := ["영웅", "위인", "신화", "근현대"]
const TILE_TYPES := [
	"start", "normal", "fork", "random", "attr", "battle", "ambush", "treasure", "forward",
	"warp", "luck", "curse", "prison", "fate", "checkpoint", "goal",
]
const PARTIES := [
	{"name": "A", "attack": "lubu", "defense": "athena", "support": "choichiwon"},
	{"name": "B", "attack": "machao", "defense": "zeus", "support": "houdini"},
]
const SIM_GAMES := 400
const BALANCE_GAMES := 15000
## 카드와 어빌리티가 쓸 수 있는 효과 종류. game.gd의 _apply_effect()와 맞춘다.
const EFFECT_TYPES := [
	"move_fixed", "move_dice", "move_plus", "move_best", "atk_dice", "def_dice",
	"atk_bonus", "def_bonus", "retry", "chase", "counter", "enemy_dice_minus",
	"gauge_team", "gauge_enemy", "draw_card", "skip_enemy", "enemy_move_dice",
	"trap", "swap", "discard_enemy", "steal_card", "cure", "charm", "set_attr", "multi",
]

var _failures: Array[String] = []
var _data: Dictionary = {}


func _init() -> void:
	_data = GameData.load_all()
	_test_character_data()
	_test_board_data()
	_test_references()
	_test_ai_party()
	_test_random_tiles()
	_test_battle_odds()
	_test_move_dice()
	_test_fork_choice()
	_test_checkpoints()
	_test_cards()
	_test_pass_by_fight()
	_test_balance()
	_test_full_games()
	_test_level_bonus()
	_test_profile_basics()
	_test_summon()
	_test_upgrade_and_level()
	_test_match_rewards()
	_test_missions_and_attendance()
	if _failures.is_empty():
		print("모든 검사 통과")
		quit(0)
	else:
		for failure in _failures:
			printerr("실패: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition and not (message in _failures):
		_failures.append(message)


func _new_game(seed_value: int, parties: Array = PARTIES):
	var game = Game.new()
	game.setup(_data, parties, seed_value)
	return game


## 테스트용으로 말을 지정한 길 위에 올려 둔다.
func _place(game, player_index: int, trail: Array) -> void:
	game.players[player_index]["trail"] = trail.duplicate()
	game.players[player_index]["pos"] = int(trail.back())


func _test_character_data() -> void:
	var characters: Array = _data["characters"]
	_check(characters.size() >= 12, "프로토타입 캐릭터가 12명 미만")
	var seen_ids := {}
	for character in characters:
		var id: String = character.get("id", "")
		_check(id != "", "id가 없는 캐릭터가 있음")
		_check(not seen_ids.has(id), "id 중복: " + id)
		seen_ids[id] = true
		_check(character.get("category", "") in CATEGORIES, "분류가 잘못됨: " + id)
		var grade := int(character.get("grade", 0))
		_check(grade >= 1 and grade <= 3, "등급이 1~3이 아님: " + id)
		var move := int(character.get("move", 0))
		_check(move >= 1 and move <= 2, "이동이 1~2가 아님: " + id)
		for stat in ["attack", "defense", "intellect"]:
			var value := int(character.get(stat, 0))
			_check(value >= 1 and value <= 5, "%s가 1~5가 아님: %s" % [stat, id])


## 맵 파일이 올바른지: 칸 종류, 연결, 좌표 겹침, 출발에서 골까지 길.
func _test_board_data() -> void:
	var board: Dictionary = _data["board"]
	var raw_nodes: Array = board.get("nodes", [])
	_check(not raw_nodes.is_empty(), "맵에 칸이 없음")
	var ids := {}
	var spots := {}
	var goal_count := 0
	var fork_count := 0
	for node in raw_nodes:
		var id := int(node.get("id", -1))
		_check(not ids.has(id), "칸 id 중복: %d" % id)
		ids[id] = true
		var spot := "%d,%d" % [int(node.get("x", -1)), int(node.get("y", -1))]
		_check(not spots.has(spot), "같은 자리에 칸이 두 개: (%s)" % spot)
		spots[spot] = true
		_check(node.get("type", "") in TILE_TYPES, "모르는 칸 종류: %d번" % id)
		if node.get("type", "") == "goal":
			goal_count += 1
		if node.get("next", []).size() > 1:
			fork_count += 1
		match node.get("type", ""):
			"attr":
				_check(node.get("attr", "") in CATEGORIES, "속성 칸의 분류가 잘못됨: %d번" % id)
			"battle", "ambush", "goal":
				_check(int(node.get("dice", 0)) >= 1, "키퍼 주사위 수가 없음: %d번" % id)
	for node in raw_nodes:
		for next_id in node.get("next", []):
			_check(ids.has(int(next_id)), "없는 칸으로 이어짐: %d번 → %d번" % [int(node["id"]), int(next_id)])
		if node.get("type", "") != "goal":
			_check(not node.get("next", []).is_empty(), "막다른 칸(골이 아닌데 다음 칸이 없음): %d번" % int(node["id"]))
	_check(goal_count >= 1, "골이 없음")
	_check(fork_count >= 1, "시험용 맵에 갈림길이 없음")
	_check(ids.has(int(board.get("start", -1))), "출발 칸이 없음")

	var game = _new_game(1)
	for id in game.nodes:
		_check(game.dist_to_goal.has(id), "골로 갈 수 없는 칸: %d번" % id)


func _test_references() -> void:
	var abilities: Dictionary = _data["abilities"]
	var shared_count := 0
	for ability_id in abilities:
		var ability: Dictionary = abilities[ability_id]
		_check(str(ability.get("name", "")) != "" and str(ability.get("text", "")) != "", "어빌리티 이름이나 설명이 없음: " + ability_id)
		_check(_effect_ok(ability.get("effect", {})), "모르는 어빌리티 효과: " + ability_id)
		if not str(ability_id).begins_with("unique_"):
			shared_count += 1
	_check(shared_count >= 20 and shared_count <= 30, "공용 어빌리티가 20~30종이 아님: %d" % shared_count)
	for character in _data["characters"]:
		var ability_id: String = character.get("ability", "")
		_check(abilities.has(ability_id), "없는 어빌리티를 가리킴: " + str(character.get("id", "")))
		_check(ability_id.begins_with("unique_") == (int(character["grade"]) == 3), "전용 어빌리티는 ★★★만 가짐: " + str(character.get("id", "")))

	# 모든 어빌리티를 한 번씩 써도 판이 깨지지 않는지.
	for ability_id in abilities:
		var game_a = _new_game(60)
		game_a.begin_turn()
		game_a._apply_effect(abilities[ability_id]["effect"], 0)
		game_a.roll_move()
		while game_a.awaiting_choice():
			game_a.choose_path(0)
		_check(int(game_a.players[0]["trail"].back()) == int(game_a.players[0]["pos"]), "어빌리티를 쓴 뒤 위치가 어긋남: " + ability_id)
	var game = _new_game(1)
	for index in 2:
		_check(game.party_points(index) <= Game.POINT_LIMIT, "파티 포인트가 6을 넘음")
		_check(game.players[index]["hand"].size() == Game.START_HAND, "시작 손패가 3장이 아님")


## AI가 고르는 파티가 규칙에 맞는지 확인한다.
func _test_ai_party() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var by_id := {}
	for character in _data["characters"]:
		by_id[character["id"]] = character
	var seen := {}
	for i in 100:
		var party: Dictionary = AI.pick_party(_data["characters"], Game.POINT_LIMIT, rng)
		_check(party.size() == 3, "AI 파티에 자리가 3개가 아님")
		var ids := [party.get("attack", ""), party.get("defense", ""), party.get("support", "")]
		_check(ids[0] != ids[1] and ids[0] != ids[2] and ids[1] != ids[2], "AI 파티에 같은 캐릭터가 두 번 들어감")
		var total := 0
		for id in ids:
			_check(by_id.has(id), "AI 파티에 없는 캐릭터: %s" % id)
			total += int(by_id.get(id, {"grade": 9})["grade"])
		_check(total <= Game.POINT_LIMIT, "AI 파티 포인트가 6을 넘음")
		seen[str(ids)] = true
	_check(seen.size() > 5, "AI 파티가 매번 거의 같음")


## random 칸이 판마다 실제 효과로 바뀌는지, 판마다 배치가 달라지는지 확인한다.
func _test_random_tiles() -> void:
	var layouts := {}
	for seed_value in 20:
		var game = _new_game(seed_value + 500)
		var layout := ""
		var ids: Array = game.nodes.keys()
		ids.sort()
		for id in ids:
			_check(game.nodes[id]["type"] != "random", "random 칸이 효과로 바뀌지 않음: %d번" % id)
			layout += game.nodes[id]["type"] + ","
		layouts[layout] = true
		_check(game.is_hidden(16), "숨겨진 칸(16번)이 처음부터 보임")
	_check(layouts.size() > 1, "판마다 랜덤 칸 배치가 달라지지 않음")


## 주사위가 많은 쪽이 대체로 이기는지, 그래도 뒤집힐 수 있는지 확인한다.
func _test_battle_odds() -> void:
	var game = _new_game(7)
	var strong_wins := 0
	var even_wins := 0
	var trials := 2000
	for i in trials:
		if game.resolve_battle(5, 3, 0, 0)["attacker_won"]:
			strong_wins += 1
		if game.resolve_battle(4, 3, 0, 0)["attacker_won"]:
			even_wins += 1
	var strong_rate := float(strong_wins) / trials
	var even_rate := float(even_wins) / trials
	_check(strong_rate > 0.85 and strong_rate < 0.99, "주사위 5대3 승률이 예상 범위를 벗어남: %.2f" % strong_rate)
	_check(even_rate > 0.65 and even_rate < 0.90, "주사위 4대3 승률이 예상 범위를 벗어남: %.2f" % even_rate)


## 이동 주사위의 눈 비율이 데이터대로 나오는지 확인한다. 1개는 큰 눈, 2개는 작은 눈이 잘 나와야 한다.
func _test_move_dice() -> void:
	var game = _new_game(21)
	var trials := 6000
	var one_total := 0
	var two_total := 0
	for i in trials:
		one_total += game._sum(game.roll_weighted_dice(1, game.move_weights_for(1)))
		two_total += game._sum(game.roll_weighted_dice(2, game.move_weights_for(2)))
	var one_mean := float(one_total) / trials
	var two_mean := float(two_total) / trials
	print("[이동 주사위] 1개 평균 %.2f칸 · 2개 평균 %.2f칸" % [one_mean, two_mean])
	_check(one_mean > 3.6, "주사위 1개의 평균이 보통 주사위(3.5)보다 크지 않음: %.2f" % one_mean)
	_check(two_mean < 6.8, "주사위 2개의 평균이 보통 주사위(7)보다 작지 않음: %.2f" % two_mean)
	var faces := {}
	for value in game.roll_weighted_dice(500, game.move_weights_for(1)):
		_check(int(value) >= 1 and int(value) <= 6, "이동 주사위 눈이 1~6을 벗어남")
		faces[int(value)] = true
	_check(faces.size() == 6, "이동 주사위에서 나오지 않는 눈이 있음")


## 갈림길(13번)에서 멈추고, 고른 길로 남은 칸만큼 가는지 확인한다.
func _test_fork_choice() -> void:
	var game = _new_game(11)
	game.begin_turn()
	_place(game, 0, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
	game.players[0]["effects"].append({"key": "move_fixed", "amount": 3, "turns": 1})
	game.roll_move()
	_check(game.awaiting_choice(), "갈림길에서 멈추지 않음")
	_check(int(game.pending_choice.get("steps", 0)) == 3, "갈림길에서 남은 칸 수가 3이 아님")
	game.end_turn()
	_check(game.current == 0, "길을 고르기 전에 턴이 넘어감")
	game.choose_path(1)
	_check(not game.awaiting_choice(), "길을 고른 뒤에도 고르기가 남음")
	var pos := int(game.players[0]["pos"])
	# 보물 길로 3칸: 20, 21, 22. 도착 칸(행운)은 위치를 바꾸지 않는다.
	_check(pos == 22, "보물 길로 3칸 간 위치가 22가 아님: %d" % pos)

	# 갈림길 바로 앞에서 1칸만 가면 갈림길 위에 멈추고 고르기는 없다.
	var game2 = _new_game(12)
	game2.begin_turn()
	_place(game2, 0, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
	game2.players[0]["effects"].append({"key": "move_fixed", "amount": 1, "turns": 1})
	game2.roll_move()
	_check(not game2.awaiting_choice(), "갈림길에 딱 멈췄는데 고르기가 생김")
	_check(int(game2.players[0]["pos"]) == 13, "갈림길에 멈추지 않음")


## 지면 지나온 길을 따라 직전 거점으로 돌아가는지 확인한다.
func _test_checkpoints() -> void:
	var game = _new_game(3)
	_place(game, 0, [0, 1, 2, 3, 4, 5])
	game._return_to_checkpoint(0)
	_check(int(game.players[0]["pos"]) == 0, "5번 칸에서 지면 출발로 가야 함")

	_place(game, 0, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 20, 21, 22])
	game._return_to_checkpoint(0)
	_check(int(game.players[0]["pos"]) == 10, "보물 길에서 지면 10번 거점으로 가야 함")

	_place(game, 0, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 26])
	game._return_to_checkpoint(0)
	_check(int(game.players[0]["pos"]) == 10, "26번 거점 위에서 지면 그 이전 거점(10번)으로 가야 함")

	_place(game, 0, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])
	game._move_back(0, 4)
	_check(int(game.players[0]["pos"]) == 12, "험한 길에서 4칸 물러나면 12번이어야 함")


## 카드 20종이 모두 알려진 효과를 쓰고, 써도 판이 깨지지 않는지 확인한다.
func _test_cards() -> void:
	var known := EFFECT_TYPES
	var cards: Dictionary = _data["cards"]
	_check(cards.size() == 20, "카드가 20종이 아님: %d" % cards.size())
	for card_id in cards:
		var card: Dictionary = cards[card_id]
		_check(str(card.get("name", "")) != "" and str(card.get("text", "")) != "", "카드 이름이나 설명이 없음: " + card_id)
		_check(str(card.get("effect", {}).get("type", "")) in known, "모르는 카드 효과: " + card_id)
		var game = _new_game(40)
		game.begin_turn()
		game.players[0]["hand"] = [card_id]
		_check(game.play_card(0), "카드를 쓸 수 없음: " + card_id)
		game.roll_move()
		while game.awaiting_choice():
			game.choose_path(1)
		_check(int(game.players[0]["trail"].back()) == int(game.players[0]["pos"]), "카드를 쓴 뒤 위치가 어긋남: " + card_id)

	# 뒤바뀐 운명: 두 말의 자리가 바뀐다.
	var swap_game = _new_game(41)
	swap_game.begin_turn()
	_place(swap_game, 1, [0, 1, 2, 3, 4, 5, 6, 7, 8])
	swap_game.players[0]["hand"] = ["twisted_fate"]
	swap_game.play_card(0)
	_check(int(swap_game.players[0]["pos"]) == 8 and int(swap_game.players[1]["pos"]) == 0, "뒤바뀐 운명으로 자리가 바뀌지 않음")

	# 후공 보정: 나중에 하는 쪽은 게이지를 채우고 시작한다.
	var fresh = _new_game(42)
	var rules: Dictionary = _data["rules"]
	var per_intellect := int(rules.get("start_gauge_per_intellect", 0))
	var first_expected: int = min(100, per_intellect * int(fresh.char_of(0, "support")["intellect"]))
	var second_expected: int = min(100, per_intellect * int(fresh.char_of(1, "support")["intellect"]) + int(rules.get("second_player_gauge", 0)))
	_check(int(fresh.players[0]["gauge"]["attack"]) == first_expected, "선공 시작 게이지가 지력과 맞지 않음")
	_check(int(fresh.players[1]["gauge"]["attack"]) == second_expected, "후공 게이지 보정이 들어가지 않음")


## 이동 중에 상대 말을 지나치면 싸울지 고르고, 고른 대로 되는지 확인한다.
func _test_pass_by_fight() -> void:
	for answer in 2:
		var game = _new_game(50 + answer)
		game.begin_turn()
		_place(game, 0, [0, 1, 2, 3, 4, 5])
		_place(game, 1, [0, 1, 2, 3, 4, 5, 6, 7])
		game.players[0]["effects"].append({"key": "move_fixed", "amount": 4, "turns": 1})
		game.take_events()
		game.roll_move()
		_check(game.choice_kind() == "fight", "상대를 지나치는데 싸울지 묻지 않음")
		_check(int(game.pending_choice.get("steps", 0)) == 2, "상대를 지나칠 때 남은 칸이 2가 아님")
		game.choose_path(answer)
		var reached_nine := false
		var fought := false
		for event in game.take_events():
			if event["kind"] == "pos" and int(event["player"]) == 0 and int(event["to"]) == 9:
				reached_nine = true
			if event["kind"] == "battle" and event["target"] == "player":
				fought = true
		if answer == 1:
			_check(not fought, "지나가기를 골랐는데 싸움")
			_check(reached_nine, "지나가기를 골랐는데 9번까지 가지 않음")
		else:
			_check(fought, "싸우기를 골랐는데 전투가 없음")

	# 마지막 칸에서 만나면 묻지 않고 도착해서 싸운다.
	var arrive = _new_game(52)
	arrive.begin_turn()
	_place(arrive, 0, [0, 1, 2, 3, 4, 5])
	_place(arrive, 1, [0, 1, 2, 3, 4, 5, 6, 7])
	arrive.players[0]["effects"].append({"key": "move_fixed", "amount": 2, "turns": 1})
	arrive.take_events()
	arrive.roll_move()
	_check(arrive.choice_kind() != "fight", "도착 칸에서 만났는데 싸울지 물음")
	var arrive_fought := false
	for event in arrive.take_events():
		if event["kind"] == "battle" and event["target"] == "player":
			arrive_fought = true
	_check(arrive_fought, "도착 칸에서 만났는데 싸우지 않음")


func _effect_ok(effect: Dictionary) -> bool:
	var kind := str(effect.get("type", ""))
	if not (kind in EFFECT_TYPES):
		return false
	if kind == "multi":
		var parts: Array = effect.get("effects", [])
		if parts.is_empty():
			return false
		for part in parts:
			if not _effect_ok(part):
				return false
	return true


## 무작위 파티끼리 많이 붙여서 캐릭터·등급·분류별 승률을 출력한다. 수치 조정의 근거로 쓴다.
## 자리별로 따로 센다. 같은 캐릭터라도 ATTACK에 앉을 때와 SUPPORT에 앉을 때 하는 일이 다르다.
func _test_balance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var chars: Array = _data["characters"]
	var stats := {}
	var grade_stats := {}
	var category_stats := {}
	var finished := 0
	var total_rounds := 0
	for index in BALANCE_GAMES:
		var a: Dictionary = AI.pick_party(chars, Game.POINT_LIMIT, rng)
		var b: Dictionary = AI.pick_party(chars, Game.POINT_LIMIT, rng)
		a["name"] = "A"
		b["name"] = "B"
		var game = _new_game(5000 + index, [a, b])
		var steps := 0
		while game.winner < 0 and steps < 200:
			AI.take_turn(game)
			steps += 1
		game.take_events()
		if game.winner < 0 or game.winner == 2:
			continue
		finished += 1
		total_rounds += min(game.round_number, Game.MAX_ROUNDS)
		for player in 2:
			var won: int = 1 if game.winner == player else 0
			for slot in Game.SLOTS:
				var character: Dictionary = game.char_of(player, slot)
				var key := "%s@%s" % [character["name"], slot]
				_tally(stats, key, won)
				_tally(grade_stats, "★%d" % int(character["grade"]), won)
				_tally(category_stats, str(character["category"]), won)
	print("[밸런스] %d판 중 승부 %d판 · 평균 %.1f턴" % [BALANCE_GAMES, finished, float(total_rounds) / max(finished, 1)])
	print("[밸런스 등급] %s" % _rate_text(grade_stats, 0))
	print("[밸런스 분류] %s" % _rate_text(category_stats, 0))
	for slot in Game.SLOTS:
		var by_slot := {}
		for key in stats:
			if str(key).ends_with("@" + slot):
				by_slot[str(key).get_slice("@", 0)] = stats[key]
		print("[밸런스 %s] %s" % [slot, _rate_text(by_slot, 30)])


func _tally(table: Dictionary, key: String, won: int) -> void:
	var entry: Array = table.get(key, [0, 0])
	entry[0] += won
	entry[1] += 1
	table[key] = entry


## "이름 승률%(판수)"를 승률 높은 순으로. min_games보다 적게 나온 항목은 뺀다.
func _rate_text(table: Dictionary, min_games: int) -> String:
	var rows: Array = []
	for key in table:
		var entry: Array = table[key]
		if int(entry[1]) >= max(min_games, 1):
			rows.append([key, float(entry[0]) / float(entry[1]), int(entry[1])])
	rows.sort_custom(func(x, y): return float(x[1]) > float(y[1]))
	var parts: PackedStringArray = []
	for row in rows:
		parts.append("%s %d%%(%d)" % [row[0], int(round(float(row[1]) * 100.0)), int(row[2])])
	return ", ".join(parts)


## AI끼리 여러 판을 끝까지 돌린다.
## 판이 멈추지 않고 끝나는지, 상태가 범위를 벗어나지 않는지, 화면용 사건 기록이 실제 위치와 맞는지 본다.
## 판 길이와 승률 통계도 출력한다.
func _test_full_games() -> void:
	var goal_wins := 0
	var first_wins := 0
	var second_wins := 0
	var draws := 0
	var total_rounds := 0
	var player_battles := 0
	var keeper_battles := 0
	var team_wins := {}
	for seed_value in SIM_GAMES:
		var parties: Array = PARTIES if seed_value % 2 == 0 else [PARTIES[1], PARTIES[0]]
		var game = _new_game(seed_value + 100, parties)
		game.take_events()
		var shown := [game.start_id, game.start_id]
		var steps := 0
		while game.winner < 0 and steps < 200:
			AI.take_turn(game)
			steps += 1
			for event in game.take_events():
				if event["kind"] == "pos":
					shown[int(event["player"])] = int(event["to"])
					_check(game.nodes.has(int(event["to"])), "없는 칸으로 이동함")
				elif event["kind"] == "battle":
					_check(str(event.get("target", "")) in ["player", "keeper", "ambush"], "전투 사건의 target이 잘못됨")
					if event["target"] == "player":
						player_battles += 1
					else:
						keeper_battles += 1
			for index in 2:
				var player: Dictionary = game.players[index]
				_check(shown[index] == int(player["pos"]), "사건 기록의 말 위치가 실제 위치와 다름")
				_check(int(player["trail"].back()) == int(player["pos"]), "지나온 길의 끝과 현재 위치가 다름")
				_check(player["hand"].size() <= Game.HAND_LIMIT, "손패가 3장을 넘음")
				for slot in Game.SLOTS:
					var gauge := int(player["gauge"][slot])
					_check(gauge >= 0 and gauge <= 100, "게이지가 0~100을 벗어남")
			_check(not game.awaiting_choice(), "AI 턴이 끝났는데 길 고르기가 남음")
		_check(game.winner >= 0, "판이 끝나지 않음 (seed %d)" % (seed_value + 100))
		total_rounds += min(game.round_number, Game.MAX_ROUNDS)
		if game.winner == 2:
			draws += 1
		elif game.winner == 0:
			first_wins += 1
		elif game.winner == 1:
			second_wins += 1
		if game.winner == 0 or game.winner == 1:
			var team: String = game.char_of(game.winner, "attack")["name"] + " 팀"
			team_wins[team] = int(team_wins.get(team, 0)) + 1
		if game.winner >= 0 and game.winner < 2 and game.nodes[int(game.players[game.winner]["pos"])]["type"] == "goal":
			goal_wins += 1
	print("[통계] %d판 · 평균 %.1f턴 · 골인으로 끝남 %d판 · 선공 승 %d · 후공 승 %d · 무승부 %d · 판당 전투: 플레이어끼리 %.2f회, 키퍼 %.2f회" % [
		SIM_GAMES, float(total_rounds) / SIM_GAMES, goal_wins, first_wins, second_wins, draws,
		float(player_battles) / SIM_GAMES, float(keeper_battles) / SIM_GAMES])
	print("[팀별 승리] %s (두 팀이 번갈아 먼저 시작)" % str(team_wins))
	_check(goal_wins > 0, "골인으로 끝난 판이 하나도 없음")


# ---------------------------------------------------------------- 게임 밖 성장 규칙

## 영웅 레벨이 전투 합계에 더해지는지.
func _test_level_bonus() -> void:
	var low := PARTIES[0].duplicate()
	low["levels"] = {"attack": 1, "defense": 1, "support": 1}
	var high := PARTIES[1].duplicate()
	high["levels"] = {"attack": 5, "defense": 3, "support": 1}
	var game = Game.new()
	game.setup(_data, [low, high], 7)
	var table: Array = _data["rules"].get("level_battle_bonus", [])
	_check(table.size() == 5, "level_battle_bonus는 레벨 1~5의 5칸이어야 함")
	_check(game.level_bonus(0, "attack") == 0, "레벨 1 보너스가 0이 아님")
	_check(game.level_bonus(1, "attack") == int(table[4]), "레벨 5 공격 보너스가 표와 다름")
	_check(game.level_bonus(1, "defense") == int(table[2]), "레벨 3 방어 보너스가 표와 다름")
	_check(game._attack_bonus(1) >= int(table[4]), "레벨 보너스가 공격 합계에 들어가지 않음")


func _test_profile_basics() -> void:
	var eco: Dictionary = _data["economy"]
	_check(not eco.is_empty(), "economy.json을 읽지 못함")
	var profile := Profile.new_profile("테스터", eco)
	var chars: Array = _data["characters"]
	_check(Profile.party_ok(profile, chars, profile["party"], Game.POINT_LIMIT), "시작 파티가 규칙에 맞지 않음")
	for id in profile["owned"]:
		_check(_char_exists(id), "시작 영웅이 캐릭터 목록에 없음: " + str(id))
	_check(profile["owned"].size() >= 9, "시작 영웅이 너무 적음")
	_check(Profile.nickname_ok("용사") and not Profile.nickname_ok(" a "), "닉네임 검사가 이상함")
	# 없는 영웅으로 파티를 짜면 거절
	var bad := {"attack": "zeus", "defense": "athena", "support": "choichiwon"}
	_check(not Profile.party_ok(profile, chars, bad, Game.POINT_LIMIT) or Profile.owns(profile, "zeus"), "가지지 않은 영웅을 파티에 넣을 수 있음")
	var repaired := Profile.repair({"nickname": "옛날"}, eco)
	_check(repaired.has("owned") and repaired.has("daily") and repaired["nickname"] == "옛날", "옛 저장 데이터 고치기가 안 됨")
	_check(Profile.exchange(profile, eco, 0) and int(profile["gems"]) < int(eco["start"]["gems"]), "보석→골드 교환이 안 됨")


func _char_exists(id: String) -> bool:
	for character in _data["characters"]:
		if str(character["id"]) == id:
			return true
	return false


## 확률, 10회 보장, 천장(pity), 중복 조각.
func _test_summon() -> void:
	var eco: Dictionary = _data["economy"]
	var chars: Array = _data["characters"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var profile := Profile.new_profile("소환", eco)
	var counts := {1: 0, 2: 0, 3: 0}
	var pulls := 6000
	var longest_dry := 0
	var dry := 0
	for index in pulls:
		var result: Array = Profile.summon(profile, chars, eco, 1, rng)
		var grade := int(result[0]["grade"])
		counts[grade] += 1
		dry = 0 if grade == 3 else dry + 1
		longest_dry = max(longest_dry, dry)
	var rates: Dictionary = eco["summon"]["rates"]
	var rate3 := float(counts[3]) / pulls * 100.0
	var rate2 := float(counts[2]) / pulls * 100.0
	print("[소환] %d회: ★★★ %.1f%% (표 %s%%), ★★ %.1f%% (표 %s%%), 가장 긴 ★★★ 가뭄 %d회" % [
		pulls, rate3, str(rates["3"]), rate2, str(rates["2"]), longest_dry])
	_check(rate3 >= float(rates["3"]) - 2.0 and rate3 <= float(rates["3"]) + 4.0, "★★★ 확률이 표와 너무 다름")
	_check(abs(rate2 - float(rates["2"])) < 4.0, "★★ 확률이 표와 너무 다름")
	_check(longest_dry < int(eco["summon"]["pity_3"]), "천장(pity)이 작동하지 않음")
	_check(profile["owned"].size() == chars.size(), "많이 소환했는데 모든 영웅을 얻지 못함")
	var any_shards := false
	for id in profile["owned"]:
		if int(profile["owned"][id]["shards"]) > 0:
			any_shards = true
	_check(any_shards, "중복 영웅이 조각으로 바뀌지 않음")
	# 10회 소환에는 ★★ 이상이 하나는 있다
	for trial in 200:
		var ten: Array = Profile.summon(Profile.new_profile("열번", eco), chars, eco, 10, rng)
		var best := 0
		for entry in ten:
			best = max(best, int(entry["grade"]))
		_check(ten.size() == 10 and best >= 2, "10회 소환에 ★★ 이상 보장이 안 됨")
	# 무료 소환은 하루 정해진 횟수만
	var free_profile := Profile.new_profile("무료", eco)
	Profile.ensure_daily(free_profile, "2026-01-01")
	var per_day := int(eco["summon"]["free_per_day"])
	for index in per_day:
		_check(Profile.use_free_summon(free_profile, eco), "무료 소환을 쓸 수 없음")
	_check(not Profile.use_free_summon(free_profile, eco), "무료 소환을 정해진 횟수보다 많이 씀")
	Profile.ensure_daily(free_profile, "2026-01-02")
	_check(Profile.free_summons_left(free_profile, eco) == per_day, "다음 날 무료 소환이 다시 생기지 않음")


func _test_upgrade_and_level() -> void:
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("강화", eco)
	var id := "lubu"
	_check(not Profile.can_upgrade(profile, eco, id), "조각 없이 강화할 수 있음")
	profile["owned"][id]["shards"] = 1000
	profile["gold"] = 100000
	var max_level := int(eco["upgrade"]["max_level"])
	for step in max_level - 1:
		_check(Profile.upgrade(profile, eco, id), "강화가 안 됨 (레벨 %d)" % Profile.level_of(profile, id))
	_check(Profile.level_of(profile, id) == max_level, "최고 레벨까지 오르지 않음")
	_check(not Profile.upgrade(profile, eco, id), "최고 레벨을 넘어 강화됨")
	var battle := Profile.battle_party(profile, profile["party"], "나")
	_check(int(battle["levels"]["attack"]) == max_level, "대전 파티에 영웅 레벨이 안 들어감")
	# 플레이어 레벨
	var fresh := Profile.new_profile("레벨", eco)
	var gems := int(fresh["gems"])
	var ups := Profile.add_exp(fresh, eco, Profile.exp_to_next(fresh, eco) + 1)
	_check(ups == 1 and int(fresh["level"]) == 2 and int(fresh["exp"]) == 1, "경험치로 레벨이 제대로 오르지 않음")
	_check(int(fresh["gems"]) > gems, "레벨업 보석을 주지 않음")


func _test_match_rewards() -> void:
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("랭크", eco)
	Profile.ensure_daily(profile, "2026-01-01")
	var first := Profile.record_match(profile, eco, "rank", "win", {"battle_wins": 2, "cards": 1})
	_check(int(first["trophies"]) > 0 and int(profile["trophies"]) == int(first["trophies"]), "랭크 승리 트로피가 안 들어감")
	_check(bool(first["first_win"]) and int(first["gems"]) > 0, "오늘 첫 승리 보너스가 없음")
	var second := Profile.record_match(profile, eco, "rank", "win", {})
	_check(not bool(second["first_win"]), "첫 승리 보너스를 두 번 줌")
	for index in 20:
		Profile.record_match(profile, eco, "rank", "lose", {})
	_check(int(profile["trophies"]) == 0, "트로피가 0 아래로 내려감")
	_check(int(profile["stats"]["played"]) == 22 and int(profile["stats"]["wins"]) == 2, "전적 기록이 틀림")
	var tiers: Array = eco["tiers"]
	_check(Profile.tier_of(eco, 0)["name"] == tiers[0]["name"], "0 트로피 티어가 첫 티어가 아님")
	var last: Dictionary = tiers[tiers.size() - 1]
	_check(Profile.tier_of(eco, int(last["min"]) + 999)["name"] == last["name"], "가장 높은 티어 계산이 틀림")
	_check(Profile.trophies_to_next(eco, 0) == int(tiers[1]["min"]), "다음 티어까지 남은 트로피가 틀림")
	var local := Profile.record_match(Profile.new_profile("친구", eco), eco, "local", "win", {})
	_check(int(local["trophies"]) == 0 and not bool(local["first_win"]), "친구 대전이 랭크·첫 승리에 들어감")


func _test_missions_and_attendance() -> void:
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("미션", eco)
	Profile.ensure_daily(profile, "2026-03-01")
	var missions: Array = eco["missions"]
	_check(not Profile.has_claimable(profile, eco), "아무것도 안 했는데 받을 보상이 있음")
	for index in 3:
		Profile.record_match(profile, eco, "ai", "win", {"battle_wins": 2, "cards": 2})
	Profile.summon(profile, _data["characters"], eco, 1, RandomNumberGenerator.new())
	_check(Profile.has_claimable(profile, eco), "미션을 깼는데 받을 보상이 없음")
	var gold_before := int(profile["gold"])
	for mission in missions:
		var reward := Profile.claim_mission(profile, eco, str(mission["id"]))
		_check(not reward.is_empty(), "미션 보상을 받을 수 없음: " + str(mission["id"]))
		_check(Profile.claim_mission(profile, eco, str(mission["id"])).is_empty(), "미션 보상을 두 번 받음")
	_check(int(profile["gold"]) > gold_before, "미션 골드가 들어오지 않음")
	_check(not Profile.claim_all_clear(profile, eco).is_empty(), "모든 미션 완료 보상을 받을 수 없음")
	_check(Profile.claim_all_clear(profile, eco).is_empty(), "모든 미션 완료 보상을 두 번 받음")
	_check(Profile.ensure_daily(profile, "2026-03-02") and int(profile["daily"]["progress"].size()) == 0, "다음 날 미션이 새로 시작되지 않음")
	# 출석: 하루 한 번, 7일 표가 돌아간다
	var att := Profile.new_profile("출석", eco)
	var table: Array = eco["attendance"]
	for day in table.size() + 2:
		var today := "2026-04-%02d" % (day + 1)
		_check(Profile.can_check_in(att, today), "출석할 수 없음: " + today)
		var reward := Profile.check_in(att, eco, today)
		_check(reward == table[day % table.size()], "출석 보상 순서가 틀림")
		_check(Profile.check_in(att, eco, today).is_empty(), "하루에 두 번 출석됨")

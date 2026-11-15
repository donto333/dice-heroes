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
const AdventureScreen := preload("res://scripts/screens/adventure_screen.gd")
const BoardView := preload("res://scripts/ui/board_view.gd")
const DiceView := preload("res://scripts/ui/dice_view.gd")
const BattleOverlay := preload("res://scripts/ui/battle_overlay.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
const PartySelect := preload("res://scripts/ui/party_select.gd")
const TurnBanner := preload("res://scripts/ui/turn_banner.gd")
const ResultOverlay := preload("res://scripts/ui/result_overlay.gd")

const CATEGORIES := ["영웅", "위인", "신화", "근현대"]
const TILE_TYPES := [
	"start", "normal", "fork", "random", "attr", "battle", "ambush", "gate", "treasure", "forward",
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
	"trap", "swap", "comeback", "discard_enemy", "steal_card", "cure", "charm", "set_attr", "multi",
]

var _failures: Array[String] = []
## 큰 맵 모의 대전 전체에서 먼저 하는 쪽이 이긴 판 수(선공·후공 균형 확인용)
var _seat_total := 0
var _seat_games := 0
var _data: Dictionary = {}


func _init() -> void:
	_data = GameData.load_all()
	# 규칙 검사는 칸 번호가 정해진 작은 고정 맵으로 한다. 진짜 맵들은 _test_board_data에서 따로 검사한다.
	_data["board"] = GameData.load_json("res://tests/fixtures/board_small.json")
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
	_test_adventure()
	_test_achievements()
	_test_ai_difficulty()
	_test_hero_records()
	_test_daily_deals()
	_test_roulette()
	_test_font_coverage()
	_test_league()
	_test_challenge()
	_test_mail()
	_test_dice_skins()
	_test_pass()
	_test_events()
	_test_sweep()
	_test_double()
	_test_gate()
	_test_minigame_and_league()
	_test_relics()
	_test_album_and_weekday()
	_test_guide()
	_test_upgrade_all()
	_test_monster_kinds()
	_test_streak_power()
	_test_presets()
	_test_coupon_and_backup()
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
	var boards: Array = _data.get("boards", [])
	_check(boards.size() >= 3, "맵이 3개보다 적음")
	for index in boards.size():
		_check_board(boards[index], index)
		_simulate_board(boards[index])
	if _seat_games > 0:
		var rate := 100.0 * _seat_total / _seat_games
		print("[큰 맵 전체] %d판 · 먼저 하는 쪽 승률 %.1f%%" % [_seat_games, rate])
		_check(rate > 40.0 and rate < 60.0, "큰 맵에서 선공·후공 균형이 무너짐: 먼저 하는 쪽 승률 %.1f%%" % rate)


## 맵 하나에서 AI끼리 여러 판을 돌려 끝까지 가는지, 평균 몇 턴인지 본다.
func _simulate_board(board: Dictionary) -> void:
	var data := _data.duplicate()
	data["board"] = board
	var turns := 0
	var finished := 0
	var first_wins := 0
	var team_a_wins := 0
	var games := 300
	for index in games:
		var game = Game.new()
		# 두 팀이 번갈아 먼저 시작한다. 그래야 '먼저 하는 쪽'과 '팀'의 유불리를 따로 볼 수 있다.
		var swapped := index % 2 == 1
		game.setup(data, [PARTIES[1], PARTIES[0]] if swapped else PARTIES, 9000 + index)
		var steps := 0
		while game.winner < 0 and steps < 200:
			AI.take_turn(game)
			steps += 1
		game.take_events()
		_check(game.winner >= 0, "맵 [%s]에서 판이 끝나지 않음" % board.get("name", "?"))
		if game.winner >= 0:
			finished += 1
			turns += min(game.round_number, game.max_rounds)
			if game.winner == 0:
				first_wins += 1
			if (game.winner == 0) != swapped:
				team_a_wins += 1
	print("[맵 %s] %d판 · 평균 %.1f턴 · 먼저 하는 쪽 승 %d · %s 승 %d" % [board.get("name", "?"), finished, float(turns) / max(finished, 1),
		first_wins, str(PARTIES[0].get("name", "첫 팀")), team_a_wins])
	_seat_total += first_wins
	_seat_games += finished


func _check_board(board: Dictionary, board_index: int) -> void:
	_check(str(board.get("name", "")) != "", "맵 이름이 없음: %d번 맵" % board_index)
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
			"battle", "ambush", "gate", "goal":
				_check(int(node.get("dice", 0)) >= 1, "키퍼 주사위 수가 없음: %d번" % id)
	for node in raw_nodes:
		for next_id in node.get("next", []):
			_check(ids.has(int(next_id)), "없는 칸으로 이어짐: %d번 → %d번" % [int(node["id"]), int(next_id)])
		if node.get("type", "") != "goal":
			_check(not node.get("next", []).is_empty(), "막다른 칸(골이 아닌데 다음 칸이 없음): %d번" % int(node["id"]))
	_check(goal_count >= 1, "골이 없음")
	_check(fork_count >= 1, "시험용 맵에 갈림길이 없음")
	_check(ids.has(int(board.get("start", -1))), "출발 칸이 없음")

	var data := _data.duplicate()
	data["board"] = board
	var game = Game.new()
	game.setup(data, PARTIES, 1)
	for id in game.nodes:
		_check(game.dist_to_goal.has(id), "골로 갈 수 없는 칸: [%s] %d번" % [board.get("name", "?"), id])
	for node in raw_nodes:
		if node.get("type", "") == "warp":
			_check(ids.has(int(node.get("to", -1))), "워프 도착 칸이 없음: %d번" % int(node["id"]))


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

	# 주사위 컨트롤: 높게 노리면 평균이 오르고, 낮게 노리면 내려간다. 이동 사건에 노림과 성공 여부가 남는다.
	var sums := {"": 0, "low": 0, "high": 0}
	var hits := 0
	var tries := 600
	for aim in ["", "low", "high"]:
		for i in tries:
			var control = _new_game(1000 + i)
			control.begin_turn()
			control.take_events()
			control.roll_move(aim)
			for event in control.take_events():
				if event["kind"] == "move":
					sums[aim] = int(sums[aim]) + game._sum(event["rolls"])
					_check(str(event.get("aim", "")) == aim, "이동 사건의 노림이 틀림")
					if aim == "high" and bool(event.get("controlled", false)):
						hits += 1
					if aim == "":
						_check(not bool(event.get("controlled", false)), "노리지 않았는데 컨트롤 성공")
	print("[주사위 컨트롤] 평균 눈 합: 낮게 %.2f · 보통 %.2f · 높게 %.2f · 높게 성공 %d/%d" % [
		float(sums["low"]) / tries, float(sums[""]) / tries, float(sums["high"]) / tries, hits, tries])
	_check(int(sums["high"]) > int(sums[""]) and int(sums[""]) > int(sums["low"]), "주사위 컨트롤이 평균을 움직이지 않음")
	_check(hits > tries * 0.25 and hits < tries * 0.45, "주사위 컨트롤 성공 확률이 35%% 근처가 아님: %d/%d" % [hits, tries])

	# 따라잡기: 10칸 이상 뒤처진 쪽은 큰 눈이 더 잘 나온다. 덜 뒤처졌거나 앞서 있으면 보통 비율.
	_check(game.catchup_gap == 10, "따라잡기 기준이 10칸이 아님")
	var boosted_one := 0
	var boosted_two := 0
	for i in trials:
		boosted_one += game._sum(game.roll_weighted_dice(1, game.move_weights_for(1, true)))
		boosted_two += game._sum(game.roll_weighted_dice(2, game.move_weights_for(2, true)))
	print("[따라잡기 주사위] 1개 평균 %.2f칸 · 2개 평균 %.2f칸" % [float(boosted_one) / trials, float(boosted_two) / trials])
	_check(float(boosted_one) / trials > one_mean + 0.3, "따라잡기 주사위 1개가 보통보다 크지 않음")
	_check(float(boosted_two) / trials > two_mean + 0.3, "따라잡기 주사위 2개가 보통보다 크지 않음")
	var chase = _new_game(22)
	chase.begin_turn()
	_place(chase, 0, [0, 1])
	_place(chase, 1, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
	_check(chase.is_catching_up(0) and not chase.is_catching_up(1), "11칸 뒤처진 쪽만 따라잡기여야 함")
	chase.take_events()
	chase.roll_move()
	var flagged := false
	for event in chase.take_events():
		if event["kind"] == "move":
			flagged = bool(event.get("catchup", false))
	_check(flagged, "따라잡기 굴림인데 이동 사건에 표시가 없음")
	_place(chase, 1, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	_place(chase, 0, [0, 1])
	_check(not chase.is_catching_up(0), "9칸 뒤처졌는데 따라잡기가 됨")


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
		if str(card["effect"].get("type", "")) == "comeback":
			# 뒤처져 있어야 쓸 수 있는 카드라 상대를 12칸 앞에 둔다.
			_place(game, 1, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
		_check(game.play_card(0), "카드를 쓸 수 없음: " + card_id)
		game.roll_move()
		while game.awaiting_choice():
			game.choose_path(1)
		_check(int(game.players[0]["trail"].back()) == int(game.players[0]["pos"]), "카드를 쓴 뒤 위치가 어긋남: " + card_id)

	# 역전의 첫걸음: 10칸 이상 뒤처졌을 때만 쓸 수 있다. 이기면 나 +5칸, 상대 -5칸. 지면 그대로.
	_check(not _data["cards"].has("twisted_fate"), "뒤바뀐 운명 카드가 남아 있음")
	var wins := 0
	var losses := 0
	for seed_value in range(1, 41):
		var duel = _new_game(seed_value)
		duel.begin_turn()
		_place(duel, 0, [0, 1])
		_place(duel, 1, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
		duel.players[0]["hand"] = ["comeback_step"]
		_check(duel.can_play_card(0), "11칸 뒤처졌는데 역전의 첫걸음을 못 씀")
		duel.take_events()
		duel.play_card(0)
		var won := false
		var fought := false
		for event in duel.take_events():
			if event["kind"] == "battle" and str(event.get("target", "")) == "card":
				fought = true
				won = bool(event["won"])
		_check(fought, "역전의 첫걸음을 썼는데 전투가 없음")
		if won:
			wins += 1
			_check(int(duel.players[0]["pos"]) == 6 and int(duel.players[1]["pos"]) == 7, "역전 승리: 나 +5칸, 상대 -5칸이 아님")
		else:
			losses += 1
			_check(int(duel.players[0]["pos"]) == 1 and int(duel.players[1]["pos"]) == 12, "역전 실패인데 자리가 바뀜")
		_check(duel.players[0]["hand"].is_empty(), "쓴 카드가 손에 남음")
	_check(wins > 0 and losses > 0, "역전의 첫걸음 결과가 한쪽으로만 나옴 (승 %d, 패 %d)" % [wins, losses])
	var near = _new_game(41)
	near.begin_turn()
	_place(near, 0, [0, 1])
	_place(near, 1, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	near.players[0]["hand"] = ["comeback_step"]
	_check(not near.can_play_card(0) and not near.play_card(0), "9칸 뒤처졌는데 역전의 첫걸음을 씀")
	_check(near.players[0]["hand"].size() == 1, "못 쓴 카드가 사라짐")
	var lead = _new_game(41)
	lead.begin_turn()
	_place(lead, 0, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
	lead.players[0]["hand"] = ["comeback_step"]
	_check(not lead.can_play_card(0), "앞서 있는데 역전의 첫걸음을 씀")

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
		total_rounds += min(game.round_number, game.max_rounds)
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
					_check(str(event.get("target", "")) in ["player", "keeper", "ambush", "card"], "전투 사건의 target이 잘못됨")
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
		total_rounds += min(game.round_number, game.max_rounds)
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
	var missions: Array = Profile.active_missions(profile, eco)
	_check(missions.size() == int(eco["missions_per_day"]), "오늘의 미션 수가 틀림")
	_check(str(Profile.active_missions(profile, eco)[0]["id"]) == str(missions[0]["id"]), "같은 날 미션이 바뀜")
	var ids := {}
	for mission in missions:
		ids[str(mission["id"])] = true
	_check(ids.has("play_1") and ids.has("win_2"), "늘 나오는 미션이 빠짐")
	var varied := false
	for day in 10:
		var other := Profile.new_profile("미션", eco)
		Profile.ensure_daily(other, "2026-06-%02d" % (day + 1))
		for mission in Profile.active_missions(other, eco):
			if not ids.has(str(mission["id"])):
				varied = true
	_check(varied, "날이 바뀌어도 미션이 늘 같음")
	_check(not Profile.has_claimable(profile, eco), "아무것도 안 했는데 받을 보상이 있음")
	for index in 3:
		Profile.record_match(profile, eco, "ai", "win", {"battle_wins": 2, "cards": 2})
	_check(Profile.has_claimable(profile, eco), "미션을 깼는데 받을 보상이 없음")
	# 나머지 미션은 진행도를 채워서 보상 받기를 확인한다.
	for mission in missions:
		profile["daily"]["progress"][str(mission["id"])] = int(mission["goal"])
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


func _test_adventure() -> void:
	for chapter in _data["adventure"].get("chapters", []):
		for stage in chapter["stages"]:
			_check(str(stage.get("story", "")) != "", "모험 이야기가 없음: " + str(stage["id"]))
	var adventure: Dictionary = _data["adventure"]
	var chapters: Array = adventure.get("chapters", [])
	_check(Profile.next_stage_id(adventure, "1-1") == "1-2" and Profile.next_stage_id(adventure, "1-3") == "2-1", "다음 스테이지가 틀림")
	_check(Profile.next_stage_id(adventure, "8-3") == "", "마지막 스테이지에 다음이 있음")
	_check(chapters.size() == _data["boards"].size(), "모험 장 수가 맵 수와 다름")
	var seen := {}
	for chapter in chapters:
		_check(int(chapter["map"]) >= 0 and int(chapter["map"]) < _data["boards"].size(), "모험 장의 맵 번호가 잘못됨: " + str(chapter["id"]))
		_check(chapter["stages"].size() == 3, "장마다 스테이지가 3개가 아님: " + str(chapter["id"]))
		for stage in chapter["stages"]:
			_check(not seen.has(stage["id"]), "스테이지 id가 겹침: " + str(stage["id"]))
			seen[stage["id"]] = true
			for slot in ["attack", "defense", "support"]:
				_check(_char_exists(str(stage["enemy"].get(slot, ""))), "스테이지 적이 캐릭터 목록에 없음: %s %s" % [stage["id"], slot])
			_check(int(stage["ai_level"]) >= 1 and int(stage["ai_level"]) <= 5, "스테이지 AI 레벨이 1~5가 아님: " + str(stage["id"]))
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("모험", eco)
	var stages := Profile.all_stages(adventure)
	_check(Profile.stage_unlocked(profile, adventure, str(stages[0]["id"])), "첫 스테이지가 잠겨 있음")
	_check(not Profile.stage_unlocked(profile, adventure, str(stages[1]["id"])), "두 번째 스테이지가 처음부터 열림")
	_check(Profile.stars_for(adventure, false, 10, 0) == 0, "지면 별이 0이 아님")
	_check(Profile.stars_for(adventure, true, 999, 3) == 1, "그냥 이기면 별 1개가 아님")
	_check(Profile.stars_for(adventure, true, 5, 0) == 3, "빨리·무패로 이기면 별 3개가 아님")
	var gems := int(profile["gems"])
	var first := Profile.record_adventure(profile, adventure, str(stages[0]["id"]), true, 5, 0)
	_check(bool(first["first_clear"]) and int(first["stars"]) == 3, "첫 클리어가 기록되지 않음")
	_check(int(profile["gems"]) > gems, "첫 클리어·별 3개 보상이 없음")
	_check(Profile.stage_unlocked(profile, adventure, str(stages[1]["id"])), "앞 스테이지를 깼는데 다음이 안 열림")
	var again := Profile.record_adventure(profile, adventure, str(stages[0]["id"]), true, 5, 0)
	_check(not bool(again["first_clear"]) and int(again["reward"]["gems"]) == 0, "첫 클리어 보상을 두 번 줌")
	Profile.record_adventure(profile, adventure, str(stages[0]["id"]), true, 999, 2)
	_check(Profile.stage_stars(profile, str(stages[0]["id"])) == 3, "별이 낮은 기록으로 덮어써짐")
	_check(Profile.total_stars(profile) == 3, "별 합계가 틀림")


func _test_achievements() -> void:
	var list: Array = _data["achievements"].get("achievements", [])
	_check(list.size() >= 20, "업적이 20개보다 적음")
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("업적", eco)
	var known := ["wins", "rank_wins", "battle_wins_total", "cards_total", "summons_total", "upgrades_total",
		"owned", "max_level_heroes", "adventure_stars", "chapters_cleared", "best_trophies", "level"]
	var ids := {}
	for achievement in list:
		_check(str(achievement["stat"]) in known, "모르는 업적 값: " + str(achievement["id"]))
		_check(not ids.has(achievement["id"]), "업적 id가 겹침: " + str(achievement["id"]))
		ids[achievement["id"]] = true
	_check(not Profile.has_claimable_achievement(profile, _data), "아무것도 안 했는데 업적 보상이 있음")
	Profile.ensure_daily(profile, "2026-05-01")
	Profile.record_match(profile, eco, "ai", "win", {"battle_wins": 3, "cards": 2})
	_check(int(profile["stats"]["battle_wins_total"]) == 3 and int(profile["stats"]["cards_total"]) == 2, "누적 전투 승리·카드 기록이 안 됨")
	_check(Profile.has_claimable_achievement(profile, _data), "첫 승리 업적을 받을 수 없음")
	_check(Profile.claimable_achievement_count(profile, _data) >= 1, "받을 수 있는 업적 수가 0")
	_check(Profile.claimable_mission_count(profile, eco) >= 0, "받을 수 있는 미션 수가 음수")
	var gems := int(profile["gems"])
	_check(not Profile.claim_achievement(profile, _data, "first_win").is_empty(), "첫 승리 업적 보상을 못 받음")
	_check(int(profile["gems"]) > gems, "업적 보석이 들어오지 않음")
	_check(Profile.claim_achievement(profile, _data, "first_win").is_empty(), "업적 보상을 두 번 받음")
	_check(Profile.claim_achievement(profile, _data, "wins_100").is_empty(), "덜 한 업적 보상을 받음")
	var before_all := int(profile["gold"]) + int(profile["gems"])
	var everything := Profile.claim_everything(profile, eco, _data)
	_check(int(everything["count"]) >= 1 and int(profile["gold"]) + int(profile["gems"]) > before_all, "모두 받기가 보상을 주지 않음")
	_check(int(Profile.claim_everything(profile, eco, _data)["count"]) == 0, "모두 받기를 두 번 받음")
	Profile.summon(profile, _data["characters"], eco, 10, RandomNumberGenerator.new())
	_check(int(profile["stats"]["summons_total"]) == 10, "누적 소환 기록이 틀림")


func _test_ai_difficulty() -> void:
	var eco: Dictionary = _data["economy"]
	_check(eco.get("ai_difficulty", []).size() == 3, "AI 난이도가 3개가 아님")
	_check(str(Profile.ai_difficulty(eco, "hard")["id"]) == "hard", "어려움 난이도를 못 찾음")
	_check(str(Profile.ai_difficulty(eco, "없음")["id"]) == "easy", "모르는 난이도가 쉬움이 아님")
	var profile := Profile.new_profile("난이도", eco)
	Profile.ensure_daily(profile, "2026-05-01")
	var base := int(eco["rewards"]["ai"]["win"]["gold"])
	var reward := Profile.record_match(profile, eco, "ai", "win", {"reward_scale": 2.0})
	_check(int(reward["gold"]) == base * 2, "어려움 보상 배율이 적용되지 않음")
	var party: Dictionary = AI.pick_party(_data["characters"], Game.POINT_LIMIT, RandomNumberGenerator.new(), 1)
	_check(not party.is_empty(), "쉬움 AI 파티를 못 고름")


func _test_hero_records() -> void:
	for character in _data["characters"]:
		_check(str(character.get("bio", "")) != "" and str(character.get("title", "")) != "", "영웅 소개글이 없음: " + str(character["id"]))
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("전적", eco)
	Profile.ensure_daily(profile, "2026-05-01")
	Profile.record_match(profile, eco, "ai", "win", {"party": ["lubu", "athena", "sejong"]})
	Profile.record_match(profile, eco, "ai", "lose", {"party": ["lubu", "athena", "sejong"]})
	var record: Dictionary = Profile.hero_record(profile, "lubu")
	_check(int(record["played"]) == 2 and int(record["wins"]) == 1, "영웅별 전적이 틀림")


func _test_daily_deals() -> void:
	var eco: Dictionary = _data["economy"]
	var characters: Array = _data["characters"]
	var profile := Profile.new_profile("특가", eco)
	Profile.ensure_daily(profile, "2026-05-01")
	var deals := Profile.daily_deals(profile, characters, eco, "2026-05-01")
	_check(deals.size() == 3, "오늘의 특가가 3개가 아님")
	var again := Profile.daily_deals(profile, characters, eco, "2026-05-01")
	_check(str(deals[0]["id"]) == str(again[0]["id"]), "같은 날 특가가 바뀜")
	for deal in deals:
		_check(Profile.owns(profile, str(deal["id"])), "가지지 않은 영웅이 특가에 나옴")
	var id := str(deals[0]["id"])
	var shards := int(profile["owned"][id]["shards"])
	var gold := int(profile["gold"])
	_check(Profile.buy_deal(profile, characters, eco, "2026-05-01", 0), "특가를 못 삼")
	_check(int(profile["owned"][id]["shards"]) == shards + int(deals[0]["shards"]), "특가 조각이 안 들어옴")
	_check(int(profile["gold"]) == gold - int(deals[0]["gold"]), "특가 골드가 안 빠짐")
	_check(not Profile.buy_deal(profile, characters, eco, "2026-05-01", 0), "특가를 두 번 삼")
	profile["gold"] = 0
	_check(not Profile.buy_deal(profile, characters, eco, "2026-05-01", 1), "골드 없이 특가를 삼")
	Profile.ensure_daily(profile, "2026-05-02")
	_check(not bool(Profile.daily_deals(profile, characters, eco, "2026-05-02")[0]["bought"]), "다음 날 특가 구매 기록이 남음")


func _test_roulette() -> void:
	var eco: Dictionary = _data["economy"]
	var table: Dictionary = eco["roulette"]
	_check(table["slots"].size() == 8, "룰렛 칸이 8개가 아님")
	var profile := Profile.new_profile("룰렛", eco)
	Profile.ensure_daily(profile, "2026-05-01")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_check(Profile.roulette_cost(profile, eco) == 0, "첫 룰렛이 무료가 아님")
	var gems := int(profile["gems"])
	var gold := int(profile["gold"])
	var first := Profile.spin_roulette(profile, eco, rng)
	_check(not first.is_empty() and int(first["cost"]) == 0, "무료 룰렛을 못 돌림")
	_check(int(profile["gems"]) + int(profile["gold"]) > gems + gold, "룰렛 보상이 안 들어옴")
	_check(Profile.roulette_cost(profile, eco) == int(table["extra_cost_gems"]), "두 번째 룰렛 값이 틀림")
	for i in int(table["max_extra"]):
		_check(not Profile.spin_roulette(profile, eco, rng).is_empty(), "보석 룰렛을 못 돌림")
	_check(Profile.roulette_cost(profile, eco) == -1, "하루 제한이 없음")
	_check(Profile.spin_roulette(profile, eco, rng).is_empty(), "제한을 넘겨 룰렛을 돌림")
	profile["gems"] = 0
	Profile.ensure_daily(profile, "2026-05-02")
	_check(not Profile.spin_roulette(profile, eco, rng).is_empty(), "다음 날 무료 룰렛을 못 돌림")
	_check(Profile.spin_roulette(profile, eco, rng).is_empty(), "보석 없이 룰렛을 돌림")
	var counts := {}
	var sample := Profile.new_profile("확률", eco)
	for i in 2000:
		Profile.ensure_daily(sample, "d%d" % i)
		var result := Profile.spin_roulette(sample, eco, rng)
		counts[int(result["index"])] = int(counts.get(int(result["index"]), 0)) + 1
	_check(int(counts.get(0, 0)) > int(counts.get(7, 0)), "룰렛 확률이 가중치와 다름")


## 화면에 쓰는 글자가 모두 게임 글꼴에 들어 있는지 본다. (웹에서는 없는 글자가 깨진 네모로 보인다)
func _test_font_coverage() -> void:
	var font: FontFile = load("res://assets/fonts/NotoSansKR-Regular-subset.otf")
	if font == null:
		return
	var missing := {}
	for path in ["res://scripts/ui/kit.gd", "res://data/economy.json", "res://data/achievements.json",
			"res://data/adventure.json", "res://data/characters.json", "res://data/abilities.json", "res://data/cards.json",
			"res://scripts/screens/help_screen.gd", "res://scripts/screens/lobby_screen.gd", "res://scripts/screens/match_screen.gd"]:
		var text := FileAccess.get_file_as_string(path)
		for index in text.length():
			var code := text.unicode_at(index)
			if code > 127 and not font.has_char(code):
				missing[String.chr(code)] = path
	_check(missing.is_empty(), "글꼴에 없는 글자: " + str(missing))


func _test_league() -> void:
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("리그", eco)
	var rows := Profile.league_table(profile, eco)
	_check(rows.size() == eco["ai_names"].size() + 1, "순위표 줄 수가 틀림")
	for index in rows.size() - 1:
		_check(int(rows[index]["trophies"]) >= int(rows[index + 1]["trophies"]), "순위표가 트로피 순이 아님")
	_check(Profile.league_rank(profile, eco) == rows.size(), "트로피 0인데 꼴찌가 아님")
	profile["trophies"] = 99999
	_check(Profile.league_rank(profile, eco) == 1, "트로피가 가장 많은데 1위가 아님")
	_check(Profile.favorite_hero(profile) == "", "기록이 없는데 좋아하는 영웅이 있음")
	Profile.ensure_daily(profile, "2026-05-01")
	Profile.record_match(profile, eco, "ai", "win", {"party": ["lubu", "athena", "sejong"]})
	_check(Profile.favorite_hero(profile) != "", "출전했는데 좋아하는 영웅이 없음")


func _test_challenge() -> void:
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("도전", eco)
	Profile.ensure_daily(profile, "2026-05-01")
	_check(not Profile.challenge_done(profile), "하지도 않았는데 도전 완료")
	_check(Profile.challenge_level(profile, eco) == 2, "도전 상대 레벨이 틀림")
	var lose := Profile.record_match(profile, eco, "challenge", "lose", {})
	_check(not Profile.challenge_done(profile) and int(lose["gold"]) == int(eco["rewards"]["challenge"]["lose"]["gold"]), "져도 도전이 끝남")
	var win := Profile.record_match(profile, eco, "challenge", "win", {})
	_check(Profile.challenge_done(profile), "이겼는데 도전이 안 끝남")
	_check(int(win["gold"]) == int(eco["rewards"]["challenge"]["win"]["gold"]), "도전 승리 골드가 틀림")
	_check(int(win["gems"]) >= int(eco["rewards"]["challenge"]["win"]["gems"]), "도전 승리 보석이 안 들어옴")
	var again := Profile.record_match(profile, eco, "challenge", "win", {})
	_check(int(again["gold"]) == int(eco["rewards"]["ai"]["win"]["gold"]), "하루 두 번째 도전에 큰 보상을 줌")
	var seed_today := Profile.challenge_seed(profile)
	Profile.ensure_daily(profile, "2026-05-02")
	_check(not Profile.challenge_done(profile), "다음 날 도전이 다시 열리지 않음")
	_check(Profile.challenge_seed(profile) != seed_today, "날이 바뀌어도 도전 상대가 같음")


func _test_mail() -> void:
	var eco: Dictionary = _data["economy"]
	var mails: Dictionary = _data["mails"]
	var profile := Profile.new_profile("우편", eco)
	_check(Profile.deliver_mails(profile, mails) == mails["mails"].size(), "우편이 배달되지 않음")
	_check(Profile.deliver_mails(profile, mails) == 0, "같은 우편이 두 번 배달됨")
	_check(Profile.unclaimed_mail_count(profile) == mails["mails"].size(), "안 받은 우편 수가 틀림")
	var gems := int(profile["gems"])
	var reward := Profile.claim_mail(profile, "test_gems_10000")
	_check(int(reward.get("gems", 0)) == 10000 and int(profile["gems"]) == gems + 10000, "테스트 선물 보석 1만 개가 안 들어옴")
	_check(Profile.claim_mail(profile, "test_gems_10000").is_empty(), "우편 선물을 두 번 받음")
	_check(int(Profile.claim_all_mail(profile)["count"]) == 0, "받을 우편이 없는데 모두 받기가 됨")
	# 예전 저장 파일(우편함이 없던 프로필)도 고쳐서 받을 수 있어야 한다.
	var old := Profile.new_profile("옛날", eco)
	old.erase("mail")
	old.erase("mail_delivered")
	Profile.repair(old, eco)
	_check(Profile.deliver_mails(old, mails) == mails["mails"].size(), "예전 프로필에 우편이 배달되지 않음")


func _test_dice_skins() -> void:
	var eco: Dictionary = _data["economy"]
	var skins: Array = eco["dice_skins"]
	_check(skins.size() >= 6 and str(skins[0]["id"]) == "classic", "주사위 스킨 목록이 이상함")
	var profile := Profile.new_profile("스킨", eco)
	_check(str(Profile.current_dice_skin(profile, eco)["id"]) == "classic", "처음 스킨이 기본이 아님")
	_check(not Profile.equip_dice_skin(profile, "ruby"), "없는 스킨을 장착함")
	profile["gold"] = 0
	_check(not Profile.buy_dice_skin(profile, eco, "ruby"), "골드 없이 스킨을 삼")
	profile["gold"] = 3000
	_check(Profile.buy_dice_skin(profile, eco, "ruby") and int(profile["gold"]) == 0, "스킨을 못 사거나 값이 틀림")
	_check(str(Profile.current_dice_skin(profile, eco)["id"]) == "ruby", "산 스킨이 장착되지 않음")
	profile["gold"] = 3000
	_check(not Profile.buy_dice_skin(profile, eco, "ruby") and int(profile["gold"]) == 3000, "같은 스킨을 두 번 삼")
	_check(Profile.equip_dice_skin(profile, "classic") and str(profile["dice_skin"]) == "classic", "기본 스킨으로 못 돌아감")
	profile["dice_skin"] = "없는것"
	_check(str(Profile.current_dice_skin(profile, eco)["id"]) == "classic", "모르는 스킨이면 기본이어야 함")


func _test_pass() -> void:
	var eco: Dictionary = _data["economy"]
	var table: Dictionary = eco["pass"]
	var levels: Array = table["levels"]
	_check(levels.size() == 20 and not bool(table["premium_open"]), "패스 구성이 이상함")
	var profile := Profile.new_profile("패스", eco)
	Profile.ensure_daily(profile, "2026-05-01")
	_check(Profile.pass_level(profile, eco) == 0 and Profile.pass_claimable_count(profile, eco) == 0, "처음 패스 레벨이 0이 아님")
	_check(Profile.claim_pass(profile, eco, 1).is_empty(), "레벨이 안 됐는데 패스 보상을 받음")
	Profile.record_match(profile, eco, "ai", "win", {})
	_check(int(profile["pass"]["exp"]) == int(table["exp"]["win"]), "승리 패스 경험치가 틀림")
	Profile.record_match(profile, eco, "local", "win", {})
	_check(int(profile["pass"]["exp"]) == int(table["exp"]["win"]), "친구 대전에 패스 경험치를 줌")
	Profile.add_pass_exp(profile, eco, 250)
	_check(Profile.pass_level(profile, eco) == 2, "패스 레벨 계산이 틀림")
	var gold := int(profile["gold"])
	var first := Profile.claim_pass(profile, eco, 1)
	_check(int(first.get("gold", 0)) == int(levels[0]["free"]["gold"]) and int(profile["gold"]) == gold + int(first["gold"]), "패스 1레벨 보상이 틀림")
	_check(Profile.claim_pass(profile, eco, 1).is_empty(), "패스 보상을 두 번 받음")
	_check(Profile.claim_pass(profile, eco, 3).is_empty(), "아직 안 된 레벨의 패스 보상을 받음")
	_check(int(Profile.claim_all_pass(profile, eco)["count"]) == 1, "패스 모두 받기 개수가 틀림")
	Profile.add_pass_exp(profile, eco, 999999)
	_check(Profile.pass_level(profile, eco) == levels.size() and Profile.pass_progress(profile, eco) == 1.0, "패스 최고 레벨 처리가 틀림")


func _test_coupon_and_backup() -> void:
	var eco: Dictionary = _data["economy"]
	var coupons: Dictionary = _data["coupons"]
	var profile := Profile.new_profile("쿠폰", eco)
	var gems := int(profile["gems"])
	var result := Profile.redeem_coupon(profile, coupons, " welcome ")
	_check(bool(result["ok"]) and int(profile["gems"]) == gems + 300, "쿠폰(소문자·공백 포함)을 못 씀")
	_check(str(Profile.redeem_coupon(profile, coupons, "WELCOME")["reason"]) == "used", "쿠폰을 두 번 씀")
	_check(str(Profile.redeem_coupon(profile, coupons, "없는코드")["reason"]) == "unknown", "없는 쿠폰이 통함")
	_check(str(Profile.redeem_coupon(profile, coupons, "")["reason"]) == "unknown", "빈 쿠폰이 통함")
	# 옮기기 코드: 내보냈다가 불러오면 같은 프로필이어야 한다.
	var code := SaveStore.export_text(profile)
	var back := SaveStore.import_text("  " + code + "\n")
	_check(str(back.get("nickname", "")) == "쿠폰" and int(back.get("gems", -1)) == int(profile["gems"]), "옮기기 코드로 프로필이 돌아오지 않음")
	_check(back["owned"].size() == profile["owned"].size(), "옮기기 코드에서 영웅 수가 달라짐")
	_check(SaveStore.import_text("아무 글자").is_empty() and SaveStore.import_text("DH1:엉터리").is_empty(), "틀린 옮기기 코드가 통함")
	_check(SaveStore.import_text("DH1:" + Marshalls.utf8_to_base64("{\"a\": 1}")).is_empty(), "프로필이 아닌 코드가 통함")


func _test_presets() -> void:
	var eco: Dictionary = _data["economy"]
	var characters: Array = _data["characters"]
	var profile := Profile.new_profile("저장칸", eco)
	var party: Dictionary = profile["party"].duplicate()
	_check(Profile.save_preset(profile, characters, 1, party, Game.POINT_LIMIT), "파티를 저장 칸에 못 넣음")
	_check(str(profile["party_presets"][1]["attack"]) == str(party["attack"]) and profile["party_presets"][0].is_empty(), "저장 칸 내용이 틀림")
	_check(not Profile.save_preset(profile, characters, 3, party, Game.POINT_LIMIT), "없는 칸에 저장함")
	var bad := party.duplicate()
	bad["defense"] = bad["attack"]
	_check(not Profile.save_preset(profile, characters, 0, bad, Game.POINT_LIMIT), "같은 영웅이 두 번 든 파티를 저장함")
	profile.erase("party_presets")
	_check(Profile.save_preset(profile, characters, 2, party, Game.POINT_LIMIT) and profile["party_presets"].size() == 3, "예전 프로필에 저장 칸이 안 생김")


func _test_streak_power() -> void:
	var eco: Dictionary = _data["economy"]
	var characters: Array = _data["characters"]
	var profile := Profile.new_profile("연승", eco)
	Profile.ensure_daily(profile, "2026-05-01")
	var base := int(eco["rewards"]["rank"]["win"]["gold"])
	var per := int(eco["rewards"]["streak"]["gold_per_win"])
	var first := Profile.record_match(profile, eco, "rank", "win", {})
	_check(int(first["streak"]) == 1 and int(first["gold"]) == base, "1연승에 보너스가 붙음")
	var second := Profile.record_match(profile, eco, "rank", "win", {})
	_check(int(second["streak"]) == 2 and int(second["gold"]) == base + per, "2연승 보너스가 틀림")
	for i in 6:
		Profile.record_match(profile, eco, "rank", "win", {})
	var capped := Profile.record_match(profile, eco, "rank", "win", {})
	_check(int(capped["streak_gold"]) == (int(eco["rewards"]["streak"]["max_count"]) - 1) * per, "연승 보너스 상한이 틀림")
	Profile.record_match(profile, eco, "ai", "lose", {})
	_check(Profile.streak(profile) == 9, "AI전 패배로 랭크 연승이 끊김")
	Profile.record_match(profile, eco, "rank", "lose", {})
	_check(Profile.streak(profile) == 0 and int(profile["stats"]["best_streak"]) == 9, "연승이 끊기지 않거나 최고 연승이 틀림")
	_check(int(first["pass_exp"]) == int(eco["pass"]["exp"]["win"]), "결과에 패스 경험치가 없음")
	var power := Profile.my_power(profile, characters, eco)
	_check(power > 0, "전투력이 0")
	var id := str(profile["party"]["attack"])
	profile["owned"][id]["level"] = 5
	_check(Profile.my_power(profile, characters, eco) == power + 4 * int(eco["power"]["level"]), "레벨이 전투력에 반영되지 않음")
	profile["owned"][id]["shards"] = 7
	var gold := int(profile["gold"])
	_check(Profile.sell_shards(profile, eco, id) == 7 and int(profile["gold"]) == gold + 7 * int(eco["upgrade"]["shard_sell_gold"]), "조각 팔기가 틀림")
	_check(Profile.sell_shards(profile, eco, id) == 0, "조각이 없는데 팔림")
	var other := str(profile["party"]["defense"])
	profile["owned"][other]["shards"] = 5
	_check(Profile.sell_shards(profile, eco, other) == 0, "최고 레벨이 아닌 영웅의 조각을 팖")


## 맵에 나오는 적 이름이 모두 그림 종류에 맞게 나뉘는지 본다(뜻밖에 전부 '짐승'으로 가지 않게).
func _test_monster_kinds() -> void:
	var BoardView = load("res://scripts/ui/board_view.gd")
	_check(BoardView.monster_kind("goal", "메두사") == 6, "골의 수호자가 보스 그림이 아님")
	_check(BoardView.monster_kind("battle", "화산 골렘") == 2 and BoardView.monster_kind("ambush", "유령 병사") == 1, "적 그림 종류가 틀림")
	_check(BoardView.monster_kind("ambush", "돌풍") == 5 and BoardView.monster_kind("battle", "하늘 고래") == 4, "위험물·새 그림 종류가 틀림")
	var kinds := {}
	for board in _data["boards"]:
		for node in board["nodes"]:
			if str(node.get("type", "")) in ["battle", "ambush"]:
				kinds[BoardView.monster_kind(str(node["type"]), str(node.get("name", "")))] = true
	_check(kinds.size() >= 5, "맵의 적들이 그림 종류 5가지 이상으로 나뉘지 않음: %d" % kinds.size())


func _test_events() -> void:
	var eco: Dictionary = _data["economy"]
	var events := {"events": [
		{"id": "a", "name": "골드", "start": "2026-05-01", "end": "2026-05-03", "effect": {"match_gold_scale": 2.0}},
		{"id": "b", "name": "패스", "start": "2026-05-03", "end": "2026-05-05", "effect": {"pass_exp_scale": 3.0}},
	]}
	_check(Profile.active_events(events, "2026-04-30").is_empty(), "시작 전인데 이벤트가 열림")
	_check(Profile.active_events(events, "2026-05-01").size() == 1 and Profile.active_events(events, "2026-05-03").size() == 2, "이벤트 기간 계산이 틀림")
	_check(Profile.active_events(events, "2026-05-06").is_empty(), "끝났는데 이벤트가 열림")
	_check(Profile.event_scale(events, "2026-05-02", "match_gold_scale") == 2.0 and Profile.event_scale(events, "2026-05-02", "pass_exp_scale") == 1.0, "이벤트 배율이 틀림")
	var profile := Profile.new_profile("이벤트", eco)
	Profile.ensure_daily(profile, "2026-05-02")
	var reward := Profile.record_match(profile, eco, "ai", "win", {"event_gold_scale": 2.0, "event_pass_scale": 3.0})
	_check(int(reward["gold"]) == int(eco["rewards"]["ai"]["win"]["gold"]) * 2, "이벤트 골드 배율이 보상에 반영되지 않음")
	_check(int(reward["pass_exp"]) == int(eco["pass"]["exp"]["win"]) * 3, "이벤트 패스 배율이 반영되지 않음")
	# 실제 이벤트 파일의 모양 확인
	for event in _data["events"].get("events", []):
		if event.has("weekdays"):
			_check(not (event["weekdays"] as Array).is_empty(), "요일 이벤트에 요일이 없음: " + str(event.get("id", "")))
			continue
		_check(str(event.get("start", "")).length() == 10 and str(event.get("end", "")) >= str(event.get("start", "")), "이벤트 날짜가 이상함: " + str(event.get("id", "")))


func _test_sweep() -> void:
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("소탕", eco)
	Profile.ensure_daily(profile, "2026-05-01")
	var per_day := int(eco["sweep"]["per_day"])
	_check(not Profile.can_sweep(profile, eco, "1-1") and Profile.sweep(profile, eco, "1-1").is_empty(), "깨지 않은 스테이지를 소탕함")
	profile["adventure"]["1-1"] = 2
	_check(not Profile.can_sweep(profile, eco, "1-1"), "별 2개인데 소탕함")
	profile["adventure"]["1-1"] = 3
	var gold := int(profile["gold"])
	var reward := Profile.sweep(profile, eco, "1-1")
	_check(int(reward.get("gold", 0)) == int(eco["rewards"]["adventure"]["win"]["gold"]) and int(profile["gold"]) > gold, "소탕 보상이 틀림")
	for i in per_day - 1:
		_check(not Profile.sweep(profile, eco, "1-1").is_empty(), "남은 횟수가 있는데 소탕이 안 됨")
	_check(Profile.sweeps_left(profile, eco) == 0 and Profile.sweep(profile, eco, "1-1").is_empty(), "하루 횟수를 넘겨 소탕함")
	_check((profile.get("history", []) as Array).is_empty(), "소탕이 최근 전적에 남음")
	for i in 12:
		Profile.record_match(profile, eco, "ai", "win" if i % 2 == 0 else "lose", {"map": "초원", "turns": i})
	var history: Array = profile["history"]
	_check(history.size() == Profile.HISTORY_LIMIT and int(history[0]["turns"]) == 11 and str(history[0]["outcome"]) == "lose", "최근 전적이 틀림")
	var on_map: Dictionary = Profile.map_record(profile, "초원")
	_check(int(on_map["played"]) == 12 and int(on_map["wins"]) == 6 and int(Profile.map_record(profile, "없는 맵")["played"]) == 0, "맵별 전적이 틀림")
	_check(Profile.three_star_count(profile) == 1, "별 3개 스테이지 수가 틀림")
	Profile.ensure_daily(profile, "2026-05-02")
	_check(Profile.sweeps_left(profile, eco) == per_day, "다음 날 소탕 횟수가 돌아오지 않음")


func _test_upgrade_all() -> void:
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("강화", eco)
	_check(Profile.upgrade_all(profile, eco) == 0, "조각이 없는데 일괄 강화됨")
	var lead := str(profile["party"]["attack"])
	profile["owned"][lead]["shards"] = int(eco["upgrade"]["shards"][0]) + int(eco["upgrade"]["shards"][1])
	profile["gold"] = 1000000
	_check(Profile.upgrade_all(profile, eco) == 2 and Profile.level_of(profile, lead) == 3, "일괄 강화가 두 단계를 올리지 않음")
	_check(Profile.upgrade_all(profile, eco) == 0, "더 올릴 것이 없는데 일괄 강화됨")


func _test_guide() -> void:
	var eco: Dictionary = _data["economy"]
	var steps: Array = _data["guide"]["steps"]
	var profile := Profile.new_profile("길잡이", eco)
	_check(steps.size() >= 5 and not Profile.guide_claimable(profile, _data) and Profile.claim_guide(profile, _data).is_empty(), "하지 않은 길잡이 과제를 받음")
	for step in steps:
		_check(Profile.achievement_value(profile, _data, str(step["stat"])) == 0, "길잡이 과제의 값 이름이 틀림: %s" % str(step["stat"]))
		_check(not (step["reward"] as Dictionary).is_empty() and int(step["goal"]) > 0, "길잡이 과제의 보상이나 목표가 없음")
	Profile.ensure_daily(profile, "2026-05-01")
	Profile.record_match(profile, eco, "ai", "lose", {})
	var gold := int(profile["gold"])
	_check(Profile.guide_claimable(profile, _data) and not Profile.claim_guide(profile, _data).is_empty(), "한 판을 했는데 첫 과제를 못 받음")
	_check(int(profile["gold"]) == gold + int(steps[0]["reward"]["gold"]) and int(profile["guide_step"]) == 1, "길잡이 보상이나 다음 단계가 틀림")
	profile["guide_step"] = steps.size()
	_check(Profile.guide_current(profile, _data).is_empty() and not Profile.guide_claimable(profile, _data), "끝난 길잡이가 남아 있음")


func _test_double() -> void:
	_check(absf(Game.win_chance(1, 1, 0, 0) - 0.5) < 0.001 and absf(Game.win_chance(3, 3, 0, 0) - 0.5) < 0.001, "같은 주사위인데 승률이 반반이 아님")
	_check(Game.win_chance(5, 1, 0, 0) > 0.95 and Game.win_chance(1, 5, 0, 0) < 0.05, "주사위 수 차이가 승률에 안 드러남")
	_check(Game.win_chance(2, 2, 2, 0) > Game.win_chance(2, 2, 0, 0) and Game.win_chance(1, 1, 0, 6) == 0.0, "보너스가 승률에 안 드러남")
	_check(int(Game.sum_distribution(2)[7]) == 6 and int(Game.sum_distribution(2)[2]) == 1, "주사위 합 분포가 틀림")
	_check(Game.is_double([3, 3]) and Game.is_double([6, 6, 6]), "같은 눈인데 더블이 아님")
	_check(not Game.is_double([3]) and not Game.is_double([2, 5]) and not Game.is_double([]), "더블이 아닌데 더블임")
	_check(int(_data["rules"].get("double_gauge", 0)) > 0 and int(_data["rules"]["double_gauge"]) <= 20, "더블 게이지가 없거나 너무 큼")


## 관문: 지나가다가도 멈춰 싸우고, 이기면 다음부터 그냥 지나가고, 지면 관문지기가 약해진다.
func _test_gate() -> void:
	var stopped := 0
	for seed_value in 20:
		var game = _new_game(700 + seed_value)
		game.nodes[3] = (game.nodes[3] as Dictionary).duplicate()
		game.nodes[3]["type"] = "gate"
		game.nodes[3]["name"] = "관문지기 산적"
		game.nodes[3]["dice"] = 3
		game.begin_turn()
		_place(game, 0, [0])
		game.players[0]["effects"].append({"key": "move_fixed", "amount": 5, "turns": 1})
		game.roll_move()
		var passed := false
		var fought := false
		for event in game.events:
			if str(event.get("kind", "")) == "pos" and int(event.get("player", -1)) == 0 and int(event.get("to", -1)) == 4:
				passed = true
			if str(event.get("kind", "")) == "battle" and str(event.get("target", "")) == "keeper":
				fought = true
		_check(not passed and fought, "관문을 싸우지 않고 지나감")
		if game.gates_cleared[0].has(3):
			_check(int(game.players[0]["pos"]) == 3, "관문을 이겼는데 관문 칸에 없음")
		else:
			_check(int(game.players[0]["pos"]) < 3 and int(game.gate_fails[0].get(3, 0)) == 1 and game.gate_dice_for(0, 3) == 2, "관문에서 졌는데 돌아가지 않거나 약해지지 않음")
		_check(game.gate_blocks(1, 3), "한 사람이 뚫은 관문이 상대에게도 열림")
		stopped += 1
	_check(stopped == 20, "관문 검사가 돌지 않음")
	# 이미 뚫은 관문은 그냥 지나간다.
	var game2 = _new_game(731)
	game2.nodes[3] = (game2.nodes[3] as Dictionary).duplicate()
	game2.nodes[3]["type"] = "gate"
	game2.nodes[3]["name"] = "관문지기 산적"
	game2.nodes[3]["dice"] = 3
	game2.gates_cleared[0][3] = true
	game2.begin_turn()
	_place(game2, 0, [0])
	game2.players[0]["effects"].append({"key": "move_fixed", "amount": 5, "turns": 1})
	game2.roll_move()
	var went_on := false
	for event in game2.events:
		if str(event.get("kind", "")) == "pos" and int(event.get("to", -1)) == 4:
			went_on = true
	_check(went_on, "뚫은 관문에서 또 멈춤")
	game2.gate_fails[1][3] = 9
	_check(game2.gate_dice_for(1, 3) == 1, "관문지기 주사위가 1개 밑으로 내려감")
	# 맵마다 관문이 큰길에 3개 있다.
	for board in _data["boards"]:
		var gates := 0
		for node in board["nodes"]:
			if str(node.get("type", "")) == "gate":
				gates += 1
		_check(gates == 3, "%s 맵의 관문이 3개가 아님: %d개" % [board.get("name", ""), gates])


func _test_album_and_weekday() -> void:
	var eco: Dictionary = _data["economy"]
	var characters: Array = _data["characters"]
	var profile := Profile.new_profile("앨범", eco)
	var steps: Array = eco["album"]["steps"]
	_check(steps.size() == (eco["album"]["rewards"] as Array).size(), "앨범 단계와 보상 수가 다름")
	profile["owned"] = {}
	_check(not Profile.album_has_claimable(profile, eco, characters), "영웅이 없는데 앨범 보상이 있음")
	var added := 0
	for character in characters:
		if str(character["category"]) == "위인" and added < int(steps[1]):
			profile["owned"][str(character["id"])] = {"level": 1, "shards": 0}
			added += 1
	_check(Profile.album_count(profile, characters, "위인") == int(steps[1]) and Profile.album_claimable(profile, eco, characters, "위인").size() == 2, "앨범 단계 계산이 틀림")
	var gems := int(profile["gems"])
	var reward := Profile.claim_album(profile, eco, characters, "위인")
	_check(int(reward.get("gems", 0)) == int(eco["album"]["rewards"][0].get("gems", 0)) and int(profile["gems"]) == gems + int(reward.get("gems", 0)), "앨범 보상이 틀림")
	_check(Profile.claim_album(profile, eco, characters, "위인").is_empty() and Profile.claim_album(profile, eco, characters, "신화").is_empty(), "앨범 보상을 두 번 받음")
	# 요일 이벤트: 2026-11-14는 토요일, 11-16은 월요일
	var events := {"events": [{"id": "w", "weekdays": [6, 0], "effect": {"match_gold_scale": 1.3}}]}
	_check(absf(Profile.event_scale(events, "2026-11-14", "match_gold_scale") - 1.3) < 0.001, "토요일 이벤트가 안 열림")
	_check(absf(Profile.event_scale(events, "2026-11-15", "match_gold_scale") - 1.3) < 0.001, "일요일 이벤트가 안 열림")
	_check(absf(Profile.event_scale(events, "2026-11-16", "match_gold_scale") - 1.0) < 0.001, "월요일에 주말 이벤트가 열림")


func _test_relics() -> void:
	_check(Profile.rank_boost(_data["economy"], 0).is_empty() and int(Profile.rank_boost(_data["economy"], 600).get("gauge", 0)) == 15 and int(Profile.rank_boost(_data["economy"], 5000).get("atk_bonus", 0)) == 1, "랭크전 상대 강화 단계가 틀림")
	var gate_profile := Profile.new_profile("관문", _data["economy"])
	Profile.ensure_daily(gate_profile, "2026-05-01")
	Profile.record_match(gate_profile, _data["economy"], "ai", "win", {"gates": 3})
	_check(Profile.achievement_value(gate_profile, _data, "gates_total") == 3, "관문 돌파 기록이 안 쌓임")
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("유물", eco)
	_check(Profile.current_relic(profile, eco).is_empty() and not Profile.equip_relic(profile, "banner"), "없는 유물을 장착함")
	profile["gold"] = 0
	_check(not Profile.buy_relic(profile, eco, "banner"), "골드 없이 유물을 삼")
	profile["gold"] = 5000
	_check(Profile.buy_relic(profile, eco, "banner") and int(profile["gold"]) == 2000 and str(Profile.current_relic(profile, eco)["id"]) == "banner", "유물 사기가 틀림")
	_check(not Profile.buy_relic(profile, eco, "banner"), "같은 유물을 두 번 삼")
	Profile.equip_relic(profile, "banner")
	_check(Profile.current_relic(profile, eco).is_empty(), "유물을 벗었는데 남아 있음")
	# 판에서의 효과
	var plain = _new_game(5)
	var parties: Array = []
	for party in PARTIES:
		parties.append((party as Dictionary).duplicate(true))
	parties[0]["relic"] = {"atk_bonus": 1, "turns": 5, "gauge": 15, "charm": true}
	var boosted = _new_game(5, parties)
	_check(boosted.effect_sum(0, "atk_bonus") == plain.effect_sum(0, "atk_bonus") + 1, "유물 공격 보너스가 안 붙음")
	_check(int(boosted.players[0]["gauge"]["attack"]) == mini(100, int(plain.players[0]["gauge"]["attack"]) + 15), "유물 게이지가 안 참")
	_check(bool(boosted.players[0]["charm"]) and not bool(boosted.players[1]["charm"]), "유물 부적이 틀림")
	_check(boosted.effect_sum(1, "atk_bonus") == plain.effect_sum(1, "atk_bonus"), "상대에게 유물 효과가 붙음")
	for item in eco["relics"]:
		_check(not (item["effect"] as Dictionary).is_empty() and not (item["cost"] as Dictionary).is_empty(), "유물 자료가 비어 있음")


func _test_minigame_and_league() -> void:
	var eco: Dictionary = _data["economy"]
	var profile := Profile.new_profile("홀짝", eco)
	Profile.ensure_daily(profile, "2026-05-01")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var per_day := int(eco["odd_even"]["per_day"])
	_check(Profile.play_odd_even(profile, eco, "셋", rng).is_empty(), "홀짝이 아닌 것을 받음")
	for i in per_day:
		var gold := int(profile["gold"])
		var result := Profile.play_odd_even(profile, eco, "odd", rng)
		_check(not result.is_empty() and bool(result["won"]) == (int(result["roll"]) % 2 == 1), "홀짝 판정이 틀림")
		_check(int(profile["gold"]) == gold + int(eco["odd_even"]["win" if bool(result["won"]) else "lose"]["gold"]), "홀짝 보상이 틀림")
	_check(Profile.play_odd_even(profile, eco, "odd", rng).is_empty() and Profile.odd_even_left(profile, eco) == 0, "하루 횟수를 넘겨 홀짝을 함")
	# 주간 리그: 2026-11-15(일)와 11-16(월)은 다른 주, 11-16과 11-22(일)는 같은 주
	_check(Profile.week_of("2026-11-15") + 1 == Profile.week_of("2026-11-16") and Profile.week_of("2026-11-16") == Profile.week_of("2026-11-22"), "주 계산이 틀림")
	_check(Profile.settle_league(profile, eco, "2026-11-15").is_empty() and Profile.settle_league(profile, eco, "2026-11-15").is_empty(), "같은 주에 리그 보상을 줌")
	profile["trophies"] = 99999
	var gems := int(profile["gems"])
	var settled := Profile.settle_league(profile, eco, "2026-11-16")
	_check(int(settled.get("rank", 0)) == 1 and bool(settled["medal"]) and int(profile.get("medals", 0)) == 1, "1위인데 훈장을 못 받음")
	_check(int(profile["gems"]) == gems + int(eco["league_weekly"]["tiers"][0]["reward"]["gems"]), "주간 리그 보상이 틀림")
	_check(Profile.settle_league(profile, eco, "2026-11-17").is_empty(), "한 주에 리그 보상을 두 번 줌")
	_check(not Profile.league_tier(eco, 13).is_empty(), "꼴찌가 받을 주간 보상이 없음")

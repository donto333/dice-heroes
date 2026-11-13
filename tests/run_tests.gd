extends SceneTree
## 화면 없이 도는 자동 검사. CI에서 `godot --headless --script res://tests/run_tests.gd`로 실행한다.
## 하나라도 실패하면 종료 코드 1로 끝나 빌드가 멈춘다.

const GameData := preload("res://scripts/game_data.gd")
const Game := preload("res://scripts/rules/game.gd")
const AI := preload("res://scripts/rules/ai.gd")
# 화면 코드는 실행하지 않지만, 문법 오류를 잡으려고 불러 둔다.
const MainScreen := preload("res://scripts/main.gd")
const BoardView := preload("res://scripts/ui/board_view.gd")
const DiceView := preload("res://scripts/ui/dice_view.gd")
const BattleOverlay := preload("res://scripts/ui/battle_overlay.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")
const PartySelect := preload("res://scripts/ui/party_select.gd")

const CATEGORIES := ["영웅", "위인", "신화", "근현대"]
const TILE_TYPES := [
	"start", "normal", "fork", "random", "attr", "battle", "treasure", "forward",
	"warp", "luck", "curse", "prison", "fate", "checkpoint", "goal",
]
const PARTIES := [
	{"name": "A", "attack": "lubu", "defense": "athena", "support": "choichiwon"},
	{"name": "B", "attack": "machao", "defense": "zeus", "support": "houdini"},
]
const SIM_GAMES := 400

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
	_test_full_games()
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
			"battle", "goal":
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
	for character in _data["characters"]:
		_check(abilities.has(character.get("ability", "")), "없는 어빌리티를 가리킴: " + str(character.get("id", "")))
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
					var other_names := [game.char_of(0, "defense")["name"], game.char_of(1, "defense")["name"]]
					if event["defender"] in other_names:
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

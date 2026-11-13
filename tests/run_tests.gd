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

const CATEGORIES := ["영웅", "위인", "신화", "근현대"]
const PARTIES := [
	{"name": "A", "attack": "lubu", "defense": "athena", "support": "choichiwon"},
	{"name": "B", "attack": "machao", "defense": "zeus", "support": "houdini"},
]

var _failures: Array[String] = []
var _data: Dictionary = {}


func _init() -> void:
	_data = GameData.load_all()
	_test_character_data()
	_test_board_data()
	_test_references()
	_test_battle_odds()
	_test_checkpoints()
	_test_full_games()
	_test_events()
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


func _new_game(seed_value: int):
	var game = Game.new()
	game.setup(_data, PARTIES, seed_value)
	return game


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


func _test_board_data() -> void:
	var board: Array = _data["board"]
	_check(board.size() == 41, "보드가 41칸(0~40)이 아님")
	if board.is_empty():
		return
	_check(board[0]["type"] == "start", "0번 칸이 출발이 아님")
	_check(board[board.size() - 1]["type"] == "goal", "마지막 칸이 골이 아님")
	for index in board.size():
		var tile: Dictionary = board[index]
		match tile["type"]:
			"warp":
				var to := int(tile.get("to", -1))
				_check(to > 0 and to < board.size() - 1, "워프 목적지가 잘못됨: %d번 칸" % index)
			"attr":
				_check(tile.get("attr", "") in CATEGORIES, "속성 칸의 분류가 잘못됨: %d번 칸" % index)
			"battle", "goal":
				_check(int(tile.get("dice", 0)) >= 1, "키퍼 주사위 수가 없음: %d번 칸" % index)


func _test_references() -> void:
	var abilities: Dictionary = _data["abilities"]
	for character in _data["characters"]:
		_check(abilities.has(character.get("ability", "")), "없는 어빌리티를 가리킴: " + str(character.get("id", "")))
	var game = _new_game(1)
	for index in 2:
		_check(game.party_points(index) <= Game.POINT_LIMIT, "파티 포인트가 6을 넘음")
		_check(game.players[index]["hand"].size() == Game.START_HAND, "시작 손패가 3장이 아님")


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


func _test_checkpoints() -> void:
	var game = _new_game(3)
	_check(game.checkpoint_before(5) == 0, "5번 칸의 직전 거점은 출발이어야 함")
	_check(game.checkpoint_before(10) == 0, "10번 칸(거점 위)의 직전 거점은 출발이어야 함")
	_check(game.checkpoint_before(15) == 10, "15번 칸의 직전 거점은 10이어야 함")
	_check(game.checkpoint_before(40) == 30, "40번 칸의 직전 거점은 30이어야 함")


## AI끼리 여러 판을 끝까지 돌려, 판이 멈추지 않고 끝나는지와 상태가 범위를 벗어나지 않는지 본다.
func _test_full_games() -> void:
	var goal_wins := 0
	var games := 300
	for seed_value in games:
		var game = _new_game(seed_value + 100)
		var steps := 0
		while game.winner < 0 and steps < 200:
			AI.take_turn(game)
			steps += 1
			for player in game.players:
				_check(int(player["pos"]) >= 0 and int(player["pos"]) <= game.goal_index(), "말이 보드 밖으로 나감")
				_check(player["hand"].size() <= Game.HAND_LIMIT, "손패가 3장을 넘음")
				for slot in Game.SLOTS:
					var gauge := int(player["gauge"][slot])
					_check(gauge >= 0 and gauge <= 100, "게이지가 0~100을 벗어남")
		_check(game.winner >= 0, "판이 끝나지 않음 (seed %d)" % (seed_value + 100))
		if game.winner >= 0 and game.winner < 2 and int(game.players[game.winner]["pos"]) == game.goal_index():
			goal_wins += 1
	print("골인으로 끝난 판: %d / %d" % [goal_wins, games])
	_check(goal_wins > 0, "300판 중 골인으로 끝난 판이 하나도 없음")


## 화면 연출용 사건 기록이 말 위치와 맞는지 확인한다.
func _test_events() -> void:
	for seed_value in 50:
		var game = _new_game(seed_value + 1000)
		game.take_events()
		var shown := [0, 0]
		var steps := 0
		while game.winner < 0 and steps < 200:
			AI.take_turn(game)
			for event in game.take_events():
				if event["kind"] == "pos":
					shown[int(event["player"])] = int(event["to"])
				elif event["kind"] == "move":
					_check(int(event["total"]) >= 1, "이동 칸 수가 1 미만")
				elif event["kind"] == "battle":
					_check(event["attack_rolls"].size() >= 1, "전투 주사위 기록이 비어 있음")
			for index in 2:
				_check(shown[index] == int(game.players[index]["pos"]), "사건 기록의 말 위치가 실제 위치와 다름")
			steps += 1
		_check(game.events.is_empty(), "take_events 후 사건 기록이 남아 있음")

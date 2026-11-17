extends SceneTree
## 승률 계산기: AI끼리 수많은 판을 돌려 조합(파티)마다, 영웅마다 승률을 낸다. 화면 없이 돈다.
##   godot --headless --script res://tools/sim_winrate.gd
## 환경 변수: LIMIT(소환 포인트 한도, 기본 6) · GAMES(조합마다 돌릴 판 수, 기본 150) ·
##   SHARD/SHARDS(여러 서버가 나눠 돌릴 때 내 몫) · OUT(결과 json을 쓸 경로)
## 조합 = 세 명(포인트 합이 한도 또는 한도-1)을 AI.best_placement로 자리에 앉힌 파티.
## 상대는 같은 조합 목록에서 무작위, 맵 9종을 무작위로, 선·후공을 번갈아 한다. 영웅 레벨은 모두 1.

const GameData := preload("res://scripts/game_data.gd")
const Game := preload("res://scripts/rules/game.gd")
const AI := preload("res://scripts/rules/ai.gd")


func _env_int(name: String, fallback: int) -> int:
	var text := OS.get_environment(name)
	return int(text) if text != "" else fallback


func _init() -> void:
	var limit := _env_int("LIMIT", 6)
	var games := _env_int("GAMES", 150)
	var shard := _env_int("SHARD", 0)
	var shards := maxi(1, _env_int("SHARDS", 1))
	var out_path := OS.get_environment("OUT")
	var data: Dictionary = GameData.load_all()
	var chars: Array = data["characters"]
	var datas: Array = []
	for board in data["boards"]:
		var copy := data.duplicate()
		copy["board"] = board
		datas.append(copy)

	# 조합 목록(모든 서버가 같은 순서)
	var parties: Array = []
	for i in chars.size():
		for j in range(i + 1, chars.size()):
			for k in range(j + 1, chars.size()):
				var total := int(chars[i]["grade"]) + int(chars[j]["grade"]) + int(chars[k]["grade"])
				if total > limit or total < limit - 1:
					continue
				var party: Dictionary = AI.best_placement([chars[i], chars[j], chars[k]])["party"]
				parties.append(party)
	var combo_stats := {}
	var hero_stats := {}
	var board_first := []
	for index in datas.size():
		board_first.append([0, 0.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261118 + shard * 7919
	var played := 0
	var draws := 0
	var rounds := 0
	var started := Time.get_ticks_msec()
	for index in parties.size():
		if index % shards != shard:
			continue
		for round_index in games:
			var mine: Dictionary = parties[index]
			var other: Dictionary = parties[rng.randi_range(0, parties.size() - 1)]
			var mine_first := round_index % 2 == 0
			var board_index := rng.randi_range(0, datas.size() - 1)
			var a: Dictionary = (mine if mine_first else other).duplicate()
			var b: Dictionary = (other if mine_first else mine).duplicate()
			a["name"] = "A"
			b["name"] = "B"
			var game = Game.new()
			game.setup(datas[board_index], [a, b], rng.randi() & 0x7fffffff)
			var steps := 0
			while game.winner < 0 and steps < 400:
				AI.take_turn(game)
				steps += 1
			played += 1
			rounds += int(game.round_number)
			var first_score := 0.5
			if game.winner == 0:
				first_score = 1.0
			elif game.winner == 1:
				first_score = 0.0
			else:
				draws += 1
			board_first[board_index][0] += 1
			board_first[board_index][1] += first_score
			_record(combo_stats, hero_stats, a, first_score)
			_record(combo_stats, hero_stats, b, 1.0 - first_score)
		if played % 3000 < games:
			print("진행 %d판 · %.0f초" % [played, (Time.get_ticks_msec() - started) / 1000.0])
	var result := {
		"limit": limit, "games_per_combo": games, "shard": shard, "shards": shards, "combos_total": parties.size(),
		"played": played, "draws": draws, "rounds": rounds, "boards": board_first,
		"combos": combo_stats, "heroes": hero_stats,
	}
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(result))
		file.close()
	print("끝: 조합 %d개 중 내 몫 · %d판 · 무승부 %d · 평균 %.1f턴 · %.0f초" % [parties.size(), played, draws, float(rounds) / maxf(1.0, played), (Time.get_ticks_msec() - started) / 1000.0])
	quit(0)


## 한 판의 결과를 조합과 영웅(자리별)에 더한다. score: 이기면 1, 지면 0, 비기면 0.5.
func _record(combo_stats: Dictionary, hero_stats: Dictionary, party: Dictionary, score: float) -> void:
	var key := "%s,%s,%s" % [party["attack"], party["defense"], party["support"]]
	if not combo_stats.has(key):
		combo_stats[key] = [0, 0.0]
	combo_stats[key][0] += 1
	combo_stats[key][1] += score
	for slot in ["attack", "defense", "support"]:
		var hero_key := "%s|%s" % [party[slot], slot]
		if not hero_stats.has(hero_key):
			hero_stats[hero_key] = [0, 0.0]
		hero_stats[hero_key][0] += 1
		hero_stats[hero_key][1] += score

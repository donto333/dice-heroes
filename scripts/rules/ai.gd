extends RefCounted
## 프로토타입용 단순한 AI. 쓸 수 있는 어빌리티와 카드를 쓰고 주사위를 굴린다.
## 갈림길에서는 골까지 가까운 길을 고른다.
## 판단을 잘하는 AI가 아니라, 규칙이 끝까지 돌아가는지 확인하는 상대다.

## 현재 차례인 플레이어의 한 턴을 끝까지 진행한다.
static func take_turn(game) -> void:
	if game.winner >= 0:
		return
	if game.begin_turn():
		for slot in game.SLOTS:
			if game.can_use_ability(slot):
				game.use_ability(slot)
				break
		if game.can_play_card(0):
			game.play_card(0)
		game.roll_move()
		var guard := 0
		while game.awaiting_choice() and guard < 10:
			game.choose_path(choose(game))
			guard += 1
	game.end_turn()


## 갈림길에서 고를 길의 순번.
static func choose(game) -> int:
	return game.best_option(game.pending_choice["options"])


## AI 파티를 고른다. 포인트 제한 안에서 무작위로 세 명을 뽑고,
## 공격이 가장 높은 캐릭터를 ATTACK, 남은 중 방어가 높은 쪽을 DEFENSE, 나머지를 SUPPORT에 앉힌다.
static func pick_party(characters: Array, point_limit: int, rng: RandomNumberGenerator) -> Dictionary:
	var combos: Array = []
	for i in characters.size():
		for j in range(i + 1, characters.size()):
			for k in range(j + 1, characters.size()):
				var trio: Array = [characters[i], characters[j], characters[k]]
				var total := 0
				for character in trio:
					total += int(character["grade"])
				# 너무 약한 조합은 빼고, 포인트를 거의 다 쓰는 조합만 쓴다.
				if total <= point_limit and total >= point_limit - 1:
					combos.append(trio)
	if combos.is_empty():
		return {}
	var trio: Array = combos[rng.randi_range(0, combos.size() - 1)].duplicate()
	trio.sort_custom(func(a, b): return int(a["attack"]) > int(b["attack"]))
	var attacker: Dictionary = trio.pop_front()
	trio.sort_custom(func(a, b): return int(a["defense"]) > int(b["defense"]))
	var defender: Dictionary = trio.pop_front()
	var supporter: Dictionary = trio.pop_front()
	return {"attack": attacker["id"], "defense": defender["id"], "support": supporter["id"]}

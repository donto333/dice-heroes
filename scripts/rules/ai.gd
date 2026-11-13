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
		var card_index := pick_card(game)
		if card_index >= 0:
			game.play_card(card_index)
		game.roll_move()
		var guard := 0
		while game.awaiting_choice() and guard < 10:
			game.choose_path(choose(game))
			guard += 1
	game.end_turn()


## 고르기의 답. 갈림길이면 골에 가까운 길,
## 상대를 지나칠 때는 내 공격 주사위가 상대 방어 주사위보다 많으면 싸운다.
static func choose(game) -> int:
	if game.choice_kind() == "fight":
		var me: int = game.current
		var attack := int(game.char_of(me, "attack")["attack"])
		var defense := int(game.char_of(1 - me, "defense")["defense"])
		return 0 if attack > defense else 1
	return game.best_option(game.pending_choice["options"])


## 이번 턴에 쓸 카드의 순번. 쓸 만한 카드가 없으면 -1.
static func pick_card(game) -> int:
	var hand: Array = game.players[game.current]["hand"]
	for index in hand.size():
		if game.can_play_card(index) and card_useful(game, game.cards[hand[index]]):
			return index
	return -1


## 지금 쓰면 손해이거나 아무 일도 없는 카드를 거른다.
static func card_useful(game, card: Dictionary) -> bool:
	var me: int = game.current
	var other_hand: Array = game.players[1 - me]["hand"]
	match str(card["effect"].get("type", "")):
		"swap":
			return game.distance_of(1 - me) < game.distance_of(me)
		"discard_enemy":
			return not other_hand.is_empty()
		"steal_card":
			return not other_hand.is_empty() and game.players[me]["hand"].size() < game.HAND_LIMIT
		"draw_card":
			return game.players[me]["hand"].size() < game.HAND_LIMIT
	return true


## AI 파티를 고른다. 포인트 제한 안에서 무작위로 세 명을 뽑고,
## 공격이 가장 높은 캐릭터를 ATTACK, 남은 중 방어가 높은 쪽을 DEFENSE, 나머지를 SUPPORT에 앉힌다.
static func pick_party(characters: Array, point_limit: int, rng: RandomNumberGenerator) -> Dictionary:
	# 캐릭터가 많아 모든 조합을 만들면 느리므로, 무작위로 뽑아 조건에 맞을 때까지 다시 뽑는다.
	# 너무 약한 조합은 빼고, 포인트를 거의 다 쓰는 조합만 쓴다.
	var count := characters.size()
	if count < 3:
		return {}
	var trio: Array = []
	for attempt in 5000:
		var i := rng.randi_range(0, count - 1)
		var j := rng.randi_range(0, count - 1)
		var k := rng.randi_range(0, count - 1)
		if i == j or i == k or j == k:
			continue
		var total := int(characters[i]["grade"]) + int(characters[j]["grade"]) + int(characters[k]["grade"])
		if total <= point_limit and total >= point_limit - 1:
			trio = [characters[i], characters[j], characters[k]]
			break
	if trio.is_empty():
		return {}
	trio.sort_custom(func(a, b): return int(a["attack"]) > int(b["attack"]))
	var attacker: Dictionary = trio.pop_front()
	trio.sort_custom(func(a, b): return int(a["defense"]) > int(b["defense"]))
	var defender: Dictionary = trio.pop_front()
	var supporter: Dictionary = trio.pop_front()
	return {"attack": attacker["id"], "defense": defender["id"], "support": supporter["id"]}

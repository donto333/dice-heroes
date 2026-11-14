extends RefCounted
## 프로토타입용 단순한 AI. 쓸 수 있는 어빌리티와 카드를 쓰고 주사위를 굴린다.
## 갈림길에서는 골까지 가까운 길을 고른다.
## 판단을 잘하는 AI가 아니라, 규칙이 끝까지 돌아가는지 확인하는 상대다.

## 현재 차례인 플레이어의 한 턴을 끝까지 진행한다.
static func take_turn(game) -> void:
	if game.winner >= 0:
		return
	if game.begin_turn():
		var slot := pick_ability(game)
		if slot != "":
			game.use_ability(slot)
		var card_index := pick_card(game)
		if card_index >= 0:
			game.play_card(card_index)
		# AI는 늘 높게 노린다(성공 확률은 사람과 같다).
		game.roll_move("high")
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


## 이번 턴에 쓸 어빌리티의 자리. 없으면 "".
## 한 턴에 하나만 쓸 수 있으므로 ★★★ 전용을 먼저 쓰고, 나머지는 턴마다 순서를 돌려 고르게 쓴다.
static func pick_ability(game) -> String:
	var ready: Array = []
	for slot in game.SLOTS:
		if game.can_use_ability(slot):
			ready.append(slot)
	if ready.is_empty():
		return ""
	for slot in ready:
		var ability_id := str(game.char_of(game.current, slot).get("ability", ""))
		if ability_id.begins_with("unique_"):
			return slot
	return ready[int(game.round_number) % ready.size()]


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
		"comeback":
			# 쓸 수 있는 조건(10칸 이상 뒤처짐)이면 늘 쓸 만하다.
			return game.card_condition_met(card)
		"discard_enemy":
			return not other_hand.is_empty()
		"steal_card":
			return not other_hand.is_empty() and game.players[me]["hand"].size() < game.HAND_LIMIT
		"draw_card":
			return game.players[me]["hand"].size() < game.HAND_LIMIT
	return true


## AI 파티를 고른다. 포인트 제한 안의 조합을 무작위로 여러 개 뽑아,
## 자리 배치까지 따져 가장 점수가 높은 조합을 쓴다. 매번 뽑는 조합이 달라서 상대가 다양하다.
const PARTY_SAMPLES := 12

static func pick_party(characters: Array, point_limit: int, rng: RandomNumberGenerator, samples: int = PARTY_SAMPLES) -> Dictionary:
	var count := characters.size()
	if count < 3:
		return {}
	var best := {}
	var best_score := -1
	var found := 0
	for attempt in 5000:
		if found >= samples:
			break
		var i := rng.randi_range(0, count - 1)
		var j := rng.randi_range(0, count - 1)
		var k := rng.randi_range(0, count - 1)
		if i == j or i == k or j == k:
			continue
		var total := int(characters[i]["grade"]) + int(characters[j]["grade"]) + int(characters[k]["grade"])
		# 너무 약한 조합은 빼고, 포인트를 거의 다 쓰는 조합만 쓴다.
		if total > point_limit or total < point_limit - 1:
			continue
		found += 1
		var placed := best_placement([characters[i], characters[j], characters[k]])
		if int(placed["score"]) > best_score:
			best_score = int(placed["score"])
			best = placed["party"]
	return best


## 세 명을 자리에 앉히는 6가지 방법 중 점수가 가장 높은 배치.
static func best_placement(trio: Array) -> Dictionary:
	var orders := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
	var best := {}
	var best_score := -1
	for order in orders:
		var a: Dictionary = trio[order[0]]
		var d: Dictionary = trio[order[1]]
		var s: Dictionary = trio[order[2]]
		var score := slot_score(a, "attack") + slot_score(d, "defense") + slot_score(s, "support")
		if score > best_score:
			best_score = score
			best = {"attack": a["id"], "defense": d["id"], "support": s["id"]}
	return {"party": best, "score": best_score}


## 캐릭터가 그 자리에서 얼마나 쓸모 있는지 대강 매긴 점수.
static func slot_score(character: Dictionary, slot: String) -> int:
	match slot:
		"attack":
			return int(character["attack"]) * 4 + int(character["move"]) * 3
		"defense":
			return int(character["defense"]) * 3
	return int(character["intellect"]) * 2

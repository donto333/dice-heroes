extends RefCounted
## 프로토타입용 단순한 AI. 쓸 수 있는 어빌리티와 카드를 쓰고 주사위를 굴린다.
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
	game.end_turn()

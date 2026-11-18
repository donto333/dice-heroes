extends SceneTree
## 화면 사진 찍기. CI에서 가상 화면(xvfb)으로 게임을 띄워 주요 장면을 PNG로 저장한다.
## 사람이 보지 않아도 화면이 깨졌는지 확인하려고 쓴다. 결과는 환경 변수 SHOT_DIR 폴더(없으면 /tmp/screenshots)에 생긴다.
## 실행: SHOT_DIR=$PWD/screenshots godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/capture.gd
## 타이틀 → 로그인 → 로비 → 출석 → 영웅 → 상점·소환 → 미션 → 설정 → 파티 → 대전 → 전투 → 결과 순서로 찍는다.

const MAIN_SCENE := "res://scenes/main.tscn"
const SaveStore := preload("res://scripts/save_store.gd")
const Dialog := preload("res://scripts/ui/dialog.gd")
const MatchLauncher := preload("res://scripts/ui/match_launcher.gd")

var _app: Node
var _out_dir := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	_out_dir = OS.get_environment("SHOT_DIR")
	if _out_dir == "":
		_out_dir = "/tmp/screenshots"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	SaveStore.erase()
	_app = load(MAIN_SCENE).instantiate()
	root.add_child(_app)
	await _wait(0.5)
	await _shot("00_title_loading")
	await _wait(1.2)
	await _shot("01_title")
	# 오프닝 영상 장면 두 개
	var opening = load("res://scripts/ui/opening.gd").new()
	_app.add_child(opening)
	await _wait(1.6)
	await _shot("00b_opening")
	opening._next()
	await _wait(1.4)
	await _shot("00c_opening2")
	# 장면이 적으면 _next()로 이미 끝나 스스로 사라졌을 수 있다.
	if is_instance_valid(opening) and not opening.is_queued_for_deletion():
		opening.queue_free()
	await _frames(3)
	# 여기부터는 기다림·전환 효과 없이 바로바로 넘어가게 한다(사진 순서가 흔들리지 않게).
	_app.instant = true

	# 진짜로 화면을 눌러서 로그인 화면으로 넘어가는지 확인한다.
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.position = Vector2(360, 640)
	tap.global_position = tap.position
	tap.pressed = true
	root.push_input(tap)
	var release := tap.duplicate()
	release.pressed = false
	root.push_input(release)
	await _wait(0.5)
	if _app.current_name == "login":
		print("터치 확인: 타이틀을 누르면 로그인으로 넘어감")
	else:
		printerr("터치 실패: 타이틀을 눌러도 넘어가지 않음 (지금 화면: %s)" % _app.current_name)
		_app.go("login")
	var login = _app.current_screen
	login._name_edit.text = "주사위왕"
	login._on_text_changed("주사위왕")
	await _frames(5)
	await _shot("02_login")
	login._on_start_pressed()
	await _wait(0.6)
	await _shot("03_welcome")
	_close_dialogs()
	_app.current_screen._maybe_attendance()
	await _wait(0.6)
	await _shot("04_attendance")
	_close_dialogs()
	_app.current_screen._claim_attendance()
	await _wait(0.5)
	await _shot("05_lobby")
	_close_dialogs()
	_app.current_screen.open_roulette()
	await _wait(0.4)
	_app.current_screen._on_spin()
	await _wait(4.0)
	await _shot("05c_roulette")
	_close_dialogs()
	_app.go("lobby")
	await _wait(0.4)
	_close_dialogs()
	_app.loading.show_for("대전 준비 중...", 1.5, true)
	await _wait(0.6)
	await _shot("05g_loading")
	await _wait(1.4)
	_app.current_screen.open_mailbox()
	await _wait(0.4)
	await _shot("05f_mailbox")
	_close_dialogs()
	await _wait(0.2)
	_app.current_screen.open_todo()
	await _wait(0.4)
	await _shot("05i_todo")
	_close_dialogs()
	await _wait(0.2)
	_app.current_screen.open_odd_even()
	await _wait(0.3)
	_app.current_screen._on_odd_even("odd")
	await _wait(0.3)
	await _shot("05j_odd_even")
	_close_dialogs()
	_app.profile["pass"]["exp"] = 260
	_app.go("shop", {"tab": "pass"})
	await _wait(0.4)
	await _shot("05h_pass")
	_app.go("lobby")
	await _wait(0.4)
	_close_dialogs()
	_app.show_profile()
	await _wait(0.4)
	await _shot("05d_profile")
	_close_dialogs()
	_app.show_league()
	await _wait(0.4)
	await _shot("05e_league")
	_close_dialogs()
	_app.current_screen._choose_difficulty()
	await _wait(0.4)
	await _shot("05b_ai_difficulty")
	_close_dialogs()

	_app.go("heroes")
	await _wait(0.4)
	await _shot("06_heroes")
	_app.go("heroes", {"view": "album"})
	await _wait(0.4)
	await _shot("06a_album")
	_app.go("party", {"purpose": "edit"})
	await _wait(0.4)
	await _shot("06b_formation")
	_app.go("heroes")
	await _wait(0.4)
	_app.current_screen.show_hero("lubu")
	await _wait(0.5)
	await _shot("07_hero_detail")
	_close_dialogs()

	_app.profile["gems"] = int(_app.profile["gems"]) + 3000
	_app.go("shop")
	await _wait(0.4)
	await _shot("08_shop")
	for part in [["grow", "08c_shop_grow"], ["look", "08b_dice_shop"], ["gems", "08e_shop_gems"]]:
		_app.go("shop", {"tab": str(part[0])})
		await _wait(0.4)
		await _shot(str(part[1]))
	_app.go("shop")
	await _wait(0.4)
	_app.current_screen._on_paid(10)
	await _wait(2.0)
	await _shot("09_summon")
	# 소환 연출(전체 화면)을 닫는다.
	for child in _app.get_children():
		if child.has_method("_hero_cut"):
			child._close(false)
	await _wait(0.4)
	_close_dialogs()
	# 소환 연출을 처음부터 끝까지(★★★ 등장 컷 포함): 정해 둔 결과로 연출만 돌려 장면마다 찍는다.
	var summon_show = load("res://scripts/ui/summon_show.gd").new()
	_app.add_child(summon_show)
	_app.instant = false
	summon_show.play(_app, [
		{"id": "lubu", "grade": 3, "new": true, "shards": 0},
		{"id": "machao", "grade": 2, "new": false, "shards": 5},
		{"id": "earhart", "grade": 1, "new": true, "shards": 0},
	], 300)
	await _wait(1.6)
	await _shot("09a_summon_die")
	await _wait(2.7)
	await _shot("09b_summon_gold")
	await _wait(1.2)
	await _shot("09c_summon_cards")
	await _wait(1.5)
	await _shot("09d_summon_hero")
	summon_show._on_skip()
	await _wait(1.0)
	await _shot("09e_summon_result")
	_app.instant = true
	summon_show._close(false)
	await _wait(0.3)

	# 카드(2026-11-18): 영웅 메뉴의 카드 목록·카드 편성, 상점의 골드 소환·카드 뽑기, 10장 뽑기 결과
	_app.go("heroes", {"view": "cards"})
	await _wait(0.4)
	await _shot("09k_cards_list")
	_app.go("heroes", {"view": "deck"})
	await _wait(0.4)
	await _shot("09f_cards_deck")
	_app.go("heroes", {"view": "card_album"})
	await _wait(0.5)
	await _shot("09l_card_album")
	_app.go("shop")
	await _wait(0.4)
	var shop_scroll := _find_scroll(_app.current_screen)
	if shop_scroll != null:
		shop_scroll.scroll_vertical = 330
		await _wait(0.2)
	await _shot("09j_shop_gold")
	_app.go("shop", {"tab": "cards"})
	await _wait(0.4)
	await _shot("09g_cards_gacha")
	var card_scroll := _find_scroll(_app.current_screen)
	if card_scroll != null:
		card_scroll.scroll_vertical = 100000
		await _wait(0.2)
	await _shot("09i_cards_gold")
	_app.profile["gems"] = int(_app.profile.get("gems", 0)) + 1000
	var card_panels: Node = null
	for child in _app.current_screen.get_children():
		if child.has_method("build_gacha"):
			card_panels = child
	if card_panels != null:
		card_panels._on_paid_draw(10)
		await _wait(0.6)
		await _shot("09h_cards_result")
	# 카드 뽑기 연출(전체 화면)을 닫는다.
	for child in _app.get_children():
		if child.has_method("_card_cut"):
			child._close(false)
	await _wait(0.4)
	_close_dialogs()
	# 카드 뽑기 연출을 처음부터(★★★ 전설 카드 등장 컷 포함): 정해 둔 결과로 연출만 돌려 찍는다.
	var card_show = load("res://scripts/ui/summon_show.gd").new()
	card_show.kind = "card"
	_app.add_child(card_show)
	_app.instant = false
	card_show.play(_app, [
		{"id": "war_god", "grade": 3, "new": true, "gold": 0},
		{"id": "keen_blade", "grade": 2, "new": false, "gold": 300},
		{"id": "herb", "grade": 1, "new": true, "gold": 0},
	], 30)
	await _wait(5.5)
	await _shot("09m_card_show_cards")
	await _wait(1.5)
	await _shot("09n_card_show_legend")
	card_show._on_skip()
	await _wait(1.0)
	await _shot("09o_card_show_result")
	_app.instant = true
	card_show._close(false)
	await _wait(0.3)

	_app.go("missions")
	await _wait(0.4)
	await _shot("10_missions")
	# 끌어서 내리기 확인: 판 위를 누른 채 위로 300만큼 끌면 스크롤이 내려가야 한다.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(360, 800)
	_app._input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(360, 500)
	_app._input(drag)
	var moved := -1
	if _app._drag_scroll != null:
		moved = _app._drag_scroll.scroll_vertical
	var lift := InputEventMouseButton.new()
	lift.button_index = MOUSE_BUTTON_LEFT
	lift.pressed = false
	lift.position = Vector2(360, 500)
	_app._input(lift)
	print("SCROLLCHECK 미션 화면을 끌어 내린 값: %d" % moved)
	await _wait(0.2)
	await _shot("10a_missions_scrolled")
	_app.go("missions", {"tab": "achievements"})
	await _wait(0.4)
	await _shot("10b_achievements")
	var mission_scroll := _find_scroll(_app.current_screen)
	if mission_scroll != null:
		mission_scroll.scroll_vertical = 100000
		await _wait(0.3)
		await _shot("10b_achievements")
	_app.go("settings")
	await _wait(0.4)
	await _shot("11_settings")
	_app.go("adventure")
	await _wait(0.4)
	await _shot("11a_adventure")
	_app.current_screen._on_stage("1-1")
	await _wait(0.5)
	await _shot("11a2_stage")
	_close_dialogs()
	# 소탕 확인: 별 3개로 깬 것으로 해 두고 소탕 버튼과 소탕 뒤 화면을 찍은 다음 되돌린다.
	var stars_before: Dictionary = (_app.profile["adventure"] as Dictionary).duplicate(true)
	_app.profile["adventure"]["1-1"] = 3
	_app.go("adventure")
	await _wait(0.4)
	_app.current_screen._on_stage("1-1")
	await _wait(0.5)
	await _shot("11a3_sweep")
	_close_dialogs()
	_app.current_screen._sweep("1-1")
	await _wait(0.5)
	await _shot("11a4_swept")
	_app.profile["adventure"] = stars_before
	_app.go("help", {"back": "lobby"})
	await _wait(0.4)
	await _shot("11b_help")

	# 대전 시작 확인 창(파티 편성 + 카드 편성, 확인·취소)
	_app.start_mode("rank")
	await _wait(0.4)
	await _shot("12_start_confirm")
	_close_dialogs()
	_app.go("party", {"purpose": "edit"})
	await _wait(0.4)
	await _shot("12_party")
	var picker = _party_picker()
	picker._on_save_mode_pressed()
	picker._on_preset_pressed(0)
	await _wait(0.3)
	await _shot("12c_presets")
	# 자동 추천 전략 창과 공격형 추천 결과
	_party_picker()._on_auto_pressed()
	await _wait(0.3)
	await _shot("12d_strategies")
	_party_picker()._auto_pick("attack")
	await _wait(0.3)
	await _shot("12e_auto_attack")
	_party_picker()._on_start_pressed()
	await _wait(0.3)
	_app.start_mode("rank")
	await _wait(0.3)
	_app.get_meta("match_launcher").confirm()
	await _wait(0.6)
	await _shot("12a_searching")
	await _wait(2.1)
	await _shot("12b_versus")
	await _wait(2.1)
	await _shot("13_match_banner")
	await _wait(1.6)
	await _shot("14_match")
	_app.current_screen._show_skill_info("attack")
	await _wait(0.3)
	await _shot("14s_skill_info")
	_close_dialogs()
	await _wait(0.2)
	# 연출 확인용 사진: 효과 그림들이 실제로 어떻게 겹쳐 보이는지 한 화면에 터뜨려 찍는다.
	var fx_layer = _app.current_screen.get("_fx")
	if fx_layer != null:
		fx_layer.quiet = false
		var spots := [Vector2(180, 200), Vector2(430, 200), Vector2(680, 200), Vector2(930, 200), Vector2(1150, 200),
			Vector2(180, 470), Vector2(430, 470), Vector2(680, 470), Vector2(930, 470), Vector2(1150, 470)]
		var kinds := ["spark", "coin", "smoke", "star", "petal", "ember", "ice", "impact", "heal", "bolt"]
		for index in kinds.size():
			fx_layer.burst(spots[index], kinds[index], 16, 0.7)
		await _wait(0.16)
		await _shot("14x_fx_bursts")
		await _wait(0.9)
		fx_layer.speed_lines(Vector2(640, 360), Color(0.6, 0.85, 1.0), 1.0)
		fx_layer.rays(true, Vector2(640, 300), Color(1.0, 0.9, 0.4, 0.16))
		fx_layer.shower("petal", 60)
		await _wait(0.5)
		await _shot("14y_fx_screen")
		fx_layer.rays(false)
		await _wait(1.2)
		fx_layer.quiet = true
	var match_screen = _app.current_screen
	match_screen._toggle_emotes()
	match_screen._say(1, "ㅋㅋㅋ")
	match_screen._say(0, "가자!")
	await _wait(0.5)
	await _shot("14c_emotes")
	match_screen._toggle_emotes()
	match_screen._on_card_pressed(0)
	await _wait(0.4)
	await _shot("14b_card")
	_close_dialogs()
	# 관문 칸 확인: 내 말을 첫 관문 바로 앞에 잠깐 세워 사진을 찍고 되돌린다.
	var gate_game = match_screen.game
	var gate_id := -1
	for id in gate_game.nodes:
		if str(gate_game.nodes[id].get("type", "")) == "gate":
			if gate_id < 0 or int(gate_game.dist_to_goal.get(id, 0)) > int(gate_game.dist_to_goal.get(gate_id, 0)):
				gate_id = int(id)
	if gate_id >= 0:
		var before_pos := int(gate_game.players[0]["pos"])
		for id in gate_game.nodes:
			if (gate_game.nodes[id].get("next", []) as Array).has(gate_id):
				gate_game.players[0]["pos"] = int(id)
				break
		match_screen._board_view.reset_pieces()
		match_screen._board_view.focus_on(0)
		await _wait(0.6)
		await _shot("14f_gate")
		gate_game.players[0]["pos"] = before_pos
		match_screen._board_view.reset_pieces()
		match_screen._board_view.focus_on(0)
		await _wait(0.3)
	# 갈림길 안개 확인: 내 말을 첫 갈림길 칸에 잠깐 세워 두 갈래가 안개에 가려진 모습을 찍고 되돌린다.
	var fork_id := -1
	for id in gate_game.nodes:
		if (gate_game.nodes[id].get("next", []) as Array).size() > 1:
			if fork_id < 0 or int(gate_game.dist_to_goal.get(id, 0)) > int(gate_game.dist_to_goal.get(fork_id, 0)):
				fork_id = int(id)
	if fork_id >= 0:
		var fork_before := int(gate_game.players[0]["pos"])
		gate_game.players[0]["pos"] = fork_id
		match_screen._board_view.reset_pieces()
		match_screen._board_view.focus_on(0)
		await _wait(0.6)
		await _shot("14g_branch_fog")
		gate_game.players[0]["pos"] = fork_before
		match_screen._board_view.reset_pieces()
		match_screen._board_view.focus_on(0)
		await _wait(0.3)
	match_screen._cutin.play(_app.character("lubu"), "천하무쌍", "2턴간 공격 주사위 +2개", Color("4fc3f7"))
	await _wait(0.6)
	await _shot("14e_cutin")
	await _wait(0.8)
	match_screen._aim_bar.start()
	await _wait(0.75)
	await _shot("14d_aim_bar")
	match_screen._aim_bar.stop()
	match_screen._on_roll_pressed()
	await _wait(0.95)
	await _shot("15a_big_dice")
	await _wait(1.3)
	await _shot("15_after_roll")

	var fake_battle := {
		"kind": "battle", "target": "keeper", "player": 0,
		"attacker": "여포", "defender": "메두사",
		"attack_rolls": [6, 5, 3, 2, 1], "defense_rolls": [4, 4, 3, 2],
		"attack_total": 17, "defense_total": 13, "won": true,
	}
	# 자동 진행 중인 컷인·알림이 전투 창을 가리지 않게 맨 앞으로 올린다.
	match_screen.move_child(match_screen._battle_overlay, match_screen.get_child_count() - 1)
	match_screen._battle_overlay.play(fake_battle, {
		"boss_name": "메두사",
		"attacker_side": "공격 · 나", "defender_side": "방어 · 골의 수호자",
		"attacker_color": Color("4fc3f7"), "defender_color": Color("ffcf66"),
		"winner_text": "나 승리!", "loser_text": "나 패배...", "good_for_me": true,
		"attacker_character": _app.character("lubu"),
	})
	await _wait(1.2)
	await _shot("16a_battle_rolling")
	await _wait(2.3)
	await _shot("16_battle")
	await _wait(2.4)

	if _app.current_screen == match_screen and match_screen.game != null:
		match_screen.game.winner = 0
		match_screen._show_game_over()
		await _wait(0.8)
		await _shot("17_result")

	_app.start_mode("local")
	await _wait(0.4)
	await _shot("18_party_local")
	MatchLauncher.for_map(_app).pick_map({})
	await _wait(0.4)
	await _shot("18b_map_pick")
	_close_dialogs()
	_app.go("lobby")
	await _wait(0.4)
	await _shot("19_lobby_after")
	_close_dialogs()
	# 다른 언어 화면(lang.gd): 영어 5장, 베트남어 2장을 찍고 한국어로 돌아온다.
	for item in [["en", ["lobby", "heroes", "shop", "settings", "help"]], ["vi", ["lobby", "shop"]]]:
		Lang.use(str(item[0]))
		for screen_name in item[1]:
			_app.go(str(screen_name))
			await _wait(0.5)
			await _shot("30_%s_%s" % [item[0], screen_name])
			_close_dialogs()
	Lang.use("ko")
	await _play_full_game()
	# 세로로 든 화면: 게임이 스스로 돌아 가로로 그려지는지 확인한다(로비와 영웅 화면).
	root.size = Vector2i(720, 1280)
	_app.go("lobby")
	await _wait(0.6)
	await _shot("22_upright_lobby")
	_app.go("heroes")
	await _wait(0.6)
	await _shot("23_upright_heroes")
	_app.dialog("세로 화면 시험", Label.new(), [["확인"]], 520)
	await _wait(0.4)
	await _shot("24_upright_dialog")
	quit(0)


func _close_dialogs() -> void:
	for child in _app.get_children():
		if child.get_script() == Dialog:
			child.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	image.save_png(path)
	print("사진 저장: ", path)


func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var found := _find_scroll(child)
		if found != null:
			return found
	return null


## 파티 화면 안의 파티 고르기 칸(PartySelect). 시안식 틀 안에 들어가 있어 깊이 찾는다.
func _party_picker() -> Node:
	var found = _find_with(_app.current_screen, "_on_start_pressed")
	return found if found != null else _app.current_screen.get_child(0)


func _find_with(node: Node, method: String) -> Node:
	for child in node.get_children():
		if child.has_method(method):
			return child
		var deeper = _find_with(child, method)
		if deeper != null:
			return deeper
	return null


## 한 판을 처음부터 끝까지 자동으로 해 본다(빠르게). 실제 흐름에서 스크립트 오류가 나는지 보는 용도.
## 내 차례면 굴리고, 갈림길·싸움 선택은 첫 번째를 고르고, VS·전투 화면은 바로 넘긴다.
func _play_full_game() -> void:
	_app.start_mode("rank")
	await _wait(0.4)
	_app.get_meta("match_launcher").confirm()
	await _wait(0.3)
	var screen = _app.current_screen
	Engine.time_scale = 10.0
	var steps := 0
	var rolls := 0
	var choices := 0
	while steps < 1600:
		steps += 1
		await _wait(0.5)
		if _app.current_screen != screen or screen.game == null:
			break
		_close_dialogs()
		screen._versus._skipped = true
		screen._battle_overlay._skip = true
		if screen.game.winner >= 0:
			break
		if screen._choosing_path and screen.game.awaiting_choice() and not screen._board_view.is_busy():
			choices += 1
			screen._on_path_chosen(0)
		elif screen._waiting_for_player:
			rolls += 1
			if rolls == 2:
				screen._on_emote("가자!")
			screen._on_roll_pressed()
		# 중간부터는 자동 진행을 켜서 그 흐름도 확인한다.
		if steps == 200 and not screen._auto:
			screen._on_auto_pressed()
		if steps == 60:
			Engine.time_scale = 1.0
			await _shot("20_midgame")
			Engine.time_scale = 10.0
	Engine.time_scale = 1.0
	await _wait(1.2)
	await _shot("21_game_end")
	if screen.game != null:
		print("FULLGAME 끝: 승자 %d · %d턴 · 굴림 %d번 · 선택 %d번 · 확인 %d번" % [int(screen.game.winner), int(screen.game.round_number), rolls, choices, steps])

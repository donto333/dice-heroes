extends SceneTree
## 화면 사진 찍기. CI에서 가상 화면(xvfb)으로 게임을 띄워 주요 장면을 PNG로 저장한다.
## 사람이 보지 않아도 화면이 깨졌는지 확인하려고 쓴다. 결과는 환경 변수 SHOT_DIR 폴더(없으면 /tmp/screenshots)에 생긴다.
## 실행: SHOT_DIR=$PWD/screenshots godot --rendering-driver opengl3 --resolution 720x1280 --script res://tools/capture.gd
## 타이틀 → 로그인 → 로비 → 출석 → 영웅 → 상점·소환 → 미션 → 설정 → 파티 → 대전 → 전투 → 결과 순서로 찍는다.

const MAIN_SCENE := "res://scenes/main.tscn"
const SaveStore := preload("res://scripts/save_store.gd")
const Dialog := preload("res://scripts/ui/dialog.gd")

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
	await _wait(1.0)
	await _shot("01_title")

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
	_app.current_screen.show_hero("lubu")
	await _wait(0.5)
	await _shot("07_hero_detail")
	_close_dialogs()

	_app.profile["gems"] = int(_app.profile["gems"]) + 3000
	_app.go("shop")
	await _wait(0.4)
	await _shot("08_shop")
	_app.current_screen._on_paid(10)
	await _wait(2.0)
	await _shot("09_summon")
	_close_dialogs()

	_app.go("missions")
	await _wait(0.4)
	await _shot("10_missions")
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
	_app.go("help", {"back": "lobby"})
	await _wait(0.4)
	await _shot("11b_help")

	_app.start_mode("rank")
	await _wait(0.4)
	await _shot("12_party")
	_app.current_screen.get_child(0)._on_start_pressed()
	await _wait(1.0)
	await _shot("12b_versus")
	await _wait(2.1)
	await _shot("13_match_banner")
	await _wait(1.6)
	await _shot("14_match")
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
	match_screen._battle_overlay.play(fake_battle, {
		"attacker_side": "공격 · 나", "defender_side": "방어 · 키퍼",
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
	_app.current_screen._pick_map({})
	await _wait(0.4)
	await _shot("18b_map_pick")
	_close_dialogs()
	_app.go("lobby")
	await _wait(0.4)
	await _shot("19_lobby_after")
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

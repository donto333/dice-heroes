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
	_app.go("settings")
	await _wait(0.4)
	await _shot("11_settings")

	_app.start_mode("rank")
	await _wait(0.4)
	await _shot("12_party")
	_app.current_screen.get_child(0)._on_start_pressed()
	await _frames(10)
	await _shot("13_match_banner")
	await _wait(1.6)
	await _shot("14_match")
	var match_screen = _app.current_screen
	match_screen._on_roll_pressed()
	await _wait(1.4)
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
	await _wait(2.0)
	await _shot("16_battle")
	await _wait(3.0)

	if _app.current_screen == match_screen and match_screen.game != null:
		match_screen.game.winner = 0
		match_screen._show_game_over()
		await _wait(0.8)
		await _shot("17_result")

	_app.start_mode("local")
	await _wait(0.4)
	await _shot("18_party_local")
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

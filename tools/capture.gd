extends SceneTree
## 화면 사진 찍기. CI에서 가상 화면(xvfb)으로 게임을 띄워 주요 장면을 PNG로 저장한다.
## 사람이 보지 않아도 화면이 깨졌는지 확인하려고 쓴다. 결과는 환경 변수 SHOT_DIR 폴더(없으면 /tmp/screenshots)에 생긴다.
## 실행: SHOT_DIR=$PWD/screenshots godot --rendering-driver opengl3 --resolution 720x1280 --script res://tools/capture.gd

const MAIN_SCENE := "res://scenes/main.tscn"

var _main: Node
var _out_dir := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	_out_dir = OS.get_environment("SHOT_DIR")
	if _out_dir == "":
		_out_dir = "/tmp/screenshots"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_main = load(MAIN_SCENE).instantiate()
	root.add_child(_main)
	await _frames(20)
	await _shot("01_party_select")

	# 분류 탭: 신화만 보기
	_main._party_select._on_filter_pressed("신화")
	_main._party_select._show_info("zeus")
	await _frames(5)
	await _shot("02_party_filter")
	_main._party_select._on_filter_pressed("")

	# 게임 시작
	_main._party_select._on_start_pressed()
	await _frames(10)
	await _shot("03_turn_banner")
	await _wait(1.5)
	await _shot("04_board")

	# 내 차례에 주사위 굴리기
	_main._on_roll_pressed()
	await _wait(1.2)
	await _shot("05_after_roll")

	# 전투 화면 (실제 전투 대신 보기용 사건을 넣는다)
	var fake_battle := {
		"kind": "battle", "target": "keeper", "player": 0,
		"attacker": "여포", "defender": "메두사",
		"attack_rolls": [6, 5, 3, 2, 1], "defense_rolls": [4, 4, 3, 2],
		"attack_total": 17, "defense_total": 13, "won": true,
	}
	_main._battle_overlay.play(fake_battle, {
		"attacker_side": "공격 · 나", "defender_side": "방어 · 키퍼",
		"attacker_color": Color("4fc3f7"), "defender_color": Color("ffcf66"),
		"winner_text": "나 승리!", "loser_text": "나 패배...", "good_for_me": true,
	})
	await _wait(2.0)
	await _shot("06_battle")
	await _wait(3.0)

	# 결과 화면
	_main._result_overlay.show_result("win", "승리! 골에 먼저 들어갔습니다.", PackedStringArray([
		"진행한 턴: 9턴", "골까지 남은 거리: 나 0칸 · AI 7칸", "내 전투: 5승 1패",
		"내 파티: 여포 · 아테나 · 최치원", "AI 파티: 마초 · 제우스 · 해리 후디니"]))
	await _wait(0.8)
	await _shot("07_result")
	quit(0)


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

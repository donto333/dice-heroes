extends Control
## 보상형 광고(2026-11-19, 정식 출시 준비 5번). 광고를 끝까지 보면 true를 돌려준다.
## 지금은 진짜 광고(AdMob)가 붙지 않아 economy.json ads.test_seconds초 동안 '시험 광고' 화면을 보여 준다.
## 진짜 광고를 붙일 때는 play() 안에서 AdMob 보상형 광고를 띄우고, 보상 알림(onUserEarnedReward)을 받으면 true를 돌려주면 된다.
## 보상 지급과 횟수 세기는 규칙 코드 Profile.watch_ad가 한다.
## 쓰는 법: var ad := AdPlayer.new(); app.add_child(ad); if await ad.play(app): Profile.watch_ad(...)

const Kit := preload("res://scripts/ui/kit.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")

var _count: Label


func play(app) -> bool:
	add_to_group("modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.08, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := Kit.vbox(18)
	center.add_child(column)
	column.add_child(Kit.title("광고", 48))
	column.add_child(Kit.para("시험 광고예요. 정식 출시 때는 여기에 진짜 광고가 나와요.", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	_count = Kit.label("", 30, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_count)
	var seconds := int(app.eco.get("ads", {}).get("test_seconds", 5))
	if bool(app.get("instant")):
		seconds = 0
	for left in range(seconds, 0, -1):
		_count.text = "%d초 뒤에 보상을 받아요" % left
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return false
	queue_free()
	return true

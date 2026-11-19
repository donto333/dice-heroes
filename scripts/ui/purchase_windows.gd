extends RefCounted
## 구매 확인 창과 구매 내역 창(2026-11-19, 정식 출시 준비 2·3번).
## 아직 결제가 연결되지 않아(economy.json gem_packs.open=false) 확인 창의 결제 버튼은 '정식 출시 때 열려요'로 꺼져 있다.
## 결제가 붙으면 결제 → 서버 영수증 확인 → Profile.record_purchase 순서로 보석을 준다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")


static func won(price: int) -> String:
	return "₩%s" % Kit.comma(price)


## 상품을 누르면 뜨는 확인 창: 가격·받는 것·환불 규칙.
static func confirm(app, id: String) -> Control:
	app.play("click")
	var pack := Profile.gem_pack(app.eco, id)
	var contents := Profile.pack_contents(app.profile, app.eco, id)
	var body := Kit.vbox(12)
	var top := MenuArt.row(12)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(top)
	var line := Kit.hbox(12)
	top.add_child(line)
	line.add_child(Kit.icon("gem", 64.0))
	var words := Kit.vbox(4)
	line.add_child(Kit.expand(words))
	words.add_child(Kit.label(str(pack.get("name", id)), 28, Kit.GOLD))
	var gets := "유료 보석 %s" % Kit.comma(int(contents["gems"]))
	if int(contents["bonus"]) > 0:
		gets = "유료 보석 %s + 덤 %s" % [Kit.comma(int(contents["gems"])), Kit.comma(int(contents["bonus"]))]
	words.add_child(Kit.label(gets, 22, Kit.GEM))
	if int(pack.get("daily", 0)) > 0:
		words.add_child(Kit.label("그리고 %d일 동안 매일 보석 %d" % [int(pack.get("days", 30)), int(pack.get("daily", 0))], 20, Color.WHITE))
	line.add_child(Kit.label(won(int(pack.get("price", 0))), 30, Color.WHITE))
	body.add_child(Kit.para(rules_text(app), 17, Kit.MUTED))
	var open := bool(app.eco.get("gem_packs", {}).get("open", false))
	var pay := MenuArt.pill_button("%s 결제" % won(int(pack.get("price", 0))) if open else "정식 출시 때 열려요", "gold" if open else "gray", "l")
	pay.disabled = not open
	body.add_child(pay)
	var window: Control = app.dialog("구매 확인", body, [["닫기", Kit.PANEL_LIGHT]], 720)
	app.set_meta("purchase_window", window)
	return window


static func rules_text(app) -> String:
	var days := int(app.eco.get("gem_packs", {}).get("refund_days", 7))
	return "\n".join(PackedStringArray([
		"· 가격은 부가세가 포함된 금액이에요.",
		"· 산 지 %d일 안이고 받은 보석을 쓰지 않았다면 청약 철회(환불)할 수 있어요." % days,
		"· 환불하면 그 구매로 받은 보석(덤 포함)을 되돌려요.",
		"· 무료 보석을 먼저 쓰고, 유료 보석은 나중에 써요.",
		"· 미성년자가 법정대리인 동의 없이 산 경우 취소할 수 있어요.",
	]))


## 구매 내역 창: 유료·무료 보석과 산 기록.
static func history(app) -> Control:
	app.play("click")
	var body := Kit.vbox(10)
	var caps := Kit.hbox(8)
	caps.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(caps)
	caps.add_child(MenuArt.capsule("유료 보석 %s" % Kit.comma(Profile.paid_gems(app.profile)), "gem", 20))
	caps.add_child(MenuArt.capsule("무료 보석 %s" % Kit.comma(Profile.free_gems(app.profile)), "gem", 20))
	var list: Array = app.profile.get("purchases", [])
	if list.is_empty():
		body.add_child(Kit.para("아직 산 상품이 없어요.", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	for index in range(list.size() - 1, -1, -1):
		var entry: Dictionary = list[index]
		var row := MenuArt.row(10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(row)
		var line := Kit.hbox(10)
		row.add_child(line)
		var words := Kit.vbox(2)
		line.add_child(Kit.expand(words))
		words.add_child(Kit.label(str(entry.get("name", "")), 22, Color.WHITE))
		words.add_child(Kit.label(str(entry.get("at", "")), 16, Kit.MUTED))
		line.add_child(Kit.label("보석 %s" % Kit.comma(int(entry.get("gems", 0)) + int(entry.get("bonus", 0))), 20, Kit.GEM))
		line.add_child(Kit.label(won(int(entry.get("price", 0))), 20, Color.WHITE))
		if bool(entry.get("refunded", false)):
			line.add_child(Kit.label("환불됨", 18, Kit.MUTED))
	body.add_child(Kit.para("결제한 스토어(구글 플레이)의 주문 내역에서도 확인할 수 있어요.", 16, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var window: Control = app.dialog("구매 내역", body, [["닫기", Kit.PANEL_LIGHT]], 760)
	app.set_meta("purchase_window", window)
	return window

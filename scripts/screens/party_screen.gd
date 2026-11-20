extends Control
## 파티 고르기 화면을 감싼다. 쓰임새(purpose)에 따라 글자와 다음 화면이 다르다.
##   edit  : 영웅 화면의 파티 편성. 가진 영웅만 고를 수 있고, 정하면 저장.
##   match : 친구 대전 직전(mode local). 두 사람 모두 48명 전부에서 고른다.
## 랭크전·AI 연습전·모험·오늘의 도전은 이 화면을 거치지 않고 시작 확인 창(match_launcher.gd)을 띄운다.

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const PartySelect := preload("res://scripts/ui/party_select.gd")
const AI := preload("res://scripts/rules/ai.gd")
const Game := preload("res://scripts/rules/game.gd")
const MatchLauncher := preload("res://scripts/ui/match_launcher.gd")

var app
var _params: Dictionary = {}


## 이 화면에서 쓰는 소환 포인트 한도(내 레벨 기준, 친구 대전은 고정값)
var _limit := Game.POINT_LIMIT


## 한도가 다음에 늘어나는 레벨 안내. 더 없으면 빈 글.
func _next_limit_text() -> String:
	var step: Dictionary = Game.next_point_step(app.data["rules"], int(app.profile.get("level", 1)))
	return "" if step.is_empty() else " (플레이어 레벨 %d에 %d로 늘어요)" % [int(step["level"]), int(step["limit"])]


func setup(main_app, params: Dictionary) -> void:
	app = main_app
	_params = params
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var purpose := str(params.get("purpose", "edit"))
	var mode := str(params.get("mode", ""))
	var player := int(params.get("player", 1))
	# 시안식 틀: 파티 편성은 영웅 화면과 같은 왼쪽 항목 판, 대전 전 파티 확인은 큰 판만.
	var rail: Array = []
	if purpose == "edit":
		# 로비 '편성' 메뉴(2026-11-18 사용자 결정): 파티 편성 · 카드 편성
		rail = [["party", "파티 편성", "swords"], ["deck", "카드 편성", "todo"]]
		set_meta("title_spec", ["편성", "swords"])
	var holder := MenuArt.frame(self, app, "ui/bg_party", rail, "party", _on_rail)
	var select := PartySelect.new()
	select.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(select)
	var characters: Array = app.owned_characters()
	var initial: Dictionary = app.profile["party"]
	_limit = app.point_limit()
	if mode == "local":
		_limit = int(app.data["rules"].get("local_point_limit", _limit))
	var options := {"cancel_text": "뒤로", "levels": app.owned_levels(), "point_limit": _limit, "framed": true, "narrow": purpose == "edit"}
	if purpose == "edit":
		options["title"] = "파티 편성"
		options["subtitle"] = "가진 영웅 %d명 중에서 골라요. 소환 포인트(★ 합계)는 %d까지.%s" % [characters.size(), _limit, _next_limit_text()]
		options["confirm_text"] = "저장"
	elif mode == "local":
		characters = app.data["characters"]
		options["levels"] = {}
		options["title"] = "친구 대전 · 플레이어 %d" % player
		options["subtitle"] = "플레이어 %d가 파티를 고르세요. 친구 대전은 48명 모두 쓸 수 있고 소환 포인트는 %d까지예요." % [player, _limit]
		options["confirm_text"] = "다음" if player == 1 else "대전 시작"
		if player == 2:
			initial = {"attack": "", "defense": "", "support": ""}
	# 내 영웅으로 파티를 짤 때만 저장 칸을 보여 준다(친구 대전은 48명을 다 쓰므로 제외).
	if mode != "local":
		options["presets"] = app.profile.get("party_presets", [{}, {}, {}])
		select.preset_saved.connect(_on_preset_saved)
	select.setup(app, characters, app.data["abilities"], initial, options)
	select.confirmed.connect(_on_confirmed)
	select.cancelled.connect(_on_cancelled)


func _on_rail(id: String) -> void:
	if id == "party":
		return
	app.play("tab")
	app.go("heroes", {"view": "deck"})


func _on_preset_saved(index: int, party: Dictionary) -> void:
	if Profile.save_preset(app.profile, app.data["characters"], index, party, _limit):
		app.save()
		app.play("good")


func _on_confirmed(party: Dictionary) -> void:
	var purpose := str(_params.get("purpose", "edit"))
	var mode := str(_params.get("mode", ""))
	app.play("good")
	if purpose == "edit":
		if Profile.party_ok(app.profile, app.data["characters"], party, _limit):
			app.profile["party"] = party.duplicate()
			app.save()
			app.toast("파티를 저장했어요.")
			app.tutorial_event("party")
		app.go("party", {"purpose": "edit"})
		return
	if mode == "local":
		if int(_params.get("player", 1)) == 1:
			app.go("party", {"purpose": "match", "mode": "local", "player": 2, "first": party})
			return
		var first: Dictionary = _params.get("first", {}).duplicate()
		first["name"] = "플레이어 1"
		var second := party.duplicate()
		second["name"] = "플레이어 2"
		MatchLauncher.for_map(app).pick_map({"mode": "local", "parties": [first, second], "humans": [true, true]})
		return
	# 그 밖의 쓰임새는 더 없다(시작 확인 창으로 옮겨 감). 혹시 오면 로비로.
	app.go("lobby")


func _on_cancelled() -> void:
	app.play("click")
	app.go("lobby")

extends Control
## 파티 고르기 화면을 감싼다. 쓰임새(purpose)에 따라 글자와 다음 화면이 다르다.
##   edit  : 영웅 화면의 파티 편성. 가진 영웅만 고를 수 있고, 정하면 저장.
##   match : 대전 직전. 랭크전·AI 연습은 가진 영웅만, 친구 대전은 두 사람 모두 48명 전부에서 고른다.

const Kit := preload("res://scripts/ui/kit.gd")
const Profile := preload("res://scripts/rules/profile.gd")
const PartySelect := preload("res://scripts/ui/party_select.gd")
const AI := preload("res://scripts/rules/ai.gd")
const Game := preload("res://scripts/rules/game.gd")

const MODE_TITLES := {"rank": "랭크전", "ai": "AI 연습전", "local": "친구 대전"}

var app
var _params: Dictionary = {}


func setup(main_app, params: Dictionary) -> void:
	app = main_app
	_params = params
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var purpose := str(params.get("purpose", "edit"))
	var mode := str(params.get("mode", ""))
	var player := int(params.get("player", 1))
	var select := PartySelect.new()
	add_child(select)
	var characters: Array = app.owned_characters()
	var initial: Dictionary = app.profile["party"]
	var options := {"cancel_text": "뒤로", "levels": app.owned_levels()}
	if purpose == "edit":
		options["title"] = "파티 편성"
		options["subtitle"] = "가진 영웅 %d명 중에서 골라요. 소환 포인트(★ 합계)는 %d까지." % [characters.size(), Game.POINT_LIMIT]
		options["confirm_text"] = "저장"
	elif mode == "local":
		characters = app.data["characters"]
		options["levels"] = {}
		options["title"] = "친구 대전 · 플레이어 %d" % player
		options["subtitle"] = "플레이어 %d가 파티를 고르세요. 친구 대전은 48명 모두 쓸 수 있어요." % player
		options["confirm_text"] = "다음" if player == 1 else "대전 시작"
		if player == 2:
			initial = {"attack": "", "defense": "", "support": ""}
	else:
		options["title"] = "%s · 파티 확인" % MODE_TITLES.get(mode, "대전")
		options["subtitle"] = "이대로 시작하거나 바꿔도 돼요. 바꾼 파티는 저장돼요."
		options["confirm_text"] = "대전 시작"
	select.setup(characters, app.data["abilities"], initial, options)
	select.confirmed.connect(_on_confirmed)
	select.cancelled.connect(_on_cancelled)


func _on_confirmed(party: Dictionary) -> void:
	var purpose := str(_params.get("purpose", "edit"))
	var mode := str(_params.get("mode", ""))
	app.play("good")
	if purpose == "edit":
		if Profile.party_ok(app.profile, app.data["characters"], party, Game.POINT_LIMIT):
			app.profile["party"] = party.duplicate()
			app.save()
			app.toast("파티를 저장했어요.")
		app.go("heroes")
		return
	if mode == "local":
		if int(_params.get("player", 1)) == 1:
			app.go("party", {"purpose": "match", "mode": "local", "player": 2, "first": party})
			return
		var first: Dictionary = _params.get("first", {}).duplicate()
		first["name"] = "플레이어 1"
		var second := party.duplicate()
		second["name"] = "플레이어 2"
		app.go("match", {"mode": "local", "parties": [first, second], "humans": [true, true]})
		return
	if not Profile.party_ok(app.profile, app.data["characters"], party, Game.POINT_LIMIT):
		app.toast("가진 영웅으로만 파티를 짤 수 있어요.")
		return
	app.profile["party"] = party.duplicate()
	app.save()
	var mine := Profile.battle_party(app.profile, party, "나")
	var theirs: Dictionary = AI.pick_party(app.data["characters"], Game.POINT_LIMIT, app.rng)
	theirs["name"] = "AI"
	var ai_level := 1
	if mode == "rank":
		ai_level = Profile.rank_ai_level(app.eco, int(app.profile["trophies"]))
	theirs["levels"] = {"attack": ai_level, "defense": ai_level, "support": ai_level}
	app.go("match", {"mode": mode, "parties": [mine, theirs], "humans": [true, false]})


func _on_cancelled() -> void:
	app.play("click")
	if str(_params.get("purpose", "edit")) == "edit":
		app.go("heroes")
	else:
		app.go("lobby")

extends RefCounted
## 빨간 점은 각 메뉴에서 아직 확인하지 않은 항목이 있을 때만 보인다.

const Profile := preload("res://scripts/rules/profile.gd")


static func pending(profile: Dictionary, eco: Dictionary, data: Dictionary, today: String) -> Dictionary:
	var alerts := {"mail": [], "attendance": [], "roulette": [], "list": [], "album": [], "shop": [], "missions": [], "todo": []}
	for entry in profile.get("mail", []):
		if not bool(entry.get("claimed", false)):
			alerts["mail"].append("mail:" + str(entry["id"]))
	if Profile.can_check_in(profile, today):
		alerts["attendance"].append("attendance:" + today)
	if Profile.roulette_spins(profile) == 0 and Profile.can_pay(profile, "gems", int(eco["roulette"]["cost_gems"])):
		alerts["roulette"].append("roulette:" + today)
	for id in profile.get("owned", {}):
		if Profile.can_upgrade(profile, eco, str(id)):
			alerts["list"].append(str(id))
	for category in ["영웅", "위인", "신화", "근현대"]:
		for index in Profile.album_claimable(profile, eco, data.get("characters", []), category):
			alerts["album"].append("hero:%s:%d" % [category, index])
	for grade in [1, 2, 3]:
		for index in Profile.card_album_claimable(profile, eco, data.get("cards", {}), grade):
			alerts["album"].append("card:%d:%d" % [grade, index])
	var todo: Array = alerts["todo"]
	for topic in ["attendance", "roulette", "mail"]:
		todo.append_array(alerts[topic])
	if Profile.free_summons_left(profile, eco) > 0:
		alerts["shop"].append(free_hero_key(today))
		todo.append(free_hero_key(today))
	if Profile.free_card_draws_left(profile, eco) > 0:
		alerts["shop"].append("free_card:" + today)
	if Profile.odd_even_left(profile, eco) > 0:
		todo.append("odd_even:" + today)
	for index in Profile.mileage_claimable(profile, eco):
		alerts["shop"].append("mileage:%d" % index)
	for level in range(1, Profile.pass_level(profile, eco) + 1):
		if not Profile.pass_claimed(profile, level):
			alerts["shop"].append("pass:%d" % level)
			todo.append("pass:%d" % level)
	var missions: Array = alerts["missions"]
	for mission in Profile.active_missions(profile, eco):
		if Profile.mission_done(profile, mission) and not Profile.mission_claimed(profile, mission):
			missions.append("mission:%s:%s" % [today, mission["id"]])
	if Profile.all_missions_done(profile, eco) and not bool(profile["daily"].get("all_claimed", false)):
		missions.append("all_clear:" + today)
	if Profile.guide_claimable(profile, data):
		missions.append("guide:%d" % int(profile.get("guide_step", 0)))
	todo.append_array(missions)
	for entry in data.get("achievements", {}).get("achievements", []):
		if Profile.achievement_done(profile, data, entry) and not Profile.achievement_claimed(profile, entry):
			missions.append("achievement:" + str(entry["id"]))
	return alerts


static func free_hero_key(today: String) -> String:
	return "free_hero:" + today


static func unread(profile: Dictionary, topic: String, entries: Array) -> Array:
	var seen: Array = profile.get("lobby_seen", {}).get(topic, [])
	return entries.filter(func(entry): return entry not in seen)


## 방금 화면을 연 메뉴만 확인 처리한다. 이미 본 항목이 사라져도 다른 항목이 다시 미확인으로 바뀌지 않는다.
static func mark_seen(profile: Dictionary, topic: String, entries: Array) -> bool:
	if unread(profile, topic, entries).is_empty():
		return false
	var seen: Dictionary = profile.get("lobby_seen", {})
	seen[topic] = entries.duplicate()
	profile["lobby_seen"] = seen
	return true


## 더 이상 받을 수 없는 알림은 정리해 같은 영웅을 다시 강화할 수 있을 때 새 알림을 띄운다.
static func discard_resolved(profile: Dictionary, alerts: Dictionary) -> bool:
	var seen: Dictionary = profile.get("lobby_seen", {})
	var changed := false
	for topic in seen.keys():
		var current: Array = alerts.get(topic, [])
		var remaining: Array = seen[topic].filter(func(entry): return entry in current)
		if remaining.size() != seen[topic].size():
			seen[topic] = remaining
			changed = true
	return changed

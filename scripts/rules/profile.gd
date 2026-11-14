extends RefCounted
## 게임 밖 성장 규칙: 저장 데이터(프로필), 재화, 영웅 소환, 강화, 판 보상, 랭크, 일일 미션, 출석.
## 화면 코드와 분리되어 있어 tests/run_tests.gd에서 검사한다. 수치는 data/economy.json.
## 모든 함수는 프로필 사전을 직접 고친다. 저장은 scripts/save_store.gd가 맡는다.
## 날짜는 "2026-11-14" 같은 글자로 받는다. (화면 쪽에서 오늘 날짜를 넘겨준다)

const VERSION := 1


# ---------------------------------------------------------------- 프로필

static func new_profile(nickname: String, eco: Dictionary) -> Dictionary:
	var start: Dictionary = eco.get("start", {})
	var owned := {}
	for id in start.get("characters", []):
		owned[str(id)] = {"level": 1, "shards": 0}
	return {
		"version": VERSION,
		"nickname": nickname,
		"level": 1,
		"exp": 0,
		"gold": int(start.get("gold", 0)),
		"gems": int(start.get("gems", 0)),
		"trophies": 0,
		"best_trophies": 0,
		"owned": owned,
		"party": (start.get("party", {}) as Dictionary).duplicate(),
		"stats": {"played": 0, "wins": 0, "losses": 0, "draws": 0, "rank_wins": 0,
			"battle_wins_total": 0, "cards_total": 0, "summons_total": 0, "upgrades_total": 0},
		## 받은 업적 id
		"achievements": [],
		## 첫 판 안내를 본 것 {"roll": true, ...}
		"tutorial": {},
		## 위쪽 막대에 보일 대표 영웅 id (비어 있으면 ATTACK 영웅)
		"avatar": "",
		## 가진 주사위 스킨 id와 지금 쓰는 스킨
		"dice_skins": ["classic"],
		"dice_skin": "classic",
		## 우편함: [{"id", "title", "text", "reward", "claimed"}], mail_delivered: 이미 배달된 우편 id
		"mail": [],
		"mail_delivered": [],
		## 마지막으로 고른 AI 연습전 난이도 id
		"ai_difficulty": "easy",
		## 영웅별 전적 {id: {"played": n, "wins": n}}
		"hero_stats": {},
		"pity": 0,
		"daily": {"date": "", "progress": {}, "claimed": [], "all_claimed": false, "free_summons": 0, "first_win": false, "deals_bought": [], "roulette_spins": 0, "challenge_done": false},
		"attendance": {"last_date": "", "count": 0},
		"settings": {"sfx": true, "bgm": true, "fast": false, "vibrate": true},
		## 마지막으로 새 소식을 본 버전
		"seen_version": "",
		## 모험 진행: {스테이지 id: 얻은 별 수(0~3)}
		"adventure": {},
	}


## 닉네임은 공백을 빼고 2~10글자.
static func clean_nickname(text: String) -> String:
	return text.strip_edges().left(10)


static func nickname_ok(text: String) -> bool:
	var cleaned := clean_nickname(text)
	return cleaned.length() >= 2


## 예전 저장 데이터에 빠진 항목을 채운다. 저장 형식이 바뀌어도 기존 사용자가 이어서 할 수 있게.
static func repair(profile: Dictionary, eco: Dictionary) -> Dictionary:
	var fresh := new_profile(str(profile.get("nickname", "용사")), eco)
	for key in fresh:
		if not profile.has(key):
			profile[key] = fresh[key]
	for key in fresh["daily"]:
		if not profile["daily"].has(key):
			profile["daily"][key] = fresh["daily"][key]
	for key in fresh["stats"]:
		if not profile["stats"].has(key):
			profile["stats"][key] = fresh["stats"][key]
	profile["version"] = VERSION
	return profile


# ---------------------------------------------------------------- 재화

static func can_pay(profile: Dictionary, currency: String, amount: int) -> bool:
	return int(profile.get(currency, 0)) >= amount


static func pay(profile: Dictionary, currency: String, amount: int) -> bool:
	if not can_pay(profile, currency, amount):
		return false
	profile[currency] = int(profile[currency]) - amount
	return true


## 보상 묶음({"gold": 100, "gems": 30})을 더한다.
static func grant(profile: Dictionary, reward: Dictionary) -> void:
	for currency in ["gold", "gems"]:
		if reward.has(currency):
			profile[currency] = int(profile.get(currency, 0)) + int(reward[currency])


static func reward_text(reward: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(reward.get("gold", 0)) != 0:
		parts.append("골드 %d" % int(reward["gold"]))
	if int(reward.get("gems", 0)) != 0:
		parts.append("보석 %d" % int(reward["gems"]))
	if int(reward.get("trophies", 0)) != 0:
		parts.append("트로피 %+d" % int(reward["trophies"]))
	if int(reward.get("exp", 0)) != 0:
		parts.append("경험치 %d" % int(reward["exp"]))
	return ", ".join(parts)


# ---------------------------------------------------------------- 영웅 보유·파티

static func owns(profile: Dictionary, id: String) -> bool:
	return profile["owned"].has(id)


static func level_of(profile: Dictionary, id: String) -> int:
	if not owns(profile, id):
		return 0
	return int(profile["owned"][id]["level"])


## 파티가 비어 있지 않고, 보유한 영웅이고, 서로 다르고, 포인트 제한 안인지.
static func party_ok(profile: Dictionary, characters: Array, party: Dictionary, point_limit: int) -> bool:
	var seen := {}
	var total := 0
	for slot in ["attack", "defense", "support"]:
		var id := str(party.get(slot, ""))
		if id == "" or seen.has(id) or not owns(profile, id):
			return false
		seen[id] = true
		total += _grade_of(characters, id)
	return total <= point_limit


## 규칙 엔진에 넘길 파티. 자리마다 영웅 레벨을 같이 넣는다.
static func battle_party(profile: Dictionary, party: Dictionary, name: String) -> Dictionary:
	var result := party.duplicate()
	result["name"] = name
	result["levels"] = {}
	for slot in ["attack", "defense", "support"]:
		result["levels"][slot] = max(1, level_of(profile, str(party.get(slot, ""))))
	return result


static func _grade_of(characters: Array, id: String) -> int:
	for character in characters:
		if str(character["id"]) == id:
			return int(character["grade"])
	return 99


# ---------------------------------------------------------------- 소환

## 소환 한 번의 등급. 보장(pity)이 차면 ★★★, guarantee_two면 ★★ 이상.
static func roll_grade(profile: Dictionary, eco: Dictionary, rng: RandomNumberGenerator, guarantee_two: bool) -> int:
	var summon: Dictionary = eco.get("summon", {})
	var pity_limit := int(summon.get("pity_3", 0))
	if pity_limit > 0 and int(profile.get("pity", 0)) + 1 >= pity_limit:
		return 3
	var rates: Dictionary = summon.get("rates", {"1": 100})
	var roll := rng.randf() * 100.0
	var grade := 1
	var acc := 0.0
	for key in ["3", "2", "1"]:
		acc += float(rates.get(key, 0))
		if roll < acc:
			grade = int(key)
			break
	if guarantee_two and grade < 2:
		grade = 2
	return grade


## 영웅을 count번 소환한다. 비용은 먼저 치러야 한다(pay 또는 무료 소환).
## 돌려주는 값: [{"id", "grade", "new": 처음 얻었는지, "shards": 중복이면 받은 조각}]
static func summon(profile: Dictionary, characters: Array, eco: Dictionary, count: int, rng: RandomNumberGenerator) -> Array:
	var summon_table: Dictionary = eco.get("summon", {})
	var shard_table: Dictionary = summon_table.get("shards_on_duplicate", {})
	var results: Array = []
	for index in count:
		var guarantee_two := count >= 10 and index == count - 1 and not _has_grade_at_least(results, 2)
		var grade := roll_grade(profile, eco, rng, guarantee_two)
		if grade == 3:
			profile["pity"] = 0
		else:
			profile["pity"] = int(profile.get("pity", 0)) + 1
		var pool: Array = []
		for character in characters:
			if int(character["grade"]) == grade:
				pool.append(character)
		var picked: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var id := str(picked["id"])
		var entry := {"id": id, "grade": grade, "new": false, "shards": 0}
		if owns(profile, id):
			var shards := int(shard_table.get(str(grade), 5))
			profile["owned"][id]["shards"] = int(profile["owned"][id]["shards"]) + shards
			entry["shards"] = shards
		else:
			profile["owned"][id] = {"level": 1, "shards": 0}
			entry["new"] = true
		results.append(entry)
	add_progress(profile, eco, "summon", 1)
	_add_stat(profile, "summons_total", count)
	return results


static func _has_grade_at_least(results: Array, grade: int) -> bool:
	for entry in results:
		if int(entry["grade"]) >= grade:
			return true
	return false


static func free_summons_left(profile: Dictionary, eco: Dictionary) -> int:
	var per_day := int(eco.get("summon", {}).get("free_per_day", 0))
	return max(0, per_day - int(profile["daily"].get("free_summons", 0)))


## 무료 소환 1회를 쓴다. 남은 무료 소환이 없으면 false.
static func use_free_summon(profile: Dictionary, eco: Dictionary) -> bool:
	if free_summons_left(profile, eco) <= 0:
		return false
	profile["daily"]["free_summons"] = int(profile["daily"].get("free_summons", 0)) + 1
	return true


# ---------------------------------------------------------------- 강화

## 다음 레벨로 올리는 비용. 이미 최고 레벨이거나 없는 영웅이면 빈 사전.
static func upgrade_cost(profile: Dictionary, eco: Dictionary, id: String) -> Dictionary:
	var table: Dictionary = eco.get("upgrade", {})
	var level := level_of(profile, id)
	if level <= 0 or level >= int(table.get("max_level", 5)):
		return {}
	return {"shards": int(table["shards"][level - 1]), "gold": int(table["gold"][level - 1])}


static func can_upgrade(profile: Dictionary, eco: Dictionary, id: String) -> bool:
	var cost := upgrade_cost(profile, eco, id)
	if cost.is_empty():
		return false
	return int(profile["owned"][id]["shards"]) >= int(cost["shards"]) and can_pay(profile, "gold", int(cost["gold"]))


static func upgrade(profile: Dictionary, eco: Dictionary, id: String) -> bool:
	if not can_upgrade(profile, eco, id):
		return false
	var cost := upgrade_cost(profile, eco, id)
	profile["owned"][id]["shards"] = int(profile["owned"][id]["shards"]) - int(cost["shards"])
	pay(profile, "gold", int(cost["gold"]))
	profile["owned"][id]["level"] = level_of(profile, id) + 1
	_add_stat(profile, "upgrades_total", 1)
	add_progress(profile, eco, "upgrade", 1)
	return true


# ---------------------------------------------------------------- 플레이어 레벨

static func exp_to_next(profile: Dictionary, eco: Dictionary) -> int:
	var table: Dictionary = eco.get("player_level", {})
	return int(table.get("base", 100)) + int(table.get("per_level", 50)) * (int(profile["level"]) - 1)


## 경험치를 더하고 오른 레벨 수를 돌려준다. 레벨이 오를 때마다 보석을 준다.
static func add_exp(profile: Dictionary, eco: Dictionary, amount: int) -> int:
	var gained := 0
	profile["exp"] = int(profile["exp"]) + amount
	while int(profile["exp"]) >= exp_to_next(profile, eco):
		profile["exp"] = int(profile["exp"]) - exp_to_next(profile, eco)
		profile["level"] = int(profile["level"]) + 1
		profile["gems"] = int(profile["gems"]) + int(eco.get("player_level", {}).get("level_up_gems", 0))
		gained += 1
	return gained


# ---------------------------------------------------------------- 랭크

static func tier_index(eco: Dictionary, trophies: int) -> int:
	var tiers: Array = eco.get("tiers", [])
	var found := 0
	for index in tiers.size():
		if trophies >= int(tiers[index]["min"]):
			found = index
	return found


static func tier_of(eco: Dictionary, trophies: int) -> Dictionary:
	var tiers: Array = eco.get("tiers", [])
	if tiers.is_empty():
		return {"name": "-", "min": 0, "color": "ffffff", "ai_level": 1}
	return tiers[tier_index(eco, trophies)]


## 다음 티어까지 필요한 트로피. 마지막 티어면 0.
static func trophies_to_next(eco: Dictionary, trophies: int) -> int:
	var tiers: Array = eco.get("tiers", [])
	var index := tier_index(eco, trophies)
	if index + 1 >= tiers.size():
		return 0
	return int(tiers[index + 1]["min"]) - trophies


## 랭크전 AI 상대의 영웅 레벨. 내 티어가 높을수록 상대도 강하다.
static func rank_ai_level(eco: Dictionary, trophies: int) -> int:
	return int(tier_of(eco, trophies).get("ai_level", 1))


# ---------------------------------------------------------------- 판 결과

## 판이 끝났을 때 보상을 계산해 적용한다.
## mode: "rank", "ai", "local" / outcome: "win", "lose", "draw"
## stats: {"battle_wins": n, "cards": n} 미션 진행에 쓴다.
## 돌려주는 값: {"gold", "gems", "exp", "trophies", "level_ups", "first_win", "tier_before", "tier_after"}
static func record_match(profile: Dictionary, eco: Dictionary, mode: String, outcome: String, stats: Dictionary) -> Dictionary:
	var reward_mode := mode
	if mode == "challenge":
		# 오늘의 도전 보상은 하루 한 번. 이미 이겼으면 AI 연습전 보상을 준다.
		if challenge_done(profile):
			reward_mode = "ai"
		elif outcome == "win":
			profile["daily"]["challenge_done"] = true
	var table: Dictionary = eco.get("rewards", {}).get(reward_mode, {}).get(outcome, {})
	var scale := float(stats.get("reward_scale", 1.0))
	var reward := {"gold": int(round(int(table.get("gold", 0)) * scale)), "gems": int(table.get("gems", 0)), "exp": int(round(int(table.get("exp", 0)) * scale)), "trophies": 0,
		"level_ups": 0, "first_win": false, "tier_before": "", "tier_after": ""}
	var played: Dictionary = profile["stats"]
	played["played"] = int(played["played"]) + 1
	match outcome:
		"win":
			played["wins"] = int(played["wins"]) + 1
		"lose":
			played["losses"] = int(played["losses"]) + 1
		_:
			played["draws"] = int(played["draws"]) + 1
	if mode == "rank":
		var before := int(profile["trophies"])
		reward["tier_before"] = tier_of(eco, before)["name"]
		var after: int = max(0, before + int(table.get("trophies", 0)))
		reward["trophies"] = after - before
		profile["trophies"] = after
		profile["best_trophies"] = max(int(profile["best_trophies"]), after)
		reward["tier_after"] = tier_of(eco, after)["name"]
		if outcome == "win":
			played["rank_wins"] = int(played["rank_wins"]) + 1
	var counts_as_win := outcome == "win" and mode != "local"
	if counts_as_win and not bool(profile["daily"].get("first_win", false)):
		profile["daily"]["first_win"] = true
		reward["gems"] = int(reward["gems"]) + int(eco.get("rewards", {}).get("first_win_gems", 0))
		reward["first_win"] = true
	grant(profile, reward)
	reward["level_ups"] = add_exp(profile, eco, int(reward["exp"]))
	add_progress(profile, eco, "play", 1)
	if mode == "rank":
		add_progress(profile, eco, "rank_play", 1)
	if mode == "adventure" and outcome == "win":
		add_progress(profile, eco, "adventure_win", 1)
	if counts_as_win:
		add_progress(profile, eco, "win", 1)
	add_progress(profile, eco, "battle_win", int(stats.get("battle_wins", 0)))
	add_progress(profile, eco, "card", int(stats.get("cards", 0)))
	_add_stat(profile, "battle_wins_total", int(stats.get("battle_wins", 0)))
	_add_stat(profile, "cards_total", int(stats.get("cards", 0)))
	_record_heroes(profile, stats.get("party", []), outcome == "win")
	return reward


## 영웅별 출전·승리 수
static func _record_heroes(profile: Dictionary, party: Array, won: bool) -> void:
	if not profile.has("hero_stats"):
		profile["hero_stats"] = {}
	for id in party:
		var entry: Dictionary = profile["hero_stats"].get(str(id), {"played": 0, "wins": 0})
		entry["played"] = int(entry["played"]) + 1
		if won:
			entry["wins"] = int(entry["wins"]) + 1
		profile["hero_stats"][str(id)] = entry


static func hero_record(profile: Dictionary, id: String) -> Dictionary:
	return profile.get("hero_stats", {}).get(id, {"played": 0, "wins": 0})


static func _add_stat(profile: Dictionary, key: String, amount: int) -> void:
	var stats: Dictionary = profile["stats"]
	stats[key] = int(stats.get(key, 0)) + amount


# ---------------------------------------------------------------- 일일 미션

## 날짜가 바뀌었으면 일일 미션·무료 소환·첫 승리를 새로 시작한다. 바뀌었으면 true.
static func ensure_daily(profile: Dictionary, today: String) -> bool:
	if str(profile["daily"].get("date", "")) == today:
		return false
	profile["daily"] = {"date": today, "progress": {}, "claimed": [], "all_claimed": false, "free_summons": 0, "first_win": false, "deals_bought": [], "roulette_spins": 0, "challenge_done": false}
	return true


## 오늘의 미션. 미션 목록(eco.missions)에서 하루 missions_per_day개를 날짜로 정해 고른다.
## "always": true인 미션은 늘 들어간다. 같은 날에는 늘 같은 목록이다.
static func active_missions(profile: Dictionary, eco: Dictionary) -> Array:
	var pool: Array = eco.get("missions", [])
	var per_day := int(eco.get("missions_per_day", pool.size()))
	if pool.size() <= per_day:
		return pool
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("missions|" + str(profile.get("daily", {}).get("date", "")))
	var picked := {}
	var others: Array = []
	for mission in pool:
		if bool(mission.get("always", false)):
			picked[str(mission["id"])] = true
		else:
			others.append(mission)
	while picked.size() < per_day and not others.is_empty():
		var index := rng.randi_range(0, others.size() - 1)
		picked[str(others[index]["id"])] = true
		others.remove_at(index)
	var result: Array = []
	for mission in pool:
		if picked.has(str(mission["id"])):
			result.append(mission)
	return result


static func add_progress(profile: Dictionary, eco: Dictionary, event: String, amount: int) -> void:
	if amount <= 0:
		return
	var progress: Dictionary = profile["daily"]["progress"]
	for mission in active_missions(profile, eco):
		if str(mission["event"]) == event:
			var id := str(mission["id"])
			progress[id] = min(int(mission["goal"]), int(progress.get(id, 0)) + amount)


static func mission_progress(profile: Dictionary, mission: Dictionary) -> int:
	return int(profile["daily"]["progress"].get(str(mission["id"]), 0))


static func mission_done(profile: Dictionary, mission: Dictionary) -> bool:
	return mission_progress(profile, mission) >= int(mission["goal"])


static func mission_claimed(profile: Dictionary, mission: Dictionary) -> bool:
	return str(mission["id"]) in profile["daily"]["claimed"]


static func claim_mission(profile: Dictionary, eco: Dictionary, id: String) -> Dictionary:
	for mission in active_missions(profile, eco):
		if str(mission["id"]) == id and mission_done(profile, mission) and not mission_claimed(profile, mission):
			profile["daily"]["claimed"].append(id)
			grant(profile, mission["reward"])
			return mission["reward"]
	return {}


static func all_missions_done(profile: Dictionary, eco: Dictionary) -> bool:
	for mission in active_missions(profile, eco):
		if not mission_claimed(profile, mission):
			return false
	return true


static func claim_all_clear(profile: Dictionary, eco: Dictionary) -> Dictionary:
	if bool(profile["daily"].get("all_claimed", false)) or not all_missions_done(profile, eco):
		return {}
	profile["daily"]["all_claimed"] = true
	var reward: Dictionary = eco.get("missions_all_clear", {})
	grant(profile, reward)
	return reward


## 받을 수 있는 미션 보상이 있는지 (로비 알림 점에 쓴다).
static func has_claimable(profile: Dictionary, eco: Dictionary) -> bool:
	for mission in active_missions(profile, eco):
		if mission_done(profile, mission) and not mission_claimed(profile, mission):
			return true
	if all_missions_done(profile, eco) and not bool(profile["daily"].get("all_claimed", false)):
		return true
	return false


# ---------------------------------------------------------------- 출석

static func can_check_in(profile: Dictionary, today: String) -> bool:
	return str(profile["attendance"].get("last_date", "")) != today


## 오늘 출석 보상을 받는다. 7일 보상이 돌아가며 나온다. 받은 보상(이미 받았으면 빈 사전).
static func check_in(profile: Dictionary, eco: Dictionary, today: String) -> Dictionary:
	if not can_check_in(profile, today):
		return {}
	var table: Array = eco.get("attendance", [])
	if table.is_empty():
		return {}
	var count := int(profile["attendance"].get("count", 0))
	var reward: Dictionary = table[count % table.size()]
	profile["attendance"]["count"] = count + 1
	profile["attendance"]["last_date"] = today
	grant(profile, reward)
	return reward


## 출석 보상표에서 오늘 받을 칸 순번 (0부터).
static func attendance_day(profile: Dictionary, eco: Dictionary) -> int:
	var table: Array = eco.get("attendance", [])
	if table.is_empty():
		return 0
	return int(profile["attendance"].get("count", 0)) % table.size()


# ---------------------------------------------------------------- 교환

static func exchange(profile: Dictionary, eco: Dictionary, index: int) -> bool:
	var table: Array = eco.get("exchange", [])
	if index < 0 or index >= table.size():
		return false
	var offer: Dictionary = table[index]
	if not pay(profile, "gems", int(offer["gems"])):
		return false
	profile["gold"] = int(profile["gold"]) + int(offer["gold"])
	return true


# ---------------------------------------------------------------- 모험

## 스테이지를 찾는다. 돌려주는 값: {"stage", "chapter", "index"(전체 순번)} 또는 빈 사전.
static func find_stage(adventure: Dictionary, stage_id: String) -> Dictionary:
	var index := 0
	for chapter in adventure.get("chapters", []):
		for stage in chapter["stages"]:
			if str(stage["id"]) == stage_id:
				return {"stage": stage, "chapter": chapter, "index": index}
			index += 1
	return {}


## 모든 스테이지를 순서대로.
static func all_stages(adventure: Dictionary) -> Array:
	var result: Array = []
	for chapter in adventure.get("chapters", []):
		for stage in chapter["stages"]:
			result.append(stage)
	return result


## 이 스테이지 다음 스테이지의 id. 마지막이면 "".
static func next_stage_id(adventure: Dictionary, stage_id: String) -> String:
	var stages := all_stages(adventure)
	for index in stages.size() - 1:
		if str(stages[index]["id"]) == stage_id:
			return str(stages[index + 1]["id"])
	return ""


static func stage_stars(profile: Dictionary, stage_id: String) -> int:
	return int(profile.get("adventure", {}).get(stage_id, 0))


## 첫 스테이지는 처음부터 열려 있고, 나머지는 바로 앞 스테이지를 깨야 열린다.
static func stage_unlocked(profile: Dictionary, adventure: Dictionary, stage_id: String) -> bool:
	var stages := all_stages(adventure)
	for index in stages.size():
		if str(stages[index]["id"]) == stage_id:
			return index == 0 or stage_stars(profile, str(stages[index - 1]["id"])) > 0
	return false


static func total_stars(profile: Dictionary) -> int:
	var total := 0
	for id in profile.get("adventure", {}):
		total += int(profile["adventure"][id])
	return total


## 별 계산: 이기면 1, 정한 턴 안에 이기면 +1, 전투에서 한 번도 지지 않았으면 +1.
static func stars_for(adventure: Dictionary, won: bool, turns: int, battle_losses: int) -> int:
	if not won:
		return 0
	var stars := 1
	if turns <= int(adventure.get("star_rules", {}).get("turns", 24)):
		stars += 1
	if battle_losses == 0:
		stars += 1
	return stars


## 모험 판 결과를 기록한다. 첫 클리어 보상과 처음 별 3개 보상을 준다.
## 돌려주는 값: {"stars", "best", "first_clear", "reward"(받은 보상 묶음)}
static func record_adventure(profile: Dictionary, adventure: Dictionary, stage_id: String, won: bool, turns: int, battle_losses: int) -> Dictionary:
	var found := find_stage(adventure, stage_id)
	var result := {"stars": 0, "best": stage_stars(profile, stage_id), "first_clear": false, "reward": {}}
	if found.is_empty():
		return result
	if not profile.has("adventure"):
		profile["adventure"] = {}
	var stars := stars_for(adventure, won, turns, battle_losses)
	var before := stage_stars(profile, stage_id)
	result["stars"] = stars
	var reward := {"gold": 0, "gems": 0}
	if stars > 0 and before == 0:
		result["first_clear"] = true
		var first: Dictionary = found["stage"].get("reward", {})
		reward["gold"] += int(first.get("gold", 0))
		reward["gems"] += int(first.get("gems", 0))
	if stars == 3 and before < 3:
		reward["gems"] += int(adventure.get("three_star_gems", 0))
	if stars > before:
		profile["adventure"][stage_id] = stars
	result["best"] = max(before, stars)
	grant(profile, reward)
	result["reward"] = reward
	return result


# ---------------------------------------------------------------- 업적

## 업적이 보는 값. data는 GameData.load_all()의 묶음(characters, adventure 등).
static func achievement_value(profile: Dictionary, data: Dictionary, stat: String) -> int:
	var stats: Dictionary = profile.get("stats", {})
	match stat:
		"owned":
			return profile.get("owned", {}).size()
		"max_level_heroes":
			var count := 0
			for id in profile.get("owned", {}):
				if int(profile["owned"][id]["level"]) >= 5:
					count += 1
			return count
		"adventure_stars":
			return total_stars(profile)
		"chapters_cleared":
			var cleared := 0
			for chapter in data.get("adventure", {}).get("chapters", []):
				var last: Dictionary = chapter["stages"][chapter["stages"].size() - 1]
				if stage_stars(profile, str(last["id"])) > 0:
					cleared += 1
			return cleared
		"best_trophies":
			return int(profile.get("best_trophies", 0))
		"level":
			return int(profile.get("level", 1))
	return int(stats.get(stat, 0))


static func achievement_done(profile: Dictionary, data: Dictionary, achievement: Dictionary) -> bool:
	return achievement_value(profile, data, str(achievement["stat"])) >= int(achievement["goal"])


static func achievement_claimed(profile: Dictionary, achievement: Dictionary) -> bool:
	return str(achievement["id"]) in profile.get("achievements", [])


static func claim_achievement(profile: Dictionary, data: Dictionary, id: String) -> Dictionary:
	if not profile.has("achievements"):
		profile["achievements"] = []
	for achievement in data.get("achievements", {}).get("achievements", []):
		if str(achievement["id"]) == id and achievement_done(profile, data, achievement) and not achievement_claimed(profile, achievement):
			profile["achievements"].append(id)
			grant(profile, achievement["reward"])
			return achievement["reward"]
	return {}


## 지금 받을 수 있는(달성했지만 아직 안 받은) 업적 수
static func claimable_achievement_count(profile: Dictionary, data: Dictionary) -> int:
	var count := 0
	for achievement in data.get("achievements", {}).get("achievements", []):
		if achievement_done(profile, data, achievement) and not achievement_claimed(profile, achievement):
			count += 1
	return count


## 지금 받을 수 있는 일일 미션 수
static func claimable_mission_count(profile: Dictionary, eco: Dictionary) -> int:
	var count := 0
	for mission in active_missions(profile, eco):
		if mission_done(profile, mission) and not mission_claimed(profile, mission):
			count += 1
	return count


static func has_claimable_achievement(profile: Dictionary, data: Dictionary) -> bool:
	for achievement in data.get("achievements", {}).get("achievements", []):
		if achievement_done(profile, data, achievement) and not achievement_claimed(profile, achievement):
			return true
	return false


# ---------------------------------------------------------------- AI 연습전 난이도

## 난이도 정보. 모르는 id면 첫 번째(쉬움).
static func ai_difficulty(eco: Dictionary, id: String) -> Dictionary:
	var list: Array = eco.get("ai_difficulty", [])
	for entry in list:
		if str(entry["id"]) == id:
			return entry
	if list.is_empty():
		return {"id": "easy", "name": "쉬움", "level": 1, "smart": false, "reward_scale": 1.0}
	return list[0]


# ---------------------------------------------------------------- 오늘의 특가

## 오늘의 특가 목록. 날짜와 닉네임으로 정해지므로 같은 날에는 몇 번 열어도 같다.
## 각 항목: {"id", "grade", "shards", "gold", "bought"}
static func daily_deals(profile: Dictionary, characters: Array, eco: Dictionary, today: String) -> Array:
	var table: Dictionary = eco.get("daily_deals", {})
	var offers: Dictionary = table.get("offers", {})
	var max_level := int(eco.get("upgrade", {}).get("max_level", 5))
	var candidates: Array = []
	for character in characters:
		var id := str(character["id"])
		if owns(profile, id) and level_of(profile, id) < max_level:
			candidates.append(character)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today + "|" + str(profile.get("nickname", "")))
	var picked: Array = []
	var count: int = min(int(table.get("count", 3)), candidates.size())
	while picked.size() < count:
		var index := rng.randi_range(0, candidates.size() - 1)
		picked.append(candidates[index])
		candidates.remove_at(index)
	var bought: Array = profile.get("daily", {}).get("deals_bought", [])
	var deals: Array = []
	for character in picked:
		var grade := int(character["grade"])
		var offer: Dictionary = offers.get(str(grade), {"shards": 5, "gold": 1000})
		var id := str(character["id"])
		deals.append({"id": id, "grade": grade, "shards": int(offer["shards"]), "gold": int(offer["gold"]), "bought": id in bought})
	return deals


## 오늘의 특가 하나를 산다. 골드가 모자라거나 이미 샀으면 false.
static func buy_deal(profile: Dictionary, characters: Array, eco: Dictionary, today: String, index: int) -> bool:
	var deals := daily_deals(profile, characters, eco, today)
	if index < 0 or index >= deals.size():
		return false
	var deal: Dictionary = deals[index]
	if bool(deal["bought"]) or not pay(profile, "gold", int(deal["gold"])):
		return false
	if not profile["daily"].has("deals_bought"):
		profile["daily"]["deals_bought"] = []
	profile["daily"]["deals_bought"].append(str(deal["id"]))
	var owned: Dictionary = profile["owned"][str(deal["id"])]
	owned["shards"] = int(owned["shards"]) + int(deal["shards"])
	add_progress(profile, eco, "deal", 1)
	return true


# ---------------------------------------------------------------- 행운의 룰렛

## 오늘 돌린 횟수
static func roulette_spins(profile: Dictionary) -> int:
	return int(profile.get("daily", {}).get("roulette_spins", 0))


## 이번에 돌릴 때 드는 보석. 무료면 0, 오늘 더 못 돌리면 -1.
static func roulette_cost(profile: Dictionary, eco: Dictionary) -> int:
	var table: Dictionary = eco.get("roulette", {})
	var spins := roulette_spins(profile)
	var free := int(table.get("free_per_day", 1))
	if spins < free:
		return 0
	if spins >= free + int(table.get("max_extra", 0)):
		return -1
	return int(table.get("extra_cost_gems", 30))


static func can_spin_free(profile: Dictionary, eco: Dictionary) -> bool:
	return roulette_cost(profile, eco) == 0


## 룰렛을 돌린다. 못 돌리면 {}. 돌리면 {"index": 걸린 칸, "reward": 보상, "cost": 낸 보석}
static func spin_roulette(profile: Dictionary, eco: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var slots: Array = eco.get("roulette", {}).get("slots", [])
	var cost := roulette_cost(profile, eco)
	if slots.is_empty() or cost < 0:
		return {}
	if cost > 0 and not pay(profile, "gems", cost):
		return {}
	var total := 0
	for slot in slots:
		total += int(slot["weight"])
	var roll := rng.randi_range(1, max(total, 1))
	var index := 0
	for slot_index in slots.size():
		roll -= int(slots[slot_index]["weight"])
		if roll <= 0:
			index = slot_index
			break
	profile["daily"]["roulette_spins"] = roulette_spins(profile) + 1
	add_progress(profile, eco, "roulette", 1)
	grant(profile, slots[index]["reward"])
	return {"index": index, "reward": slots[index]["reward"], "cost": cost}


# ---------------------------------------------------------------- 연습 리그 순위표

## AI 상대들과 나를 트로피 순으로 줄 세운 표. 온라인이 없으므로 AI 이름과 정해진 트로피로 만든다.
## 각 줄: {"name", "trophies", "me"}
static func league_table(profile: Dictionary, eco: Dictionary) -> Array:
	var rows: Array = []
	var names: Array = eco.get("ai_names", [])
	for index in names.size():
		var name := str(names[index])
		# 이름마다 늘 같은 트로피(0~2300 사이에 고르게 퍼지게)
		var trophies := 40 + int(2300.0 * (index + 1) / (names.size() + 1)) + absi(hash(name)) % 60
		rows.append({"name": name, "trophies": trophies, "me": false})
	rows.append({"name": str(profile.get("nickname", "나")), "trophies": int(profile.get("trophies", 0)), "me": true})
	rows.sort_custom(func(a, b): return int(a["trophies"]) > int(b["trophies"]))
	return rows


## 순위표에서 내 순위(1부터)
static func league_rank(profile: Dictionary, eco: Dictionary) -> int:
	var rows := league_table(profile, eco)
	for index in rows.size():
		if bool(rows[index]["me"]):
			return index + 1
	return rows.size()


## 가장 많이 출전시킨 영웅 id. 기록이 없으면 "".
static func favorite_hero(profile: Dictionary) -> String:
	var best := ""
	var best_played := 0
	var stats: Dictionary = profile.get("hero_stats", {})
	for id in stats:
		if int(stats[id]["played"]) > best_played:
			best_played = int(stats[id]["played"])
			best = str(id)
	return best


# ---------------------------------------------------------------- 오늘의 도전

## 오늘의 도전을 이미 이겼는지
static func challenge_done(profile: Dictionary) -> bool:
	return bool(profile.get("daily", {}).get("challenge_done", false))


## 오늘의 도전 상대 영웅 레벨: 내 가장 높은 영웅 레벨 + level_bonus (최고 max_level)
static func challenge_level(profile: Dictionary, eco: Dictionary) -> int:
	var best := 1
	for id in profile.get("owned", {}):
		best = max(best, int(profile["owned"][id]["level"]))
	var table: Dictionary = eco.get("challenge", {})
	return min(int(table.get("max_level", 5)), best + int(table.get("level_bonus", 1)))


## 오늘의 도전에 쓸 난수 씨앗(날짜마다 같다). 상대 파티와 맵을 정하는 데 쓴다.
static func challenge_seed(profile: Dictionary) -> int:
	return hash("challenge|" + str(profile.get("daily", {}).get("date", "")))


# ---------------------------------------------------------------- 모두 받기

## 받을 수 있는 미션·모두 완료 보너스·업적 보상을 한꺼번에 받는다. 받은 합계 {"gold", "gems", "count"}를 돌려준다.
static func claim_everything(profile: Dictionary, eco: Dictionary, data: Dictionary) -> Dictionary:
	var total := {"gold": 0, "gems": 0, "count": 0}
	var rewards: Array = []
	for mission in active_missions(profile, eco):
		var reward := claim_mission(profile, eco, str(mission["id"]))
		if not reward.is_empty():
			rewards.append(reward)
	var bonus := claim_all_clear(profile, eco)
	if not bonus.is_empty():
		rewards.append(bonus)
	for achievement in data.get("achievements", {}).get("achievements", []):
		var reward := claim_achievement(profile, data, str(achievement["id"]))
		if not reward.is_empty():
			rewards.append(reward)
	for reward in rewards:
		total["gold"] = int(total["gold"]) + int(reward.get("gold", 0))
		total["gems"] = int(total["gems"]) + int(reward.get("gems", 0))
		total["count"] = int(total["count"]) + 1
	return total


# ---------------------------------------------------------------- 우편함

## data/mails.json의 우편 중 아직 안 받은 것을 우편함에 넣는다. 새로 넣은 수를 돌려준다.
static func deliver_mails(profile: Dictionary, mails: Dictionary) -> int:
	if not profile.has("mail"):
		profile["mail"] = []
	if not profile.has("mail_delivered"):
		profile["mail_delivered"] = []
	var added := 0
	for mail in mails.get("mails", []):
		var id := str(mail["id"])
		if id in profile["mail_delivered"]:
			continue
		profile["mail_delivered"].append(id)
		profile["mail"].append({"id": id, "title": str(mail.get("title", "")), "text": str(mail.get("text", "")),
			"reward": (mail.get("reward", {}) as Dictionary).duplicate(), "claimed": false})
		added += 1
	return added


## 아직 보상을 안 받은 우편 수
static func unclaimed_mail_count(profile: Dictionary) -> int:
	var count := 0
	for mail in profile.get("mail", []):
		if not bool(mail.get("claimed", false)):
			count += 1
	return count


## 우편 하나의 보상을 받는다. 이미 받았거나 없으면 {}.
static func claim_mail(profile: Dictionary, id: String) -> Dictionary:
	for mail in profile.get("mail", []):
		if str(mail["id"]) == id and not bool(mail.get("claimed", false)):
			mail["claimed"] = true
			grant(profile, mail["reward"])
			return mail["reward"]
	return {}


## 안 받은 우편을 모두 받는다. 합계 {"gold", "gems", "count"}.
static func claim_all_mail(profile: Dictionary) -> Dictionary:
	var total := {"gold": 0, "gems": 0, "count": 0}
	for mail in profile.get("mail", []):
		var reward := claim_mail(profile, str(mail["id"]))
		if not reward.is_empty():
			total["gold"] = int(total["gold"]) + int(reward.get("gold", 0))
			total["gems"] = int(total["gems"]) + int(reward.get("gems", 0))
			total["count"] = int(total["count"]) + 1
	return total


# ---------------------------------------------------------------- 주사위 스킨

## 스킨 정보. 모르는 id면 첫 번째(기본).
static func dice_skin(eco: Dictionary, id: String) -> Dictionary:
	var list: Array = eco.get("dice_skins", [])
	for entry in list:
		if str(entry["id"]) == id:
			return entry
	return list[0] if not list.is_empty() else {"id": "classic", "name": "기본 주사위"}


static func owns_dice_skin(profile: Dictionary, id: String) -> bool:
	return id == "classic" or id in profile.get("dice_skins", [])


## 지금 쓰는 스킨 정보
static func current_dice_skin(profile: Dictionary, eco: Dictionary) -> Dictionary:
	var id := str(profile.get("dice_skin", "classic"))
	return dice_skin(eco, id if owns_dice_skin(profile, id) else "classic")


## 스킨을 산다(한 번 사면 계속 쓴다). 이미 있거나 재화가 모자라면 false. 사면 바로 장착한다.
static func buy_dice_skin(profile: Dictionary, eco: Dictionary, id: String) -> bool:
	var skin := dice_skin(eco, id)
	if str(skin.get("id", "")) != id or owns_dice_skin(profile, id):
		return false
	var cost: Dictionary = skin.get("cost", {})
	for currency in cost:
		if not can_pay(profile, str(currency), int(cost[currency])):
			return false
	for currency in cost:
		pay(profile, str(currency), int(cost[currency]))
	if not profile.has("dice_skins"):
		profile["dice_skins"] = ["classic"]
	profile["dice_skins"].append(id)
	profile["dice_skin"] = id
	return true


## 가진 스킨으로 바꾼다.
static func equip_dice_skin(profile: Dictionary, id: String) -> bool:
	if not owns_dice_skin(profile, id):
		return false
	profile["dice_skin"] = id
	return true

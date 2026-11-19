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
			"battle_wins_total": 0, "cards_total": 0, "summons_total": 0, "upgrades_total": 0, "card_draws_total": 0},
		## 받은 업적 id
		"achievements": [],
		## 첫 판 안내를 본 것 {"roll": true, ...}
		"tutorial": {},
		## 위쪽 막대에 보일 대표 영웅 id (비어 있으면 ATTACK 영웅)
		"avatar": "",
		## 저장해 둔 파티 3칸 ({}이면 빈 칸)
		"party_presets": [{}, {}, {}],
		## 이미 쓴 쿠폰 코드
		"coupons_used": [],
		## 시즌 패스: 쌓은 경험치와 이미 받은 무료 보상 레벨(1부터)
		"pass": {"exp": 0, "claimed": []},
		## 가진 주사위 스킨 id와 지금 쓰는 스킨
		"dice_skins": ["classic"],
		"dice_skin": "classic",
		## 가진 발끝 효과 id와 지금 쓰는 것(2026-11-19)
		"trails": [],
		"trail": "none",
		## 우편함: [{"id", "title", "text", "reward", "claimed"}], mail_delivered: 이미 배달된 우편 id
		"mail": [],
		"mail_delivered": [],
		## 마지막으로 고른 AI 연습전 난이도 id
		"ai_difficulty": "easy",
		## 영웅별 전적 {id: {"played": n, "wins": n}}
		"hero_stats": {},
		"pity": 0,
		"daily": {"date": "", "progress": {}, "claimed": [], "all_claimed": false, "free_summons": 0, "first_win": false, "deals_bought": [], "roulette_spins": 0, "challenge_done": false, "sweeps": 0, "free_card_draws": 0},
		"attendance": {"last_date": "", "count": 0},
		"settings": {"sfx": true, "bgm": true, "fast": false, "vibrate": true},
		## 마지막으로 새 소식을 본 버전
		"seen_version": "",
		## 모험 진행: {스테이지 id: 얻은 별 수(0~3)}
		"adventure": {},
		## 가진 아이템 카드 id와 판에 들고 가는 카드 덱(data/cards.json, economy.json의 card_deck)
		"cards": (start.get("cards", []) as Array).duplicate(),
		"deck": (start.get("deck", []) as Array).duplicate(),
		## 카드 뽑기 ★★★ 보장까지 센 횟수
		"card_pity": 0,
		## 돈으로 산 보석(gems 안에 든 몫). 무료 보석부터 먼저 쓴다(쓰지 않은 유료 보석만 청약 철회 대상).
		"gems_paid": 0,
		## 산 기록 [{"id", "name", "price", "gems", "bonus", "at", "refunded"}]
		"purchases": [],
		## 처음 하는 사람 길잡이 단계(data/guide.json의 tutorial). 예전 저장에는 없으므로 끝난 것으로 본다.
		"guide_flow": 0,
	}


## 계정 번호(2026-11-19): 문의할 때 알려 주는 번호. 없으면 만들어 둔다. 예: DH-3F9A-0C21
static func ensure_account_id(profile: Dictionary, rng: RandomNumberGenerator) -> String:
	var id := str(profile.get("account_id", ""))
	if id == "":
		id = "DH-%04X-%04X" % [rng.randi_range(0, 0xFFFF), rng.randi_range(0, 0xFFFF)]
		profile["account_id"] = id
	return id


## 길잡이(2026-11-19): 지금 단계. 끝났거나 예전 저장(tutorial 없음)이면 {}.
static func tutorial_step(profile: Dictionary, guide: Dictionary) -> Dictionary:
	var steps: Array = guide.get("tutorial", {}).get("steps", [])
	var index := int(profile.get("guide_flow", 9999))
	if index < 0 or index >= steps.size():
		return {}
	return steps[index]


## 일(event: match_end·summon·party·rank)이 지금 단계의 일이면 다음 단계로 가고 보상을 준다.
## 돌려주는 값: {"reward": 보상, "done": 길잡이를 다 끝냈는지} 또는 {}.
static func tutorial_event(profile: Dictionary, guide: Dictionary, event: String) -> Dictionary:
	var step := tutorial_step(profile, guide)
	if step.is_empty() or str(step.get("event", "")) != event:
		return {}
	var reward: Dictionary = step.get("reward", {})
	grant(profile, reward)
	profile["guide_flow"] = int(profile["guide_flow"]) + 1
	return {"reward": reward, "done": tutorial_step(profile, guide).is_empty()}


static func skip_tutorial(profile: Dictionary) -> void:
	profile["guide_flow"] = 9999


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
	# paid_gems: 유료 보석으로만 내는 값(유료 전용 꾸미기). 보석 합계에서 빠지고 유료 몫도 줄어든다.
	if currency == "paid_gems":
		return paid_gems(profile) >= amount
	return int(profile.get(currency, 0)) >= amount


static func pay(profile: Dictionary, currency: String, amount: int) -> bool:
	if not can_pay(profile, currency, amount):
		return false
	if currency == "paid_gems":
		profile["gems_paid"] = paid_gems(profile) - amount
		profile["gems"] = int(profile["gems"]) - amount
		profile["gems_spent"] = int(profile.get("gems_spent", 0)) + amount
		return true
	profile[currency] = int(profile[currency]) - amount
	if currency == "gems":
		# 보석 마일리지: 쓴 보석을 센다.
		profile["gems_spent"] = int(profile.get("gems_spent", 0)) + amount
		# 무료 보석부터 쓰므로, 유료 몫은 남은 보석보다 많을 수 없다.
		profile["gems_paid"] = clampi(int(profile.get("gems_paid", 0)), 0, maxi(int(profile["gems"]), 0))
	return true


## 유료 보석·무료 보석(2026-11-19, 정식 출시 준비). gems는 둘을 합친 값 그대로다.
static func paid_gems(profile: Dictionary) -> int:
	return clampi(int(profile.get("gems_paid", 0)), 0, maxi(int(profile.get("gems", 0)), 0))


static func free_gems(profile: Dictionary) -> int:
	return maxi(int(profile.get("gems", 0)) - paid_gems(profile), 0)


static func gem_pack(eco: Dictionary, id: String) -> Dictionary:
	for pack in eco.get("gem_packs", {}).get("packs", []):
		if str(pack.get("id", "")) == id:
			return pack
	return {}


## 이 상품을 지금 사면 받는 보석 {"gems": 유료, "bonus": 무료 덤}. 처음 사는 first_double 상품은 gems가 2배.
static func pack_contents(profile: Dictionary, eco: Dictionary, id: String) -> Dictionary:
	var pack := gem_pack(eco, id)
	var gems := int(pack.get("gems", 0))
	if bool(pack.get("first_double", false)) and not has_bought(profile, id):
		gems *= 2
	return {"gems": gems, "bonus": int(pack.get("bonus", 0))}


static func has_bought(profile: Dictionary, id: String) -> bool:
	for entry in profile.get("purchases", []):
		if str(entry.get("id", "")) == id and not bool(entry.get("refunded", false)):
			return true
	return false


## 결제가 확인된 뒤에만 부른다(나중에 서버가 영수증을 확인하고 부름). at은 "2026-11-19 20:10" 같은 때.
## 유료 보석은 gems_paid에도 더하고, 덤은 무료 보석이다. 월정액의 매일 보석은 여기서 주지 않는다.
static func record_purchase(profile: Dictionary, eco: Dictionary, id: String, at: String) -> Dictionary:
	var pack := gem_pack(eco, id)
	if pack.is_empty():
		return {}
	var contents := pack_contents(profile, eco, id)
	profile["gems"] = int(profile.get("gems", 0)) + int(contents["gems"]) + int(contents["bonus"])
	profile["gems_paid"] = int(profile.get("gems_paid", 0)) + int(contents["gems"])
	var entry := {"id": id, "name": str(pack.get("name", id)), "price": int(pack.get("price", 0)), "gems": int(contents["gems"]), "bonus": int(contents["bonus"]), "at": at, "refunded": false}
	if not profile.has("purchases"):
		profile["purchases"] = []
	profile["purchases"].append(entry)
	return entry


## 환불(청약 철회·스토어 환불): 그 구매로 받은 보석을 되돌린다. 이미 써 버렸으면 보석이 마이너스가 될 수 있다.
static func refund_purchase(profile: Dictionary, index: int) -> bool:
	var list: Array = profile.get("purchases", [])
	if index < 0 or index >= list.size() or bool(list[index].get("refunded", false)):
		return false
	var entry: Dictionary = list[index]
	var paid := mini(int(entry["gems"]), int(profile.get("gems_paid", 0)))
	profile["gems_paid"] = int(profile.get("gems_paid", 0)) - paid
	profile["gems"] = int(profile.get("gems", 0)) - int(entry["gems"]) - int(entry.get("bonus", 0))
	entry["refunded"] = true
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
## 파티가 한도를 넘으면 가진 영웅 중 ★이 낮은 영웅으로 바꿔 한도 안에 맞춘다(한도가 줄었을 때 예전 파티 구제).
## 지력 → 방어 → 공격 자리 순으로 바꾼다. 바꿨으면 true.
static func fit_party(profile: Dictionary, characters: Array, point_limit: int) -> bool:
	var grades := {}
	for character in characters:
		grades[str(character["id"])] = int(character["grade"])
	var party: Dictionary = profile.get("party", {})
	var changed := false
	for slot in ["support", "defense", "attack"]:
		var total := 0
		for key in ["attack", "defense", "support"]:
			total += int(grades.get(str(party.get(key, "")), 0))
		if total <= point_limit:
			break
		var current := str(party.get(slot, ""))
		var need := int(grades.get(current, 0)) - (total - point_limit)
		var best := ""
		for id in profile.get("owned", {}).keys():
			var grade := int(grades.get(str(id), 99))
			if str(id) in party.values() or grade >= int(grades.get(current, 0)):
				continue
			# 한도에 딱 맞는 가장 높은 ★을 고르고, 없으면 가장 낮은 ★
			if best == "" or (grade <= need and (int(grades[best]) > need or grade > int(grades[best]))) or (int(grades[best]) > need and grade < int(grades[best])):
				best = str(id)
		if best != "":
			party[slot] = best
			changed = true
	profile["party"] = party
	return changed


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

## 확률표 {"3": %, "2": %, "1": %}로 등급 하나. 골드 뽑기(★·★★만)에 쓴다.
static func roll_rates(rates: Dictionary, rng: RandomNumberGenerator, guarantee_two: bool) -> int:
	var total := 0.0
	for key in ["3", "2", "1"]:
		total += float(rates.get(key, 0))
	var roll := rng.randf() * maxf(total, 0.001)
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
## gold: true면 골드 소환(economy.json의 summon.gold 확률, ★·★★만, ★★★ 보장은 세지 않음).
## 픽업 소환 영웅(economy.json summon.pickup). date는 "2026-11-19". 없으면 "".
static func pickup_hero(eco: Dictionary, date: String) -> String:
	var table: Dictionary = eco.get("summon", {}).get("pickup", {})
	var heroes: Array = table.get("heroes", [])
	if heroes.is_empty():
		return ""
	return str(heroes[_pickup_round(table, date) % heroes.size()])


## 지금 픽업이 끝나기까지 남은 날(오늘 포함).
static func pickup_days_left(eco: Dictionary, date: String) -> int:
	var table: Dictionary = eco.get("summon", {}).get("pickup", {})
	var days := maxi(int(table.get("days", 14)), 1)
	var passed := _days_between(str(table.get("start", "")), date)
	return days - posmod(passed, days)


static func _pickup_round(table: Dictionary, date: String) -> int:
	var passed := _days_between(str(table.get("start", "")), date)
	return maxi(passed, 0) / maxi(int(table.get("days", 14)), 1)


static func _days_between(from_date: String, to_date: String) -> int:
	if from_date == "" or to_date == "":
		return 0
	var a := Time.get_unix_time_from_datetime_string(from_date + "T00:00:00")
	var b := Time.get_unix_time_from_datetime_string(to_date + "T00:00:00")
	return int(floor(float(b - a) / 86400.0))


static func summon(profile: Dictionary, characters: Array, eco: Dictionary, count: int, rng: RandomNumberGenerator, gold: bool = false) -> Array:
	var summon_table: Dictionary = eco.get("summon", {})
	var shard_table: Dictionary = summon_table.get("shards_on_duplicate", {})
	var results: Array = []
	for index in count:
		var guarantee_two := count >= 10 and index == count - 1 and not _has_grade_at_least(results, 2)
		var grade := 1
		var forced := false
		if gold:
			grade = roll_rates(summon_table.get("gold", {}).get("rates", {"1": 100}), rng, guarantee_two)
		else:
			var pity_limit := int(summon_table.get("pity_3", 0))
			forced = pity_limit > 0 and int(profile.get("pity", 0)) + 1 >= pity_limit
			grade = roll_grade(profile, eco, rng, guarantee_two)
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
		# 픽업 소환: ★★★면 share%(확정이면 반드시)는 픽업 영웅, 아니면 다른 ★★★ 중 하나.
		var pickup := pickup_hero(eco, str(profile.get("daily", {}).get("date", "")))
		if not gold and grade == 3 and pickup != "" and pool.size() > 1:
			var share := float(summon_table.get("pickup", {}).get("share", 0))
			if forced or rng.randf() * 100.0 < share:
				id = pickup
			else:
				var others: Array = []
				for character in pool:
					if str(character["id"]) != pickup:
						others.append(str(character["id"]))
				id = others[rng.randi_range(0, others.size() - 1)]
		var entry := {"id": id, "grade": grade, "new": false, "shards": 0, "pickup": id == pickup and grade == 3}
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
## 그 맵에서의 내 전적 {played, wins}
static func map_record(profile: Dictionary, map_name: String) -> Dictionary:
	return profile.get("map_stats", {}).get(map_name, {"played": 0, "wins": 0})


## 프로필에 남기는 최근 전적 수
const HISTORY_LIMIT := 10

static func record_match(profile: Dictionary, eco: Dictionary, mode: String, outcome: String, stats: Dictionary) -> Dictionary:
	var reward_mode := mode
	if mode == "challenge":
		# 오늘의 도전 보상은 하루 한 번. 이미 이겼으면 AI 연습전 보상을 준다.
		if challenge_done(profile):
			reward_mode = "ai"
		elif outcome == "win":
			profile["daily"]["challenge_done"] = true
	var table: Dictionary = eco.get("rewards", {}).get(reward_mode, {}).get(outcome, {})
	# 기간 이벤트 배율(stats에 실려 온다. 없으면 1배)
	var scale := float(stats.get("reward_scale", 1.0)) * float(stats.get("event_gold_scale", 1.0))
	var reward := {"gold": int(round(int(table.get("gold", 0)) * scale)), "gems": int(table.get("gems", 0)), "exp": int(round(int(table.get("exp", 0)) * scale)), "trophies": 0,
		"level_ups": 0, "first_win": false, "tier_before": "", "tier_after": "", "streak": 0, "streak_gold": 0, "pass_exp": 0}
	var played: Dictionary = profile["stats"]
	played["played"] = int(played["played"]) + 1
	match outcome:
		"win":
			played["wins"] = int(played["wins"]) + 1
		"lose":
			played["losses"] = int(played["losses"]) + 1
		_:
			played["draws"] = int(played["draws"]) + 1
	# 최근 전적(프로필 창에 보인다). 소탕처럼 판을 하지 않은 것은 남기지 않는다.
	if not bool(stats.get("no_history", false)):
		var history: Array = profile.get("history", [])
		history.push_front({"mode": mode, "outcome": outcome, "map": str(stats.get("map", "")), "turns": int(stats.get("turns", 0))})
		while history.size() > HISTORY_LIMIT:
			history.pop_back()
		profile["history"] = history
		# 맵별 전적(맵 고르기에 보인다)
		var map_name := str(stats.get("map", ""))
		if map_name != "":
			var maps: Dictionary = profile.get("map_stats", {})
			var record: Dictionary = maps.get(map_name, {"played": 0, "wins": 0})
			record["played"] = int(record["played"]) + 1
			if outcome == "win":
				record["wins"] = int(record["wins"]) + 1
			maps[map_name] = record
			profile["map_stats"] = maps
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
		# 연승: 이기면 +1, 지면 0. 비기면 그대로. 2연승부터 골드를 더 준다.
		var streak := int(played.get("streak", 0))
		if outcome == "win":
			streak += 1
		elif outcome == "lose":
			streak = 0
		played["streak"] = streak
		played["best_streak"] = max(int(played.get("best_streak", 0)), streak)
		reward["streak"] = streak
		if outcome == "win" and streak >= 2:
			var bonus_table: Dictionary = eco.get("rewards", {}).get("streak", {})
			var counted: int = min(streak, int(bonus_table.get("max_count", 5))) - 1
			reward["streak_gold"] = counted * int(bonus_table.get("gold_per_win", 0))
			reward["gold"] = int(reward["gold"]) + int(reward["streak_gold"])
	# 프리미엄 시즌 패스: 판 보상(골드·경험치)을 광고 없이 2배로 준다. 첫 승리 보석·트로피는 그대로.
	var pass_scale := pass_reward_scale(profile, eco)
	if pass_scale > 1 and mode != "local":
		reward["gold"] = int(reward["gold"]) * pass_scale
		reward["exp"] = int(reward["exp"]) * pass_scale
		reward["pass_double"] = pass_scale
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
	add_progress(profile, eco, "gate", int(stats.get("gates", 0)))
	_add_stat(profile, "gates_total", int(stats.get("gates", 0)))
	_record_heroes(profile, stats.get("party", []), outcome == "win")
	if mode != "local":
		reward["pass_exp"] = int(round(int(eco.get("pass", {}).get("exp", {}).get(outcome, 0)) * float(stats.get("event_pass_scale", 1.0))))
		add_pass_exp(profile, eco, int(reward["pass_exp"]))
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
	profile["daily"] = {"date": today, "progress": {}, "claimed": [], "all_claimed": false, "free_summons": 0, "first_win": false, "deals_bought": [], "roulette_spins": 0, "challenge_done": false, "sweeps": 0, "free_card_draws": 0, "ads": {}}
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
			add_pass_exp(profile, eco, int(eco.get("pass", {}).get("exp", {}).get("mission", 0)))
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
## by_ad: 광고를 보고 돌리는 한 번(보석·하루 횟수와 상관없음, 광고 횟수는 watch_ad로 따로 셈).
static func spin_roulette(profile: Dictionary, eco: Dictionary, rng: RandomNumberGenerator, by_ad: bool = false) -> Dictionary:
	var slots: Array = eco.get("roulette", {}).get("slots", [])
	var cost := 0 if by_ad else roulette_cost(profile, eco)
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
	if not by_ad:
		profile["daily"]["roulette_spins"] = roulette_spins(profile) + 1
	add_progress(profile, eco, "roulette", 1)
	grant(profile, slots[index]["reward"])
	return {"index": index, "reward": slots[index]["reward"], "cost": cost}


# ---------------------------------------------------------------- 보상형 광고(2026-11-19)

## 오늘 이 자리(economy.json ads.placements)에서 광고를 더 볼 수 있는 횟수. 하루 전체 한도도 함께 본다.
static func ads_left(profile: Dictionary, eco: Dictionary, placement: String) -> int:
	var table: Dictionary = eco.get("ads", {})
	var spot: Dictionary = table.get("placements", {}).get(placement, {})
	if spot.is_empty():
		return 0
	var seen: Dictionary = profile.get("daily", {}).get("ads", {})
	var total := 0
	for key in seen:
		total += int(seen[key])
	var spot_left := int(spot.get("per_day", 0)) - int(seen.get(placement, 0))
	var day_left := int(table.get("daily_max", 0)) - total
	return maxi(mini(spot_left, day_left), 0)


## 광고를 끝까지 본 뒤 부른다. 횟수를 세고, 그 자리 보상(placements의 reward 또는 extra)을 준다.
## extra: 판 끝 골드 2배·원정 2배처럼 그때그때 정해지는 보상. 못 보면(한도) {}.
static func watch_ad(profile: Dictionary, eco: Dictionary, placement: String, extra: Dictionary = {}) -> Dictionary:
	if ads_left(profile, eco, placement) <= 0:
		return {}
	if not profile["daily"].has("ads"):
		profile["daily"]["ads"] = {}
	profile["daily"]["ads"][placement] = int(profile["daily"]["ads"].get(placement, 0)) + 1
	var reward: Dictionary = (eco.get("ads", {}).get("placements", {}).get(placement, {}) as Dictionary).get("reward", {}).duplicate()
	for key in extra:
		reward[key] = int(reward.get(key, 0)) + int(extra[key])
	grant(profile, reward)
	return reward


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


# ---------------------------------------------------------------- 발끝 효과(2026-11-19)

static func trail(eco: Dictionary, id: String) -> Dictionary:
	for entry in eco.get("trails", []):
		if str(entry["id"]) == id:
			return entry
	return {"id": "none", "name": "없음", "fx": "", "cost": {}}


static func owns_trail(profile: Dictionary, id: String) -> bool:
	return id == "none" or id in profile.get("trails", [])


## 지금 쓰는 발끝 효과의 fx 이름(없으면 "").
static func trail_fx(profile: Dictionary, eco: Dictionary) -> String:
	var id := str(profile.get("trail", "none"))
	return str(trail(eco, id if owns_trail(profile, id) else "none").get("fx", ""))


## 산다(사면 바로 씀). 이미 있거나 값이 모자라면 false.
static func buy_trail(profile: Dictionary, eco: Dictionary, id: String) -> bool:
	var entry := trail(eco, id)
	if str(entry.get("id", "")) != id or owns_trail(profile, id):
		return false
	var cost: Dictionary = entry.get("cost", {})
	for currency in cost:
		if str(currency) != "_comment" and not can_pay(profile, str(currency), int(cost[currency])):
			return false
	for currency in cost:
		pay(profile, str(currency), int(cost[currency]))
	if not profile.has("trails"):
		profile["trails"] = []
	profile["trails"].append(id)
	profile["trail"] = id
	return true


static func equip_trail(profile: Dictionary, id: String) -> bool:
	if not owns_trail(profile, id):
		return false
	profile["trail"] = id
	return true


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


# ---------------------------------------------------------------- 시즌 패스

static func _pass_state(profile: Dictionary) -> Dictionary:
	if not profile.has("pass"):
		profile["pass"] = {"exp": 0, "claimed": []}
	return profile["pass"]


static func add_pass_exp(profile: Dictionary, eco: Dictionary, amount: int) -> void:
	if amount <= 0 or not eco.has("pass"):
		return
	var state := _pass_state(profile)
	var table: Dictionary = eco["pass"]
	var level_list: Array = table.get("levels", [])
	var cap: int = int(table.get("exp_per_level", 100)) * level_list.size()
	state["exp"] = min(cap, int(state["exp"]) + amount)


## 프리미엄 시즌 패스를 가졌는지. 결제가 붙으면 구매 확인 뒤 pass.premium을 true로 둔다.
static func pass_premium(profile: Dictionary) -> bool:
	return bool(_pass_state(profile).get("premium", false))


## 프리미엄 패스가 있으면 판 보상(골드·경험치)에 곱하는 배수. 없으면 1.
static func pass_reward_scale(profile: Dictionary, eco: Dictionary) -> int:
	if not pass_premium(profile):
		return 1
	return maxi(1, int(eco.get("pass", {}).get("premium_reward_scale", 1)))


## 지금 패스 레벨(0부터, 최고는 levels 수)
static func pass_level(profile: Dictionary, eco: Dictionary) -> int:
	var table: Dictionary = eco.get("pass", {})
	var per := int(table.get("exp_per_level", 100))
	return min(table.get("levels", []).size(), int(_pass_state(profile)["exp"]) / max(per, 1))


## 다음 레벨까지 쌓은 비율(0~1). 최고 레벨이면 1.
static func pass_progress(profile: Dictionary, eco: Dictionary) -> float:
	var table: Dictionary = eco.get("pass", {})
	var per := int(table.get("exp_per_level", 100))
	if pass_level(profile, eco) >= table.get("levels", []).size():
		return 1.0
	return float(int(_pass_state(profile)["exp"]) % max(per, 1)) / float(max(per, 1))


static func pass_claimed(profile: Dictionary, level: int) -> bool:
	return level in _pass_state(profile)["claimed"]


## 무료 보상을 받을 수 있는 레벨 수
static func pass_claimable_count(profile: Dictionary, eco: Dictionary) -> int:
	var count := 0
	for level in range(1, pass_level(profile, eco) + 1):
		if not pass_claimed(profile, level):
			count += 1
	return count


## level(1부터)의 무료 보상을 받는다. 아직 못 갔거나 이미 받았으면 {}.
static func claim_pass(profile: Dictionary, eco: Dictionary, level: int) -> Dictionary:
	var levels: Array = eco.get("pass", {}).get("levels", [])
	if level < 1 or level > levels.size() or level > pass_level(profile, eco) or pass_claimed(profile, level):
		return {}
	_pass_state(profile)["claimed"].append(level)
	var reward: Dictionary = levels[level - 1].get("free", {})
	grant(profile, reward)
	return reward


## 받을 수 있는 패스 보상을 모두 받는다. 합계 {"gold", "gems", "count"}.
static func claim_all_pass(profile: Dictionary, eco: Dictionary) -> Dictionary:
	var total := {"gold": 0, "gems": 0, "count": 0}
	for level in range(1, pass_level(profile, eco) + 1):
		var reward := claim_pass(profile, eco, level)
		if not reward.is_empty():
			total["gold"] = int(total["gold"]) + int(reward.get("gold", 0))
			total["gems"] = int(total["gems"]) + int(reward.get("gems", 0))
			total["count"] = int(total["count"]) + 1
	return total


# ---------------------------------------------------------------- 쿠폰

## 쿠폰 코드를 쓴다. 결과: {"ok": 성공 여부, "reason": 실패 이유("unknown"·"used"), "reward": 보상, "text": 쿠폰 이름}
static func redeem_coupon(profile: Dictionary, coupons: Dictionary, code: String) -> Dictionary:
	var key := code.strip_edges().to_upper()
	var table: Dictionary = coupons.get("coupons", {})
	if key == "" or not table.has(key):
		return {"ok": false, "reason": "unknown"}
	if not profile.has("coupons_used"):
		profile["coupons_used"] = []
	if key in profile["coupons_used"]:
		return {"ok": false, "reason": "used"}
	profile["coupons_used"].append(key)
	var reward: Dictionary = table[key].get("reward", {})
	grant(profile, reward)
	return {"ok": true, "reason": "", "reward": reward, "text": str(table[key].get("text", ""))}


# ---------------------------------------------------------------- 파티 저장 칸

## index번 칸(0~2)에 파티를 저장한다. 파티가 규칙에 안 맞으면 false.
static func save_preset(profile: Dictionary, characters: Array, index: int, party: Dictionary, point_limit: int) -> bool:
	if index < 0 or index > 2 or not party_ok(profile, characters, party, point_limit):
		return false
	if not profile.has("party_presets") or typeof(profile["party_presets"]) != TYPE_ARRAY:
		profile["party_presets"] = [{}, {}, {}]
	while profile["party_presets"].size() < 3:
		profile["party_presets"].append({})
	profile["party_presets"][index] = {"attack": str(party["attack"]), "defense": str(party["defense"]), "support": str(party["support"])}
	return true


# ---------------------------------------------------------------- 연승·전투력·조각 팔기

## 지금 랭크전 연승 수
static func streak(profile: Dictionary) -> int:
	return int(profile.get("stats", {}).get("streak", 0))


## 파티 전투력(보여 주기용). party: {"attack": id, ...}, levels: {"attack": 레벨, ...} (없으면 1).
static func party_power(characters: Array, eco: Dictionary, party: Dictionary, levels: Dictionary = {}) -> int:
	var weight: Dictionary = eco.get("power", {})
	var by_id := {}
	for character in characters:
		by_id[str(character["id"])] = character
	var total := 0
	for slot in ["attack", "defense", "support"]:
		var hero: Dictionary = by_id.get(str(party.get(slot, "")), {})
		if hero.is_empty():
			continue
		match slot:
			"attack":
				total += int(hero["attack"]) * int(weight.get("attack", 10)) + int(hero["move"]) * int(weight.get("move", 8))
			"defense":
				total += int(hero["defense"]) * int(weight.get("defense", 10))
			"support":
				total += int(hero["intellect"]) * int(weight.get("intellect", 12))
		total += int(hero["grade"]) * int(weight.get("grade", 5))
		total += (int(levels.get(slot, 1)) - 1) * int(weight.get("level", 6))
	return total


## 내 파티의 전투력(가진 영웅 레벨 반영)
static func my_power(profile: Dictionary, characters: Array, eco: Dictionary) -> int:
	var levels := {}
	for slot in ["attack", "defense", "support"]:
		levels[slot] = level_of(profile, str(profile["party"].get(slot, "")))
	return party_power(characters, eco, profile["party"], levels)


## 최고 레벨 영웅의 남는 조각을 골드로 판다. 판 조각 수를 돌려준다(못 팔면 0).
static func sell_shards(profile: Dictionary, eco: Dictionary, id: String) -> int:
	if not owns(profile, id) or level_of(profile, id) < int(eco.get("upgrade", {}).get("max_level", 5)):
		return 0
	var shards := int(profile["owned"][id]["shards"])
	if shards <= 0:
		return 0
	profile["owned"][id]["shards"] = 0
	grant(profile, {"gold": shards * int(eco.get("upgrade", {}).get("shard_sell_gold", 0))})
	return shards


# ---------------------------------------------------------------- 기간 이벤트

## today(YYYY-MM-DD)에 열려 있는 이벤트 목록. 날짜는 글자 비교로 충분하다(같은 형식).
static func active_events(events: Dictionary, today: String) -> Array:
	var result: Array = []
	for event in events.get("events", []):
		if event.has("weekdays"):
			# 요일 이벤트: 0=일요일 … 6=토요일
			var weekday := int(Time.get_datetime_dict_from_datetime_string(today, true).get("weekday", -1))
			for day in event["weekdays"]:
				if int(day) == weekday:
					result.append(event)
					break
		elif today >= str(event.get("start", "")) and today <= str(event.get("end", "")):
			result.append(event)
	return result


## 열려 있는 이벤트의 효과 배율을 곱한 값. 해당 효과가 없으면 1.
static func event_scale(events: Dictionary, today: String, effect: String) -> float:
	var scale := 1.0
	for event in active_events(events, today):
		scale *= float(event.get("effect", {}).get(effect, 1.0))
	return scale


# ---------------------------------------------------------------- 모험 소탕

## 오늘 남은 소탕 횟수
static func sweeps_left(profile: Dictionary, eco: Dictionary) -> int:
	return max(0, int(eco.get("sweep", {}).get("per_day", 0)) + int(profile.get("daily", {}).get("sweeps_bought", 0)) - int(profile.get("daily", {}).get("sweeps", 0)))


## 오늘 보석으로 더 살 수 있는 소탕 횟수
static func sweep_buys_left(profile: Dictionary, eco: Dictionary) -> int:
	return max(0, int(eco.get("sweep", {}).get("extra_per_day", 0)) - int(profile.get("daily", {}).get("sweeps_bought", 0)))


## 보석으로 소탕 1번을 더 산다.
static func buy_sweep(profile: Dictionary, eco: Dictionary) -> bool:
	if sweep_buys_left(profile, eco) <= 0 or not pay(profile, "gems", int(eco["sweep"].get("extra_cost_gems", 0))):
		return false
	profile["daily"]["sweeps_bought"] = int(profile["daily"].get("sweeps_bought", 0)) + 1
	return true


## 별 3개로 깬 스테이지이고 오늘 횟수가 남았으면 소탕할 수 있다.
static func can_sweep(profile: Dictionary, eco: Dictionary, stage_id: String) -> bool:
	return stage_stars(profile, stage_id) >= 3 and sweeps_left(profile, eco) > 0


## 소탕: 대전 없이 모험 승리 보상을 받는다. 못 하면 {}. (전적·미션·패스는 판을 한 것과 같이 오른다)
static func sweep(profile: Dictionary, eco: Dictionary, stage_id: String, stats: Dictionary = {}) -> Dictionary:
	if not can_sweep(profile, eco, stage_id):
		return {}
	profile["daily"]["sweeps"] = int(profile["daily"].get("sweeps", 0)) + 1
	var sweep_stats := stats.duplicate()
	sweep_stats["no_history"] = true
	return record_match(profile, eco, "adventure", "win", sweep_stats)


## 별 3개로 깬 모험 스테이지 수
static func three_star_count(profile: Dictionary) -> int:
	var count := 0
	for id in profile.get("adventure", {}):
		if int(profile["adventure"][id]) >= 3:
			count += 1
	return count


## 일괄 강화: 지금 강화할 수 있는 영웅을 파티원 먼저, 한 단계씩 돌아가며 올린다. 올린 횟수를 돌려준다.
static func upgrade_all(profile: Dictionary, eco: Dictionary) -> int:
	var order: Array = []
	for slot in ["attack", "defense", "support"]:
		var id := str(profile.get("party", {}).get(slot, ""))
		if id != "" and not order.has(id):
			order.append(id)
	var rest: Array = profile.get("owned", {}).keys()
	rest.sort()
	for id in rest:
		if not order.has(str(id)):
			order.append(str(id))
	var done := 0
	var changed := true
	while changed:
		changed = false
		for id in order:
			if upgrade(profile, eco, str(id)):
				done += 1
				changed = true
	return done


# ---------------------------------------------------------------- 초보자 길잡이 과제

## 지금 하고 있는 길잡이 과제. 모두 끝냈으면 {}.
static func guide_current(profile: Dictionary, data: Dictionary) -> Dictionary:
	var steps: Array = data.get("guide", {}).get("steps", [])
	var index := int(profile.get("guide_step", 0))
	if index < 0 or index >= steps.size():
		return {}
	return steps[index]


## 지금 과제를 달성했나(보상을 받을 수 있나)
static func guide_claimable(profile: Dictionary, data: Dictionary) -> bool:
	var step := guide_current(profile, data)
	return not step.is_empty() and achievement_value(profile, data, str(step["stat"])) >= int(step["goal"])


## 지금 과제의 보상을 받고 다음 과제로 넘어간다. 못 받으면 {}.
static func claim_guide(profile: Dictionary, data: Dictionary) -> Dictionary:
	if not guide_claimable(profile, data):
		return {}
	var step := guide_current(profile, data)
	profile["guide_step"] = int(profile.get("guide_step", 0)) + 1
	grant(profile, step["reward"])
	return step["reward"]


# ---------------------------------------------------------------- 수집 앨범

## 그 분류에서 가진 영웅 수
static func album_count(profile: Dictionary, characters: Array, category: String) -> int:
	var count := 0
	for character in characters:
		if str(character.get("category", "")) == category and profile.get("owned", {}).has(str(character["id"])):
			count += 1
	return count


## 받을 수 있는 앨범 보상 단계(0부터)의 목록
static func album_claimable(profile: Dictionary, eco: Dictionary, characters: Array, category: String) -> Array:
	var result: Array = []
	var steps: Array = eco.get("album", {}).get("steps", [])
	var owned := album_count(profile, characters, category)
	for index in steps.size():
		if owned >= int(steps[index]) and not album_claimed(profile, category, index):
			result.append(index)
	return result


static func album_claimed(profile: Dictionary, category: String, index: int) -> bool:
	return (profile.get("album", []) as Array).has("%s:%d" % [category, index])


## 받을 수 있는 앨범 보상이 하나라도 있나
static func album_has_claimable(profile: Dictionary, eco: Dictionary, characters: Array) -> bool:
	for category in ["영웅", "위인", "신화", "근현대"]:
		if not album_claimable(profile, eco, characters, category).is_empty():
			return true
	return false


## 그 분류의 받을 수 있는 앨범 보상을 모두 받는다. 받은 것을 합쳐 돌려준다(없으면 {}).
static func claim_album(profile: Dictionary, eco: Dictionary, characters: Array, category: String) -> Dictionary:
	var total := {}
	var claimed: Array = profile.get("album", [])
	for index in album_claimable(profile, eco, characters, category):
		var reward: Dictionary = eco["album"]["rewards"][index]
		grant(profile, reward)
		claimed.append("%s:%d" % [category, index])
		for key in reward:
			total[key] = int(total.get(key, 0)) + int(reward[key])
	profile["album"] = claimed
	return total


# ---------------------------------------------------------------- 카드 앨범(2026-11-18)
## 등급마다 가진 카드 수가 economy.json card_album.steps에 닿으면 보상. 받은 단계는 profile["card_album"]에 "등급:순번".

static func card_album_count(profile: Dictionary, cards: Dictionary, grade: int) -> int:
	var count := 0
	for id in profile.get("cards", []):
		if cards.has(str(id)) and card_grade(cards, str(id)) == grade:
			count += 1
	return count


static func card_album_total(cards: Dictionary, grade: int) -> int:
	var count := 0
	for id in cards:
		if card_grade(cards, str(id)) == grade:
			count += 1
	return count


static func card_album_claimed(profile: Dictionary, grade: int, index: int) -> bool:
	return (profile.get("card_album", []) as Array).has("%d:%d" % [grade, index])


static func card_album_claimable(profile: Dictionary, eco: Dictionary, cards: Dictionary, grade: int) -> Array:
	var result: Array = []
	var steps: Array = eco.get("card_album", {}).get("steps", {}).get(str(grade), [])
	var owned := card_album_count(profile, cards, grade)
	for index in steps.size():
		if owned >= int(steps[index]) and not card_album_claimed(profile, grade, index):
			result.append(index)
	return result


static func card_album_has_claimable(profile: Dictionary, eco: Dictionary, cards: Dictionary) -> bool:
	for grade in [1, 2, 3]:
		if not card_album_claimable(profile, eco, cards, grade).is_empty():
			return true
	return false


## 그 등급의 받을 수 있는 카드 앨범 보상을 모두 받는다. 합친 보상(없으면 {}).
static func claim_card_album(profile: Dictionary, eco: Dictionary, cards: Dictionary, grade: int) -> Dictionary:
	var total := {}
	var claimed: Array = profile.get("card_album", [])
	var rewards: Array = eco.get("card_album", {}).get("rewards", {}).get(str(grade), [])
	for index in card_album_claimable(profile, eco, cards, grade):
		if index >= rewards.size():
			continue
		var reward: Dictionary = rewards[index]
		grant(profile, reward)
		claimed.append("%d:%d" % [grade, index])
		for key in reward:
			total[key] = int(total.get(key, 0)) + int(reward[key])
	profile["card_album"] = claimed
	return total


# ---------------------------------------------------------------- 유물(장착 아이템)

static func relic(eco: Dictionary, id: String) -> Dictionary:
	for item in eco.get("relics", []):
		if str(item["id"]) == id:
			return item
	return {}


static func owns_relic(profile: Dictionary, id: String) -> bool:
	return (profile.get("relics", []) as Array).has(id)


## 지금 장착한 유물. 없으면 {}.
static func current_relic(profile: Dictionary, eco: Dictionary) -> Dictionary:
	var id := str(profile.get("relic", ""))
	if id == "" or not owns_relic(profile, id):
		return {}
	return relic(eco, id)


## 유물을 산다. 사면 바로 장착한다.
static func buy_relic(profile: Dictionary, eco: Dictionary, id: String) -> bool:
	var item := relic(eco, id)
	if item.is_empty() or owns_relic(profile, id):
		return false
	var cost: Dictionary = item.get("cost", {})
	for currency in cost:
		if not can_pay(profile, str(currency), int(cost[currency])):
			return false
	for currency in cost:
		pay(profile, str(currency), int(cost[currency]))
	var owned: Array = profile.get("relics", [])
	owned.append(id)
	profile["relics"] = owned
	profile["relic"] = id
	return true


## 가진 유물을 장착한다. 이미 장착한 것을 고르면 벗는다.
static func equip_relic(profile: Dictionary, id: String) -> bool:
	if not owns_relic(profile, id):
		return false
	profile["relic"] = "" if str(profile.get("relic", "")) == id else id
	return true


# ---------------------------------------------------------------- 홀짝 미니게임

static func odd_even_left(profile: Dictionary, eco: Dictionary) -> int:
	return max(0, int(eco.get("odd_even", {}).get("per_day", 0)) - int(profile.get("daily", {}).get("odd_even", 0)))


## 홀짝을 건다. guess는 "odd"(홀) 또는 "even"(짝). 못 하면 {}.
## 하면 {"roll": 나온 눈, "won": 맞혔나, "reward": 받은 것}
static func play_odd_even(profile: Dictionary, eco: Dictionary, guess: String, rng: RandomNumberGenerator) -> Dictionary:
	if odd_even_left(profile, eco) <= 0 or not guess in ["odd", "even"]:
		return {}
	profile["daily"]["odd_even"] = int(profile["daily"].get("odd_even", 0)) + 1
	var roll := rng.randi_range(1, 6)
	var won := (roll % 2 == 1) == (guess == "odd")
	var reward: Dictionary = eco["odd_even"]["win" if won else "lose"]
	grant(profile, reward)
	return {"roll": roll, "won": won, "reward": reward}


# ---------------------------------------------------------------- 주간 리그 보상

## 그 날짜가 속한 주의 번호(월요일에 바뀐다)
static func week_of(today: String) -> int:
	var days := int(Time.get_unix_time_from_datetime_string(today)) / 86400
	return (days + 3) / 7


## 그 순위가 받는 주간 보상 줄 {max_rank, reward, medal}
static func league_tier(eco: Dictionary, rank: int) -> Dictionary:
	for tier in eco.get("league_weekly", {}).get("tiers", []):
		if rank <= int(tier["max_rank"]):
			return tier
	return {}


## 주가 바뀌었으면 지난주 순위로 보상을 준다. 줬으면 {"rank", "reward", "medal"}, 아니면 {}.
## 처음 부르면 이번 주만 적어 둔다.
static func settle_league(profile: Dictionary, eco: Dictionary, today: String) -> Dictionary:
	var week := week_of(today)
	if not profile.has("league_week"):
		profile["league_week"] = week
		return {}
	if int(profile["league_week"]) == week:
		return {}
	profile["league_week"] = week
	var rank := league_rank(profile, eco)
	var tier := league_tier(eco, rank)
	if tier.is_empty():
		return {}
	grant(profile, tier["reward"])
	var medal := bool(tier.get("medal", false))
	if medal:
		profile["medals"] = int(profile.get("medals", 0)) + 1
	return {"rank": rank, "reward": tier["reward"], "medal": medal}


## 랭크전 상대가 갖고 시작하는 효과(유물과 같은 형식). 트로피가 낮으면 {}.
static func rank_boost(eco: Dictionary, trophies: int) -> Dictionary:
	var best := {}
	var best_at := -1
	for tier in eco.get("rank_boost", {}).get("tiers", []):
		if trophies >= int(tier["trophies"]) and int(tier["trophies"]) > best_at:
			best_at = int(tier["trophies"])
			best = tier["relic"]
	return best


# ---------------------------------------------------------------- 원정 보상(접속하지 않은 동안 쌓이는 골드)

## 지금까지 쌓인 원정 골드. now는 지금 시각(초, 유닉스 시간). 처음이면 0.
static func idle_gold(profile: Dictionary, eco: Dictionary, now: int) -> int:
	var table: Dictionary = eco.get("idle", {})
	if not profile.has("idle_at"):
		return 0
	var seconds: int = clampi(now - int(profile["idle_at"]), 0, int(table.get("max_hours", 0)) * 3600)
	var tier_index := 0
	var tiers: Array = eco.get("tiers", [])
	for index in tiers.size():
		if int(profile.get("trophies", 0)) >= int(tiers[index].get("min", 0)):
			tier_index = index
	var per_hour := int(table.get("gold_per_hour", 0)) + tier_index * int(table.get("gold_per_tier", 0))
	return int(float(per_hour) * float(seconds) / 3600.0)


## 받을 만큼 쌓였나(min_minutes분이 지났나)
static func idle_ready(profile: Dictionary, eco: Dictionary, now: int) -> bool:
	return profile.has("idle_at") and now - int(profile["idle_at"]) >= int(eco.get("idle", {}).get("min_minutes", 0)) * 60


## 원정 보상을 받는다. 받은 골드를 돌려준다. 처음 부르면 시계만 맞추고 0.
static func claim_idle(profile: Dictionary, eco: Dictionary, now: int) -> int:
	if not profile.has("idle_at"):
		profile["idle_at"] = now
		return 0
	if not idle_ready(profile, eco, now):
		return 0
	var gold := idle_gold(profile, eco, now)
	profile["idle_at"] = now
	if gold > 0:
		grant(profile, {"gold": gold})
	return gold


# ---------------------------------------------------------------- 보석 마일리지

## 받을 수 있는 마일리지 단계(0부터)의 목록
static func mileage_claimable(profile: Dictionary, eco: Dictionary) -> Array:
	var result: Array = []
	var steps: Array = eco.get("mileage", {}).get("steps", [])
	var claimed: Array = profile.get("mileage_claimed", [])
	for index in steps.size():
		if int(profile.get("gems_spent", 0)) >= int(steps[index]) and not claimed.has(index):
			result.append(index)
	return result


## 받을 수 있는 마일리지 보상을 모두 받는다. 합친 보상을 돌려준다(없으면 {}).
static func claim_mileage(profile: Dictionary, eco: Dictionary) -> Dictionary:
	var total := {}
	var claimed: Array = profile.get("mileage_claimed", [])
	for index in mileage_claimable(profile, eco):
		var reward: Dictionary = eco["mileage"]["rewards"][index]
		grant(profile, reward)
		claimed.append(index)
		for key in reward:
			total[key] = int(total.get(key, 0)) + int(reward[key])
	profile["mileage_claimed"] = claimed
	return total



# ---------------------------------------------------------------- 아이템 카드(뽑기·덱)
## 카드는 등급(1=★ 일반, 2=★★ 희귀, 3=★★★ 전설)이 있고, 카드 뽑기로 모은다.
## 판에서는 덱에 넣은 카드만 뽑힌다(game.gd의 setup이 party["deck"]을 받는다).
## cards: data/cards.json의 cards 사전. 수치는 economy.json의 card_gacha·card_deck.

static func owns_card(profile: Dictionary, id: String) -> bool:
	return (profile.get("cards", []) as Array).has(id)


## 확률 보기 창(2026-11-19, 정식 출시 준비: 확률형 아이템 정보 공개)에 보여 줄 표.
## kind: hero(영웅 소환)·hero_gold(골드 소환)·card(카드 뽑기)·card_gold(골드 카드 뽑기)·roulette(행운의 룰렛).
## 실제 뽑기와 같은 economy.json 값으로 계산한다. 등급 안에서는 모두 같은 확률이다.
## 돌려주는 값: {"groups": [{"grade", "rate"(%), "items": [{"id", "name", "rate"(%)}]}], "pity_3", "guarantee_two"}
## 룰렛은 groups 하나에 칸마다 {"reward", "rate"}.
static func odds_table(kind: String, characters: Array, cards: Dictionary, eco: Dictionary, date: String = "") -> Dictionary:
	if kind == "roulette":
		var slots: Array = eco.get("roulette", {}).get("slots", [])
		var total := 0.0
		for slot in slots:
			total += float(slot.get("weight", 0))
		var items: Array = []
		for slot in slots:
			items.append({"reward": slot.get("reward", {}), "rate": 100.0 * float(slot.get("weight", 0)) / maxf(total, 0.001)})
		return {"groups": [{"grade": 0, "rate": 100.0, "items": items}], "pity_3": 0, "guarantee_two": false}
	var is_card := kind.begins_with("card")
	var table: Dictionary = eco.get("card_gacha" if is_card else "summon", {})
	var gold := kind.ends_with("_gold")
	var rates: Dictionary = (table.get("gold", {}) as Dictionary).get("rates", {}) if gold else table.get("rates", {})
	var total_rate := 0.0
	for key in ["3", "2", "1"]:
		total_rate += float(rates.get(key, 0))
	var groups: Array = []
	for grade in [3, 2, 1]:
		var rate := 100.0 * float(rates.get(str(grade), 0)) / maxf(total_rate, 0.001)
		if rate <= 0.0:
			continue
		var pool: Array = []
		if is_card:
			for key in cards:
				if str(key) != "_comment" and card_grade(cards, str(key)) == grade:
					pool.append({"id": str(key), "name": str((cards[key] as Dictionary).get("name", key))})
		else:
			for character in characters:
				if int(character.get("grade", 0)) == grade:
					pool.append({"id": str(character["id"]), "name": str(character.get("name", character["id"]))})
		var items: Array = []
		var pickup := "" if is_card or gold else pickup_hero(eco, date)
		var has_pickup := false
		for entry in pool:
			has_pickup = has_pickup or (grade == 3 and str(entry["id"]) == pickup)
		var share := float(table.get("pickup", {}).get("share", 0)) / 100.0
		for entry in pool:
			var each := rate / float(pool.size())
			if has_pickup and pool.size() > 1:
				each = rate * share if str(entry["id"]) == pickup else rate * (1.0 - share) / float(pool.size() - 1)
			items.append({"id": entry["id"], "name": entry["name"], "rate": each, "pickup": has_pickup and str(entry["id"]) == pickup})
		if has_pickup:
			items.sort_custom(func(a, b) -> bool: return bool(a["pickup"]) and not bool(b["pickup"]))
		groups.append({"grade": grade, "rate": rate, "items": items})
	var result := {"groups": groups, "pity_3": 0 if gold else int(table.get("pity_3", 0)), "guarantee_two": true}
	if not is_card and not gold:
		result["pickup"] = pickup_hero(eco, date)
		result["pickup_share"] = int(table.get("pickup", {}).get("share", 0))
	return result


static func card_grade(cards: Dictionary, id: String) -> int:
	return int((cards.get(id, {}) as Dictionary).get("grade", 1))


static func free_card_draws_left(profile: Dictionary, eco: Dictionary) -> int:
	var per_day := int(eco.get("card_gacha", {}).get("free_per_day", 0))
	return max(0, per_day - int(profile["daily"].get("free_card_draws", 0)))


## 무료 카드 뽑기 1회를 쓴다. 남은 것이 없으면 false.
static func use_free_card_draw(profile: Dictionary, eco: Dictionary) -> bool:
	if free_card_draws_left(profile, eco) <= 0:
		return false
	profile["daily"]["free_card_draws"] = int(profile["daily"].get("free_card_draws", 0)) + 1
	return true


## 카드 뽑기 한 번의 등급. 보장이 차면 ★★★, guarantee_two면 ★★ 이상.
static func roll_card_grade(profile: Dictionary, eco: Dictionary, rng: RandomNumberGenerator, guarantee_two: bool) -> int:
	var table: Dictionary = eco.get("card_gacha", {})
	var pity_limit := int(table.get("pity_3", 0))
	if pity_limit > 0 and int(profile.get("card_pity", 0)) + 1 >= pity_limit:
		return 3
	var rates: Dictionary = table.get("rates", {"1": 100})
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


## 카드를 count장 뽑는다. 비용은 먼저 치러야 한다(pay 또는 무료 뽑기).
## 돌려주는 값: [{"id", "grade", "new": 처음 얻었는지, "gold": 중복이라 바뀐 골드}]
## gold: true면 골드 뽑기(card_gacha.gold 확률, ★·★★만, ★★★ 보장은 세지 않음).
static func draw_cards(profile: Dictionary, cards: Dictionary, eco: Dictionary, count: int, rng: RandomNumberGenerator, gold: bool = false) -> Array:
	var dupe_gold: Dictionary = eco.get("card_gacha", {}).get("dupe_gold", {})
	if not profile.has("cards"):
		profile["cards"] = []
	var results: Array = []
	for index in count:
		var guarantee_two := count >= 10 and index == count - 1 and not _has_grade_at_least(results, 2)
		var grade := 1
		if gold:
			grade = roll_rates(eco.get("card_gacha", {}).get("gold", {}).get("rates", {"1": 100}), rng, guarantee_two)
		else:
			grade = roll_card_grade(profile, eco, rng, guarantee_two)
			if grade == 3:
				profile["card_pity"] = 0
			else:
				profile["card_pity"] = int(profile.get("card_pity", 0)) + 1
		var pool: Array = []
		for key in cards:
			if card_grade(cards, str(key)) == grade:
				pool.append(str(key))
		if pool.is_empty():
			continue
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		var entry := {"id": id, "grade": grade, "new": false, "gold": 0}
		if owns_card(profile, id):
			var refund := int(dupe_gold.get(str(grade), 100))
			grant(profile, {"gold": refund})
			entry["gold"] = refund
		else:
			profile["cards"].append(id)
			entry["new"] = true
		results.append(entry)
	_add_stat(profile, "card_draws_total", count)
	return results


## 덱이 규칙에 맞는지. 맞으면 "", 아니면 이유.
static func deck_error(profile: Dictionary, cards: Dictionary, eco: Dictionary, deck: Array) -> String:
	var rule: Dictionary = eco.get("card_deck", {})
	var per_grade: Dictionary = rule.get("per_grade", {})
	var seen := {}
	var counts := {1: 0, 2: 0, 3: 0}
	for id in deck:
		if not cards.has(str(id)):
			return "없는 카드가 있어요."
		if not owns_card(profile, str(id)):
			return "가지지 않은 카드가 있어요."
		if seen.has(str(id)):
			return "같은 카드는 한 장만 넣을 수 있어요."
		seen[str(id)] = true
		var grade := card_grade(cards, str(id))
		counts[grade] = int(counts.get(grade, 0)) + 1
	if deck.size() > int(rule.get("size", 15)):
		return "덱에는 %d장까지 넣을 수 있어요." % int(rule.get("size", 15))
	for grade in [3, 2, 1]:
		var limit := int(per_grade.get(str(grade), 99))
		if int(counts[grade]) > limit:
			return "%s 카드는 %d장까지 넣을 수 있어요." % ["★".repeat(grade), limit]
	if deck.size() < int(rule.get("min", 1)):
		return "덱에는 %d장 이상 있어야 해요." % int(rule.get("min", 1))
	return ""


## 덱에 든 등급별 장수 {3: n, 2: n, 1: n}
static func deck_counts(cards: Dictionary, deck: Array) -> Dictionary:
	var counts := {1: 0, 2: 0, 3: 0}
	for id in deck:
		var grade := card_grade(cards, str(id))
		counts[grade] = int(counts.get(grade, 0)) + 1
	return counts


## 카드 한 장을 덱에 넣거나 뺀다. 되면 "", 안 되면 이유.
static func toggle_deck(profile: Dictionary, cards: Dictionary, eco: Dictionary, id: String) -> String:
	var deck: Array = (profile.get("deck", []) as Array).duplicate()
	if deck.has(id):
		deck.erase(id)
	else:
		deck.append(id)
	var problem := deck_error(profile, cards, eco, deck)
	if problem != "":
		return problem
	profile["deck"] = deck
	return ""


## 저장된 덱을 규칙에 맞게 다듬는다. 카드 등급이 바뀌어 등급별 자리 수를 넘게 된 덱은
## 넘친 카드만(뒤에 넣은 것부터) 빼고, 없는 카드·가지지 않은 카드·겹친 카드도 뺀다. 바뀌었으면 true.
static func fit_deck(profile: Dictionary, cards: Dictionary, eco: Dictionary) -> bool:
	var rule: Dictionary = eco.get("card_deck", {})
	var per_grade: Dictionary = rule.get("per_grade", {})
	var size := int(rule.get("size", 15))
	var old: Array = profile.get("deck", [])
	var kept: Array = []
	var counts := {1: 0, 2: 0, 3: 0}
	for id in old:
		var key := str(id)
		if not cards.has(key) or not owns_card(profile, key) or kept.has(key) or kept.size() >= size:
			continue
		var grade := card_grade(cards, key)
		if int(counts.get(grade, 0)) >= int(per_grade.get(str(grade), 99)):
			continue
		counts[grade] = int(counts.get(grade, 0)) + 1
		kept.append(key)
	if kept.size() == old.size():
		return false
	profile["deck"] = kept
	return true


## 판에 들고 갈 덱. 넘친 카드는 빼서 맞추고, 그래도 안 맞으면(너무 적음 등) 처음 덱으로 되돌린다.
static func battle_deck(profile: Dictionary, cards: Dictionary, eco: Dictionary) -> Array:
	fit_deck(profile, cards, eco)
	var deck: Array = profile.get("deck", [])
	if deck_error(profile, cards, eco, deck) == "":
		return deck.duplicate()
	var fallback: Array = []
	for id in eco.get("start", {}).get("deck", []):
		if cards.has(str(id)):
			fallback.append(str(id))
			if not owns_card(profile, str(id)):
				profile["cards"].append(str(id))
	profile["deck"] = fallback.duplicate()
	return fallback

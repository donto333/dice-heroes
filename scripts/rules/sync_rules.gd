extends RefCounted
## 시각이 같거나 양쪽 모두 예전 저장이면 현재 기기 기록을 유지한다.

static func choose(local: Dictionary, remote: Dictionary) -> Dictionary:
	if remote.is_empty():
		return local
	if local.is_empty():
		return remote
	# 길잡이 단계가 없는 예전 저장은 새 프로필로 보지 않는다.
	if int(local.get("guide_flow", -1)) == 0 and int(local.get("level", 1)) == 1 and int(local.get("exp", 0)) == 0:
		var stats: Dictionary = local.get("stats", {})
		if stats.values().all(func(value): return int(value) == 0) and local.get("purchases", []).is_empty():
			return remote
	return remote if float(remote.get("saved_at", 0)) > float(local.get("saved_at", 0)) else local

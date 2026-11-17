class_name Lang
extends Translation
## 게임 글 번역(한국어 원문 → 영어·베트남어).
##
## 화면 코드는 지금처럼 한국어로 글을 넣는다. Godot는 Label·Button 등의 글을 그릴 때
## TranslationServer에 물어보는데, 이 번역표가 원문을 찾아 바꿔 준다.
## - 번역 파일: data/i18n/<언어>.json  {"한국어 원문": "번역"}
## - "보석 %d개"처럼 숫자·이름이 끼는 글도 번역 파일에 %d·%s 꼴로 적어 두면,
##   화면에 나온 "보석 30개"를 그 꼴에 맞춰 찾아 "30 gems"로 바꾼다.
## - 번역이 없는 글은 한국어 그대로 보인다.
## - 고른 언어는 기기에 저장된다(user://lang.cfg). 기본은 한국어.

const LANGUAGES := [
	{"code": "ko", "name": "한국어"},
	{"code": "en", "name": "English"},
	{"code": "vi", "name": "Tiếng Việt"},
]
const CONFIG_PATH := "user://lang.cfg"

static var current := "ko"
static var _active: Lang = null

var _exact: Dictionary = {}
## [정규식, 번역 꼴, 끼워 넣을 자리 수] 목록. 긴 꼴부터 맞춰 본다.
var _patterns: Array = []
var _cache: Dictionary = {}


## 처음 켤 때 한 번 부른다. 저장해 둔 언어를 불러 적용한다.
static func setup() -> void:
	var config := ConfigFile.new()
	var code := "ko"
	if config.load(CONFIG_PATH) == OK:
		code = str(config.get_value("lang", "code", "ko"))
	use(code)


## 언어를 바꾼다(설정 화면). 화면은 부른 쪽이 다시 그린다.
static func use(code: String) -> void:
	if not LANGUAGES.any(func(item): return item["code"] == code):
		code = "ko"
	current = code
	if _active != null:
		TranslationServer.remove_translation(_active)
		_active = null
	if code != "ko":
		var table := Lang.new()
		table.locale = code
		table._load(code)
		TranslationServer.add_translation(table)
		_active = table
	TranslationServer.set_locale(code)
	var config := ConfigFile.new()
	config.set_value("lang", "code", code)
	config.save(CONFIG_PATH)


static func language_name(code: String = current) -> String:
	for item in LANGUAGES:
		if item["code"] == code:
			return str(item["name"])
	return code


## 다음 언어 코드(설정 버튼을 누를 때마다 차례로 바뀜).
static func next_code() -> String:
	for i in LANGUAGES.size():
		if LANGUAGES[i]["code"] == current:
			return str(LANGUAGES[(i + 1) % LANGUAGES.size()]["code"])
	return "ko"


## 코드에서 직접 번역할 때(그림에 글을 그리는 곳 등).
static func t(text: String) -> String:
	if _active == null:
		return text
	return str(_active._get_message(StringName(text), StringName()))


func _load(code: String) -> void:
	var path := "res://data/i18n/%s.json" % code
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("번역 파일이 없다: " + path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("번역 파일을 읽지 못했다: " + path)
		return
	var shaped: Array = []
	for source in parsed:
		var target := str(parsed[source])
		if target == "" or source.begins_with("_"):
			continue
		if _has_slot(source):
			shaped.append([source, target])
		else:
			_exact[source] = target
	# 고정된 글자가 많은 꼴부터 맞춰 봐야 "보석 %d"가 "보석 %d개"를 먼저 가로채지 않는다.
	shaped.sort_custom(func(a, b): return _fixed_length(a[0]) > _fixed_length(b[0]))
	for pair in shaped:
		var regex := RegEx.new()
		if regex.compile(_to_regex(pair[0])) == OK:
			_patterns.append([regex, pair[1]])


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var text := String(src_message)
	if text == "":
		return src_message
	if _cache.has(text):
		return _cache[text]
	var result := _translate(text)
	if _cache.size() > 4000:
		_cache.clear()
	_cache[text] = result
	return StringName(result)


func _translate(text: String) -> String:
	if _exact.has(text):
		return _exact[text]
	# 여러 줄 글은 줄마다 따로 찾는다.
	if text.contains("\n"):
		var lines := text.split("\n")
		var changed := false
		for i in lines.size():
			var line := _translate_line(lines[i])
			if line != lines[i]:
				lines[i] = line
				changed = true
		return "\n".join(lines) if changed else text
	return _translate_line(text)


func _translate_line(text: String) -> String:
	if _exact.has(text):
		return _exact[text]
	var stripped := text.strip_edges()
	if stripped != text and _exact.has(stripped):
		return text.replace(stripped, _exact[stripped])
	for pattern in _patterns:
		var found: RegExMatch = pattern[0].search(text)
		if found == null:
			continue
		var values: Array = []
		for i in range(1, found.get_group_count() + 1):
			var value := found.get_string(i)
			# 끼워 넣은 이름(영웅 이름 등)도 번역이 있으면 바꾼다.
			values.append(_exact.get(value, value))
		return _fill(str(pattern[1]), values)
	# "★★★  영웅", "골드 300 · 보석 30"처럼 이어 붙인 글은 조각마다 찾아 본다.
	for separator in ["  ·  ", " · ", "  ", " / "]:
		if text.contains(separator):
			var parts := text.split(separator)
			var changed := false
			for i in parts.size():
				var part := _translate_line(parts[i]) if parts[i] != "" else ""
				if part != parts[i]:
					parts[i] = part
					changed = true
			if changed:
				return separator.join(parts)
	return text


## "%d", "%s", "%.1f", "%%" 같은 자리를 정규식으로 바꾼다.
static func _to_regex(shape: String) -> String:
	var out := "^"
	var i := 0
	while i < shape.length():
		var ch := shape[i]
		if ch == "%":
			var j := i + 1
			while j < shape.length() and "0123456789.+-".contains(shape[j]):
				j += 1
			if j < shape.length():
				var kind := shape[j]
				if not "sdf%".contains(kind):
					out += _escape(ch)
					i += 1
					continue
				if kind == "%":
					out += "%"
				elif kind == "d":
					out += "([-+]?[0-9][0-9,]*)"
				elif kind == "f":
					out += "([-+]?[0-9][0-9,]*(?:\\.[0-9]+)?)"
				else:
					out += "(.+?)"
				i = j + 1
				continue
		out += _escape(ch)
		i += 1
	return out + "$"


static func _escape(ch: String) -> String:
	return "\\" + ch if "\\^$.|?*+()[]{}/".contains(ch) else ch


## "%d"·"%s" 같은 끼워 넣는 자리가 있는지("25%"처럼 그냥 % 글자는 아님).
static func _has_slot(text: String) -> bool:
	return RegEx.create_from_string("%(?:[0-9]+\\$)?[0-9.+-]*[sdf]").search(text.replace("%%", "")) != null


static func _fixed_length(shape: String) -> int:
	var regex := RegEx.create_from_string("%[0-9.+-]*[a-z%]")
	return regex.sub(shape, "", true).length()


## 번역 꼴의 자리에 값을 차례로 넣는다. 번역에서 자리 순서를 바꾸려면 %1$s 꼴을 쓴다.
static func _fill(shape: String, values: Array) -> String:
	var out := ""
	var index := 0
	var i := 0
	while i < shape.length():
		var ch := shape[i]
		if ch == "%" and i + 1 < shape.length():
			var j := i + 1
			var number := ""
			while j < shape.length() and shape[j].is_valid_int():
				number += shape[j]
				j += 1
			var slot := -1
			if number != "" and j < shape.length() and shape[j] == "$":
				slot = int(number) - 1
				j += 1
			while j < shape.length() and "0123456789.+-".contains(shape[j]):
				j += 1
			if j < shape.length() and "sdf%".contains(shape[j]):
				var kind := shape[j]
				if kind == "%":
					out += "%"
				else:
					var at := slot if slot >= 0 else index
					out += str(values[at]) if at < values.size() else ""
					if slot < 0:
						index += 1
				i = j + 1
				continue
		out += ch
		i += 1
	return out

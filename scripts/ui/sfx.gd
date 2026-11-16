extends Node
## 효과음. 소리 파일 없이 코드로 짧은 소리를 합성해 둔다.
## 나중에 진짜 효과음 파일이 생기면 같은 이름으로 바꿔 끼우면 된다.
## 웹에서는 사용자가 화면을 한 번 누른 뒤부터 소리가 난다(브라우저 규칙).

const RATE := 22050
const VOLUME := 0.22
const PLAYERS := 5
const FILE_DIR := "res://assets/audio/sfx"
## 파일에서 읽은 소리는 최대 크기를 맞춰 두었으므로 이만큼(dB) 줄여서 튼다.
const FILE_VOLUME_DB := -8.0
## 자주 나는 짧은 소리는 더 작게 튼다.
const QUIET_SOUNDS := {"click": -16.0, "card": -12.0, "good": -11.0, "coin": -11.0, "whoosh": -12.0}
var _from_file: Dictionary = {}

var _sounds: Dictionary = {}
var _players: Array = []
var _next := 0
var _noise := RandomNumberGenerator.new()


func _ready() -> void:
	_noise.seed = 7
	for i in PLAYERS:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_sounds["click"] = _tone([[880.0, 0.03]], "square")
	_sounds["step"] = _tone([[620.0, 0.035]], "square")
	_sounds["dice"] = _clicks(7, 0.045)
	_sounds["hit"] = _hit()
	_sounds["win"] = _tone([[523.3, 0.09], [659.3, 0.09], [784.0, 0.09], [1046.5, 0.22]], "square")
	_sounds["lose"] = _tone([[392.0, 0.12], [329.6, 0.12], [261.6, 0.3]], "triangle")
	_sounds["good"] = _tone([[784.0, 0.06], [1046.5, 0.12]], "square")
	_sounds["bad"] = _tone([[220.0, 0.08], [164.8, 0.16]], "triangle")
	_sounds["reveal"] = _sweep(300.0, 900.0, 0.18)
	# 연출용 소리
	_sounds["whoosh"] = _noise_sweep(0.22, 0.2, 1.0)
	_sounds["impact"] = _impact()
	_sounds["sparkle"] = _tone([[1568.0, 0.04], [2093.0, 0.04], [2637.0, 0.05], [3136.0, 0.09]], "sine")
	_sounds["card"] = _noise_sweep(0.12, 1.0, 0.3)
	_sounds["skill"] = _sweep(200.0, 1400.0, 0.32)
	_sounds["fanfare"] = _tone([[523.3, 0.1], [523.3, 0.1], [523.3, 0.1], [659.3, 0.14], [784.0, 0.14], [659.3, 0.1], [784.0, 0.1], [1046.5, 0.4]], "square")
	_sounds["defeat"] = _tone([[392.0, 0.16], [370.0, 0.16], [349.2, 0.16], [261.6, 0.5]], "triangle")
	_sounds["fling"] = _sweep(900.0, 180.0, 0.4)
	_sounds["land"] = _tone([[160.0, 0.05], [110.0, 0.07]], "triangle")
	_sounds["coin"] = _tone([[1318.5, 0.05], [1760.0, 0.1]], "sine")
	# 녹음된 효과음 파일(assets/audio/sfx/이름.ogg)이 있으면 합성한 소리 대신 쓴다.
	# 파일은 tools/sfx_prompts.json 주문서로 ElevenLabs에서 만든 것이다.
	for sound_name in _sounds.keys():
		var path := "%s/%s.ogg" % [FILE_DIR, sound_name]
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream is AudioStream:
				_sounds[sound_name] = stream
				_from_file[sound_name] = true


func play(sound_name: String) -> void:
	if not _sounds.has(sound_name) or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _sounds[sound_name]
	player.volume_db = float(QUIET_SOUNDS.get(sound_name, FILE_VOLUME_DB)) if _from_file.has(sound_name) else 0.0
	player.play()


# ---------------------------------------------------------------- 소리 만들기

func _wave(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"triangle":
			return 4.0 * abs(fmod(phase, 1.0) - 0.5) - 1.0
		_:
			return sin(phase * TAU)


## notes: [[주파수, 길이(초)], ...]를 이어서 소리 낸다. 음마다 끝이 부드럽게 줄어든다.
func _tone(notes: Array, kind: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	for note in notes:
		var frequency: float = note[0]
		var length: int = int(float(note[1]) * RATE)
		for i in length:
			var envelope := 1.0 - float(i) / length
			samples.append(_wave(kind, frequency * i / RATE) * envelope * 0.8)
	return _to_stream(samples)


## 주사위가 탁자에 부딪히는 짧은 딸깍 소리 여러 번.
func _clicks(count: int, gap: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var gap_len := int(gap * RATE)
	for c in count:
		var strength := 1.0 - float(c) / (count + 1)
		for i in gap_len:
			var value := 0.0
			if i < 300:
				value = _noise.randf_range(-1.0, 1.0) * (1.0 - i / 300.0) * strength
			samples.append(value)
	return _to_stream(samples)


## 전투 시작 소리: 낮은 소리와 잡음이 섞인 쿵.
func _hit() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var length := int(0.25 * RATE)
	for i in length:
		var t := float(i) / RATE
		var envelope := pow(1.0 - float(i) / length, 2.0)
		var low := sin(TAU * (110.0 - 60.0 * t * 4.0) * t)
		var noise := _noise.randf_range(-1.0, 1.0) * 0.5
		samples.append((low + noise) * envelope)
	return _to_stream(samples)


func _sweep(from_hz: float, to_hz: float, seconds: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var length := int(seconds * RATE)
	var phase := 0.0
	for i in length:
		var ratio := float(i) / length
		phase += lerp(from_hz, to_hz, ratio) / RATE
		samples.append(_wave("square", phase) * (1.0 - ratio) * 0.6)
	return _to_stream(samples)


## 바람 소리: 잡음의 세기가 변하며 지나간다. start·end는 처음과 끝의 밝기(0 어두움 ~ 1 밝음).
func _noise_sweep(seconds: float, start: float, end: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var length := int(seconds * RATE)
	var last := 0.0
	for i in length:
		var ratio := float(i) / length
		var bright: float = lerp(start, end, ratio)
		# 간단한 저역 통과: 밝을수록 잡음이 그대로, 어두울수록 뭉개진다.
		last = lerp(last, _noise.randf_range(-1.0, 1.0), 0.08 + 0.6 * bright)
		samples.append(last * sin(ratio * PI) * 0.9)
	return _to_stream(samples)


## 충돌: 짧고 센 잡음 뒤에 낮은 울림.
func _impact() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var length := int(0.32 * RATE)
	for i in length:
		var t := float(i) / RATE
		var envelope := pow(1.0 - float(i) / length, 3.0)
		var crack := _noise.randf_range(-1.0, 1.0) * (1.0 if i < 700 else 0.25)
		var boom := sin(TAU * (90.0 - 120.0 * t) * t) * 1.2
		samples.append(clampf((crack + boom) * envelope, -1.0, 1.0))
	return _to_stream(samples)


func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var value := int(clamp(samples[i] * VOLUME, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream

extends Node
## 효과음. 소리 파일 없이 코드로 짧은 소리를 합성해 둔다.
## 나중에 진짜 효과음 파일이 생기면 같은 이름으로 바꿔 끼우면 된다.
## 웹에서는 사용자가 화면을 한 번 누른 뒤부터 소리가 난다(브라우저 규칙).

const RATE := 22050
const VOLUME := 0.22
const PLAYERS := 5

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


func play(sound_name: String) -> void:
	if not _sounds.has(sound_name) or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _sounds[sound_name]
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

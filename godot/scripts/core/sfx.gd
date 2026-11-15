class_name Sfx
extends Node

# 运行时合成音频：不依赖外部音频文件，全部用程序生成立体声波形。
# 音效走 10 个复用播放器，BGM 是一条循环的原创芯片音乐。

const RATE := 16000

var enabled := true
var _streams: Dictionary = {}
var _players: Array = []
var _next := 0
var _last_ms: Dictionary = {}
var _bgm: AudioStreamPlayer


func _ready() -> void:
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.volume_db = -9.0
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.volume_db = -19.0
	add_child(_bgm)
	_build()
	_bgm.stream = _make_bgm()
	_bgm.play()


func play(key: String, volume_db := 0.0) -> void:
	if not enabled:
		return
	var stream = _streams.get(key)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if key == "hit" and now - int(_last_ms.get(key, -999)) < 45:
		return
	_last_ms[key] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = -9.0 + volume_db
	p.play()


func set_enabled(on: bool) -> void:
	enabled = on
	_bgm.volume_db = -19.0 if on else -80.0
	if on and not _bgm.playing:
		_bgm.play()


func _build() -> void:
	_streams["hit"] = _make_hit()
	_streams["cast"] = _make_cast()
	_streams["boom"] = _make_boom()
	_streams["ult"] = _make_ult()
	_streams["win"] = _make_win()
	_streams["lose"] = _make_lose()
	_streams["click"] = _make_click()


func _wav(samples: PackedFloat32Array, loop := false, rate := RATE) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _buf(seconds: float, rate := RATE) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(maxi(1, int(seconds * float(rate))))
	return b


func _tone(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float,
		vol: float, kind := "sine", rate := RATE) -> void:
	var i0 := int(start * float(rate))
	var n := maxi(1, int(dur * float(rate)))
	var phase := 0.0
	for k in range(n):
		var i := i0 + k
		if i < 0 or i >= buf.size():
			continue
		var t := float(k) / float(n)
		var f := lerpf(f0, f1, t)
		phase += TAU * f / float(rate)
		var s := sin(phase)
		if kind == "square":
			s = signf(s) * 0.55
		elif kind == "triangle":
			s = asin(sin(phase)) * 0.64
		var env := minf(1.0, t * 40.0) * (1.0 - t)
		buf[i] += s * vol * env


func _noise(buf: PackedFloat32Array, start: float, dur: float, vol: float, decay := 2.5,
		rate := RATE) -> void:
	var i0 := int(start * float(rate))
	var n := maxi(1, int(dur * float(rate)))
	var last := 0.0
	for k in range(n):
		var i := i0 + k
		if i < 0 or i >= buf.size():
			continue
		var t := float(k) / float(n)
		last = lerpf(last, randf_range(-1.0, 1.0), 0.34)
		buf[i] += last * vol * pow(1.0 - t, decay)


func _make_hit() -> AudioStreamWAV:
	var b := _buf(0.12)
	_noise(b, 0.0, 0.09, 0.55, 3.0)
	_tone(b, 0.0, 0.10, 230.0, 90.0, 0.38, "square")
	return _wav(b)


func _make_cast() -> AudioStreamWAV:
	var b := _buf(0.24)
	_tone(b, 0.0, 0.20, 420.0, 940.0, 0.42, "triangle")
	_tone(b, 0.03, 0.18, 640.0, 1280.0, 0.16, "sine")
	return _wav(b)


func _make_boom() -> AudioStreamWAV:
	var b := _buf(0.55)
	_noise(b, 0.0, 0.40, 0.85, 2.2)
	_tone(b, 0.0, 0.42, 95.0, 42.0, 0.62, "sine")
	_tone(b, 0.0, 0.26, 150.0, 60.0, 0.22, "square")
	return _wav(b)


func _make_ult() -> AudioStreamWAV:
	var b := _buf(0.50)
	_tone(b, 0.0, 0.30, 300.0, 980.0, 0.36, "saw")
	_tone(b, 0.10, 0.36, 620.0, 1500.0, 0.22, "sine")
	_tone(b, 0.24, 0.22, 900.0, 1800.0, 0.16, "triangle")
	return _wav(b)


func _make_win() -> AudioStreamWAV:
	var b := _buf(0.95)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in range(notes.size()):
		var at := float(i) * 0.16
		_tone(b, at, 0.30, notes[i], notes[i], 0.34, "square")
		_tone(b, at, 0.28, notes[i] * 0.5, notes[i] * 0.5, 0.14, "triangle")
	_tone(b, 0.64, 0.30, 1046.5, 1046.5, 0.26, "square")
	return _wav(b)


func _make_lose() -> AudioStreamWAV:
	var b := _buf(0.85)
	var notes := [392.0, 329.63, 261.63, 196.0]
	for i in range(notes.size()):
		_tone(b, float(i) * 0.18, 0.34, notes[i], notes[i], 0.32, "triangle")
	return _wav(b)


func _make_click() -> AudioStreamWAV:
	var b := _buf(0.07)
	_tone(b, 0.0, 0.055, 900.0, 620.0, 0.30, "square")
	return _wav(b)


func _make_bgm() -> AudioStreamWAV:
	# 原创 4 小节循环：C - G - Am - F，芯片音色 + 轻量鼓点。
	# BGM 用 11kHz 合成，缩短启动耗时，芯片音色听感几乎无差别。
	var br := 11025
	var bpm := 112.0
	var beat := 60.0 / bpm
	var bars := 4
	var total := beat * 4.0 * float(bars)
	var buf := _buf(total, br)
	var chords := [
		[261.63, 329.63, 392.0],
		[196.0, 246.94, 293.66],
		[220.0, 261.63, 329.63],
		[174.61, 220.0, 261.63],
	]
	var melody := [
		523.25, 659.25, 783.99, 659.25, 587.33, 659.25, 523.25, 440.0,
		523.25, 587.33, 659.25, 783.99, 880.0, 783.99, 659.25, 587.33,
		659.25, 587.33, 523.25, 440.0, 392.0, 440.0, 523.25, 587.33,
		659.25, 783.99, 880.0, 1046.5, 880.0, 783.99, 659.25, 523.25,
	]
	for bar in range(bars):
		var ch: Array = chords[bar]
		for b in range(4):
			var at := (float(bar) * 4.0 + float(b)) * beat
			_tone(buf, at, beat * 0.88, ch[0] * 0.5, ch[0] * 0.5, 0.15, "square", br)
			if b % 2 == 0:
				for tone in ch:
					_tone(buf, at, beat * 1.85, tone, tone, 0.042, "triangle", br)
				_noise(buf, at, 0.05, 0.05, 3.0, br)
			_noise(buf, at + beat * 0.5, 0.03, 0.035, 4.0, br)
			for e in range(2):
				var idx := bar * 8 + b * 2 + e
				if idx < melody.size():
					var f: float = melody[idx]
					_tone(buf, at + float(e) * beat * 0.5, beat * 0.44, f, f, 0.075, "square", br)
	return _wav(buf, true, br)

class_name Sfx
extends Node

# 运行时合成音频：不依赖外部音频文件，全部用程序生成立体声波形。
# 音效走 10 个复用播放器，BGM 是一条循环的原创芯片音乐。

const RATE := 16000

# 8 位英雄的施法/命中/大招音色参数：波形、起止频率、噪声量、普攻音高。
const HERO_AUDIO := {
	"tiger": {"cast0": 320.0, "cast1": 820.0, "wave": "square", "hit0": 240.0, "hit1": 90.0, "noise": 0.55, "shoot": 0.0},
	"fox": {"cast0": 520.0, "cast1": 1280.0, "wave": "triangle", "hit0": 460.0, "hit1": 300.0, "noise": 0.18, "shoot": 920.0},
	"rabbit": {"cast0": 680.0, "cast1": 1180.0, "wave": "sine", "hit0": 620.0, "hit1": 880.0, "noise": 0.10, "shoot": 720.0},
	"bear": {"cast0": 180.0, "cast1": 420.0, "wave": "square", "hit0": 150.0, "hit1": 55.0, "noise": 0.75, "shoot": 0.0},
	"frog": {"cast0": 380.0, "cast1": 620.0, "wave": "triangle", "hit0": 340.0, "hit1": 180.0, "noise": 0.30, "shoot": 480.0},
	"cat": {"cast0": 760.0, "cast1": 1500.0, "wave": "triangle", "hit0": 720.0, "hit1": 420.0, "noise": 0.16, "shoot": 1200.0},
	"panda": {"cast0": 260.0, "cast1": 560.0, "wave": "triangle", "hit0": 210.0, "hit1": 95.0, "noise": 0.45, "shoot": 0.0},
	"owl": {"cast0": 620.0, "cast1": 1600.0, "wave": "sine", "hit0": 700.0, "hit1": 1100.0, "noise": 0.08, "shoot": 1050.0},
	"turtle": {"cast0": 220.0, "cast1": 480.0, "wave": "triangle", "hit0": 180.0, "hit1": 90.0, "noise": 0.55, "shoot": 0.0},
	"hedgehog": {"cast0": 780.0, "cast1": 1550.0, "wave": "triangle", "hit0": 520.0, "hit1": 340.0, "noise": 0.25, "shoot": 980.0},
	"redpanda": {"cast0": 300.0, "cast1": 720.0, "wave": "square", "hit0": 280.0, "hit1": 140.0, "noise": 0.42, "shoot": 0.0},
	"wolf": {"cast0": 420.0, "cast1": 960.0, "wave": "triangle", "hit0": 300.0, "hit1": 120.0, "noise": 0.38, "shoot": 0.0},
	"crane": {"cast0": 700.0, "cast1": 1700.0, "wave": "sine", "hit0": 660.0, "hit1": 990.0, "noise": 0.10, "shoot": 1120.0},
}

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
	_bgm.volume_db = -8.0
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
	if key.begins_with("hit") and now - int(_last_ms.get(key, -999)) < 45:
		return
	_last_ms[key] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = -9.0 + volume_db
	p.play()


func set_enabled(on: bool) -> void:
	enabled = on
	_bgm.volume_db = -8.0 if on else -80.0
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
	_streams["pickup"] = _make_pickup()
	# 每个英雄的施法 / 命中 / 大招 / 普攻音色都不同。
	for id in HERO_AUDIO:
		_streams["cast_" + id] = _make_cast_variant(id)
		_streams["hit_" + id] = _make_hit_variant(id)
		_streams["ult_" + id] = _make_ult_variant(id)
		if float(HERO_AUDIO[id]["shoot"]) > 0.0:
			_streams["shoot_" + id] = _make_shoot_variant(id)


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


func _make_pickup() -> AudioStreamWAV:
	var b := _buf(0.20)
	_tone(b, 0.0, 0.08, 660.0, 880.0, 0.26, "sine")
	_tone(b, 0.07, 0.11, 880.0, 1320.0, 0.22, "sine")
	return _wav(b)


func _make_cast_variant(id: String) -> AudioStreamWAV:
	var p: Dictionary = HERO_AUDIO[id]
	var b := _buf(0.24)
	_tone(b, 0.0, 0.20, float(p["cast0"]), float(p["cast1"]), 0.40, str(p["wave"]))
	_tone(b, 0.03, 0.16, float(p["cast1"]) * 0.75, float(p["cast1"]) * 1.2, 0.12, "sine")
	return _wav(b)


func _make_hit_variant(id: String) -> AudioStreamWAV:
	var p: Dictionary = HERO_AUDIO[id]
	var b := _buf(0.13)
	_noise(b, 0.0, 0.09, float(p["noise"]), 3.0)
	_tone(b, 0.0, 0.10, float(p["hit0"]), float(p["hit1"]), 0.32, str(p["wave"]))
	return _wav(b)


func _make_ult_variant(id: String) -> AudioStreamWAV:
	var p: Dictionary = HERO_AUDIO[id]
	var b := _buf(0.55)
	var f := float(p["cast1"])
	_tone(b, 0.0, 0.28, f * 0.5, f, 0.34, str(p["wave"]))
	_tone(b, 0.12, 0.34, f * 0.8, f * 1.5, 0.18, "sine")
	_tone(b, 0.28, 0.22, f, f * 1.8, 0.12, "triangle")
	return _wav(b)


func _make_shoot_variant(id: String) -> AudioStreamWAV:
	var p: Dictionary = HERO_AUDIO[id]
	var f := float(p["shoot"])
	var b := _buf(0.09)
	_tone(b, 0.0, 0.07, f, f * 1.4, 0.16, str(p["wave"]))
	_tone(b, 0.0, 0.05, f * 0.5, f * 0.5, 0.06, "sine")
	return _wav(b)


func _bell(buf: PackedFloat32Array, start: float, dur: float, freq: float,
		vol: float, rate := RATE) -> void:
	# 柔和钟琴/木琴音色：基音 + 少量二三次谐波，快速起音、自然衰减。
	var i0 := int(start * float(rate))
	var n := maxi(1, int(dur * float(rate)))
	var phase := 0.0
	for k in range(n):
		var i := i0 + k
		if i < 0 or i >= buf.size():
			continue
		var t := float(k) / float(n)
		phase += TAU * freq / float(rate)
		var s := sin(phase) + 0.24 * sin(phase * 2.0) + 0.10 * sin(phase * 3.0)
		var env := minf(1.0, t * 24.0) * exp(-4.6 * t)
		buf[i] += s * vol * env


func _make_bgm() -> AudioStreamWAV:
	# 儿童向的明亮 8 小节循环：C - F - G - C，钟琴主旋律 + 温柔低音和轻拍手。
	# 100 BPM、C 大调、无小调；音量留出余量，避免连续播放刺耳。
	var br := 16000
	var bpm := 100.0
	var beat := 60.0 / bpm
	var bars := 8
	var total := beat * 4.0 * float(bars)
	var buf := _buf(total, br)

	var chords := [
		[261.63, 329.63, 392.0], [349.23, 440.0, 523.25],
		[392.0, 493.88, 587.33], [261.63, 329.63, 392.0],
		[261.63, 329.63, 392.0], [349.23, 440.0, 523.25],
		[392.0, 493.88, 587.33], [261.63, 329.63, 392.0],
	]
	var roots := [261.63, 349.23, 392.0, 261.63, 261.63, 349.23, 392.0, 261.63]
	# 八个八分音符一栏；0 表示休止，旋律尽量级进、可跟唱。
	var melody := [
		[659.25, 783.99, 880.0, 783.99, 659.25, 587.33, 523.25, 0.0],
		[698.46, 880.0, 1046.5, 880.0, 783.99, 698.46, 659.25, 0.0],
		[587.33, 783.99, 987.77, 783.99, 880.0, 783.99, 698.46, 587.33],
		[523.25, 659.25, 783.99, 1046.5, 987.77, 783.99, 659.25, 0.0],
		[783.99, 659.25, 783.99, 880.0, 783.99, 659.25, 587.33, 523.25],
		[880.0, 1046.5, 880.0, 783.99, 698.46, 783.99, 880.0, 0.0],
		[987.77, 1174.66, 987.77, 783.99, 880.0, 987.77, 783.99, 587.33],
		[1046.5, 783.99, 659.25, 783.99, 659.25, 587.33, 523.25, 0.0],
	]

	for bar in range(bars):
		var at := float(bar) * 4.0 * beat
		var ch: Array = chords[bar]
		for b in range(4):
			var bt := at + float(b) * beat
			# 低音：每小节第 1、3 拍，三角波，温暖不轰头。
			if b % 2 == 0:
				_tone(buf, bt, beat * 0.86, roots[bar] * 0.5, roots[bar] * 0.5, 0.168, "triangle", br)
			# 和弦垫：轻三角波，长音铺底。
			if b == 0:
				for tone in ch:
					_tone(buf, bt, beat * 3.6, tone, tone, 0.029, "sine", br)
			# 轻拍手：2、4 拍，很轻的噪声短点。
			if b == 1 or b == 3:
				_noise(buf, bt, 0.028, 0.042, 4.5, br)
			# 木鱼/木块：给小朋友一个清楚的拍点。
			_tone(buf, bt, 0.035, 920.0, 660.0, 0.035, "sine", br)

		for step in range(8):
			var f: float = melody[bar][step]
			if f <= 0.0:
				continue
			_bell(buf, at + float(step) * beat * 0.5, beat * 0.58, f, 0.125, br)

		# 每小节开头轻轻起一下，循环衔接更自然。
		_tone(buf, at, 0.07, 120.0, 72.0, 0.048, "sine", br)

	return _wav(buf, true, br)

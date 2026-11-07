extends Node3D

# 垂直切片入口：直接进入战斗；首页/选人在 P4 接回。
const BattleSimScript = preload("res://scripts/core/battle_sim.gd")
const BattleViewScript = preload("res://scripts/view/battle_view.gd")
const CameraRigScript = preload("res://scripts/view/camera_rig.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const InputHubScript = preload("res://scripts/ui/input_hub.gd")

const SIM_DT := 1.0 / 30.0

var sim = null
var view = null
var cam = null
var hud = null
var input_hub = null

var paused := false
var hitstop_until_ms := 0
var current_hero := "tiger"
var current_difficulty := 0
var current_seed := 20261107
var fps_start_ms := 0
var fps_frames := 0
var last_back_ms := 0
var sim_us_total := 0
var sim_frames := 0
var sim_acc := 0.0


func _ready() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_title("萌兽峡谷 TapArena · Godot 垂直切片")
	if OS.get_name() == "Android":
		# 3D 用 65% 分辨率渲染，HUD 仍按原生分辨率绘制；低端机优先保帧率。
		get_viewport().scaling_3d_scale = 0.65
	var win := get_window()
	if win.has_signal("go_back_requested"):
		win.go_back_requested.connect(_on_go_back_requested)
	fps_start_ms = Time.get_ticks_msec()
	_start_match(current_hero, current_difficulty, current_seed)


func _start_match(hero_id: String, difficulty: int, seed_value: int) -> void:
	current_hero = hero_id
	current_difficulty = difficulty
	current_seed = seed_value

	for child in get_children():
		if child is Control:
			child.visible = false
		if child is Camera3D:
			child.current = false
		child.queue_free()

	Engine.time_scale = 1.0
	paused = false
	hitstop_until_ms = 0
	sim_acc = 0.0

	sim = BattleSimScript.new()
	sim.setup(hero_id, difficulty, seed_value)

	view = BattleViewScript.new()
	view.process_priority = 0
	add_child(view)
	view.attach(sim)

	cam = CameraRigScript.new()
	add_child(cam)
	cam.set_target(Vector3(sim.player.pos.x, 0, sim.player.pos.y))
	cam.snap()

	hud = HudScript.new()
	hud.process_priority = 10
	add_child(hud)
	hud.attach(sim, cam)
	hud.paused = false

	input_hub = InputHubScript.new()
	input_hub.process_priority = -10
	add_child(input_hub)
	input_hub.attach(sim, hud)
	input_hub.pause_toggle.connect(_toggle_pause)
	input_hub.restart_requested.connect(_restart)

	sim.fx.connect(_on_fx)
	sim.hitstop.connect(_on_hitstop)
	sim.match_ended.connect(_on_match_ended)

	print("[MATCH] hero=%s difficulty=%d seed=%d" % [hero_id, difficulty, seed_value])


func _process(delta: float) -> void:
	if sim == null:
		return

	fps_frames += 1
	var now_ms := Time.get_ticks_msec()
	if now_ms - fps_start_ms >= 5000:
		var sim_ms := sim_us_total / 1000.0 / maxf(1.0, float(sim_frames))
		print("[FPS] %.1f sim_ms=%.2f" % [float(fps_frames) * 1000.0 / float(now_ms - fps_start_ms), sim_ms])
		fps_start_ms = now_ms
		fps_frames = 0
		sim_us_total = 0
		sim_frames = 0

	if not paused:
		var t0 := Time.get_ticks_usec()
		sim_acc += delta
		var steps := 0
		while sim_acc >= SIM_DT and steps < 3:
			sim.step(SIM_DT)
			sim_acc -= SIM_DT
			steps += 1
		sim_us_total += Time.get_ticks_usec() - t0
		sim_frames += steps
		if sim.player != null:
			cam.set_target(Vector3(sim.player.pos.x, 0, sim.player.pos.y))

	if hitstop_until_ms > 0 and Time.get_ticks_msec() >= hitstop_until_ms:
		hitstop_until_ms = 0
		if not paused:
			Engine.time_scale = 1.0


func _on_hitstop(seconds: float) -> void:
	# 重入保护：Unity 版就是因为两段顿帧重叠把 timeScale 卡在 0.18。
	if hitstop_until_ms > Time.get_ticks_msec():
		return
	Engine.time_scale = 0.18
	hitstop_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)


func _toggle_pause() -> void:
	if sim == null or sim.over:
		return
	paused = not paused
	hud.paused = paused
	Engine.time_scale = 0.0 if paused else 1.0
	if paused:
		input_hub._zero_move()
	hud.queue_redraw()


func _restart() -> void:
	_start_match(current_hero, current_difficulty, current_seed + 1)


func _on_match_ended(_winner: int) -> void:
	if hud != null:
		hud.queue_redraw()


func _on_fx(kind: String, _pos: Vector3, _color: Color, radius: float) -> void:
	if cam == null:
		return
	if kind == "punch":
		cam.add_punch(0.9)
		cam.add_shake(4.0)
	elif kind == "ring" and radius >= 170.0:
		cam.add_shake(3.0)


func _on_go_back_requested() -> void:
	# 通知和 Window 信号可能同时到达，250ms 内只处理一次。
	var now := Time.get_ticks_msec()
	if now - last_back_ms < 250:
		return
	last_back_ms = now
	_toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_go_back_requested()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if sim != null and not sim.over and not paused:
			_toggle_pause()


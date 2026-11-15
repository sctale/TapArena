extends Node3D

# 入口状态机：首页选人 → 战斗 → 暂停/结算 → 回首页。
const BattleSimScript = preload("res://scripts/core/battle_sim.gd")
const BattleViewScript = preload("res://scripts/view/battle_view.gd")
const CameraRigScript = preload("res://scripts/view/camera_rig.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const InputHubScript = preload("res://scripts/ui/input_hub.gd")
const HomeScript = preload("res://scripts/ui/home.gd")
const SfxScript = preload("res://scripts/core/sfx.gd")

const SIM_DT := 1.0 / 60.0

var sim = null
var view = null
var cam = null
var hud = null
var input_hub = null
var home = null
var sfx = null
var match_active := false

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
var camera_follow := true
var auto_run := false
var cinematic := false
var cinematic_until_ms := 0
var cinematic_flash_until_ms := 0


func _ready() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_title("萌兽峡谷 TapArena · Godot")
	if OS.get_name() == "Android":
		# 像素风要看清方块边缘：3D 按原生分辨率渲染，不用低分辨率放大。
		get_viewport().scaling_3d_scale = 1.0
	var win := get_window()
	if win.has_signal("go_back_requested"):
		win.go_back_requested.connect(_on_go_back_requested)
	fps_start_ms = Time.get_ticks_msec()

	sfx = SfxScript.new()
	sfx.name = "Sfx"
	add_child(sfx)

	var args := OS.get_cmdline_user_args()
	# 调试：--hero=frog 指定英雄，便于逐个检查技能特效。
	for a in args:
		if str(a).begins_with("--hero="):
			current_hero = str(a).substr(7)
			break
	if "--skip-home" in args or "--top" in args or "--no-hud" in args:
		_start_match(current_hero, current_difficulty, current_seed)
	else:
		_show_home()


func _clear_scene() -> void:
	for child in get_children():
		if child == sfx:
			continue
		remove_child(child)
		child.queue_free()
	sim = null
	view = null
	cam = null
	hud = null
	input_hub = null
	home = null


func _show_home() -> void:
	_clear_scene()
	match_active = false
	cinematic = false
	paused = false
	Engine.time_scale = 1.0
	hitstop_until_ms = 0
	sim_acc = 0.0
	home = HomeScript.new()
	add_child(home)
	home.start_requested.connect(_on_home_start)
	home.ui_click.connect(_on_ui_click)


func _on_home_start(hero_id: String, difficulty: int) -> void:
	_start_match(hero_id, difficulty, int(Time.get_ticks_msec() % 1000000))


func _on_ui_click() -> void:
	if sfx != null:
		sfx.play("click")


func _start_match(hero_id: String, difficulty: int, seed_value: int) -> void:
	current_hero = hero_id
	current_difficulty = difficulty
	current_seed = seed_value

	_clear_scene()

	Engine.time_scale = 1.0
	paused = false
	cinematic = false
	hitstop_until_ms = 0
	sim_acc = 0.0
	match_active = true

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

	# 调试：`-- --look-base` 把镜头固定在蓝方基地，用于核对素材颜色。
	camera_follow = true
	auto_run = "--auto-run" in OS.get_cmdline_user_args()
	if "--look-base" in OS.get_cmdline_user_args():
		camera_follow = false
		cam.set_target(Vector3(230, 0, 800))
		cam.snap()
	if "--look-red" in OS.get_cmdline_user_args():
		camera_follow = false
		cam.set_target(Vector3(2770, 0, 800))
		cam.snap()
	if "--look-lane" in OS.get_cmdline_user_args():
		camera_follow = false
		cam.set_target(Vector3(700, 0, 800))
		cam.snap()
	if "--look-tower" in OS.get_cmdline_user_args():
		camera_follow = false
		cam.set_target(Vector3(1900, 0, 800))
		cam.snap()
	# 调试：把玩家放到蓝方内塔后方，检查建筑半透明。
	if "--behind" in OS.get_cmdline_user_args():
		sim.player.pos = Vector2(700, 650)
		sim.player.prev_pos = sim.player.pos
		camera_follow = false
		cam.set_target(Vector3(730, 0, 720))
		cam.snap()
	# 调试：直接升到 2 级并释放大招，检查冷却显示。
	if "--ult" in OS.get_cmdline_user_args():
		sim.player.level = 2
		sim.player.xp = sim.xp_to_level2
		sim.try_cast(sim.player, 2)
	if "--top" in OS.get_cmdline_user_args():
		camera_follow = false
		cam.frozen = true
		cam.fov = 58.0
		cam.position = Vector3(1500, 1450, 2500)
		cam.look_at(Vector3(1500, 0, 820), Vector3.UP)
	# 调试：拆掉双方外塔，检查废墟模型。
	if "--ruins" in OS.get_cmdline_user_args():
		sim.deal_damage(sim.towers_blue[0], 99999.0, sim.player)
		sim.deal_damage(sim.towers_red[0], 99999.0, sim.player)
		if "--top" not in OS.get_cmdline_user_args():
			camera_follow = false
			cam.set_target(Vector3(1180, 0, 800))
			cam.snap()

	hud = HudScript.new()
	hud.process_priority = 10
	add_child(hud)
	hud.attach(sim, cam)
	hud.paused = false
	if "--no-hud" in OS.get_cmdline_user_args():
		hud.visible = false

	input_hub = InputHubScript.new()
	input_hub.process_priority = -10
	add_child(input_hub)
	input_hub.attach(sim, hud)
	input_hub.pause_toggle.connect(_toggle_pause)
	input_hub.restart_requested.connect(_restart)
	input_hub.home_requested.connect(_show_home)
	input_hub.sound_toggle.connect(_toggle_sound)
	hud.sound_on = sfx.enabled if sfx != null else true

	sim.fx.connect(_on_fx)
	sim.sfx.connect(_on_sfx)
	sim.hitstop.connect(_on_hitstop)
	sim.match_ended.connect(_on_match_ended)
	sim.banner.connect(_on_banner)

	# 开发用：直接查看暂停/结算界面。
	if "--pause" in OS.get_cmdline_user_args():
		_toggle_pause()
	if "--result" in OS.get_cmdline_user_args():
		sim.end_match(sim.BLUE, "调试结算")
	# 开发用：直接摧毁红方水晶，检查结束动画与结算页。
	var vargs := OS.get_cmdline_user_args()
	if "--victory" in vargs or "--victory-minion" in vargs:
		sim.towers_red[0].hp = 0.0
		sim.towers_red[1].hp = 0.0
		var killer = sim.player
		if "--victory-minion" in vargs:
			sim.spawn_wave(sim.BLUE)
			if not sim.minions.is_empty():
				killer = sim.minions[0]
		sim.deal_damage(sim.base_red, 99999.0, killer)
		sim.step(0.016)
		hud.queue_redraw()

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
		if auto_run and sim.player != null:
			sim.player_move = Vector2(1, 0)
		var t0 := Time.get_ticks_usec()
		sim_acc += delta
		var steps := 0
		while sim_acc >= SIM_DT and steps < 6:
			sim.step(SIM_DT)
			sim_acc -= SIM_DT
			steps += 1
		sim.interp_alpha = clampf(sim_acc / SIM_DT, 0.0, 1.0)
		sim_us_total += Time.get_ticks_usec() - t0
		sim_frames += steps
		if sim.player != null and camera_follow:
			var rp: Vector2 = sim.render_pos(sim.player)
			cam.set_target(Vector3(rp.x, 0, rp.y))

	if hitstop_until_ms > 0 and Time.get_ticks_msec() >= hitstop_until_ms:
		hitstop_until_ms = 0
		if not paused:
			Engine.time_scale = 1.0

	if cinematic:
		var now := Time.get_ticks_msec()
		if now >= cinematic_flash_until_ms and Engine.time_scale < 1.0:
			Engine.time_scale = 1.0
		if now >= cinematic_until_ms:
			cinematic = false
			if hud != null:
				hud.finish_cinematic()


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
	# 不用 time_scale=0，否则 HUD 的 delta 变 0，暂停面板文字不会刷新。
	Engine.time_scale = 1.0
	if paused:
		input_hub._zero_move()
	hud.queue_redraw()


func _restart() -> void:
	_start_match(current_hero, current_difficulty, current_seed + 1)


func _on_match_ended(winner: int) -> void:
	if hud == null or sim == null:
		return
	var loser_base = sim.base_red if winner == sim.BLUE else sim.base_blue
	# 不论最后一击来自玩家、AI 英雄还是小兵，只要水晶被摧毁就播结束动画。
	if loser_base != null and sim.end_reason == "水晶被摧毁":
		var now := Time.get_ticks_msec()
		cinematic = true
		cinematic_until_ms = now + 2600
		cinematic_flash_until_ms = now + 900
		hud.start_cinematic()
		camera_follow = false
		if cam != null:
			cam.set_target(Vector3(loser_base.pos.x, 0, loser_base.pos.y))
			cam.set_zoom(0.72)
			cam.add_shake(10.0)
			cam.add_punch(1.4)
		if view != null:
			var col := Color(0.42, 0.72, 0.95) if winner == sim.BLUE else Color(0.92, 0.44, 0.38)
			view.play_victory(loser_base, col)
		Engine.time_scale = 0.35
	else:
		hud.finish_cinematic()


func _on_banner(text: String, _duration: float) -> void:
	if cam != null and text.begins_with("终极对决"):
		cam.set_zoom(0.82)


func _on_fx(kind: String, _pos: Vector3, _color: Color, radius: float) -> void:
	if cam == null:
		return
	if kind == "punch":
		cam.add_punch(0.9)
		cam.add_shake(4.0)
	elif kind == "ring" and radius >= 170.0:
		cam.add_shake(3.0)


func _on_sfx(key: String) -> void:
	if sfx != null:
		sfx.play(key)
	if key == "boom" and cam != null:
		cam.add_shake(9.0)


func _toggle_sound() -> void:
	if sfx == null:
		return
	sfx.set_enabled(not sfx.enabled)
	if hud != null:
		hud.sound_on = sfx.enabled
		hud.queue_redraw()
	sfx.play("click")


func _on_go_back_requested() -> void:
	# 通知和 Window 信号可能同时到达，250ms 内只处理一次。
	var now := Time.get_ticks_msec()
	if now - last_back_ms < 250:
		return
	last_back_ms = now
	if not match_active or sim == null:
		get_tree().quit()
		return
	if sim.over:
		_show_home()
		return
	_toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_go_back_requested()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if match_active and sim != null and not sim.over and not paused:
			_toggle_pause()


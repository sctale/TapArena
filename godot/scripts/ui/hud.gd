class_name Hud
extends Control

# 最小战斗 HUD：纯 _draw 绘制，坐标全部走安全区，和 Unity 版的信息层级保持一致。
# 垂直切片只保留战斗必需元素：头像/血条、比分/计时、塔位、小地图、技能、摇杆、播报、结算/暂停。

var sim = null
var cam: Camera3D = null
var input_hub = null
var paused := false
var font: Font = null

var banners: Array = []
var floats: Array = []
var redraw_acc := 0.0
var draw_us_total := 0
var draw_count := 0
var prof: Dictionary = {}
var lbl_skill_icon: Array = []
var lbl_skill_name: Array = []
var lbl_skill_state: Array = []
var lbl_skill_ult: Label
var lbl_avatar: Label
var lbl_level: Label
var lbl_plate_name: Label
var lbl_plate_hp: Label
var lbl_plate_ult: Label
var lbl_score: Label
var lbl_clock: Label
var lbl_sudden: Label
var rect_mm: MultiMesh
var disc_mm: MultiMesh
var white_tex: Texture2D
var disc_tex: Texture2D
var rect_i := 0
var disc_i := 0

const C_PANEL := Color(0.07, 0.17, 0.15, 0.90)
const C_PANEL_DEEP := Color(0.05, 0.13, 0.11, 0.95)
const C_CREAM := Color(1.0, 0.96, 0.87)
const C_GOLD := Color(1.0, 0.78, 0.34)
const C_GOLD_SOFT := Color(1.0, 0.88, 0.58)
const C_BLUE := Color(0.55, 0.90, 1.0)
const C_RED := Color(1.0, 0.62, 0.55)
const C_INK := Color(0.09, 0.07, 0.04)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	font = load("res://assets/fonts/TapArenaCJK.ttf")
	if font == null:
		font = ThemeDB.fallback_font
	_make_skill_labels()
	_make_shape_batches()
	set_process(true)


func attach(s, c: Camera3D) -> void:
	sim = s
	cam = c
	sim.banner.connect(_on_banner)
	sim.float_text.connect(_on_float_text)
	queue_redraw()


func viewport_size() -> Vector2:
	return get_viewport_rect().size


func _safe() -> Rect2:
	var vp := viewport_size()
	if OS.get_name() != "Android":
		return Rect2(Vector2.ZERO, vp)
	var win := Vector2(get_window().size)
	var sr := DisplayServer.get_display_safe_area()
	if sr.size.x <= 0 or sr.size.y <= 0 or win.x <= 0.0 or win.y <= 0.0:
		return Rect2(Vector2.ZERO, vp)
	var k := vp / win
	return Rect2(Vector2(sr.position) * k, Vector2(sr.size) * k)


func pause_rect() -> Rect2:
	var safe := _safe()
	var s := maxf(48.0, safe.size.y * 0.075)
	return Rect2(safe.end.x - s - 14.0, safe.position.y + safe.size.y * 0.195, s, s)


func skill_rect(i: int) -> Rect2:
	var safe := _safe()
	var h := safe.size.y
	var bs: Array = [h * 0.150, h * 0.140, h * 0.160]
	var cx: Array = [safe.end.x - h * 0.270, safe.end.x - h * 0.160, safe.end.x - h * 0.180]
	var cy: Array = [safe.end.y - h * 0.215, safe.end.y - h * 0.395, safe.end.y - h * 0.580]
	return Rect2(cx[i] - bs[i] * 0.5, cy[i] - bs[i] * 0.5, bs[i], bs[i])


func resume_rect() -> Rect2:
	var safe := _safe()
	var p := _pause_panel()
	return Rect2(p.position.x + p.size.x * 0.20, p.position.y + p.size.y * 0.18, p.size.x * 0.60, safe.size.y * 0.09)


func restart_rect() -> Rect2:
	var safe := _safe()
	var p := _pause_panel()
	return Rect2(p.position.x + p.size.x * 0.20, p.position.y + p.size.y * 0.32, p.size.x * 0.60, safe.size.y * 0.08)


func result_restart_rect() -> Rect2:
	var safe := _safe()
	var p := _result_panel()
	return Rect2(p.position.x + p.size.x * 0.20, p.position.y + p.size.y * 0.66, p.size.x * 0.60, safe.size.y * 0.10)


func _pause_panel() -> Rect2:
	var safe := _safe()
	return Rect2(safe.position.x + safe.size.x * 0.31, safe.position.y + safe.size.y * 0.14, safe.size.x * 0.38, safe.size.y * 0.72)


func _result_panel() -> Rect2:
	var safe := _safe()
	return Rect2(safe.position.x + safe.size.x * 0.24, safe.position.y + safe.size.y * 0.11, safe.size.x * 0.52, safe.size.y * 0.78)


func _on_banner(text: String, duration: float) -> void:
	banners.append({"text": text, "t": 0.0, "life": duration})
	if banners.size() > 4:
		banners.pop_front()
	queue_redraw()


func _on_float_text(pos: Vector3, text: String, color: Color) -> void:
	floats.append({"pos": pos, "text": text, "color": color, "t": 0.0, "life": 0.9})
	queue_redraw()


func _process(delta: float) -> void:
	for i in range(banners.size() - 1, -1, -1):
		banners[i]["t"] += delta
		if banners[i]["t"] >= banners[i]["life"]:
			banners.remove_at(i)
	for i in range(floats.size() - 1, -1, -1):
		floats[i]["t"] += delta
		if floats[i]["t"] >= floats[i]["life"]:
			floats.remove_at(i)
	# HUD 30fps 重绘即可；中文字符串绘制是 Android 上的主要 CPU 开销之一。
	redraw_acc += delta
	if redraw_acc >= 1.0 / 30.0:
		redraw_acc = 0.0
		_update_skill_labels()
		_update_plate_labels()
		_update_score_labels()
		queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var t0 := Time.get_ticks_usec()
	var safe := _safe()
	if sim.over:
		_draw_result(safe)
	elif paused:
		_draw_pause(safe)
	else:
		_draw_battle(safe)
	draw_us_total += Time.get_ticks_usec() - t0
	draw_count += 1
	if draw_count >= 60:
		var parts: Array = []
		for k in prof:
			parts.append("%s=%.2f" % [k, float(prof[k]) / 1000.0 / float(draw_count)])
		print("[HUD] draw_ms=%.2f %s" % [draw_us_total / 1000.0 / float(draw_count), " ".join(parts)])
		draw_us_total = 0
		draw_count = 0
		prof.clear()


func _prof_add(key: String, us: int) -> void:
	prof[key] = int(prof.get(key, 0)) + us


func _mk_label(size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.visible = false
	add_child(l)
	return l


func _make_skill_labels() -> void:
	var h := _safe().size.y
	var fs := int(h * 0.026)
	var fs_small := int(h * 0.019)
	for i in range(3):
		lbl_skill_icon.append(_mk_label(int(fs * 1.3), Color(0.16, 0.12, 0.07)))
		lbl_skill_name.append(_mk_label(fs_small, Color(1, 0.97, 0.88)))
		lbl_skill_state.append(_mk_label(fs_small, Color(1, 1, 1, 0.95)))
	lbl_skill_ult = _mk_label(fs_small, C_GOLD_SOFT)
	lbl_avatar = _mk_label(int(fs * 1.2), C_CREAM)
	lbl_level = _mk_label(int(fs * 0.8), C_INK)
	lbl_plate_name = _mk_label(fs, C_CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_plate_hp = _mk_label(fs_small, C_CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_plate_ult = _mk_label(fs_small, Color(0.95, 0.92, 0.8, 0.7))
	lbl_score = _mk_label(fs, C_CREAM)
	lbl_clock = _mk_label(int(fs * 1.15), C_GOLD_SOFT)
	lbl_sudden = _mk_label(fs_small, Color(1.0, 0.84, 0.44))


func _make_shape_batches() -> void:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	white_tex = ImageTexture.create_from_image(img)
	disc_tex = _make_disc_texture(64)

	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	rect_mm = MultiMesh.new()
	rect_mm.transform_format = MultiMesh.TRANSFORM_2D
	rect_mm.use_colors = true
	rect_mm.mesh = quad
	rect_mm.instance_count = 512

	disc_mm = MultiMesh.new()
	disc_mm.transform_format = MultiMesh.TRANSFORM_2D
	disc_mm.use_colors = true
	disc_mm.mesh = quad
	disc_mm.instance_count = 256


func _make_disc_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var c := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var dx := float(x) + 0.5 - c
			var dy := float(y) + 0.5 - c
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf((c - 1.0 - d) * 2.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _begin_batch() -> void:
	rect_i = 0
	disc_i = 0


func _add_rect(r: Rect2, c: Color) -> void:
	if rect_i >= rect_mm.instance_count:
		return
	rect_mm.set_instance_transform_2d(rect_i, Transform2D(0.0, r.size, 0.0, r.get_center()))
	rect_mm.set_instance_color(rect_i, c)
	rect_i += 1


func _add_disc(center: Vector2, radius: float, c: Color) -> void:
	if disc_i >= disc_mm.instance_count:
		return
	disc_mm.set_instance_transform_2d(disc_i, Transform2D(0.0, Vector2(radius * 2.0, radius * 2.0), 0.0, center))
	disc_mm.set_instance_color(disc_i, c)
	disc_i += 1


func _flush_batches() -> void:
	rect_mm.visible_instance_count = rect_i
	disc_mm.visible_instance_count = disc_i
	draw_multimesh(disc_mm, disc_tex)
	draw_multimesh(rect_mm, white_tex)


func _set_label(l: Label, text: String, color: Color) -> void:
	if l.text != text:
		l.text = text
	if l.get_theme_color("font_color") != color:
		l.add_theme_color_override("font_color", color)


func _update_skill_labels() -> void:
	if sim == null:
		return
	var show: bool = not paused and not sim.over
	if not show:
		for i in range(3):
			lbl_skill_icon[i].visible = false
			lbl_skill_name[i].visible = false
			lbl_skill_state[i].visible = false
		lbl_skill_ult.visible = false
		return
	var p = sim.player
	if p == null:
		return
	var fs_small := int(_safe().size.y * 0.019)
	# 只更新文本，位置/尺寸每帧同步；Label 内部缓存字形，避免每帧 draw_string。
	for i in range(3):
		var r := skill_rect(i)
		var s: Dictionary = p.skills[i]
		var locked: bool = s.get("unlock_at_2", false) and p.level < 2
		var cooling: bool = p.cds[i] > 0.0
		var icon: Label = lbl_skill_icon[i]
		icon.visible = not locked and not cooling
		icon.position = Vector2(r.position.x, r.position.y + r.size.y * 0.12)
		icon.size = Vector2(r.size.x, r.size.y * 0.38)
		_set_label(icon, str(s.get("name", "技能")).substr(0, 1), Color(0.16, 0.12, 0.07))

		var nr := Rect2(r.position.x + r.size.x * 0.06, r.end.y - r.size.y * 0.30, r.size.x * 0.88, r.size.y * 0.24)
		var name_l: Label = lbl_skill_name[i]
		name_l.visible = true
		name_l.position = nr.position
		name_l.size = nr.size
		_set_label(name_l, str(s.get("name", "技能")), Color(1, 0.97, 0.88, 0.62 if locked else 0.92))

		var state_l: Label = lbl_skill_state[i]
		if locked:
			state_l.visible = true
			state_l.position = Vector2(r.position.x, r.position.y + r.size.y * 0.22)
			state_l.size = Vector2(r.size.x, r.size.y * 0.25)
			_set_label(state_l, "2级解锁", Color(1, 1, 1, 0.78))
		elif cooling:
			state_l.visible = true
			state_l.position = r.position
			state_l.size = r.size
			_set_label(state_l, "%.1f" % p.cds[i], Color(1, 1, 1, 0.95))
		else:
			state_l.visible = false

	lbl_skill_ult.visible = p.level >= 2 and p.cds[2] <= 0.0
	if lbl_skill_ult.visible:
		var r3 := skill_rect(2)
		lbl_skill_ult.position = Vector2(r3.position.x - 12.0, r3.position.y - fs_small - 8.0)
		lbl_skill_ult.size = Vector2(r3.size.x + 24.0, fs_small + 4.0)
		_set_label(lbl_skill_ult, "大招", C_GOLD_SOFT)


func _update_plate_labels() -> void:
	var show: bool = sim != null and not paused and not sim.over
	lbl_avatar.visible = show
	lbl_level.visible = show
	lbl_plate_name.visible = show
	lbl_plate_hp.visible = show
	lbl_plate_ult.visible = show
	if not show:
		return
	var p = sim.player
	if p == null:
		return
	var safe := _safe()
	var plate := Rect2(safe.position.x + 12.0, safe.position.y + 12.0, safe.size.x * 0.30, safe.size.y * 0.135)
	var av_r := plate.size.y * 0.34
	var av_c := plate.position + Vector2(plate.size.y * 0.5, plate.size.y * 0.5)
	var text_x := av_c.x + av_r + 12.0
	var name_w := plate.end.x - text_x - 10.0
	var hp_bar := Rect2(text_x, plate.position.y + plate.size.y * 0.42, name_w, plate.size.y * 0.24)
	var chip := Rect2(plate.end.x - safe.size.x * 0.10 - 10.0, plate.position.y + 10.0, safe.size.x * 0.10, plate.size.y * 0.26)

	lbl_avatar.position = av_c - Vector2(av_r, av_r)
	lbl_avatar.size = Vector2(av_r * 2.0, av_r * 2.0)
	_set_label(lbl_avatar, str(p.def.get("name", "?")).substr(0, 1), C_CREAM)

	var lv_c := av_c + Vector2(av_r * 0.85, av_r * 0.85)
	lbl_level.position = lv_c - Vector2(av_r * 0.42, av_r * 0.42)
	lbl_level.size = Vector2(av_r * 0.84, av_r * 0.84)
	_set_label(lbl_level, str(p.level), C_INK)

	lbl_plate_name.position = Vector2(text_x, plate.position.y + plate.position.y * 0.0 + plate.size.y * 0.10)
	lbl_plate_name.size = Vector2(name_w, plate.size.y * 0.30)
	_set_label(lbl_plate_name, "%s · %s" % [str(p.def.get("name", "?")), str(p.def.get("role", ""))], C_CREAM)

	lbl_plate_hp.position = hp_bar.position
	lbl_plate_hp.size = hp_bar.size
	_set_label(lbl_plate_hp, "%d / %d" % [roundi(p.hp), roundi(p.max_hp)], C_CREAM)

	lbl_plate_ult.position = chip.position
	lbl_plate_ult.size = chip.size
	var ult_text := "大招就绪" if p.level >= 2 else "大招 %d%%" % int(clampf(p.xp / sim.xp_to_level2, 0.0, 1.0) * 100.0)
	_set_label(lbl_plate_ult, ult_text, C_GOLD_SOFT if p.level >= 2 else Color(0.95, 0.92, 0.8, 0.7))


func _update_score_labels() -> void:
	var show: bool = sim != null and not paused and not sim.over
	lbl_score.visible = show
	lbl_clock.visible = show
	lbl_sudden.visible = show and sim.sudden_death
	if not show:
		return
	var safe := _safe()
	var w := safe.size.x
	var panel := Rect2(safe.position.x + w * 0.5 - w * 0.15, safe.position.y + 8.0, w * 0.30, safe.size.y * 0.115)
	lbl_score.position = panel.position
	lbl_score.size = Vector2(panel.size.x, panel.size.y * 0.48)
	_set_label(lbl_score, "蓝 %d : %d 红" % [sim.score_blue, sim.score_red], C_CREAM)

	lbl_clock.position = Vector2(panel.position.x, panel.position.y + panel.size.y * 0.44)
	lbl_clock.size = Vector2(panel.size.x, panel.size.y * 0.40)
	_set_label(lbl_clock, _time_text(sim.clock), C_GOLD_SOFT)

	var pip_y := panel.end.y + 4.0
	lbl_sudden.position = Vector2(safe.position.x + w * 0.5 - w * 0.16, pip_y + safe.size.y * 0.02)
	lbl_sudden.size = Vector2(w * 0.32, safe.size.y * 0.03)
	_set_label(lbl_sudden, "终极对决 · 水晶全开", Color(1.0, 0.84, 0.44))


func _draw_battle(safe: Rect2) -> void:
	var w := safe.size.x
	var h := safe.size.y
	var fs := int(h * 0.026)
	var fs_small := int(h * 0.019)
	_begin_batch()
	var t := Time.get_ticks_usec()
	_draw_player_plate(safe, fs, fs_small)
	_prof_add("plate", Time.get_ticks_usec() - t)
	t = Time.get_ticks_usec()
	_draw_score(safe, fs, fs_small)
	_prof_add("score", Time.get_ticks_usec() - t)
	_draw_pause_button(safe)
	t = Time.get_ticks_usec()
	_draw_world_bars(safe)
	_prof_add("worldbars", Time.get_ticks_usec() - t)
	t = Time.get_ticks_usec()
	_draw_skill_buttons(safe, fs, fs_small)
	_prof_add("skills", Time.get_ticks_usec() - t)
	_draw_joystick(safe)
	t = Time.get_ticks_usec()
	_draw_banners(safe, fs)
	_prof_add("banners", Time.get_ticks_usec() - t)
	t = Time.get_ticks_usec()
	_draw_floats(safe, fs)
	_prof_add("floats", Time.get_ticks_usec() - t)

	var p = sim.player
	if p != null and not p.is_alive():
		var box := Rect2(safe.position.x + w * 0.34, safe.position.y + h * 0.38, w * 0.32, h * 0.16)
		_add_rect(box, C_PANEL)
		_text_center(Rect2(box.position.x, box.position.y + h * 0.02, box.size.x, h * 0.07), "倒下啦…", h * 0.035, Color(1, 0.86, 0.78))
		_text_center(Rect2(box.position.x, box.position.y + h * 0.09, box.size.x, h * 0.05),
			"%d 秒后复活" % maxi(1, ceili(p.respawn_t)), h * 0.024, C_CREAM)

	_flush_batches()


func _draw_player_plate(safe: Rect2, fs: int, fs_small: int) -> void:
	var p = sim.player
	if p == null:
		return
	var plate := Rect2(safe.position.x + 12.0, safe.position.y + 12.0, safe.size.x * 0.30, safe.size.y * 0.135)
	_add_rect(plate, C_PANEL)

	var av_r := plate.size.y * 0.34
	var av_c := plate.position + Vector2(plate.size.y * 0.5, plate.size.y * 0.5)

	var text_x := av_c.x + av_r + 12.0
	var name_w := plate.end.x - text_x - 10.0

	var hp_bar := Rect2(text_x, plate.position.y + plate.size.y * 0.42, name_w, plate.size.y * 0.24)
	_add_rect(hp_bar, Color(0.02, 0.08, 0.07, 0.9))
	var hp_k := clampf(p.hp / p.max_hp, 0.0, 1.0)
	var hp_color := Color(0.44, 0.87, 0.50) if hp_k > 0.55 else (Color(1, 0.80, 0.36) if hp_k > 0.28 else Color(1, 0.48, 0.40))
	_add_rect(Rect2(hp_bar.position, Vector2(hp_bar.size.x * hp_k, hp_bar.size.y)), hp_color)

	var xp_bar := Rect2(text_x, hp_bar.end.y + plate.size.y * 0.08, name_w, plate.size.y * 0.075)
	_add_rect(xp_bar, Color(0.03, 0.08, 0.07, 0.8))
	if p.level >= 2:
		_add_rect(xp_bar, Color(1, 0.80, 0.35, 0.92))
	else:
		var xp_k := clampf(p.xp / sim.xp_to_level2, 0.0, 1.0)
		_add_rect(Rect2(xp_bar.position, Vector2(xp_bar.size.x * xp_k, xp_bar.size.y)), Color(1, 0.80, 0.35, 0.95))

	var chip := Rect2(plate.end.x - safe.size.x * 0.10 - 10.0, plate.position.y + 10.0, safe.size.x * 0.10, plate.size.y * 0.26)
	_add_rect(chip, Color(0.04, 0.11, 0.09, 0.72))


func _draw_score(safe: Rect2, fs: int, fs_small: int) -> void:
	var w := safe.size.x
	var panel := Rect2(safe.position.x + w * 0.5 - w * 0.15, safe.position.y + 8.0, w * 0.30, safe.size.y * 0.115)
	_add_rect(panel, C_PANEL)

	var pip_y := panel.end.y + 4.0
	var pip_w := w * 0.035
	for i in range(4):
		var x := safe.position.x + w * 0.5 - pip_w * 2.4 + i * (pip_w + 4.0)
		var r := Rect2(x, pip_y, pip_w, safe.size.y * 0.012)
		if i < 2:
			var alive: bool = sim.towers_blue[i].is_alive()
			_add_rect(r, C_BLUE if alive else Color(0.3, 0.4, 0.42, 0.45))
		else:
			var alive: bool = sim.towers_red[i - 2].is_alive()
			_add_rect(r, C_RED if alive else Color(0.42, 0.34, 0.32, 0.45))


func _draw_minimap(safe: Rect2, fs_small: int) -> void:
	var mini := Rect2(safe.end.x - safe.size.x * 0.205 - 12.0, safe.position.y + 12.0, safe.size.x * 0.205, safe.size.y * 0.165)
	_panel(mini, C_PANEL)
	draw_rect(mini, Color(1, 1, 1, 0.10), false, 1.0)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for u in sim.units:
		if not u.is_alive():
			continue
		var px: float = mini.position.x + u.pos.x / sim.map_w * mini.size.x
		var py: float = mini.position.y + u.pos.y / sim.map_h * mini.size.y
		var c := C_BLUE if u.team == sim.BLUE else C_RED
		var rad := 6.0 if u.kind == sim.BASE else (4.0 if u.kind == sim.TOWER else 2.5)
		var center := Vector2(px, py)
		var seg := 8
		for k in range(seg):
			var a0 := TAU * float(k) / float(seg)
			var a1 := TAU * float(k + 1) / float(seg)
			pts.append(center)
			cols.append(c)
			pts.append(center + Vector2(cos(a0), sin(a0)) * rad)
			cols.append(c)
			pts.append(center + Vector2(cos(a1), sin(a1)) * rad)
			cols.append(c)
	if pts.size() > 0:
		draw_polygon(pts, cols)
	if sim.player != null:
		var pp := mini.position + Vector2(sim.player.pos.x / sim.map_w * mini.size.x, sim.player.pos.y / sim.map_h * mini.size.y)
		draw_arc(pp, 6.0, 0.0, TAU, 16, Color(1, 0.95, 0.8, 0.9), 1.5)


func _draw_pause_button(safe: Rect2) -> void:
	var r := pause_rect()
	_add_rect(r, C_PANEL_DEEP)
	var bar_w := r.size.x * 0.10
	_add_rect(Rect2(r.position.x + r.size.x * 0.34, r.position.y + r.size.y * 0.30, bar_w, r.size.y * 0.40), C_CREAM)
	_add_rect(Rect2(r.position.x + r.size.x * 0.56, r.position.y + r.size.y * 0.30, bar_w, r.size.y * 0.40), C_CREAM)


func _draw_world_bars(safe: Rect2) -> void:
	if cam == null:
		return
	for u in sim.units:
		if not u.is_alive():
			continue
		if u.kind == sim.TOWER or u.kind == sim.BASE:
			var wp := Vector3(u.pos.x, u.height * 0.55 + 24.0, u.pos.y)
			if cam.is_position_behind(wp):
				continue
			var sp := cam.unproject_position(wp)
			var bw := 86.0 if u.kind == sim.BASE else 64.0
			var br := Rect2(sp.x - bw * 0.5, sp.y, bw, 7.0)
			_add_rect(Rect2(br.position - Vector2(2, 2), br.size + Vector2(4, 4)), Color(0.02, 0.06, 0.05, 0.85))
			_add_rect(br, Color(0.03, 0.08, 0.07, 0.9))
			var hp_k := clampf(u.hp / u.max_hp, 0.0, 1.0)
			_add_rect(Rect2(br.position, Vector2(br.size.x * hp_k, br.size.y)), C_BLUE if u.team == sim.BLUE else C_RED)
			if u.kind == sim.BASE:
				_text_center(Rect2(br.position.x - 16.0, br.position.y - 16.0, br.size.x + 32.0, 14.0),
					"我方水晶" if u.team == sim.BLUE else "敌方水晶", 12, C_BLUE if u.team == sim.BLUE else C_RED)
	for u in sim.heroes:
		if not u.is_alive() or u == sim.player:
			continue
		var wp := Vector3(u.pos.x, u.height * 1.16 + 18.0, u.pos.y)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var bw := 48.0
		var br := Rect2(sp.x - bw * 0.5, sp.y, bw, 5.0)
		_add_rect(Rect2(br.position - Vector2(2, 2), br.size + Vector2(4, 4)), Color(0.02, 0.06, 0.05, 0.88))
		_add_rect(br, Color(0.04, 0.10, 0.09, 0.9))
		var hp_k := clampf(u.hp / u.max_hp, 0.0, 1.0)
		_add_rect(Rect2(br.position, Vector2(br.size.x * hp_k, br.size.y)), C_BLUE if u.team == sim.BLUE else C_RED)


func _draw_skill_buttons(safe: Rect2, fs: int, fs_small: int) -> void:
	var p = sim.player
	if p == null:
		return
	for i in range(3):
		var r := skill_rect(i)
		var s: Dictionary = p.skills[i]
		var locked: bool = s.get("unlock_at_2", false) and p.level < 2
		var cooling: bool = p.cds[i] > 0.0
		var ready := not locked and not cooling
		var ult := i == 2

		_add_disc(r.get_center(), r.size.x * 0.5, Color(0.25, 0.30, 0.28, 0.94) if locked else (C_GOLD if ult else Color(0.98, 0.74, 0.40)))

		if locked:
			_draw_skill_name_bg(r)
			continue

		if cooling:
			_add_disc(r.get_center(), r.size.x * 0.5, Color(0.02, 0.05, 0.04, 0.62))

		_draw_skill_name_bg(r)


func _draw_skill_name_bg(r: Rect2) -> void:
	var nr := Rect2(r.position.x + r.size.x * 0.06, r.end.y - r.size.y * 0.30, r.size.x * 0.88, r.size.y * 0.24)
	_add_rect(nr, Color(0.04, 0.10, 0.09, 0.62))


func _draw_pie(center: Vector2, radius: float, ratio: float, color: Color) -> void:
	if ratio <= 0.01:
		return
	var pts := PackedVector2Array()
	pts.append(center)
	var steps := maxi(3, int(28.0 * ratio))
	for k in range(steps + 1):
		var a := -PI * 0.5 + ratio * TAU * float(k) / float(steps)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)


func _draw_joystick(safe: Rect2) -> void:
	if input_hub == null or not input_hub.joy_active:
		return
	var jr := safe.size.y * 0.12
	var c: Vector2 = input_hub.joy_center
	var knob: Vector2 = input_hub.joy_knob
	_add_disc(c, jr, Color(0.05, 0.12, 0.10, 0.28))
	_add_disc(knob, jr * 0.44, Color(1, 0.96, 0.85, 0.72))
	_add_disc(knob, jr * 0.24, Color(1, 0.99, 0.92, 0.75))


func _draw_banners(safe: Rect2, fs: int) -> void:
	for b in banners:
		var k: float = float(b["t"]) / float(b["life"])
		var a := clampf(k * 2.0, 0.0, 1.0)
		var r := Rect2(safe.position.x + safe.size.x * 0.22, safe.position.y + safe.size.y * 0.145,
			safe.size.x * 0.56, safe.size.y * 0.068)
		_add_rect(r, Color(0.05, 0.15, 0.12, 0.78 * a))
		_add_rect(Rect2(r.position.x + r.size.x * 0.30, r.end.y - 4.0, r.size.x * 0.40, 2.0),
			Color(1, 0.84, 0.44, 0.72 * a))
		_text_center(r, str(b["text"]), fs, Color(1, 0.97, 0.88, a))


func _draw_floats(safe: Rect2, fs: int) -> void:
	if cam == null:
		return
	for item in floats:
		var wp: Vector3 = item["pos"]
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var k: float = float(item["t"]) / float(item["life"])
		var a := clampf(1.0 - k, 0.0, 1.0)
		var color: Color = item["color"]
		var sz := int(fs * 0.95)
		draw_string(font, sp + Vector2(-70.0, -10.0) + Vector2(1.5, 2.5), str(item["text"]),
			HORIZONTAL_ALIGNMENT_CENTER, 140.0, sz, Color(0.04, 0.07, 0.06, a * 0.65))
		draw_string(font, sp + Vector2(-70.0, -10.0), str(item["text"]),
			HORIZONTAL_ALIGNMENT_CENTER, 140.0, sz, Color(color.r, color.g, color.b, a))


func _draw_pause(safe: Rect2) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size()), Color(0.03, 0.10, 0.09, 0.74), true)
	var p := _pause_panel()
	_panel(p, Color(0.09, 0.22, 0.19, 0.98))
	_text_center(Rect2(p.position.x, p.position.y + safe.size.y * 0.035, p.size.x, safe.size.y * 0.09),
		"暂停一下", safe.size.y * 0.045, C_CREAM)

	var r1 := resume_rect()
	_panel(r1, C_GOLD)
	_text_center(r1, "继续", safe.size.y * 0.032, C_INK)

	var r2 := restart_rect()
	_panel(r2, Color(0.10, 0.26, 0.22, 0.95))
	_text_center(r2, "重新开始", safe.size.y * 0.028, C_CREAM)

	_text_center(Rect2(p.position.x, p.end.y - safe.size.y * 0.10, p.size.x, safe.size.y * 0.045),
		"目标：拆两座蘑菇塔，再点亮敌方水晶", safe.size.y * 0.019, Color(1, 0.95, 0.84, 0.72))


func _draw_result(safe: Rect2) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size()), Color(0.03, 0.10, 0.09, 0.78), true)
	var p := _result_panel()
	_panel(p, Color(0.09, 0.22, 0.19, 0.97))
	var win: bool = sim.winner == sim.BLUE
	_text_center(Rect2(p.position.x, p.position.y + safe.size.y * 0.04, p.size.x, safe.size.y * 0.12),
		"胜利！" if win else "差一点点！", safe.size.y * 0.052, C_GOLD_SOFT if win else Color(1, 0.85, 0.8))

	var pdata = sim.player
	if pdata != null:
		_text_center(Rect2(p.position.x, p.position.y + safe.size.y * 0.18, p.size.x, safe.size.y * 0.06),
			"%s · %s" % [str(pdata.def.get("name", "?")), str(pdata.def.get("role", ""))],
			safe.size.y * 0.028, C_CREAM)

	_text_center(Rect2(p.position.x, p.position.y + safe.size.y * 0.27, p.size.x, safe.size.y * 0.05),
		"击杀 蓝 %d : %d 红   ·   用时 %s" % [sim.score_blue, sim.score_red, _time_text(sim.clock)],
		safe.size.y * 0.024, Color(1, 0.95, 0.84, 0.9))
	if pdata != null:
		_text_center(Rect2(p.position.x, p.position.y + safe.size.y * 0.34, p.size.x, safe.size.y * 0.05),
			"你击败了 %d 位，倒下 %d 次" % [pdata.kills, pdata.deaths],
			safe.size.y * 0.024, Color(0.85, 0.96, 0.88, 0.82))

	var r := result_restart_rect()
	_panel(r, C_GOLD)
	_text_center(r, "再来一局", safe.size.y * 0.032, C_INK)


func _time_text(t: float) -> String:
	return "%d:%02d" % [floori(t / 60.0), floori(fmod(t, 60.0))]


func _panel(r: Rect2, c: Color) -> void:
	draw_rect(r, c, true)
	draw_rect(r, Color(1, 1, 1, 0.10), false, 1.0)


func _text(pos: Vector2, text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, pos + Vector2(1.5, 2.0), text, align, width, size, Color(0.04, 0.07, 0.06, color.a * 0.6))
	draw_string(font, pos, text, align, width, size, color)


func _text_center(r: Rect2, text: String, size: int, color: Color) -> void:
	var pos := Vector2(r.position.x, r.position.y + r.size.y * 0.72)
	draw_string(font, pos + Vector2(1.5, 2.0), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, Color(0.04, 0.07, 0.06, color.a * 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, color)

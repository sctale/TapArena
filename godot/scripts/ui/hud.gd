class_name Hud
extends Control

# 像素风战斗 HUD：方块面板、像素图标、5×7 像素数字。
# 形状全部走 MultiMesh 合批；中文文本走 Label 节点缓存，避免每帧重排字形。

var sim = null
var cam: Camera3D = null
var input_hub = null
var paused := false
var sound_on := true
var result_ready := true
var cinematic_start_ms := 0
var font: Font = null
var icons = null

var banners: Array = []
var floats: Array = []
var redraw_acc := 0.0

var rect_mm: MultiMesh
var disc_mm: MultiMesh
var rect_mm_fg: MultiMesh
var disc_mm_fg: MultiMesh
# 最上层圆盘：小地图英雄/BOSS/玩家标记，必须在所有批次矩形之后绘制。
var disc_ui: MultiMesh
var white_tex: Texture2D
var disc_tex: Texture2D
var rect_i := 0
var disc_i := 0
var disc_ui_i := 0
var disc_ui_warned := false
var front := false

var lbl_plate_name: Label
var lbl_plate_sub: Label
var lbl_skill_name: Array = []
var lbl_banner: Label
var lbl_sudden: Label
var lbl_pause_title: Label
var lbl_pause_goal: Label
var lbl_pause_btn1: Label
var lbl_pause_btn2: Label
var lbl_pause_btn3: Label
var lbl_pause_sound: Label
var lbl_pause_foot: Label
var lbl_res_title: Label
var lbl_res_reason: Label
var lbl_res_hint: Label
var lbl_res_team_blue: Label
var lbl_res_team_red: Label
var lbl_res_score: Label
var lbl_res_time: Label
var lbl_res_cols: Array = []
var lbl_res_names: Array = []
var lbl_res_levels: Array = []
var lbl_res_kds: Array = []
var lbl_res_btn: Label
var lbl_res_home: Label
var lbl_cinematic: Label
var lbl_cinematic_sub: Label
var hero_labels: Dictionary = {}

const PANEL_FILL := Color("2b3531")
const PANEL_DEEP := Color("1f2824")
const PANEL_LIGHT := Color("e8e0cf")
const PANEL_DARK := Color("0f1512")
const CREAM := Color("f5eedc")
const GOLD := Color("f5c542")
const GREEN := Color("5aa83c")
const BLUE := Color("4fa8e0")
const RED := Color("e0523c")
const INK := Color("221a12")


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
	icons = load("res://scripts/art/pixel_icons.gd").new()
	_make_batches()
	_make_labels()
	set_process(true)


func attach(s, c: Camera3D) -> void:
	sim = s
	cam = c
	sim.banner.connect(_on_banner)
	sim.float_text.connect(_on_float_text)
	_update_labels()
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
	var s := maxf(64.0, safe.size.y * 0.085)
	return Rect2(safe.end.x - s - 12.0, safe.position.y + safe.size.y * 0.205, s, s)


func skill_rect(i: int) -> Rect2:
	var safe := _safe()
	var h := safe.size.y
	# 圆形技能钮：直径与冷却转盘一致，整体比上一版缩小，避免挡住战场。
	var bs: Array = [h * 0.112, h * 0.104, h * 0.124]
	var cx: Array = [safe.end.x - h * 0.250, safe.end.x - h * 0.145, safe.end.x - h * 0.155]
	var cy: Array = [safe.end.y - h * 0.170, safe.end.y - h * 0.335, safe.end.y - h * 0.500]
	return Rect2(cx[i] - bs[i] * 0.5, cy[i] - bs[i] * 0.5, bs[i], bs[i])


func joystick_center() -> Vector2:
	var safe := _safe()
	return Vector2(safe.position.x + safe.size.x * 0.145, safe.end.y - safe.size.y * 0.205)


func joystick_radius() -> float:
	return _safe().size.y * 0.112


func _pause_panel() -> Rect2:
	var safe := _safe()
	return Rect2(safe.position.x + safe.size.x * 0.30, safe.position.y + safe.size.y * 0.13,
		safe.size.x * 0.40, safe.size.y * 0.74)


func _result_panel() -> Rect2:
	var safe := _safe()
	return Rect2(safe.position.x + safe.size.x * 0.125, safe.position.y + safe.size.y * 0.055,
		safe.size.x * 0.75, safe.size.y * 0.89)


func _result_score_rect() -> Rect2:
	var p := _result_panel()
	return Rect2(p.position.x + p.size.x * 0.04, p.position.y + p.size.y * 0.150,
		p.size.x * 0.92, p.size.y * 0.050)


func _result_team_rect(team: int) -> Rect2:
	# 双方战绩卡左右分栏：每队独立卡头/列头/行区，5v5 十人也保证每人一行完整信息。
	var p := _result_panel()
	var gap := p.size.x * 0.02
	var w := (p.size.x * 0.96 - gap) * 0.5
	var x := p.position.x + p.size.x * 0.02
	if team != sim.BLUE:
		x += w + gap
	return Rect2(x, p.position.y + p.size.y * 0.218, w, p.size.y * 0.644)


func _result_team_head_h(c: Rect2) -> float:
	return c.size.y * 0.085


func _result_col_head_h(c: Rect2) -> float:
	return c.size.y * 0.055


func _result_row_rect(team: int, i: int) -> Rect2:
	var c := _result_team_rect(team)
	var rows := maxi(1, sim.team_size)
	var top := _result_team_head_h(c) + _result_col_head_h(c)
	var rh := (c.size.y - top) / float(rows)
	return Rect2(c.position.x + 6.0, c.position.y + top + rh * float(i), c.size.x - 12.0, rh - 3.0)


func _result_col_rect(row: Rect2, k: int) -> Rect2:
	# k: 0 姓名 1 等级 2 击杀·死亡 3 输出。
	match k:
		0:
			return Rect2(row.position.x + row.size.x * 0.16, row.position.y,
				row.size.x * 0.29, row.size.y)
		1:
			return Rect2(row.position.x + row.size.x * 0.47, row.position.y,
				row.size.x * 0.10, row.size.y)
		2:
			return Rect2(row.position.x + row.size.x * 0.57, row.position.y,
				row.size.x * 0.18, row.size.y)
	return Rect2(row.position.x + row.size.x * 0.75, row.position.y,
		row.size.x * 0.23, row.size.y)


func _result_heroes(team: int) -> Array:
	var out: Array = []
	for u in sim.heroes:
		if u.team == team:
			out.append(u)
	return out


func resume_rect() -> Rect2:
	var safe := _safe()
	var p := _pause_panel()
	return Rect2(p.position.x + p.size.x * 0.16, p.position.y + p.size.y * 0.15,
		p.size.x * 0.68, safe.size.y * 0.095)


func restart_rect() -> Rect2:
	var safe := _safe()
	var p := _pause_panel()
	return Rect2(p.position.x + p.size.x * 0.16, p.position.y + p.size.y * 0.28,
		p.size.x * 0.68, safe.size.y * 0.085)


func home_rect() -> Rect2:
	var safe := _safe()
	var p := _pause_panel()
	return Rect2(p.position.x + p.size.x * 0.16, p.position.y + p.size.y * 0.39,
		p.size.x * 0.68, safe.size.y * 0.085)


func sound_rect() -> Rect2:
	var safe := _safe()
	var p := _pause_panel()
	return Rect2(p.position.x + p.size.x * 0.16, p.position.y + p.size.y * 0.505,
		p.size.x * 0.68, safe.size.y * 0.075)


func result_restart_rect() -> Rect2:
	var p := _result_panel()
	var bw := p.size.x * 0.30
	return Rect2(p.position.x + p.size.x * 0.19, p.position.y + p.size.y * 0.915,
		bw, p.size.y * 0.075)


func result_home_rect() -> Rect2:
	var p := _result_panel()
	var bw := p.size.x * 0.30
	return Rect2(p.end.x - p.size.x * 0.19 - bw, p.position.y + p.size.y * 0.915,
		bw, p.size.y * 0.075)


# ---- 形状批 ----

func _make_batches() -> void:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	white_tex = ImageTexture.create_from_image(img)
	disc_tex = _make_disc_texture(32)

	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	rect_mm = MultiMesh.new()
	rect_mm.transform_format = MultiMesh.TRANSFORM_2D
	rect_mm.use_colors = true
	rect_mm.mesh = quad
	# 像素数字每个亮点都是一个矩形，带描边时消耗很快；结算页 10 人 × 5 位输出
	# 最多约 5.1k 个矩形，旧版 4096 会在底部行静默丢字（表现就是最下面两行没数字）。
	rect_mm.instance_count = 8192

	rect_mm_fg = MultiMesh.new()
	rect_mm_fg.transform_format = MultiMesh.TRANSFORM_2D
	rect_mm_fg.use_colors = true
	rect_mm_fg.mesh = quad
	rect_mm_fg.instance_count = 8192

	disc_mm = MultiMesh.new()
	disc_mm.transform_format = MultiMesh.TRANSFORM_2D
	disc_mm.use_colors = true
	disc_mm.mesh = quad
	# 小地图要画英雄/BOSS/野怪圆点，给圆盘批次留足余量。
	disc_mm.instance_count = 192

	disc_mm_fg = MultiMesh.new()
	disc_mm_fg.transform_format = MultiMesh.TRANSFORM_2D
	disc_mm_fg.use_colors = true
	disc_mm_fg.mesh = quad
	disc_mm_fg.instance_count = 192

	disc_ui = MultiMesh.new()
	disc_ui.transform_format = MultiMesh.TRANSFORM_2D
	disc_ui.use_colors = true
	disc_ui.mesh = quad
	disc_ui.instance_count = 128


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


func _begin_batch(front_layer := false) -> void:
	front = front_layer
	rect_i = 0
	disc_i = 0


func _add_rect(r: Rect2, c: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var mm := rect_mm_fg if front else rect_mm
	if rect_i >= mm.instance_count:
		return
	mm.set_instance_transform_2d(rect_i, Transform2D(0.0, r.size, 0.0, r.get_center()))
	mm.set_instance_color(rect_i, c)
	rect_i += 1


func _add_box(r: Rect2, c: Color, t: float) -> void:
	_add_rect(Rect2(r.position.x, r.position.y, r.size.x, t), c)
	_add_rect(Rect2(r.position.x, r.end.y - t, r.size.x, t), c)
	_add_rect(Rect2(r.position.x, r.position.y, t, r.size.y), c)
	_add_rect(Rect2(r.end.x - t, r.position.y, t, r.size.y), c)


func _add_rot_rect(center: Vector2, size: Vector2, angle: float, c: Color) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var mm := rect_mm_fg if front else rect_mm
	if rect_i >= mm.instance_count:
		return
	mm.set_instance_transform_2d(rect_i, Transform2D(angle, size, 0.0, center))
	mm.set_instance_color(rect_i, c)
	rect_i += 1


func _add_seg(a: Vector2, b: Vector2, width: float, c: Color) -> void:
	# 批次版折线：每段一个旋转矩形，两端各延长半个线宽，拐角不留缝。
	var d := b - a
	var l := d.length()
	if l < 0.5 or width <= 0.0:
		return
	var dir := d / l
	var mid := (a + b) * 0.5
	_add_rot_rect(mid, Vector2(l + width, width), atan2(dir.y, dir.x), c)


func _add_disc(center: Vector2, radius: float, c: Color) -> void:
	var mm := disc_mm_fg if front else disc_mm
	if disc_i >= mm.instance_count:
		return
	mm.set_instance_transform_2d(disc_i, Transform2D(0.0, Vector2(radius * 2.0, radius * 2.0), 0.0, center))
	mm.set_instance_color(disc_i, c)
	disc_i += 1


func _add_ui_disc(center: Vector2, radius: float, c: Color) -> void:
	# 最上层圆盘：在所有批次矩形之后统一绘制，用于小地图标记。
	if disc_ui_i >= disc_ui.instance_count:
		if not disc_ui_warned:
			disc_ui_warned = true
			print("[HUD] minimap disc overlay overflow")
		return
	disc_ui.set_instance_transform_2d(disc_ui_i, Transform2D(0.0, Vector2(radius * 2.0, radius * 2.0), 0.0, center))
	disc_ui.set_instance_color(disc_ui_i, c)
	disc_ui_i += 1


func _flush_batches() -> void:
	if front:
		rect_mm_fg.visible_instance_count = rect_i
		disc_mm_fg.visible_instance_count = disc_i
		draw_multimesh(disc_mm_fg, disc_tex)
		draw_multimesh(rect_mm_fg, white_tex)
	else:
		rect_mm.visible_instance_count = rect_i
		disc_mm.visible_instance_count = disc_i
		draw_multimesh(disc_mm, disc_tex)
		draw_multimesh(rect_mm, white_tex)


func _panel(r: Rect2, fill: Color, light := PANEL_LIGHT, dark := PANEL_DARK) -> void:
	_add_rect(r, fill)
	_add_box(r, light, 2.0)
	_add_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 2), light)
	_add_rect(Rect2(r.position.x + 2, r.position.y + 2, 2, r.size.y - 4), light)
	_add_rect(Rect2(r.position.x + 2, r.end.y - 4, r.size.x - 4, 2), dark)
	_add_rect(Rect2(r.end.x - 4, r.position.y + 2, 2, r.size.y - 4), dark)


func _button(r: Rect2, fill: Color) -> void:
	_add_rect(r, fill)
	_add_box(r, PANEL_DARK, 3.0)
	_add_rect(Rect2(r.position.x + 3, r.position.y + 3, r.size.x - 6, 2), Color(1, 1, 1, 0.35))
	_add_rect(Rect2(r.position.x + 3, r.end.y - 5, r.size.x - 6, 2), Color(0, 0, 0, 0.35))


func _digit(text: String, pos: Vector2, px: float, color: Color, outline := true) -> void:
	var rects: Array = icons.number_rects(text, pos.x, pos.y, px)
	if outline:
		for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
			for r in rects:
				_add_rect(Rect2((r as Rect2).position + d * px, (r as Rect2).size), Color(0.06, 0.05, 0.03, color.a * 0.85))
	for r in rects:
		_add_rect(r, color)


func _digit_center(text: String, r: Rect2, px: float, color: Color, outline := true) -> void:
	var sz: Vector2 = icons.number_size(text, px)
	_digit(text, Vector2(r.get_center().x - sz.x * 0.5, r.get_center().y - sz.y * 0.5), px, color, outline)


func _digit_mid(text: String, center_x: float, y: float, px: float, color: Color) -> void:
	var sz: Vector2 = icons.number_size(text, px)
	_digit(text, Vector2(center_x - sz.x * 0.5, y), px, color, true)


func _digit_right(text: String, right_x: float, y: float, px: float, color: Color) -> void:
	var sz: Vector2 = icons.number_size(text, px)
	_digit(text, Vector2(right_x - sz.x, y), px, color, true)


# ---- Label 缓存 ----

func _mk_label(size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.05, 0.04, 0.03, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.visible = false
	add_child(l)
	return l


func _make_labels() -> void:
	var h := _safe().size.y
	lbl_plate_name = _mk_label(int(h * 0.028), CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_plate_sub = _mk_label(int(h * 0.019), Color(0.85, 0.92, 0.86, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	for i in range(3):
		lbl_skill_name.append(_mk_label(int(h * 0.017), CREAM))
	lbl_banner = _mk_label(int(h * 0.026), CREAM)
	lbl_sudden = _mk_label(int(h * 0.022), Color("ffd76a"))
	lbl_pause_title = _mk_label(int(h * 0.048), GOLD)
	lbl_pause_btn1 = _mk_label(int(h * 0.030), INK)
	lbl_pause_btn2 = _mk_label(int(h * 0.028), CREAM)
	lbl_pause_btn3 = _mk_label(int(h * 0.028), CREAM)
	lbl_pause_sound = _mk_label(int(h * 0.024), CREAM)
	lbl_pause_goal = _mk_label(int(h * 0.019), Color(1, 0.96, 0.85, 0.8))
	lbl_pause_foot = _mk_label(int(h * 0.017), Color(1, 1, 1, 0.55))
	lbl_res_title = _mk_label(int(h * 0.050), GOLD)
	lbl_res_reason = _mk_label(int(h * 0.024), Color(1, 0.96, 0.86, 0.92))
	lbl_res_hint = _mk_label(int(h * 0.017), Color(1, 1, 1, 0.62))
	lbl_res_team_blue = _mk_label(int(h * 0.024), Color("9fd6f5"), HORIZONTAL_ALIGNMENT_LEFT)
	lbl_res_team_red = _mk_label(int(h * 0.024), Color("ffb3a6"), HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_res_score = _mk_label(int(h * 0.032), CREAM)
	lbl_res_time = _mk_label(int(h * 0.020), Color(1, 1, 1, 0.68), HORIZONTAL_ALIGNMENT_RIGHT)
	var col_align := [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER,
		HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT]
	for i in range(8):
		lbl_res_cols.append(_mk_label(int(h * 0.016), Color(1, 0.96, 0.86, 0.55), col_align[i % 4]))
	for i in range(10):
		lbl_res_names.append(_mk_label(int(h * 0.021), CREAM, HORIZONTAL_ALIGNMENT_LEFT))
		lbl_res_levels.append(_mk_label(int(h * 0.019), CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		lbl_res_kds.append(_mk_label(int(h * 0.019), CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	lbl_res_btn = _mk_label(int(h * 0.030), INK)
	lbl_res_home = _mk_label(int(h * 0.028), CREAM)
	lbl_cinematic = _mk_label(int(h * 0.065), GOLD)
	lbl_cinematic_sub = _mk_label(int(h * 0.026), Color(1, 0.96, 0.86, 0.85))


func _set_label(l: Label, text: String) -> void:
	if l.text != text:
		l.text = text


func _place(l: Label, r: Rect2, visible := true) -> void:
	l.visible = visible
	l.position = r.position
	l.size = r.size


func _on_banner(text: String, duration: float) -> void:
	banners.append({"text": text, "t": 0.0, "life": duration})
	if banners.size() > 3:
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
	redraw_acc += delta
	if redraw_acc >= 1.0 / 60.0:
		redraw_acc = 0.0
		_update_labels()
		queue_redraw()


func _update_labels() -> void:
	if sim == null:
		return
	var h := _safe().size.y
	var show_battle: bool = not paused and not sim.over
	var p = sim.player

	if p != null and show_battle:
		var plate := _plate_rect(_safe(), h)
		var av := plate.size.y - 16.0
		var text_x := plate.position.x + av + 16.0
		var name_w := plate.end.x - text_x - 12.0
		var chip := _ult_chip_rect(plate)
		_place(lbl_plate_name, Rect2(text_x, plate.position.y + 4.0, name_w, plate.size.y * 0.30))
		_set_label(lbl_plate_name, "%s · %s" % [str(p.def.get("name", "?")), str(p.def.get("role", ""))])
		_place(lbl_plate_sub, Rect2(chip.end.x + 12.0, chip.position.y, plate.end.x - chip.end.x - 24.0, chip.size.y))
		_set_label(lbl_plate_sub, "大招冷却中" if p.level >= 2 and p.cds[2] > 0.0
			else ("2 级解锁大招" if p.level < 2 else "大招已就绪"))
	else:
		lbl_plate_name.visible = false
		lbl_plate_sub.visible = false

	for i in range(3):
		var l: Label = lbl_skill_name[i]
		if not show_battle or p == null:
			l.visible = false
			continue
		var r := skill_rect(i)
		var s: Dictionary = p.skills[i]
		var locked: bool = s.get("unlock_at_2", false) and p.level < 2
		var nr := Rect2(r.position.x, r.end.y + 2.0, r.size.x, h * 0.030)
		_place(l, nr, true)
		var nm := str(s.get("name", "技能"))
		l.add_theme_color_override("font_color", Color(1, 0.97, 0.88, 0.55) if locked else CREAM)
		_set_label(l, nm)

	# 其他英雄名字
	var seen: Dictionary = {}
	for u in sim.heroes:
		if u.is_player:
			continue
		var key := str(u.uid)
		var l: Label = hero_labels.get(key)
		if l == null:
			l = _mk_label(int(h * 0.019), CREAM)
			hero_labels[key] = l
		if not u.is_alive() or not show_battle or cam == null:
			l.visible = false
			continue
		var rp: Vector2 = sim.render_pos(u)
		var wp := Vector3(rp.x, u.height * 1.20 + 40.0, rp.y)
		if cam.is_position_behind(wp):
			l.visible = false
			continue
		var sp := cam.unproject_position(wp)
		var sz := Vector2(h * 0.14, h * 0.030)
		_place(l, Rect2(sp.x - sz.x * 0.5, sp.y - sz.y, sz.x, sz.y), true)
		l.add_theme_color_override("font_color", BLUE if u.team == sim.BLUE else Color("ffb3a6"))
		_set_label(l, str(u.def.get("name", "")))

	# 主播报（暂停和结算时隐藏）
	if not banners.is_empty() and show_battle:
		var b: Dictionary = banners[banners.size() - 1]
		var a: float = clampf(float(b["t"]) * 6.0, 0.0, 1.0)
		_place(lbl_banner, _banner_rect(_safe(), h), true)
		lbl_banner.add_theme_color_override("font_color", Color(1, 0.97, 0.88, a))
		_set_label(lbl_banner, str(b["text"]))
	else:
		lbl_banner.visible = false

	if show_battle and sim.sudden_death:
		var w := _safe().size.x
		var panel := _score_rect(_safe(), h)
		_place(lbl_sudden, Rect2(_safe().position.x + w * 0.5 - w * 0.16,
			panel.end.y + h * 0.024, w * 0.32, h * 0.032), true)
		var left := maxi(0, ceili(sim.match_cap - sim.clock))
		if left <= 60:
			_set_label(lbl_sudden, "结算倒计时 %d:%02d" % [left / 60, left % 60])
			lbl_sudden.add_theme_color_override("font_color", Color("ff9a7a"))
		else:
			_set_label(lbl_sudden, "终极对决 · 水晶全开")
			lbl_sudden.add_theme_color_override("font_color", Color("ffd76a"))
	else:
		lbl_sudden.visible = false

	var show_cine: bool = sim.over and not result_ready
	if show_cine:
		_place(lbl_cinematic, Rect2(_safe().position.x, _safe().position.y + h * 0.36,
			_safe().size.x, h * 0.12), true)
		_set_label(lbl_cinematic, "水晶破碎！")
		_place(lbl_cinematic_sub, Rect2(_safe().position.x, _safe().position.y + h * 0.49,
			_safe().size.x, h * 0.05), true)
		_set_label(lbl_cinematic_sub, "正在结算…")
	else:
		lbl_cinematic.visible = false
		lbl_cinematic_sub.visible = false

	_update_panel_labels()


func _update_panel_labels() -> void:
	var h := _safe().size.y
	var show_pause: bool = paused and sim != null and not sim.over
	var show_result: bool = sim != null and sim.over and result_ready
	for l in [lbl_pause_title, lbl_pause_goal, lbl_pause_btn1, lbl_pause_btn2, lbl_pause_btn3,
			lbl_pause_sound, lbl_pause_foot, lbl_res_title, lbl_res_reason, lbl_res_hint,
			lbl_res_team_blue, lbl_res_team_red, lbl_res_score, lbl_res_time,
			lbl_res_btn, lbl_res_home]:
		(l as Label).visible = false
	for l in lbl_res_cols + lbl_res_names + lbl_res_levels + lbl_res_kds:
		(l as Label).visible = false

	if show_pause:
		var p := _pause_panel()
		_place(lbl_pause_title, Rect2(p.position.x, p.position.y + p.size.y * 0.045, p.size.x, h * 0.085))
		_set_label(lbl_pause_title, "暂停一下")
		_place(lbl_pause_btn1, resume_rect())
		_set_label(lbl_pause_btn1, "继续")
		_place(lbl_pause_btn2, restart_rect())
		_set_label(lbl_pause_btn2, "重新开始")
		_place(lbl_pause_btn3, home_rect())
		_set_label(lbl_pause_btn3, "回首页")
		_place(lbl_pause_sound, sound_rect())
		_set_label(lbl_pause_sound, "音效：开" if sound_on else "音效：关")
		lbl_pause_sound.add_theme_color_override("font_color", CREAM if sound_on else Color(1, 1, 1, 0.55))
		_place(lbl_pause_goal, Rect2(p.position.x, p.position.y + p.size.y * 0.66, p.size.x, h * 0.045))
		_set_label(lbl_pause_goal, "三路推进 → 拆掉两座塔，再点亮水晶" if sim.five_v_five
			else "往右走 → 拆外塔、拆内塔，再点亮水晶")
		_place(lbl_pause_foot, Rect2(p.position.x, p.end.y - h * 0.08, p.size.x, h * 0.04))
		_set_label(lbl_pause_foot, "萌兽峡谷 · Godot 4.7.2")
	elif show_result:
		# 结算页：标题 → 比分条 → 双方战绩卡（每队独立行区）→ 提示与按钮。
		var p := _result_panel()
		var win: bool = sim.winner == sim.BLUE
		_place(lbl_res_title, Rect2(p.position.x, p.position.y + p.size.y * 0.012,
			p.size.x, p.size.y * 0.073))
		_set_label(lbl_res_title, "胜利！" if win else "差一点点！")
		lbl_res_title.add_theme_color_override("font_color", GOLD if win else Color("ffb3a6"))
		_place(lbl_res_reason, Rect2(p.position.x, p.position.y + p.size.y * 0.088,
			p.size.x, p.size.y * 0.044))
		_set_label(lbl_res_reason, sim.end_reason if not sim.end_reason.is_empty() else "水晶被摧毁")

		var strip := _result_score_rect()
		_place(lbl_res_score, Rect2(strip.position.x + strip.size.x * 0.02, strip.position.y,
			strip.size.x * 0.60, strip.size.y))
		_set_label(lbl_res_score, "蓝队 %d : %d 红队" % [sim.score_blue, sim.score_red])
		_place(lbl_res_time, Rect2(strip.position.x + strip.size.x * 0.64, strip.position.y,
			strip.size.x * 0.34, strip.size.y))
		_set_label(lbl_res_time, "用时 %s" % _time_text(sim.clock))

		var rows := maxi(1, sim.team_size)
		for team in [sim.BLUE, sim.RED]:
			var c := _result_team_rect(team)
			var team_l: Label = lbl_res_team_blue if team == sim.BLUE else lbl_res_team_red
			_place(team_l, Rect2(c.position.x + c.size.x * 0.04, c.position.y,
				c.size.x * 0.60, _result_team_head_h(c)))
			_set_label(team_l, "蓝队" if team == sim.BLUE else "红队")
			var col_base := 0 if team == sim.BLUE else 4
			var col_y := c.position.y + _result_team_head_h(c)
			var col_rect := Rect2(c.position.x + 6.0, col_y, c.size.x - 12.0,
				_result_col_head_h(c))
			var col_texts := ["英雄", "等级", "击杀·死亡", "输出"]
			for k in range(4):
				_place(lbl_res_cols[col_base + k], _result_col_rect(col_rect, k))
				_set_label(lbl_res_cols[col_base + k], col_texts[k])
			var list := _result_heroes(team)
			var idx_base := 0 if team == sim.BLUE else rows
			for i in range(rows):
				var row := _result_row_rect(team, i)
				var idx := idx_base + i
				var l: Label = lbl_res_names[idx]
				_place(l, _result_col_rect(row, 0))
				_place(lbl_res_levels[idx], _result_col_rect(row, 1))
				_place(lbl_res_kds[idx], _result_col_rect(row, 2))
				if i >= list.size():
					# 人数不足时补占位符，绝不留只有底色的空行。
					_set_label(l, "—")
					_set_label(lbl_res_levels[idx], "—")
					_set_label(lbl_res_kds[idx], "—")
					l.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
					lbl_res_levels[idx].add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
					lbl_res_kds[idx].add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
					continue
				var u = list[i]
				var nm := str(u.def.get("name", "?"))
				if u == sim.player:
					_set_label(l, "%s（你）" % nm)
					l.add_theme_color_override("font_color", GOLD)
				else:
					_set_label(l, nm)
					l.add_theme_color_override("font_color",
						Color(0.78, 0.90, 1.0) if team == sim.BLUE else Color(1.0, 0.80, 0.74))
				_set_label(lbl_res_levels[idx], "Lv%d" % u.level)
				_set_label(lbl_res_kds[idx], "%d / %d" % [u.kills, u.deaths])
				lbl_res_levels[idx].add_theme_color_override("font_color", CREAM)
				lbl_res_kds[idx].add_theme_color_override("font_color", CREAM)

		_place(lbl_res_hint, Rect2(p.position.x, p.position.y + p.size.y * 0.872,
			p.size.x, p.size.y * 0.033))
		_set_label(lbl_res_hint, "金色边框 = 你 · ★ = 输出最高")
		_place(lbl_res_btn, result_restart_rect())
		_set_label(lbl_res_btn, "再来一局")
		_place(lbl_res_home, result_home_rect())
		_set_label(lbl_res_home, "回首页")


func _time_text(t: float) -> String:
	return "%d:%02d" % [floori(t / 60.0), floori(fmod(t, 60.0))]


func _xp_progress(p) -> float:
	# 级内经验进度：当前级阈值 → 下一级阈值；满级恒满。3v3 等价于旧的 2 级封顶。
	if sim == null or p == null or sim.xp_levels.is_empty():
		return 1.0
	if p.level >= sim.level_cap:
		return 1.0
	var next: float = sim.xp_next(p)
	var prev := 0.0
	if p.level >= 2:
		prev = float(sim.xp_levels[clampi(p.level - 2, 0, sim.xp_levels.size() - 1)])
	return clampf((p.xp - prev) / maxf(0.01, next - prev), 0.0, 1.0)


# ---- 绘制 ----

func _draw() -> void:
	if sim == null:
		return
	disc_ui_i = 0
	var safe := _safe()
	_begin_batch()
	if sim.over:
		if result_ready:
			_draw_result_bg(safe)
			_flush_batches()
			_draw_result_icons(safe)
		else:
			_draw_cinematic(safe)
			_flush_batches()
	elif paused:
		_draw_pause(safe)
		_flush_batches()
	else:
		_draw_battle_bg(safe)
		_flush_batches()
		_draw_battle_icons(safe)
		_begin_batch(true)
		_draw_battle_fg(safe)
		_flush_batches()
		# 小地图圆点标记最后画，保证压在底色与兵线之上。
		disc_ui.visible_instance_count = disc_ui_i
		draw_multimesh(disc_ui, disc_tex)


func _draw_battle_bg(safe: Rect2) -> void:
	var h := safe.size.y
	# 世界血条先画，后面的所有 HUD 面板都压在它上面（血条不能盖住小地图）。
	_draw_world_bars(safe, h)
	_draw_player_plate_bg(safe, h)
	_draw_score_bg(safe, h)
	_draw_minimap(safe, h)
	_draw_pause_button(safe, h)
	_draw_skill_bg(safe, h)
	_draw_joystick(safe, h)
	# 播报底框：独立一层，避免文字直接压在战场上，也把播报和比分/倒计时分开。
	if not banners.is_empty():
		_panel(_banner_rect(safe, h), Color(0.12, 0.15, 0.12, 0.90))


func _draw_battle_icons(safe: Rect2) -> void:
	var h := safe.size.y
	var p = sim.player
	if p != null:
		var plate := _plate_rect(safe, h)
		var av := plate.size.y * 0.86
		var av_rect := Rect2(plate.position.x + 5.0, plate.position.y + (plate.size.y - av) * 0.5, av, av)
		var portrait: Texture2D = icons.hero_portrait(p.hero_id, p.fur,
			p.def.get("cream_c", p.fur), p.def.get("dark_c", p.fur), p.accent)
		draw_texture_rect(portrait, av_rect, false)
	_draw_score_icons(safe, h)
	_draw_skill_icons(safe, h)
	_draw_objective(safe, h)


func _draw_objective(safe: Rect2, h: float) -> void:
	# 在当前要拆的敌方建筑头顶挂一颗跳动的星星，提示「先打这里」。
	if cam == null or sim == null or sim.player == null:
		return
	var front = sim.front_structure(sim.BLUE)
	if front == null or not front.is_alive():
		return
	var wp := Vector3(front.pos.x, front.height + 78.0, front.pos.y)
	if cam.is_position_behind(wp):
		return
	var sp := cam.unproject_position(wp)
	var s := h * 0.030
	var pulse := 0.65 + sin(Time.get_ticks_msec() * 0.005) * 0.25
	var diamond := PackedVector2Array([
		sp + Vector2(0, -s), sp + Vector2(s, 0), sp + Vector2(0, s), sp + Vector2(-s, 0),
	])
	draw_colored_polygon(diamond, Color(0.06, 0.08, 0.07, 0.75))
	var icon: Texture2D = icons.tex("ui_star")
	draw_texture_rect(icon, Rect2(sp - Vector2(s, s) * 0.86, Vector2(s, s) * 1.72), false,
		Color(1, 1, 1, pulse))


func _draw_battle_fg(safe: Rect2) -> void:
	var h := safe.size.y
	var p = sim.player
	if p != null:
		_draw_player_plate_fg(safe, h, p)
	_draw_score_fg(safe, h)
	_draw_skill_fg(safe, h)
	_draw_floats(safe, h)

	if p != null and not p.is_alive():
		var box := Rect2(safe.position.x + safe.size.x * 0.34, safe.position.y + h * 0.40,
			safe.size.x * 0.32, h * 0.14)
		_panel(box, PANEL_FILL)
		_digit_center("%d" % maxi(1, ceili(p.respawn_t)),
			Rect2(box.position.x, box.position.y + 6, box.size.x, box.size.y * 0.55), h * 0.010,
			Color(1, 1, 1, 1))
		_add_rect(Rect2(box.position.x, box.get_center().y + 4, box.size.x, 2), Color(1, 1, 1, 0.18))


func _plate_rect(safe: Rect2, h: float) -> Rect2:
	return Rect2(safe.position.x + 12.0, safe.position.y + 12.0, safe.size.x * 0.325, h * 0.17)


func _banner_rect(safe: Rect2, h: float) -> Rect2:
	# 主播报条：下移到玩家信息面板 / 小地图 / 比分与倒计时之下，留出整段空白，
	# 巨兽出场等长提示不会再和顶部任何文字贴在一起。
	return Rect2(safe.position.x + safe.size.x * 0.24, safe.position.y + h * 0.245,
		safe.size.x * 0.52, h * 0.056)


func _draw_player_plate_bg(safe: Rect2, h: float) -> void:
	var p = sim.player
	if p == null:
		return
	var plate := _plate_rect(safe, h)
	_panel(plate, PANEL_FILL)

	var av := plate.size.y - 16.0
	var av_rect := Rect2(plate.position.x + 8.0, plate.position.y + 8.0, av, av)
	_add_rect(Rect2(av_rect.position - Vector2(2, 2), av_rect.size + Vector2(4, 4)), PANEL_DARK)

	var text_x := plate.position.x + av + 16.0
	var name_w := plate.end.x - text_x - 12.0
	var hp_bar := Rect2(text_x, plate.position.y + plate.size.y * 0.38, name_w, plate.size.y * 0.155)
	_add_rect(Rect2(hp_bar.position - Vector2(2, 2), hp_bar.size + Vector2(4, 4)), PANEL_DARK)
	_add_rect(hp_bar, Color(0.10, 0.14, 0.12, 0.95))
	var hp_k := clampf(p.hp / p.max_hp, 0.0, 1.0)
	var hp_color := Color("6ecf5a") if hp_k > 0.55 else (GOLD if hp_k > 0.28 else RED)
	_add_rect(Rect2(hp_bar.position, Vector2(hp_bar.size.x * hp_k, hp_bar.size.y)), hp_color)
	_add_rect(Rect2(hp_bar.position, Vector2(hp_bar.size.x, 2)), Color(1, 1, 1, 0.22))

	var xp_bar := Rect2(text_x, hp_bar.end.y + 5.0, name_w, plate.size.y * 0.075)
	_add_rect(xp_bar, Color(0.09, 0.12, 0.10, 0.95))
	var xp_k := _xp_progress(p)
	_add_rect(Rect2(xp_bar.position, Vector2(xp_bar.size.x * xp_k, xp_bar.size.y)), GOLD)

	var chip := _ult_chip_rect(plate)
	_add_rect(chip, PANEL_DEEP)
	_add_rect(Rect2(chip.position, Vector2(chip.size.x, 2)), Color(1, 1, 1, 0.16))


func _ult_chip_rect(plate: Rect2) -> Rect2:
	var av := plate.size.y - 16.0
	var text_x := plate.position.x + av + 16.0
	var name_w := plate.end.x - text_x - 12.0
	var y := plate.position.y + plate.size.y * 0.665
	return Rect2(text_x, y, name_w * 0.34, plate.size.y * 0.16)


func _draw_player_plate_fg(safe: Rect2, h: float, p) -> void:
	var plate := _plate_rect(safe, h)
	var av := plate.size.y - 16.0
	var av_rect := Rect2(plate.position.x + 8.0, plate.position.y + 8.0, av, av)
	var lv_s := av * 0.30
	var lv_c := av_rect.end - Vector2(lv_s * 0.5, lv_s * 0.5)
	_add_disc(lv_c, lv_s * 0.5, GOLD)
	_add_disc(lv_c, lv_s * 0.5 - 2.0, PANEL_DEEP)
	_digit(str(p.level), Vector2(lv_c.x - lv_s * 0.14, lv_c.y - lv_s * 0.30), maxf(1.0, h * 0.0028), CREAM, false)

	var chip := _ult_chip_rect(plate)
	var ult_k := 1.0 if p.level >= 2 else clampf(p.xp / sim.xp_to_level2, 0.0, 1.0)
	var chip_icon: Texture2D = icons.tex("ui_star")
	var ics := chip.size.y * 0.62
	draw_texture_rect(chip_icon, Rect2(chip.position.x + 6, chip.get_center().y - ics * 0.5, ics, ics), false,
		Color(1, 1, 1, 0.35 + ult_k * 0.65))
	var num := "%d%%" % int(ult_k * 100.0)
	var num_col := GOLD if p.level >= 2 else Color(1, 0.95, 0.82, 0.85)
	if p.level >= 2 and p.cds[2] > 0.0:
		num = "%d" % ceili(p.cds[2])
		num_col = Color(1, 1, 1, 1)
	_digit(num, Vector2(chip.position.x + ics + 12.0, chip.get_center().y - h * 0.0034 * 3.5),
		maxf(1.0, h * 0.0034), num_col, false)


func _draw_score_bg(safe: Rect2, h: float) -> void:
	var panel := _score_rect(safe, h)
	_panel(panel, PANEL_FILL)
	var chip := h * 0.032
	var cy := panel.position.y + h * 0.014
	# 左右队伍色块，让比分归属一眼可见。
	var blue_chip := Rect2(panel.position.x + panel.size.x * 0.11 - chip * 0.5, cy, chip, chip)
	_add_rect(blue_chip, BLUE)
	_add_box(blue_chip, PANEL_DARK, 2.0)
	var red_chip := Rect2(panel.end.x - panel.size.x * 0.11 - chip * 0.5, cy, chip, chip)
	_add_rect(red_chip, Color("f07a63"))
	_add_box(red_chip, PANEL_DARK, 2.0)
	# 小比分条贴在本方半区，不再挤在正中间。
	var tower_slots := mini(6, sim.towers_blue.size())
	var pip_w := panel.size.x * 0.022 * 2.0 / float(maxi(1, tower_slots))
	var pip_h := h * 0.012
	var pip_y := panel.end.y - h * 0.022
	for i in range(tower_slots):
		var bx := panel.position.x + panel.size.x * 0.15 + float(i) * (pip_w + 4.0)
		var br := Rect2(bx, pip_y, pip_w, pip_h)
		_add_rect(Rect2(br.position - Vector2(1, 1), br.size + Vector2(2, 2)), PANEL_DARK)
		_add_rect(br, BLUE if sim.towers_blue[i].is_alive() else Color(0.22, 0.28, 0.30, 0.7))
		var rx := panel.end.x - panel.size.x * 0.15 - float(i) * (pip_w + 4.0) - pip_w
		var rr := Rect2(rx, pip_y, pip_w, pip_h)
		_add_rect(Rect2(rr.position - Vector2(1, 1), rr.size + Vector2(2, 2)), PANEL_DARK)
		_add_rect(rr, Color("f07a63") if sim.towers_red[i].is_alive() else Color(0.30, 0.24, 0.22, 0.7))


func _score_rect(safe: Rect2, h: float) -> Rect2:
	var w := safe.size.x
	return Rect2(safe.position.x + w * 0.5 - w * 0.145, safe.position.y + 8.0, w * 0.29, h * 0.105)


func _draw_score_icons(safe: Rect2, h: float) -> void:
	var panel := _score_rect(safe, h)
	var isz := h * 0.042
	draw_texture_rect(icons.tex("ui_clock"),
		Rect2(panel.get_center().x - h * 0.069, panel.position.y + h * 0.016, isz, isz), false)


func _draw_score_fg(safe: Rect2, h: float) -> void:
	var panel := _score_rect(safe, h)
	var px := maxf(2.2, h * 0.0052)
	var ty := panel.position.y + h * 0.030
	_digit_mid(str(sim.score_blue), panel.position.x + panel.size.x * 0.21, ty, px, Color(0.78, 0.91, 1.0))
	_digit_mid(str(sim.score_red), panel.position.x + panel.size.x * 0.79, ty, px, Color(1.0, 0.82, 0.76))
	var time_px := maxf(2.0, h * 0.0040)
	var time_text := _time_text(sim.clock)
	var time_x := panel.get_center().x - h * 0.019
	_digit(time_text, Vector2(time_x, panel.position.y + h * 0.030), time_px,
		GOLD if sim.sudden_death else CREAM)


func _draw_minimap(safe: Rect2, h: float) -> void:
	var box := Rect2(safe.end.x - safe.size.x * 0.205 - 12.0, safe.position.y + 12.0,
		safe.size.x * 0.205, h * 0.175)
	# 内区按地图真实宽高比适配：5v5 正方形、3v3 1.875:1，杜绝横向拉伸。
	var k := minf(box.size.x / sim.map_w, box.size.y / sim.map_h)
	var inner_size := Vector2(sim.map_w * k, sim.map_h * k)
	var inner := Rect2(box.get_center() - inner_size * 0.5, inner_size)
	var us := inner.size.y / 180.0
	_panel(Rect2(inner.position - Vector2(4, 4), inner.size + Vector2(8, 8)), Color("3f6b32"))
	_add_rect(inner, Color("4f8a3f"))
	# 3v3 一条中路，5v5 三条对角兵线；河道用浅蓝折线（批次线段，避免被批次覆盖）。
	var mini_paths: Array = sim.lane_paths if sim.five_v_five else [sim.lane]
	if sim.five_v_five and sim.river.size() >= 2:
		var rw := maxf(2.0, inner.size.y * 0.022)
		for i in range(sim.river.size() - 1):
			_add_seg(_mini_pos(inner, sim.river[i]), _mini_pos(inner, sim.river[i + 1]), rw, Color("7fc4e8"))
	var lw := maxf(2.0, inner.size.y * 0.030)
	for path in mini_paths:
		if path.size() < 2:
			continue
		for i in range(path.size() - 1):
			_add_seg(_mini_pos(inner, path[i]), _mini_pos(inner, path[i + 1]), lw, Color("b09464"))

	# ---- 标识分级（模仿王者荣耀式小地图的通用语言；批次内后加在上）----
	var enemy_c := Color("f07a63")
	# 野怪：小黄点，弱存在感。
	for un in sim.units:
		if un.is_alive() and un.kind == sim.JUNGLE:
			_add_ui_disc(_mini_pos(inner, sim.render_pos(un)), 2.4 * us, Color("e2c46a"))
	# 药剂：绿色十字。
	for pt in sim.potions:
		if not pt.active:
			continue
		var mp := _mini_pos(inner, pt.pos)
		_add_rect(Rect2(mp.x - 4.0 * us, mp.y - 4.0 * us, 8.0 * us, 8.0 * us), PANEL_DARK)
		_add_rect(Rect2(mp.x - 3.0 * us, mp.y - 1.0 * us, 6.0 * us, 2.0 * us), Color(0.55, 1.0, 0.65))
		_add_rect(Rect2(mp.x - 1.0 * us, mp.y - 3.0 * us, 2.0 * us, 6.0 * us), Color(0.55, 1.0, 0.65))
	# 塔：菱形；水晶：大方块，与英雄圆点形状区分。
	for un in sim.units:
		if not un.is_alive():
			continue
		var tc := BLUE if un.team == sim.BLUE else enemy_c
		if un.kind == sim.TOWER:
			_add_rot_rect(_mini_pos(inner, un.pos), Vector2(5.0 * us, 5.0 * us), PI * 0.25, tc)
		elif un.kind == sim.BASE:
			var mp := _mini_pos(inner, un.pos)
			var s2 := 5.0 * us
			_add_rect(Rect2(mp.x - s2 - us, mp.y - s2 - us, (s2 + us) * 2.0, (s2 + us) * 2.0), PANEL_DARK)
			_add_rect(Rect2(mp.x - s2, mp.y - s2, s2 * 2.0, s2 * 2.0), tc)
	# 英雄：队伍色圆点 + 深色描边（敌红我蓝，一眼可辨）。
	for hh in sim.heroes:
		if not hh.is_alive():
			continue
		var mp := _mini_pos(inner, sim.render_pos(hh))
		_add_ui_disc(mp, 5.5 * us + 1.5 * us, PANEL_DARK)
		_add_ui_disc(mp, 5.5 * us, BLUE if hh.team == sim.BLUE else enemy_c)
	# BOSS：最大标记 + 金色双环 + 呼吸缩放，全场最醒目。
	if sim.boss != null and sim.boss.is_alive():
		var mp := _mini_pos(inner, sim.render_pos(sim.boss))
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.08
		_add_ui_disc(mp, 12.0 * us * pulse, Color("ffd76a"))
		_add_ui_disc(mp, 11.0 * us * pulse, PANEL_DARK)
		_add_ui_disc(mp, 10.0 * us * pulse, Color("ffd76a"))
		_add_ui_disc(mp, 8.0 * us * pulse, BLUE if sim.boss.team == sim.BLUE else enemy_c)
	# 玩家：英雄点之上叠金色环 + 朝向小三角（针形），永远最上层。
	if sim.player != null and sim.player.is_alive():
		var mp := _mini_pos(inner, sim.render_pos(sim.player))
		_add_ui_disc(mp, 8.0 * us, PANEL_DARK)
		_add_ui_disc(mp, 7.0 * us, Color("ffd76a"))
		_add_ui_disc(mp, 5.5 * us, BLUE if sim.player.team == sim.BLUE else enemy_c)
		var fd: Vector2 = sim.player.face_dir
		if fd.length_squared() > 0.0001:
			fd = fd.normalized()
			_add_seg(mp + fd * 7.0 * us, mp + fd * 13.5 * us, maxf(1.5, 2.4 * us), Color(1.0, 0.98, 0.88))


func _mini_pos(inner: Rect2, p: Vector2) -> Vector2:
	return Vector2(inner.position.x + p.x / sim.map_w * inner.size.x,
		inner.position.y + p.y / sim.map_h * inner.size.y)


func _draw_pause_button(safe: Rect2, h: float) -> void:
	var r := pause_rect()
	_button(r, PANEL_FILL)
	var bar_w := r.size.x * 0.12
	_add_rect(Rect2(r.position.x + r.size.x * 0.32, r.position.y + r.size.y * 0.28, bar_w, r.size.y * 0.44), CREAM)
	_add_rect(Rect2(r.position.x + r.size.x * 0.56, r.position.y + r.size.y * 0.28, bar_w, r.size.y * 0.44), CREAM)


func _draw_world_bars(safe: Rect2, h: float) -> void:
	if cam == null:
		return
	for u in sim.units:
		if not u.is_alive():
			continue
		if u.kind == sim.TOWER or u.kind == sim.BASE or u.kind == sim.BOSS:
			var rp: Vector2 = sim.render_pos(u)
			var wp := Vector3(rp.x, u.height * 0.55 + 30.0, rp.y)
			if cam.is_position_behind(wp):
				continue
			var sp := cam.unproject_position(wp)
			var bw := h * 0.090 if u.kind == sim.BASE else (h * 0.110 if u.kind == sim.BOSS else h * 0.065)
			var bh := h * 0.009
			var br := Rect2(sp.x - bw * 0.5, sp.y, bw, bh)
			_add_rect(Rect2(br.position - Vector2(2, 2), br.size + Vector2(4, 4)), PANEL_DARK)
			_add_rect(br, Color(0.08, 0.10, 0.09, 0.95))
			var hp_k := clampf(u.hp / u.max_hp, 0.0, 1.0)
			_add_rect(Rect2(br.position, Vector2(br.size.x * hp_k, br.size.y)),
				BLUE if u.team == sim.BLUE else Color("f07a63"))
	for u in sim.heroes:
		if not u.is_alive() or u == sim.player:
			continue
		var rp: Vector2 = sim.render_pos(u)
		var wp := Vector3(rp.x, u.height * 1.10 + 18.0, rp.y)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var bw := h * 0.052
		var bh := h * 0.007
		var br := Rect2(sp.x - bw * 0.5, sp.y, bw, bh)
		_add_rect(Rect2(br.position - Vector2(2, 2), br.size + Vector2(4, 4)), PANEL_DARK)
		_add_rect(br, Color(0.08, 0.10, 0.09, 0.95))
		var hp_k := clampf(u.hp / u.max_hp, 0.0, 1.0)
		_add_rect(Rect2(br.position, Vector2(br.size.x * hp_k, br.size.y)),
			BLUE if u.team == sim.BLUE else Color("f07a63"))


func _draw_skill_bg(safe: Rect2, h: float) -> void:
	var p = sim.player
	if p == null:
		return
	for i in range(3):
		var r := skill_rect(i)
		var s: Dictionary = p.skills[i]
		var locked: bool = s.get("unlock_at_2", false) and p.level < 2
		var c := r.get_center()
		var rad := r.size.x * 0.5
		# 外圈描边 + 内圈填充，做成和冷却转盘同尺寸的圆形按钮。
		_add_disc(c, rad + 2.5, PANEL_LIGHT if not locked else Color(0.52, 0.55, 0.52, 1.0))
		_add_disc(c, rad, PANEL_DEEP if locked else Color("3f4f46"))
		_add_disc(c - Vector2(0, rad * 0.30), rad * 0.72, Color(1, 1, 1, 0.06))


func _draw_skill_icons(safe: Rect2, h: float) -> void:
	var p = sim.player
	if p == null:
		return
	for i in range(3):
		var r := skill_rect(i)
		var s: Dictionary = p.skills[i]
		var locked: bool = s.get("unlock_at_2", false) and p.level < 2
		var c := r.get_center()
		var icon_name := "skill_" + str(s.get("kind", "aoe"))
		var icon: Texture2D = icons.tex(icon_name)
		var isz := r.size.x * 0.62
		var icon_rect := Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz))
		var tint := Color(1, 1, 1, 1) if not locked else Color(0.62, 0.64, 0.62, 0.9)
		draw_texture_rect(icon, icon_rect, false, tint)


func _draw_skill_fg(safe: Rect2, h: float) -> void:
	var p = sim.player
	if p == null:
		return
	for i in range(3):
		var r := skill_rect(i)
		var s: Dictionary = p.skills[i]
		var locked: bool = s.get("unlock_at_2", false) and p.level < 2
		var cooling: bool = p.cds[i] > 0.0
		var c := r.get_center()
		var rad := r.size.x * 0.5 - 1.0

		if cooling:
			var total: float = maxf(0.01, float(s.get("cd", 1.0)))
			var ratio := clampf(p.cds[i] / total, 0.0, 1.0)
			# 扇形遮罩与圆形按钮同尺寸：整个圆盘轻压暗，剩余冷却再盖一层扇形。
			draw_circle(c, rad, Color(0.02, 0.03, 0.03, 0.32))
			_draw_cd_sweep(c, rad, ratio, Color(0.02, 0.03, 0.03, 0.66))
			if ratio < 0.999:
				var a_end := -PI * 0.5 + TAU * ratio
				draw_line(c, c + Vector2(cos(a_end), sin(a_end)) * rad,
					Color(1, 1, 1, 0.45), maxf(1.0, h * 0.0018))
			_digit_center(str(ceili(p.cds[i])), r, maxf(2.0, h * 0.0044), Color(1, 1, 1, 1), true)

		if locked:
			_digit_center("2", r, maxf(2.0, h * 0.0048), Color(1, 1, 1, 0.85), true)

		if i == 2 and not locked and not cooling:
			var glow := 0.5 + sin(Time.get_ticks_msec() * 0.004) * 0.3
			draw_arc(c, rad + 5.0, 0.0, TAU, 44, Color(1.0, 0.86, 0.35, glow), 2.5, true)


func _draw_cd_sweep(center: Vector2, radius: float, ratio: float, color: Color) -> void:
	if ratio <= 0.001:
		return
	if ratio >= 0.999:
		draw_circle(center, radius, color)
		return
	var steps := maxi(4, ceili(40.0 * ratio))
	var pts := PackedVector2Array()
	pts.append(center)
	var start := -PI * 0.5
	for k in range(steps + 1):
		var a := start + TAU * ratio * float(k) / float(steps)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)


func _draw_joystick(safe: Rect2, h: float) -> void:
	if input_hub == null:
		return
	var c: Vector2 = input_hub.joy_center
	var jr: float = input_hub.joy_radius
	var active: bool = input_hub.joy_active
	# 固定圆形轮盘：底座常驻左下角，激活时描边和摇杆头变亮。
	draw_circle(c, jr, Color(0.07, 0.12, 0.09, 0.38 if active else 0.26))
	draw_arc(c, jr, 0.0, TAU, 48, Color(1, 0.97, 0.88, 0.42 if active else 0.25), 2.5, true)
	draw_arc(c, jr * 0.64, 0.0, TAU, 40, Color(1, 1, 1, 0.18 if active else 0.10), 1.5, true)
	var knob: Vector2 = input_hub.joy_knob if active else c
	var kr := jr * 0.38
	draw_circle(knob, kr, Color(0.98, 0.94, 0.84, 0.78 if active else 0.52))
	draw_arc(knob, kr, 0.0, TAU, 32, Color(1, 1, 1, 0.72 if active else 0.45), 2.0, true)


func _draw_floats(safe: Rect2, h: float) -> void:
	if cam == null:
		return
	var px := maxf(1.0, h * 0.0034)
	for item in floats:
		var wp: Vector3 = item["pos"]
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var k: float = float(item["t"]) / float(item["life"])
		var a := clampf(1.0 - k, 0.0, 1.0)
		var color: Color = item["color"]
		var sz: Vector2 = icons.number_size(str(item["text"]), px)
		_digit(str(item["text"]), Vector2(sp.x - sz.x * 0.5, sp.y - px * 8.0 - k * h * 0.03), px,
			Color(color.r, color.g, color.b, a), true)


func _draw_pause(safe: Rect2) -> void:
	_add_rect(Rect2(Vector2.ZERO, viewport_size()), Color(0.03, 0.07, 0.06, 0.72))
	var p := _pause_panel()
	_panel(p, PANEL_FILL)
	_button(resume_rect(), GOLD)
	_button(restart_rect(), Color("4a5a50"))
	_button(home_rect(), Color("4a5a50"))
	_button(sound_rect(), Color("3a4a40"))
	_digit_center(_time_text(sim.clock), Rect2(p.position.x, p.position.y + p.size.y * 0.595,
		p.size.x, safe.size.y * 0.05), maxf(2.0, safe.size.y * 0.0042), CREAM)


func _draw_cinematic(safe: Rect2) -> void:
	_add_rect(Rect2(Vector2.ZERO, viewport_size()), Color(0.03, 0.05, 0.08, 0.55))
	var k := clampf(float(Time.get_ticks_msec() - cinematic_start_ms) / 380.0, 0.0, 1.0)
	if k < 1.0:
		_add_rect(Rect2(Vector2.ZERO, viewport_size()), Color(1, 1, 1, (1.0 - k) * 0.85))


func start_cinematic() -> void:
	result_ready = false
	cinematic_start_ms = Time.get_ticks_msec()
	queue_redraw()


func finish_cinematic() -> void:
	result_ready = true
	queue_redraw()


func _draw_result_bg(safe: Rect2) -> void:
	_add_rect(Rect2(Vector2.ZERO, viewport_size()), Color(0.03, 0.07, 0.06, 0.82))
	var p := _result_panel()
	_panel(p, PANEL_FILL)
	_add_rect(Rect2(p.position.x + 2.0, p.position.y + 2.0, p.size.x - 4.0, 5.0), GOLD)

	# 比分与用时独立成条，避免和标题/战绩卡挤在一起。
	var strip := _result_score_rect()
	_add_rect(strip, PANEL_DEEP)
	_add_box(strip, Color(1, 1, 1, 0.12), 1.0)
	_add_rect(Rect2(strip.position.x + strip.size.x * 0.62, strip.position.y + 4.0, 2.0,
		strip.size.y - 8.0), Color(1, 1, 1, 0.16))

	# 双方战绩卡：每队固定 team_size 行，行内姓名/等级/击杀死亡/输出齐全。
	var dpx := maxf(2.2, safe.size.y * 0.0040)
	for team in [sim.BLUE, sim.RED]:
		var c := _result_team_rect(team)
		var team_c: Color = BLUE if team == sim.BLUE else Color("f07a63")
		_add_rect(c, Color(0.10, 0.15, 0.13, 0.94))
		_add_box(c, Color(1, 1, 1, 0.10), 1.0)
		_add_rect(Rect2(c.position.x, c.position.y, c.size.x, 4.0), team_c)
		_add_rect(Rect2(c.position.x, c.position.y + 4.0, c.size.x, _result_team_head_h(c) - 4.0),
			Color(0.16, 0.24, 0.21, 0.95))
		var col_y := c.position.y + _result_team_head_h(c)
		_add_rect(Rect2(c.position.x, col_y, c.size.x, _result_col_head_h(c)),
			Color(0.12, 0.18, 0.16, 0.95))
		var list := _result_heroes(team)
		for i in range(maxi(1, sim.team_size)):
			var row := _result_row_rect(team, i)
			var u = list[i] if i < list.size() else null
			var is_me: bool = u != null and u == sim.player
			var fill := Color(0.20, 0.32, 0.38, 0.55) if team == sim.BLUE \
				else Color(0.38, 0.24, 0.22, 0.55)
			if is_me:
				fill = Color(0.98, 0.80, 0.35, 0.20)
			_add_rect(row, fill)
			_add_rect(Rect2(row.position.x, row.position.y, 5.0, row.size.y), team_c)
			if is_me:
				_add_box(row, GOLD, 2.0)
			if u != null:
				var ty := row.position.y + (row.size.y - 7.0 * dpx) * 0.5
				_digit_right(str(int(round(u.damage_dealt))), row.end.x - 8.0, ty, dpx,
					GOLD if is_me else CREAM)

	_button(result_restart_rect(), GOLD)
	_button(result_home_rect(), Color("4a5a50"))


func _draw_result_icons(_safe_rect: Rect2) -> void:
	var best = null
	for u in sim.heroes:
		if best == null or u.damage_dealt > best.damage_dealt:
			best = u
	for team in [sim.BLUE, sim.RED]:
		var c := _result_team_rect(team)
		var list := _result_heroes(team)
		for i in range(maxi(1, sim.team_size)):
			if i >= list.size():
				continue
			var u = list[i]
			var row := _result_row_rect(team, i)
			var ps := minf(row.size.y * 0.68, c.size.x * 0.125)
			var ar := Rect2(row.position.x + 6.0,
				row.position.y + (row.size.y - ps) * 0.5, ps, ps)
			if u == sim.player:
				draw_rect(Rect2(ar.position - Vector2(3, 3), ar.size + Vector2(6, 6)),
					GOLD, false, 2.0)
			var portrait: Texture2D = icons.hero_portrait(u.hero_id, u.fur,
				u.def.get("cream_c", u.fur), u.def.get("dark_c", u.fur), u.accent)
			draw_texture_rect(portrait, ar, false)
			draw_rect(Rect2(ar.position - Vector2(1, 1), ar.size + Vector2(2, 2)),
				Color(0, 0, 0, 0.35), false, 1.0)
			if u == best and u.damage_dealt > 0.0:
				var s := ps * 0.42
				draw_texture_rect(icons.tex("ui_star"),
					Rect2(ar.end.x - s * 0.72, ar.position.y - s * 0.42, s, s), false)

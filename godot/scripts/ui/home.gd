class_name Home
extends Control

# 像素风首页：标题、10 只英雄选人卡片、难度切换、开始按钮。
# 点卡片弹出人物介绍与三技能详情；头像使用 32×32 半身像。

signal start_requested(hero_id: String, difficulty: int, mode_5v5: bool)
signal ui_click

const HeroPortraitsScript = preload("res://scripts/art/hero_portraits.gd")
const BASE_HERO_IDS := ["tiger", "fox", "rabbit", "bear", "frog", "cat", "panda", "owl", "axolotl", "deer"]
const GOLD := Color("f5c542")
const CREAM := Color("f5eedc")
const PANEL_FILL := Color("2b3531")
const PANEL_DEEP := Color("1f2824")
const PANEL_LIGHT := Color("e8e0cf")
const PANEL_DARK := Color("0f1512")
const INK := Color("221a12")
const GREEN := Color("5aa83c")
const SKY := Color("9fd9f2")
const GRASS := Color("7fc45c")

var all_heroes: Array = []
var heroes: Array = []
var sel_index := 0
var difficulty := 0
var mode_5v5 := false
var font: Font = null
var icons = null
var portraits = null
var detail_open := false

var lbl_title: Label
var lbl_sub: Label
var lbl_start: Label
var lbl_easy: Label
var lbl_challenge: Label
var lbl_mode3: Label
var lbl_mode5: Label
var lbl_foot: Label
var lbl_hint: Label
var hero_name_labels: Array = []
var hero_blurb_labels: Array = []

var lbl_detail_name: Label
var lbl_detail_sub: Label
var lbl_detail_blurb: Label
var lbl_detail_tip: Label
var lbl_detail_close: Label
var lbl_detail_start: Label
var detail_skill_names: Array = []
var detail_skill_hints: Array = []
var detail_skill_meta: Array = []

var last_tap_frame := -1


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
	portraits = HeroPortraitsScript.new()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_heroes()
	_make_labels()
	detail_open = "--detail" in OS.get_cmdline_user_args()
	_refresh_labels()
	set_process(true)


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


func _load_heroes() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes.json"))
	if parsed == null:
		push_error("首页加载 heroes.json 失败")
		return
	all_heroes = parsed.get("heroes", [])
	for d in all_heroes:
		d["fur_c"] = Color.from_string(str(d.get("fur", "#FFFFFF")), Color.WHITE)
		d["dark_c"] = Color.from_string(str(d.get("dark", "#000000")), Color.BLACK)
		d["cream_c"] = Color.from_string(str(d.get("cream", "#FFFFFF")), Color.WHITE)
		d["accent_c"] = Color.from_string(str(d.get("accent", "#FFFFFF")), Color.WHITE)
	_apply_mode()


func _apply_mode() -> void:
	heroes.clear()
	for d in all_heroes:
		var hid := str(d.get("id", ""))
		if mode_5v5 or BASE_HERO_IDS.has(hid):
			heroes.append(d)
	sel_index = clampi(sel_index, 0, maxi(0, heroes.size() - 1))
	detail_open = false


# ---- 布局 ----

func _title_rect() -> Rect2:
	var safe := _safe()
	return Rect2(safe.position.x, safe.position.y + safe.size.y * 0.055,
		safe.size.x, safe.size.y * 0.145)


func _grid_rect() -> Rect2:
	var safe := _safe()
	return Rect2(safe.position.x + safe.size.x * 0.05, safe.position.y + safe.size.y * 0.245,
		safe.size.x * 0.90, safe.size.y * 0.49)


func card_rect(i: int) -> Rect2:
	var g := _grid_rect()
	var cols := 5
	var rows := int(ceil(float(heroes.size()) / float(cols)))
	var gap := g.size.x * 0.010
	var cw := (g.size.x - gap * float(cols - 1)) / float(cols)
	var ch := (g.size.y - gap * float(maxi(1, rows - 1))) / float(maxi(1, rows))
	var col := i % cols
	var row := i / cols
	return Rect2(g.position + Vector2(float(col) * (cw + gap), float(row) * (ch + gap)), Vector2(cw, ch))


func mode3_rect() -> Rect2:
	var safe := _safe()
	return Rect2(safe.position.x + safe.size.x * 0.06, safe.end.y - safe.size.y * 0.255,
		safe.size.x * 0.095, safe.size.y * 0.060)


func mode5_rect() -> Rect2:
	var r := mode3_rect()
	return Rect2(r.end.x + 10.0, r.position.y, r.end.x - r.position.x, r.size.y)


func easy_rect() -> Rect2:
	var safe := _safe()
	return Rect2(safe.position.x + safe.size.x * 0.06, safe.end.y - safe.size.y * 0.155,
		safe.size.x * 0.13, safe.size.y * 0.082)


func challenge_rect() -> Rect2:
	var r := easy_rect()
	return Rect2(r.end.x + 10.0, r.position.y, r.size.x, r.size.y)


func start_rect() -> Rect2:
	var safe := _safe()
	return Rect2(safe.end.x - safe.size.x * 0.255, safe.end.y - safe.size.y * 0.165,
		safe.size.x * 0.205, safe.size.y * 0.10)


func detail_rect() -> Rect2:
	var safe := _safe()
	var w := safe.size.x * 0.76
	var h := safe.size.y * 0.68
	return Rect2(safe.position.x + (safe.size.x - w) * 0.5,
		safe.position.y + safe.size.y * 0.13, w, h)


func detail_portrait_rect() -> Rect2:
	var d := detail_rect()
	var side := minf(d.size.x * 0.30, d.size.y * 0.58)
	return Rect2(d.position.x + d.size.x * 0.035, d.position.y + d.size.y * 0.13,
		side, side)


func detail_text_x() -> float:
	var d := detail_rect()
	return detail_portrait_rect().end.x + d.size.x * 0.035


func detail_skill_rect(i: int) -> Rect2:
	var d := detail_rect()
	var x := detail_text_x()
	var w := d.end.x - x - d.size.x * 0.035
	var rh := d.size.y * 0.125
	return Rect2(x, d.position.y + d.size.y * (0.42 + float(i) * 0.145), w, rh)


func detail_close_rect() -> Rect2:
	var d := detail_rect()
	return Rect2(d.end.x - d.size.x * 0.105, d.position.y + d.size.y * 0.035,
		d.size.x * 0.075, d.size.y * 0.060)


func detail_start_rect() -> Rect2:
	var d := detail_rect()
	return Rect2(d.end.x - d.size.x * 0.235, d.end.y - d.size.y * 0.135,
		d.size.x * 0.195, d.size.y * 0.090)


# ---- 文本 ----

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
	add_child(l)
	return l


func _make_labels() -> void:
	var h := _safe().size.y
	lbl_title = _mk_label(int(h * 0.072), GOLD)
	lbl_sub = _mk_label(int(h * 0.026), Color(1, 0.97, 0.88, 0.92))
	lbl_start = _mk_label(int(h * 0.040), INK)
	lbl_easy = _mk_label(int(h * 0.028), INK)
	lbl_challenge = _mk_label(int(h * 0.028), INK)
	lbl_mode3 = _mk_label(int(h * 0.022), INK)
	lbl_mode5 = _mk_label(int(h * 0.022), INK)
	lbl_hint = _mk_label(int(h * 0.021), Color(1, 1, 1, 0.72))
	lbl_foot = _mk_label(int(h * 0.018), Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_RIGHT)
	for i in range(all_heroes.size()):
		hero_name_labels.append(_mk_label(int(h * 0.028), CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		var blurb := _mk_label(int(h * 0.018), Color(0.92, 0.96, 0.90, 0.82), HORIZONTAL_ALIGNMENT_LEFT)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hero_blurb_labels.append(blurb)

	# 详情弹窗文字：人物标题 / 定位 / 介绍 / 三技能。
	lbl_detail_name = _mk_label(int(h * 0.042), GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_detail_sub = _mk_label(int(h * 0.024), CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_detail_blurb = _mk_label(int(h * 0.022), Color(0.95, 0.98, 0.92, 0.88), HORIZONTAL_ALIGNMENT_LEFT)
	lbl_detail_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_detail_tip = _mk_label(int(h * 0.019), Color(1, 0.94, 0.78, 0.62), HORIZONTAL_ALIGNMENT_LEFT)
	lbl_detail_close = _mk_label(int(h * 0.024), CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_detail_start = _mk_label(int(h * 0.035), INK, HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(3):
		detail_skill_names.append(_mk_label(int(h * 0.028), GOLD, HORIZONTAL_ALIGNMENT_LEFT))
		var hint := _mk_label(int(h * 0.020), Color(0.93, 0.97, 0.91, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_skill_hints.append(hint)
		detail_skill_meta.append(_mk_label(int(h * 0.018), Color(0.82, 0.96, 0.88, 0.72),
			HORIZONTAL_ALIGNMENT_RIGHT))


func _place(l: Label, r: Rect2) -> void:
	l.position = r.position
	l.size = r.size


func _refresh_labels() -> void:
	var safe := _safe()
	var h := safe.size.y
	_place(lbl_title, Rect2(safe.position.x, safe.position.y + h * 0.035, safe.size.x, h * 0.095))
	lbl_title.text = "萌兽峡谷"
	_place(lbl_sub, Rect2(safe.position.x, safe.position.y + h * 0.135, safe.size.x, h * 0.040))
	lbl_sub.text = "选一只小动物 · 点开卡片看技能 · 推掉对面的蘑菇塔"

	for i in range(heroes.size()):
		var d: Dictionary = heroes[i]
		var card := card_rect(i)
		var pad := card.size.y * 0.055
		var av := minf(card.size.x - pad * 2.0, card.size.y * 0.66)
		_place(hero_name_labels[i], Rect2(card.position.x, card.position.y + av + pad * 0.7,
			card.size.x, card.size.y * 0.19))
		hero_name_labels[i].text = "%s · %s" % [str(d.get("name", "?")), str(d.get("role", ""))]
		hero_name_labels[i].add_theme_color_override("font_color",
			GOLD if i == sel_index else CREAM)
		hero_blurb_labels[i].visible = false
	for i in range(heroes.size(), hero_name_labels.size()):
		hero_name_labels[i].visible = false

	_place(lbl_mode3, mode3_rect())
	lbl_mode3.text = "3v3"
	lbl_mode3.add_theme_color_override("font_color", INK if not mode_5v5 else CREAM)
	_place(lbl_mode5, mode5_rect())
	lbl_mode5.text = "5v5"
	lbl_mode5.add_theme_color_override("font_color", INK if mode_5v5 else CREAM)
	_place(lbl_easy, easy_rect())
	lbl_easy.text = "轻松"
	lbl_easy.add_theme_color_override("font_color", INK if difficulty == 0 else CREAM)
	_place(lbl_challenge, challenge_rect())
	lbl_challenge.text = "挑战"
	lbl_challenge.add_theme_color_override("font_color", INK if difficulty == 1 else CREAM)
	_place(lbl_start, start_rect())
	lbl_start.text = "开始冒险"
	_place(lbl_hint, Rect2(safe.position.x + safe.size.x * 0.06, easy_rect().end.y + 6.0,
		safe.size.x * 0.38, h * 0.034))
	lbl_hint.text = ("5v5 三路：多 5 位英雄 + 野区" if mode_5v5 else "3v3 单路：10 位英雄") + 		(" · 轻松" if difficulty == 0 else " · 挑战")
	_place(lbl_foot, Rect2(safe.end.x - safe.size.x * 0.30, safe.end.y - h * 0.045,
		safe.size.x * 0.26, h * 0.032))
	lbl_foot.text = "v%s · Godot" % str(ProjectSettings.get_setting("application/config/version", "dev"))

	var dsel: Dictionary = heroes[sel_index]
	var dr := detail_rect()
	var pr := detail_portrait_rect()
	var tx := detail_text_x()
	var right_w := dr.end.x - tx - dr.size.x * 0.035
	_place(lbl_detail_name, Rect2(tx, dr.position.y + dr.size.y * 0.045, right_w, h * 0.055))
	lbl_detail_name.text = "%s · %s" % [str(dsel.get("name", "?")), str(dsel.get("title", ""))]
	_place(lbl_detail_sub, Rect2(tx, dr.position.y + dr.size.y * 0.115, right_w, h * 0.035))
	lbl_detail_sub.text = "%s · 生命 %d · 攻击 %d · 射程 %d" % [
		str(dsel.get("role", "")), int(dsel.get("hp", 0)), int(dsel.get("dmg", 0)),
		int(dsel.get("range", 0))]
	_place(lbl_detail_blurb, Rect2(tx, dr.position.y + dr.size.y * 0.165, right_w, h * 0.052))
	lbl_detail_blurb.text = str(dsel.get("blurb", ""))
	_place(lbl_detail_tip, Rect2(tx, dr.end.y - h * 0.045, right_w * 0.55, h * 0.030))
	lbl_detail_tip.text = "关闭后可点其他卡片 · 开始后进入 %s" % ("5v5 三路" if mode_5v5 else "3v3 单路")

	var skills: Array = dsel.get("skills", [])
	for i in range(3):
		if i < skills.size():
			var s: Dictionary = skills[i]
			var r := detail_skill_rect(i)
			var icon_w := r.size.y * 0.72
			var sx := r.position.x + icon_w + r.size.y * 0.18
			var text_w := r.end.x - sx - r.size.x * 0.03
			_place(detail_skill_names[i], Rect2(sx, r.position.y + 2.0, text_w * 0.72, r.size.y * 0.40))
			detail_skill_names[i].text = str(s.get("name", ""))
			_place(detail_skill_hints[i], Rect2(sx, r.position.y + r.size.y * 0.42, text_w, r.size.y * 0.52))
			detail_skill_hints[i].text = str(s.get("hint", ""))
			_place(detail_skill_meta[i], Rect2(r.end.x - r.size.x * 0.27, r.position.y,
				r.size.x * 0.25, r.size.y * 0.40))
			detail_skill_meta[i].text = "2 级解锁" if s.get("unlock_at_2", false) else "冷却 %s 秒" % str(s.get("cd", "?"))
			for l in [detail_skill_names[i], detail_skill_hints[i], detail_skill_meta[i]]:
				l.visible = detail_open
		else:
			for l in [detail_skill_names[i], detail_skill_hints[i], detail_skill_meta[i]]:
				l.visible = false

	_place(lbl_detail_close, detail_close_rect())
	lbl_detail_close.text = "返回"
	_place(lbl_detail_start, detail_start_rect())
	lbl_detail_start.text = "带它出发"

	var main_visible := not detail_open
	for l in [lbl_title, lbl_sub, lbl_start, lbl_easy, lbl_challenge, lbl_mode3, lbl_mode5, lbl_hint, lbl_foot]:
		l.visible = main_visible
	for l in hero_name_labels:
		l.visible = main_visible
	for l in [lbl_detail_name, lbl_detail_sub, lbl_detail_blurb, lbl_detail_tip,
			lbl_detail_close, lbl_detail_start]:
		l.visible = detail_open


# ---- 绘制 ----

func _draw() -> void:
	var vp := viewport_size()
	var horizon := vp.y * 0.70
	# 粉彩渐变天空：顶部青蓝 → 地平线近白，贴合参考图的柔和背景。
	for i in range(6):
		var t := float(i) / 5.0
		draw_rect(Rect2(0, horizon * t, vp.x, horizon / 5.0 + 1.0), SKY.lerp(Color("e6f7fd"), t))
	draw_rect(Rect2(0, horizon, vp.x, vp.y - horizon), GRASS)
	draw_rect(Rect2(0, horizon - 8.0, vp.x, 8.0), Color("5f9e45"))
	for i in range(7):
		var cx := vp.x * (0.06 + float(i) * 0.145)
		var cy := vp.y * (0.10 + float(i % 3) * 0.035)
		draw_rect(Rect2(cx, cy, vp.x * 0.075, vp.y * 0.035), Color(1, 1, 1, 0.75))
		draw_rect(Rect2(cx + vp.x * 0.018, cy - vp.y * 0.022, vp.x * 0.042, vp.y * 0.025),
			Color(1, 1, 1, 0.75))
	# 底部草方块装饰
	for i in range(10):
		var bx := vp.x * (0.03 + float(i) * 0.10)
		var by := horizon + vp.y * (0.03 + float(i % 2) * 0.04)
		draw_rect(Rect2(bx, by, vp.x * 0.035, vp.y * 0.03), Color("6fb84f"))
		draw_rect(Rect2(bx, by, vp.x * 0.035, vp.y * 0.008), Color("7fbf5a"))

	var safe := _safe()
	var tr := _title_rect()
	_panel(Rect2(tr.position.x + safe.size.x * 0.22, tr.position.y, safe.size.x * 0.56,
		tr.size.y * 0.62), PANEL_FILL)

	for i in range(heroes.size()):
		var card := card_rect(i)
		var selected := i == sel_index
		_panel(card, Color("2f4038") if selected else PANEL_DEEP)
		if selected:
			_outline(card, GOLD, 4.0)
		var d: Dictionary = heroes[i]
		var pad := card.size.y * 0.055
		var av := minf(card.size.x - pad * 2.0, card.size.y * 0.66)
		var ar := Rect2(card.get_center().x - av * 0.5, card.position.y + pad, av, av)
		draw_rect(Rect2(ar.position - Vector2(4, 4), ar.size + Vector2(8, 8)), PANEL_DARK)
		var portrait: Texture2D = portraits.portrait(str(d.get("id", "tiger")),
			d.get("fur_c", Color.WHITE), d.get("cream_c", Color.WHITE),
			d.get("dark_c", Color.BLACK), d.get("accent_c", Color.WHITE))
		draw_texture_rect(portrait, ar, false)
		_outline(Rect2(ar.position - Vector2(2, 2), ar.size + Vector2(4, 4)),
			GOLD if selected else Color(0.86, 0.93, 0.84, 0.35), 2.0)
		# 卡底职业色条
		draw_rect(Rect2(card.position.x + 8, card.end.y - 8, card.size.x - 16, 3),
			d.get("accent_c", GOLD))

	var start := start_rect()
	draw_rect(start, GOLD)
	_outline(start, PANEL_DARK, 4.0)
	draw_rect(Rect2(start.position + Vector2(4, 4), Vector2(start.size.x - 8, 3)),
		Color(1, 1, 1, 0.45))
	var play_c := Vector2(start.position.x + start.size.x * 0.10, start.get_center().y)
	var tri := PackedVector2Array([
		play_c + Vector2(-8, -11), play_c + Vector2(-8, 11), play_c + Vector2(12, 0),
	])
	draw_colored_polygon(tri, PANEL_DARK)

	var m3 := mode3_rect()
	draw_rect(m3, GOLD if not mode_5v5 else Color("4a5a50"))
	_outline(m3, PANEL_DARK, 3.0)
	var m5 := mode5_rect()
	draw_rect(m5, GOLD if mode_5v5 else Color("4a5a50"))
	_outline(m5, PANEL_DARK, 3.0)
	var er := easy_rect()
	draw_rect(er, GOLD if difficulty == 0 else Color("4a5a50"))
	_outline(er, PANEL_DARK, 3.0)
	var cr := challenge_rect()
	draw_rect(cr, GOLD if difficulty == 1 else Color("4a5a50"))
	_outline(cr, PANEL_DARK, 3.0)

	if detail_open:
		_draw_detail()


func _draw_detail() -> void:
	var vp := viewport_size()
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.05, 0.04, 0.76))
	var d := detail_rect()
	_panel(d, PANEL_FILL)
	_outline(d, GOLD, 3.0)

	var dsel: Dictionary = heroes[sel_index]
	var pr := detail_portrait_rect()
	draw_rect(Rect2(pr.position - Vector2(7, 7), pr.size + Vector2(14, 14)), PANEL_DARK)
	draw_rect(Rect2(pr.position - Vector2(4, 4), pr.size + Vector2(8, 8)),
		Color(1.0, 0.86, 0.46, 0.40))
	var portrait: Texture2D = portraits.portrait(str(dsel.get("id", "tiger")),
		dsel.get("fur_c", Color.WHITE), dsel.get("cream_c", Color.WHITE),
		dsel.get("dark_c", Color.BLACK), dsel.get("accent_c", Color.WHITE))
	draw_texture_rect(portrait, pr, false)
	_outline(pr, GOLD, 3.0)

	var tx := detail_text_x()
	draw_rect(Rect2(tx - 10, d.position.y + d.size.y * 0.04, 3,
		d.size.y * 0.56), Color(0.95, 0.84, 0.54, 0.55))

	var skills: Array = dsel.get("skills", [])
	for i in range(3):
		var r := detail_skill_rect(i)
		draw_rect(r, Color(0.10, 0.20, 0.17, 0.92))
		_outline(r, Color(0.72, 0.82, 0.70, 0.22), 1.0)
		if i < skills.size():
			var s: Dictionary = skills[i]
			var isz := r.size.y * 0.72
			var ir := Rect2(r.position.x + r.size.y * 0.12, r.position.y + (r.size.y - isz) * 0.5,
				isz, isz)
			var sc: Color = Color.from_string(str(s.get("color", "#FFFFFF")), GOLD)
			draw_circle(ir.get_center(), isz * 0.58, Color(sc.r, sc.g, sc.b, 0.22))
			draw_texture_rect(icons.tex("skill_" + str(s.get("kind", "aoe"))), ir, false)

	var close := detail_close_rect()
	draw_rect(close, PANEL_DEEP)
	_outline(close, Color(0.80, 0.86, 0.76, 0.42), 2.0)
	var go := detail_start_rect()
	draw_rect(go, GOLD)
	_outline(go, PANEL_DARK, 3.0)
	draw_rect(Rect2(go.position + Vector2(5, 4), Vector2(go.size.x - 10, 3)),
		Color(1, 1, 1, 0.45))


func _panel(r: Rect2, fill: Color) -> void:
	draw_rect(r, fill)
	_outline(r, PANEL_LIGHT, 2.0)
	draw_rect(Rect2(r.position.x + 2, r.end.y - 4, r.size.x - 4, 2), PANEL_DARK)
	draw_rect(Rect2(r.end.x - 4, r.position.y + 2, 2, r.size.y - 4), PANEL_DARK)


func _outline(r: Rect2, c: Color, t: float) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, t), c)
	draw_rect(Rect2(r.position.x, r.end.y - t, r.size.x, t), c)
	draw_rect(Rect2(r.position.x, r.position.y, t, r.size.y), c)
	draw_rect(Rect2(r.end.x - t, r.position.y, t, r.size.y), c)


# ---- 输入 ----

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Android 上鼠标事件是从触摸模拟出来的，坐标空间可能不同，直接忽略。
		if OS.get_name() != "Android":
			_tap(event.position)


func _tap(pos: Vector2) -> void:
	# 同一次物理触摸可能同时产生触摸与模拟鼠标事件，同一帧只处理一次。
	var frame := Engine.get_process_frames()
	if frame == last_tap_frame:
		return
	last_tap_frame = frame
	print("[HOME] tap=(%.0f,%.0f) sel=%d" % [pos.x, pos.y, sel_index])

	if detail_open:
		if detail_close_rect().has_point(pos) or not detail_rect().has_point(pos):
			detail_open = false
			ui_click.emit()
			_refresh_labels()
			queue_redraw()
			return
		if detail_start_rect().has_point(pos):
			ui_click.emit()
			start_requested.emit(str(heroes[sel_index].get("id", "tiger")), difficulty, mode_5v5)
			return
		# 弹窗内的技能区不响应点击，避免误触关闭。
		return

	for i in range(heroes.size()):
		if card_rect(i).has_point(pos):
			if sel_index != i:
				sel_index = i
				ui_click.emit()
			detail_open = true
			_refresh_labels()
			queue_redraw()
			return

	if mode3_rect().has_point(pos):
		if mode_5v5:
			mode_5v5 = false
			_apply_mode()
			ui_click.emit()
			_refresh_labels()
			queue_redraw()
		return
	if mode5_rect().has_point(pos):
		if not mode_5v5:
			mode_5v5 = true
			_apply_mode()
			ui_click.emit()
			_refresh_labels()
			queue_redraw()
		return
	if easy_rect().has_point(pos):
		if difficulty != 0:
			difficulty = 0
			ui_click.emit()
			_refresh_labels()
			queue_redraw()
		return
	if challenge_rect().has_point(pos):
		if difficulty != 1:
			difficulty = 1
			ui_click.emit()
			_refresh_labels()
			queue_redraw()
		return
	if start_rect().has_point(pos):
		ui_click.emit()
		start_requested.emit(str(heroes[sel_index].get("id", "tiger")), difficulty, mode_5v5)

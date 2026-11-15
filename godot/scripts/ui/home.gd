class_name Home
extends Control

# 像素风首页：标题、6 只英雄选人卡片、难度切换、开始按钮。
# 全部用 Godot 原生绘制与 Label，不依赖外部图片。

signal start_requested(hero_id: String, difficulty: int)
signal ui_click

const GOLD := Color("f5c542")
const CREAM := Color("f5eedc")
const PANEL_FILL := Color("2b3531")
const PANEL_DEEP := Color("1f2824")
const PANEL_LIGHT := Color("e8e0cf")
const PANEL_DARK := Color("0f1512")
const INK := Color("221a12")
const GREEN := Color("5aa83c")
const SKY := Color("8ec9f0")
const GRASS := Color("6fae4e")

var heroes: Array = []
var sel_index := 0
var difficulty := 0
var font: Font = null
var icons = null

var lbl_title: Label
var lbl_sub: Label
var lbl_start: Label
var lbl_easy: Label
var lbl_challenge: Label
var lbl_foot: Label
var lbl_hint: Label
var hero_name_labels: Array = []
var hero_blurb_labels: Array = []

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
	_load_heroes()
	_make_labels()
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
	heroes = parsed.get("heroes", [])
	for d in heroes:
		d["fur_c"] = Color.from_string(str(d.get("fur", "#FFFFFF")), Color.WHITE)
		d["dark_c"] = Color.from_string(str(d.get("dark", "#000000")), Color.BLACK)
		d["cream_c"] = Color.from_string(str(d.get("cream", "#FFFFFF")), Color.WHITE)
		d["accent_c"] = Color.from_string(str(d.get("accent", "#FFFFFF")), Color.WHITE)


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
	var gap := g.size.x * 0.012
	var cw := (g.size.x - gap * 2.0) / 3.0
	var ch := (g.size.y - gap) / 2.0
	var col := i % 3
	var row := i / 3
	return Rect2(g.position + Vector2(float(col) * (cw + gap), float(row) * (ch + gap)), Vector2(cw, ch))


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
	lbl_hint = _mk_label(int(h * 0.021), Color(1, 1, 1, 0.72))
	lbl_foot = _mk_label(int(h * 0.018), Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_RIGHT)
	for i in range(heroes.size()):
		hero_name_labels.append(_mk_label(int(h * 0.031), CREAM, HORIZONTAL_ALIGNMENT_LEFT))
		var blurb := _mk_label(int(h * 0.020), Color(0.92, 0.96, 0.90, 0.82), HORIZONTAL_ALIGNMENT_LEFT)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hero_blurb_labels.append(blurb)


func _place(l: Label, r: Rect2) -> void:
	l.position = r.position
	l.size = r.size


func _refresh_labels() -> void:
	var safe := _safe()
	var h := safe.size.y
	_place(lbl_title, Rect2(safe.position.x, safe.position.y + h * 0.035, safe.size.x, h * 0.095))
	lbl_title.text = "萌兽峡谷"
	_place(lbl_sub, Rect2(safe.position.x, safe.position.y + h * 0.135, safe.size.x, h * 0.040))
	lbl_sub.text = "选一只小动物 · 推掉对面的蘑菇塔 · 点亮水晶"

	for i in range(heroes.size()):
		var d: Dictionary = heroes[i]
		var card := card_rect(i)
		var pad := card.size.y * 0.10
		var av := card.size.y - pad * 2.0
		var tx := card.position.x + av + pad * 1.6
		var tw := card.end.x - tx - pad
		_place(hero_name_labels[i], Rect2(tx, card.position.y + pad, tw, card.size.y * 0.34))
		hero_name_labels[i].text = "%s · %s" % [str(d.get("name", "?")), str(d.get("role", ""))]
		hero_name_labels[i].add_theme_color_override("font_color",
			GOLD if i == sel_index else CREAM)
		_place(hero_blurb_labels[i], Rect2(tx, card.position.y + card.size.y * 0.46, tw,
			card.size.y * 0.42))
		hero_blurb_labels[i].text = str(d.get("blurb", ""))

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
	lbl_hint.text = "轻松：电脑更慢，适合第一次玩" if difficulty == 0 else "挑战：电脑更凶，会抢技能"
	_place(lbl_foot, Rect2(safe.end.x - safe.size.x * 0.30, safe.end.y - h * 0.045,
		safe.size.x * 0.26, h * 0.032))
	lbl_foot.text = "v4.2.1-dev.1 · Godot"


# ---- 绘制 ----

func _draw() -> void:
	var vp := viewport_size()
	draw_rect(Rect2(Vector2.ZERO, vp), SKY)
	var horizon := vp.y * 0.70
	draw_rect(Rect2(0, horizon, vp.x, vp.y - horizon), GRASS)
	draw_rect(Rect2(0, horizon - 8.0, vp.x, 8.0), Color("5d9a42"))
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
		draw_rect(Rect2(bx, by, vp.x * 0.035, vp.y * 0.03), Color("4f8f3f"))
		draw_rect(Rect2(bx, by, vp.x * 0.035, vp.y * 0.008), Color("7fbf5a"))

	var safe := _safe()
	var tr := _title_rect()
	_panel(Rect2(tr.position.x + safe.size.x * 0.22, tr.position.y, safe.size.x * 0.56,
		tr.size.y * 0.62), PANEL_FILL)

	for i in range(heroes.size()):
		var card := card_rect(i)
		var selected := i == sel_index
		_panel(card, PANEL_DEEP if not selected else Color("34463c"))
		if selected:
			_outline(card, GOLD, 4.0)
		var d: Dictionary = heroes[i]
		var pad := card.size.y * 0.10
		var av := card.size.y - pad * 2.0
		var ar := Rect2(card.position.x + pad, card.position.y + pad, av, av)
		draw_rect(Rect2(ar.position - Vector2(3, 3), ar.size + Vector2(6, 6)), PANEL_DARK)
		var portrait: Texture2D = icons.hero_portrait(str(d.get("id", "tiger")),
			d.get("fur_c", Color.WHITE), d.get("cream_c", Color.WHITE),
			d.get("dark_c", Color.BLACK), d.get("accent_c", Color.WHITE))
		draw_texture_rect(portrait, ar, false)

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

	var er := easy_rect()
	draw_rect(er, GOLD if difficulty == 0 else Color("4a5a50"))
	_outline(er, PANEL_DARK, 3.0)
	var cr := challenge_rect()
	draw_rect(cr, GOLD if difficulty == 1 else Color("4a5a50"))
	_outline(cr, PANEL_DARK, 3.0)


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

	for i in range(heroes.size()):
		if card_rect(i).has_point(pos):
			if sel_index != i:
				sel_index = i
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
		start_requested.emit(str(heroes[sel_index].get("id", "tiger")), difficulty)

class_name PixelIcons
extends RefCounted

# 16×16 像素图标：用掩膜（mask）拼形状，再自动描 1px 深色边，保证全套图标风格一致。
# 同时提供 5×7 像素数字，供 HUD 用矩形批绘制，不额外增加绘制调用。

const S := 16
const OUTLINE := Color("221a12")

const INK := Color("3a2a1e")
const CREAM := Color("f5eedc")
const GRAY := Color("9aa39a")
const DARKGRAY := Color("5f6b62")
const RED := Color("e0523c")
const ORANGE := Color("f0902f")
const YELLOW := Color("f5c542")
const GREEN := Color("5aa83c")
const DGREEN := Color("2f6b2a")
const BLUE := Color("4fa8e0")
const DBLUE := Color("2f6fa8")
const ICE := Color("9fe8f0")
const PURPLE := Color("9a6ad0")
const PINK := Color("f09ac0")
const BROWN := Color("8a5a3b")

var _cache: Dictionary = {}


func _init() -> void:
	_build_common()


func tex(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	if name.begins_with("hero_"):
		push_warning("缺少英雄头像：" + name)
	if name.begins_with("skill_"):
		return tex("skill_aoe")
	return tex("ui_star")


func hero_portrait(hero_id: String, fur: Color, cream: Color, dark: Color, accent: Color, with_bg := true) -> ImageTexture:
	var key := "hero_" + hero_id + ("" if with_bg else "_nobg")
	if _cache.has(key):
		return _cache[key]
	var ops: Array = []
	if with_bg:
		_portrait_bg(ops, dark)
	# 人形半身像：肩膀衣服 + 脖子 + 头 + 动物耳/面部涂装 + 眼睛
	_add(ops, _rect_mask(3, 12, 10, 4), accent)
	_add(ops, _rect_mask(7, 10, 2, 3), _lighter_col(fur, 0.08))
	_add(ops, _rect_mask(4, 3, 8, 9), fur)
	_add(ops, _rect_mask(4, 3, 8, 1), _lighter_col(fur, 0.12))
	match hero_id:
		"tiger":
			_add(ops, _rect_mask(4, 1, 2, 2), fur)
			_add(ops, _rect_mask(10, 1, 2, 2), fur)
			_add(ops, _rect_mask(6, 3, 1, 2), dark)
			_add(ops, _rect_mask(9, 3, 1, 2), dark)
			_add(ops, _rect_mask(4, 7, 1, 2), dark)
			_add(ops, _rect_mask(11, 7, 1, 2), dark)
			_add(ops, _rect_mask(5, 9, 6, 3), cream)
			_add(ops, _rect_mask(7, 9, 2, 2), dark)
			_add(ops, _rect_mask(7, 13, 2, 2), cream)
		"fox":
			_add(ops, _poly_mask([Vector2(4, 4), Vector2(4.6, 0), Vector2(7, 3)]), fur)
			_add(ops, _poly_mask([Vector2(12, 4), Vector2(11.4, 0), Vector2(9, 3)]), fur)
			_add(ops, _rect_mask(4, 9, 8, 3), cream)
			_add(ops, _rect_mask(5, 6, 2, 2), dark)
			_add(ops, _rect_mask(9, 6, 2, 2), dark)
			_add(ops, _rect_mask(7, 9, 2, 2), dark)
			_add(ops, _diamond_mask(8, 13, 2), YELLOW)
		"rabbit":
			_add(ops, _rect_mask(5, 0, 2, 5), cream)
			_add(ops, _rect_mask(9, 0, 2, 5), cream)
			_add(ops, _rect_mask(5, 1, 1, 3), PINK)
			_add(ops, _rect_mask(9, 1, 1, 3), PINK)
			_add(ops, _rect_mask(5, 6, 2, 2), dark)
			_add(ops, _rect_mask(9, 6, 2, 2), dark)
			_add(ops, _rect_mask(6, 9, 4, 3), cream)
			_add(ops, _rect_mask(7, 9, 2, 2), PINK)
			_add(ops, _rect_mask(7, 13, 2, 2), cream)
		"bear":
			_add(ops, _disc_mask(4.0, 3.6, 2.2), dark)
			_add(ops, _disc_mask(12.0, 3.6, 2.2), dark)
			_add(ops, _rect_mask(4, 5, 3, 3), cream)
			_add(ops, _rect_mask(9, 5, 3, 3), cream)
			_add(ops, _rect_mask(5, 6, 2, 2), dark)
			_add(ops, _rect_mask(9, 6, 2, 2), dark)
			_add(ops, _rect_mask(5, 9, 6, 3), cream)
			_add(ops, _rect_mask(7, 9, 2, 2), dark)
			_add(ops, _rect_mask(4, 13, 2, 2), cream)
			_add(ops, _rect_mask(10, 13, 2, 2), cream)
		"frog":
			_add(ops, _rect_mask(2, 5, 12, 7), fur)
			_add(ops, _disc_mask(4.5, 4.5, 3.0), cream)
			_add(ops, _disc_mask(11.5, 4.5, 3.0), cream)
			_add(ops, _rect_mask(3, 4, 2, 3), dark)
			_add(ops, _rect_mask(10, 4, 2, 3), dark)
			_add(ops, _rect_mask(4, 10, 8, 2), dark)
			_add(ops, _rect_mask(2, 12, 12, 4), accent)
		"cat":
			_add(ops, _poly_mask([Vector2(4, 4), Vector2(4.8, 0), Vector2(7, 3)]), fur)
			_add(ops, _poly_mask([Vector2(12, 4), Vector2(11.2, 0), Vector2(9, 3)]), fur)
			_add(ops, _poly_mask([Vector2(4.6, 3.4), Vector2(4.9, 1.2), Vector2(6.2, 3)]), accent)
			_add(ops, _poly_mask([Vector2(11.4, 3.4), Vector2(11.1, 1.2), Vector2(9.8, 3)]), accent)
			_add(ops, _rect_mask(5, 6, 2, 2), dark)
			_add(ops, _rect_mask(9, 6, 2, 2), dark)
			_add(ops, _rect_mask(7, 9, 2, 2), PINK)
			_add(ops, _rect_mask(2, 9, 2, 1), cream)
			_add(ops, _rect_mask(2, 11, 2, 1), cream)
			_add(ops, _rect_mask(12, 9, 2, 1), cream)
			_add(ops, _rect_mask(12, 11, 2, 1), cream)
		"panda":
			_add(ops, _disc_mask(4.4, 3.4, 2.3), dark)
			_add(ops, _disc_mask(11.6, 3.4, 2.3), dark)
			_add(ops, _rect_mask(4, 5, 4, 4), dark)
			_add(ops, _rect_mask(8, 5, 4, 4), dark)
			_add(ops, _rect_mask(5, 6, 2, 2), cream)
			_add(ops, _rect_mask(9, 6, 2, 2), cream)
			_add(ops, _rect_mask(6, 9, 4, 3), cream)
			_add(ops, _rect_mask(7, 9, 2, 2), Color("1a1a1a"))
			_add(ops, _rect_mask(2, 13, 12, 3), accent)
		"owl":
			_add(ops, _poly_mask([Vector2(4.4, 4), Vector2(4.8, 0), Vector2(7, 3)]), dark)
			_add(ops, _poly_mask([Vector2(11.6, 4), Vector2(11.2, 0), Vector2(9, 3)]), dark)
			_add(ops, _disc_mask(5.2, 5.6, 2.8), cream)
			_add(ops, _disc_mask(10.8, 5.6, 2.8), cream)
			_add(ops, _rect_mask(4, 5, 2, 2), dark)
			_add(ops, _rect_mask(10, 5, 2, 2), dark)
			_add(ops, _poly_mask([Vector2(6.5, 8), Vector2(9.5, 8), Vector2(8, 11)]), accent)
			_add(ops, _rect_mask(4, 12, 8, 4), cream)
			_add(ops, _diamond_mask(8, 14, 2), accent)
		_:
			_add(ops, _rect_mask(5, 6, 2, 2), dark)
			_add(ops, _rect_mask(9, 6, 2, 2), dark)
			_add(ops, _rect_mask(5, 9, 6, 3), cream)
	if with_bg:
		_add(ops, _rect_mask(1, 1, 1, 14), accent)
	var t := _compose(ops)
	_cache[key] = t
	return t


func _lighter_col(c: Color, k: float) -> Color:
	return Color(minf(1.0, c.r + k), minf(1.0, c.g + k), minf(1.0, c.b + k), c.a)


func _build_common() -> void:
	# 技能图标
	_cache["skill_dash"] = _make_dash()
	_cache["skill_aoe"] = _make_aoe()
	_cache["skill_splash"] = _make_splash()
	_cache["skill_cone"] = _make_cone()
	_cache["skill_heal"] = _make_heal()
	_cache["skill_shield"] = _make_shield()
	_cache["skill_pull"] = _make_pull()
	_cache["skill_leap"] = _make_leap()
	_cache["skill_multi"] = _make_multi()
	_cache["skill_radial"] = _make_radial()
	_cache["skill_projectile"] = _make_projectile()
	# 界面图标
	_cache["ui_heart"] = _make_heart()
	_cache["ui_sword"] = _make_sword()
	_cache["ui_clock"] = _make_clock()
	_cache["ui_tower"] = _make_tower()
	_cache["ui_gem"] = _make_gem()
	_cache["ui_star"] = _make_star()


func _make_dash() -> ImageTexture:
	var ops: Array = []
	_add(ops, _poly_mask([Vector2(2, 6), Vector2(9, 6), Vector2(9, 2), Vector2(15, 8),
		Vector2(9, 14), Vector2(9, 10), Vector2(2, 10)]), YELLOW)
	_add(ops, _rect_mask(0, 3, 3, 2), CREAM)
	_add(ops, _rect_mask(0, 11, 3, 2), CREAM)
	return _compose(ops)


func _make_aoe() -> ImageTexture:
	var ops: Array = []
	_add(ops, _ring_mask(8.0, 8.0, 7.0, 4.4), ICE)
	_add(ops, _disc_mask(8.0, 8.0, 2.6), BLUE)
	return _compose(ops)


func _make_splash() -> ImageTexture:
	var ops: Array = []
	_add(ops, _poly_mask([Vector2(8, 1), Vector2(12, 7), Vector2(13, 10), Vector2(11, 13),
		Vector2(8, 14), Vector2(5, 13), Vector2(3, 10), Vector2(4, 7)]), BLUE)
	_add(ops, _rect_mask(6, 6, 2, 5), ICE)
	_add(ops, _rect_mask(1, 11, 2, 2), ICE)
	_add(ops, _rect_mask(13, 11, 2, 2), ICE)
	return _compose(ops)


func _make_cone() -> ImageTexture:
	var ops: Array = []
	_add(ops, _poly_mask([Vector2(2, 3), Vector2(15, 8), Vector2(2, 13)]), ORANGE)
	_add(ops, _rect_mask(2, 7, 6, 2), YELLOW)
	return _compose(ops)


func _make_heal() -> ImageTexture:
	var ops: Array = []
	_add(ops, _rect_mask(6, 2, 4, 12), GREEN)
	_add(ops, _rect_mask(2, 6, 12, 4), GREEN)
	_add(ops, _rect_mask(7, 3, 2, 10), Color("8fe06a"))
	_add(ops, _rect_mask(3, 7, 10, 2), Color("8fe06a"))
	return _compose(ops)


func _make_shield() -> ImageTexture:
	var ops: Array = []
	_add(ops, _poly_mask([Vector2(8, 1), Vector2(14, 4), Vector2(13, 10), Vector2(8, 15),
		Vector2(3, 10), Vector2(2, 4)]), Color("c8d4dc"))
	_add(ops, _poly_mask([Vector2(8, 4), Vector2(11, 6), Vector2(10, 10), Vector2(8, 12),
		Vector2(6, 10), Vector2(5, 6)]), BLUE)
	return _compose(ops)


func _make_pull() -> ImageTexture:
	var ops: Array = []
	_add(ops, _rect_mask(3, 3, 4, 11), GRAY)
	_add(ops, _rect_mask(9, 3, 4, 11), GRAY)
	_add(ops, _rect_mask(3, 10, 10, 4), GRAY)
	_add(ops, _rect_mask(3, 3, 4, 3), RED)
	_add(ops, _rect_mask(9, 3, 4, 3), DBLUE)
	return _compose(ops)


func _make_leap() -> ImageTexture:
	var ops: Array = []
	_add(ops, _poly_mask([Vector2(8, 1), Vector2(13, 7), Vector2(10, 7), Vector2(10, 12),
		Vector2(6, 12), Vector2(6, 7), Vector2(3, 7)]), GREEN)
	_add(ops, _rect_mask(2, 14, 12, 2), DARKGRAY)
	return _compose(ops)


func _make_multi() -> ImageTexture:
	var ops: Array = []
	_add(ops, _diamond_mask(4, 5, 3), PURPLE)
	_add(ops, _diamond_mask(12, 5, 3), PURPLE)
	_add(ops, _diamond_mask(8, 12, 3), Color("c0a0f0"))
	return _compose(ops)


func _make_radial() -> ImageTexture:
	var ops: Array = []
	for k in range(8):
		var a := TAU * float(k) / 8.0
		var p := Vector2(8.0 + cos(a) * 6.2, 8.0 + sin(a) * 6.2)
		_add(ops, _line_mask(Vector2(8, 8), p, 2.4), YELLOW)
	_add(ops, _disc_mask(8.0, 8.0, 3.2), ORANGE)
	return _compose(ops)


func _make_projectile() -> ImageTexture:
	var ops: Array = []
	_add(ops, _poly_mask([Vector2(10, 1), Vector2(4, 9), Vector2(8, 9), Vector2(6, 15),
		Vector2(13, 7), Vector2(9, 7)]), YELLOW)
	return _compose(ops)


func _make_heart() -> ImageTexture:
	var ops: Array = []
	_add(ops, _disc_mask(5.4, 6.0, 3.2), RED)
	_add(ops, _disc_mask(10.6, 6.0, 3.2), RED)
	_add(ops, _poly_mask([Vector2(2.4, 7.0), Vector2(13.6, 7.0), Vector2(8.0, 14.5)]), RED)
	_add(ops, _rect_mask(4, 4, 2, 2), Color("ff8a74"))
	return _compose(ops)


func _make_sword() -> ImageTexture:
	var ops: Array = []
	_add(ops, _line_mask(Vector2(4, 12), Vector2(12, 4), 4.0), Color("d8e0e8"))
	_add(ops, _line_mask(Vector2(4, 12), Vector2(12, 4), 2.0), Color("ffffff"))
	_add(ops, _line_mask(Vector2(3, 9), Vector2(7, 13), 3.0), YELLOW)
	_add(ops, _line_mask(Vector2(2, 14), Vector2(5, 11), 3.0), BROWN)
	return _compose(ops)


func _make_clock() -> ImageTexture:
	var ops: Array = []
	_add(ops, _disc_mask(8.0, 8.0, 7.0), GRAY)
	_add(ops, _disc_mask(8.0, 8.0, 5.2), CREAM)
	_add(ops, _rect_mask(7, 4, 2, 5), INK)
	_add(ops, _rect_mask(8, 7, 4, 2), INK)
	return _compose(ops)


func _make_tower() -> ImageTexture:
	var ops: Array = []
	_add(ops, _rect_mask(3, 11, 10, 4), GRAY)
	_add(ops, _rect_mask(5, 6, 6, 6), GRAY)
	_add(ops, _rect_mask(3, 3, 2, 3), CREAM)
	_add(ops, _rect_mask(7, 3, 2, 3), CREAM)
	_add(ops, _rect_mask(11, 3, 2, 3), CREAM)
	_add(ops, _rect_mask(7, 8, 2, 3), Color("4a4a4a"))
	return _compose(ops)


func _make_gem() -> ImageTexture:
	var ops: Array = []
	_add(ops, _diamond_mask(8, 8, 7), ICE)
	_add(ops, _diamond_mask(8, 8, 4), BLUE)
	_add(ops, _rect_mask(6, 6, 2, 2), Color("ffffff"))
	return _compose(ops)


func _make_star() -> ImageTexture:
	var ops: Array = []
	_add(ops, _poly_mask([Vector2(8, 1), Vector2(10, 6), Vector2(15, 8), Vector2(10, 10),
		Vector2(8, 15), Vector2(6, 10), Vector2(1, 8), Vector2(6, 6)]), YELLOW)
	return _compose(ops)


func _portrait_bg(ops: Array, dark: Color) -> void:
	_add(ops, _rect_mask(0, 0, 16, 16), Color(dark.r * 0.32, dark.g * 0.32, dark.b * 0.32, 1.0))


# ---- 掩膜构造 ----

func _empty() -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(S * S)
	m.fill(0)
	return m


func _plot(m: PackedByteArray, x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= S or y >= S:
		return
	m[y * S + x] = 1


func _rect_mask(x0: int, y0: int, w: int, h: int) -> PackedByteArray:
	var m := _empty()
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_plot(m, x, y)
	return m


func _disc_mask(cx: float, cy: float, r: float) -> PackedByteArray:
	var m := _empty()
	for y in range(S):
		for x in range(S):
			var dx := float(x) + 0.5 - cx
			var dy := float(y) + 0.5 - cy
			if dx * dx + dy * dy <= r * r:
				_plot(m, x, y)
	return m


func _ring_mask(cx: float, cy: float, r_out: float, r_in: float) -> PackedByteArray:
	var m := _empty()
	for y in range(S):
		for x in range(S):
			var dx := float(x) + 0.5 - cx
			var dy := float(y) + 0.5 - cy
			var d := dx * dx + dy * dy
			if d <= r_out * r_out and d >= r_in * r_in:
				_plot(m, x, y)
	return m


func _poly_mask(pts: Array) -> PackedByteArray:
	var m := _empty()
	for y in range(S):
		for x in range(S):
			if _inside(Vector2(float(x) + 0.5, float(y) + 0.5), pts):
				_plot(m, x, y)
	return m


func _diamond_mask(cx: int, cy: int, r: int) -> PackedByteArray:
	var m := _empty()
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if absi(x - cx) + absi(y - cy) <= r:
				_plot(m, x, y)
	return m


func _line_mask(a: Vector2, b: Vector2, width: float) -> PackedByteArray:
	var m := _empty()
	var half := width * 0.5
	for y in range(S):
		for x in range(S):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			if _dist_to_segment(p, a, b) <= half:
				_plot(m, x, y)
	return m


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _inside(p: Vector2, pts: Array) -> bool:
	var inside := false
	var j := pts.size() - 1
	for i in range(pts.size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[j]
		if ((a.y > p.y) != (b.y > p.y)) and (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x):
			inside = not inside
		j = i
	return inside


func _add(ops: Array, mask: PackedByteArray, color: Color) -> void:
	ops.append({"mask": mask, "color": color})


func _compose(ops: Array) -> ImageTexture:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var union := _empty()
	for op in ops:
		var mask: PackedByteArray = op["mask"]
		for i in range(S * S):
			if mask[i] == 1:
				union[i] = 1

	for y in range(S):
		for x in range(S):
			var i := y * S + x
			if union[i] != 1:
				continue
			var color: Color = Color(0, 0, 0, 0)
			for op in ops:
				var mask: PackedByteArray = op["mask"]
				if mask[i] == 1:
					color = op["color"]
			img.set_pixel(x, y, color)

	for y in range(S):
		for x in range(S):
			var i := y * S + x
			if union[i] == 1:
				continue
			var near := false
			if x > 0 and union[i - 1] == 1:
				near = true
			if x < S - 1 and union[i + 1] == 1:
				near = true
			if y > 0 and union[i - S] == 1:
				near = true
			if y < S - 1 and union[i + S] == 1:
				near = true
			if near:
				img.set_pixel(x, y, OUTLINE)

	return ImageTexture.create_from_image(img)


# ---- 5×7 像素数字 ----

const DIGITS := {
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	":": ["00000", "00100", "00100", "00000", "00100", "00100", "00000"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
	"+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	"/": ["00001", "00010", "00100", "01000", "10000", "00000", "00000"],
	"%": ["11001", "11010", "00100", "01000", "10110", "00110", "00000"],
}

const DIGIT_W := 5
const DIGIT_H := 7
const DIGIT_GAP := 1


func number_size(text: String, px: int) -> Vector2:
	var n := text.length()
	if n == 0:
		return Vector2.ZERO
	return Vector2(float(n * DIGIT_W + (n - 1) * DIGIT_GAP) * float(px), float(DIGIT_H * px))


# 返回像素坐标列表（单位：像素格），由 HUD 换算成矩形批量绘制。
func number_pixels(text: String, ox: float, oy: float, px: float) -> Array:
	var out: Array = []
	var cx := ox
	for ch in text:
		var glyph: Array = DIGITS.get(ch, DIGITS["-"])
		for row in range(DIGIT_H):
			var line: String = glyph[row]
			for col in range(DIGIT_W):
				if line[col] == "1":
					out.append(Vector2(cx + float(col) * px, oy + float(row) * px))
		cx += float(DIGIT_W + DIGIT_GAP) * px
	return out


func number_rects(text: String, ox: float, oy: float, px: float) -> Array:
	var rects: Array = []
	for p in number_pixels(text, ox, oy, px):
		rects.append(Rect2(p, Vector2(px, px)))
	return rects

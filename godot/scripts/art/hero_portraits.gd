class_name HeroPortraits
extends RefCounted

# 32×32 英雄半身头像：比 HUD 用的 16×16 图标多一层明暗、耳/角/鳃和围巾细节。
# 选人卡片、详情弹窗与应用图标共用同一套形状，保持像素风。

const S := 32
const OUTLINE := Color("221a12")

var _cache: Dictionary = {}


func portrait(hero_id: String, fur: Color, cream: Color, dark: Color, accent: Color,
		with_bg := true) -> ImageTexture:
	var key := "portrait32_" + hero_id + ("_bg" if with_bg else "_nobg")
	if _cache.has(key):
		return _cache[key]
	var ops: Array = []
	if with_bg:
		_bg(ops, dark)
	_bust(ops, hero_id, fur, cream, dark, accent)
	var t := _compose(ops)
	_cache[key] = t
	return t


func _bust(ops: Array, id: String, fur: Color, cream: Color, dark: Color, accent: Color) -> void:
	# 肩/领/脖子/头的基础半身。坐标以 32×32 为画布。
	_add(ops, _rect(5, 25, 22, 7), accent)
	_add(ops, _rect(7, 25, 18, 2), _lighter(accent, 0.12))
	_add(ops, _rect(13, 21, 6, 6), fur)
	_add(ops, _rect(10, 5, 12, 18), fur)
	_add(ops, _rect(8, 8, 2, 11), fur)
	_add(ops, _rect(22, 8, 2, 11), fur)
	_add(ops, _rect(10, 4, 12, 3), _lighter(fur, 0.12))
	_add(ops, _rect(12, 20, 8, 3), _lighter(cream, 0.02))
	_add(ops, _rect(11, 11, 4, 4), Color("fbf8ef"))
	_add(ops, _rect(17, 11, 4, 4), Color("fbf8ef"))
	_add(ops, _rect(12, 12, 2, 2), dark)
	_add(ops, _rect(18, 12, 2, 2), dark)
	_add(ops, _rect(12, 12, 1, 1), Color.WHITE)
	_add(ops, _rect(18, 12, 1, 1), Color.WHITE)
	_add(ops, _rect(12, 17, 8, 5), cream)
	_add(ops, _rect(15, 17, 2, 2), dark)
	_add(ops, _rect(8, 15, 2, 2), _lighter(accent, 0.04))
	_add(ops, _rect(22, 15, 2, 2), _lighter(accent, 0.04))
	# 围巾/领口：按 3D 模型的实际配色（不再一律用 accent）。
	var scarf: Color = {
		"tiger": Color("60a868"), "fox": Color("8060b8"), "rabbit": Color("f6aebc"),
		"bear": Color("60a868"), "frog": Color("6fae4a"), "cat": accent,
		"panda": accent, "owl": Color("485474"), "axolotl": accent,
		"deer": accent, "turtle": Color("e0604f"), "hedgehog": Color("e0604f"),
		"redpanda": Color("f2c14e"), "wolf": Color("485474"), "crane": accent,
	}.get(id, accent)
	_add(ops, _rect(8, 24, 16, 3), scarf)
	_add(ops, _rect(13, 26, 6, 2), _lighter(scarf, 0.10))

	match id:
		"tiger":
			_add(ops, _disc(9, 5, 3), _darker(fur, 0.92))
			_add(ops, _disc(23, 5, 3), _darker(fur, 0.92))
			_add(ops, _disc(9, 5, 1.4), cream)
			_add(ops, _disc(23, 5, 1.4), cream)
			for x in [10, 20]:
				_add(ops, _rect(x, 7, 1, 6), dark)
			_add(ops, _rect(13, 6, 1, 3), dark)
			_add(ops, _rect(18, 6, 1, 3), dark)
			_add(ops, _rect(15, 17, 2, 2), Color("5b3a28"))
		"fox":
			_add(ops, _poly([Vector2(10, 6), Vector2(10, 0), Vector2(15, 5)]), fur)
			_add(ops, _poly([Vector2(22, 6), Vector2(22, 0), Vector2(17, 5)]), fur)
			_add(ops, _poly([Vector2(11.5, 4.5), Vector2(11.5, 1.5), Vector2(14, 4.5)]), cream)
			_add(ops, _poly([Vector2(20.5, 4.5), Vector2(20.5, 1.5), Vector2(18, 4.5)]), cream)
			_add(ops, _rect(10, 16, 12, 5), cream)
			_add(ops, _rect(15, 16, 2, 2), dark)
			_add(ops, _diamond(24, 18, 2), accent)
		"rabbit":
			_add(ops, _rect(10, 0, 4, 8), cream)
			_add(ops, _rect(18, 0, 4, 8), cream)
			_add(ops, _rect(11, 1, 2, 6), Color("f2a6c0"))
			_add(ops, _rect(19, 1, 2, 6), Color("f2a6c0"))
			_add(ops, _rect(14, 17, 4, 3), Color("eca0ba"))
			_add(ops, _rect(15, 17, 2, 2), dark)
		"bear":
			_add(ops, _disc(9, 5, 3.2), _darker(fur, 0.9))
			_add(ops, _disc(23, 5, 3.2), _darker(fur, 0.9))
			_add(ops, _disc(9, 5, 1.5), cream)
			_add(ops, _disc(23, 5, 1.5), cream)
			_add(ops, _rect(10, 16, 12, 5), cream)
			_add(ops, _rect(14, 17, 4, 2), Color("3a2a20"))
		"frog":
			_add(ops, _disc(8, 7, 4.2), fur)
			_add(ops, _disc(24, 7, 4.2), fur)
			_add(ops, _disc(8, 7, 2.2), cream)
			_add(ops, _disc(24, 7, 2.2), cream)
			_add(ops, _rect(7, 13, 18, 2), dark)
			_add(ops, _rect(10, 15, 12, 4), cream)
			_add(ops, _rect(12, 17, 8, 2), Color("3a5a34"))
		"cat":
			_add(ops, _poly([Vector2(10, 6), Vector2(10, 0), Vector2(15, 5)]), fur)
			_add(ops, _poly([Vector2(22, 6), Vector2(22, 0), Vector2(17, 5)]), fur)
			_add(ops, _poly([Vector2(11.5, 4.5), Vector2(11.5, 1.5), Vector2(14, 4.5)]), accent)
			_add(ops, _poly([Vector2(20.5, 4.5), Vector2(20.5, 1.5), Vector2(18, 4.5)]), accent)
			for y in [15, 18]:
				_add(ops, _rect(5, y, 5, 1), cream)
				_add(ops, _rect(22, y, 5, 1), cream)
			_add(ops, _rect(15, 17, 2, 2), Color("e888a8"))
		"panda":
			_add(ops, _disc(9, 5, 3.2), dark)
			_add(ops, _disc(23, 5, 3.2), dark)
			_add(ops, _rect(9, 10, 5, 5), dark)
			_add(ops, _rect(18, 10, 5, 5), dark)
			_add(ops, _rect(11, 11, 2, 2), Color.WHITE)
			_add(ops, _rect(19, 11, 2, 2), Color.WHITE)
			_add(ops, _rect(13, 17, 6, 4), cream)
			_add(ops, _rect(15, 17, 2, 2), dark)
		"owl":
			_add(ops, _poly([Vector2(9, 7), Vector2(9, 0), Vector2(14, 5)]), dark)
			_add(ops, _poly([Vector2(23, 7), Vector2(23, 0), Vector2(18, 5)]), dark)
			_add(ops, _disc(11, 11, 4), cream)
			_add(ops, _disc(21, 11, 4), cream)
			_add(ops, _disc(11, 11, 2), dark)
			_add(ops, _disc(21, 11, 2), dark)
			_add(ops, _poly([Vector2(14, 17), Vector2(18, 17), Vector2(16, 21)]), accent)
			_add(ops, _rect(10, 24, 12, 4), cream)
		"axolotl":
			for sx in [-1, 1]:
				for k in range(3):
					var gy := 9 + k * 4
					var gx := 4 - k if sx < 0 else 26 + k
					_add(ops, _rect(gx, gy, 3, 2), _lighter(fur, 0.04 + k * 0.02))
			_add(ops, _rect(10, 6, 12, 2), _lighter(fur, 0.15))
			_add(ops, _rect(13, 17, 6, 4), cream)
			_add(ops, _rect(15, 17, 2, 2), dark)
			_add(ops, _rect(11, 24, 10, 2), _lighter(accent, 0.12))
		"deer":
			for sx in [-1, 1]:
				_add(ops, _rect(10 if sx < 0 else 20, 0, 2, 8), accent)
				_add(ops, _rect(7 if sx < 0 else 23, 2, 4, 2), accent)
				_add(ops, _rect(9 if sx < 0 else 21, 6, 4, 2), accent)
				_add(ops, _rect(9 if sx < 0 else 21, 7, 2, 8), fur)
				_add(ops, _rect(9 if sx < 0 else 21, 8, 1, 5), cream)
			_add(ops, _rect(12, 17, 8, 5), cream)
			_add(ops, _rect(15, 17, 2, 2), dark)
			_add(ops, _rect(7, 20, 2, 2), cream)
			_add(ops, _rect(23, 20, 2, 2), cream)
			_add(ops, _diamond(8, 26, 2), accent)
		"turtle":
			for sx in [-1, 1]:
				_add(ops, _rect(4 if sx < 0 else 25, 10, 3, 9), _darker(fur, 0.8))
				_add(ops, _rect(6 if sx < 0 else 23, 7, 3, 4), accent)
			_add(ops, _rect(9, 5, 14, 4), _darker(fur, 0.86))
			_add(ops, _rect(12, 17, 8, 4), cream)
			_add(ops, _rect(15, 17, 2, 2), dark)
		"hedgehog":
			for sx in [-1, 1]:
				for k in range(3):
					_add(ops, _rect((2 if sx < 0 else 27) - k if sx < 0 else (27 + k), 7 + k * 4, 3, 4), dark)
			_add(ops, _rect(12, 17, 8, 4), cream)
			_add(ops, _rect(15, 17, 2, 2), dark)
		"redpanda":
			_add(ops, _disc(9, 5, 3), dark)
			_add(ops, _disc(23, 5, 3), dark)
			_add(ops, _disc(9, 5, 1.4), cream)
			_add(ops, _disc(23, 5, 1.4), cream)
			_add(ops, _rect(10, 16, 12, 5), cream)
			_add(ops, _rect(15, 16, 2, 2), dark)
			_add(ops, _rect(12, 6, 8, 2), _lighter(fur, 0.12))
		"wolf":
			_add(ops, _poly([Vector2(10, 6), Vector2(10, 0), Vector2(15, 5)]), dark)
			_add(ops, _poly([Vector2(22, 6), Vector2(22, 0), Vector2(17, 5)]), dark)
			_add(ops, _rect(10, 16, 12, 5), cream)
			_add(ops, _rect(15, 16, 2, 2), dark)
			_add(ops, _rect(11, 10, 3, 2), cream)
		"crane":
			_add(ops, _rect(14, 0, 4, 4), accent)
			_add(ops, _poly([Vector2(14, 16), Vector2(18, 16), Vector2(16, 22)]), accent)
			_add(ops, _rect(5, 16, 4, 3), dark)
			_add(ops, _rect(23, 16, 4, 3), dark)
			_add(ops, _rect(10, 24, 12, 3), cream)

	# 配件层：与 3D 模型一致，按角色补帽子/盾牌/法杖/花环/挎包等，保证选人卡能看出人设。
	match id:
		"tiger":
			_add(ops, _rect(6, 23, 20, 4), Color("60a868"))
			_add(ops, _rect(14, 27, 4, 4), Color("60a868"))
			_add(ops, _disc(5, 27, 3.4), Color("b28c5c"))
			_add(ops, _disc(5, 27, 1.6), Color("60a868"))
		"fox":
			_add(ops, _rect(5, 3, 22, 2), Color("8060b8"))
			_add(ops, _rect(10, 0, 12, 3), Color("8060b8"))
			_add(ops, _rect(13, 0, 6, 1), Color("a486d6"))
			_add(ops, _rect(16, 3, 2, 1), Color("f2c14e"))
			_add(ops, _rect(25, 27, 2, 5), Color("f2c14e"))
			_add(ops, _diamond(26, 24, 2), Color("f2c14e"))
		"rabbit":
			# 花环压在额头前缘，粉/金交替，白花在白毛上看不出来。
			for k in range(4):
				var wx := 9 + k * 4
				var wc: Color = [Color("f6aebc"), Color("f2c14e"), Color("f6aebc"), Color("f2c14e")][k]
				_add(ops, _rect(wx, 5, 2, 2), wc)
			_add(ops, _rect(9, 24, 14, 3), Color("f6aebc"))
			_add(ops, _rect(15, 27, 2, 2), Color.WHITE)
		"bear":
			_add(ops, _rect(7, 23, 18, 4), Color("60a868"))
			_add(ops, _rect(14, 27, 4, 4), Color("60a868"))
			_add(ops, _disc(4, 26, 3.2), Color("b28c5c"))
			_add(ops, _disc(4, 26, 1.4), Color("f2c14e"))
		"frog":
			_add(ops, _rect(5, 1, 22, 3), Color("6fae4a"))
			_add(ops, _rect(4, 3, 24, 1), Color("5c8f3c"))
			_add(ops, _rect(21, 0, 3, 2), Color("f6aebc"))
			_add(ops, _rect(22, 0, 1, 1), Color("f2c14e"))
		"cat":
			_add(ops, _rect(8, 23, 16, 3), accent)
			_add(ops, _disc(16, 27, 2.2), Color("f2c14e"))
		"panda":
			_add(ops, _rect(7, 23, 18, 3), accent)
			_add(ops, _rect(27, 3, 2, 22), Color("7cbf4a"))
			for y in [8, 14, 20]:
				_add(ops, _rect(26, y, 4, 1), Color("4e8c34"))
			_add(ops, _rect(25, 1, 4, 2), Color("9bd968"))
		"owl":
			_add(ops, _rect(7, 22, 18, 4), Color("485474"))
			_add(ops, _rect(25, 24, 2, 4), Color("485474"))
			_add(ops, _diamond(16, 27, 2), Color("f2c14e"))
		"axolotl":
			for sx in [-1, 1]:
				for k in range(3):
					var gy := 9 + k * 4
					var gx := (4 - k) if sx < 0 else (26 + k)
					_add(ops, _rect(gx, gy, 3, 2), Color("f6aebc"))
					_add(ops, _rect(gx + (2 if sx > 0 else 0), gy, 1, 1), Color("f49ea6"))
			_add(ops, _rect(27, 16, 3, 6), Color("f6aebc"))
		"deer":
			_add(ops, _rect(1, 24, 8, 6), Color("f0e8d2"))
			_add(ops, _rect(1, 23, 8, 2), Color("b28c5c"))
			_add(ops, _rect(8, 27, 1, 4), Color("b28c5c"))
		"turtle":
			_add(ops, _rect(7, 23, 18, 4), Color("e0604f"))
			_add(ops, _rect(23, 25, 4, 3), Color("e0604f"))
		"hedgehog":
			_add(ops, _rect(7, 23, 18, 3), Color("e0604f"))
			_add(ops, _rect(23, 21, 2, 7), Color("8a5a3b"))
			_add(ops, _rect(25, 22, 4, 5), Color("b28c5c"))
			_add(ops, _rect(26, 21, 2, 2), Color("d8485a"))
		"redpanda":
			_add(ops, _rect(7, 23, 18, 3), Color("f2c14e"))
			_add(ops, _disc(9, 5, 1.3), Color("fff1dc"))
			_add(ops, _disc(23, 5, 1.3), Color("fff1dc"))
		"wolf":
			_add(ops, _rect(7, 22, 18, 3), Color("485474"))
			for k in range(3):
				_add(ops, _rect(12 + k * 3, 25, 2, 3), Color("f2f4f6"))
		"crane":
			_add(ops, _rect(9, 23, 14, 2), Color("f2c14e"))
			_add(ops, _rect(15, 22, 2, 2), Color("f2c14e"))

	# 重装备层：主武器/披风/盾画在左右空白列，不压脸。
	var steel32 := Color("dfe8f0")
	match id:
		"tiger":
			_add(ops, _rect(27, 9, 2, 12), steel32)
			_add(ops, _rect(28, 7, 1, 2), Color("f4f8ff"))
			_add(ops, _rect(25, 21, 6, 1), Color("f2c14e"))
			_add(ops, _rect(27, 22, 2, 3), Color("b28c5c"))
		"fox":
			_add(ops, _rect(3, 24, 3, 7), Color("a486d6"))
			_add(ops, _rect(26, 24, 3, 7), Color("a486d6"))
			_add(ops, _rect(3, 30, 3, 1), Color("f2c14e"))
			_add(ops, _rect(26, 30, 3, 1), Color("f2c14e"))
		"rabbit":
			_add(ops, _rect(28, 8, 2, 16), Color("b28c5c"))
			_add(ops, _rect(26, 5, 6, 2), Color("f2c14e"))
			_add(ops, _rect(25, 7, 2, 2), Color("f2c14e"))
			_add(ops, _rect(31, 7, 1, 2), Color("f2c14e"))
			_add(ops, _rect(0, 22, 4, 8), Color("f0e8d2"))
			_add(ops, _rect(0, 22, 4, 2), Color("f6aebc"))
			_add(ops, _rect(1, 25, 2, 1), Color("58c878"))
			_add(ops, _rect(2, 24, 1, 3), Color("58c878"))
		"bear":
			_add(ops, _rect(28, 10, 2, 18), Color("b28c5c"))
			_add(ops, _rect(24, 7, 8, 6), Color("8a5a3b"))
			_add(ops, _rect(24, 8, 8, 1), Color("9aa39a"))
			_add(ops, _rect(24, 12, 8, 1), Color("9aa39a"))
		"frog":
			_add(ops, _rect(28, 12, 2, 14), Color("b28c5c"))
			_add(ops, _rect(26, 7, 5, 5), Color("9fe8f0"))
			_add(ops, _rect(29, 4, 2, 2), Color("c8f4ff"))
		"cat":
			_add(ops, _rect(2, 8, 1, 16), Color("b28c5c"))
			_add(ops, _rect(0, 7, 3, 1), Color("b28c5c"))
			_add(ops, _rect(0, 24, 3, 1), Color("b28c5c"))
			_add(ops, _rect(4, 8, 1, 16), Color("f5eedc"))
		"panda":
			_add(ops, _rect(7, 3, 18, 1), Color("e8c98a"))
			_add(ops, _rect(12, 0, 8, 3), Color("d8b878"))
			_add(ops, _rect(15, 0, 2, 1), Color("c8a864"))
		"owl":
			_add(ops, _rect(3, 24, 3, 7), Color("485474"))
			_add(ops, _rect(26, 24, 3, 7), Color("485474"))
			_add(ops, _rect(28, 8, 2, 16), Color("b28c5c"))
			_add(ops, _rect(26, 5, 6, 2), Color("f2c14e"))
			_add(ops, _rect(25, 7, 2, 2), Color("f2c14e"))
			_add(ops, _rect(31, 7, 1, 2), Color("f2c14e"))
		"axolotl":
			_add(ops, _rect(0, 21, 5, 9), Color("f0e8d2"))
			_add(ops, _rect(1, 23, 3, 1), Color("f6aebc"))
			_add(ops, _rect(1, 26, 3, 1), Color("f6aebc"))
			_add(ops, _rect(1, 29, 3, 1), Color("f6aebc"))
		"deer":
			_add(ops, _rect(2, 6, 1, 20), Color("b28c5c"))
			_add(ops, _rect(0, 5, 3, 1), Color("b28c5c"))
			_add(ops, _rect(0, 26, 3, 1), Color("b28c5c"))
			_add(ops, _rect(4, 6, 1, 20), Color("f5eedc"))
		"turtle":
			_add(ops, _rect(0, 20, 6, 11), Color("b28c5c"))
			_add(ops, _rect(0, 20, 6, 1), Color("f0e8d2"))
			_add(ops, _rect(2, 24, 2, 4), Color("9aa39a"))
		"hedgehog":
			_add(ops, _rect(2, 10, 2, 7), steel32)
			_add(ops, _rect(2, 17, 2, 3), Color("b28c5c"))
			_add(ops, _rect(28, 10, 2, 7), steel32)
			_add(ops, _rect(28, 17, 2, 3), Color("b28c5c"))
		"redpanda":
			_add(ops, _rect(28, 7, 2, 14), Color("f27a32"))
			_add(ops, _rect(29, 9, 1, 10), Color("ffd08a"))
			_add(ops, _rect(28, 5, 2, 2), Color("ffe0a8"))
		"wolf":
			_add(ops, _rect(2, 12, 1, 5), Color("dfe8f0"))
			_add(ops, _rect(29, 12, 1, 5), Color("dfe8f0"))
			_add(ops, _rect(4, 25, 3, 6), Color("9aa8b8"))
			_add(ops, _rect(25, 25, 3, 6), Color("9aa8b8"))
		"crane":
			_add(ops, _rect(28, 8, 2, 16), Color("b28c5c"))
			_add(ops, _rect(25, 5, 7, 2), Color("f5eedc"))
			_add(ops, _rect(27, 3, 3, 3), Color("9fe8f0"))


func _bg(ops: Array, dark: Color) -> void:
	# 深色底 + 上方一点主题色光晕，卡片/弹窗缩放时仍能看清轮廓。
	var base := Color(dark.r * 0.30, dark.g * 0.30, dark.b * 0.30, 1.0)
	_add(ops, _rect(0, 0, S, S), base)
	_add(ops, _disc(16, 12, 15), Color(base.r * 1.22, base.g * 1.22, base.b * 1.22, 1.0))
	_add(ops, _rect(0, 27, S, 5), Color(base.r * 0.72, base.g * 0.72, base.b * 0.72, 1.0))


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
			var color := Color(0, 0, 0, 0)
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
			if (x > 0 and union[i - 1] == 1) or (x < S - 1 and union[i + 1] == 1) \
					or (y > 0 and union[i - S] == 1) or (y < S - 1 and union[i + S] == 1):
				img.set_pixel(x, y, OUTLINE)
	return ImageTexture.create_from_image(img)


func _add(ops: Array, mask: PackedByteArray, color: Color) -> void:
	ops.append({"mask": mask, "color": color})


func _empty() -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(S * S)
	m.fill(0)
	return m


func _plot(m: PackedByteArray, x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= S or y >= S:
		return
	m[y * S + x] = 1


func _rect(x0: int, y0: int, w: int, h: int) -> PackedByteArray:
	var m := _empty()
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_plot(m, x, y)
	return m


func _disc(cx: float, cy: float, r: float) -> PackedByteArray:
	var m := _empty()
	for y in range(S):
		for x in range(S):
			var dx := float(x) + 0.5 - cx
			var dy := float(y) + 0.5 - cy
			if dx * dx + dy * dy <= r * r:
				_plot(m, x, y)
	return m


func _poly(pts: Array) -> PackedByteArray:
	var m := _empty()
	for y in range(S):
		for x in range(S):
			if _inside(Vector2(float(x) + 0.5, float(y) + 0.5), pts):
				_plot(m, x, y)
	return m


func _diamond(cx: int, cy: int, r: int) -> PackedByteArray:
	var m := _empty()
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if absi(x - cx) + absi(y - cy) <= r:
				_plot(m, x, y)
	return m


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


func _lighter(c: Color, k: float) -> Color:
	return Color(minf(1.0, c.r + k), minf(1.0, c.g + k), minf(1.0, c.b + k), c.a)


func _darker(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

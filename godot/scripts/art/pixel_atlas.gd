class_name PixelAtlas
extends RefCounted

# 16×16 像素瓦片图集：运行时生成，最近邻采样，所有方块模型共用一张贴图。
# 风格约束：16px、无渐变、最多 3-4 档明暗、纯色像素噪点。
# 4.14.0 起配方对齐宣传片：整体提亮、每像素微噪、草叶/花朵/亮斑点缀。

const TILE := 16
const COLS := 16
const SIZE := TILE * COLS

const ORDER := [
	"grass_top", "grass_side", "dirt", "stone", "stone_brick", "sand",
	"log_side", "log_top", "leaves", "planks", "path", "crystal",
	"fur", "flat", "face_slime", "flag", "glow", "cloud", "mushroom", "gold",
	"ice", "lava", "face_angry", "mushroom_blue",
	"water", "moss", "blush", "navy", "wood", "purple", "purple_light", "pink", "cream",
	"boss_stone",
]

var texture: ImageTexture
var _image: Image
var _index: Dictionary = {}
var _tile_tex: Dictionary = {}


func _init() -> void:
	_image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0.35, 0.35, 0.35, 1.0))
	for i in range(ORDER.size()):
		_index[ORDER[i]] = i
		_paint(ORDER[i], i)
	texture = ImageTexture.create_from_image(_image)


func uv(tile: String) -> Rect2:
	var i: int = int(_index.get(tile, _index["flat"]))
	var col := i % COLS
	var row := i / COLS
	var inset := 0.5 / float(SIZE)
	var u0 := float(col * TILE) / float(SIZE) + inset
	var v0 := float(row * TILE) / float(SIZE) + inset
	var u1 := float(col * TILE + TILE) / float(SIZE) - inset
	var v1 := float(row * TILE + TILE) / float(SIZE) - inset
	return Rect2(u0, v0, u1 - u0, v1 - v0)


# 单瓦片贴图：用于需要 UV 平铺的地面、道路、云朵（图集整体平铺会串图）。
func tile_texture(tile: String) -> ImageTexture:
	if _tile_tex.has(tile):
		return _tile_tex[tile]
	var i: int = int(_index.get(tile, _index["flat"]))
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.blit_rect(_image, Rect2i((i % COLS) * TILE, (i / COLS) * TILE, TILE, TILE), Vector2i.ZERO)
	var tex := ImageTexture.create_from_image(img)
	_tile_tex[tile] = tex
	return tex


func _h(x: int, y: int, s: int) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	return float(absi(n) % 1000) / 1000.0


func _px(ox: int, oy: int, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= TILE or y >= TILE:
		return
	_image.set_pixel(ox + x, oy + y, c)


func _fill(ox: int, oy: int, c: Color) -> void:
	for y in range(TILE):
		for x in range(TILE):
			_px(ox, oy, x, y, c)


# 视频配方：每个像素在基色上做 ±amp 的微噪（按通道独立抖动），干净又有颗粒。
func _grain(ox: int, oy: int, base: Color, amp: float, seed_v: int) -> void:
	for y in range(TILE):
		for x in range(TILE):
			var r := (_h(x, y, seed_v) * 2.0 - 1.0) * amp / 255.0
			var g := (_h(x, y, seed_v + 1) * 2.0 - 1.0) * amp / 255.0
			var b := (_h(x, y, seed_v + 2) * 2.0 - 1.0) * amp / 255.0
			_px(ox, oy, x, y, Color(
				clampf(base.r + r, 0.0, 1.0),
				clampf(base.g + g, 0.0, 1.0),
				clampf(base.b + b, 0.0, 1.0), base.a))


func _speck(ox: int, oy: int, c: Color, count: int, seed_v: int, size := 1) -> void:
	for k in range(count):
		var sx := int(_h(k, 2, seed_v) * float(TILE - size))
		var sy := int(_h(k, 3, seed_v + 1) * float(TILE - size))
		for yy in range(size):
			for xx in range(size):
				_px(ox, oy, sx + xx, sy + yy, c)


func _noise(ox: int, oy: int, base: Color, shades: Array, seed_v: int, density := 0.42) -> void:
	for y in range(TILE):
		for x in range(TILE):
			var r := _h(x, y, seed_v)
			var c := base
			if r < density:
				c = shades[int(r / density * float(shades.size())) % shades.size()]
			_px(ox, oy, x, y, c)


func _paint(tile: String, i: int) -> void:
	var ox := (i % COLS) * TILE
	var oy := (i / COLS) * TILE
	match tile:
		"grass_top":
			# 宣传片草地：干净基色 + 3 条深色草叶 + 2 粒奶油小花。
			_grain(ox, oy, Color("6fb84f"), 8.0, 11)
			var blades := [Color("55a23d"), Color("59a641"), Color("5a9f3c")]
			for k in range(3):
				var bx := int(_h(k, 4, 12) * 15.0)
				var by := int(_h(k, 5, 13) * 12.0)
				for yy in range(4):
					_px(ox, oy, bx, by + yy, blades[k])
			_speck(ox, oy, Color("f6ecb2"), 2, 14)
		"grass_side":
			_grain(ox, oy, Color("b98a5f"), 8.0, 12)
			# 山丘侧面以草为主，只在底部留一条泥土，远看是明亮的绿色丘陵。
			for x in range(TILE):
				var drop := 13 + int(_h(x, 0, 13) * 2.0)
				for y in range(drop):
					var c := Color("6fb84f")
					if _h(x, y, 14) < 0.3:
						c = Color("5fa845")
					_px(ox, oy, x, y, c)
		"dirt":
			_grain(ox, oy, Color("b08355"), 9.0, 15)
			_speck(ox, oy, Color("9c7146"), 6, 16)
		"stone":
			_grain(ox, oy, Color("d8d2c2"), 8.0, 16)
			_speck(ox, oy, Color("c0baaa"), 4, 17)
		"stone_brick":
			_fill(ox, oy, Color("b7b0a0"))
			for row in range(4):
				for col in range(2):
					var bx := col * 8 + (4 if row % 2 == 1 else 0)
					for y in range(4):
						for x in range(7):
							var xx := (bx + x) % TILE
							var c := Color("dcd5c5")
							if _h(xx, row * 4 + y, 18) < 0.16:
								c = Color("ccc5b5")
							if y == 0 or x == 0:
								c = Color("e8e1d1") if y == 0 else c
							_px(ox, oy, xx, row * 4 + y, c)
		"sand":
			_grain(ox, oy, Color("e8d9b0"), 7.0, 19)
			_speck(ox, oy, Color("dccba0"), 5, 20)
		"log_side":
			# 宣传片树皮：基色微噪 + 每 3px 竖纹 + 少量亮斑。
			_grain(ox, oy, Color("96704c"), 8.0, 20)
			for x in range(0, TILE, 3):
				for y in range(TILE):
					_px(ox, oy, x, y, Color("7e5c3c"))
			for k in range(3):
				var bx := int(_h(k, 6, 21) * 13.0)
				var by := int(_h(k, 7, 22) * 13.0)
				for yy in range(3):
					for xx in range(2):
						_px(ox, oy, bx + xx, by + yy, Color("a88058"))
		"log_top":
			_fill(ox, oy, Color("b98a5e"))
			for y in range(TILE):
				for x in range(TILE):
					var dx := float(x) - 7.5
					var dy := float(y) - 7.5
					var d := sqrt(dx * dx + dy * dy)
					if int(d) % 2 == 0:
						_px(ox, oy, x, y, Color("9b6f45"))
					if d < 1.6:
						_px(ox, oy, x, y, Color("d0a374"))
		"leaves":
			# 宣传片叶簇：基色微噪 + 3 块 2×2 亮斑。
			_grain(ox, oy, Color("5ca84a"), 9.0, 22)
			var bright := [Color("70ba58"), Color("6eb858"), Color("6ab656")]
			for k in range(3):
				var bx := int(_h(k, 8, 23) * 14.0)
				var by := int(_h(k, 9, 24) * 14.0)
				for yy in range(2):
					for xx in range(2):
						_px(ox, oy, bx + xx, by + yy, bright[k])
		"planks":
			_fill(ox, oy, Color("c08f5e"))
			for y in range(TILE):
				if y % 4 == 3:
					for x in range(TILE):
						_px(ox, oy, x, y, Color("a0764a"))
			_speck(ox, oy, Color("cd9d6c"), 8, 25)
		"path":
			_grain(ox, oy, Color("cfbd99"), 7.0, 27)
			_speck(ox, oy, Color("c4b08c"), 5, 28)
		"crystal":
			_fill(ox, oy, Color("d9faff"))
			for y in range(TILE):
				for x in range(TILE):
					if (x + y) % 6 == 0:
						_px(ox, oy, x, y, Color("9debf7"))
					elif (x + y) % 6 == 3:
						_px(ox, oy, x, y, Color("ffffff"))
		"fur":
			_grain(ox, oy, Color("efe8d9"), 5.0, 28)
		"flat":
			_fill(ox, oy, Color("ffffff"))
		"face_slime":
			_fill(ox, oy, Color("ffffff"))
			for y in range(5, 8):
				for x in range(3, 6):
					_px(ox, oy, x, y, Color("232323"))
				for x in range(10, 13):
					_px(ox, oy, x, y, Color("232323"))
			for x in range(5, 11):
				_px(ox, oy, x, 11, Color("232323"))
			_px(ox, oy, 4, 12, Color("232323"))
			_px(ox, oy, 11, 12, Color("232323"))
		"flag":
			_fill(ox, oy, Color("ffffff"))
			for y in range(10, 13):
				for x in range(TILE):
					_px(ox, oy, x, y, Color("d8d8d8"))
		"glow":
			_fill(ox, oy, Color("ffffff"))
			for y in range(TILE):
				for x in range(TILE):
					if x % 4 == 0 and y % 4 == 0:
						_px(ox, oy, x, y, Color("fff4c0"))
		"cloud":
			_grain(ox, oy, Color("f4f8fa"), 3.0, 29)
			_speck(ox, oy, Color("ffffff"), 8, 30)
		"mushroom":
			# 红方队色菌盖：亮橙红 + 奶油白斑。
			_grain(ox, oy, Color("f0845c"), 6.0, 30)
			for k in range(7):
				var cx := 2 + int(_h(k, 6, 30) * 12.0)
				var cy := 2 + int(_h(k, 7, 31) * 12.0)
				for y in range(2):
					for x in range(2):
						_px(ox, oy, cx + x, cy + y, Color("fff2de"))
		"gold":
			_grain(ox, oy, Color("f2c14e"), 6.0, 32)
			_speck(ox, oy, Color("ffd970"), 5, 33)
		"ice":
			_fill(ox, oy, Color("e4faff"))
			for y in range(TILE):
				for x in range(TILE):
					if (x + y * 2) % 9 == 0:
						_px(ox, oy, x, y, Color("bcefff"))
					elif (x * 2 + y) % 13 == 0:
						_px(ox, oy, x, y, Color("ffffff"))
		"lava":
			_fill(ox, oy, Color("4a221a"))
			for y in range(TILE):
				for x in range(TILE):
					var r := _h(x, y, 33)
					if r < 0.16:
						_px(ox, oy, x, y, Color("f27a32"))
					elif r < 0.24:
						_px(ox, oy, x, y, Color("ffc05c"))
					elif r < 0.34:
						_px(ox, oy, x, y, Color("6a3224"))
		"face_angry":
			_fill(ox, oy, Color("ffffff"))
			# 斜挑的怒眉
			for k in range(3):
				_px(ox, oy, 3 + k, 5 + k, Color("232323"))
				_px(ox, oy, 12 - k, 5 + k, Color("232323"))
			for y in range(7, 9):
				for x in range(4, 7):
					_px(ox, oy, x, y, Color("232323"))
				for x in range(9, 12):
					_px(ox, oy, x, y, Color("232323"))
			# 锯齿嘴
			for x in range(4, 12):
				if x % 2 == 0:
					_px(ox, oy, x, 11, Color("232323"))
				else:
					_px(ox, oy, x, 12, Color("232323"))
		"mushroom_blue":
			# 蓝方队色菌盖：亮天蓝 + 近白斑点。
			_grain(ox, oy, Color("4fc3e8"), 6.0, 34)
			for k in range(8):
				var cx := 2 + int(_h(k, 8, 34) * 12.0)
				var cy := 2 + int(_h(k, 9, 35) * 12.0)
				for y in range(2):
					for x in range(2):
						_px(ox, oy, cx + x, cy + y, Color("eafbff"))
		"water":
			_grain(ox, oy, Color("7ec6e2"), 6.0, 36)
			_speck(ox, oy, Color("b8e8f6"), 3, 37, 2)
		"moss":
			_grain(ox, oy, Color("6c9852"), 7.0, 38)
			_speck(ox, oy, Color("5c8846"), 4, 39)
		"blush":
			_grain(ox, oy, Color("f49ea6"), 3.0, 40)
			_speck(ox, oy, Color("ee909a"), 3, 41, 2)
		"navy":
			_grain(ox, oy, Color("485474"), 4.0, 42)
		"wood":
			_grain(ox, oy, Color("b28c5c"), 7.0, 43)
			for x in range(0, TILE, 5):
				for y in range(TILE):
					if _h(x, y, 44) < 0.5:
						_px(ox, oy, x, y, Color("a07a4c"))
		"purple":
			_grain(ox, oy, Color("8060b8"), 5.0, 45)
		"purple_light":
			_grain(ox, oy, Color("a486d6"), 4.0, 46)
		"pink":
			_grain(ox, oy, Color("f6aebc"), 4.0, 47)
		"cream":
			_grain(ox, oy, Color("f0e8d2"), 4.0, 48)
		"boss_stone":
			# 巨兽暖灰石甲：直接吃贴图色，不再靠深色 tint 压暗。
			_grain(ox, oy, Color("8a867e"), 9.0, 49)
			_speck(ox, oy, Color("706c66"), 6, 50, 2)
		_:
			_fill(ox, oy, Color("ff00ff"))

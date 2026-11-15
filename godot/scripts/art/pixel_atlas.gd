class_name PixelAtlas
extends RefCounted

# 16×16 像素瓦片图集：运行时生成，最近邻采样，所有方块模型共用一张贴图。
# 风格约束：16px、无渐变、最多 3-4 档明暗、纯色像素噪点。

const TILE := 16
const COLS := 16
const SIZE := TILE * COLS

const ORDER := [
	"grass_top", "grass_side", "dirt", "stone", "stone_brick", "sand",
	"log_side", "log_top", "leaves", "planks", "path", "crystal",
	"fur", "flat", "face_slime", "flag", "glow", "cloud", "mushroom", "gold",
	"ice", "lava", "face_angry", "mushroom_blue",
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
			_noise(ox, oy, Color("5d9c3f"), [Color("6fae4a"), Color("4f8a36"), Color("7cbb55")], 11)
		"grass_side":
			_noise(ox, oy, Color("8a5a3b"), [Color("7a4d31"), Color("9a6744")], 12, 0.5)
			for x in range(TILE):
				var drop := 3 + int(_h(x, 0, 13) * 3.0)
				for y in range(drop):
					var c := Color("5d9c3f")
					if _h(x, y, 14) < 0.3:
						c = Color("4f8a36")
					_px(ox, oy, x, y, c)
		"dirt":
			_noise(ox, oy, Color("8a5a3b"), [Color("75492d"), Color("9c6a45"), Color("6b4227")], 15)
		"stone":
			_noise(ox, oy, Color("8c8c8c"), [Color("7c7c7c"), Color("9c9c9c"), Color("707070")], 16, 0.55)
			for k in range(5):
				_px(ox, oy, 2 + k, 8 + int(_h(k, 1, 17) * 3.0), Color("6a6a6a"))
		"stone_brick":
			_fill(ox, oy, Color("6f6f6f"))
			for row in range(4):
				for col in range(2):
					var bx := col * 8 + (4 if row % 2 == 1 else 0)
					for y in range(4):
						for x in range(7):
							var xx := (bx + x) % TILE
							var c := Color("8e8e8e")
							if _h(xx, row * 4 + y, 18) < 0.16:
								c = Color("808080")
							if y == 0 or x == 0:
								c = Color("a2a2a2") if y == 0 else c
							_px(ox, oy, xx, row * 4 + y, c)
		"sand":
			_noise(ox, oy, Color("dbc98a"), [Color("cbb877"), Color("ecd99b")], 19, 0.4)
		"log_side":
			_noise(ox, oy, Color("6b4a2a"), [Color("5c3f23"), Color("7c5734")], 20, 0.3)
			for x in range(TILE):
				if _h(x, 0, 21) < 0.22:
					for y in range(TILE):
						_px(ox, oy, x, y, Color("573a20"))
		"log_top":
			_fill(ox, oy, Color("8a6038"))
			for y in range(TILE):
				for x in range(TILE):
					var dx := float(x) - 7.5
					var dy := float(y) - 7.5
					var d := sqrt(dx * dx + dy * dy)
					if int(d) % 2 == 0:
						_px(ox, oy, x, y, Color("6f4a29"))
					if d < 1.6:
						_px(ox, oy, x, y, Color("a87a48"))
		"leaves":
			_noise(ox, oy, Color("3f7a33"), [Color("2f6b2a"), Color("4f8f3f"), Color("356f2c")], 22, 0.55)
			for k in range(6):
				_px(ox, oy, int(_h(k, 2, 23) * 16.0), int(_h(k, 3, 24) * 16.0), Color("244f21"))
		"planks":
			_fill(ox, oy, Color("a8794b"))
			for y in range(TILE):
				if y % 4 == 3:
					for x in range(TILE):
						_px(ox, oy, x, y, Color("7a5433"))
			for k in range(8):
				_px(ox, oy, int(_h(k, 4, 25) * 16.0), int(_h(k, 5, 26) * 15.0), Color("9a6c41"))
		"path":
			_noise(ox, oy, Color("c2a878"), [Color("b09464"), Color("d2b98a"), Color("a4875a")], 27, 0.5)
		"crystal":
			_fill(ox, oy, Color("eaf6ff"))
			for y in range(TILE):
				for x in range(TILE):
					if (x + y) % 6 == 0:
						_px(ox, oy, x, y, Color("b8dff5"))
					elif (x + y) % 6 == 3:
						_px(ox, oy, x, y, Color("ffffff"))
		"fur":
			_noise(ox, oy, Color("e6dfd2"), [Color("d8cfc0"), Color("f2ece0")], 28, 0.45)
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
			_noise(ox, oy, Color("f4f8fa"), [Color("e6edf0"), Color("ffffff")], 29, 0.35)
		"mushroom":
			_fill(ox, oy, Color("c8402f"))
			for k in range(7):
				var cx := 2 + int(_h(k, 6, 30) * 12.0)
				var cy := 2 + int(_h(k, 7, 31) * 12.0)
				for y in range(2):
					for x in range(2):
						_px(ox, oy, cx + x, cy + y, Color("f4efe0"))
		"gold":
			_noise(ox, oy, Color("f0b93c"), [Color("d99f28"), Color("ffd96a")], 32, 0.45)
		"ice":
			_fill(ox, oy, Color("dff6ff"))
			for y in range(TILE):
				for x in range(TILE):
					if (x + y * 2) % 9 == 0:
						_px(ox, oy, x, y, Color("b8e8ff"))
					elif (x * 2 + y) % 13 == 0:
						_px(ox, oy, x, y, Color("ffffff"))
		"lava":
			_fill(ox, oy, Color("3a1c16"))
			for y in range(TILE):
				for x in range(TILE):
					var r := _h(x, y, 33)
					if r < 0.16:
						_px(ox, oy, x, y, Color("f0702a"))
					elif r < 0.24:
						_px(ox, oy, x, y, Color("ffb347"))
					elif r < 0.34:
						_px(ox, oy, x, y, Color("5a2a1e"))
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
			_fill(ox, oy, Color("4f9fc0"))
			for k in range(8):
				var cx := 2 + int(_h(k, 8, 34) * 12.0)
				var cy := 2 + int(_h(k, 9, 35) * 12.0)
				for y in range(2):
					for x in range(2):
						_px(ox, oy, cx + x, cy + y, Color("e8f8ff"))
		_:
			_fill(ox, oy, Color("ff00ff"))

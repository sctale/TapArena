extends SceneTree

# 生成 512×512 像素风应用图标：奶油金环 + 32×32 老虎半身像 + 森林渐变底。
# 运行：godot --headless --path godot --script res://tests/make_icon.gd

const HeroPortraitsScript = preload("res://scripts/art/hero_portraits.gd")

const S := 128
const GOLD := Color("f5c542")
const DARK := Color("221a12")


func _init() -> void:
	var portraits = HeroPortraitsScript.new()
	var portrait: Image = portraits.portrait("tiger", Color("E8B662"), Color("F8E9C9"),
		Color("8A5A32"), Color("D9822B"), false).get_image()

	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261116
	for y in range(S):
		for x in range(S):
			var u := float(x) / float(S - 1)
			var v := float(y) / float(S - 1)
			var edge := Color("0b1b17").lerp(Color("173a2f"), 1.0 - absf(u - 0.5) * 1.1)
			edge = edge.lerp(Color("1f4a3b"), 1.0 - v * 0.55)
			var dx := float(x) - 64.0
			var dy := float(y) - 60.0
			var glow := clampf(1.0 - sqrt(dx * dx + dy * dy) / 78.0, 0.0, 1.0)
			var c := edge.lerp(Color("5a4a28"), glow * 0.34)
			if rng.randf() < 0.045:
				c = c.lightened(0.06)
			img.set_pixel(x, y, c)

	# 外暗框 + 金环 + 细高光。
	for y in range(S):
		for x in range(S):
			var dx := float(x) - 64.0
			var dy := float(y) - 64.0
			var d := sqrt(dx * dx + dy * dy)
			if d >= 56.0 and d <= 63.0:
				img.set_pixel(x, y, DARK)
			elif d >= 50.0 and d < 56.0:
				img.set_pixel(x, y, GOLD)
			elif d >= 47.5 and d < 50.0:
				img.set_pixel(x, y, Color("fff0b0"))
			if x < 4 or y < 4 or x >= S - 4 or y >= S - 4:
				img.set_pixel(x, y, DARK)

	# 32×32 半身像放大到 96，居中放进金环。
	var big := portrait.duplicate()
	big.resize(96, 96, Image.INTERPOLATE_NEAREST)
	img.blend_rect(big, Rect2i(0, 0, 96, 96), Vector2i(16, 17))

	# 四角金色小星，避免纯色大面积。
	for p in [Vector2i(17, 22), Vector2i(109, 26), Vector2i(21, 102), Vector2i(108, 104)]:
		img.set_pixel(p.x, p.y, GOLD)
		img.set_pixel(p.x + 1, p.y, Color("fff0b0"))
		img.set_pixel(p.x, p.y + 1, GOLD)

	img.resize(512, 512, Image.INTERPOLATE_NEAREST)
	var path := ProjectSettings.globalize_path("res://assets/icons/app_icon.png")
	img.save_png(path)
	print("ICON_OK " + path)
	quit(0)

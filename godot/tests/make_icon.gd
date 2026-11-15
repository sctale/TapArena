extends SceneTree

# 生成像素风应用图标：草方块底 + 老虎人形头像 + 金色描边。
# 运行：godot --headless --path godot --script res://tests/make_icon.gd

const PixelIconsScript = preload("res://scripts/art/pixel_icons.gd")

const S := 64


func _init() -> void:
	var icons = PixelIconsScript.new()
	var portrait: Image = icons.hero_portrait("tiger", Color("E8B662"), Color("F8E9C9"),
		Color("8A5A32"), Color("D9822B"), false).get_image()

	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color("4f8a36"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261115
	for y in range(S):
		for x in range(S):
			var r := rng.randf()
			var c := Color("5d9c3f")
			if y < 12:
				c = Color("6fae4a")
			elif y > 52:
				c = Color("4a7c32")
			if r < 0.14:
				c = c.darkened(0.12)
			elif r < 0.24:
				c = c.lightened(0.08)
			img.set_pixel(x, y, c)

	# 头像 16×16 最近邻放大到 48×48，居中（透明背景叠加到草地上）
	var big := portrait.duplicate()
	big.resize(44, 44, Image.INTERPOLATE_NEAREST)
	img.blend_rect(big, Rect2i(0, 0, 44, 44), Vector2i(10, 12))

	# 深色外框 + 金色内框
	for y in range(S):
		for x in range(S):
			if x < 3 or y < 3 or x >= S - 3 or y >= S - 3:
				img.set_pixel(x, y, Color("2a1e14"))
			elif x < 5 or y < 5 or x >= S - 5 or y >= S - 5:
				img.set_pixel(x, y, Color("f5c542"))

	img.resize(512, 512, Image.INTERPOLATE_NEAREST)
	var path := ProjectSettings.globalize_path("res://assets/icons/app_icon.png")
	img.save_png(path)
	print("ICON_OK " + path)
	quit(0)

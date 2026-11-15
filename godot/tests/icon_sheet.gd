extends SceneTree

# 生成图标与图集预览，供人工核对像素风一致性。
# 运行：godot --headless --path godot --script res://tests/icon_sheet.gd

const PixelIconsScript = preload("res://scripts/art/pixel_icons.gd")
const PixelAtlasScript = preload("res://scripts/art/pixel_atlas.gd")

const SKILLS := [
	"skill_dash", "skill_aoe", "skill_splash", "skill_cone", "skill_shield", "skill_heal",
	"skill_pull", "skill_leap", "skill_multi", "skill_radial", "skill_projectile",
	"ui_heart", "ui_sword", "ui_clock", "ui_tower", "ui_gem", "ui_star",
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	var icons = PixelIconsScript.new()

	var hero_colors := {
		"tiger": ["E8B662", "F8E9C9", "8A5A32", "D9822B"],
		"fox": ["D96A2B", "F1E6D2", "5B3721", "7B54C7"],
		"rabbit": ["A89684", "F3EEE4", "6D5747", "EE8FB8"],
		"bear": ["4A3428", "C9A57D", "191816", "4E9A63"],
		"frog": ["6FA34B", "E8E3CC", "3F6B33", "4FA88F"],
		"cat": ["B08A63", "F2E9DA", "6B4A35", "4C8F9E"],
	}

	var entries: Array = []
	for k in SKILLS:
		entries.append({"tex": icons.tex(k), "name": k})
	for id in hero_colors:
		var c: Array = hero_colors[id]
		entries.append({
			"tex": icons.hero_portrait(id, Color(c[0]), Color(c[1]), Color(c[2]), Color(c[3])),
			"name": "hero_" + id,
		})

	_sheet(entries, 16, 4, 6, "res://build/icon-sheet.png")

	var atlas = PixelAtlasScript.new()
	var atlas_entries: Array = []
	var atlas_img: Image = atlas.texture.get_image()
	for i in range(20):
		var col: int = i % 16
		var row: int = i / 16
		var tile: Image = atlas_img.get_region(Rect2i(col * 16, row * 16, 16, 16))
		atlas_entries.append({"img": tile, "name": "tile_%d" % i})
	_image_sheet(atlas_entries, 16, 6, 6, "res://build/atlas-sheet.png")
	print("SHEET_OK icons=%d" % entries.size())
	quit(0)


func _sheet(entries: Array, src_size: int, scale: int, cols: int, path: String) -> void:
	var imgs: Array = []
	for e in entries:
		imgs.append({"img": (e["tex"] as ImageTexture).get_image(), "name": str(e["name"])})
	_image_sheet(imgs, src_size, scale, cols, path)


func _image_sheet(entries: Array, src_size: int, scale: int, cols: int, path: String) -> void:
	var cell := src_size * scale
	var pad := 8
	var rows := int(ceil(float(entries.size()) / float(cols)))
	var sheet := Image.create(cols * (cell + pad) + pad, rows * (cell + pad) + pad, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1e2a26"))
	for i in range(entries.size()):
		var img: Image = entries[i]["img"]
		var col := i % cols
		var row := i / cols
		var ox := pad + col * (cell + pad)
		var oy := pad + row * (cell + pad)
		for y in range(cell):
			for x in range(cell):
				var c := img.get_pixel(x / scale, y / scale)
				if c.a > 0.05:
					sheet.set_pixel(ox + x, oy + y, c)
	sheet.save_png(ProjectSettings.globalize_path(path))

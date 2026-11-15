class_name BlockModels
extends RefCounted

# 方块体素模型库：英雄、小兵、塔、水晶、树、石头、蘑菇、路牌、脚下队环。
# 全部按「16 单位 ≈ 1 个方块」的比例搭建，保持粗颗粒的方块游戏观感。


static func _b(boxes: Array, pos: Vector3, size: Vector3, tile: String, tint: Color, faces := {}) -> void:
	boxes.append(VoxelModel.box(pos, size, tile, tint, faces))


static func _darker(c: Color, k := 0.82) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func _lighter(c: Color, k := 0.14) -> Color:
	return Color(minf(1.0, c.r + k), minf(1.0, c.g + k), minf(1.0, c.b + k), c.a)


static func hero(id: String, atlas: PixelAtlas, fur: Color, cream: Color, dark: Color, accent: Color) -> ArrayMesh:
	var boxes: Array = []
	_humanoid_base(boxes, fur, cream, dark, accent)
	match id:
		"tiger":
			# 老虎：黑条纹 + 圆耳 + 上翘长尾 + 橙色围巾
			for sx in [-1, 1]:
				_b(boxes, Vector3(9.5 * sx, 75, 0), Vector3(8, 10, 8), "fur", fur)
				_b(boxes, Vector3(9.5 * sx, 77, 3.6), Vector3(5, 5, 2), "flat", cream)
				_b(boxes, Vector3(11.4 * sx, 62, 12.7), Vector3(3, 12, 2), "flat", dark)
				_b(boxes, Vector3(20.0 * sx, 40, 0), Vector3(10.6, 3, 10.6), "flat", dark)
				_b(boxes, Vector3(20.0 * sx, 48, 0), Vector3(10.6, 3, 10.6), "flat", dark)
			_b(boxes, Vector3(0, 72, 12.7), Vector3(12, 3, 2), "flat", dark)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(9, 8, 1), "flat", cream)
			_b(boxes, Vector3(10, 34, -14), Vector3(7, 7, 16), "fur", fur)
			_b(boxes, Vector3(10, 40, -26), Vector3(7, 7, 12), "fur", fur)
			_b(boxes, Vector3(10, 46, -33), Vector3(7, 7, 6), "flat", dark)
		"fox":
			# 狐狸：尖耳 + 白脸颊 + 上翘蓬松大尾 + 紫色法师围巾
			for sx in [-1, 1]:
				_b(boxes, Vector3(8.5 * sx, 75, 0), Vector3(7, 14, 7), "fur", fur)
				_b(boxes, Vector3(8.5 * sx, 77, 3.6), Vector3(3, 9, 2), "flat", cream)
				_b(boxes, Vector3(7.5 * sx, 66, 12.7), Vector3(5, 5, 2), "flat", dark)
			_b(boxes, Vector3(0, 58, 12.6), Vector3(24, 7, 2), "flat", cream)
			_b(boxes, Vector3(0, 60, 13.0), Vector3(5, 3, 1), "flat", dark)
			_b(boxes, Vector3(10, 40, 10.4), Vector3(11, 15, 2), "flat", accent)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(7, 7, 1), "flat", Color("f5c542"))
			_b(boxes, Vector3(9, 32, -14), Vector3(13, 13, 14), "fur", fur)
			_b(boxes, Vector3(9, 36, -25), Vector3(16, 16, 14), "fur", fur)
			_b(boxes, Vector3(9, 42, -34), Vector3(10, 10, 8), "flat", cream)
		"rabbit":
			# 兔子：长耳 + 粉内耳 + 毛球尾 + 粉色背心
			for sx in [-1, 1]:
				_b(boxes, Vector3(6.5 * sx, 75, 0), Vector3(6, 23, 5), "fur", cream)
				_b(boxes, Vector3(6.5 * sx, 77, 2.8), Vector3(3, 17, 2), "flat", Color("f0a8c0"))
				_b(boxes, Vector3(5.5 * sx, 66, 12.7), Vector3(4, 4, 2), "flat", dark)
			_b(boxes, Vector3(0, 60, 13.0), Vector3(4, 3, 2), "flat", Color("e888a8"))
			_b(boxes, Vector3(0, 30, 10.2), Vector3(24, 16, 2), "flat", accent)
			_b(boxes, Vector3(0, 34, 10.6), Vector3(10, 8, 1), "flat", cream)
			_b(boxes, Vector3(8, 30, -13), Vector3(11, 11, 10), "fur", cream)
		"bear":
			# 熊：圆耳 + 大吻部 + 绿色背心 + 短尾 + 粗壮身形
			for sx in [-1, 1]:
				_b(boxes, Vector3(9.5 * sx, 74, 0), Vector3(10, 10, 9), "fur", _darker(fur, 0.9))
				_b(boxes, Vector3(9.5 * sx, 76, 3.8), Vector3(5, 5, 2), "flat", cream)
				_b(boxes, Vector3(8.5 * sx, 62, 10.4), Vector3(7, 18, 2), "flat", accent)
				_b(boxes, Vector3(6.5 * sx, 68, 12.7), Vector3(5, 5, 2), "flat", dark)
			_b(boxes, Vector3(0, 58, 12.6), Vector3(20, 11, 2), "flat", cream)
			_b(boxes, Vector3(0, 61, 13.2), Vector3(7, 4, 2), "flat", dark)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(9, 9, 1), "flat", cream)
			_b(boxes, Vector3(8, 32, -12), Vector3(9, 9, 8), "fur", cream)
		"frog":
			# 青蛙：头顶大眼 + 宽嘴 + 青色围巾 + 浅色肚皮
			for sx in [-1, 1]:
				_b(boxes, Vector3(8.5 * sx, 75, 3), Vector3(12, 10, 12), "fur", cream)
				_b(boxes, Vector3(8.5 * sx, 77, 9.2), Vector3(6, 5, 2), "flat", dark)
			_b(boxes, Vector3(0, 62, 12.7), Vector3(16, 3, 2), "flat", dark)
			_b(boxes, Vector3(0, 30, 10.2), Vector3(24, 16, 2), "flat", cream)
			_b(boxes, Vector3(0, 52, 0), Vector3(28, 4, 22), "flat", accent)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(8, 7, 1), "flat", accent)
		"cat":
			# 猫：尖耳 + 胡须 + 上翘细尾 + 青色围巾
			for sx in [-1, 1]:
				_b(boxes, Vector3(8.5 * sx, 75, 0), Vector3(7, 11, 6), "fur", fur)
				_b(boxes, Vector3(8.5 * sx, 77, 3.4), Vector3(3, 6, 2), "flat", accent)
				for k in range(3):
					_b(boxes, Vector3(12.3 * sx, 60.0 + float(k) * 2.6, 12.7), Vector3(5, 1, 2), "flat", cream)
			_b(boxes, Vector3(0, 60, 13.0), Vector3(5, 4, 2), "flat", Color("e888a8"))
			_b(boxes, Vector3(0, 52, 0), Vector3(28, 4, 22), "flat", accent)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(8, 7, 1), "flat", accent)
			_b(boxes, Vector3(9, 32, -14), Vector3(5, 6, 16), "fur", fur)
			_b(boxes, Vector3(9, 40, -26), Vector3(5, 6, 12), "fur", _darker(fur, 0.7))
		_:
			pass
	return VoxelModel.mesh(atlas, boxes)


# 人形骨架：腿 / 靴 / 躯干 / 腰带 / 手臂 / 手套 / 头 / 眼 / 嘴
static func _humanoid_base(boxes: Array, fur: Color, cream: Color, dark: Color, accent: Color) -> void:
	var pants := _darker(fur, 0.78)
	for sx in [-1, 1]:
		_b(boxes, Vector3(8.0 * sx, 0, 0), Vector3(13, 26, 13), "fur", pants)
		_b(boxes, Vector3(8.0 * sx, 0, 1), Vector3(14, 7, 14), "flat", dark)
		_b(boxes, Vector3(20.0 * sx, 28, 0), Vector3(10, 24, 10), "fur", fur)
		_b(boxes, Vector3(20.0 * sx, 28, 0), Vector3(11, 7, 11), "flat", dark)
	_b(boxes, Vector3(0, 26, 0), Vector3(30, 26, 20), "fur", fur)
	_b(boxes, Vector3(0, 26, 0), Vector3(31, 5, 21), "flat", dark)
	_b(boxes, Vector3(0, 52, 0), Vector3(28, 4, 22), "flat", accent)
	_b(boxes, Vector3(0, 56, 0), Vector3(26, 22, 24), "fur", fur)
	_b(boxes, Vector3(0, 58, 12.6), Vector3(18, 10, 2), "flat", cream)
	for sx in [-1, 1]:
		_b(boxes, Vector3(5.5 * sx, 68, 12.7), Vector3(4, 4, 2), "flat", dark)
	_b(boxes, Vector3(0, 61, 13.1), Vector3(6, 2, 1), "flat", dark)


static func minion(atlas: PixelAtlas, color: Color, radius: float) -> ArrayMesh:
	var boxes: Array = []
	var body := radius * 1.85
	var tint := _lighter(color, 0.06)
	_b(boxes, Vector3(0, 2, 0), Vector3(body, body, body), "flat", tint, {"front": "face_slime"})
	_b(boxes, Vector3(0, 0, 0), Vector3(body * 0.86, 3, body * 0.86), "flat", _darker(color, 0.8))
	return VoxelModel.mesh(atlas, boxes)


static func tower(atlas: PixelAtlas, color: Color, radius: float, height: float) -> ArrayMesh:
	var boxes: Array = []
	var stone := Color(0.86, 0.86, 0.86)
	var slab_h := height * 0.06
	var base_h := height * 0.12
	var mid_h := height * 0.40
	var top_h := height * 0.26
	_b(boxes, Vector3(0, 0, 0), Vector3(radius * 2.4, base_h, radius * 2.4), "stone_brick", stone)
	_b(boxes, Vector3(0, base_h, 0), Vector3(radius * 1.8, mid_h, radius * 1.8), "stone_brick", stone)
	_b(boxes, Vector3(0, base_h + mid_h - 10.0, 0), Vector3(radius * 1.92, 10, radius * 1.92), "flag", color)
	_b(boxes, Vector3(0, base_h + mid_h, 0), Vector3(radius * 1.5, top_h, radius * 1.5), "stone_brick", _darker(stone, 0.94))
	var slab_y := base_h + mid_h + top_h
	_b(boxes, Vector3(0, slab_y, 0), Vector3(radius * 1.9, slab_h, radius * 1.9), "planks", Color(0.95, 0.95, 0.95))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_b(boxes, Vector3(radius * 0.72 * sx, slab_y + slab_h, radius * 0.72 * sz),
				Vector3(14, height * 0.12, 14), "stone_brick", stone)
	var pole_y := slab_y + slab_h + height * 0.12
	_b(boxes, Vector3(0, pole_y, 0), Vector3(6, height * 0.16, 6), "log_side", Color(0.9, 0.9, 0.9))
	_b(boxes, Vector3(0, pole_y + height * 0.05, radius * 0.42), Vector3(4, height * 0.11, radius * 0.8), "flag", color)
	return VoxelModel.mesh(atlas, boxes)


static func base_pedestal(atlas: PixelAtlas, radius: float) -> ArrayMesh:
	var boxes: Array = []
	var stone := Color(0.84, 0.86, 0.84)
	var widths := [radius * 2.7, radius * 2.2, radius * 1.7]
	var heights := [14.0, 14.0, 12.0]
	var tops := [0.0, 14.0, 28.0]
	for layer in range(3):
		var w: float = widths[layer]
		var cell := w / 3.0
		for ix in range(3):
			for iz in range(3):
				var px := -w * 0.5 + cell * (float(ix) + 0.5)
				var pz := -w * 0.5 + cell * (float(iz) + 0.5)
				var tint := stone if layer > 0 else _darker(stone, 0.9)
				_b(boxes, Vector3(px, tops[layer], pz), Vector3(cell, heights[layer], cell), "stone", tint)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_b(boxes, Vector3(radius * 1.05 * sx, 40, radius * 1.05 * sz), Vector3(14, 26, 14), "stone_brick", stone)
	return VoxelModel.mesh(atlas, boxes)


static func base_crystal(atlas: PixelAtlas, color: Color, radius: float, height: float) -> ArrayMesh:
	var boxes: Array = []
	var gem := _lighter(color, 0.18)
	_b(boxes, Vector3(0, 0, 0), Vector3(radius * 1.05, height * 0.24, radius * 1.05), "crystal", gem)
	_b(boxes, Vector3(0, height * 0.24, 0), Vector3(radius * 0.78, height * 0.30, radius * 0.78), "crystal", gem)
	_b(boxes, Vector3(0, height * 0.54, 0), Vector3(radius * 0.52, height * 0.26, radius * 0.52), "crystal", _lighter(gem, 0.12))
	_b(boxes, Vector3(0, height * 0.80, 0), Vector3(radius * 0.26, height * 0.18, radius * 0.26), "glow", _lighter(gem, 0.3))
	return VoxelModel.mesh(atlas, boxes)


static func tree(atlas: PixelAtlas, variant: int, leaf: Color) -> ArrayMesh:
	var boxes: Array = []
	var trunk_h := 64.0 + float(variant % 3) * 18.0
	_b(boxes, Vector3(0, 0, 0), Vector3(22, trunk_h, 22), "log_side", Color(0.94, 0.94, 0.94),
		{"top": "log_top"})
	var y0 := trunk_h - 12.0
	_b(boxes, Vector3(0, y0, 0), Vector3(80, 30, 80), "leaves", _darker(leaf, 0.9))
	_b(boxes, Vector3(0, y0 + 24.0, 0), Vector3(58, 26, 58), "leaves", leaf)
	_b(boxes, Vector3(0, y0 + 46.0, 0), Vector3(32, 22, 32), "leaves", _lighter(leaf, 0.05))
	return VoxelModel.mesh(atlas, boxes)


static func rock(atlas: PixelAtlas, variant: int) -> ArrayMesh:
	var boxes: Array = []
	var stone := Color(0.8, 0.8, 0.8)
	var w := 34.0 + float(variant % 3) * 14.0
	_b(boxes, Vector3(0, 0, 0), Vector3(w, w * 0.62, w * 0.9), "stone", stone)
	_b(boxes, Vector3(w * 0.32, 0, w * 0.22), Vector3(w * 0.55, w * 0.44, w * 0.55), "stone", _darker(stone, 0.92))
	return VoxelModel.mesh(atlas, boxes)


static func mushroom(atlas: PixelAtlas) -> ArrayMesh:
	var boxes: Array = []
	_b(boxes, Vector3(0, 0, 0), Vector3(16, 28, 16), "planks", Color(0.97, 0.95, 0.88))
	_b(boxes, Vector3(0, 28, 0), Vector3(46, 18, 46), "mushroom", Color(0.92, 0.92, 0.92))
	_b(boxes, Vector3(0, 46, 0), Vector3(30, 10, 30), "mushroom", Color(0.86, 0.86, 0.86))
	return VoxelModel.mesh(atlas, boxes)


static func sign(atlas: PixelAtlas) -> ArrayMesh:
	var boxes: Array = []
	_b(boxes, Vector3(0, 0, 0), Vector3(9, 62, 9), "log_side", Color(0.9, 0.9, 0.9))
	_b(boxes, Vector3(0, 44, 0), Vector3(56, 24, 7), "planks", Color(1.0, 1.0, 1.0))
	_b(boxes, Vector3(-14, 52, 4.0), Vector3(18, 5, 2), "flat", Color(0.22, 0.16, 0.12))
	_b(boxes, Vector3(12, 52, 4.0), Vector3(12, 5, 2), "flat", Color(0.22, 0.16, 0.12))
	return VoxelModel.mesh(atlas, boxes)


static func ground_ring(atlas: PixelAtlas, radius: float, color: Color) -> ArrayMesh:
	var boxes: Array = []
	var t := 6.0
	var y := 1.2
	_b(boxes, Vector3(0, y, -radius), Vector3(radius * 2.0, 2, t), "flat", color)
	_b(boxes, Vector3(0, y, radius), Vector3(radius * 2.0, 2, t), "flat", color)
	_b(boxes, Vector3(-radius, y, 0), Vector3(t, 2, radius * 2.0), "flat", color)
	_b(boxes, Vector3(radius, y, 0), Vector3(t, 2, radius * 2.0), "flat", color)
	return VoxelModel.mesh(atlas, boxes)

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


const HEAD_PIVOT := Vector3(0, 56, 0)
const ARM_L_PIVOT := Vector3(-20, 52, 0)
const ARM_R_PIVOT := Vector3(20, 52, 0)
const LEG_L_PIVOT := Vector3(-8, 26, 0)
const LEG_R_PIVOT := Vector3(8, 26, 0)
const TAIL_PIVOT := Vector3(0, 34, -12)


static func hero(id: String, atlas: PixelAtlas, fur: Color, cream: Color, dark: Color, accent: Color) -> ArrayMesh:
	return VoxelModel.mesh(atlas, _hero_boxes(id, fur, cream, dark, accent))


static func hero_parts(id: String, atlas: PixelAtlas, fur: Color, cream: Color, dark: Color, accent: Color) -> Dictionary:
	# 把英雄拆成可独立旋转的部件，供战斗表现层摆动四肢。
	var pivots := {
		"body": Vector3.ZERO,
		"head": HEAD_PIVOT,
		"arm_l": ARM_L_PIVOT,
		"arm_r": ARM_R_PIVOT,
		"leg_l": LEG_L_PIVOT,
		"leg_r": LEG_R_PIVOT,
		"tail": TAIL_PIVOT,
	}
	var buckets := {
		"body": [], "head": [], "arm_l": [], "arm_r": [], "leg_l": [], "leg_r": [], "tail": [],
	}
	for b in _hero_boxes(id, fur, cream, dark, accent):
		var part := _part_of(b)
		var pivot: Vector3 = pivots[part]
		var nb: Dictionary = b.duplicate()
		nb["pos"] = (b["pos"] as Vector3) - pivot
		buckets[part].append(nb)
	var meshes := {}
	for part in buckets:
		meshes[part] = VoxelModel.mesh(atlas, buckets[part])
	return {"mesh": meshes, "pivots": pivots}


static func _part_of(b: Dictionary) -> String:
	var pos: Vector3 = b.get("pos", Vector3.ZERO)
	var size: Vector3 = b.get("size", Vector3.ONE)
	if pos.z + size.z * 0.5 <= 0.0 and pos.y < 56.0:
		return "tail"
	if pos.y + size.y <= 27.0 and absf(pos.x) >= 1.0:
		return "leg_l" if pos.x < 0.0 else "leg_r"
	if absf(pos.x) >= 15.0 and pos.y < 56.0:
		return "arm_l" if pos.x < 0.0 else "arm_r"
	if pos.y >= 56.0:
		return "head"
	return "body"


static func _hero_boxes(id: String, fur: Color, cream: Color, dark: Color, accent: Color) -> Array:
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
				_b(boxes, Vector3(8.5 * sx, 39, 10.4), Vector3(7, 18, 2), "flat", accent)
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
	return boxes


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


static func minion(atlas: PixelAtlas, color: Color, radius: float, team: int) -> ArrayMesh:
	# 蓝方：圆润小果冻 + 头顶嫩芽；红方：高瘦尖刺怪 + 怒脸。
	var boxes: Array = []
	var tint := _lighter(color, 0.06)
	if team == 1:
		var body := radius * 1.9
		var bh := radius * 2.15
		_b(boxes, Vector3(0, 2, 0), Vector3(body, bh, body), "flat", tint, {"front": "face_angry"})
		_b(boxes, Vector3(0, 0, 0), Vector3(body * 0.9, 3, body * 0.9), "flat", _darker(color, 0.72))
		for i in range(3):
			var sx := float(i - 1) * radius * 0.62
			var sh := 10.0 + float(i % 2) * 6.0
			_b(boxes, Vector3(sx, bh + 2.0, 0), Vector3(8, sh, 8), "stone", _darker(color, 0.5))
			_b(boxes, Vector3(sx, bh + 2.0 + sh, 0), Vector3(6, 4, 6), "glow", Color("ffb36b"))
		for sx in [-1, 1]:
			_b(boxes, Vector3(sx * radius * 1.08, 8.0, 0), Vector3(6, radius * 0.9, radius * 1.25),
				"stone", Color("5a3a32"))
	else:
		var body := radius * 1.85
		_b(boxes, Vector3(0, 2, 0), Vector3(body, body, body), "flat", tint, {"front": "face_slime"})
		_b(boxes, Vector3(0, 0, 0), Vector3(body * 0.86, 3, body * 0.86), "flat", _darker(color, 0.8))
		_b(boxes, Vector3(0, body + 2.0, 0), Vector3(5, 10, 5), "log_side", Color("6fae4a"))
		_b(boxes, Vector3(0, body + 12.0, 0), Vector3(15, 6, 9), "leaves", Color("7fcf5a"))
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


static func base_pedestal(atlas: PixelAtlas, radius: float, team: int) -> ArrayMesh:
	# 蓝方：月光石台 + 冰晶柱 + 浅冰环；红方：暗石台 + 岩浆裂缝 + 尖石柱。
	var boxes: Array = []
	var stone := Color(0.82, 0.90, 0.96) if team == 0 else Color(0.52, 0.44, 0.42)
	var tile := "stone" if team == 0 else "stone_brick"
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
				_b(boxes, Vector3(px, tops[layer], pz), Vector3(cell, heights[layer], cell), tile, tint)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			if team == 0:
				_b(boxes, Vector3(radius * 1.05 * sx, 40, radius * 1.05 * sz), Vector3(14, 26, 14),
					"ice", Color(0.88, 0.98, 1.0))
				_b(boxes, Vector3(radius * 1.05 * sx, 66, radius * 1.05 * sz), Vector3(8, 12, 8),
					"ice", Color(0.95, 1.0, 1.0))
			else:
				_b(boxes, Vector3(radius * 1.05 * sx, 34, radius * 1.05 * sz), Vector3(16, 18, 16),
					"stone_brick", Color(0.34, 0.30, 0.30))
				_b(boxes, Vector3(radius * 1.05 * sx, 52, radius * 1.05 * sz), Vector3(10, 16, 10),
					"lava", Color(0.95, 0.6, 0.35))
	if team == 0:
		_b(boxes, Vector3(0, 40, 0), Vector3(radius * 2.15, 1, radius * 2.15), "ice", Color(0.72, 0.94, 1.0))
	else:
		for i in range(4):
			var a := float(i) * PI * 0.5
			var px := cos(a) * radius * 1.25
			var pz := sin(a) * radius * 1.25
			_b(boxes, Vector3(px, 40, pz), Vector3(radius * 0.8, 2, radius * 0.5), "lava", Color(0.95, 0.55, 0.3))
	return VoxelModel.mesh(atlas, boxes)


static func base_crystal(atlas: PixelAtlas, color: Color, radius: float, height: float, team: int) -> ArrayMesh:
	var boxes: Array = []
	if team == 0:
		# 高而尖的月光水晶，两侧小晶体 + 顶部悬浮星。
		var gem := _lighter(color, 0.22)
		_b(boxes, Vector3(0, 0, 0), Vector3(radius * 1.0, height * 0.22, radius * 1.0), "crystal", gem)
		_b(boxes, Vector3(0, height * 0.22, 0), Vector3(radius * 0.72, height * 0.32, radius * 0.72), "crystal", gem)
		_b(boxes, Vector3(0, height * 0.54, 0), Vector3(radius * 0.44, height * 0.28, radius * 0.44),
			"crystal", _lighter(gem, 0.10))
		_b(boxes, Vector3(0, height * 0.82, 0), Vector3(radius * 0.20, height * 0.16, radius * 0.20),
			"glow", _lighter(gem, 0.35))
		for sx in [-1, 1]:
			_b(boxes, Vector3(radius * 0.62 * sx, 0, radius * 0.1), Vector3(radius * 0.30, height * 0.30, radius * 0.30),
				"crystal", _lighter(gem, 0.05))
			_b(boxes, Vector3(radius * 0.42 * sx, height * 0.30, radius * 0.1),
				Vector3(radius * 0.20, height * 0.12, radius * 0.20), "glow", Color(0.9, 0.98, 1.0))
		_b(boxes, Vector3(0, height * 1.02, 0), Vector3(10, 10, 10), "glow", Color(1, 1, 0.95))
	else:
		# 宽底熔岩水晶，三根高低尖刺 + 暗色熔岩底座。
		_b(boxes, Vector3(0, 0, 0), Vector3(radius * 1.18, height * 0.16, radius * 1.18), "lava", Color(0.9, 0.5, 0.28))
		_b(boxes, Vector3(0, height * 0.16, 0), Vector3(radius * 0.92, height * 0.20, radius * 0.92),
			"crystal", _darker(color, 0.78))
		for i in range(3):
			var sx := float(i - 1) * radius * 0.42
			var hh := height * (0.24 + 0.07 * float(i))
			_b(boxes, Vector3(sx, height * 0.34, float(i % 2) * 6.0 - 3.0),
				Vector3(radius * 0.28, hh, radius * 0.28), "crystal", _lighter(color, 0.06))
			_b(boxes, Vector3(sx, height * 0.34 + hh, float(i % 2) * 6.0 - 3.0),
				Vector3(radius * 0.16, height * 0.08, radius * 0.16), "glow", Color(1.0, 0.72, 0.35))
		_b(boxes, Vector3(0, height * 0.34, 0), Vector3(radius * 0.22, height * 0.44, radius * 0.22),
			"crystal", _lighter(color, 0.12))
	return VoxelModel.mesh(atlas, boxes)


static func tower_ruins(atlas: PixelAtlas, color: Color, radius: float) -> ArrayMesh:
	# 塔废墟：比原塔矮一半的断柱 + 塌落的石砖 + 倒下的旗杆和破旗。
	var boxes: Array = []
	var stone := Color(0.90, 0.90, 0.90)
	_b(boxes, Vector3(0, 0, 0), Vector3(radius * 2.35, 8, radius * 2.35), "stone", Color(0.82, 0.82, 0.82))
	_b(boxes, Vector3(-radius * 0.30, 8, radius * 0.12), Vector3(radius * 1.30, 28, radius * 1.12),
		"stone_brick", stone)
	_b(boxes, Vector3(radius * 0.48, 8, -radius * 0.22), Vector3(radius * 0.82, 42, radius * 0.78),
		"stone_brick", _darker(stone, 0.92))
	_b(boxes, Vector3(-radius * 0.08, 36, -radius * 0.15), Vector3(radius * 0.62, 12, radius * 0.55),
		"stone_brick", _lighter(stone, 0.05))
	# 断口碎石
	_b(boxes, Vector3(radius * 0.52, 50, -radius * 0.2), Vector3(11, 9, 11), "stone", _darker(stone, 0.85))
	_b(boxes, Vector3(-radius * 0.45, 32, radius * 0.4), Vector3(9, 7, 9), "stone", _darker(stone, 0.8))
	# 塌落的木顶
	_b(boxes, Vector3(radius * 0.85, 3, radius * 0.35), Vector3(radius * 1.15, 5, radius * 0.85),
		"planks", Color(0.82, 0.82, 0.82))
	# 倒下的旗杆
	_b(boxes, Vector3(-radius * 0.15, 8, radius * 1.15), Vector3(radius * 2.0, 5, 5),
		"log_side", Color(0.85, 0.85, 0.85))
	# 挂在断柱上的破旗
	_b(boxes, Vector3(radius * 0.62, 24, -radius * 0.62), Vector3(4, 16, radius * 0.72), "flag", color)
	# 周围散落碎石
	for i in range(5):
		var ang := float(i) * 1.26
		var rx := cos(ang) * radius * 1.55
		var rz := sin(ang) * radius * 1.35
		_b(boxes, Vector3(rx, 0, rz), Vector3(radius * 0.26, 6 + float(i % 3) * 4.0, radius * 0.24),
			"stone", Color(0.62, 0.62, 0.62))
	return VoxelModel.mesh(atlas, boxes)


static func base_ruins(atlas: PixelAtlas, color: Color, radius: float, height: float) -> ArrayMesh:
	var boxes: Array = []
	var stone := Color(0.78, 0.78, 0.76)
	_b(boxes, Vector3(0, 0, 0), Vector3(radius * 2.5, 9, radius * 2.5), "stone", Color(0.66, 0.66, 0.64))
	_b(boxes, Vector3(-radius * 0.55, 9, radius * 0.2), Vector3(radius * 1.2, 15, radius * 1.1),
		"stone_brick", stone)
	_b(boxes, Vector3(radius * 0.55, 9, -radius * 0.25), Vector3(radius * 0.95, 24, radius * 0.85),
		"stone_brick", _darker(stone, 0.88))
	# 碎水晶残片：高低错落，仍带队伍色
	_b(boxes, Vector3(-radius * 0.28, 16, radius * 0.35), Vector3(radius * 0.32, height * 0.20, radius * 0.32),
		"crystal", _darker(color, 0.82))
	_b(boxes, Vector3(radius * 0.35, 12, -radius * 0.28), Vector3(radius * 0.26, height * 0.26, radius * 0.26),
		"crystal", _darker(color, 0.68))
	_b(boxes, Vector3(radius * 0.05, 8, radius * 0.55), Vector3(radius * 0.22, height * 0.13, radius * 0.22),
		"crystal", _darker(color, 0.58))
	# 地面裂痕
	_b(boxes, Vector3(0, 0, radius * 1.1), Vector3(radius * 1.5, 1, radius * 0.3), "lava", Color(0.9, 0.55, 0.3))
	# 周围碎块
	for i in range(4):
		var ang := 0.4 + float(i) * 1.35
		_b(boxes, Vector3(cos(ang) * radius * 1.5, 0, sin(ang) * radius * 1.4),
			Vector3(radius * 0.22, 6 + float(i % 2) * 5.0, radius * 0.22), "stone", Color(0.55, 0.53, 0.52))
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

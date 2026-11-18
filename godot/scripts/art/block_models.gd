class_name BlockModels
extends RefCounted

# 方块体素模型库：英雄、小兵、塔、水晶、树、石头、蘑菇、路牌、药瓶、云、脚下队环。
# 全部按「16 单位 ≈ 1 个方块」的比例搭建，保持粗颗粒的方块游戏观感。
# 4.14 起造型与配色对齐宣传片：腮红/眼高光、navy 裤深色鞋、队伍配饰、奶油石建筑。

const SHOE := Color("3a3432")
const SCARF_GREEN := Color("60a868")
const SCARF_RED := Color("e0604f")
const NAVY := Color("485474")
const GOLD := Color("f2c14e")
const PINK := Color("f6aebc")
const BLUSH := Color("f49ea6")
const MOSS := Color("6c9852")
const BOSS_STONE := Color("8a867e")
const BOSS_DARK := Color("5f5b54")
const BERRY := Color("d8485a")


static func _b(boxes: Array, pos: Vector3, size: Vector3, tile: String, tint: Color, faces := {},
		part := "") -> void:
	var b: Dictionary = VoxelModel.box(pos, size, tile, tint, faces)
	if part != "":
		b["part"] = part
	boxes.append(b)


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


static func hero(id: String, atlas: PixelAtlas, fur: Color, cream: Color, dark: Color, accent: Color,
		pants := "navy") -> ArrayMesh:
	return VoxelModel.mesh(atlas, _hero_boxes(id, fur, cream, dark, accent, pants))


static func hero_parts(id: String, atlas: PixelAtlas, fur: Color, cream: Color, dark: Color, accent: Color,
		pants := "navy") -> Dictionary:
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
	for b in _hero_boxes(id, fur, cream, dark, accent, pants):
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
	# 显式归属优先（背包、背鳍这类跨部件配件），其余按包围盒位置推断。
	if b.has("part"):
		return str(b["part"])
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


static func _hero_boxes(id: String, fur: Color, cream: Color, dark: Color, accent: Color,
		pants := "navy") -> Array:
	var boxes: Array = []
	_humanoid_base(boxes, fur, cream, dark, accent, pants)
	match id:
		"tiger":
			# 老虎：黑条纹 + 圆耳 + 上翘长尾 + 绿围巾 + 左臂木盾。
			for sx in [-1, 1]:
				_b(boxes, Vector3(9.5 * sx, 75, 0), Vector3(8, 10, 8), "fur", fur)
				_b(boxes, Vector3(9.5 * sx, 77, 3.6), Vector3(5, 5, 2), "flat", cream)
				_b(boxes, Vector3(11.4 * sx, 62, 12.7), Vector3(3, 12, 2), "flat", dark)
				_b(boxes, Vector3(20.0 * sx, 40, 0), Vector3(10.6, 3, 10.6), "flat", dark)
				_b(boxes, Vector3(20.0 * sx, 48, 0), Vector3(10.6, 3, 10.6), "flat", dark)
			_b(boxes, Vector3(0, 72, 12.7), Vector3(12, 3, 2), "flat", dark)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(9, 8, 1), "flat", cream)
			# 绿围巾环 + 前垂巾
			_b(boxes, Vector3(0, 52, 0), Vector3(32, 6, 26), "flat", SCARF_GREEN)
			_b(boxes, Vector3(4, 38, 12.4), Vector3(7, 14, 2), "flat", SCARF_GREEN)
			# 左臂圆盾：三层盒子拼出圆盾轮廓 + 绿盾心
			_b(boxes, Vector3(-26.5, 34, 1), Vector3(4, 14, 22), "wood", Color.WHITE)
			_b(boxes, Vector3(-26.5, 30, 1), Vector3(4, 22, 14), "wood", Color.WHITE)
			_b(boxes, Vector3(-28.8, 38, 1), Vector3(1.6, 8, 8), "flat", SCARF_GREEN)
			_b(boxes, Vector3(10, 34, -14), Vector3(7, 7, 16), "fur", fur)
			_b(boxes, Vector3(10, 40, -26), Vector3(7, 7, 12), "fur", fur)
			_b(boxes, Vector3(10, 46, -33), Vector3(7, 7, 6), "flat", dark)
		"fox":
			# 狐狸：尖耳 + 白脸颊 + 上翘蓬松大尾 + 紫巫师帽/紫袍 + 星杖。
			for sx in [-1, 1]:
				_b(boxes, Vector3(8.5 * sx, 75, 0), Vector3(7, 14, 7), "fur", fur)
				_b(boxes, Vector3(8.5 * sx, 77, 3.6), Vector3(3, 9, 2), "flat", cream)
				_b(boxes, Vector3(7.5 * sx, 66, 12.7), Vector3(5, 5, 2), "flat", dark)
			_b(boxes, Vector3(0, 58, 12.6), Vector3(24, 7, 2), "flat", cream)
			_b(boxes, Vector3(0, 60, 13.0), Vector3(5, 3, 1), "flat", dark)
			# 巫师帽：檐 37×4×35 / 身 24×18 / 斜顶 16×13 + 金星
			_b(boxes, Vector3(0, 78, 0), Vector3(37, 4, 35), "purple", Color.WHITE)
			_b(boxes, Vector3(0, 82, 0), Vector3(24, 18, 24), "purple", Color.WHITE)
			_b(boxes, Vector3(1.5, 100, -1), Vector3(16, 13, 16), "purple_light", Color.WHITE)
			_b(boxes, Vector3(0, 88, 12.6), Vector3(5, 5, 2), "gold", Color.WHITE)
			# 紫袍摆 + 浅紫边
			_b(boxes, Vector3(0, 26, 0), Vector3(33, 20, 25), "purple", Color.WHITE)
			_b(boxes, Vector3(0, 26, 0), Vector3(35, 5, 27), "purple_light", Color.WHITE)
			# 右臂星杖：金杆 + 金色十字星
			_b(boxes, Vector3(27, 28, 6), Vector3(4, 58, 4), "gold", Color.WHITE)
			_b(boxes, Vector3(27, 84, 6), Vector3(10, 10, 4), "gold", Color.WHITE, {}, "arm_r")
			_b(boxes, Vector3(27, 87, 6), Vector3(20, 4, 4), "gold", Color.WHITE, {}, "arm_r")
			_b(boxes, Vector3(9, 32, -14), Vector3(13, 13, 14), "fur", fur)
			_b(boxes, Vector3(9, 36, -25), Vector3(16, 16, 14), "fur", fur)
			_b(boxes, Vector3(9, 42, -34), Vector3(10, 10, 8), "flat", cream)
		"rabbit":
			# 兔子：长耳 + 粉内耳 + 毛球尾 + 花环 + 粉裙 + 蝴蝶结。
			for sx in [-1, 1]:
				_b(boxes, Vector3(6.5 * sx, 75, 0), Vector3(6, 23, 5), "fur", cream)
				_b(boxes, Vector3(6.5 * sx, 77, 2.8), Vector3(3, 17, 2), "flat", Color("f0a8c0"))
				_b(boxes, Vector3(5.5 * sx, 66, 12.7), Vector3(4, 4, 2), "flat", dark)
			_b(boxes, Vector3(0, 60, 13.0), Vector3(4, 3, 2), "flat", Color("e888a8"))
			# 头顶花环：8 朵小花 pink/white/gold 循环
			var wreath_cols := ["pink", "flat", "gold", "pink", "flat", "pink", "pink", "gold"]
			for k in range(8):
				var ang := TAU * float(k) / 8.0
				_b(boxes, Vector3(cos(ang) * 11.5, 78, sin(ang) * 10.0), Vector3(5, 5, 5),
					wreath_cols[k], Color.WHITE)
			# 粉裙 + 白裙摆 + 胸前蝴蝶结
			_b(boxes, Vector3(0, 26, 0), Vector3(33, 18, 25), "pink", Color.WHITE)
			_b(boxes, Vector3(0, 26, 0), Vector3(35, 5, 27), "flat", Color.WHITE)
			_b(boxes, Vector3(-4.5, 46, 13.0), Vector3(7, 5, 2), "pink", Color.WHITE)
			_b(boxes, Vector3(4.5, 46, 13.0), Vector3(7, 5, 2), "pink", Color.WHITE)
			_b(boxes, Vector3(0, 46.5, 13.4), Vector3(4, 4, 2), "flat", Color.WHITE)
			_b(boxes, Vector3(8, 30, -13), Vector3(11, 11, 10), "fur", cream)
		"bear":
			# 熊：圆耳 + 大吻部 + 绿领巾 + 左臂小圆盾 + 短尾 + 粗壮身形。
			for sx in [-1, 1]:
				_b(boxes, Vector3(9.5 * sx, 74, 0), Vector3(10, 10, 9), "fur", _darker(fur, 0.9))
				_b(boxes, Vector3(9.5 * sx, 76, 3.8), Vector3(5, 5, 2), "flat", cream)
				_b(boxes, Vector3(6.5 * sx, 68, 12.7), Vector3(5, 5, 2), "flat", dark)
			_b(boxes, Vector3(0, 58, 12.6), Vector3(20, 11, 2), "flat", cream)
			_b(boxes, Vector3(0, 61, 13.2), Vector3(7, 4, 2), "flat", dark)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(9, 9, 1), "flat", cream)
			# 绿领巾 + 前垂尖
			_b(boxes, Vector3(0, 52, 0), Vector3(33, 7, 26), "flat", SCARF_GREEN)
			_b(boxes, Vector3(0, 43, 13.2), Vector3(10, 8, 2), "flat", SCARF_GREEN)
			_b(boxes, Vector3(0, 38, 13.2), Vector3(6, 6, 2), "flat", SCARF_GREEN)
			# 左臂小圆盾：三层盒子拼出圆盾轮廓 + 金盾心
			_b(boxes, Vector3(-26.5, 36, 1), Vector3(4, 12, 20), "wood", Color.WHITE)
			_b(boxes, Vector3(-26.5, 32, 1), Vector3(4, 20, 12), "wood", Color.WHITE)
			_b(boxes, Vector3(-28.8, 38, 1), Vector3(1.6, 7, 7), "gold", Color.WHITE)
			_b(boxes, Vector3(8, 32, -12), Vector3(9, 9, 8), "fur", cream)
		"frog":
			# 青蛙：头顶大眼 + 宽嘴 + 荷叶帽 + 粉花 + 浅色肚皮。
			for sx in [-1, 1]:
				_b(boxes, Vector3(8.5 * sx, 75, 3), Vector3(12, 10, 12), "fur", cream)
				_b(boxes, Vector3(8.5 * sx, 77, 9.2), Vector3(6, 5, 2), "flat", dark)
			_b(boxes, Vector3(0, 62, 12.7), Vector3(16, 3, 2), "flat", dark)
			_b(boxes, Vector3(0, 30, 10.2), Vector3(24, 16, 2), "flat", cream)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(8, 7, 1), "flat", accent)
			# 荷叶帽 + 粉花
			_b(boxes, Vector3(0, 84, 0), Vector3(32, 4, 28), "leaves", Color("6fae4a"))
			_b(boxes, Vector3(7, 88, 5), Vector3(6, 5, 6), "pink", Color.WHITE)
			_b(boxes, Vector3(7, 92, 5), Vector3(3, 3, 3), "gold", Color.WHITE)
			_b(boxes, Vector3(-8, 88, -4), Vector3(4.5, 4, 4.5), "pink", Color.WHITE)
			_b(boxes, Vector3(-8, 91.5, -4), Vector3(2.4, 2.4, 2.4), "gold", Color.WHITE)
		"cat":
			# 猫：尖耳 + 胡须 + 上翘细尾 + 青围巾 + 金铃。
			for sx in [-1, 1]:
				_b(boxes, Vector3(8.5 * sx, 75, 0), Vector3(7, 11, 6), "fur", fur)
				_b(boxes, Vector3(8.5 * sx, 77, 3.4), Vector3(3, 6, 2), "flat", accent)
				for k in range(3):
					_b(boxes, Vector3(12.3 * sx, 60.0 + float(k) * 2.6, 12.7), Vector3(5, 1, 2), "flat", cream)
			_b(boxes, Vector3(0, 60, 13.0), Vector3(5, 4, 2), "flat", Color("e888a8"))
			_b(boxes, Vector3(0, 52, 0), Vector3(32, 6, 25), "flat", accent)
			_b(boxes, Vector3(0, 44, 13.0), Vector3(6.5, 6.5, 4), "gold", Color.WHITE)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(8, 7, 1), "flat", accent)
			_b(boxes, Vector3(9, 32, -14), Vector3(5, 6, 16), "fur", fur)
			_b(boxes, Vector3(9, 40, -26), Vector3(5, 6, 12), "fur", _darker(fur, 0.7))
		"panda":
			# 熊猫：黑耳朵 + 黑眼圈 + 黑臂环/腿环 + 竹绿围巾 + 右臂竹竿。
			for sx in [-1, 1]:
				_b(boxes, Vector3(9.5 * sx, 75, 0), Vector3(10, 10, 9), "fur", dark)
				_b(boxes, Vector3(6.0 * sx, 66, 12.7), Vector3(7, 7, 2), "flat", dark)
				_b(boxes, Vector3(20.0 * sx, 30, 0), Vector3(11, 18, 11), "fur", dark)
				_b(boxes, Vector3(8.0 * sx, 0, 0), Vector3(14, 18, 14), "fur", dark)
			_b(boxes, Vector3(0, 60, 13.0), Vector3(8, 4, 2), "flat", cream)
			_b(boxes, Vector3(0, 62, 13.4), Vector3(4, 2, 1), "flat", Color("1a1a1a"))
			_b(boxes, Vector3(0, 52, 0), Vector3(31, 6, 24), "flat", accent)
			_b(boxes, Vector3(0, 40, 10.2), Vector3(14, 12, 1), "flat", cream)
			# 右臂竹竿
			_b(boxes, Vector3(27, 28, 4), Vector3(4, 56, 4), "leaves", Color("7cbf4a"))
			_b(boxes, Vector3(27, 42, 4), Vector3(5.4, 3, 5.4), "leaves", Color("4e8c34"))
			_b(boxes, Vector3(27, 56, 4), Vector3(5.4, 3, 5.4), "leaves", Color("4e8c34"))
			_b(boxes, Vector3(31, 78, 4), Vector3(10, 4, 3), "leaves", Color("9bd968"), {}, "arm_r")
			_b(boxes, Vector3(0, 32, -12), Vector3(9, 9, 8), "fur", dark)
		"owl":
			# 猫头鹰：耳羽 + 大圆眼 + 金色喙 + 深色翅膀 + 学者巾 + 金星徽。
			for sx in [-1, 1]:
				_b(boxes, Vector3(9.0 * sx, 76, 0), Vector3(7, 12, 7), "fur", dark)
				_b(boxes, Vector3(7.0 * sx, 66, 12.9), Vector3(8, 8, 2), "flat", cream)
				_b(boxes, Vector3(6.5 * sx, 69, 13.5), Vector3(4, 4, 1), "flat", dark)
				_b(boxes, Vector3(20.0 * sx, 28, 0), Vector3(12, 24, 14), "fur", dark)
				_b(boxes, Vector3(20.0 * sx, 30, 8), Vector3(6, 6, 2), "flat", cream)
			_b(boxes, Vector3(0, 59, 13.2), Vector3(5, 7, 5), "flat", accent)
			_b(boxes, Vector3(0, 38, 10.2), Vector3(20, 18, 1), "flat", cream)
			_b(boxes, Vector3(0, 52, 0), Vector3(31, 7, 25), "navy", Color.WHITE)
			_b(boxes, Vector3(0, 46, 13.0), Vector3(6, 6, 2), "gold", Color.WHITE)
			_b(boxes, Vector3(12, 44, 11.0), Vector3(2.6, 8, 2.6), "gold", Color.WHITE)
			_b(boxes, Vector3(0, 30, -13), Vector3(12, 12, 10), "fur", dark)
			_b(boxes, Vector3(0, 36, -21), Vector3(8, 8, 8), "fur", _darker(fur, 0.8))
		"axolotl":
			# 美西螈：两侧三簇粉色外鳃 + 奶油肚皮 + 背部小鳍 + 扁尾鳍。
			for sx in [-1, 1]:
				for k in range(3):
					var gy := 66.0 + float(k) * 5.2
					_b(boxes, Vector3((15.5 + float(k) * 1.1) * sx, gy, -1.0),
						Vector3(7, 3, 5), "flat", PINK)
					_b(boxes, Vector3((18.5 + float(k) * 1.4) * sx, gy + 1.2, -1.0),
						Vector3(4, 2, 3), "flat", BLUSH)
				_b(boxes, Vector3(8.5 * sx, 69, 12.7), Vector3(5, 4, 2), "flat", dark)
			_b(boxes, Vector3(0, 58, 12.7), Vector3(19, 7, 2), "flat", cream)
			_b(boxes, Vector3(0, 44, 10.3), Vector3(18, 13, 1), "flat", cream)
			_b(boxes, Vector3(0, 52, 0), Vector3(28, 4, 22), "flat", accent)
			_b(boxes, Vector3(10, 34, -14), Vector3(8, 10, 12), "fur", accent)
			_b(boxes, Vector3(10, 28, -24), Vector3(14, 3, 12), "flat", _lighter(accent, 0.10))
			# 背部小鳍
			_b(boxes, Vector3(0, 40, -13), Vector3(4, 12, 7), "pink", Color.WHITE, {}, "body")
		"deer":
			# 小鹿：分叉鹿角 + 长耳 + 白斑点 + 左胯奶油挎包 + 短尾。
			for sx in [-1, 1]:
				_b(boxes, Vector3(9.0 * sx, 76, 0), Vector3(4, 8, 4), "flat", accent)
				_b(boxes, Vector3(9.0 * sx, 83, 0), Vector3(3, 7, 3), "flat", _lighter(accent, 0.08))
				_b(boxes, Vector3(13.0 * sx, 81, 0), Vector3(6, 3, 3), "flat", _lighter(accent, 0.08))
				_b(boxes, Vector3(6.0 * sx, 85, 0), Vector3(5, 3, 3), "flat", _lighter(accent, 0.08))
				_b(boxes, Vector3(8.0 * sx, 70, 0), Vector3(6, 13, 5), "fur", fur)
				_b(boxes, Vector3(8.0 * sx, 72, 2.8), Vector3(3, 9, 2), "flat", cream)
				_b(boxes, Vector3(8.0 * sx, 66, 12.7), Vector3(5, 4, 2), "flat", dark)
			_b(boxes, Vector3(0, 59, 12.7), Vector3(17, 6, 2), "flat", cream)
			_b(boxes, Vector3(0, 61, 13.2), Vector3(5, 2, 1), "flat", dark)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(8, 9, 1), "flat", cream)
			for sx in [-1, 1]:
				_b(boxes, Vector3(6.5 * sx, 36, 10.3), Vector3(3, 3, 1), "flat", cream)
				_b(boxes, Vector3(9.5 * sx, 30, 10.3), Vector3(2, 2, 1), "flat", cream)
			# 左胯奶油挎包 + 肩带
			_b(boxes, Vector3(-14, 18, 10), Vector3(9, 12, 9), "cream", Color.WHITE, {}, "body")
			_b(boxes, Vector3(-14, 28, 10.4), Vector3(9.6, 3, 9.4), "wood", Color.WHITE, {}, "body")
			_b(boxes, Vector3(-13, 30, 10.8), Vector3(2, 20, 1.5), "wood", Color.WHITE, {}, "body")
			_b(boxes, Vector3(9, 32, -13), Vector3(7, 7, 9), "fur", cream)
		"turtle":
			# 小龟：背甲 + 腹甲 + 小头 + 蹼手 + 红侦察巾。
			_b(boxes, Vector3(0, 24, -14), Vector3(32, 34, 13), "stone", _darker(fur, 0.72))
			_b(boxes, Vector3(0, 27, -20), Vector3(24, 24, 3), "flat", accent)
			_b(boxes, Vector3(0, 44, 10.3), Vector3(22, 15, 1), "flat", cream)
			for sx in [-1, 1]:
				_b(boxes, Vector3(8.0 * sx, 66, 12.7), Vector3(5, 4, 2), "flat", dark)
				_b(boxes, Vector3(15.0 * sx, 23, 0), Vector3(7, 10, 12), "fur", _darker(fur, 0.88))
			_b(boxes, Vector3(0, 59, 12.9), Vector3(6, 4, 1), "flat", dark)
			_b(boxes, Vector3(0, 52, 0), Vector3(32, 6, 25), "flat", SCARF_RED)
			_b(boxes, Vector3(-11, 46, 11.0), Vector3(5, 5, 3), "flat", SCARF_RED)
			_b(boxes, Vector3(8, 30, -13), Vector3(8, 7, 8), "fur", _darker(fur, 0.8))
		"hedgehog":
			# 刺猬：头背尖刺 + 奶油脸 + 红围巾 + 浆果背袋。
			for sx in [-1, 1]:
				for k in range(3):
					_b(boxes, Vector3((12.0 + k * 2.0) * sx, 65.0 + k * 5.0, -3.0),
						Vector3(6, 9, 6), "flat", dark)
				_b(boxes, Vector3(13.0 * sx, 34, -8), Vector3(8, 12, 9), "flat", dark)
			for k in range(3):
				_b(boxes, Vector3(float(k - 1) * 11.0, 48.0 + float(k % 2) * 6.0, -14),
					Vector3(8, 10, 8), "flat", _darker(dark, 0.9))
			_b(boxes, Vector3(0, 58, 12.7), Vector3(18, 8, 2), "flat", cream)
			_b(boxes, Vector3(0, 61, 13.2), Vector3(6, 3, 1), "flat", dark)
			_b(boxes, Vector3(0, 52, 0), Vector3(31, 7, 25), "flat", SCARF_RED)
			# 浆果背袋（跟随躯干，不跟尾巴）
			_b(boxes, Vector3(0, 38, -17), Vector3(10, 9, 7), "wood", Color.WHITE, {}, "body")
			_b(boxes, Vector3(0, 40, 10.6), Vector3(3, 14, 1.2), "wood", Color.WHITE, {}, "body")
			_b(boxes, Vector3(-1, 48, -18.5), Vector3(2.6, 2.6, 2.6), "flat", BERRY, {}, "body")
			_b(boxes, Vector3(-3, 46, -18), Vector3(3, 3, 3), "flat", BERRY, {}, "body")
			_b(boxes, Vector3(1, 47, -19), Vector3(2.6, 2.6, 2.6), "flat", BLUSH, {}, "body")
			_b(boxes, Vector3(3, 45.5, -17), Vector3(2.6, 2.6, 2.6), "flat", BERRY, {}, "body")
			_b(boxes, Vector3(8, 30, -13), Vector3(8, 8, 8), "flat", dark)
		"redpanda":
			# 小熊猫：红棕身体 + 深色四肢 + 环纹大尾 + 金围巾 + 奶油尾尖。
			for sx in [-1, 1]:
				_b(boxes, Vector3(9.0 * sx, 74, 0), Vector3(8, 10, 7), "fur", dark)
				_b(boxes, Vector3(9.0 * sx, 76, 3.5), Vector3(4, 4, 2), "flat", cream)
				_b(boxes, Vector3(20.0 * sx, 12, 0), Vector3(10, 18, 10), "flat", dark)
				_b(boxes, Vector3(8.0 * sx, 0, 0), Vector3(13, 16, 13), "flat", dark)
			_b(boxes, Vector3(0, 58, 12.7), Vector3(19, 9, 2), "flat", cream)
			_b(boxes, Vector3(0, 61, 13.2), Vector3(6, 3, 1), "flat", dark)
			_b(boxes, Vector3(0, 52, 0), Vector3(31, 6, 24), "flat", GOLD)
			_b(boxes, Vector3(0, 42, 10.2), Vector3(12, 9, 1), "flat", cream)
			_b(boxes, Vector3(10, 32, -14), Vector3(9, 9, 16), "fur", fur)
			_b(boxes, Vector3(10, 39, -27), Vector3(9, 9, 11), "flat", cream)
		"wolf":
			# 小狼：尖耳 + 灰毛 + 深色吻部 + 深蓝围巾 + 白牙项链 + 长尾。
			for sx in [-1, 1]:
				_b(boxes, Vector3(8.5 * sx, 75, 0), Vector3(7, 13, 7), "fur", dark)
				_b(boxes, Vector3(8.5 * sx, 77, 3.6), Vector3(3, 8, 2), "flat", cream)
				_b(boxes, Vector3(8.0 * sx, 66, 12.7), Vector3(4, 4, 2), "flat", dark)
			_b(boxes, Vector3(0, 59, 12.7), Vector3(17, 7, 2), "flat", cream)
			_b(boxes, Vector3(0, 61, 13.2), Vector3(5, 3, 1), "flat", dark)
			_b(boxes, Vector3(0, 52, 0), Vector3(31, 6, 24), "navy", Color.WHITE)
			for k in range(3):
				_b(boxes, Vector3(float(k - 1) * 4.5, 44.6, 13.0), Vector3(3.2, 5.0, 1.8), "flat",
					Color(0.97, 0.97, 0.94))
			_b(boxes, Vector3(12, 46, 11.2), Vector3(5, 5, 3), "navy", Color.WHITE)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(9, 10, 1), "flat", cream)
			_b(boxes, Vector3(9, 34, -14), Vector3(9, 9, 15), "fur", fur)
			_b(boxes, Vector3(9, 38, -27), Vector3(8, 8, 11), "fur", dark)
		"crane":
			# 小鹤：白羽 + 红顶 + 长喙 + 黑翅尖 + 细腿 + 金腿环。
			for sx in [-1, 1]:
				_b(boxes, Vector3(9.0 * sx, 68, 0), Vector3(8, 14, 7), "fur", fur)
				_b(boxes, Vector3(20.0 * sx, 30, 0), Vector3(11, 24, 12), "fur", cream)
				_b(boxes, Vector3(20.0 * sx, 28, 8), Vector3(6, 6, 2), "flat", dark)
				_b(boxes, Vector3(8.0 * sx, 14, 0), Vector3(14.5, 3, 14.5), "gold", Color.WHITE)
			_b(boxes, Vector3(0, 52, 0), Vector3(29, 3, 23), "gold", Color.WHITE)
			_b(boxes, Vector3(0, 78, 2), Vector3(7, 4, 5), "flat", accent)
			_b(boxes, Vector3(0, 60, 14.2), Vector3(5, 3, 7), "flat", accent)
			_b(boxes, Vector3(0, 58, 12.7), Vector3(16, 7, 2), "flat", cream)
			_b(boxes, Vector3(0, 44, 10.2), Vector3(8, 10, 1), "flat", cream)
			_b(boxes, Vector3(0, 30, -13), Vector3(8, 10, 8), "fur", cream)
		_:
			pass
	return boxes


# 人形骨架：腿 / 鞋 / 躯干 / 腰带 / 手臂 / 手套 / 头 / 眼高光 / 腮红 / 嘴
static func _humanoid_base(boxes: Array, fur: Color, cream: Color, dark: Color, accent: Color,
		pants := "navy") -> void:
	for sx in [-1, 1]:
		# 裤子默认 navy，由 heroes.json 的 pants 字段按角色覆盖；鞋统一深色。
		_b(boxes, Vector3(8.0 * sx, 0, 0), Vector3(13, 26, 13), pants, Color.WHITE)
		_b(boxes, Vector3(8.0 * sx, 0, 1), Vector3(14, 7, 14), "flat", SHOE)
		_b(boxes, Vector3(20.0 * sx, 28, 0), Vector3(10, 24, 10), "fur", fur)
		_b(boxes, Vector3(20.0 * sx, 28, 0), Vector3(11, 7, 11), "flat", dark)
	_b(boxes, Vector3(0, 26, 0), Vector3(30, 26, 20), "fur", fur)
	_b(boxes, Vector3(0, 26, 0), Vector3(31, 5, 21), pants, Color(0.84, 0.84, 0.84))
	_b(boxes, Vector3(0, 56, 0), Vector3(26, 22, 24), "fur", fur)
	_b(boxes, Vector3(0, 58, 12.6), Vector3(18, 10, 2), "flat", cream)
	for sx in [-1, 1]:
		_b(boxes, Vector3(5.5 * sx, 68, 12.7), Vector3(4, 4, 2), "flat", dark)
		# 眼高光：每只眼上内侧 1 颗白点（贴在眼睛最前面）
		_b(boxes, Vector3(6.4 * sx, 70.2, 14.75), Vector3(1.6, 1.6, 0.6), "flat", Color.WHITE)
		# 腮红：两颊的粉色小块（贴着头皮正面，避开嘴部）
		_b(boxes, Vector3(10.8 * sx, 62.6, 12.1), Vector3(3.6, 2.2, 0.8), "blush", Color.WHITE)
	_b(boxes, Vector3(0, 61, 14.75), Vector3(6, 2, 0.6), "flat", dark)


static func jungle_monster(atlas: PixelAtlas, kind: String) -> ArrayMesh:
	var boxes: Array = []
	if kind == "crab":
		# 河蟹：亮橙红甲壳 + 奶油吻部 + 眼高光。
		_b(boxes, Vector3(0, 4, 0), Vector3(32, 18, 28), "stone", Color("e07850"))
		_b(boxes, Vector3(0, 8, 0), Vector3(24, 12, 22), "flat", Color("f59a70"))
		for sx in [-1, 1]:
			_b(boxes, Vector3(20 * sx, 8, 4), Vector3(12, 8, 8), "stone", Color("c9653f"))
			_b(boxes, Vector3(10 * sx, 20, 12), Vector3(5, 5, 5), "flat", Color("1c1b1a"))
			_b(boxes, Vector3(10 * sx + 1.2, 23.0, 14.0), Vector3(1.8, 1.8, 1.2), "flat", Color.WHITE)
		_b(boxes, Vector3(0, 4, 15), Vector3(8, 3, 4), "flat", Color("f5d08a"))
	elif kind == "wolf":
		# 灰狼：亮灰身体 + 奶油吻部 + 眼高光。
		_b(boxes, Vector3(0, 8, 0), Vector3(24, 20, 42), "fur", Color("a8b2be"))
		_b(boxes, Vector3(0, 22, 18), Vector3(18, 16, 16), "fur", Color("bcc4ce"))
		_b(boxes, Vector3(0, 25, 27), Vector3(10, 8, 8), "flat", Color("e8edf3"))
		_b(boxes, Vector3(0, 28, 30), Vector3(4, 3, 3), "flat", Color("1c1b1a"))
		for sx in [-1, 1]:
			_b(boxes, Vector3(6 * sx, 32, 18), Vector3(5, 8, 5), "fur", Color("6b7685"))
			_b(boxes, Vector3(6 * sx, 0, 12), Vector3(5, 10, 5), "fur", Color("6b7685"))
			_b(boxes, Vector3(6 * sx, 0, -12), Vector3(5, 10, 5), "fur", Color("6b7685"))
			_b(boxes, Vector3(5.0 * sx, 26, 30), Vector3(3, 3, 2), "flat", Color("1c1b1a"))
			_b(boxes, Vector3(5.8 * sx, 27.4, 31.0), Vector3(1.4, 1.4, 0.6), "flat", Color.WHITE)
		_b(boxes, Vector3(0, 18, -22), Vector3(8, 8, 16), "fur", Color("8a94a2"))
	else:
		# 野猪：暖棕身体 + 奶油吻部 + 眼高光。
		_b(boxes, Vector3(0, 4, 0), Vector3(36, 22, 30), "fur", Color("b08050"))
		_b(boxes, Vector3(0, 20, 13), Vector3(18, 16, 14), "fur", Color("c08f60"))
		_b(boxes, Vector3(0, 22, 22), Vector3(10, 7, 6), "flat", Color("e8c69a"))
		_b(boxes, Vector3(0, 24, 25), Vector3(4, 3, 3), "flat", Color("1c1b1a"))
		for sx in [-1, 1]:
			_b(boxes, Vector3(6 * sx, 24, 20), Vector3(4, 4, 4), "flat", Color("1c1b1a"))
			_b(boxes, Vector3(6 * sx + 1.0, 27.0, 22.0), Vector3(1.6, 1.6, 0.6), "flat", Color.WHITE)
			_b(boxes, Vector3(12 * sx, 5, 8), Vector3(8, 3, 3), "flat", Color("f5eedc"))
			_b(boxes, Vector3(7 * sx, 0, 12), Vector3(5, 8, 5), "fur", Color("8a5a3a"))
			_b(boxes, Vector3(7 * sx, 0, -12), Vector3(5, 8, 5), "fur", Color("8a5a3a"))
		_b(boxes, Vector3(0, 20, -16), Vector3(5, 5, 8), "fur", Color("8a5a3a"))
	return VoxelModel.mesh(atlas, boxes)


static func minion(atlas: PixelAtlas, color: Color, radius: float, team: int) -> ArrayMesh:
	# 蓝方：圆润小果冻 + 头顶嫩芽；红方：高瘦尖刺怪 + 怒脸。
	var boxes: Array = []
	var tint := _lighter(color, 0.06)
	if team == 1:
		var body := radius * 1.9
		var bh := radius * 2.15
		var warm := Color("6a4a3a")
		_b(boxes, Vector3(0, 2, 0), Vector3(body, bh, body), "flat", tint, {"front": "face_angry"})
		_b(boxes, Vector3(0, 0, 0), Vector3(body * 0.9, 3, body * 0.9), "flat", _darker(color, 0.72))
		for i in range(3):
			var sx := float(i - 1) * radius * 0.62
			var sh := 10.0 + float(i % 2) * 6.0
			_b(boxes, Vector3(sx, bh + 2.0, 0), Vector3(8, sh, 8), "stone", warm)
			_b(boxes, Vector3(sx, bh + 2.0 + sh, 0), Vector3(6, 4, 6), "glow", Color("ffb36b"))
		for sx in [-1, 1]:
			_b(boxes, Vector3(sx * radius * 1.08, 8.0, 0), Vector3(6, radius * 0.9, radius * 1.25),
				"stone", warm)
		# 双爪 + 脚
		for sx in [-1, 1]:
			_b(boxes, Vector3(sx * body * 0.62, 12, 2), Vector3(7, 14, 7), "flat", _darker(tint, 0.82))
			_b(boxes, Vector3(sx * body * 0.66, 9, 5), Vector3(8, 4, 8), "stone", warm)
			_b(boxes, Vector3(sx * body * 0.30, 0, body * 0.24), Vector3(9, 4, 9), "stone", warm)
		# 背部尖刺 + 胸口熔岩核心
		for i in range(3):
			_b(boxes, Vector3(float(i - 1) * 9.0, 18.0 + float(i % 2) * 8.0, -body * 0.55),
				Vector3(7, 12, 7), "stone", warm)
		_b(boxes, Vector3(0, 9, body * 0.5 + 0.8), Vector3(9, 8, 2), "glow", Color("ff9a4a"))
	else:
		var body := radius * 1.85
		_b(boxes, Vector3(0, 2, 0), Vector3(body, body, body), "flat", tint, {"front": "face_slime"})
		_b(boxes, Vector3(0, 0, 0), Vector3(body * 0.86, 3, body * 0.86), "flat", _darker(color, 0.8))
		_b(boxes, Vector3(0, body + 2.0, 0), Vector3(5, 10, 5), "log_side", Color("6fae4a"))
		_b(boxes, Vector3(0, body + 12.0, 0), Vector3(15, 6, 9), "leaves", Color("7fcf5a"))
		# 小手臂 + 白手套
		for sx in [-1, 1]:
			_b(boxes, Vector3(sx * body * 0.60, 10, 1), Vector3(6, 12, 6), "flat", _darker(tint, 0.92))
			_b(boxes, Vector3(sx * body * 0.60, 8, 3), Vector3(7, 4, 7), "flat", Color(0.96, 0.99, 1.0))
			_b(boxes, Vector3(sx * body * 0.30, 0, body * 0.22), Vector3(9, 4, 8), "flat", _darker(color, 0.76))
		# 侧芽 + 金色小花
		_b(boxes, Vector3(4, body + 13, 0), Vector3(5, 8, 7), "leaves", Color("8fdf6a"))
		_b(boxes, Vector3(-4, body + 9, 0), Vector3(4, 6, 5), "leaves", Color("6fbf4a"))
		_b(boxes, Vector3(0, body + 18, 0), Vector3(6, 4, 6), "gold", Color("ffd76a"))
		# 眼高光：贴着脸部两只眼睛上缘
		for sx in [-1, 1]:
			_b(boxes, Vector3(sx * body * 0.16, body * 0.64, body * 0.5 + 0.6), Vector3(3, 3, 1.0),
				"flat", Color.WHITE)
	return VoxelModel.mesh(atlas, boxes)


static func boss(atlas: PixelAtlas, color: Color, team: int, flight := false) -> ArrayMesh:
	# 3 分钟后出场的峡谷巨兽：暖灰石甲、苔藓点缀、金角、胸口团队色核心。
	var boxes: Array = []
	var stone := Color.WHITE
	var dark := Color(0.62, 0.60, 0.57)
	var glow := Color("ffd76a") if team == 0 else Color("ff8a5a")
	for sx in [-1, 1]:
		_b(boxes, Vector3(20.0 * sx, 4, 0), Vector3(30, 10, 36), "boss_stone", dark)
		_b(boxes, Vector3(18.0 * sx, 22, 0), Vector3(24, 34, 24), "boss_stone", stone)
		_b(boxes, Vector3(18.0 * sx, 38, 0), Vector3(25, 6, 25), "flat", color)
	# 躯干、胸口核心、腰带
	_b(boxes, Vector3(0, 58, 0), Vector3(58, 46, 38), "boss_stone", stone)
	_b(boxes, Vector3(0, 58, 19.6), Vector3(34, 8, 3), "flat", color)
	_b(boxes, Vector3(0, 66, 20.2), Vector3(14, 14, 2), "glow", glow)
	_b(boxes, Vector3(0, 42, 20.0), Vector3(20, 4, 2), "gold", Color("d8a63a"))
	# 肩甲、手臂、巨拳
	for sx in [-1, 1]:
		_b(boxes, Vector3(36.0 * sx, 80, 0), Vector3(26, 20, 28), "boss_stone", dark)
		_b(boxes, Vector3(36.0 * sx, 88, 0), Vector3(27, 4, 29), "flat", color)
		_b(boxes, Vector3(36.0 * sx, 100, 0), Vector3(20, 4, 22), "moss", Color.WHITE)
		_b(boxes, Vector3(44.0 * sx, 54, 0), Vector3(20, 34, 20), "boss_stone", stone)
		_b(boxes, Vector3(46.0 * sx, 30, 0), Vector3(28, 22, 28), "boss_stone", dark)
		_b(boxes, Vector3(46.0 * sx, 30, 0), Vector3(29, 5, 29), "flat", color)
	# 头、发光眼、金角、苔藓
	_b(boxes, Vector3(0, 99, 0), Vector3(30, 24, 28), "boss_stone", stone)
	_b(boxes, Vector3(0, 94, 14.4), Vector3(18, 5, 2), "flat", dark)
	for sx in [-1, 1]:
		_b(boxes, Vector3(7.0 * sx, 100, 14.8), Vector3(5, 5, 2), "glow", glow)
		_b(boxes, Vector3(12.0 * sx, 117, 0), Vector3(7, 14, 7), "gold", Color("f5cb55"))
	_b(boxes, Vector3(0, 114, 0), Vector3(10, 10, 5), "gold", Color("f5cb55"))
	_b(boxes, Vector3(0, 123, 0), Vector3(20, 4, 18), "moss", Color.WHITE)
	_b(boxes, Vector3(0, 104, -19), Vector3(28, 6, 8), "moss", Color.WHITE)
	# 背部尖刺
	for i in range(3):
		_b(boxes, Vector3(float(i - 1) * 16.0, 78.0 + float(i % 2) * 10.0, -21.0),
			Vector3(9, 16, 9), "boss_stone", dark)
		_b(boxes, Vector3(float(i - 1) * 16.0, 87.0 + float(i % 2) * 10.0, -21.0),
			Vector3(5, 5, 5), "glow", glow)
	if flight:
		# 第二形态：展开一对石翼，飞在空中；翼面提亮 + 苔藓翼缘。
		for sx in [-1, 1]:
			_b(boxes, Vector3(32.0 * sx, 62, -12), Vector3(30, 7, 24), "stone", Color("c8c2d2"))
			_b(boxes, Vector3(58.0 * sx, 66, -20), Vector3(28, 5, 30), "stone", Color("d8d2e2"))
			_b(boxes, Vector3(58.0 * sx, 71, -20), Vector3(24, 3, 16), "moss", Color.WHITE)
			_b(boxes, Vector3(80.0 * sx, 72, -28), Vector3(20, 4, 22), "flat", Color("dcd6e4"))
			_b(boxes, Vector3(34.0 * sx, 54, -10), Vector3(20, 4, 14), "flat", Color("ffd76a"))
	return VoxelModel.mesh(atlas, boxes)


static func tower(atlas: PixelAtlas, color: Color, radius: float, height: float, team: int) -> ArrayMesh:
	# 卡通蘑菇塔：奶油菌柄 + 队伍色多层菌盖 + 顶部旗杆与队旗。
	var boxes: Array = []
	var cap_tile := "mushroom_blue" if team == 0 else "mushroom"
	var cap_tint := Color(0.99, 1.0, 1.0) if team == 0 else Color(1, 0.99, 0.97)
	var stalk_tint := Color.WHITE
	var gill_tint := Color(0.99, 0.97, 0.90)

	# 奶油石底座 + 四角晶石 + 绿植点缀
	_b(boxes, Vector3(0, 0, 0), Vector3(radius * 2.35, 10, radius * 2.35), "stone",
		Color(0.96, 0.94, 0.87))
	for i in range(4):
		var ang := float(i) * PI * 0.5 + 0.4
		var px := cos(ang) * radius * 1.15
		var pz := sin(ang) * radius * 1.15
		if team == 0:
			_b(boxes, Vector3(px, 10, pz), Vector3(12, 10, 12), "crystal", Color(0.72, 0.94, 1.0))
		else:
			_b(boxes, Vector3(px, 10, pz), Vector3(13, 8, 13), "crystal", Color(1.0, 0.55, 0.36))
	for i in range(3):
		var a := 0.9 + float(i) * 2.0
		_b(boxes, Vector3(cos(a) * radius * 1.38, 10, sin(a) * radius * 1.38),
			Vector3(10, 7, 10), "leaves", Color("6fbf4a"))

	# 菌柄：三段，越往上越细（两队统一奶油色）
	var stalk_y := 10.0
	var stalks := [
		[radius * 2.0, 22.0, radius * 1.0],
		[radius * 1.85, 20.0, radius * 0.9],
		[radius * 1.7, 18.0, radius * 0.8],
	]
	for s in stalks:
		var w: float = s[0]
		var hh: float = s[1]
		_b(boxes, Vector3(0, stalk_y, 0), Vector3(w, hh, w), "cream", stalk_tint)
		stalk_y += hh

	# 菌褶 + 四层菌盖（逐层收窄，形成圆顶轮廓）
	_b(boxes, Vector3(0, stalk_y, 0), Vector3(radius * 1.9, 10, radius * 1.9), "cream", gill_tint)
	var cap_y := stalk_y + 10.0
	_b(boxes, Vector3(0, cap_y, 0), Vector3(radius * 2.25, 10, radius * 2.25), cap_tile, cap_tint)
	_b(boxes, Vector3(0, cap_y + 10, 0), Vector3(radius * 1.98, 12, radius * 1.98), cap_tile,
		_lighter(cap_tint, 0.03))
	_b(boxes, Vector3(0, cap_y + 22, 0), Vector3(radius * 1.56, 14, radius * 1.56), cap_tile,
		_lighter(cap_tint, 0.06))
	_b(boxes, Vector3(0, cap_y + 36, 0), Vector3(radius * 1.02, 12, radius * 1.02), cap_tile,
		_lighter(cap_tint, 0.10))
	# 顶部：小发光核心 + 金色旗杆 + 队伍色旗
	_b(boxes, Vector3(0, cap_y + 48, 0), Vector3(radius * 0.42, 10, radius * 0.42), "glow",
		Color(0.75, 0.95, 1.0) if team == 0 else Color(1.0, 0.80, 0.45))
	_b(boxes, Vector3(0, cap_y + 58, 0), Vector3(3, 30, 3), "gold", Color.WHITE)
	_b(boxes, Vector3(11, cap_y + 74, 0), Vector3(20, 12, 2.5), cap_tile, cap_tint)
	return VoxelModel.mesh(atlas, boxes)


static func base_pedestal(atlas: PixelAtlas, radius: float, team: int) -> ArrayMesh:
	# 宣传片同款奶油石祭坛：三层砖台 + 四角队色晶柱 + 队色能量环（两队同底座）。
	var boxes: Array = []
	var stone := Color(0.95, 0.93, 0.86)
	var tile := "stone_brick"
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
					"crystal", Color(0.72, 0.94, 1.0))
				_b(boxes, Vector3(radius * 1.05 * sx, 66, radius * 1.05 * sz), Vector3(8, 12, 8),
					"ice", Color(0.95, 1.0, 1.0))
			else:
				_b(boxes, Vector3(radius * 1.05 * sx, 40, radius * 1.05 * sz), Vector3(14, 26, 14),
					"crystal", Color(1.0, 0.55, 0.36))
				_b(boxes, Vector3(radius * 1.05 * sx, 66, radius * 1.05 * sz), Vector3(8, 12, 8),
					"crystal", Color(1.0, 0.80, 0.60))
	# 能量环：四条细边围出方环，避免整块亮色盖住祭坛。
	var ring_tile := "ice" if team == 0 else "crystal"
	var ring_tint := Color(0.72, 0.94, 1.0) if team == 0 else Color(1.0, 0.55, 0.36)
	var rr := radius * 1.02
	_b(boxes, Vector3(0, 40, rr), Vector3(radius * 2.15, 1, 7), ring_tile, ring_tint)
	_b(boxes, Vector3(0, 40, -rr), Vector3(radius * 2.15, 1, 7), ring_tile, ring_tint)
	_b(boxes, Vector3(rr, 40, 0), Vector3(7, 1, radius * 2.15), ring_tile, ring_tint)
	_b(boxes, Vector3(-rr, 40, 0), Vector3(7, 1, radius * 2.15), ring_tile, ring_tint)
	return VoxelModel.mesh(atlas, boxes)


static func base_crystal(atlas: PixelAtlas, color: Color, radius: float, height: float, team: int) -> ArrayMesh:
	var boxes: Array = []
	if team == 0:
		# 高而尖的月光水晶（亮天蓝），两侧小晶体 + 顶部悬浮星。
		var gem := Color("92e4f8")
		var core := Color("b8f0ff")
		_b(boxes, Vector3(0, 0, 0), Vector3(radius * 1.0, height * 0.22, radius * 1.0), "crystal", gem)
		_b(boxes, Vector3(0, height * 0.22, 0), Vector3(radius * 0.72, height * 0.32, radius * 0.72),
			"crystal", gem)
		_b(boxes, Vector3(0, height * 0.54, 0), Vector3(radius * 0.44, height * 0.28, radius * 0.44),
			"crystal", core)
		_b(boxes, Vector3(0, height * 0.82, 0), Vector3(radius * 0.20, height * 0.16, radius * 0.20),
			"glow", Color(0.90, 0.98, 1.0))
		for sx in [-1, 1]:
			_b(boxes, Vector3(radius * 0.62 * sx, 0, radius * 0.1),
				Vector3(radius * 0.30, height * 0.30, radius * 0.30), "crystal", gem)
			_b(boxes, Vector3(radius * 0.42 * sx, height * 0.30, radius * 0.1),
				Vector3(radius * 0.20, height * 0.12, radius * 0.20), "glow", Color(0.9, 0.98, 1.0))
		_b(boxes, Vector3(0, height * 1.02, 0), Vector3(10, 10, 10), "glow", Color(0.9, 1.0, 1.0))
	else:
		# 熔岩水晶改亮橙晶体：晶体底座 + 三根高低晶柱 + 暖光顶。
		var gem := Color(1.0, 0.58, 0.40)
		var core := Color(1.0, 0.72, 0.50)
		_b(boxes, Vector3(0, 0, 0), Vector3(radius * 1.18, height * 0.16, radius * 1.18), "crystal", gem)
		_b(boxes, Vector3(0, height * 0.16, 0), Vector3(radius * 0.92, height * 0.20, radius * 0.92),
			"crystal", core)
		for i in range(3):
			var sx := float(i - 1) * radius * 0.42
			var hh := height * (0.24 + 0.07 * float(i))
			_b(boxes, Vector3(sx, height * 0.34, float(i % 2) * 6.0 - 3.0),
				Vector3(radius * 0.28, hh, radius * 0.28), "crystal", gem)
			_b(boxes, Vector3(sx, height * 0.34 + hh, float(i % 2) * 6.0 - 3.0),
				Vector3(radius * 0.16, height * 0.08, radius * 0.16), "glow", Color(1.0, 0.84, 0.60))
		_b(boxes, Vector3(0, height * 0.34, 0), Vector3(radius * 0.22, height * 0.44, radius * 0.22),
			"crystal", core)
	return VoxelModel.mesh(atlas, boxes)


static func tower_ruins(atlas: PixelAtlas, color: Color, radius: float, team: int) -> ArrayMesh:
	# 蘑菇塔废墟：奶油断柄 + 倒地碎菌盖 + 散落白斑与碎石。
	var boxes: Array = []
	var cap_tile := "mushroom_blue" if team == 0 else "mushroom"
	var cap_tint := Color(0.96, 1.0, 1.0) if team == 0 else Color(1, 0.99, 0.97)
	var stalk_tint := Color.WHITE
	_b(boxes, Vector3(0, 0, 0), Vector3(radius * 2.2, 8, radius * 2.2), "stone",
		Color(0.88, 0.86, 0.79))
	# 断裂的菌柄（高低两截，奶油色）
	_b(boxes, Vector3(-radius * 0.22, 8, radius * 0.1), Vector3(radius * 1.15, 24, radius * 0.95),
		"cream", stalk_tint)
	_b(boxes, Vector3(radius * 0.38, 8, -radius * 0.18), Vector3(radius * 0.72, 14, radius * 0.68),
		"cream", _darker(stalk_tint, 0.92))
	_b(boxes, Vector3(radius * 0.38, 22, -radius * 0.18), Vector3(radius * 0.52, 7, radius * 0.5),
		"cream", stalk_tint)
	# 倒地的碎菌盖
	_b(boxes, Vector3(radius * 0.95, 3, radius * 0.45), Vector3(radius * 1.5, 7, radius * 1.15),
		cap_tile, cap_tint)
	_b(boxes, Vector3(-radius * 0.65, 2, radius * 0.85), Vector3(radius * 0.85, 5, radius * 0.7),
		cap_tile, _darker(cap_tint, 0.95))
	# 散落白斑与碎石
	for i in range(4):
		_b(boxes, Vector3(-radius * 1.1 + float(i) * radius * 0.72, 0, radius * 1.2),
			Vector3(7, 5, 7), "cream", Color(0.96, 0.94, 0.84))
	for i in range(3):
		var ang := float(i) * 1.7 + 0.5
		_b(boxes, Vector3(cos(ang) * radius * 1.45, 0, sin(ang) * radius * 1.35),
			Vector3(radius * 0.24, 6 + float(i % 2) * 4.0, radius * 0.22), "stone",
			Color(0.76, 0.75, 0.70))
	# 残余微光
	_b(boxes, Vector3(0, 26, 0), Vector3(8, 6, 8), "glow",
		Color(0.7, 0.92, 1.0) if team == 0 else Color(1.0, 0.76, 0.40))
	return VoxelModel.mesh(atlas, boxes)


static func base_ruins(atlas: PixelAtlas, color: Color, radius: float, height: float) -> ArrayMesh:
	var boxes: Array = []
	var stone := Color(0.90, 0.88, 0.81)
	_b(boxes, Vector3(0, 0, 0), Vector3(radius * 2.5, 9, radius * 2.5), "stone", Color(0.82, 0.80, 0.73))
	_b(boxes, Vector3(-radius * 0.55, 9, radius * 0.2), Vector3(radius * 1.2, 15, radius * 1.1),
		"stone_brick", stone)
	_b(boxes, Vector3(radius * 0.55, 9, -radius * 0.25), Vector3(radius * 0.95, 24, radius * 0.85),
		"stone_brick", _darker(stone, 0.90))
	# 碎水晶残片：高低错落，仍带队伍色（提亮）
	_b(boxes, Vector3(-radius * 0.28, 16, radius * 0.35), Vector3(radius * 0.32, height * 0.20, radius * 0.32),
		"crystal", _lighter(color, 0.18))
	_b(boxes, Vector3(radius * 0.35, 12, -radius * 0.28), Vector3(radius * 0.26, height * 0.26, radius * 0.26),
		"crystal", _lighter(color, 0.10))
	_b(boxes, Vector3(radius * 0.05, 8, radius * 0.55), Vector3(radius * 0.22, height * 0.13, radius * 0.22),
		"crystal", _lighter(color, 0.04))
	# 地面裂痕
	_b(boxes, Vector3(0, 0, radius * 1.1), Vector3(radius * 1.5, 1, radius * 0.3), "lava",
		Color(0.95, 0.66, 0.40))
	# 周围碎块
	for i in range(4):
		var ang := 0.4 + float(i) * 1.35
		_b(boxes, Vector3(cos(ang) * radius * 1.5, 0, sin(ang) * radius * 1.4),
			Vector3(radius * 0.22, 6 + float(i % 2) * 5.0, radius * 0.22), "stone",
			Color(0.72, 0.70, 0.66))
	return VoxelModel.mesh(atlas, boxes)


static func tree(atlas: PixelAtlas, variant: int, leaf: Color) -> ArrayMesh:
	var boxes: Array = []
	var trunk_h := 64.0 + float(variant % 3) * 18.0
	_b(boxes, Vector3(0, 0, 0), Vector3(22, trunk_h, 22), "log_side", Color.WHITE,
		{"top": "log_top"})
	var y0 := trunk_h - 12.0
	_b(boxes, Vector3(0, y0, 0), Vector3(80, 30, 80), "leaves", _darker(leaf, 0.88))
	_b(boxes, Vector3(0, y0 + 24.0, 0), Vector3(58, 26, 58), "leaves", leaf)
	_b(boxes, Vector3(0, y0 + 46.0, 0), Vector3(32, 22, 32), "leaves", _lighter(leaf, 0.08))
	return VoxelModel.mesh(atlas, boxes)


static func rock(atlas: PixelAtlas, variant: int) -> ArrayMesh:
	var boxes: Array = []
	var stone := Color(0.95, 0.93, 0.88)
	var w := 34.0 + float(variant % 3) * 14.0
	_b(boxes, Vector3(0, 0, 0), Vector3(w, w * 0.62, w * 0.9), "stone", stone)
	_b(boxes, Vector3(w * 0.32, 0, w * 0.22), Vector3(w * 0.55, w * 0.44, w * 0.55), "stone",
		_darker(stone, 0.94))
	return VoxelModel.mesh(atlas, boxes)


static func mushroom(atlas: PixelAtlas) -> ArrayMesh:
	var boxes: Array = []
	_b(boxes, Vector3(0, 0, 0), Vector3(16, 28, 16), "cream", Color.WHITE)
	_b(boxes, Vector3(0, 28, 0), Vector3(46, 18, 46), "mushroom", Color(0.94, 0.90, 1.0))
	_b(boxes, Vector3(0, 46, 0), Vector3(30, 10, 30), "mushroom", Color(0.90, 0.86, 1.0))
	return VoxelModel.mesh(atlas, boxes)


static func sign(atlas: PixelAtlas) -> ArrayMesh:
	var boxes: Array = []
	_b(boxes, Vector3(0, 0, 0), Vector3(9, 62, 9), "log_side", Color.WHITE)
	_b(boxes, Vector3(0, 44, 0), Vector3(56, 24, 7), "planks", Color(1.0, 1.0, 1.0))
	_b(boxes, Vector3(-14, 52, 4.0), Vector3(18, 5, 2), "flat", Color(0.30, 0.22, 0.16))
	_b(boxes, Vector3(12, 52, 4.0), Vector3(12, 5, 2), "flat", Color(0.30, 0.22, 0.16))
	return VoxelModel.mesh(atlas, boxes)


static func potion(atlas: PixelAtlas) -> ArrayMesh:
	# 回血药剂：不透明体重素小瓶（绿玻璃 + 浅绿颈 + 木塞 + 白十字），脚下光圈由表现层另加。
	var boxes: Array = []
	var glass := Color("58c878")
	var neck := Color("8fe0a8")
	_b(boxes, Vector3(0, 0, 0), Vector3(20, 24, 20), "flat", glass)
	_b(boxes, Vector3(0, 22, 0), Vector3(15, 5, 15), "flat", neck)
	_b(boxes, Vector3(0, 27, 0), Vector3(10, 9, 10), "flat", neck)
	_b(boxes, Vector3(0, 36, 0), Vector3(12, 5, 12), "wood", Color.WHITE)
	_b(boxes, Vector3(0, 8, 10.2), Vector3(5, 14, 2), "flat", Color.WHITE)
	_b(boxes, Vector3(0, 12, 10.2), Vector3(14, 5, 2), "flat", Color.WHITE)
	return VoxelModel.mesh(atlas, boxes)


static func cloud(atlas: PixelAtlas) -> ArrayMesh:
	# 体素云：几块错落的云团，表现层悬空摆放并缓慢漂移。
	var boxes: Array = []
	_b(boxes, Vector3(-160, 0, 0), Vector3(260, 110, 110), "cloud", Color.WHITE)
	_b(boxes, Vector3(0, 50, 20), Vector3(300, 130, 140), "cloud", Color.WHITE)
	_b(boxes, Vector3(180, 10, -10), Vector3(220, 100, 90), "cloud", Color.WHITE)
	_b(boxes, Vector3(20, -10, -70), Vector3(200, 80, 90), "cloud", Color.WHITE)
	return VoxelModel.mesh(atlas, boxes)


static func grass_tuft(atlas: PixelAtlas) -> ArrayMesh:
	# 前景草丛：2–3 片亮绿草叶。
	var boxes: Array = []
	var blades := [Color(1.15, 1.25, 1.02), Color(1.0, 1.12, 0.9), Color(1.3, 1.4, 1.1)]
	for i in range(3):
		var x := float(i - 1) * 7.0
		var h := 16.0 + float(i % 2) * 8.0
		_b(boxes, Vector3(x, 0, float(i % 2) * 5.0 - 2.5), Vector3(4.5, h, 4.5), "leaves",
			blades[i])
	return VoxelModel.mesh(atlas, boxes)


static func flower(atlas: PixelAtlas, petal: Color) -> ArrayMesh:
	# 小花：绿茎 + 四瓣 + 金色花心。
	var boxes: Array = []
	_b(boxes, Vector3(0, 0, 0), Vector3(2.5, 18, 2.5), "leaves", Color("5f9e46"))
	for i in range(4):
		var ang := TAU * float(i) / 4.0
		_b(boxes, Vector3(cos(ang) * 5.5, 17, sin(ang) * 5.5), Vector3(6, 4, 6), "flat", petal)
	_b(boxes, Vector3(0, 18, 0), Vector3(4, 4, 4), "gold", Color.WHITE)
	return VoxelModel.mesh(atlas, boxes)

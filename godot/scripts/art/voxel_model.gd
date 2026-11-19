class_name VoxelModel
extends RefCounted

# 把「盒子列表」合并成单个 ArrayMesh：一次绘制一个模型，贴图共用像素图集。
# 面明暗以柔和常数烘焙进调色板（上 1.0 / 前后 0.97 / 左右 0.93 / 底 0.80），
# 与实时太阳光叠加后不会双重压暗；每个面同时写真实法线供光照/阴影使用。
# 关键：颜色不走顶点色（Android GLES/ANGLE 下顶点色会出现 G/B 通道互换），
# 而是把颜色写进每个模型自己的 1×64 调色板纹理，顶点用 UV2.x 取色。

const PALETTE_SIZE := 64
const INSET := 0.5 / 256.0


static func shader() -> Shader:
	return load("res://shaders/voxel.gdshader")


static func material_for(atlas: PixelAtlas, palette: PackedColorArray) -> ShaderMaterial:
	return _material(atlas, palette, shader())


static func fade_material_for(atlas: PixelAtlas, palette: PackedColorArray) -> ShaderMaterial:
	# 0 = 不透明；渲染层按遮挡程度逐步加大 fade（抖动裁剪）。
	var mat := _material(atlas, palette, load("res://shaders/voxel_fade.gdshader"))
	mat.set_shader_parameter("fade", 0.0)
	return mat


static func _material(atlas: PixelAtlas, palette: PackedColorArray, shader_res: Shader) -> ShaderMaterial:
	var img := Image.create(PALETTE_SIZE, 1, false, Image.FORMAT_RGBA8)
	for i in range(PALETTE_SIZE):
		# 调色板纹理按原始数值采样（与地面贴图同一套 sRGB 直出管线），保持设定色。
		img.set_pixel(i, 0, palette[i] if i < palette.size() else Color.WHITE)
	var palette_tex := ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = shader_res
	mat.set_shader_parameter("albedo_tex", atlas.texture)
	mat.set_shader_parameter("palette_tex", palette_tex)
	return mat


static func mesh(atlas: PixelAtlas, boxes: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var palette := PackedColorArray()
	var stats := {"overflow": 0}
	for b in boxes:
		_add_box(st, atlas, b, palette, stats)
	var m := st.commit()
	m.set_meta("palette", palette)
	m.set_meta("palette_overflow", int(stats["overflow"]))
	return m


static func box(pos: Vector3, size: Vector3, tile: String, tint: Color, overrides := {}) -> Dictionary:
	return {"pos": pos, "size": size, "tile": tile, "tint": tint, "faces": overrides}


static func _tile_for(b: Dictionary, face: String) -> String:
	var overrides: Dictionary = b.get("faces", {})
	if overrides.has(face):
		return str(overrides[face])
	return str(b.get("tile", "flat"))


static func _shade_for(face: String) -> float:
	match face:
		"top":
			return 1.0
		"bottom":
			return 0.80
		"front", "back":
			return 0.97
		"right", "left":
			return 0.93
	return 0.95


static func _normal_for(face: String) -> Vector3:
	match face:
		"top":
			return Vector3.UP
		"bottom":
			return Vector3.DOWN
		"front":
			return Vector3.BACK
		"back":
			return Vector3.FORWARD
		"right":
			return Vector3.RIGHT
		"left":
			return Vector3.LEFT
	return Vector3.UP


static func _palette_index(palette: PackedColorArray, c: Color, stats: Dictionary) -> int:
	for i in range(palette.size()):
		if palette[i].is_equal_approx(c):
			return i
	if palette.size() >= PALETTE_SIZE:
		# 调色板满：用最后一个槽近似，并记录溢出供测试断言（正常模型不应触发）。
		stats["overflow"] = int(stats.get("overflow", 0)) + 1
		return PALETTE_SIZE - 1
	palette.append(c)
	return palette.size() - 1


static func _face(st: SurfaceTool, atlas: PixelAtlas, b: Dictionary, face: String, tint: Color,
		palette: PackedColorArray, stats: Dictionary, rb: Basis, has_rot: bool,
		origin: Vector3, pts: Array) -> void:
	var p: Array = pts
	if has_rot:
		var out: Array = []
		for v in pts:
			out.append(origin + rb * ((v as Vector3) - origin))
		p = out
	var n := _normal_for(face)
	if has_rot:
		n = (rb * n).normalized()
	_quad(st, atlas, _tile_for(b, face), tint * _shade_for(face), palette, stats, p, n)


static func _add_box(st: SurfaceTool, atlas: PixelAtlas, b: Dictionary, palette: PackedColorArray,
		stats: Dictionary) -> void:
	# 可选 rot/rot_origin：武器/盾牌绕手掌等支点做静态旋转，读起来是“握着”而不是贴着手臂。
	var size: Vector3 = b.get("size", Vector3.ONE)
	var c: Vector3 = b.get("pos", Vector3.ZERO)
	var tint: Color = b.get("tint", Color.WHITE)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var y0 := 0.0
	var y1 := size.y
	var rot: Vector3 = b.get("rot", Vector3.ZERO)
	var has_rot := rot.length_squared() > 0.000001
	var rb := Basis.from_euler(rot)
	var origin: Vector3 = b.get("rot_origin", Vector3(c.x, (y0 + y1) * 0.5, c.z))

	_face(st, atlas, b, "front", tint, palette, stats, rb, has_rot, origin, [
		c + Vector3(-hx, y0, hz), c + Vector3(hx, y0, hz),
		c + Vector3(hx, y1, hz), c + Vector3(-hx, y1, hz),
	])
	_face(st, atlas, b, "back", tint, palette, stats, rb, has_rot, origin, [
		c + Vector3(hx, y0, -hz), c + Vector3(-hx, y0, -hz),
		c + Vector3(-hx, y1, -hz), c + Vector3(hx, y1, -hz),
	])
	_face(st, atlas, b, "right", tint, palette, stats, rb, has_rot, origin, [
		c + Vector3(hx, y0, -hz), c + Vector3(hx, y0, hz),
		c + Vector3(hx, y1, hz), c + Vector3(hx, y1, -hz),
	])
	_face(st, atlas, b, "left", tint, palette, stats, rb, has_rot, origin, [
		c + Vector3(-hx, y0, hz), c + Vector3(-hx, y0, -hz),
		c + Vector3(-hx, y1, -hz), c + Vector3(-hx, y1, hz),
	])
	_face(st, atlas, b, "top", tint, palette, stats, rb, has_rot, origin, [
		c + Vector3(-hx, y1, -hz), c + Vector3(hx, y1, -hz),
		c + Vector3(hx, y1, hz), c + Vector3(-hx, y1, hz),
	])
	_face(st, atlas, b, "bottom", tint, palette, stats, rb, has_rot, origin, [
		c + Vector3(-hx, y0, hz), c + Vector3(hx, y0, hz),
		c + Vector3(hx, y0, -hz), c + Vector3(-hx, y0, -hz),
	])


static func _quad(st: SurfaceTool, atlas: PixelAtlas, tile: String, tint: Color,
		palette: PackedColorArray, stats: Dictionary, pts: Array, normal: Vector3) -> void:
	var r := atlas.uv(tile)
	var uv := [
		Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y),
		Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.position.y),
	]
	var idx := _palette_index(palette, tint, stats)
	var uv2 := Vector2((float(idx) + 0.5) / float(PALETTE_SIZE), 0.5)
	var order := [0, 1, 2, 0, 2, 3]
	for k in order:
		st.set_normal(normal)
		st.set_uv(uv[k])
		st.set_uv2(uv2)
		st.add_vertex(pts[k])

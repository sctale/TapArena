class_name VoxelModel
extends RefCounted

# 把「盒子列表」合并成单个 ArrayMesh：一次绘制一个模型，贴图共用像素图集。
# 面光照直接烘焙进调色板（上 1.0 / 侧 0.88 / 底 0.55）。
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
	for b in boxes:
		_add_box(st, atlas, b, palette)
	var m := st.commit()
	m.set_meta("palette", palette)
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
			return 0.62
		"front", "back":
			return 0.94
		"right", "left":
			return 0.86
	return 0.92


static func _palette_index(palette: PackedColorArray, c: Color) -> int:
	for i in range(palette.size()):
		if palette[i].is_equal_approx(c):
			return i
	if palette.size() >= PALETTE_SIZE:
		return PALETTE_SIZE - 1
	palette.append(c)
	return palette.size() - 1


static func _add_box(st: SurfaceTool, atlas: PixelAtlas, b: Dictionary, palette: PackedColorArray) -> void:
	var size: Vector3 = b.get("size", Vector3.ONE)
	var c: Vector3 = b.get("pos", Vector3.ZERO)
	var tint: Color = b.get("tint", Color.WHITE)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var y0 := 0.0
	var y1 := size.y

	_quad(st, atlas, _tile_for(b, "front"), tint * _shade_for("front"), palette, [
		c + Vector3(-hx, y0, hz), c + Vector3(hx, y0, hz),
		c + Vector3(hx, y1, hz), c + Vector3(-hx, y1, hz),
	])
	_quad(st, atlas, _tile_for(b, "back"), tint * _shade_for("back"), palette, [
		c + Vector3(hx, y0, -hz), c + Vector3(-hx, y0, -hz),
		c + Vector3(-hx, y1, -hz), c + Vector3(hx, y1, -hz),
	])
	_quad(st, atlas, _tile_for(b, "right"), tint * _shade_for("right"), palette, [
		c + Vector3(hx, y0, -hz), c + Vector3(hx, y0, hz),
		c + Vector3(hx, y1, hz), c + Vector3(hx, y1, -hz),
	])
	_quad(st, atlas, _tile_for(b, "left"), tint * _shade_for("left"), palette, [
		c + Vector3(-hx, y0, hz), c + Vector3(-hx, y0, -hz),
		c + Vector3(-hx, y1, -hz), c + Vector3(-hx, y1, hz),
	])
	_quad(st, atlas, _tile_for(b, "top"), tint * _shade_for("top"), palette, [
		c + Vector3(-hx, y1, -hz), c + Vector3(hx, y1, -hz),
		c + Vector3(hx, y1, hz), c + Vector3(-hx, y1, hz),
	])
	_quad(st, atlas, _tile_for(b, "bottom"), tint * _shade_for("bottom"), palette, [
		c + Vector3(-hx, y0, hz), c + Vector3(hx, y0, hz),
		c + Vector3(hx, y0, -hz), c + Vector3(-hx, y0, -hz),
	])


static func _quad(st: SurfaceTool, atlas: PixelAtlas, tile: String, tint: Color,
		palette: PackedColorArray, pts: Array) -> void:
	var r := atlas.uv(tile)
	var uv := [
		Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y),
		Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.position.y),
	]
	var idx := _palette_index(palette, tint)
	var uv2 := Vector2((float(idx) + 0.5) / float(PALETTE_SIZE), 0.5)
	var order := [0, 1, 2, 0, 2, 3]
	for k in order:
		st.set_uv(uv[k])
		st.set_uv2(uv2)
		st.add_vertex(pts[k])

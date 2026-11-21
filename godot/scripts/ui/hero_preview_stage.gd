class_name HeroPreviewStage
extends SubViewport

# 首页详情页的 3D 英雄展示台：自己的一套 World、灯光、渐变背景、草地圆台与旋转英雄。
# 由 Home 放进 TextureRect；支持自动旋转、上下浮动与轻微待机摆动。

const PART_KEYS := ["head", "arm_l", "arm_r", "leg_l", "leg_r", "tail"]
const TARGET_HEIGHT := 94.0

var atlas: PixelAtlas = null
var hero_root: Node3D = null
var pivots: Dictionary = {}
var hero_id := ""
var rot := -0.55
var idle_t := 0.0
var dragging := false


func _init() -> void:
	size = Vector2i(512, 512)
	own_world_3d = true
	transparent_bg = false
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	atlas = PixelAtlas.new()
	_build_stage()


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("d8f1ea")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffffff")
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.90
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# 渐变背景板：上青蓝、下奶油绿，和首页天空同色系。
	var grad := Gradient.new()
	grad.set_color(0, Color("bfe9ff"))
	grad.set_color(1, Color("f2fbe9"))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 8
	gtex.height = 128
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_texture = gtex
	bmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var quad := QuadMesh.new()
	quad.size = Vector2(320, 320)
	var backdrop := MeshInstance3D.new()
	backdrop.mesh = quad
	backdrop.material_override = bmat
	backdrop.position = Vector3(0, 48, -120)
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(backdrop)

	# 草地圆台 + 金环。
	var cyl := CylinderMesh.new()
	cyl.top_radius = 54.0
	cyl.bottom_radius = 58.0
	cyl.height = 8.0
	cyl.radial_segments = 24
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("6fae4a")
	pmat.roughness = 1.0
	var platform := MeshInstance3D.new()
	platform.mesh = cyl
	platform.material_override = pmat
	platform.position = Vector3(0, 2, 0)
	add_child(platform)

	var ring := TorusMesh.new()
	ring.inner_radius = 51.0
	ring.outer_radius = 55.0
	ring.rings = 32
	ring.ring_segments = 6
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color("f5c542")
	rmat.metallic = 0.25
	rmat.roughness = 0.45
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	ring_node.material_override = rmat
	ring_node.position = Vector3(0, 6.2, 0)
	add_child(ring_node)

	# 暖色主光 + 冷色补光。
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("FFE6BC")
	sun.light_energy = 0.60
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42, -34, 0)
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("D6ECFF")
	fill.light_energy = 0.13
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-18, 40, 0)
	add_child(fill)

	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 62, 235), Vector3(0, 46, 0))

	hero_root = Node3D.new()
	add_child(hero_root)


func set_hero(id: String, d: Dictionary) -> void:
	if id == hero_id:
		return
	hero_id = id
	pivots.clear()
	for child in hero_root.get_children():
		child.queue_free()
	var parts = BlockModels.hero_parts(id, atlas,
		d.get("fur_c", Color.WHITE), d.get("cream_c", Color.WHITE),
		d.get("dark_c", Color.BLACK), d.get("accent_c", Color.WHITE),
		str(d.get("pants", "navy")))
	var meshes: Dictionary = parts["mesh"]
	var body := _mesh_instance(meshes["body"])
	hero_root.add_child(body)
	for key in PART_KEYS:
		var pivot := Node3D.new()
		pivot.position = parts["pivots"][key]
		pivot.add_child(_mesh_instance(meshes[key]))
		hero_root.add_child(pivot)
		pivots[key] = pivot
	var top := 0.0
	for key in meshes.keys():
		var lift := 0.0
		if key != "body":
			var pv: Vector3 = parts["pivots"][key]
			lift = pv.y
		var pm: ArrayMesh = meshes[key]
		top = maxf(top, pm.get_aabb().end.y + lift)
	var s := TARGET_HEIGHT / maxf(top, 1.0)
	hero_root.scale = Vector3(s, s, s)
	hero_root.position = Vector3(0, 6.0, 0)
	rot = -0.55
	idle_t = 0.0


func _mesh_instance(mesh: ArrayMesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = VoxelModel.material_for(atlas,
		mesh.get_meta("palette", PackedColorArray()))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return node


func set_active(active: bool) -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if active \
		else SubViewport.UPDATE_DISABLED


func tick(delta: float) -> void:
	if hero_root == null:
		return
	idle_t += delta
	if not dragging:
		rot += delta * 0.52
	hero_root.rotation.y = rot
	hero_root.position.y = 6.0 + sin(idle_t * 1.6) * 1.0
	if pivots.has("head"):
		(pivots["head"] as Node3D).rotation.y = sin(idle_t * 0.85) * 0.10
	if pivots.has("arm_l"):
		(pivots["arm_l"] as Node3D).rotation.x = sin(idle_t * 1.15) * 0.06
	if pivots.has("arm_r"):
		(pivots["arm_r"] as Node3D).rotation.x = -sin(idle_t * 1.15) * 0.06
	if pivots.has("tail"):
		(pivots["tail"] as Node3D).rotation.y = sin(idle_t * 0.9) * 0.14


func drag(dx: float) -> void:
	rot += dx * 0.012

class_name BattleView
extends Node3D

# 方块体素表现层：读取 BattleSim 状态，不反向修改规则。
# 4.14 起视觉对齐宣传片：太阳光 + 实时阴影 + FILMIC 影调 + 环境点缀；
# 模型仍走像素图集 + 调色板（不写 ALPHA），面明暗只做轻量烘焙避免双重压暗。

const HERO_DESIGN_H := {
	"tiger": 88.0, "fox": 88.0, "rabbit": 88.0, "bear": 88.0, "frog": 88.0, "cat": 88.0,
	"panda": 88.0, "owl": 88.0, "axolotl": 88.0, "deer": 88.0,
	"turtle": 88.0, "hedgehog": 88.0, "redpanda": 88.0, "wolf": 88.0, "crane": 88.0,
}

var sim = null
var atlas
var icons = null

var hero_nodes: Dictionary = {}
var minion_nodes: Dictionary = {}
var jungle_nodes: Dictionary = {}
var boss_nodes: Dictionary = {}
var structure_nodes: Dictionary = {}
var shot_nodes: Dictionary = {}
var zone_mesh: CylinderMesh = null
var potion_nodes: Dictionary = {}
var shot_free: Array = []
var zone_nodes: Array = []
var fx_items: Array = []
var debris_items: Array = []
var sprout_items: Array = []
var shot_mats: Dictionary = {}
var shot_meshes: Dictionary = {}
var alpha_mats: Dictionary = {}
var fx_mesh_cache: Dictionary = {}
var model_cache: Dictionary = {}
var mesh_mats: Dictionary = {}
var fade_mats: Dictionary = {}
var cloud_nodes: Array = []
# 性能兜底唯一开关：high = 2 级阴影 + 树/石投影 + glow；low = 单级阴影 + 近裁剪 + 树/石不投影。
var shadow_quality := "high"
var rng := RandomNumberGenerator.new()
var sync_us_total := 0
var sync_frames := 0

const C_BLUE := Color("4fc3e8")
const C_RED := Color("f0845c")


func attach(s) -> void:
	sim = s
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--shadow-quality=low":
			shadow_quality = "low"
	atlas = load("res://scripts/art/pixel_atlas.gd").new()
	icons = load("res://scripts/art/pixel_icons.gd").new()
	rng.seed = 7127
	_build_world()
	sim.fx.connect(_on_fx)
	if sim.has_signal("beam_fx"):
		sim.beam_fx.connect(_on_beam_fx)


func _team_color(team: int) -> Color:
	return C_BLUE if team == sim.BLUE else C_RED


func _tile_material(tile: String, tint: Color, alpha := 1.0) -> StandardMaterial3D:
	# 地面 / 兵线 / 河道 / 路缘 / 山丘走受光材质，能接太阳阴影；alpha 特效另用 _alpha_material。
	var m := StandardMaterial3D.new()
	m.albedo_texture = atlas.tile_texture(tile)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _tiled_material(tile: String, repeat: Vector2) -> StandardMaterial3D:
	var m := _tile_material(tile, Color.WHITE)
	m.uv1_scale = Vector3(repeat.x, repeat.y, 1.0)
	m.uv1_offset = Vector3.ZERO
	return m


func _model(key: String, factory: Callable):
	if model_cache.has(key):
		return model_cache[key]
	var mesh = factory.call()
	model_cache[key] = mesh
	return mesh


func _make_instance(mesh: ArrayMesh, cast_shadow := true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mesh_material(mesh)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _mesh_material(mesh: ArrayMesh) -> ShaderMaterial:
	var id := mesh.get_instance_id()
	if mesh_mats.has(id):
		return mesh_mats[id]
	var palette: PackedColorArray = mesh.get_meta("palette", PackedColorArray())
	var mat := VoxelModel.material_for(atlas, palette)
	mesh_mats[id] = mat
	return mat


func _mesh_fade_material(mesh: ArrayMesh) -> ShaderMaterial:
	var id := mesh.get_instance_id()
	if fade_mats.has(id):
		return fade_mats[id]
	var palette: PackedColorArray = mesh.get_meta("palette", PackedColorArray())
	var mat := VoxelModel.fade_material_for(atlas, palette)
	fade_mats[id] = mat
	return mat


func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	# 宣传片天空：顶部天蓝、地平线近白；环境光用冷色常量（Compatibility 下取天空会被地面绿色污染）。
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4aa8dc")
	sky_mat.sky_horizon_color = Color("b9e4f5")
	sky_mat.sky_curve = 0.15
	sky_mat.ground_bottom_color = Color("8fa9b8")
	sky_mat.ground_horizon_color = Color("d8e4e6")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cfe4f5")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	env.glow_enabled = shadow_quality != "low"
	env.glow_intensity = 0.22
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.25
	env.fog_enabled = true
	env.fog_light_color = Color("CCE7F6")
	env.fog_light_energy = 0.38
	env.fog_density = 0.00002
	env.fog_sky_affect = 0.35
	env_node.environment = env
	add_child(env_node)

	# 主太阳：暖白色，方向按本机俯视镜头微调（比宣传片更偏高）；移动端 2 级阴影，低画质切单级。
	# 能量取 0.55：GL Compatibility 的光照近似是按 sRGB 直出叠加，2.6 会把浅色地面全部打爆。
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("FFE6BC")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	if shadow_quality == "low":
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 600.0
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 900.0
	sun.shadow_bias = 0.6
	sun.shadow_normal_bias = 2.0
	add_child(sun)
	sun.look_at_from_position(Vector3(60, 58, 74).normalized() * 700.0, Vector3.ZERO)

	# 冷色补光：压一点暗部，不投影。
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("D6ECFF")
	fill.light_energy = 0.14
	fill.shadow_enabled = false
	add_child(fill)
	fill.look_at_from_position(Vector3(-30, 22, 40).normalized() * 700.0, Vector3.ZERO)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(sim.map_w + 600.0, sim.map_h + 600.0)
	ground.mesh = plane
	ground.position = Vector3(sim.map_w * 0.5, 0, sim.map_h * 0.5)
	ground.material_override = _tiled_material("grass_top",
		Vector2((sim.map_w + 600.0) / 64.0, (sim.map_h + 600.0) / 64.0))
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var lane_paths: Array = sim.lane_paths if sim.five_v_five else [sim.lane]
	_build_lane_roads(lane_paths)

	_build_river()
	_build_lane_curb()
	_build_hills()
	_build_scatter()
	_build_units()


func _build_lane_roads(lane_paths: Array) -> void:
	# 沿兵线折线逐段铺路：对角/竖直路段都不会画成整幅横条，拐角靠两端各多铺 95 接缝。
	for path in lane_paths:
		if path.size() < 2:
			continue
		for i in range(path.size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var seg: float = a.distance_to(b)
			if seg < 1.0:
				continue
			var mid: Vector2 = (a + b) * 0.5
			var lane := MeshInstance3D.new()
			var lane_plane := PlaneMesh.new()
			lane_plane.size = Vector2(seg + 190.0, 190.0)
			lane.mesh = lane_plane
			lane.position = Vector3(mid.x, 0.6, mid.y)
			lane.rotation.y = -atan2(b.y - a.y, b.x - a.x)
			lane.material_override = _tiled_material("path", Vector2((seg + 190.0) / 48.0, 190.0 / 48.0))
			lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(lane)


func _build_river() -> void:
	# 河道：与中路垂直的对角浅水带，河蟹营地就在这里。
	if not sim.five_v_five or sim.river.size() < 2:
		return
	var a: Vector2 = sim.river[0]
	var b: Vector2 = sim.river[1]
	var seg: float = a.distance_to(b)
	var mid: Vector2 = (a + b) * 0.5
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(seg, 260.0)
	water.mesh = plane
	water.position = Vector3(mid.x, 0.3, mid.y)
	water.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	var mat := _tile_material("water", Color(0.92, 0.98, 1.0), 0.9)
	mat.uv1_scale = Vector3(seg / 48.0, 260.0 / 48.0, 1.0)
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _lane_paths() -> Array:
	return sim.lane_paths if sim.five_v_five else [sim.lane]


func _dist_to_path(p: Vector2, path: Array) -> float:
	var best := 1.0e20
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var ab: Vector2 = b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, (a + ab * t).distance_to(p))
	return best


func _near_lane(x: float, z: float, margin := 145.0) -> bool:
	for path in _lane_paths():
		if path.size() >= 2 and _dist_to_path(Vector2(x, z), path) < margin:
			return true
	return false


func _near_structure(x: float, z: float, margin := 260.0) -> bool:
	# 花草不压建筑：基地/塔附近留空，避免长在祭坛上。
	for u in sim.units:
		if u.kind == sim.TOWER or u.kind == sim.BASE:
			if Vector2(x, z).distance_to(u.pos) < margin + u.radius:
				return true
	return false


func _near_river(x: float, z: float, margin := 200.0) -> bool:
	if not sim.five_v_five or sim.river.size() < 2:
		return false
	return _dist_to_path(Vector2(x, z), sim.river) < margin


func _build_lane_curb() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(46, 22, 46)
	var mat := _tile_material("stone", Color(0.90, 0.885, 0.85))
	var spots: Array = []
	for path in _lane_paths():
		if path.size() < 2:
			continue
		for i in range(path.size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var seg: float = a.distance_to(b)
			if seg < 1.0:
				continue
			var dir: Vector2 = (b - a) / seg
			var normal := Vector2(-dir.y, dir.x)
			var steps := int(seg / 56.0)
			for k in range(steps + 1):
				var p: Vector2 = a + dir * (56.0 * float(k))
				for side in [-1.0, 1.0]:
					spots.append(p + normal * (118.0 * float(side)))
	# 拐角接缝处去重，避免两块石头叠在一起。
	var kept: Array = []
	for p in spots:
		var dup := false
		for k in kept:
			if k.distance_to(p) < 40.0:
				dup = true
				break
		if not dup:
			kept.append(p)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = kept.size()
	for i in range(kept.size()):
		var p: Vector2 = kept[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(p.x, 0, p.y)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _build_hills() -> void:
	var mesh := VoxelModel.mesh(atlas, [
		VoxelModel.box(Vector3(0, 0, 0), Vector3(240, 240, 200), "grass_side", Color(1, 1, 1),
			{"top": "grass_top"}),
		VoxelModel.box(Vector3(30, 240, 10), Vector3(170, 120, 150), "grass_side", Color(0.96, 0.96, 0.96),
			{"top": "grass_top"}),
	])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 8
	for i in range(8):
		var x := 120.0 + float(i) * 360.0 + rng.randf_range(-70.0, 70.0)
		var z := rng.randf_range(-300.0, -90.0)
		var s := rng.randf_range(0.9, 1.7)
		var basis := Basis.IDENTITY.scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, 0, z)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _mesh_material(mesh)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node)


func _build_scatter() -> void:
	var tree_shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow_quality != "low" \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var leaf_tints := [Color(0.86, 0.86, 0.84), Color(1, 1, 1), Color(1.12, 1.16, 1.04)]
	for v in range(3):
		var mesh = _model("tree_%d" % v, func(): return BlockModels.tree(atlas, v, leaf_tints[v]))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var spots: Array = []
		for k in range(6):
			for tries in range(8):
				var x := rng.randf_range(140.0, sim.map_w - 140.0)
				var z := rng.randf_range(140.0, sim.map_h - 140.0)
				if _near_lane(x, z, 170.0) or _near_river(x, z, 210.0):
					continue
				spots.append(Vector3(x, 0, z))
				break
		mm.instance_count = spots.size()
		for k in range(spots.size()):
			var s := rng.randf_range(0.85, 1.35)
			mm.set_instance_transform(k, Transform3D(
				Basis.IDENTITY.scaled(Vector3(s, s, s)).rotated(Vector3.UP, rng.randf_range(0.0, TAU)), spots[k]))
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = _mesh_material(mesh)
		node.cast_shadow = tree_shadow
		add_child(node)

	for v in range(2):
		var rmesh = _model("rock_%d" % v, func(): return BlockModels.rock(atlas, v))
		var rmm := MultiMesh.new()
		rmm.transform_format = MultiMesh.TRANSFORM_3D
		rmm.mesh = rmesh
		var rock_spots: Array = []
		for k in range(5):
			for tries in range(8):
				var x := rng.randf_range(180.0, sim.map_w - 180.0)
				var z := rng.randf_range(180.0, sim.map_h - 180.0)
				if _near_lane(x, z, 170.0) or _near_river(x, z, 210.0):
					continue
				rock_spots.append(Vector3(x, 0, z))
				break
		rmm.instance_count = rock_spots.size()
		for k in range(rock_spots.size()):
			rmm.set_instance_transform(k, Transform3D(Basis.IDENTITY, rock_spots[k]))
		var rnode := MultiMeshInstance3D.new()
		rnode.multimesh = rmm
		rnode.material_override = _mesh_material(rmesh)
		rnode.cast_shadow = tree_shadow
		add_child(rnode)

	var mush = _model("mushroom", func(): return BlockModels.mushroom(atlas))
	var mush_spots := [Vector2(560, 1500), Vector2(1840, 900), Vector2(1000, 1900), Vector2(1400, 500)]
	for k in range(mush_spots.size()):
		var node := _make_instance(mush)
		var p: Vector2 = mush_spots[k]
		node.position = Vector3(p.x, 0, p.y)
		var s := rng.randf_range(0.7, 1.1)
		node.scale = Vector3(s, s, s)
		add_child(node)

	var sign_mesh = _model("sign", func(): return BlockModels.sign(atlas))
	for p in [Vector3(430, 0, 1470), Vector3(1970, 0, 930)]:
		var node := _make_instance(sign_mesh)
		node.position = p
		add_child(node)

	_build_ground_decor()


func _build_ground_decor() -> void:
	# 宣传片里的前景点缀：草丛 ~40、小花 ~24、体素云 6–8 朵。
	var tuft = _model("grass_tuft", func(): return BlockModels.grass_tuft(atlas))
	var tmm := MultiMesh.new()
	tmm.transform_format = MultiMesh.TRANSFORM_3D
	tmm.mesh = tuft
	var tuft_spots: Array = []
	for k in range(40):
		for tries in range(10):
			var x := rng.randf_range(90.0, sim.map_w - 90.0)
			var z := rng.randf_range(90.0, sim.map_h - 90.0)
			if _near_lane(x, z, 110.0) or _near_river(x, z, 150.0) or _near_structure(x, z):
				continue
			tuft_spots.append(Vector3(x, 0, z))
			break
	tmm.instance_count = tuft_spots.size()
	for k in range(tuft_spots.size()):
		var s := rng.randf_range(0.8, 1.4)
		tmm.set_instance_transform(k, Transform3D(
			Basis.IDENTITY.scaled(Vector3(s, s * rng.randf_range(0.85, 1.25), s))
			.rotated(Vector3.UP, rng.randf_range(0.0, TAU)), tuft_spots[k]))
	var tnode := MultiMeshInstance3D.new()
	tnode.multimesh = tmm
	tnode.material_override = _mesh_material(tuft)
	tnode.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tnode)

	var petals := [Color("f6aebc"), Color("f2c14e"), Color("ffffff")]
	for pi in range(3):
		var fmesh = _model("flower_%d" % pi, func(): return BlockModels.flower(atlas, petals[pi]))
		var fmm := MultiMesh.new()
		fmm.transform_format = MultiMesh.TRANSFORM_3D
		fmm.mesh = fmesh
		var fspots: Array = []
		for k in range(8):
			for tries in range(10):
				var x := rng.randf_range(100.0, sim.map_w - 100.0)
				var z := rng.randf_range(100.0, sim.map_h - 100.0)
				if _near_lane(x, z, 120.0) or _near_river(x, z, 160.0) or _near_structure(x, z):
					continue
				fspots.append(Vector3(x, 0, z))
				break
		fmm.instance_count = fspots.size()
		for k in range(fspots.size()):
			var s := rng.randf_range(0.9, 1.5)
			fmm.set_instance_transform(k, Transform3D(
				Basis.IDENTITY.scaled(Vector3(s, s, s)).rotated(Vector3.UP, rng.randf_range(0.0, TAU)),
				fspots[k]))
		var fnode := MultiMeshInstance3D.new()
		fnode.multimesh = fmm
		fnode.material_override = _mesh_material(fmesh)
		fnode.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fnode)

	if "--top" in OS.get_cmdline_user_args():
		return
	var cloud_mesh = _model("cloud_vox", func(): return BlockModels.cloud(atlas))
	for k in range(7):
		var node := _make_instance(cloud_mesh, false)
		node.position = Vector3(
			rng.randf_range(-200.0, sim.map_w + 200.0),
			rng.randf_range(320.0, 460.0),
			rng.randf_range(-250.0, sim.map_h + 250.0))
		var s := rng.randf_range(0.7, 1.1)
		node.scale = Vector3(s, s, s)
		node.rotation.y = rng.randf_range(0.0, TAU)
		add_child(node)
		cloud_nodes.append({"node": node, "speed": rng.randf_range(8.0, 18.0)})


func _build_units() -> void:
	for u in sim.units:
		if u.kind == sim.HERO:
			_add_hero(u)
		elif u.kind == sim.MINION:
			_add_minion(u)
		elif u.kind == sim.BOSS:
			_add_boss(u)
		elif u.kind == sim.JUNGLE:
			_add_jungle(u)
		elif u.kind == sim.TOWER or u.kind == sim.BASE:
			_add_structure(u)


func _hero_scale(u) -> float:
	var design: float = float(HERO_DESIGN_H.get(u.hero_id, 76.0))
	return float(u.height) / design


func _add_hero(u) -> void:
	var root := Node3D.new()
	root.name = "Hero_%d" % u.uid
	add_child(root)

	var parts: Dictionary = _model("hero_parts_" + u.hero_id, func(): return BlockModels.hero_parts(
		u.hero_id, atlas, u.fur, u.def.get("cream_c", u.fur), u.def.get("dark_c", u.fur), u.accent,
		str(u.def.get("pants", "navy"))))
	var meshes: Dictionary = parts["mesh"]
	var pivots: Dictionary = parts["pivots"]

	var body := _make_instance(meshes["body"])
	root.add_child(body)

	var limbs := {}
	for key in ["head", "arm_l", "arm_r", "leg_l", "leg_r", "tail"]:
		var pivot := Node3D.new()
		pivot.name = key
		pivot.position = pivots[key]
		pivot.add_child(_make_instance(meshes[key]))
		root.add_child(pivot)
		limbs[key] = pivot

	var s := _hero_scale(u)
	root.scale = Vector3(s, s, s)
	var item := {"root": root, "body": body, "limbs": limbs, "scale": s, "atk_active": false,
		"entrance_t": 0.0}
	if u.hero_id in ["turtle", "hedgehog", "redpanda", "wolf", "crane"]:
		# 5v5 五位英雄的开局招牌姿势：1.1 秒，仅首次创建时播放。
		item["entrance_t"] = 1.1
		_entrance_fx(u)
	hero_nodes[u.uid] = item


func _add_minion(u) -> void:
	var root := Node3D.new()
	root.name = "Minion_%d" % u.uid
	add_child(root)
	var mesh = _model("minion_%d" % u.team, func(): return BlockModels.minion(
		atlas, _team_color(u.team), u.radius, u.team))
	var body := _make_instance(mesh)
	root.add_child(body)
	minion_nodes[u.uid] = {"root": root, "body": body}


func _add_jungle(u) -> void:
	var root := Node3D.new()
	root.name = "Jungle_%d" % u.uid
	add_child(root)
	var mesh = _model("jungle_" + u.jungle_kind, func(): return BlockModels.jungle_monster(
		atlas, u.jungle_kind))
	var body := _make_instance(mesh)
	root.add_child(body)
	jungle_nodes[u.uid] = {"root": root, "body": body}


func _sync_jungle(u, delta: float) -> void:
	var item = jungle_nodes.get(u.uid)
	if item == null:
		_add_jungle(u)
		item = jungle_nodes[u.uid]
	var root: Node3D = item["root"]
	root.visible = u.is_alive()
	if not u.is_alive():
		return
	var rp: Vector2 = sim.render_pos(u)
	root.position = Vector3(rp.x, 0, rp.y)
	_face_yaw(item, u, delta)
	item["body"].rotation.y = sin(Time.get_ticks_msec() * 0.001 + float(u.uid)) * 0.08


func _add_boss(u) -> void:
	var root := Node3D.new()
	root.name = "Boss_%d" % u.uid
	add_child(root)
	var flight: bool = u.boss_flying
	var mesh = _model("boss_%d_%s" % [u.team, str(flight)], func(): return BlockModels.boss(
		atlas, _team_color(u.team), u.team, flight))
	var body := _make_instance(mesh)
	root.add_child(body)
	boss_nodes[u.uid] = {"root": root, "body": body, "flight": flight}


func _sync_boss(u, delta: float) -> void:
	var item = boss_nodes.get(u.uid)
	if item != null and bool(item.get("flight", false)) != bool(u.boss_flying):
		(item["root"] as Node3D).queue_free()
		boss_nodes.erase(u.uid)
		item = null
	if item == null:
		_add_boss(u)
		item = boss_nodes[u.uid]
	var root: Node3D = item["root"]
	root.visible = u.is_alive()
	if not u.is_alive():
		return
	var rp: Vector2 = sim.render_pos(u)
	var wt: float = u.walk_t
	if u.moving:
		wt -= (1.0 - sim.interp_alpha) * (1.0 / 30.0)
	var air := 58.0 if u.boss_flying else 0.0
	var hover := 0.0
	if u.boss_flying:
		# 飞行形态一直悬停，翅膀微微上下起伏；地面形态只在走路时弹跳。
		hover = sin(Time.get_ticks_msec() * 0.0024) * 4.0
	root.position = Vector3(rp.x, air + hover + absf(sin(wt * 6.0)) * (5.0 if u.moving else 0.0), rp.y)
	_face_yaw(item, u, delta)
	root.rotation.z = sin(Time.get_ticks_msec() * 0.0024 + 0.8) * 0.035 if u.boss_flying else 0.0
	var s := 1.0
	if u.atk_anim > 0.0:
		var k: float = 1.0 - u.atk_anim / 0.32
		s = 1.0 + sin(k * PI) * 0.08
	if u.cast_anim > 0.0:
		# 技能前摇：巨兽先吸气鼓起，再砸/吼/撞出去。
		var ck: float = clampf(1.0 - u.cast_anim / 0.70, 0.0, 1.0)
		s += sin(ck * PI) * 0.10
	root.scale = Vector3(s, 1.0, s)


func _add_structure(u) -> void:
	var root := Node3D.new()
	root.name = "Structure_%d" % u.uid
	root.position = Vector3(u.pos.x, 0, u.pos.y)
	add_child(root)
	var team_c := _team_color(u.team)

	if u.kind == sim.TOWER:
		var mesh = _model("tower_%d" % u.team, func(): return BlockModels.tower(
			atlas, team_c, u.radius, u.height, u.team))
		var body := _make_instance(mesh)
		root.add_child(body)
		var ruin_mesh = _model("tower_ruins_%d" % u.team, func(): return BlockModels.tower_ruins(
			atlas, team_c, u.radius, u.team))
		var ruins := _make_instance(ruin_mesh)
		ruins.visible = false
		root.add_child(ruins)
		structure_nodes[u.uid] = {"root": root, "body": body, "crystal": null, "ruins": ruins, "fade": 0.0,
			"body_mat": body.material_override, "body_fade": _mesh_fade_material(mesh)}
	else:
		var ped = _model("base_ped_%d" % u.team, func(): return BlockModels.base_pedestal(
			atlas, u.radius, u.team))
		var ped_node := _make_instance(ped)
		root.add_child(ped_node)
		var cry = _model("base_cry_%d" % u.team, func(): return BlockModels.base_crystal(
			atlas, team_c, u.radius, u.height, u.team))
		var crystal := _make_instance(cry)
		crystal.position = Vector3(0, 40, 0)
		root.add_child(crystal)
		var ruin_mesh = _model("base_ruins_%d" % u.team, func(): return BlockModels.base_ruins(
			atlas, team_c, u.radius, u.height))
		var ruins := _make_instance(ruin_mesh)
		ruins.visible = false
		root.add_child(ruins)
		structure_nodes[u.uid] = {"root": root, "body": ped_node, "crystal": crystal, "ruins": ruins, "fade": 0.0,
			"body_mat": ped_node.material_override, "body_fade": _mesh_fade_material(ped),
			"crystal_mat": crystal.material_override, "crystal_fade": _mesh_fade_material(cry)}


func _process(delta: float) -> void:
	if sim == null:
		return
	var t0 := Time.get_ticks_usec()
	_sync_units(delta)
	_sync_shots()
	_sync_zones()
	_step_fx(delta)
	_step_debris(delta)
	_step_sprouts(delta)
	_step_clouds(delta)
	sync_us_total += Time.get_ticks_usec() - t0
	sync_frames += 1
	if sync_frames >= 300:
		print("[VIEW] sync_ms=%.2f" % (sync_us_total / 1000.0 / float(sync_frames)))
		sync_us_total = 0
		sync_frames = 0


func _sync_units(delta: float) -> void:
	var live: Dictionary = {}
	for u in sim.units:
		live[u.uid] = true
		if u.kind == sim.HERO:
			_sync_hero(u, delta)
		elif u.kind == sim.MINION:
			_sync_minion(u, delta)
		elif u.kind == sim.BOSS:
			_sync_boss(u, delta)
		elif u.kind == sim.JUNGLE:
			_sync_jungle(u, delta)
		elif u.kind == sim.TOWER or u.kind == sim.BASE:
			var item = structure_nodes.get(u.uid)
			if item != null:
				var alive: bool = u.is_alive()
				item["root"].visible = true
				if item["body"] != null:
					item["body"].visible = alive
				if item["crystal"] != null:
					var c: Node3D = item["crystal"]
					c.visible = alive
					if alive:
						c.rotation.y += delta * 0.8
						c.position.y = 40.0 + sin(Time.get_ticks_msec() * 0.002) * 5.0
				if item["ruins"] != null:
					item["ruins"].visible = not alive
				# 玩家走到建筑后方时把建筑挖空（抖动裁剪），保证角色轮廓清楚可见。
				var fade_target := 0.0
				if alive and sim.player != null and sim.player.is_alive():
					var pp: Vector2 = sim.render_pos(sim.player)
					if pp.y < u.pos.y - 8.0 and absf(pp.x - u.pos.x) < u.radius * 1.15 \
							and (u.pos.y - pp.y) < 240.0:
						fade_target = 0.70
				var fade: float = item.get("fade", 0.0)
				fade = lerpf(fade, fade_target, 1.0 - exp(-12.0 * delta))
				item["fade"] = fade
				if item["body"] != null:
					if fade > 0.02:
						item["body"].material_override = item["body_fade"]
						item["body_fade"].set_shader_parameter("fade", fade)
					else:
						item["body"].material_override = item["body_mat"]
				if item["crystal"] != null:
					if fade > 0.02:
						item["crystal"].material_override = item["crystal_fade"]
						item["crystal_fade"].set_shader_parameter("fade", fade)
					else:
						item["crystal"].material_override = item["crystal_mat"]

	for uid in hero_nodes:
		var item: Dictionary = hero_nodes[uid]
		var u = null
		for x in sim.heroes:
			if x.uid == uid:
				u = x
				break
		item["root"].visible = u != null and u.is_alive()

	var dead_minions: Array = []
	for uid in minion_nodes:
		if not live.has(uid):
			(minion_nodes[uid] as Dictionary)["root"].queue_free()
			dead_minions.append(uid)
	for uid in dead_minions:
		minion_nodes.erase(uid)

	_sync_potions()


func _face_yaw(item: Dictionary, u, delta: float) -> void:
	# 朝向跟随移动/攻击/施法方向（任意角度）；保留水平行走的 20° 露脸偏置，
	# 纯竖直不偏。3v3 水平移动时与旧版 ±(90°-19.5°) 完全一致。
	if not item.has("yaw"):
		var y0 := PI * 0.5 - 0.34
		item["yaw"] = y0 if u.facing >= 0.0 else -y0
	var d: Vector2 = u.face_dir
	if d.length_squared() > 0.0001:
		d = d.normalized()
		var yaw_target := atan2(d.x, d.y) - 0.34 * signf(d.x) * (1.0 - absf(d.y))
		item["yaw"] = lerp_angle(float(item["yaw"]), yaw_target, 1.0 - exp(-12.0 * delta))
	(item["root"] as Node3D).rotation.y = float(item["yaw"])


func _sync_potions() -> void:
	# 一塔后的回血药剂：绿色小药瓶 + 地面光圈，喝掉后隐藏，30 秒后重新出现。
	for p in sim.potions:
		var node: Node3D = potion_nodes.get(p.view_id)
		if node == null:
			node = _make_potion_node()
			add_child(node)
			potion_nodes[p.view_id] = node
		node.visible = p.active
		if not p.active:
			continue
		var bob := sin(Time.get_ticks_msec() * 0.003 + float(p.view_id) * 1.7) * 4.0
		node.position = Vector3(p.pos.x, 2.0 + bob, p.pos.y)
		node.rotation.y += 0.02


func _make_potion_node() -> Node3D:
	# 不透明体素小瓶：绿玻璃 + 浅绿颈 + 木塞 + 白十字；脚下 alpha 光晕环保留。
	var root := Node3D.new()
	var mesh = _model("potion", func(): return BlockModels.potion(atlas))
	var body := _make_instance(mesh)
	root.add_child(body)
	var glow := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 30.0
	gm.bottom_radius = 30.0
	gm.height = 0.6
	gm.radial_segments = 28
	glow.mesh = gm
	glow.position.y = 1.0
	glow.material_override = _alpha_material(Color(0.45, 1.0, 0.6, 0.22))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	return root


func _step_clouds(delta: float) -> void:
	for c in cloud_nodes:
		var node: Node3D = c["node"]
		node.position.x += float(c["speed"]) * delta
		if node.position.x > sim.map_w + 500.0:
			node.position.x = -500.0


func _sync_hero(u, delta: float) -> void:
	var item = hero_nodes.get(u.uid)
	if item == null:
		_add_hero(u)
		item = hero_nodes[u.uid]
	var root: Node3D = item["root"]
	var s: float = item["scale"]
	var rp: Vector2 = sim.render_pos(u)
	root.position = Vector3(rp.x, 0, rp.y)
	_face_yaw(item, u, delta)
	# 攻击起始帧：按英雄的主武器放一次挥砍/弓弦/法杖闪光。
	var atk_now: bool = u.atk_anim > 0.0
	if atk_now and not bool(item.get("atk_active", false)):
		_weapon_strike(u)
	item["atk_active"] = atk_now
	var step := 1.0 / 30.0
	var wt: float = u.walk_t
	if u.moving:
		wt -= (1.0 - sim.interp_alpha) * step
	var bob := absf(sin(wt * 9.0)) * (4.0 if u.moving else 0.0)
	root.position.y = bob
	if u.move_skill_total > 0.0:
		var mk := 1.0 - clampf(u.move_skill_t / u.move_skill_total, 0.0, 1.0)
		if u.move_skill_kind == "leap":
			root.position.y += sin(mk * PI) * 72.0
		elif u.move_skill_kind == "backstep":
			root.position.y += sin(mk * PI) * 18.0
	var sxz := 1.0
	var sy := 1.0
	if u.atk_anim > 0.0:
		var k: float = 1.0 - u.atk_anim / 0.34
		sxz = 1.0 + sin(k * PI) * 0.08
		sy = 1.0 - sin(k * PI) * 0.06
	if u.hurt_anim > 0.0:
		sxz = 0.94
	root.scale = Vector3(s * sxz, s * sy, s * sxz)

	var limbs: Dictionary = item["limbs"]
	var now := Time.get_ticks_msec() * 0.001
	var phase := now + float(u.uid) * 0.7
	var swing := sin(wt * 9.0) if u.moving else 0.0

	# 腿：走路前后摆；待机时轻微屈膝。
	var leg_l: Node3D = limbs["leg_l"]
	var leg_r: Node3D = limbs["leg_r"]
	leg_l.rotation.x = swing * 0.72
	leg_r.rotation.x = -swing * 0.72

	# 手臂：先铺走路摆臂 + 待机呼吸，再叠加攻击/施法姿势。
	var idle := sin(phase * 2.2) * 0.05
	var arm_l: Node3D = limbs["arm_l"]
	var arm_r: Node3D = limbs["arm_r"]
	var arm_l_x := -swing * 0.58 + idle
	var arm_r_x := swing * 0.58 - idle
	var arm_l_z := 0.06 + sin(phase * 1.7) * 0.03
	var arm_r_z := -arm_l_z

	if u.atk_anim > 0.0:
		var k: float = 1.0 - u.atk_anim / 0.34
		var punch := sin(k * PI)
		if u.attack_range > 250.0:
			# 远程：双手前推。
			arm_l_x = -1.25 * punch
			arm_r_x = -1.25 * punch
		else:
			# 近战：右手抡爪，左手后撤。
			arm_r_x = -2.15 * punch
			arm_r_z = -0.35 * punch
			arm_l_x = 0.35 * punch

	if u.cast_anim > 0.0:
		var ck: float = 1.0 - u.cast_anim / maxf(0.01, u.cast_total)
		var raise := sin(ck * PI)
		arm_l_x = -2.35 * raise
		arm_r_x = -2.35 * raise
		arm_l_z = 0.3 * raise
		arm_r_z = -0.3 * raise

	arm_l.rotation.x = arm_l_x
	arm_r.rotation.x = arm_r_x
	arm_l.rotation.z = arm_l_z
	arm_r.rotation.z = arm_r_z

	# 头：走路点头 + 受击后仰 + 施法抬下巴。
	var head: Node3D = limbs["head"]
	var head_x := sin(wt * 9.0) * 0.045 * (1.0 if u.moving else 0.0)
	head_x += sin(phase * 2.0) * 0.02
	if u.hurt_anim > 0.0:
		head_x -= 0.28
	if u.cast_anim > 0.0:
		head_x += 0.18
	head.rotation.x = head_x
	head.rotation.y = sin(phase * 0.9) * 0.10

	# 尾巴：左右甩 + 走路时上下颤。
	var tail: Node3D = limbs["tail"]
	tail.rotation.y = sin(phase * 4.2) * (0.38 + (0.18 if u.moving else 0.0))
	tail.rotation.x = sin(phase * 3.1) * 0.12 - swing * 0.10

	# 入场姿势：1.1 秒内覆盖手臂/头部，之后自然回到常规动画。
	var et: float = float(item.get("entrance_t", 0.0))
	if et > 0.0:
		et = maxf(0.0, et - delta)
		item["entrance_t"] = et
		var ek := sin((1.0 - et / 1.1) * PI)
		match u.hero_id:
			"turtle":
				arm_l.rotation.x = -2.1 * ek
				arm_r.rotation.x = 0.35 * ek
				head.rotation.x = 0.14 * ek
			"hedgehog":
				arm_l.rotation.x = -2.3 * ek
				arm_r.rotation.x = -2.3 * ek
				head.rotation.x = -0.12 * ek
			"redpanda":
				arm_r.rotation.x = -2.6 * ek
				arm_l.rotation.x = 0.5 * ek
				head.rotation.x = -0.20 * ek
				tail.rotation.x = 0.5 * ek
			"wolf":
				head.rotation.x = -0.5 * ek
				arm_l.rotation.x = 0.55 * ek
				arm_r.rotation.x = 0.55 * ek
			"crane":
				arm_l.rotation.z = 1.15 * ek
				arm_r.rotation.z = -1.15 * ek
				arm_r.rotation.x = -1.7 * ek
				head.rotation.x = -0.10 * ek


func _sync_minion(u, delta: float) -> void:
	var item = minion_nodes.get(u.uid)
	if item == null:
		_add_minion(u)
		item = minion_nodes[u.uid]
	var root: Node3D = item["root"]
	root.visible = true
	var rp: Vector2 = sim.render_pos(u)
	var step := 1.0 / 30.0
	var wt: float = u.walk_t
	if u.moving:
		wt -= (1.0 - sim.interp_alpha) * step
	root.position = Vector3(rp.x, absf(sin(wt * 8.0)) * (5.0 if u.moving else 0.0), rp.y)
	_face_yaw(item, u, delta)
	var sxz := 1.0
	var sy := 1.0
	if u.atk_anim > 0.0:
		var k: float = 1.0 - u.atk_anim / 0.22
		sxz = 1.0 + sin(k * PI) * 0.16
		sy = 1.0 - sin(k * PI) * 0.14
	root.scale = Vector3(sxz, sy, sxz)


func _shot_material(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if shot_mats.has(key):
		return shot_mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	shot_mats[key] = m
	return m


func _sync_shots() -> void:
	var live: Dictionary = {}
	for p in sim.shots:
		live[p.view_id] = true
		var node = shot_nodes.get(p.view_id)
		if node == null:
			if not shot_free.is_empty():
				node = shot_free.pop_back()
			else:
				node = _make_shot_node()
				add_child(node)
			shot_nodes[p.view_id] = node
		node.visible = true
		var rp: Vector2 = p.prev_pos.lerp(p.pos, sim.interp_alpha)
		node.position = Vector3(rp.x, 34.0, rp.y)
		node.mesh = _shot_mesh(p.style)
		node.material_override = _shot_material(Color(p.color.r, p.color.g, p.color.b, 0.95))
		var sz: float = maxf(0.7, p.size / 7.0)
		node.scale = Vector3(sz, sz, sz)
		# 箭矢沿飞行方向，其他弹道自旋，让不同英雄的普攻一眼能区分。
		match p.style:
			"arrow":
				node.rotation.y = atan2(p.dir.x, p.dir.y)
				node.rotation.z = 0.0
			"leaf":
				node.rotation.y += 0.16
				node.rotation.z = 0.55
			"star":
				node.rotation.y += 0.30
				node.rotation.z = 0.78
			"moon":
				node.rotation.y += 0.35
				node.rotation.z = 0.2
			"bubble":
				node.rotation.y += 0.06
				node.rotation.z = 0.0
			_:
				node.rotation.y += 0.25
				node.rotation.z = 0.0

	var dead: Array = []
	for vid in shot_nodes:
		if not live.has(vid):
			var node: MeshInstance3D = shot_nodes[vid]
			node.visible = false
			shot_free.append(node)
			dead.append(vid)
	for vid in dead:
		shot_nodes.erase(vid)


func _make_shot_node() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _shot_mesh("cube")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _shot_mesh(style: String) -> Mesh:
	if shot_meshes.has(style):
		return shot_meshes[style]
	var mesh: Mesh
	match style:
		"arrow":
			var b := BoxMesh.new()
			b.size = Vector3(5, 5, 26)
			mesh = b
		"leaf":
			var b := BoxMesh.new()
			b.size = Vector3(9, 3, 18)
			mesh = b
		"claw":
			var b := BoxMesh.new()
			b.size = Vector3(7, 4, 20)
			mesh = b
		"star":
			var b := BoxMesh.new()
			b.size = Vector3(16, 5, 16)
			mesh = b
		"bubble":
			var s := SphereMesh.new()
			s.radius = 9.0
			s.height = 18.0
			s.radial_segments = 10
			s.rings = 5
			mesh = s
		"moon":
			var t := TorusMesh.new()
			t.inner_radius = 4.0
			t.outer_radius = 9.0
			t.rings = 10
			t.ring_segments = 4
			mesh = t
		_:
			var b := BoxMesh.new()
			b.size = Vector3(13, 13, 13)
			mesh = b
	shot_meshes[style] = mesh
	return mesh


func _sync_zones() -> void:
	if zone_mesh == null:
		# 用扁平圆柱做圆形范围指示，避免方块缩放后变成方形。
		zone_mesh = CylinderMesh.new()
		zone_mesh.top_radius = 1.0
		zone_mesh.bottom_radius = 1.0
		zone_mesh.height = 0.8
		zone_mesh.radial_segments = 32
		zone_mesh.rings = 1
	while zone_nodes.size() < sim.zones.size():
		var node := MeshInstance3D.new()
		node.mesh = zone_mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		zone_nodes.append(node)
	for i in range(zone_nodes.size()):
		var node: MeshInstance3D = zone_nodes[i]
		if i >= sim.zones.size():
			node.visible = false
			continue
		var z = sim.zones[i]
		node.visible = true
		node.position = Vector3(z.pos.x, 1.2, z.pos.y)
		node.scale = Vector3(z.radius, 1.0, z.radius)
		node.material_override = _alpha_material(Color(z.color.r, z.color.g, z.color.b, 0.30))


func _alpha_material(c: Color, unshaded := true) -> StandardMaterial3D:
	var key := c.to_html() + "_" + str(unshaded)
	if alpha_mats.has(key):
		return alpha_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	alpha_mats[key] = m
	return m


func _on_fx(kind: String, pos: Vector3, color: Color, radius: float) -> void:
	if kind.begins_with("cast_"):
		_spawn_style(kind.substr(5), pos, color, radius)
		return
	match kind:
		"ring":
			_spawn_ring(pos, color, maxf(radius, 30.0), 0.42)
		"burst":
			_spawn_burst(pos, color, 0.36)
		"hit":
			_spawn_burst(pos, color, 0.20)
		"slash":
			_spawn_slash(pos, color)
		"muzzle":
			_spawn_burst(pos, color, 0.14)
		"debris":
			_spawn_debris(pos, color, maxi(6, int(radius / 16.0)))
		"potion_spawn":
			_spawn_style("leafheal", pos, color, 110.0)
		"potion_pick":
			_spawn_style("leafheal", pos, color, 90.0)
			_spawn_burst(pos, color, 0.30)


func _on_beam_fx(from: Vector3, to: Vector3, color: Color, width: float) -> void:
	# 光柱 / 月链 / 鹤羽：用一根细长盒子连接两点，短暂闪过后消失。
	var delta := to - from
	var length := delta.length()
	if length < 1.0:
		return
	var mesh := _fx_mesh("fx_beam", func():
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 1.0, 1.0)
		return bm)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = from + delta * 0.5
	node.scale = Vector3(length, maxf(width, 8.0), maxf(width, 8.0))
	node.rotation = Vector3(0.0, atan2(-delta.z, delta.x), 0.0)
	node.material_override = _fx_mat(color, 0.85)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	fx_items.append({"node": node, "t": 0.0, "life": 0.24, "start": 0.35, "end": 2.2})
	_spawn_burst(to, color, 0.28)


func _spawn_ring(pos: Vector3, color: Color, radius: float, life: float) -> void:
	var node := MeshInstance3D.new()
	var rkey := "fx_ring_%d" % int(round(radius))
	var torus: Mesh
	if fx_mesh_cache.has(rkey):
		torus = fx_mesh_cache[rkey]
	else:
		var tm := TorusMesh.new()
		tm.inner_radius = radius * 0.90
		tm.outer_radius = radius
		tm.rings = 32
		tm.ring_segments = 6
		fx_mesh_cache[rkey] = tm
		torus = tm
	node.mesh = torus
	node.position = Vector3(pos.x, 1.6, pos.z)
	node.material_override = _alpha_material(Color(color.r, color.g, color.b, 0.85))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	fx_items.append({"node": node, "t": 0.0, "life": life, "start": 0.75, "end": 1.15})


func _spawn_burst(pos: Vector3, color: Color, life: float) -> void:
	var node := MeshInstance3D.new()
	var cube: Mesh
	if fx_mesh_cache.has("fx_burst"):
		cube = fx_mesh_cache["fx_burst"]
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(20, 20, 20)
		fx_mesh_cache["fx_burst"] = bm
		cube = bm
	node.mesh = cube
	node.position = Vector3(pos.x, maxf(pos.y, 10.0), pos.z)
	node.material_override = _alpha_material(Color(color.r, color.g, color.b, 0.92))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	fx_items.append({"node": node, "t": 0.0, "life": life, "start": 0.5, "end": 1.7})


func _spawn_slash(pos: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var box: Mesh
	if fx_mesh_cache.has("fx_slash"):
		box = fx_mesh_cache["fx_slash"]
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(96, 8, 18)
		fx_mesh_cache["fx_slash"] = bm
		box = bm
	node.mesh = box
	node.position = Vector3(pos.x, 34.0, pos.z)
	node.rotation_degrees = Vector3(0, 0, 22)
	node.material_override = _alpha_material(Color(color.r, color.g, color.b, 0.9))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	fx_items.append({"node": node, "t": 0.0, "life": 0.13, "start": 0.6, "end": 1.1})


func _fx_mat(c: Color, a := 0.9) -> StandardMaterial3D:
	var key := "fx_" + c.to_html() + "_" + str(a)
	if alpha_mats.has(key):
		return alpha_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	alpha_mats[key] = m
	return m


func _fx_mesh(key: String, factory: Callable) -> Mesh:
	if fx_mesh_cache.has(key):
		return fx_mesh_cache[key]
	var m: Mesh = factory.call()
	fx_mesh_cache[key] = m
	return m


func _add_fx_mesh(mesh: Mesh, mat: Material, at: Vector3, life: float, start: float, end: float,
		vel := Vector3.ZERO, spin := Vector3.ZERO, rot := Vector3.ZERO) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.rotation = rot
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var item: Dictionary = {"node": node, "t": 0.0, "life": life, "start": start, "end": end}
	if vel != Vector3.ZERO:
		item["vel"] = vel
	if spin != Vector3.ZERO:
		item["spin"] = spin
	fx_items.append(item)


func _weapon_strike(u) -> void:
	# 每次攻击只触发一次，纯表现；不消耗逻辑随机数。
	var rp: Vector2 = sim.render_pos(u)
	var at := Vector3(rp.x, 0.0, rp.y)
	match u.hero_id:
		"tiger":
			_spawn_slashes(at + Vector3(0, 30, 0), Color("ffffff"), 3, 100.0)
		"wolf":
			_spawn_slashes(at + Vector3(0, 30, 0), Color("f4f8ff"), 3, 96.0)
		"hedgehog":
			_spawn_slashes(at + Vector3(0, 28, 0), Color("ffffff"), 3, 84.0)
		"bear":
			_spawn_ring(at, Color("8a6a4a"), 62.0, 0.50)
			_spawn_ring(at, Color("d8c09a"), 44.0, 0.40)
			_spawn_burst(at + Vector3(0, 8, 0), Color("c8a87a"), 0.24)
			_spawn_debris(at + Vector3(0, 6, 0), Color("8a6a4a"), 6)
		"turtle":
			_spawn_ring(at, Color("e0604f"), 54.0, 0.42)
			_spawn_burst(at + Vector3(0, 8, 0), Color("c8a87a"), 0.22)
			_spawn_debris(at + Vector3(0, 4, 0), Color("b28c5c"), 4)
		"panda":
			_spawn_style("leaf", at, Color("9bd968"), 60.0)
		"redpanda":
			_spawn_slashes(at + Vector3(0, 30, 0), Color("ff9a4a"), 3, 104.0)
		"cat", "deer":
			var line_c := Color("f5eedc") if u.hero_id == "cat" else Color("e8f6c8")
			_spawn_arrow_line(at, u.face_dir, line_c)
		"fox":
			_spawn_burst(at + Vector3(0, 48, 0), Color("c9a6ff"), 0.12)
		"owl":
			_spawn_burst(at + Vector3(0, 48, 0), Color("d9c2ff"), 0.12)
		"rabbit":
			_spawn_burst(at + Vector3(0, 44, 0), Color("ffe7a8"), 0.12)
		"frog":
			_spawn_burst(at + Vector3(0, 44, 0), Color("bfe9ff"), 0.14)
		"crane":
			_spawn_burst(at + Vector3(0, 46, 0), Color("e8e4ff"), 0.12)
		"axolotl":
			_spawn_ring(at, Color("8ff0e0"), 38.0, 0.30)


func _spawn_arrow_line(pos: Vector3, dir: Vector2, c: Color) -> void:
	# 弓弦箭线：沿朝向拉出一根细亮线，和真实弹道区分开。
	if dir.length_squared() < 0.001:
		return
	var d := dir.normalized()
	var mesh := _fx_mesh("fx_arrow_line", func():
		var bm := BoxMesh.new()
		bm.size = Vector3(46, 2.4, 2.4)
		return bm)
	var at := Vector3(pos.x, 30.0, pos.z) + Vector3(d.x, 0.0, d.y) * 34.0
	_add_fx_mesh(mesh, _fx_mat(c, 0.85), at, 0.16, 1.0, 1.0, Vector3.ZERO, Vector3.ZERO,
		Vector3(0.0, atan2(-d.y, d.x), 0.0))


func _entrance_fx(u) -> void:
	# 5v5 五位英雄的开场小特效。
	var rp: Vector2 = sim.render_pos(u)
	var at := Vector3(rp.x, 0.0, rp.y)
	match u.hero_id:
		"turtle":
			_spawn_ring(at, Color("e0604f"), 46.0, 0.40)
			_spawn_debris(at + Vector3(0, 4, 0), Color("b28c5c"), 3)
		"hedgehog":
			_spawn_ring(at, Color("e0604f"), 40.0, 0.35)
			_spawn_burst(at + Vector3(0, 30, 0), Color("f4f8ff"), 0.22)
		"redpanda":
			_spawn_ring(at, Color("f27a32"), 52.0, 0.45)
			_spawn_slashes(at + Vector3(0, 30, 0), Color("ffb066"), 3, 90.0)
		"wolf":
			_spawn_roar(at, Color("9aa8b8"), 110.0)
		"crane":
			_spawn_ring(at, Color("9fe8f0"), 60.0, 0.45)
			_spawn_feathers(at, Color("c8e8ff"), 100.0)


func _spawn_style(style: String, pos: Vector3, color: Color, radius: float) -> void:
	# 每个英雄的施法形状不同：爪痕 / 星星 / 叶子 / 竹子 / 水泡 / 月光 / 羽刃…
	match style:
		"claw", "clawstorm":
			_spawn_slashes(pos, color, 6 if style == "clawstorm" else 3, maxf(radius, 120.0))
		"roll":
			_spawn_slashes(pos, color, 4, maxf(radius, 100.0))
		"star", "starfall", "blink":
			_spawn_stars(pos, color, 8 if style == "starfall" else 5, radius)
		"leaf", "leafheal":
			_spawn_leaves(pos, color, maxf(radius, 130.0))
		"bamboo_ult":
			_spawn_bamboo(pos, color, maxf(radius, 190.0))
		"claw_ult":
			_spawn_claw_ult(pos, color, maxf(radius, 180.0))
		"claw_radial":
			_spawn_claw_radial(pos, color, maxf(radius, 180.0))
		"starfall_ult":
			_spawn_star_fall(pos, color, maxf(radius, 180.0))
		"moon_ult":
			_spawn_moon_ult(pos, color, maxf(radius, 175.0))
		"quake_ult":
			_spawn_quake_ult(pos, color, maxf(radius, 190.0))
		"waterfall_ult":
			_spawn_waterfall_ult(pos, color, maxf(radius, 175.0))
		"nightfall_ult":
			_spawn_nightfall_ult(pos, color, maxf(radius, 185.0))
		"leafsmash", "quake", "bamboo", "spikes":
			_spawn_ground(pos, color, maxf(radius, 150.0), style)
		"moon", "nightfall":
			_spawn_moon(pos, color, maxf(radius, 150.0))
		"bubble", "waterfall", "wave":
			_spawn_bubbles(pos, color, maxf(radius, 110.0))
		"feather":
			_spawn_feathers(pos, color, maxf(radius, 140.0))
		"heart":
			_spawn_heart(pos, color)
		"roar", "mark", "fear":
			_spawn_roar(pos, color, maxf(radius, 160.0))
		"taunt":
			_spawn_heart(pos, color)
			_spawn_ring(pos, color, maxf(radius, 140.0), 0.55)
		"spin":
			_spawn_spin(pos, color, maxf(radius, 140.0))
		"trap":
			_spawn_ground(pos, color, maxf(radius, 120.0), "spikes")
		"heal_zone":
			_spawn_bubbles(pos, color, maxf(radius, 130.0))
			_spawn_leaves(pos, color, maxf(radius, 130.0))
		"boomerang":
			_spawn_stars(pos, color, 4, maxf(radius, 90.0))
		"beam", "chain":
			_spawn_burst(pos, color, 0.30)
		_:
			_spawn_burst(pos, color, 0.30)


func _spawn_spin(pos: Vector3, color: Color, radius: float) -> void:
	# 刺球旋身：一圈贴身圆环 + 四面飞出的短刺。
	_spawn_ring(pos, color, radius * 0.82, 0.48)
	var mat := _fx_mat(color, 0.95)
	var mesh := _fx_mesh("fx_spin_spike", func():
		var bm := BoxMesh.new()
		bm.size = Vector3(10, 10, 34)
		return bm)
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		_add_fx_mesh(mesh, mat, pos + Vector3(cos(ang), 0.0, sin(ang)) * radius * 0.58
			+ Vector3(0.0, 24.0, 0.0), 0.42, 0.35, 1.5,
			Vector3.ZERO, Vector3(0.0, 6.0, 0.0), Vector3(0.0, ang, 0.0))


func _spawn_slashes(pos: Vector3, color: Color, count: int, radius: float) -> void:
	var mat := _fx_mat(color, 0.92)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(46.0, radius * 0.50), 6, 10)
	for i in range(count):
		var a := -0.95 + (1.9 * float(i) / maxf(1.0, float(count - 1)))
		_add_fx_mesh(mesh, mat, pos + Vector3(0, 30.0, 0), 0.34, 0.55, 1.35,
			Vector3.ZERO, Vector3.ZERO, Vector3(0.0, a, 0.55))


func _spawn_stars(pos: Vector3, color: Color, count: int, radius: float) -> void:
	var mat := _fx_mat(color, 0.95)
	var mesh: Mesh
	if fx_mesh_cache.has("fx_star"):
		mesh = fx_mesh_cache["fx_star"]
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(15, 15, 4)
		fx_mesh_cache["fx_star"] = bm
		mesh = bm
	for i in range(count):
		var ang := TAU * float(i) / float(count)
		var at := pos + Vector3(cos(ang), 0, sin(ang)) * (18.0 + radius * 0.18)
		at.y = 26.0 + float(i % 3) * 10.0
		_add_fx_mesh(mesh, mat, at, 0.70, 0.5, 1.25,
			Vector3(0, 50, 0), Vector3(0, 3.0, 4.0), Vector3(0, ang, PI * 0.25))


func _spawn_leaves(pos: Vector3, color: Color, radius: float) -> void:
	var mat := _fx_mat(color, 0.90)
	var mesh: Mesh
	if fx_mesh_cache.has("fx_leaf"):
		mesh = fx_mesh_cache["fx_leaf"]
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(11, 3, 19)
		fx_mesh_cache["fx_leaf"] = bm
		mesh = bm
	for i in range(7):
		var ang := TAU * float(i) / 7.0
		var at := pos + Vector3(cos(ang), 0, sin(ang)) * (radius * 0.45)
		at.y = 12.0
		_add_fx_mesh(mesh, mat, at, 0.85, 0.4, 1.2,
			Vector3(0, 70, 0), Vector3(0, 5, 0), Vector3(0.2, ang, 0.55))


func _spawn_ground(pos: Vector3, color: Color, radius: float, style: String) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.82
	torus.outer_radius = radius * 0.92
	torus.rings = 32
	torus.ring_segments = 4
	_add_fx_mesh(torus, _fx_mat(color, 0.70), Vector3(pos.x, 6.0, pos.z), 0.70, 0.7, 1.2)
	if style == "quake":
		_spawn_debris(pos, color, 10)
	elif style == "leafsmash":
		_spawn_leaves(pos, color, radius)
	else:
		var mat := _fx_mat(color, 0.90)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(11, 62, 11)
		for i in range(8):
			var ang := TAU * float(i) / 8.0
			var at := pos + Vector3(cos(ang), 0, sin(ang)) * (radius * 0.55)
			at.y = 18.0
			_add_fx_mesh(mesh, mat, at, 0.75, 0.15, 1.25,
				Vector3.ZERO, Vector3.ZERO, Vector3(0.2, ang, 0.15))


func _spawn_bamboo(pos: Vector3, color: Color, radius: float) -> void:
	# 熊猫大招「竹林震地」：一圈竹竿从地里拔起来，带竹节、竹叶和地面冲击环。
	var ground := TorusMesh.new()
	ground.inner_radius = radius * 0.84
	ground.outer_radius = radius * 0.95
	ground.rings = 32
	ground.ring_segments = 4
	_add_fx_mesh(ground, _fx_mat(Color("A8E06A"), 0.85), Vector3(pos.x, 6.0, pos.z), 1.15, 0.55, 1.15)

	var stalk := _fx_mat(Color("7CBF4A"), 0.98)
	var node_mat := _fx_mat(Color("4E8C34"), 0.98)
	var leaf := _fx_mat(Color("9BD968"), 0.96)
	var count := 11
	for i in range(count):
		var ang := TAU * float(i) / float(count) + rng.randf_range(-0.10, 0.10)
		var rr := radius * rng.randf_range(0.20, 0.88)
		var at := pos + Vector3(cos(ang), 0.0, sin(ang)) * rr
		_make_bamboo(at, rng.randf_range(120.0, 190.0), rng.randf_range(12.0, 17.0),
			stalk, node_mat, leaf, float(i) * 0.035, ang)


func _make_pillar(base: Vector3, tall: float, thick: float, a: Material, b: Material,
		delay: float, rot_y: float, segs := 3) -> Node3D:
	# 根节点贴地，整体按 Y 轴拉伸，看起来就是从土里长出来。
	var root := Node3D.new()
	root.position = base
	root.rotation.y = rot_y
	add_child(root)
	var seg_h := tall / float(segs)
	for s in range(segs):
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(thick, seg_h * 0.93, thick)
		seg.mesh = box
		seg.position = Vector3(0.0, seg_h * (float(s) + 0.5), 0.0)
		seg.material_override = a if s % 2 == 0 else b
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(seg)
	root.visible = false
	sprout_items.append({"node": root, "t": -delay, "grow": 0.16, "hold": 0.75, "fade": 0.30})
	return root


func _make_bamboo(base: Vector3, tall: float, thick: float, stalk: Material, node_mat: Material,
		leaf: Material, delay: float, ang: float) -> void:
	var root := _make_pillar(base, tall, thick, stalk, node_mat, delay, ang)
	var seg_h := tall / 3.0
	for s in range(2):
		var ring := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(thick * 1.28, thick * 0.22, thick * 1.28)
		ring.mesh = box
		ring.position = Vector3(0.0, seg_h * float(s + 1), 0.0)
		ring.material_override = node_mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
	for l in range(4):
		var lf := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(7.0, 3.0, 30.0)
		lf.mesh = box
		lf.position = Vector3(cos(TAU * float(l) / 4.0) * 16.0, tall - 14.0 + float(l % 2) * 12.0,
			sin(TAU * float(l) / 4.0) * 16.0)
		lf.rotation = Vector3(0.22, TAU * float(l) / 4.0, 0.30)
		lf.material_override = leaf
		lf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lf)


func _spawn_claw_ult(pos: Vector3, color: Color, radius: float) -> void:
	# 阿狮「旋风爪」：橙色龙卷从脚下卷起，爪痕随旋风上升旋转。
	var base_ring := TorusMesh.new()
	base_ring.inner_radius = radius * 0.72
	base_ring.outer_radius = radius * 0.82
	base_ring.rings = 32
	base_ring.ring_segments = 4
	_add_fx_mesh(base_ring, _fx_mat(color, 0.65), Vector3(pos.x, 8.0, pos.z), 0.85, 0.5, 1.3)
	var wind := _fx_mat(Color(color.r, color.g * 0.92, color.b * 0.55), 0.14)
	for i in range(3):
		var col := CylinderMesh.new()
		col.top_radius = radius * (0.30 - float(i) * 0.06)
		col.bottom_radius = radius * (0.46 - float(i) * 0.08)
		col.height = 70.0
		col.radial_segments = 20
		_add_fx_mesh(col, wind, Vector3(pos.x, 34.0 + float(i) * 56.0, pos.z), 0.95, 0.55, 1.0)
	var mat := _fx_mat(color, 0.95)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(64, 7, 10)
	for i in range(12):
		var ang := TAU * float(i) / 12.0
		var at := pos + Vector3(cos(ang), 0.0, sin(ang)) * (radius * 0.42)
		at.y = 18.0 + float(i % 5) * 26.0
		_add_fx_mesh(mesh, mat, at, 0.80, 0.70, 1.25,
			Vector3(0, 210.0, 0), Vector3(0, 7.0, 0), Vector3(0, -ang, 0.55))
	var streak := BoxMesh.new()
	streak.size = Vector3(6, 96, 6)
	var streak_mat := _fx_mat(Color(1.0, 0.82, 0.42), 0.55)
	for i in range(6):
		var ang := TAU * float(i) / 6.0 + 0.3
		var at := pos + Vector3(cos(ang), 0.0, sin(ang)) * (radius * 0.50)
		_add_fx_mesh(streak, streak_mat, Vector3(at.x, 70.0, at.z), 0.75, 0.6, 1.0,
			Vector3(0, 160.0, 0), Vector3(0, 9.0, 0), Vector3(0.10, ang, 0.0))


func _spawn_claw_radial(pos: Vector3, color: Color, radius: float) -> void:
	# 尖尖「万爪齐发」：地面拍出五枚带描边的大爪印，短爪痕贴地向四周炸开。
	var pad_mat := _fx_mat(Color("6B4A22"), 0.95)
	var fill_mat := _fx_mat(color.lightened(0.25), 0.95)
	var pad_outline := BoxMesh.new()
	pad_outline.size = Vector3(36, 2.4, 30)
	var toe_outline := BoxMesh.new()
	toe_outline.size = Vector3(12, 2.4, 12)
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(29, 3.0, 23)
	var toe_mesh := BoxMesh.new()
	toe_mesh.size = Vector3(8, 3.0, 8)
	for i in range(5):
		var ang := TAU * float(i) / 5.0 + 0.35
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var paw := pos + dir * (radius * 0.52)
		paw.y = 3.2
		_add_fx_mesh(pad_outline, pad_mat, paw, 1.0, 0.25, 1.05,
			Vector3.ZERO, Vector3.ZERO, Vector3(0.0, -ang, 0.0))
		_add_fx_mesh(pad_mesh, fill_mat, paw + Vector3(0, 1.0, 0), 1.0, 0.25, 1.05,
			Vector3.ZERO, Vector3.ZERO, Vector3(0.0, -ang, 0.0))
		for t in range(3):
			var local := Vector3(22.0, 0.0, (float(t) - 1.0) * 9.0)
			var toe := paw + (Basis(Vector3.UP, -ang) * local)
			_add_fx_mesh(toe_outline, pad_mat, toe, 1.0, 0.2, 1.05,
				Vector3.ZERO, Vector3.ZERO, Vector3(0.0, -ang, 0.0))
			_add_fx_mesh(toe_mesh, fill_mat, toe + Vector3(0, 1.0, 0), 1.0, 0.2, 1.05,
				Vector3.ZERO, Vector3.ZERO, Vector3(0.0, -ang, 0.0))
	var mat := _fx_mat(Color(1.0, 0.97, 0.62), 0.95)
	var claw := BoxMesh.new()
	claw.size = Vector3(34, 5, 8)
	for i in range(10):
		var ang := TAU * float(i) / 10.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var at := pos + dir * 30.0
		at.y = 10.0
		_add_fx_mesh(claw, mat, at, 0.40, 0.6, 1.35,
			dir * 420.0, Vector3.ZERO, Vector3(0.0, -ang, 0.0))


func _spawn_star_fall(pos: Vector3, color: Color, radius: float) -> void:
	# 灵灵「星河坠落」：星星拖着长尾从天上砸下来。
	var mat := _fx_mat(color, 0.95)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(18, 52, 8)
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		var at := pos + Vector3(cos(ang), 0, sin(ang)) * (radius * rng.randf_range(0.12, 0.80))
		at.y = 200.0 + float(i % 3) * 30.0
		_add_fx_mesh(mesh, mat, at, 0.55, 0.5, 1.4,
			Vector3(0, -450.0, 0), Vector3(0, 6.0, 0), Vector3(0, ang, 0))
	_spawn_stars(pos, color, 6, radius)
	_spawn_ring(pos, color, radius, 0.55)


func _spawn_moon_ult(pos: Vector3, color: Color, radius: float) -> void:
	# 朵朵「满月祝福」：天上升起大满月，月光柱落到地面。
	var disc := CylinderMesh.new()
	disc.top_radius = radius * 0.52
	disc.bottom_radius = radius * 0.52
	disc.height = 5.0
	disc.radial_segments = 28
	_add_fx_mesh(disc, _fx_mat(Color(1.0, 0.97, 0.72), 0.88), Vector3(pos.x, 165.0, pos.z),
		1.15, 0.25, 1.05, Vector3.ZERO, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))
	var beam := BoxMesh.new()
	beam.size = Vector3(16, 190, 16)
	var beam_mat := _fx_mat(Color(1.0, 0.98, 0.80), 0.32)
	for i in range(5):
		var ang := TAU * float(i) / 5.0
		var at := pos + Vector3(cos(ang), 0, sin(ang)) * (radius * 0.52)
		_add_fx_mesh(beam, beam_mat, Vector3(at.x, 96.0, at.z), 1.0, 0.85, 0.95)
	_spawn_leaves(pos, color, radius)
	_spawn_ring(pos, color, radius, 0.6)


func _spawn_quake_ult(pos: Vector3, color: Color, radius: float) -> void:
	# 阿岳「山崩地裂」：地面裂开放射状裂缝，巨石从天砸落，扬尘环扩散。
	var crack := _fx_mat(Color("2E2118"), 0.92)
	var crack_mesh := BoxMesh.new()
	crack_mesh.size = Vector3(56, 3.0, 13)
	for i in range(12):
		var ang := TAU * float(i) / 12.0 + rng.randf_range(-0.10, 0.10)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var base_r := radius * rng.randf_range(0.10, 0.24)
		var near := pos + dir * base_r
		near.y = 2.4
		_add_fx_mesh(crack_mesh, crack, near, 1.05, 0.15, 1.0,
			Vector3.ZERO, Vector3.ZERO, Vector3(0.0, -ang, 0.0))
		var far := pos + dir * (base_r + radius * rng.randf_range(0.26, 0.40))
		far.y = 2.4
		_add_fx_mesh(crack_mesh, crack, far, 1.05, 0.10, 0.9,
			Vector3.ZERO, Vector3.ZERO, Vector3(0.0, -ang + rng.randf_range(-0.35, 0.35), 0.0))
	var boulder := SphereMesh.new()
	boulder.radius = 17.0
	boulder.height = 34.0
	boulder.radial_segments = 7
	boulder.rings = 4
	for i in range(7):
		var ang := TAU * float(i) / 7.0 + rng.randf_range(-0.16, 0.16)
		var at := pos + Vector3(cos(ang), 0.0, sin(ang)) * (radius * rng.randf_range(0.15, 0.80))
		var top := rng.randf_range(120.0, 170.0)
		at.y = top
		_add_fx_mesh(boulder, _fx_mat(Color("8A6A4A") if i % 2 == 0 else Color("6A4E36"), 0.98),
			at, top / 480.0, 1.0, 1.05, Vector3(0, -480.0, 0), Vector3(4.0, 3.0, 2.0))
	var dust := TorusMesh.new()
	dust.inner_radius = radius * 0.62
	dust.outer_radius = radius * 0.80
	dust.rings = 32
	dust.ring_segments = 4
	_add_fx_mesh(dust, _fx_mat(Color("C8A87A"), 0.55), Vector3(pos.x, 7.0, pos.z), 0.85, 0.35, 1.5)
	_spawn_debris(pos, color, 14)


func _spawn_waterfall_ult(pos: Vector3, color: Color, radius: float) -> void:
	# 泡泡「瀑布冲击」：三重浪环向外炸开，白色浪花与气泡四散。
	var wave_a := _fx_mat(Color(0.35, 0.66, 0.95), 0.62)
	var wave_b := _fx_mat(Color(0.62, 0.88, 1.0), 0.50)
	for i in range(3):
		var ring := TorusMesh.new()
		ring.inner_radius = radius * (0.30 + float(i) * 0.12)
		ring.outer_radius = radius * (0.42 + float(i) * 0.12)
		ring.rings = 32
		ring.ring_segments = 4
		_add_fx_mesh(ring, wave_a if i % 2 == 0 else wave_b,
			Vector3(pos.x, 7.0 + float(i) * 4.0, pos.z), 0.85, 0.45, 1.55)
	var foam := BoxMesh.new()
	foam.size = Vector3(26, 9, 12)
	var foam_mat := _fx_mat(Color(0.90, 0.98, 1.0), 0.88)
	for i in range(16):
		var ang := TAU * float(i) / 16.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var at := pos + dir * (radius * 0.34)
		at.y = 12.0
		_add_fx_mesh(foam, foam_mat, at, 0.55, 0.7, 1.15,
			dir * 300.0 + Vector3(0, 40.0, 0), Vector3.ZERO, Vector3(0, -ang, 0))
	var drop := SphereMesh.new()
	drop.radius = 8.0
	drop.height = 16.0
	drop.radial_segments = 8
	drop.rings = 4
	var drop_mat := _fx_mat(Color(0.80, 0.95, 1.0), 0.70)
	for i in range(9):
		var ang := TAU * float(i) / 9.0
		var at := pos + Vector3(cos(ang), 0, sin(ang)) * (radius * 0.38)
		_add_fx_mesh(drop, drop_mat, Vector3(at.x, 46.0, at.z), 0.62, 0.6, 1.15, Vector3(0, 270.0, 0))
	_spawn_bubbles(pos, color, radius)


func _spawn_nightfall_ult(pos: Vector3, color: Color, radius: float) -> void:
	# 咕咕「夜枭俯冲」：夜色罩住地面，两只月光眼睁开，羽刃落下。
	var shade := CylinderMesh.new()
	shade.top_radius = radius * 0.95
	shade.bottom_radius = radius * 0.95
	shade.height = 2.0
	shade.radial_segments = 28
	_add_fx_mesh(shade, _fx_mat(Color(0.20, 0.16, 0.38), 0.48), Vector3(pos.x, 2.0, pos.z), 1.05, 0.55, 1.12)
	var eye := CylinderMesh.new()
	eye.top_radius = 26.0
	eye.bottom_radius = 26.0
	eye.height = 3.0
	eye.radial_segments = 16
	var eye_mat := _fx_mat(Color(1.0, 0.94, 0.62), 0.92)
	for sx in [-1.0, 1.0]:
		_add_fx_mesh(eye, eye_mat, Vector3(pos.x + sx * 56.0, 176.0, pos.z), 1.05, 0.08, 0.95,
			Vector3.ZERO, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))
	var feather := BoxMesh.new()
	feather.size = Vector3(5, 2, 28)
	var fmat := _fx_mat(color, 0.92)
	for i in range(7):
		var ang := TAU * float(i) / 7.0
		var at := pos + Vector3(cos(ang), 0, sin(ang)) * (radius * rng.randf_range(0.15, 0.7))
		at.y = 230.0
		_add_fx_mesh(feather, fmat, at, 0.70, 0.6, 1.25,
			Vector3(0, -420.0, 0), Vector3(0, 9.0, 0), Vector3(0.3, ang, 0.0))
	_spawn_feathers(pos, color, radius)


func _step_sprouts(delta: float) -> void:
	for i in range(sprout_items.size() - 1, -1, -1):
		var item: Dictionary = sprout_items[i]
		item["t"] = float(item["t"]) + delta
		var node: Node3D = item["node"]
		var t: float = float(item["t"])
		if t < 0.0:
			continue
		node.visible = true
		var grow: float = float(item["grow"])
		var hold_end: float = grow + float(item["hold"])
		var total: float = hold_end + float(item["fade"])
		if t >= total:
			node.queue_free()
			sprout_items.remove_at(i)
			continue
		var k := 1.0
		if t < grow:
			var g := t / grow
			k = 1.0 - pow(1.0 - g, 3.0)
		elif t > hold_end:
			k = 1.0 - (t - hold_end) / float(item["fade"])
		node.scale = Vector3(1.0, maxf(0.04, k), 1.0)


func _spawn_moon(pos: Vector3, color: Color, radius: float) -> void:
	var mat := _fx_mat(color, 0.55)
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.58
	torus.outer_radius = radius * 0.66
	torus.rings = 32
	torus.ring_segments = 4
	_add_fx_mesh(torus, mat, Vector3(pos.x, 30.0, pos.z), 0.95, 0.5, 1.25)
	var orb_mat := _fx_mat(color, 0.55)
	var orb := SphereMesh.new()
	orb.radius = 8.0
	orb.height = 16.0
	orb.radial_segments = 8
	orb.rings = 4
	for i in range(5):
		var ang := TAU * float(i) / 5.0
		var at := pos + Vector3(cos(ang), 0, sin(ang)) * (radius * 0.50)
		at.y = 36.0 + float(i % 3) * 14.0
		_add_fx_mesh(orb, orb_mat, at, 0.95, 0.4, 1.1,
			Vector3(0, 30, 0), Vector3(0, 2, 0))


func _spawn_bubbles(pos: Vector3, color: Color, radius: float) -> void:
	var mat := _fx_mat(color, 0.50)
	var sphere: Mesh
	if fx_mesh_cache.has("fx_bubble"):
		sphere = fx_mesh_cache["fx_bubble"]
	else:
		var sm := SphereMesh.new()
		sm.radius = 10.0
		sm.height = 20.0
		sm.radial_segments = 10
		sm.rings = 5
		fx_mesh_cache["fx_bubble"] = sm
		sphere = sm
	for i in range(7):
		var ang := TAU * float(i) / 7.0
		var at := pos + Vector3(cos(ang), 0, sin(ang)) * (radius * 0.18 + float(i % 3) * 18.0)
		at.y = 16.0
		_add_fx_mesh(sphere, mat, at, 0.85, 0.5, 1.25,
			Vector3(0, 80 + float(i % 4) * 14, 0))


func _spawn_feathers(pos: Vector3, color: Color, radius: float) -> void:
	var mat := _fx_mat(color, 0.85)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(5, 2, 26)
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		var at := pos + Vector3(cos(ang), 0, sin(ang)) * (radius * 0.52)
		at.y = 36.0
		_add_fx_mesh(mesh, mat, at, 0.75, 0.5, 1.3,
			Vector3(0, 20, 0), Vector3(0, 7, 0), Vector3(0.4, ang, 0))


func _spawn_heart(pos: Vector3, color: Color) -> void:
	var mat := _fx_mat(Color(1.0, 0.55, 0.70), 0.92)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(16, 16, 5)
	for i in range(2):
		_add_fx_mesh(mesh, mat, pos + Vector3(-7.0 + 14.0 * float(i), 42.0, 0.0),
			0.85, 0.4, 1.2, Vector3(0, 45, 0), Vector3(0, 2, 0), Vector3(0, 0, PI * 0.25))
	_spawn_roar(pos, color, 90.0)


func _spawn_roar(pos: Vector3, color: Color, radius: float) -> void:
	for i in range(3):
		var torus := TorusMesh.new()
		torus.inner_radius = radius * (0.55 + 0.22 * float(i)) * 0.90
		torus.outer_radius = radius * (0.55 + 0.22 * float(i))
		torus.rings = 32
		torus.ring_segments = 4
		_add_fx_mesh(torus, _fx_mat(color, 0.55), Vector3(pos.x, 6.0, pos.z),
			0.55 + 0.15 * float(i), 0.55, 1.45)


func play_victory(base, color: Color) -> void:
	# 水晶破碎演出：大范围扩散环 + 多次爆点 + 方块碎块。
	var center := Vector3(base.pos.x, base.height * 0.45, base.pos.y)
	_spawn_ring(Vector3(base.pos.x, 6.0, base.pos.y), color, base.radius * 2.4, 1.0)
	_spawn_burst(center, Color(1, 1, 1), 0.6)
	_spawn_debris(center, color, 26)
	for i in range(6):
		var p := Vector3(base.pos.x + rng.randf_range(-90.0, 90.0),
			rng.randf_range(20.0, 110.0), base.pos.y + rng.randf_range(-90.0, 90.0))
		_spawn_burst(p, color, 0.45)


func _spawn_debris(pos: Vector3, color: Color, count: int) -> void:
	# 建筑倒塌：方块碎块四散、落地弹跳，纯表现不影响逻辑。
	var tint := Color(minf(1.0, color.r * 0.7 + 0.3), minf(1.0, color.g * 0.7 + 0.3),
		minf(1.0, color.b * 0.7 + 0.3), 0.95)
	var mat := _alpha_material(tint)
	for i in range(count):
		var node := MeshInstance3D.new()
		var cube := BoxMesh.new()
		var sz := rng.randf_range(9.0, 20.0)
		cube.size = Vector3(sz, sz, sz)
		node.mesh = cube
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = pos + Vector3(rng.randf_range(-42, 42), rng.randf_range(-24, 42), rng.randf_range(-42, 42))
		add_child(node)
		debris_items.append({
			"node": node,
			"vel": Vector3(rng.randf_range(-160, 160), rng.randf_range(150, 340), rng.randf_range(-160, 160)),
			"spin": Vector3(rng.randf_range(-7, 7), rng.randf_range(-7, 7), rng.randf_range(-7, 7)),
			"t": 0.0,
			"life": rng.randf_range(0.75, 1.25),
		})


func _step_debris(delta: float) -> void:
	for i in range(debris_items.size() - 1, -1, -1):
		var item: Dictionary = debris_items[i]
		item["t"] = float(item["t"]) + delta
		var node: MeshInstance3D = item["node"]
		if float(item["t"]) >= float(item["life"]):
			node.queue_free()
			debris_items.remove_at(i)
			continue
		var vel: Vector3 = item["vel"]
		vel.y -= 900.0 * delta
		node.position += vel * delta
		if node.position.y < 5.0:
			node.position.y = 5.0
			vel.y = absf(vel.y) * 0.32
			vel.x *= 0.68
			vel.z *= 0.68
		item["vel"] = vel
		node.rotation += (item["spin"] as Vector3) * delta


func _step_fx(delta: float) -> void:
	for i in range(fx_items.size() - 1, -1, -1):
		var item: Dictionary = fx_items[i]
		item["t"] = float(item["t"]) + delta
		var k: float = float(item["t"]) / float(item["life"])
		var node: MeshInstance3D = item["node"]
		if k >= 1.0:
			node.queue_free()
			fx_items.remove_at(i)
			continue
		var s: float = lerp(float(item["start"]), float(item["end"]), k)
		node.scale = Vector3.ONE * s
		if item.has("vel"):
			node.position += (item["vel"] as Vector3) * delta
		if item.has("spin"):
			node.rotation += (item["spin"] as Vector3) * delta
		var m := node.material_override as StandardMaterial3D
		if m != null:
			m.albedo_color.a = 1.0 - k

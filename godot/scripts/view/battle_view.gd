class_name BattleView
extends Node3D

# 方块体素表现层：读取 BattleSim 状态，不反向修改规则。
# 全部模型走像素图集 + 烘焙面光照（UNSHADED），无实时灯光/阴影。

const HERO_DESIGN_H := {
	"tiger": 88.0, "fox": 88.0, "rabbit": 88.0, "bear": 88.0, "frog": 88.0, "cat": 88.0,
}

var sim = null
var atlas
var icons = null

var hero_nodes: Dictionary = {}
var minion_nodes: Dictionary = {}
var structure_nodes: Dictionary = {}
var shot_nodes: Dictionary = {}
var shot_free: Array = []
var zone_nodes: Array = []
var fx_items: Array = []
var debris_items: Array = []
var shot_mats: Dictionary = {}
var alpha_mats: Dictionary = {}
var model_cache: Dictionary = {}
var mesh_mats: Dictionary = {}
var fade_mats: Dictionary = {}
var rng := RandomNumberGenerator.new()
var sync_us_total := 0
var sync_frames := 0

const C_BLUE := Color(0.42, 0.72, 0.95)
const C_RED := Color(0.92, 0.44, 0.38)


func attach(s) -> void:
	sim = s
	atlas = load("res://scripts/art/pixel_atlas.gd").new()
	icons = load("res://scripts/art/pixel_icons.gd").new()
	rng.seed = 7127
	_build_world()
	sim.fx.connect(_on_fx)


func _team_color(team: int) -> Color:
	return C_BLUE if team == sim.BLUE else C_RED


func _tile_material(tile: String, tint: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = atlas.tile_texture(tile)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
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


func _make_instance(mesh: ArrayMesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mesh_material(mesh)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8ec9f0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 1.0
	env.ambient_light_color = Color.WHITE
	env.fog_enabled = false
	env_node.environment = env
	add_child(env_node)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(sim.map_w + 600.0, sim.map_h + 600.0)
	ground.mesh = plane
	ground.position = Vector3(sim.map_w * 0.5, 0, sim.map_h * 0.5)
	ground.material_override = _tiled_material("grass_top",
		Vector2((sim.map_w + 600.0) / 48.0, (sim.map_h + 600.0) / 48.0))
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var lane := MeshInstance3D.new()
	var lane_plane := PlaneMesh.new()
	lane_plane.size = Vector2(sim.map_w, 190.0)
	lane.mesh = lane_plane
	lane.position = Vector3(sim.map_w * 0.5, 0.6, 800.0)
	lane.material_override = _tiled_material("path", Vector2(sim.map_w / 48.0, 190.0 / 48.0))
	lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lane)

	_build_lane_curb()
	_build_hills()
	_build_scatter()
	_build_units()


func _build_lane_curb() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(46, 22, 46)
	var mat := _tile_material("stone", Color(0.92, 0.92, 0.92))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var count := int(sim.map_w / 56.0) + 1
	mm.instance_count = count * 2
	var i := 0
	for k in range(count):
		for side in [-1, 1]:
			var pos := Vector3(28.0 + float(k) * 56.0, 0, 800.0 + float(side) * 118.0)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
			i += 1
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
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _build_scatter() -> void:
	var leaf_tints := [Color("4f8f3f"), Color("3f7a33"), Color("5d9c3f")]
	for v in range(3):
		var mesh = _model("tree_%d" % v, func(): return BlockModels.tree(atlas, v, leaf_tints[v]))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var spots: Array = []
		for k in range(6):
			var x := rng.randf_range(140.0, sim.map_w - 140.0)
			var z := rng.randf_range(120.0, 600.0) if (k % 2 == 0) else rng.randf_range(1000.0, 1480.0)
			spots.append(Vector3(x, 0, z))
		mm.instance_count = spots.size()
		for k in range(spots.size()):
			var s := rng.randf_range(0.85, 1.35)
			mm.set_instance_transform(k, Transform3D(
				Basis.IDENTITY.scaled(Vector3(s, s, s)).rotated(Vector3.UP, rng.randf_range(0.0, TAU)), spots[k]))
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = _mesh_material(mesh)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)

	for v in range(2):
		var rmesh = _model("rock_%d" % v, func(): return BlockModels.rock(atlas, v))
		var rmm := MultiMesh.new()
		rmm.transform_format = MultiMesh.TRANSFORM_3D
		rmm.mesh = rmesh
		rmm.instance_count = 5
		for k in range(5):
			var x := rng.randf_range(180.0, sim.map_w - 180.0)
			var z := rng.randf_range(200.0, 500.0) if (k % 2 == 0) else rng.randf_range(1100.0, 1420.0)
			rmm.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(x, 0, z)))
		var rnode := MultiMeshInstance3D.new()
		rnode.multimesh = rmm
		rnode.material_override = _mesh_material(rmesh)
		rnode.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rnode)

	var mush = _model("mushroom", func(): return BlockModels.mushroom(atlas))
	for k in range(4):
		var node := _make_instance(mush)
		var x := 300.0 + float(k) * 620.0
		var z := 520.0 if (k % 2 == 0) else 1080.0
		node.position = Vector3(x, 0, z)
		var s := rng.randf_range(0.7, 1.1)
		node.scale = Vector3(s, s, s)
		add_child(node)

	var sign_mesh = _model("sign", func(): return BlockModels.sign(atlas))
	for p in [Vector3(520, 0, 900), Vector3(2460, 0, 700)]:
		var node := _make_instance(sign_mesh)
		node.position = p
		add_child(node)


func _build_units() -> void:
	for u in sim.units:
		if u.kind == sim.HERO:
			_add_hero(u)
		elif u.kind == sim.MINION:
			_add_minion(u)
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
		u.hero_id, atlas, u.fur, u.def.get("cream_c", u.fur), u.def.get("dark_c", u.fur), u.accent))
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
	hero_nodes[u.uid] = {"root": root, "body": body, "limbs": limbs, "scale": s}


func _add_minion(u) -> void:
	var root := Node3D.new()
	root.name = "Minion_%d" % u.uid
	add_child(root)
	var mesh = _model("minion_%d" % u.team, func(): return BlockModels.minion(
		atlas, _team_color(u.team), u.radius, u.team))
	var body := _make_instance(mesh)
	root.add_child(body)
	minion_nodes[u.uid] = {"root": root, "body": body}


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
			_sync_hero(u)
		elif u.kind == sim.MINION:
			_sync_minion(u)
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
				# 玩家走到建筑后方时把建筑淡出，避免挡住操作角色。
				var fade_target := 0.0
				if alive and sim.player != null and sim.player.is_alive():
					var pp: Vector2 = sim.render_pos(sim.player)
					if pp.y < u.pos.y - 8.0 and absf(pp.x - u.pos.x) < u.radius * 1.7 \
							and (u.pos.y - pp.y) < 240.0:
						fade_target = 0.55
				var fade: float = item.get("fade", 0.0)
				fade = lerpf(fade, fade_target, 1.0 - exp(-10.0 * delta))
				item["fade"] = fade
				if item["body"] != null:
					if fade > 0.02:
						item["body"].material_override = item["body_fade"]
						item["body_fade"].set_shader_parameter("fade", 1.0 - fade)
					else:
						item["body"].material_override = item["body_mat"]
				if item["crystal"] != null:
					if fade > 0.02:
						item["crystal"].material_override = item["crystal_fade"]
						item["crystal_fade"].set_shader_parameter("fade", 1.0 - fade)
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


func _sync_hero(u) -> void:
	var item = hero_nodes.get(u.uid)
	if item == null:
		_add_hero(u)
		item = hero_nodes[u.uid]
	var root: Node3D = item["root"]
	var s: float = item["scale"]
	var rp: Vector2 = sim.render_pos(u)
	root.position = Vector3(rp.x, 0, rp.y)
	# 侧视相机下给 20° 偏航，露出动物脸和涂装。
	var yaw := PI * 0.5 - 0.34
	root.rotation.y = yaw if u.facing >= 0.0 else -yaw
	var step := 1.0 / 30.0
	var wt: float = u.walk_t
	if u.moving:
		wt -= (1.0 - sim.interp_alpha) * step
	var bob := absf(sin(wt * 9.0)) * (4.0 if u.moving else 0.0)
	root.position.y = bob
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
		var ck: float = 1.0 - u.cast_anim / 0.5
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


func _sync_minion(u) -> void:
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
	var yaw := PI * 0.5 - 0.34
	root.rotation.y = yaw if u.facing >= 0.0 else -yaw
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
		node.material_override = _shot_material(Color(p.color.r, p.color.g, p.color.b, 0.95))
		var sz: float = maxf(0.7, p.size / 7.0)
		node.scale = Vector3(sz, sz, sz)
		node.rotation.y += 0.25

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
	var cube := BoxMesh.new()
	cube.size = Vector3(13, 13, 13)
	node.mesh = cube
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _sync_zones() -> void:
	while zone_nodes.size() < sim.zones.size():
		var node := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(2, 0.8, 2)
		node.mesh = cube
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


func _spawn_ring(pos: Vector3, color: Color, radius: float, life: float) -> void:
	var node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.90
	torus.outer_radius = radius
	torus.rings = 12
	torus.ring_segments = 4
	node.mesh = torus
	node.position = Vector3(pos.x, 1.6, pos.z)
	node.material_override = _alpha_material(Color(color.r, color.g, color.b, 0.85))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	fx_items.append({"node": node, "t": 0.0, "life": life, "start": 0.75, "end": 1.15})


func _spawn_burst(pos: Vector3, color: Color, life: float) -> void:
	var node := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(20, 20, 20)
	node.mesh = cube
	node.position = Vector3(pos.x, maxf(pos.y, 10.0), pos.z)
	node.material_override = _alpha_material(Color(color.r, color.g, color.b, 0.92))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	fx_items.append({"node": node, "t": 0.0, "life": life, "start": 0.5, "end": 1.7})


func _spawn_slash(pos: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(96, 8, 18)
	node.mesh = box
	node.position = Vector3(pos.x, 34.0, pos.z)
	node.rotation_degrees = Vector3(0, 0, 22)
	node.material_override = _alpha_material(Color(color.r, color.g, color.b, 0.9))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	fx_items.append({"node": node, "t": 0.0, "life": 0.13, "start": 0.6, "end": 1.1})


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
		var m := node.material_override as StandardMaterial3D
		if m != null:
			m.albedo_color.a = 1.0 - k

class_name BattleView
extends Node3D

# 表现层：只读取 BattleSim 的状态，不反向修改规则。
# 垂直切片用基础几何体先跑通手感；P3 再把 Polyfork 模型接进来。

var sim = null
var font: Font = null
var hero_nodes: Dictionary = {}
var minion_nodes: Dictionary = {}
var structure_nodes: Dictionary = {}
var shot_nodes: Dictionary = {}
var shot_free: Array = []
var zone_nodes: Array = []
var fx_items: Array = []
var rng := RandomNumberGenerator.new()
var mat_cache: Dictionary = {}
var sync_us_total := 0
var sync_frames := 0

const C_BLUE := Color(0.55, 0.90, 1.0)
const C_RED := Color(1.0, 0.62, 0.55)


func attach(s) -> void:
	sim = s
	font = load("res://assets/fonts/TapArenaCJK.ttf")
	rng.seed = 7127
	_build_world()
	sim.fx.connect(_on_fx)


func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.78, 0.86, 0.80)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.68, 0.80)
	env.ambient_light_energy = 0.9
	env.fog_enabled = false
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.80)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-52, -32, 0)
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(sim.map_w, sim.map_h)
	ground.mesh = plane
	ground.position = Vector3(sim.map_w * 0.5, 0, sim.map_h * 0.5)
	ground.material_override = _mat_cached(Color(0.42, 0.62, 0.36))
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var lane := MeshInstance3D.new()
	var lane_mesh := BoxMesh.new()
	lane_mesh.size = Vector3(sim.map_w, 0.18, 190.0)
	lane.mesh = lane_mesh
	lane.position = Vector3(sim.map_w * 0.5, 0.06, 800.0)
	lane.material_override = _mat_cached(Color(0.62, 0.55, 0.38))
	lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lane)

	_build_trees()
	_build_units()


func _build_trees() -> void:
	var tree_mat := _mat_cached(Color(0.24, 0.46, 0.30))
	for i in range(18):
		var x := rng.randf_range(120.0, sim.map_w - 120.0)
		var z := rng.randf_range(120.0, 620.0)
		var tree := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = rng.randf_range(18.0, 30.0)
		cone.bottom_radius = rng.randf_range(42.0, 72.0)
		cone.height = rng.randf_range(110.0, 230.0)
		cone.radial_segments = 7
		tree.mesh = cone
		tree.position = Vector3(x, cone.height * 0.5, z)
		tree.rotation.y = rng.randf_range(0.0, TAU)
		tree.material_override = tree_mat
		tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tree)


func _build_units() -> void:
	for u in sim.units:
		if u.kind == sim.HERO:
			_add_hero(u)
		elif u.kind == sim.MINION:
			_add_minion(u)
		elif u.kind == sim.TOWER or u.kind == sim.BASE:
			_add_structure(u)


func _mat(c: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic = 0.0
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m


func _mat_cached(c: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f" % [c.to_html(), emission]
	if mat_cache.has(key):
		return mat_cache[key]
	var m := _mat(c, emission)
	mat_cache[key] = m
	return m


func _mat_alpha(c: Color) -> StandardMaterial3D:
	var m := _mat(c)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _team_color(team: int) -> Color:
	return C_BLUE if team == sim.BLUE else C_RED


func _add_hero(u) -> void:
	var root := Node3D.new()
	root.name = "Hero_%d" % u.uid
	add_child(root)

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = minf(u.radius, u.height * 0.5 - 3.0)
	capsule.height = u.height
	capsule.radial_segments = 10
	capsule.rings = 4
	body.mesh = capsule
	body.position.y = u.height * 0.5
	body.material_override = _mat_cached(u.fur)
	root.add_child(body)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = u.radius * 0.72
	sphere.height = u.radius * 1.44
	head.mesh = sphere
	head.position = Vector3(0, u.height * 0.92, 0)
	head.material_override = _mat_cached(u.def.get("cream_c", u.fur))
	root.add_child(head)

	hero_nodes[u.uid] = {"root": root, "body": body, "head": head}


func _add_minion(u) -> void:
	var root := Node3D.new()
	root.name = "Minion_%d" % u.uid
	add_child(root)
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = u.radius
	sphere.height = u.radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	body.mesh = sphere
	body.position.y = u.radius
	body.material_override = _mat_cached(_team_color(u.team), 0.15)
	root.add_child(body)
	minion_nodes[u.uid] = {"root": root, "body": body}


func _add_structure(u) -> void:
	var root := Node3D.new()
	root.name = "Structure_%d" % u.uid
	add_child(root)
	var team_c := _team_color(u.team)

	if u.kind == sim.TOWER:
		var base := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = u.radius * 0.78
		cyl.bottom_radius = u.radius
		cyl.height = 72.0
		cyl.radial_segments = 8
		base.mesh = cyl
		base.position.y = 36.0
		base.material_override = _mat_cached(Color(0.55, 0.42, 0.30))
		root.add_child(base)
		var cap := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = u.radius * 0.35
		cone.bottom_radius = u.radius * 0.82
		cone.height = 92.0
		cone.radial_segments = 8
		cap.mesh = cone
		cap.position.y = 118.0
		cap.material_override = _mat_cached(team_c, 0.22)
		root.add_child(cap)
	else:
		var pedestal := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = u.radius * 0.9
		cyl.bottom_radius = u.radius * 1.15
		cyl.height = 28.0
		cyl.radial_segments = 10
		pedestal.mesh = cyl
		pedestal.position.y = 14.0
		pedestal.material_override = _mat_cached(Color(0.46, 0.44, 0.40))
		root.add_child(pedestal)
		var crystal := MeshInstance3D.new()
		var hex := CylinderMesh.new()
		hex.top_radius = u.radius * 0.38
		hex.bottom_radius = u.radius * 0.72
		hex.height = u.height
		hex.radial_segments = 6
		crystal.mesh = hex
		crystal.position.y = 28.0 + u.height * 0.5
		crystal.material_override = _mat_cached(team_c, 1.1)
		root.add_child(crystal)

	structure_nodes[u.uid] = root


func _process(delta: float) -> void:
	if sim == null:
		return
	var t0 := Time.get_ticks_usec()
	_sync_units()
	_sync_shots()
	_sync_zones()
	_step_fx(delta)
	sync_us_total += Time.get_ticks_usec() - t0
	sync_frames += 1
	if sync_frames >= 300:
		print("[VIEW] sync_ms=%.2f" % (sync_us_total / 1000.0 / float(sync_frames)))
		sync_us_total = 0
		sync_frames = 0


func _sync_units() -> void:
	var live: Dictionary = {}
	for u in sim.units:
		live[u.uid] = true
		if u.kind == sim.HERO:
			_sync_hero(u)
		elif u.kind == sim.MINION:
			_sync_minion(u)
		elif u.kind == sim.TOWER or u.kind == sim.BASE:
			var node = structure_nodes.get(u.uid)
			if node != null:
				node.visible = u.is_alive()

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
			var item: Dictionary = minion_nodes[uid]
			item["root"].queue_free()
			dead_minions.append(uid)
	for uid in dead_minions:
		minion_nodes.erase(uid)


func _sync_hero(u) -> void:
	var item = hero_nodes.get(u.uid)
	if item == null:
		_add_hero(u)
		item = hero_nodes[u.uid]
	var root: Node3D = item["root"]
	root.position = Vector3(u.pos.x, 0, u.pos.y)
	root.rotation.y = PI * 0.5 if u.facing >= 0.0 else -PI * 0.5
	var bob := absf(sin(u.walk_t * 8.0)) * (3.0 if u.moving else 0.0)
	root.position.y = bob
	var squash := 1.0
	if u.atk_anim > 0.0:
		squash = 1.0 + sin((1.0 - u.atk_anim / 0.34) * PI) * 0.08
	if u.hurt_anim > 0.0:
		squash = 0.92
	root.scale = Vector3(1.0 / squash, squash, 1.0 / squash)


func _sync_minion(u) -> void:
	var item = minion_nodes.get(u.uid)
	if item == null:
		_add_minion(u)
		item = minion_nodes[u.uid]
	var root: Node3D = item["root"]
	root.visible = true
	root.position = Vector3(u.pos.x, absf(sin(u.walk_t * 8.0)) * (4.5 if u.moving else 0.0), u.pos.y)
	root.rotation.y = PI * 0.5 if u.facing >= 0.0 else -PI * 0.5
	var squash := 1.0
	if u.atk_anim > 0.0:
		squash = 1.0 + sin((1.0 - u.atk_anim / 0.22) * PI) * 0.14
	root.scale = Vector3(1.0 / squash, squash, 1.0 / squash)


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
		node.position = Vector3(p.pos.x, 32.0, p.pos.y)
		node.material_override = _mat_cached(p.color, 1.8)
		node.scale = Vector3.ONE * (p.size / 6.0 * (1.2 if p.bubble else 1.0))

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
	var sphere := SphereMesh.new()
	sphere.radius = 8.0
	sphere.height = 16.0
	sphere.radial_segments = 8
	sphere.rings = 4
	node.mesh = sphere
	node.material_override = _mat_cached(Color.WHITE, 1.8)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _sync_zones() -> void:
	while zone_nodes.size() < sim.zones.size():
		var node := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.0
		cyl.bottom_radius = 1.0
		cyl.height = 0.2
		cyl.radial_segments = 24
		node.mesh = cyl
		node.material_override = _mat_alpha(Color(1, 1, 1, 0.35))
		add_child(node)
		zone_nodes.append(node)
	for i in range(zone_nodes.size()):
		var node: MeshInstance3D = zone_nodes[i]
		if i >= sim.zones.size():
			node.visible = false
			continue
		var z = sim.zones[i]
		node.visible = true
		node.position = Vector3(z.pos.x, 0.3, z.pos.y)
		node.scale = Vector3(z.radius, 1.0, z.radius)
		var m := node.material_override as StandardMaterial3D
		m.albedo_color = Color(z.color.r, z.color.g, z.color.b, 0.32)


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


func _spawn_ring(pos: Vector3, color: Color, radius: float, life: float) -> void:
	var node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.92
	torus.outer_radius = radius
	torus.rings = 28
	torus.ring_segments = 6
	node.mesh = torus
	node.position = Vector3(pos.x, 1.2, pos.z)
	node.material_override = _mat_alpha(Color(color.r, color.g, color.b, 0.8))
	add_child(node)
	fx_items.append({"node": node, "t": 0.0, "life": life, "start": 0.75, "end": 1.15})


func _spawn_burst(pos: Vector3, color: Color, life: float) -> void:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 14.0
	sphere.height = 28.0
	sphere.radial_segments = 8
	sphere.rings = 4
	node.mesh = sphere
	node.position = Vector3(pos.x, maxf(pos.y, 10.0), pos.z)
	node.material_override = _mat_alpha(Color(color.r, color.g, color.b, 0.9))
	add_child(node)
	fx_items.append({"node": node, "t": 0.0, "life": life, "start": 0.5, "end": 1.7})


func _spawn_slash(pos: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(90.0, 5.0, 16.0)
	node.mesh = box
	node.position = Vector3(pos.x, 34.0, pos.z)
	node.rotation_degrees = Vector3(0, 0, 22)
	node.material_override = _mat_alpha(Color(color.r, color.g, color.b, 0.85))
	add_child(node)
	fx_items.append({"node": node, "t": 0.0, "life": 0.13, "start": 0.6, "end": 1.1})


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

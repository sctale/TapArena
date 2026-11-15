class_name BattleSim
extends RefCounted

# 纯逻辑战斗模拟：不引用任何节点、摄像机、音频或 UI。
# 表现层通过信号订阅；这样同一套规则可以在 Godot 里玩，也可以 --headless 跑回归。

signal banner(text: String, duration: float)
signal float_text(pos: Vector3, text: String, color: Color)
signal fx(kind: String, pos: Vector3, color: Color, radius: float)
signal sfx(key: String)
signal hitstop(seconds: float)
signal level_up(unit)
signal match_ended(winner: int)

const BLUE := 0
const RED := 1
const HERO := 0
const MINION := 1
const TOWER := 2
const BASE := 3
const BOSS := 4

class Unit:
	var uid: int = 0
	var kind: int = 0
	var team: int = 0
	var def: Dictionary = {}
	var hero_id: String = ""
	var display_name: String = ""
	var pos := Vector2.ZERO
	var prev_pos := Vector2.ZERO
	var facing: float = 1.0
	var move_dir := Vector2.ZERO

	var hp: float = 0.0
	var max_hp: float = 0.0
	var dmg: float = 0.0
	var attack_range: float = 0.0
	var atk_interval: float = 0.7
	var atk_timer: float = 0.0
	var move_speed: float = 0.0
	var radius: float = 34.0
	var height: float = 74.0
	var level: int = 1
	var xp: float = 0.0
	var level2_time: float = -1.0
	var kills: int = 0
	var deaths: int = 0
	var damage_dealt: float = 0.0

	var stun_t: float = 0.0
	var slow_t: float = 0.0
	var invuln_t: float = 0.0
	var dash_t: float = 0.0
	var hurt_t: float = 0.0
	var shield: float = 0.0
	var shield_t: float = 0.0
	var thorn_t: float = 0.0
	var calm_t: float = 0.0

	var atk_anim: float = 0.0
	var cast_anim: float = 0.0
	var hurt_anim: float = 0.0
	var die_t: float = 0.0
	var respawn_t: float = 0.0
	var walk_t: float = 0.0
	var moving: bool = false
	var is_player: bool = false

	var ai_think: float = 0.0
	var ai_target = null
	var lane_index: int = 0

	var skills: Array = []
	var cds: Array = [0.0, 0.0, 0.0]

	var fur := Color.WHITE
	var accent := Color.WHITE

	func is_alive() -> bool:
		return hp > 0.0

class Projectile:
	var pos := Vector2.ZERO
	var prev_pos := Vector2.ZERO
	var dir := Vector2.RIGHT
	var team: int = 0
	var src = null
	var speed: float = 620.0
	var dmg: float = 0.0
	var life: float = 1.6
	var size: float = 6.0
	var slow: float = 0.0
	var splash: float = 0.0
	var splash_radius: float = 0.0
	var pierce: int = 0
	var alive: bool = true
	var color := Color.WHITE
	var bubble: bool = false
	var view_id: int = 0
	var homing: bool = false
	var target = null
	var hit: Dictionary = {}
	var style: String = "cube"

class Zone:
	var pos := Vector2.ZERO
	var radius: float = 90.0
	var life: float = 2.6
	var t: float = 0.0
	var slow: float = 0.9
	var team: int = 0
	var color := Color.WHITE

class Potion:
	var team: int = 0
	var pos := Vector2.ZERO
	var radius: float = 30.0
	var active := true
	var respawn_t := 0.0
	var view_id: int = 0

var rules: Dictionary = {}
var heroes_data: Array = []
var defs_by_id: Dictionary = {}

var units: Array = []
var heroes: Array = []
var minions: Array = []
var shots: Array = []
var zones: Array = []
var potions: Array = []
var towers_blue: Array = []
var towers_red: Array = []
var base_blue = null
var base_red = null
var player = null
var boss = null
var boss_spawned := false
var boss_team := -1
var boss_respawn := 25.0

var winner: int = -1
var end_reason: String = ""
var warned_45 := false
var warned_15 := false
var final_push := false
var clock: float = 0.0
var wave_t: float = 0.0
var over: bool = false
var started: bool = false
var sudden_death: bool = false
var score_blue: int = 0
var score_red: int = 0

var player_move := Vector2.ZERO
var skill_pressed: Array = [false, false, false]
# 渲染插值：表现层在 prev_pos → pos 之间按 0..1 取值，消除 30Hz 模拟的台阶感。
var interp_alpha: float = 1.0

var lane: Array = []
var rng := RandomNumberGenerator.new()

var map_w: float = 3000.0
var map_h: float = 1600.0
var sudden_death_time: float = 180.0
var match_cap: float = 285.0
var respawn_time: float = 5.5
var base_heal_per_sec: float = 0.15
var wave_interval: float = 18.0
var xp_to_level2: float = 180.0
var xp_passive_per_sec: float = 1.0
var xp_hero_kill: float = 120.0
var xp_hero_assist: float = 45.0
var xp_tower: float = 70.0
var xp_minion: float = 10.0
var xp_minion_assist: float = 5.0

var base_cfg: Dictionary = {}
var tower_cfg: Dictionary = {}
var minion_cfg: Dictionary = {}
var comeback_cfg: Dictionary = {}
var potion_cfg: Dictionary = {}
var boss_cfg: Dictionary = {}

var ai_think_base: float = 0.22
var ai_skill_mul: float = 1.0
var enemy_dmg_mul: float = 1.0
var hitstop_threshold: float = 45.0
var hitstop_duration: float = 0.045

var _uid: int = 0
var _shot_view: int = 0
var _potion_view: int = 0
var pending: Array = []


static func color_of(hex: String, fallback := Color.WHITE) -> Color:
	return Color.from_string(hex.trim_prefix("#"), fallback)


func setup(player_hero: String, difficulty: int, seed_value: int) -> void:
	load_data()
	rng.seed = seed_value

	units.clear()
	heroes.clear()
	minions.clear()
	shots.clear()
	zones.clear()
	potions.clear()
	towers_blue.clear()
	towers_red.clear()
	pending.clear()
	base_blue = null
	base_red = null
	player = null
	boss = null
	boss_spawned = false
	boss_team = -1
	boss_respawn = 25.0
	_uid = 0
	_shot_view = 0
	_potion_view = 0
	clock = 0.0
	wave_t = 0.0
	over = false
	started = false
	sudden_death = false
	winner = -1
	end_reason = ""
	warned_45 = false
	warned_15 = false
	final_push = false
	score_blue = 0
	score_red = 0
	player_move = Vector2.ZERO
	skill_pressed = [false, false, false]

	map_w = float(rules.get("map_w", 3000))
	map_h = float(rules.get("map_h", 1600))
	sudden_death_time = float(rules.get("sudden_death_time", 180))
	match_cap = float(rules.get("match_cap", 285))
	respawn_time = float(rules.get("respawn_time", 5.5))
	base_heal_per_sec = float(rules.get("base_heal_per_sec", 0.15))
	wave_interval = float(rules.get("wave_interval", 18))
	xp_to_level2 = float(rules.get("xp_to_level2", 180))
	xp_passive_per_sec = float(rules.get("xp_passive_per_sec", 1))
	xp_hero_kill = float(rules.get("xp_hero_kill", 120))
	xp_hero_assist = float(rules.get("xp_hero_assist", 45))
	xp_tower = float(rules.get("xp_tower", 70))
	xp_minion = float(rules.get("xp_minion", 10))
	xp_minion_assist = float(rules.get("xp_minion_assist", 5))
	base_cfg = rules.get("base", {})
	tower_cfg = rules.get("tower", {})
	minion_cfg = rules.get("minion", {})
	comeback_cfg = rules.get("comeback", {})
	potion_cfg = rules.get("potion", {})
	boss_cfg = rules.get("boss", {})
	boss_respawn = float(boss_cfg.get("respawn", 25.0))
	var hs: Dictionary = rules.get("hitstop", {})
	hitstop_threshold = float(hs.get("threshold", 45))
	hitstop_duration = float(hs.get("duration", 0.045))

	var diff_name := "easy" if difficulty == 0 else "challenge"
	var dcfg: Dictionary = rules.get("difficulty", {}).get(diff_name, {})
	ai_think_base = float(dcfg.get("ai_think", 0.22))
	ai_skill_mul = float(dcfg.get("ai_skill_mul", 1.0))
	enemy_dmg_mul = float(dcfg.get("enemy_dmg_mul", 1.0))

	lane.clear()
	for p in rules.get("lane", []):
		lane.append(Vector2(float(p[0]), float(p[1])))

	var others: Array = []
	for d in heroes_data:
		if d["id"] != player_hero:
			others.append(d["id"])
	for i in range(others.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = others[i]
		others[i] = others[j]
		others[j] = tmp

	base_blue = make_base(BLUE, Vector2(230, 800))
	base_red = make_base(RED, Vector2(2770, 800))
	# 外塔 = 更靠近敌方的一侧，必须先拆；内塔在水晶旁，受外塔保护。
	towers_blue.append(make_tower(BLUE, 0, Vector2(1180, 800)))
	towers_blue.append(make_tower(BLUE, 1, Vector2(760, 800)))
	towers_red.append(make_tower(RED, 0, Vector2(1900, 800)))
	towers_red.append(make_tower(RED, 1, Vector2(2320, 800)))
	# 双方一塔后方各放一瓶回血药剂，踩到即喝，30 秒后重新长出来。
	make_potion(BLUE, Vector2(1050, 800))
	make_potion(RED, Vector2(2030, 800))

	var allies: Array = []
	var player_front := player_hero == "tiger" or player_hero == "bear"
	if not player_front:
		allies.append(take_preferred(others, ["bear", "tiger"]))
		allies.append(take_preferred(others, ["rabbit", "frog", "cat", "fox"]))
	else:
		allies.append(take_preferred(others, ["cat", "fox", "rabbit", "frog"]))
		allies.append(take_preferred(others, ["rabbit", "frog", "fox", "cat"]))

	var blue_ids: Array = [player_hero, allies[0], allies[1]]
	var red_ids: Array = others

	for i in range(3):
		var h = make_hero(blue_ids[i], BLUE, i)
		if i == 0:
			h.is_player = true
			player = h
	for i in range(3):
		make_hero(red_ids[i], RED, i)

	started = true
	wave_t = 3.0
	banner.emit("往右走 → 先拆两座蘑菇塔，再点亮敌方水晶！", 3.6)
	print("[SIM] seed=%d player=%s difficulty=%s" % [seed_value, player_hero, diff_name])


func load_data() -> void:
	heroes_data.clear()
	defs_by_id.clear()
	var parsed_heroes = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes.json"))
	if parsed_heroes == null:
		push_error("heroes.json 解析失败")
		return
	heroes_data = parsed_heroes.get("heroes", [])
	for d in heroes_data:
		d["fur_c"] = color_of(str(d.get("fur", "#FFFFFF")))
		d["dark_c"] = color_of(str(d.get("dark", "#000000")))
		d["cream_c"] = color_of(str(d.get("cream", "#FFFFFF")))
		d["accent_c"] = color_of(str(d.get("accent", "#FFFFFF")))
		for s in d.get("skills", []):
			s["color_c"] = color_of(str(s.get("color", "#FFFFFF")))
		defs_by_id[d["id"]] = d

	var parsed_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/rules.json"))
	if parsed_rules == null:
		push_error("rules.json 解析失败")
		return
	rules = parsed_rules


func take_preferred(pool: Array, prefs: Array) -> String:
	for p in prefs:
		if pool.has(p):
			pool.erase(p)
			return p
	var fallback: String = pool[0]
	pool.remove_at(0)
	return fallback


func new_unit(kind: int, team: int, display_name: String, pos: Vector2):
	var u = Unit.new()
	u.uid = _uid
	_uid += 1
	u.kind = kind
	u.team = team
	u.display_name = display_name
	u.pos = pos
	u.prev_pos = pos
	u.cds = [0.0, 0.0, 0.0]
	units.append(u)
	return u


func make_base(team: int, pos: Vector2):
	var u = new_unit(BASE, team, "清清水晶" if team == BLUE else "红红水晶", pos)
	u.hp = float(base_cfg.get("hp", 3000))
	u.max_hp = u.hp
	u.radius = float(base_cfg.get("radius", 90))
	u.height = float(base_cfg.get("height", 150))
	u.attack_range = float(base_cfg.get("range", 400))
	u.dmg = float(base_cfg.get("dmg", 120))
	u.atk_interval = float(base_cfg.get("atk_interval", 1.0))
	u.atk_timer = 1.0
	u.level = 0
	return u


func make_tower(team: int, tier: int, pos: Vector2):
	var u = new_unit(TOWER, team, "外塔" if tier == 0 else "内塔", pos)
	u.hp = float(tower_cfg.get("hp", 4200))
	u.max_hp = u.hp
	u.radius = float(tower_cfg.get("radius", 58))
	u.height = float(tower_cfg.get("height", 140))
	u.attack_range = float(tower_cfg.get("range", 350))
	u.dmg = float(tower_cfg.get("dmg", 100))
	u.atk_interval = float(tower_cfg.get("atk_interval", 1.0))
	u.atk_timer = rng.randf_range(0.0, 1.0)
	u.level = tier
	return u


func make_potion(team: int, pos: Vector2):
	var p = Potion.new()
	p.team = team
	p.pos = pos
	p.radius = float(potion_cfg.get("radius", 30))
	p.view_id = _potion_view
	_potion_view += 1
	potions.append(p)
	return p


func step_potions(dt: float) -> void:
	# 回血药剂：一塔被拆后不再刷新；满血英雄路过不会拿走。
	var heal_pct := float(potion_cfg.get("heal_pct", 0.35))
	var respawn := float(potion_cfg.get("respawn", 30.0))
	for p in potions:
		var guard = towers_blue[0] if p.team == BLUE else towers_red[0]
		if guard == null or not guard.is_alive():
			p.active = false
			p.respawn_t = 0.0
			continue
		if not p.active:
			p.respawn_t = maxf(0.0, p.respawn_t - dt)
			if p.respawn_t <= 0.0:
				p.active = true
				fx.emit("potion_spawn", Vector3(p.pos.x, 8.0, p.pos.y),
					Color(0.55, 1.0, 0.65), p.radius)
			continue
		for h in heroes:
			if not h.is_alive():
				continue
			if h.hp >= h.max_hp - 0.5:
				continue
			if h.pos.distance_to(p.pos) > p.radius + h.radius:
				continue
			p.active = false
			p.respawn_t = respawn
			var before: float = h.hp
			h.hp = minf(h.max_hp, h.hp + h.max_hp * heal_pct)
			var gained: float = h.hp - before
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y),
				"+" + str(roundi(gained)), Color(0.55, 1.0, 0.65))
			fx.emit("potion_pick", Vector3(p.pos.x, 12.0, p.pos.y),
				Color(0.55, 1.0, 0.65), p.radius)
			sfx.emit("pickup")
			break


func leading_team() -> int:
	var b: float = base_blue.hp / base_blue.max_hp
	var r: float = base_red.hp / base_red.max_hp
	if absf(b - r) >= 0.01:
		return BLUE if b > r else RED
	var bt := 0.0
	for t in towers_blue:
		bt += maxf(t.hp, 0.0) / t.max_hp
	var rt := 0.0
	for t in towers_red:
		rt += maxf(t.hp, 0.0) / t.max_hp
	if absf(bt - rt) >= 0.01:
		return BLUE if bt > rt else RED
	if score_blue != score_red:
		return BLUE if score_blue > score_red else RED
	return BLUE


func spawn_boss(team: int) -> void:
	var offset := Vector2(190.0 if team == BLUE else -190.0, 0.0)
	var u = new_unit(BOSS, team, "峡谷巨兽", base_pos(team) + offset)
	u.hp = float(boss_cfg.get("hp", 3200))
	u.max_hp = u.hp
	u.dmg = float(boss_cfg.get("dmg", 130))
	u.attack_range = float(boss_cfg.get("range", 160))
	u.atk_interval = float(boss_cfg.get("atk_interval", 0.85))
	u.move_speed = float(boss_cfg.get("move_speed", 170))
	u.radius = float(boss_cfg.get("radius", 58))
	u.height = float(boss_cfg.get("height", 132))
	u.atk_timer = 0.5
	u.lane_index = 0 if team == BLUE else lane.size() - 1
	boss = u
	boss_team = team
	banner.emit("终极对决！%s峡谷巨兽加入战场" % ("蓝方" if team == BLUE else "红方"), 4.2)
	sfx.emit("ult")
	fx.emit("cast_quake", Vector3(u.pos.x, 20.0, u.pos.y), _team_color(team), 200.0)


func respawn_boss(u) -> void:
	var home = base_blue if u.team == BLUE else base_red
	if home == null or not home.is_alive():
		return
	u.hp = u.max_hp
	u.pos = home.pos + Vector2(190.0 if u.team == BLUE else -190.0, 0.0)
	u.prev_pos = u.pos
	u.invuln_t = 1.0
	u.stun_t = 0.0
	u.slow_t = 0.0
	u.shield = 0.0
	u.atk_timer = 0.4
	banner.emit("峡谷巨兽再次出发！", 2.6)
	fx.emit("cast_quake", Vector3(u.pos.x, 20.0, u.pos.y), _team_color(u.team), 180.0)


func step_boss(u, dt: float) -> void:
	if u.stun_t > 0.0:
		return
	var front = front_structure(u.team)
	var target = nearest_enemy(u, u.attack_range + 90.0)
	if target != null and u.pos.distance_to(target.pos) <= u.attack_range + target.radius:
		u.moving = false
		u.facing = 1.0 if target.pos.x >= u.pos.x else -1.0
		if u.atk_timer <= 0.0:
			u.atk_timer = u.atk_interval
			u.atk_anim = 0.32
			var mul := float(boss_cfg.get("structure_damage_mul", 1.6)) \
				if (target.kind == TOWER or target.kind == BASE) else 1.0
			hit_with_fx(target, u.dmg * mul, u, 0.2)
		return
	if front == null:
		u.moving = false
		return
	var to: Vector2 = front.pos - u.pos
	if to.length() <= u.attack_range * 0.8:
		u.moving = false
		u.facing = 1.0 if front.pos.x >= u.pos.x else -1.0
		if u.atk_timer <= 0.0:
			u.atk_timer = u.atk_interval
			u.atk_anim = 0.32
			var mul := float(boss_cfg.get("structure_damage_mul", 1.6)) \
				if (front.kind == TOWER or front.kind == BASE) else 1.0
			hit_with_fx(front, u.dmg * mul, u, 0.2)
		return
	move_ai(u, to, dt, 0.92)


func make_hero(id: String, team: int, slot: int):
	var d: Dictionary = defs_by_id.get(id, heroes_data[0])
	var offset := Vector2(150.0 if team == BLUE else -150.0, float(slot - 1) * 70.0)
	var u = new_unit(HERO, team, str(d.get("name", id)), base_pos(team) + offset)
	u.def = d
	u.hero_id = id
	u.skills = d.get("skills", [])
	u.fur = d.get("fur_c", Color.WHITE)
	u.accent = d.get("accent_c", Color.WHITE)
	u.max_hp = float(d.get("hp", 900))
	u.hp = u.max_hp
	u.dmg = float(d.get("dmg", 45))
	u.attack_range = float(d.get("range", 120))
	u.atk_interval = float(d.get("atk_interval", 0.7))
	u.move_speed = float(d.get("move_speed", 260))
	u.radius = float(d.get("radius", 34))
	u.height = float(d.get("height", 74))
	u.cds = [0.0, 0.0, 0.0]
	u.atk_timer = 0.2
	u.lane_index = 0 if team == BLUE else lane.size() - 1
	heroes.append(u)
	return u


func base_pos(team: int) -> Vector2:
	return base_blue.pos if team == BLUE else base_red.pos


func render_pos(u) -> Vector2:
	return u.prev_pos.lerp(u.pos, clampf(interp_alpha, 0.0, 1.0))


func set_skill(i: int) -> void:
	if i >= 0 and i < 3:
		skill_pressed[i] = true


func step(dt: float) -> void:
	if not started or over:
		return
	clock += dt

	if not sudden_death and clock >= sudden_death_time:
		sudden_death = true
		# 「终极对决」与巨兽出场同一帧发生，播报合并到 spawn_boss 里只出一条，
		# 否则两条长提示会互相覆盖，看起来像文字叠在一起。
		sfx.emit("ult")
	if not boss_spawned and clock >= sudden_death_time:
		boss_spawned = true
		spawn_boss(leading_team())
	if not warned_45 and clock >= 240.0:
		warned_45 = true
		final_push = true
		banner.emit("最后 45 秒！防御塔停火，兵线加速", 3.2)
	if not warned_15 and clock >= 270.0:
		warned_15 = true
		banner.emit("最后 15 秒！", 2.4)

	# 最后 45 秒兵线加速，让「终极对决」真的能打出结果，而不是干等时间到。
	var wave_gap := wave_interval
	if clock >= 240.0:
		wave_gap = maxf(8.0, wave_interval * 0.5)
	wave_t -= dt
	if wave_t <= 0.0:
		wave_t = wave_gap
		spawn_wave(BLUE)
		spawn_wave(RED)

	for i in range(units.size()):
		step_unit(units[i], dt)
	separate_units()
	for h in heroes:
		if h.is_alive():
			add_xp(h, xp_passive_per_sec * dt)

	step_pending(dt)
	step_potions(dt)

	if not over and clock >= match_cap:
		var b: float = base_blue.hp / base_blue.max_hp
		var r: float = base_red.hp / base_red.max_hp
		if absf(b - r) < 0.01:
			end_match(BLUE if score_blue >= score_red else RED, "时间到 · 积分领先")
		else:
			end_match(BLUE if b > r else RED, "时间到 · 水晶血量领先")
		banner.emit("时间到！按水晶血量判定", 4.0)
		return

	step_projectiles(dt)
	step_zones(dt)
	cleanup_dead()

	if base_blue.hp <= 0.0 and not over:
		end_match(RED)
	elif base_red.hp <= 0.0 and not over:
		end_match(BLUE)


func spawn_wave(team: int) -> void:
	var origin := base_pos(team)
	var count := int(minion_cfg.get("count", 3))
	for k in range(count):
		var m = new_unit(MINION, team, "小果冻", origin + Vector2(0.0, float(k - 1) * 46.0))
		m.hp = float(minion_cfg.get("hp", 280))
		m.max_hp = m.hp
		m.radius = float(minion_cfg.get("radius", 20))
		m.height = float(minion_cfg.get("height", 46))
		m.attack_range = float(minion_cfg.get("range", 118))
		m.dmg = float(minion_cfg.get("dmg", 22))
		m.atk_interval = float(minion_cfg.get("atk_interval", 0.9))
		m.atk_timer = rng.randf_range(0.0, 0.6)
		m.move_speed = float(minion_cfg.get("move_speed", 176))
		m.lane_index = 1 if team == BLUE else lane.size() - 2
		minions.append(m)


func step_unit(u, dt: float) -> void:
	u.prev_pos = u.pos
	u.atk_anim = maxf(0.0, u.atk_anim - dt)
	u.cast_anim = maxf(0.0, u.cast_anim - dt)
	u.hurt_anim = maxf(0.0, u.hurt_anim - dt)
	u.stun_t = maxf(0.0, u.stun_t - dt)
	u.slow_t = maxf(0.0, u.slow_t - dt)
	u.invuln_t = maxf(0.0, u.invuln_t - dt)
	u.dash_t = maxf(0.0, u.dash_t - dt)
	u.shield_t = maxf(0.0, u.shield_t - dt)
	u.thorn_t = maxf(0.0, u.thorn_t - dt)
	if u.shield_t <= 0.0:
		u.shield = 0.0

	for i in range(u.cds.size()):
		u.cds[i] = maxf(0.0, u.cds[i] - dt)
	u.calm_t += dt

	if not u.is_alive():
		if u.kind == HERO:
			u.die_t += dt
			u.respawn_t -= dt
			if u.respawn_t <= 0.0:
				respawn(u)
		elif u.kind == BOSS:
			u.die_t += dt
			u.respawn_t -= dt
			if u.respawn_t <= 0.0:
				respawn_boss(u)
		return

	u.atk_timer -= dt

	# 只在自家水晶范围内快速回血；离开范围立刻停止，不做脱战持续回血。
	if u.kind == HERO and u.hp < u.max_hp:
		var home = base_blue if u.team == BLUE else base_red
		if home != null and u.pos.distance_to(home.pos) <= home.radius + 90.0:
			u.hp = minf(u.max_hp, u.hp + u.max_hp * base_heal_per_sec * dt)

	if u.stun_t > 0.0:
		u.moving = false
		return

	if u.kind == HERO:
		step_hero(u, dt)
	elif u.kind == MINION:
		step_minion(u, dt)
	elif u.kind == BOSS:
		step_boss(u, dt)
	else:
		step_structure(u)


func step_hero(h, dt: float) -> void:
	if h.is_player:
		# 技能最高优先级：先消费技能输入，再处理移动，保证一边跑一边放技能不丢输入，
		# 位移技能也能用当帧的摇杆方向。
		for i in range(3):
			if skill_pressed[i]:
				skill_pressed[i] = false
				try_cast(h, i)
		var dir: Vector2 = player_move
		h.moving = dir.length() > 0.1
		if h.moving:
			dir = dir.normalized()
			h.move_dir = dir
			h.facing = 1.0 if dir.x >= 0.0 else -1.0
			var speed_k := 0.55 if h.slow_t > 0.0 else 1.0
			move_to(h, h.pos + dir * (h.move_speed * speed_k * dt))
			h.walk_t += dt
	else:
		step_hero_ai(h, dt)

	var target = nearest_enemy(h, h.attack_range + h.radius)
	if target != null and h.atk_timer <= 0.0:
		h.atk_timer = h.atk_interval
		h.atk_anim = 0.34
		h.facing = 1.0 if target.pos.x >= h.pos.x else -1.0
		if h.attack_range > 250.0:
			shoot(h, target.pos - h.pos, h.dmg, h.accent, 700.0, 0.0, 0.0, 0.0, 0,
				false, null, hero_shot_style(h.hero_id))
		else:
			hit_with_fx(target, h.dmg, h, 0.0)


func hero_shot_style(id: String) -> String:
	# 普攻弹道也带角色特色：星星、叶子、水泡、箭矢、月刃。
	match id:
		"fox":
			return "star"
		"rabbit":
			return "leaf"
		"frog":
			return "bubble"
		"cat":
			return "arrow"
		"owl":
			return "moon"
	return "cube"


func step_hero_ai(h, dt: float) -> void:
	var hp_p: float = h.hp / h.max_hp
	var retreat: bool = hp_p < 0.3

	h.ai_think -= dt
	var think: bool = h.ai_think <= 0.0
	if think:
		h.ai_think = ai_think_base + float(h.uid % 5) * 0.025
	if h.ai_target == null or not h.ai_target.is_alive():
		h.ai_target = ai_target(h)
	var t = h.ai_target
	var front = front_structure(h.team)
	# 锁定目标后仍可能一路追到塔后；追击途中也要受前塔限制。
	if t != null and t != front and front != null and front.kind == TOWER and front.is_alive():
		if (h.team == BLUE and t.pos.x > front.pos.x + 20.0) or \
				(h.team == RED and t.pos.x < front.pos.x - 20.0):
			h.ai_target = null
			t = null

	if think:
		step_hero_skills(h, hp_p, retreat)

	if retreat:
		var home := base_pos(h.team) + Vector2(70.0 if h.team == BLUE else -70.0, 0.0)
		var away: Vector2 = home - h.pos
		if away.length() > 55.0:
			move_ai(h, away, dt, 1.0)
		else:
			h.moving = false
		h.facing = 1.0 if away.x >= 0.0 else -1.0
		return

	if t == null:
		# 没有近处目标时，走向「最靠前的敌方建筑」，不要直接奔向水晶。
		if front != null and front.is_alive():
			move_ai(h, front.pos - h.pos, dt, 0.9)
		else:
			h.moving = false
		return

	var to_t: Vector2 = t.pos - h.pos
	var dist := to_t.length()
	h.facing = 1.0 if to_t.x >= 0.0 else -1.0

	if h.attack_range > 250.0:
		var structure: bool = t.kind == TOWER or t.kind == BASE
		if dist < h.attack_range * 0.55:
			move_ai(h, -to_t, dt, 1.0)
		elif dist > h.attack_range * 0.86:
			move_ai(h, to_t, dt, 0.9)
		elif structure:
			# 拆塔时站定输出，别绕圈绕到水晶背后。
			h.moving = false
		else:
			var side := Vector2(-to_t.y, to_t.x) * (1.0 if (h.uid % 2) == 0 else -1.0)
			move_ai(h, side, dt, 0.35)
	else:
		var keep: float = h.attack_range * 0.84
		if dist > keep:
			move_ai(h, to_t, dt, 1.0)
		else:
			h.moving = false


func move_ai(h, dir: Vector2, dt: float, speed_k: float) -> void:
	if dir.length_squared() < 0.0001:
		h.moving = false
		return
	dir = dir.normalized()
	h.move_dir = dir
	h.moving = true
	var slow_k := 0.55 if h.slow_t > 0.0 else 1.0
	move_to(h, h.pos + dir * (h.move_speed * speed_k * slow_k * dt))
	h.walk_t += dt


func step_hero_skills(h, hp_p: float, retreat: bool) -> void:
	for i in range(3):
		var s: Dictionary = h.skills[i]
		if s.get("unlock_at_2", false) and h.level < 2:
			continue
		if h.cds[i] > 0.0:
			continue
		var kind := str(s.get("kind", ""))
		var support := kind == "heal" or kind == "shield"
		if retreat and not support:
			continue

		var use := false
		match kind:
			"heal":
				use = low_ally(h, float(s.get("radius", 380)), 0.68) and rng.randf() < 0.55
			"shield":
				use = hp_p < 0.75 and enemy_hero_near(h, 420.0) and rng.randf() < 0.5
			"dash":
				var td = h.ai_target
				if td != null:
					var d: float = h.pos.distance_to(td.pos)
					use = d > float(s.get("range", 230)) * 0.9 and d < float(s.get("range", 230)) * 1.7 and rng.randf() < 0.4
			"cone":
				use = count_enemies_around(h, float(s.get("range", 132)), 0.2) > 0 and rng.randf() < 0.5
			"pull", "leap":
				use = nearest_hero(h, float(s.get("range", 300))) != null and rng.randf() < 0.32
			"multi":
				use = nearest_enemy(h, float(s.get("range", 260))) != null and rng.randf() < 0.34
			"radial":
				use = nearest_enemy(h, float(s.get("range", 152))) != null and rng.randf() < 0.42
			"aoe":
				use = count_enemies_around(h, float(s.get("radius", 180)), -1.0) > 0 and rng.randf() < 0.42
			_:
				use = nearest_enemy(h, maxf(float(s.get("range", 260)), h.attack_range)) != null and rng.randf() < 0.36

		if use and ai_skill_mul < 1.0 and rng.randf() > ai_skill_mul:
			use = false
		if use:
			try_cast(h, i)
			break


func low_ally(h, radius: float, pct: float) -> bool:
	for a in heroes:
		if not a.is_alive() or a.team != h.team:
			continue
		if a.hp / a.max_hp < pct and a.pos.distance_to(h.pos) <= radius:
			return true
	return false


func enemy_hero_near(h, radius: float) -> bool:
	for o in heroes:
		if o.is_alive() and o.team != h.team and o.pos.distance_to(h.pos) <= radius:
			return true
	return false


func count_enemies_around(h, radius: float, dot_min: float) -> int:
	var n := 0
	var aim: Vector2 = h.move_dir.normalized() if h.move_dir.length_squared() > 0.01 else Vector2(h.facing, 0.0)
	for u in units:
		if not u.is_alive() or u.team == h.team:
			continue
		var to: Vector2 = u.pos - h.pos
		if to.length() > radius + u.radius:
			continue
		if dot_min < 0.99 and to.normalized().dot(aim) < dot_min:
			continue
		n += 1
	return n


func front_structure(team: int):
	# 敌方最靠前（离我方最近）的存活塔；两座塔都拆掉后才轮到水晶。
	var list: Array = towers_red if team == BLUE else towers_blue
	var best = null
	for t in list:
		if not t.is_alive():
			continue
		if best == null:
			best = t
		elif team == BLUE and t.pos.x < best.pos.x:
			best = t
		elif team == RED and t.pos.x > best.pos.x:
			best = t
	if best != null:
		return best
	return base_red if team == BLUE else base_blue


func ai_target(h):
	var front = front_structure(h.team)
	var tower_alive: bool = front != null and front.kind == TOWER and front.is_alive()
	var best = null
	var bd := 900.0
	for o in units:
		if not o.is_alive() or o.team == h.team:
			continue
		if o.kind == TOWER and is_tower_protected(o):
			continue
		if o.kind == BASE and is_base_protected(o):
			continue
		# 前塔还活着时不越过它去追英雄/小兵，否则会从塔边溜过去直扑水晶。
		if tower_alive and o != front and (o.kind == HERO or o.kind == MINION):
			if h.team == BLUE and o.pos.x > front.pos.x + 20.0:
				continue
			if h.team == RED and o.pos.x < front.pos.x - 20.0:
				continue
		var d: float = h.pos.distance_to(o.pos)
		var w := d + (-40.0 if o.kind == HERO else 0.0)
		if o == front:
			w -= 160.0
		if sudden_death and o.kind == BASE:
			w -= 1200.0
		if w < bd:
			bd = w
			best = o
	return best


func step_minion(m, dt: float) -> void:
	var foe = nearest_enemy(m, m.attack_range + 40.0)
	if foe != null:
		m.moving = false
		m.facing = 1.0 if foe.pos.x >= m.pos.x else -1.0
		if m.atk_timer <= 0.0:
			m.atk_timer = m.atk_interval
			m.atk_anim = 0.22
			var mul := float(minion_cfg.get("structure_damage_mul", 2.4))
			var dmg: float = m.dmg * mul if (foe.kind == TOWER or foe.kind == BASE) else m.dmg
			hit_with_fx(foe, dmg, m, 0.0)
		return

	var step_dir := 1 if m.team == BLUE else -1
	var idx := clampi(m.lane_index, 0, lane.size() - 1)
	var goal: Vector2 = lane[idx]
	for guard in range(lane.size()):
		if (goal - m.pos).length() > 70.0:
			break
		var next_idx := idx + step_dir
		if next_idx < 0 or next_idx >= lane.size():
			break
		idx = next_idx
		goal = lane[idx]
	m.lane_index = idx

	var to: Vector2 = goal - m.pos
	var d := to.length()
	if d < 10.0:
		return
	to = to / d
	m.move_dir = to
	m.facing = 1.0 if to.x >= 0.0 else -1.0
	m.moving = true
	var slow_k := 0.55 if m.slow_t > 0.0 else 1.0
	move_to(m, m.pos + to * (m.move_speed * slow_k * dt))
	m.walk_t += dt


func step_structure(s) -> void:
	# 最后 45 秒防御塔过载停火：双方都能真正推掉水晶，避免只靠时间到结算。
	if final_push:
		return
	var target = nearest_enemy(s, s.attack_range)
	if target == null:
		return
	if s.atk_timer > 0.0:
		return
	s.atk_timer = s.atk_interval
	s.atk_anim = 0.32
	var col := Color(0.6, 0.9, 1.0) if s.kind == BASE else Color(1.0, 0.86, 0.6)
	var spd := 900.0 if s.kind == BASE else 760.0
	shoot(s, target.pos - s.pos, s.dmg, col, spd, 0.0, 0.0, 0.0, 0, true, target)


func move_to(u, p: Vector2) -> void:
	p.x = clampf(p.x, 60.0, map_w - 60.0)
	p.y = clampf(p.y, 60.0, map_h - 60.0)
	u.pos = p


func shoot(src, dir: Vector2, dmg: float, color: Color, speed: float,
		slow: float, splash: float, splash_radius: float, pierce: int,
		homing := false, target = null, style := "cube") -> void:
	if dir.length_squared() < 0.001:
		dir = Vector2.RIGHT
	var p = Projectile.new()
	p.pos = src.pos
	p.prev_pos = p.pos
	p.dir = dir.normalized()
	p.team = src.team
	p.src = src
	p.speed = speed
	p.dmg = dmg
	p.life = 1.6
	p.size = 9.0 if splash > 0.0 else 6.0
	p.color = color
	p.slow = slow
	p.splash = splash
	p.splash_radius = splash_radius
	p.pierce = pierce
	p.bubble = splash > 0.0
	p.view_id = _shot_view
	_shot_view += 1
	p.homing = homing
	p.target = target
	p.style = style
	shots.append(p)
	if src != null and src.kind == HERO and src.attack_range > 250.0:
		sfx.emit("shoot_" + src.hero_id, -5.0)
	fx.emit("muzzle", Vector3(p.pos.x, src.height * 0.45, p.pos.y), color, 0.0)


func step_projectiles(dt: float) -> void:
	for p in shots:
		if not p.alive:
			continue
		p.prev_pos = p.pos
		if p.homing and p.target != null and p.target.is_alive():
			var to: Vector2 = p.target.pos - p.pos
			if to.length_squared() > 0.01:
				p.dir = to.normalized()
		p.pos += p.dir * (p.speed * dt)
		p.life -= dt
		if p.life <= 0.0:
			p.alive = false
			continue

		for u in units:
			if not u.is_alive() or u.team == p.team:
				continue
			var hit_r: float = u.radius * 0.7 if (u.kind == TOWER or u.kind == BASE) else u.radius + 10.0
			if (p.pos - u.pos).length_squared() > hit_r * hit_r:
				continue
			if p.hit.has(u.uid):
				continue

			if p.splash > 0.0:
				p.alive = false
				area_damage(p.pos, p.splash_radius, p.dmg, p.src, p.team, p.slow, 0.0, 0.0)
				fx.emit("burst", Vector3(p.pos.x, 20.0, p.pos.y), p.color, 0.0)
				fx.emit("ring", Vector3(p.pos.x, 6.0, p.pos.y), p.color, p.splash_radius)
				sfx.emit("boom")
			else:
				hit_with_fx(u, p.dmg, p.src, 0.0, p.color)
				if p.slow > 0.0:
					u.slow_t = maxf(u.slow_t, p.slow)
				p.hit[u.uid] = true
				if p.pierce > 0:
					p.pierce -= 1
				else:
					p.alive = false
				fx.emit("burst", Vector3(p.pos.x, 20.0, p.pos.y), p.color, 0.0)
			break

	var alive_shots: Array = []
	for p in shots:
		if p.alive:
			alive_shots.append(p)
	shots = alive_shots


func hit_with_fx(target, amount: float, src, stun := 0.0, col = null) -> void:
	deal_damage(target, amount, src)
	if stun > 0.0:
		target.stun_t = maxf(target.stun_t, stun)
	target.hurt_anim = 0.22
	target.hurt_t = 0.22
	if src != null and src.is_alive():
		target.facing = 1.0 if src.pos.x >= target.pos.x else -1.0
	var fx_color: Color = Color(1.0, 0.92, 0.75) if typeof(col) != TYPE_COLOR else col
	if src != null and src.kind == HERO and src.attack_range <= 260.0:
		fx.emit("slash", Vector3(src.pos.x + src.facing * 46.0, 24.0, src.pos.y), src.accent, 132.0)
	fx.emit("hit", Vector3(target.pos.x, target.height * 0.55, target.pos.y), fx_color, 0.0)
	var hit_key := "hit"
	if src != null and src.kind == HERO:
		hit_key = "hit_" + src.hero_id
	sfx.emit(hit_key)
	if src != null and src.is_player and src.dash_t <= 0.0 and amount >= hitstop_threshold:
		hitstop.emit(hitstop_duration)


func deal_damage(target, amount: float, src, reflect := true) -> void:
	if target == null or not target.is_alive():
		return
	if target.kind == HERO and target.invuln_t > 0.0:
		return
	if target.kind == TOWER and is_tower_protected(target):
		float_text.emit(Vector3(target.pos.x, target.height + 24.0, target.pos.y), "先拆外塔", Color(1, 0.95, 0.7))
		return
	if target.kind == BASE and is_base_protected(target):
		float_text.emit(Vector3(target.pos.x, target.height + 24.0, target.pos.y), "水晶被保护着", Color(1, 0.95, 0.7))
		return

	if src != null and src.team == RED and target.team == BLUE:
		amount *= enemy_dmg_mul

	# 终极对决：建筑变脆，保证 3 分钟内能打出结果。
	if sudden_death and (target.kind == TOWER or target.kind == BASE):
		amount *= float(comeback_cfg.get("sudden_death_structure_mul", 1.8))

	if reflect and target.thorn_t > 0.0 and src != null and src != target and src.is_alive() and src.kind == HERO:
		deal_damage(src, 24.0 + target.level * 5.0, target, false)
		fx.emit("hit", Vector3(src.pos.x, 40.0, src.pos.y), Color(1, 0.85, 0.66), 0.0)

	if target.shield > 0.0:
		var absorb := minf(target.shield, amount)
		target.shield -= absorb
		amount -= absorb

	var hp_damage := maxf(0.0, minf(amount, maxf(target.hp, 0.0)))
	target.hp -= amount
	if src != null and src.kind == HERO and target.kind == HERO and hp_damage > 0.0:
		src.damage_dealt += hp_damage
	if amount > 0.1:
		target.calm_t = 0.0
	if amount >= 1.0:
		var col := Color(1, 0.78, 0.72) if target.team == BLUE else Color(1, 1, 0.82)
		float_text.emit(Vector3(target.pos.x, target.height + 24.0, target.pos.y), str(roundi(amount)), col)

	if target.hp <= 0.0:
		kill(target, src)


func kill(target, killer) -> void:
	target.hp = 0.0
	target.die_t = 0.0
	fx.emit("burst", Vector3(target.pos.x, target.height * 0.5, target.pos.y), Color(1, 0.9, 0.7), 0.0)

	if target.kind == HERO:
		target.deaths += 1
		var behind := score_red - score_blue if target.team == BLUE else score_blue - score_red
		var max_tiers := int(comeback_cfg.get("max_tiers", 3))
		var cut := float(comeback_cfg.get("respawn_cut", 0.55))
		var min_respawn := float(comeback_cfg.get("min_respawn", 3.8))
		target.respawn_t = maxf(min_respawn, respawn_time - clampf(float(behind), 0.0, float(max_tiers)) * cut)
		if killer != null:
			killer.kills += 1
			if killer.kind == HERO:
				add_xp(killer, xp_hero_kill)
			for a in heroes:
				if a != killer and a.is_alive() and a.team == killer.team and a.pos.distance_to(target.pos) < 700.0:
					add_xp(a, xp_hero_assist)
		if target.team == BLUE:
			score_red += 1
		else:
			score_blue += 1
		var killer_name: String = killer.display_name if killer != null else "？"
		banner.emit("%s 击败了 %s" % [killer_name, target.display_name], 1.8)
		sfx.emit("ult")

	elif target.kind == BOSS:
		target.respawn_t = boss_respawn
		banner.emit("峡谷巨兽被击退了！", 2.4)
		sfx.emit("boom")
		fx.emit("debris", Vector3(target.pos.x, target.height * 0.45, target.pos.y),
			_team_color(target.team), target.radius)
		if killer != null and killer.kind == HERO:
			add_xp(killer, 90.0)

	elif target.kind == TOWER:
		banner.emit("我方蘑菇塔被拆了！" if target.team == BLUE else "拆掉一座敌方蘑菇塔！", 2.0)
		sfx.emit("boom")
		fx.emit("debris", Vector3(target.pos.x, target.height * 0.45, target.pos.y),
			_team_color(target.team), target.radius)
		for a in heroes:
			if a.is_alive() and a.team != target.team:
				add_xp(a, xp_tower)

	elif target.kind == MINION:
		if killer != null and killer.kind == HERO:
			add_xp(killer, xp_minion)
		if killer != null:
			for a in heroes:
				if a != killer and a.is_alive() and a.team == killer.team and a.pos.distance_to(target.pos) < 450.0:
					add_xp(a, xp_minion_assist)

	elif target.kind == BASE:
		sfx.emit("boom")
		fx.emit("debris", Vector3(target.pos.x, target.height * 0.45, target.pos.y),
			_team_color(target.team), target.radius * 1.2)


func _team_color(team: int) -> Color:
	return Color(0.42, 0.72, 0.95) if team == BLUE else Color(0.92, 0.44, 0.38)


func add_xp(h, add: float) -> void:
	if h == null or add <= 0.0 or h.level >= 2:
		return
	h.xp += add
	if h.xp >= xp_to_level2:
		h.level = 2
		h.level2_time = clock
		float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "二级解锁大招！", Color(1, 0.95, 0.6))
		if h.is_player:
			banner.emit("大招解锁！按右上的技能键放出来", 1.8)
			sfx.emit("ult")
		level_up.emit(h)


func respawn(h) -> void:
	h.hp = h.max_hp
	h.pos = base_pos(h.team) + Vector2(150.0 if h.team == BLUE else -150.0, 0.0)
	h.prev_pos = h.pos
	h.invuln_t = 1.6
	h.stun_t = 0.0
	h.slow_t = 0.0
	h.shield = 0.0
	h.thorn_t = 0.0
	h.move_dir = Vector2.ZERO
	h.atk_timer = 0.3
	fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), Color(0.6, 0.95, 1.0) if h.team == BLUE else Color(1, 0.7, 0.6), 90.0)


func area_damage(center: Vector2, radius: float, dmg: float, src, team: int,
		slow: float, stun: float, knock: float) -> void:
	for u in units:
		if not u.is_alive() or u.team == team:
			continue
		if center.distance_to(u.pos) > radius + u.radius:
			continue
		deal_damage(u, dmg, src)
		if slow > 0.0:
			u.slow_t = maxf(u.slow_t, slow)
		if stun > 0.0:
			u.stun_t = maxf(u.stun_t, stun)
		if knock > 0.0 and u.kind != TOWER and u.kind != BASE:
			var n: Vector2 = u.pos - center
			if n.length_squared() < 0.0001:
				n = Vector2.RIGHT
			move_to(u, u.pos + n.normalized() * knock)


func nearest_enemy(from, radius: float):
	var best = null
	var bd := radius
	for u in units:
		if not u.is_alive() or u.team == from.team:
			continue
		if u.kind == TOWER and is_tower_protected(u):
			continue
		if u.kind == BASE and is_base_protected(u):
			continue
		var d: float = from.pos.distance_to(u.pos)
		if d <= bd:
			bd = d
			best = u
	return best


func nearest_hero(from, radius: float):
	var best = null
	var bd := radius
	for u in heroes:
		if not u.is_alive() or u.team == from.team:
			continue
		var d: float = from.pos.distance_to(u.pos)
		if d < bd:
			bd = d
			best = u
	return best


func nearest_ally(from, radius: float, include_self: bool):
	var best = null
	var bd := radius
	for u in heroes:
		if not u.is_alive() or u.team != from.team:
			continue
		if not include_self and u == from:
			continue
		var d: float = from.pos.distance_to(u.pos)
		if d < bd:
			bd = d
			best = u
	return best


func is_tower_protected(t) -> bool:
	if sudden_death:
		return false
	if t.kind != TOWER:
		return false
	var list: Array = towers_blue if t.team == BLUE else towers_red
	for o in list:
		if o != t and o.is_alive() and o.level < t.level:
			return true
	return false


func is_base_protected(b) -> bool:
	if sudden_death:
		return false
	if b.kind != BASE:
		return false
	var list: Array = towers_blue if b.team == BLUE else towers_red
	for o in list:
		if o.is_alive():
			return true
	return false


func step_zones(dt: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var z = zones[i]
		z.t += dt
		if z.t >= z.life:
			zones.remove_at(i)
			continue
		for u in units:
			if not u.is_alive() or u.team == z.team:
				continue
			if z.pos.distance_to(u.pos) > z.radius + u.radius:
				continue
			u.slow_t = maxf(u.slow_t, z.slow)


func cleanup_dead() -> void:
	for i in range(units.size() - 1, -1, -1):
		var u = units[i]
		if u.is_alive():
			continue
		# 塔、水晶与峡谷巨兽留在 units 里，表现层才能换废墟或显示复活。
		if u.kind == HERO or u.kind == BOSS or u.kind == TOWER or u.kind == BASE:
			continue
		units.remove_at(i)
	minions = minions.filter(func(m): return m.is_alive())


func separate_units() -> void:
	for iter in range(2):
		for i in range(units.size()):
			var a = units[i]
			if not a.is_alive() or a.kind == TOWER or a.kind == BASE:
				continue
			for j in range(i + 1, units.size()):
				var b = units[j]
				if not b.is_alive() or b.kind == TOWER or b.kind == BASE:
					continue
				var min_d: float = (a.radius + b.radius) * 0.82
				var d: Vector2 = a.pos - b.pos
				var sq := d.length_squared()
				if sq >= min_d * min_d:
					continue
				var dist := sqrt(sq)
				if dist < 0.001:
					d = Vector2(1, 0)
					dist = 1.0
				var push := minf(12.0, (min_d - dist) * 0.5)
				var n := d / dist
				move_to(a, a.pos + n * push)
				move_to(b, b.pos - n * push)


func end_match(winner_team: int, reason := "水晶被摧毁") -> void:
	over = true
	winner = winner_team
	end_reason = reason
	banner.emit("胜利！水晶亮起来了" if winner_team == BLUE else "水晶被点亮了…再来一局？", 6.0)
	sfx.emit("win" if winner_team == BLUE else "lose")
	match_ended.emit(winner_team)


func try_cast(h, index: int) -> void:
	if not h.is_alive() or h.stun_t > 0.0:
		return
	if index < 0 or index >= h.skills.size():
		return
	var s: Dictionary = h.skills[index]
	if s == null:
		return
	if s.get("unlock_at_2", false) and h.level < 2:
		float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "2 级解锁", Color(1, 0.9, 0.6))
		return
	if h.cds[index] > 0.0:
		return
	h.cds[index] = float(s.get("cd", 6.0))
	h.cast_anim = 0.5
	sfx.emit(("ult_" if index == 2 else "cast_") + h.hero_id)
	if h.is_player and index == 2:
		fx.emit("punch", Vector3(h.pos.x, 40.0, h.pos.y), Color.WHITE, 0.0)
	cast(h, s, index)


func cast(h, s: Dictionary, index: int) -> void:
	var kind := str(s.get("kind", "projectile"))
	var forward: Vector2 = h.move_dir.normalized() if h.move_dir.length_squared() > 0.01 else Vector2(h.facing, 0.0)
	var aim = null
	if kind != "dash" or not h.is_player:
		aim = nearest_enemy(h, maxf(float(s.get("range", 260.0)), 260.0))
	var aim_dir := forward
	if aim != null:
		aim_dir = (aim.pos - h.pos).normalized()
		h.facing = 1.0 if aim.pos.x >= h.pos.x else -1.0
	if kind == "dash":
		# 位移技能只认玩家/英雄当前的移动方向，不自动扭头追最近敌人。
		# 否则逃跑时按瞬移会被拽回敌人身边。
		if h.is_player:
			if player_move.length_squared() > 0.01:
				aim_dir = player_move.normalized()
			else:
				aim_dir = Vector2(h.facing, 0.0)
		elif h.move_dir.length_squared() > 0.01:
			aim_dir = h.move_dir.normalized()
		elif aim != null:
			aim_dir = (aim.pos - h.pos).normalized()
		else:
			aim_dir = Vector2(h.facing, 0.0)
		h.facing = 1.0 if aim_dir.x >= 0.0 else -1.0
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	var color: Color = s.get("color_c", Color.WHITE)
	var dmg := float(s.get("dmg", 0.0))
	var radius := float(s.get("radius", 120.0))
	var style := str(s.get("fx", "burst"))
	if kind != "leap" and kind != "pull" and kind != "multi":
		# 每个英雄的施法都有专属形状：爪痕、星星、叶子、水泡、箭雨、竹子、月光…
		fx.emit("cast_" + style, Vector3(h.pos.x, 22.0, h.pos.y), color, maxf(radius, 90.0))

	match kind:
		"projectile", "radial":
			var n := int(maxf(1.0, float(s.get("count", 1))))
			for k in range(n):
				var dir := aim_dir
				if kind == "radial":
					var angle_radial := (float(k) / float(n)) * TAU
					dir = Vector2(cos(angle_radial), sin(angle_radial))
				elif n > 1:
					var angle_spread := atan2(aim_dir.y, aim_dir.x) + (float(k) - float(n - 1) * 0.5) * 0.16
					dir = Vector2(cos(angle_spread), sin(angle_spread))
				shoot(h, dir, dmg, color, float(s.get("speed", 620.0)),
					float(s.get("slow", 0.0)), 0.0, 0.0, int(s.get("pierce", 0)),
					false, null, style)
		"splash":
			var p = Projectile.new()
			p.pos = h.pos
			p.dir = aim_dir
			p.team = h.team
			p.src = h
			p.speed = float(s.get("speed", 660.0))
			p.dmg = dmg
			p.life = 1.8
			p.size = 10.0
			p.color = color
			p.slow = float(s.get("slow", 0.0))
			p.splash = dmg
			p.splash_radius = radius
			p.bubble = true
			p.style = style
			p.view_id = _shot_view
			_shot_view += 1
			shots.append(p)
			fx.emit("muzzle", Vector3(p.pos.x, h.height * 0.45, p.pos.y), color, 0.0)
		"dash":
			var dash_from: Vector2 = h.pos
			var dash_to: Vector2 = h.pos + aim_dir * float(s.get("range", 230.0))
			if not h.is_player:
				dash_to = clamp_to_front(h, dash_to)
			move_to(h, dash_to)
			h.invuln_t = maxf(h.invuln_t, 0.12)
			# 位移期间不触发顿帧，否则瞬移瞬间会明显卡一下。
			h.dash_t = maxf(h.dash_t, 0.25)
			fx.emit("burst", Vector3(dash_from.x, 24.0, dash_from.y), color, 0.0)
			fx.emit("burst", Vector3(h.pos.x, 24.0, h.pos.y), color, 0.0)
			fx.emit("cast_" + style, Vector3(h.pos.x, 22.0, h.pos.y), color, maxf(radius, 90.0))
			if dmg > 0.0:
				area_damage(h.pos, radius, dmg, h, h.team, float(s.get("slow", 0.0)), 0.0, float(s.get("knock", 0.0)))
				fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), color, radius)
			if s.get("zone", false):
				zones.append(make_zone(h.pos, 90.0, 2.6, float(s.get("slow", 0.9)), h.team, color))
		"aoe":
			area_damage(h.pos, radius, dmg, h, h.team, float(s.get("slow", 0.0)),
				float(s.get("stun", 0.0)), float(s.get("knock", 0.0)))
			fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), color, radius)
			fx.emit("burst", Vector3(h.pos.x, 30.0, h.pos.y), color, 0.0)
		"cone":
			for u in units:
				if not u.is_alive() or u.team == h.team:
					continue
				var to_cone: Vector2 = u.pos - h.pos
				if to_cone.length() > radius + u.radius:
					continue
				if to_cone.normalized().dot(aim_dir) < 0.35:
					continue
				deal_damage(u, dmg, h)
				u.slow_t = maxf(u.slow_t, float(s.get("slow", 0.0)))
				var knock := float(s.get("knock", 0.0))
				if knock > 0.0 and u.kind != TOWER and u.kind != BASE:
					move_to(u, u.pos + to_cone.normalized() * knock)
				fx.emit("hit", Vector3(u.pos.x, 30.0, u.pos.y), color, 0.0)
			fx.emit("ring", Vector3(h.pos.x + aim_dir.x * 70.0, 6.0, h.pos.y + aim_dir.y * 70.0), color, radius * 0.8)
		"heal":
			var heal_pct := float(s.get("heal_pct", 0.0))
			h.hp = minf(h.max_hp, h.hp + h.max_hp * heal_pct)
			fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), color, 110.0)
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "+" + str(roundi(h.max_hp * heal_pct)), color)
			for a in heroes:
				if a == h or not a.is_alive() or a.team != h.team:
					continue
				if a.pos.distance_to(h.pos) > radius:
					continue
				a.hp = minf(a.max_hp, a.hp + a.max_hp * heal_pct * 0.7)
				fx.emit("ring", Vector3(a.pos.x, 6.0, a.pos.y), color, 80.0)
				float_text.emit(Vector3(a.pos.x, a.height + 24.0, a.pos.y), "+" + str(roundi(a.max_hp * heal_pct * 0.7)), color)
		"shield":
			h.shield = h.max_hp * float(s.get("shield_pct", 0.0))
			h.shield_t = float(s.get("buff_t", 3.0))
			h.thorn_t = h.shield_t
			fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), color, 90.0)
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "扎手！", color)
		"pull":
			var pull_target = nearest_hero(h, float(s.get("range", 300.0)))
			if pull_target == null:
				float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "抱不到人…", color)
				h.cds[index] = 0.8
				return
			var to_h: Vector2 = h.pos + aim_dir * 62.0
			move_to(pull_target, to_h)
			pull_target.stun_t = maxf(pull_target.stun_t, float(s.get("stun", 0.0)))
			deal_damage(pull_target, dmg, h)
			h.shield = maxf(h.shield, h.max_hp * float(s.get("shield_pct", 0.0)))
			h.shield_t = maxf(h.shield_t, 3.0)
			fx.emit("cast_" + style, Vector3(pull_target.pos.x, 22.0, pull_target.pos.y), color, 80.0)
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "抱住了！", color)
		"leap":
			var leap_target = nearest_hero(h, float(s.get("range", 360.0)))
			var dest: Vector2 = leap_target.pos if leap_target != null else h.pos + aim_dir * 220.0
			if not h.is_player:
				dest = clamp_to_front(h, dest)
			move_to(h, dest)
			leap_land(h, dest, s)
		"multi":
			var multi_target = nearest_enemy(h, float(s.get("range", 600.0)))
			var center: Vector2 = multi_target.pos if multi_target != null else h.pos + aim_dir * 200.0
			var delay := float(s.get("delay", 0.42))
			var count := int(s.get("count", 3))
			for k in range(count):
				var at := center + Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-45.0, 45.0))
				fx.emit("ring", Vector3(at.x, 6.0, at.y), color, radius)
				pending.append({
					"t": delay * float(k + 1),
					"center": at,
					"skill": s,
					"src": h,
					"dmg": dmg,
					"radius": radius,
					"slow": float(s.get("slow", 0.0)),
					"heal_pct": float(s.get("heal_pct", 0.0)),
					"color": color,
					"style": style,
				})


func clamp_to_front(h, dest: Vector2) -> Vector2:
	# AI 的位移技能不能把它送过敌方前塔，否则会绕过塔直扑水晶。
	var front = front_structure(h.team)
	if front == null or front.kind != TOWER or not front.is_alive():
		return dest
	var keep: float = float(h.radius) + 18.0
	if h.team == BLUE:
		dest.x = minf(dest.x, front.pos.x - keep)
	else:
		dest.x = maxf(dest.x, front.pos.x + keep)
	return dest


func make_zone(pos: Vector2, radius: float, life: float, slow: float, team: int, color: Color):
	var z = Zone.new()
	z.pos = pos
	z.radius = radius
	z.life = life
	z.slow = slow
	z.team = team
	z.color = color
	return z


func leap_land(h, dest: Vector2, s: Dictionary) -> void:
	var color: Color = s.get("color_c", Color.WHITE)
	var radius := float(s.get("radius", 235.0))
	area_damage(dest, radius, float(s.get("dmg", 0.0)), h, h.team,
		float(s.get("slow", 0.0)), float(s.get("stun", 0.0)), 26.0)
	fx.emit("cast_" + str(s.get("fx", "quake")), Vector3(dest.x, 20.0, dest.y), color, radius)
	fx.emit("ring", Vector3(dest.x, 6.0, dest.y), color, radius)
	fx.emit("burst", Vector3(dest.x, 20.0, dest.y), color, 0.0)
	if s.get("zone", false):
		zones.append(make_zone(dest, radius * 0.8, 3.2, 0.5, h.team, color))


func step_pending(dt: float) -> void:
	for i in range(pending.size() - 1, -1, -1):
		var item: Dictionary = pending[i]
		item["t"] = float(item["t"]) - dt
		if float(item["t"]) > 0.0:
			continue
		var src = item["src"]
		if src == null or not src.is_alive():
			pending.remove_at(i)
			continue
		var center: Vector2 = item["center"]
		var radius := float(item["radius"])
		var color: Color = item["color"]
		area_damage(center, radius, float(item["dmg"]), src, src.team, float(item.get("slow", 0.0)), 0.0, 0.0)
		fx.emit("cast_" + str(item.get("style", "burst")), Vector3(center.x, 20.0, center.y), color, radius)
		fx.emit("ring", Vector3(center.x, 6.0, center.y), color, radius)
		fx.emit("burst", Vector3(center.x, 20.0, center.y), color, 0.0)
		var heal_pct := float(item.get("heal_pct", 0.0))
		if heal_pct > 0.0:
			for a in heroes:
				if not a.is_alive() or a.team != src.team:
					continue
				if a.pos.distance_to(center) > radius:
					continue
				a.hp = minf(a.max_hp, a.hp + a.max_hp * heal_pct)
				float_text.emit(Vector3(a.pos.x, a.height + 24.0, a.pos.y), "+" + str(roundi(a.max_hp * heal_pct)), color)
		sfx.emit("boom")
		pending.remove_at(i)

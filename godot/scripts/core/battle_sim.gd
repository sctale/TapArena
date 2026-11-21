class_name BattleSim
extends RefCounted

# 纯逻辑战斗模拟：不引用任何节点、摄像机、音频或 UI。
# 表现层通过信号订阅；这样同一套规则可以在 Godot 里玩，也可以 --headless 跑回归。

signal banner(text: String, duration: float)
signal float_text(pos: Vector3, text: String, color: Color)
signal fx(kind: String, pos: Vector3, color: Color, radius: float)
signal beam_fx(from: Vector3, to: Vector3, color: Color, width: float)
signal sfx(key: String, pos: Vector2)
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
const JUNGLE := 5
const NEUTRAL := 2
# 不需要敌方目标的自身/区域技能；其余方向型技能走智能瞄准。
const SELF_SKILL_KINDS := ["aoe", "radial", "heal", "heal_zone", "shield", "vanish",
	"spin", "taunt", "fear", "mark"]
# 需要按弹速做提前量预判的技能。
const LEAD_SKILL_KINDS := ["projectile", "splash", "boomerang", "beam", "cone", "multi"]

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
	# 表现用朝向：移动/攻击/施法方向（任意角度），不参与战斗逻辑；facing 的 ±1 语义保留。
	var face_dir := Vector2.ZERO

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
	# 平滑位移：冲刺/后跃/跳跃分多帧走完，避免一帧瞬移造成镜头和模型跳变。
	var move_skill_t: float = 0.0
	var move_skill_total: float = 0.0
	var move_skill_from := Vector2.ZERO
	var move_skill_to := Vector2.ZERO
	var move_skill_kind: String = ""
	var move_skill_data: Dictionary = {}
	var hurt_t: float = 0.0
	var shield: float = 0.0
	var shield_t: float = 0.0
	var thorn_t: float = 0.0
	var calm_t: float = 0.0
	# 差异化状态：猎杀标记 / 恐惧 / 嘲讽 / 旋身刺球。
	var mark_t: float = 0.0
	var fear_t: float = 0.0
	var fear_src = null
	var taunt_t: float = 0.0
	var taunt_src = null
	var spin_t: float = 0.0
	var spin_tick: float = 0.0
	var spin_radius: float = 130.0
	var spin_dmg: float = 0.0
	var spin_color := Color.WHITE
	# 野区增益与刺客伏击：野怪 buff 与「尖刺伏击」都用同一套计时字段。
	var buff_dmg_t: float = 0.0
	var buff_dmg_pct: float = 0.0
	var buff_speed_t: float = 0.0
	var buff_speed_pct: float = 0.0
	var vanish_t: float = 0.0
	var ambush_t: float = 0.0
	var ambush_pending: float = 0.0
	var ambush_mul: float = 1.8

	var atk_anim: float = 0.0
	var cast_anim: float = 0.0
	var cast_total: float = 0.5
	var cast_index: int = -1
	var cast_kind: String = ""
	var hurt_anim: float = 0.0
	var die_t: float = 0.0
	var respawn_t: float = 0.0
	var walk_t: float = 0.0
	var moving: bool = false
	var is_player: bool = false

	var ai_think: float = 0.0
	var ai_target = null
	# 撤退状态粘滞：避免站在血量/人数阈值上来回翻转（表现为原地转圈）。
	var retreat_t: float = 0.0
	# 普攻锁定目标：王者式优先级（英雄 > 残血单位 > 建筑），粘性避免来回切换。
	var atk_target = null
	var lane_index: int = 0
	var lane_id: int = 1
	var jungle_kind: String = ""
	var respawn_home := Vector2.ZERO
	# 打野位：-2 表示不在任何一路；gank 计时结束后回野区。
	var is_jungler: bool = false
	var jungle_gank_t: float = 0.0
	var jungle_gank_lane: int = 1
	# 本家野区全空时的等待计时与巡逻点：等太久就在自家野区里走动，不站成木桩。
	var jungle_wait_t: float = 0.0
	var jungle_patrol := Vector2.ZERO

	# BOSS 技能状态：前摇、冲撞、施法目标。普通英雄不用这些字段。
	var boss_skill: String = ""
	var boss_phase: int = 1
	var boss_flying: bool = false
	var boss_cast_t: float = 0.0
	var boss_charge_t: float = 0.0
	var boss_charge_dir := Vector2.ZERO
	var boss_charge_hit: Dictionary = {}
	var boss_target = null

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
	# 回旋镖：飞出一段距离后折返，折返时清空命中表，可以再打一次。
	var boom: bool = false
	var origin := Vector2.ZERO
	var boom_range: float = 420.0
	var boomed: bool = false

class Zone:
	var pos := Vector2.ZERO
	var radius: float = 90.0
	var life: float = 2.6
	var t: float = 0.0
	var slow: float = 0.9
	var team: int = 0
	var color := Color.WHITE
	# 治疗区域：每秒给区域内友军回复最大生命的比例。
	var heal_pct: float = 0.0

class Potion:
	var team: int = 0
	var pos := Vector2.ZERO
	var radius: float = 30.0
	var active := true
	var respawn_t := 0.0
	var view_id: int = 0
	# 守卫塔：本路塔被拆后，这瓶药剂停止刷新（5v5 每路各管各的）。
	var guard = null

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
# 巨兽认定的「逆风方」：出场时锁定，之后只帮这一方；反超后功成身退。
var boss_home_team := -1
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
var lane_paths: Array = []
var river: Array = []
var five_v_five := false
var team_size := 3
var keep_protection := false
var rng := RandomNumberGenerator.new()
var map_w: float = 3000.0
var map_h: float = 1600.0
var sudden_death_time: float = 180.0
# 巨兽出场时间与终极对决解耦：3v3 默认同帧（180s），5v5 由 mode_5v5 覆盖为 240s。
var boss_time: float = 180.0
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
# 等级系统：3v3 保持 2 级封顶零成长；5v5 由 mode_5v5 覆盖为 5 级并逐级成长。
var level_cap := 2
var xp_levels: Array = [110.0]
var hp_per_level := 0.0
var dmg_per_level := 0.0
var skill_per_level := 0.0

var base_cfg: Dictionary = {}
var tower_cfg: Dictionary = {}
var minion_cfg: Dictionary = {}
var comeback_cfg: Dictionary = {}
var potion_cfg: Dictionary = {}
var boss_cfg: Dictionary = {}
var jungle_cfg: Dictionary = {}
var ai_cfg: Dictionary = {}
var targeting_cfg: Dictionary = {}
var combat_cfg: Dictionary = {}

var ai_think_base: float = 0.22
var ai_skill_mul: float = 1.0
var enemy_dmg_mul: float = 1.0
var hitstop_threshold: float = 45.0
var hitstop_duration: float = 0.045

var _uid: int = 0
var _shot_view: int = 0
# 击败峡谷巨兽后，击杀方全员 15 秒伤害提升。
var team_buff_t: Array = [0.0, 0.0]
var _potion_view: int = 0
var pending: Array = []


static func color_of(hex: String, fallback := Color.WHITE) -> Color:
	return Color.from_string(hex.trim_prefix("#"), fallback)


func setup(player_hero: String, difficulty: int, seed_value: int, mode_5v5 := false) -> void:
	load_data()
	rng.seed = seed_value
	five_v_five = mode_5v5
	team_size = 3

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
	boss_home_team = -1
	boss_respawn = 25.0
	_uid = 0
	_shot_view = 0
	team_buff_t = [0.0, 0.0]
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
	boss_time = float(rules.get("boss_time", sudden_death_time))
	match_cap = float(rules.get("match_cap", 285))
	respawn_time = float(rules.get("respawn_time", 5.5))
	base_heal_per_sec = float(rules.get("base_heal_per_sec", 0.15))
	wave_interval = float(rules.get("wave_interval", 18))
	xp_to_level2 = float(rules.get("xp_to_level2", 180))
	xp_levels = [xp_to_level2]
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
	jungle_cfg = rules.get("jungle_stats", {})
	ai_cfg = rules.get("ai", {})
	targeting_cfg = rules.get("targeting", {})
	combat_cfg = rules.get("combat", {})
	boss_respawn = float(boss_cfg.get("respawn", 25.0))
	var hs: Dictionary = rules.get("hitstop", {})
	hitstop_threshold = float(hs.get("threshold", 45))
	hitstop_duration = float(hs.get("duration", 0.045))

	var diff_name := "easy" if difficulty == 0 else "challenge"
	var dcfg: Dictionary = rules.get("difficulty", {}).get(diff_name, {})
	ai_think_base = float(dcfg.get("ai_think", 0.22))
	ai_skill_mul = float(dcfg.get("ai_skill_mul", 1.0))
	enemy_dmg_mul = float(dcfg.get("enemy_dmg_mul", 1.0))

	lane_paths.clear()
	river.clear()
	if five_v_five:
		var mode_cfg: Dictionary = rules.get("mode_5v5", {})
		team_size = int(mode_cfg.get("team_size", 5))
		match_cap = float(mode_cfg.get("match_cap", match_cap))
		sudden_death_time = float(mode_cfg.get("sudden_death_time", sudden_death_time))
		boss_time = float(mode_cfg.get("boss_time", boss_time))
		keep_protection = bool(mode_cfg.get("keep_protection_in_sudden_death", true))
		# 5v5 五级成长：阈值与增幅全部来自 rules.json，便于按节奏调整。
		level_cap = int(mode_cfg.get("level_cap", 5))
		hp_per_level = float(mode_cfg.get("hp_per_level", 0.09))
		dmg_per_level = float(mode_cfg.get("dmg_per_level", 0.08))
		skill_per_level = float(mode_cfg.get("skill_per_level", 0.10))
		xp_levels.clear()
		for t in mode_cfg.get("xp_levels", [110, 280, 520, 840]):
			xp_levels.append(float(t))
		map_w = float(mode_cfg.get("map_w", map_w))
		map_h = float(mode_cfg.get("map_h", map_h))
		for raw_lane in rules.get("lanes_5v5", []):
			var path: Array = []
			for p in raw_lane:
				path.append(Vector2(float(p[0]), float(p[1])))
			lane_paths.append(path)
		if lane_paths.is_empty():
			lane_paths.append([])
		for rp in rules.get("river_5v5", []):
			river.append(Vector2(float(rp[0]), float(rp[1])))
	else:
		team_size = 3
	lane.clear()
	var mid_raw: Array = lane_paths[1] if lane_paths.size() > 1 else rules.get("lane", [])
	for p in mid_raw:
		lane.append(Vector2(float(p[0]), float(p[1])))

	var others: Array = []
	for d in heroes_data:
		var hid := str(d.get("id", ""))
		# 3v3 与 5v5 都开放全部英雄（2026-11-20 起 20 位），只是上场人数不同。
		if hid != player_hero:
			others.append(hid)
	for i in range(others.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = others[i]
		others[i] = others[j]
		others[j] = tmp

	var blue_home := Vector2(230.0, map_h * 0.5)
	var red_home := Vector2(map_w - 230.0, map_h * 0.5)
	if five_v_five:
		var mode_home: Dictionary = rules.get("mode_5v5", {})
		var bb: Array = mode_home.get("base_blue", [360, 2040])
		var rb: Array = mode_home.get("base_red", [2040, 360])
		blue_home = Vector2(float(bb[0]), float(bb[1]))
		red_home = Vector2(float(rb[0]), float(rb[1]))
	base_blue = make_base(BLUE, blue_home)
	base_red = make_base(RED, red_home)
	if five_v_five:
		# 三路各一座外塔；药剂由本路塔守卫，塔没了这一路才停刷。
		for lane_id in range(lane_paths.size()):
			var path: Array = lane_paths[lane_id]
			if path.size() < 6:
				continue
			towers_blue.append(make_tower(BLUE, 0, path[2], lane_id))
			towers_red.append(make_tower(RED, 0, path[4], lane_id))
			make_potion(BLUE, path[1], towers_blue[towers_blue.size() - 1])
			make_potion(RED, path[5], towers_red[towers_red.size() - 1])
		for camp in rules.get("jungle", []):
			var cp = camp.get("pos", [0, 0])
			make_jungle(str(camp.get("kind", "boar")), Vector2(float(cp[0]), float(cp[1])))
	else:
		# 外塔 = 更靠近敌方的一侧，必须先拆；内塔在水晶旁，受外塔保护。
		# 坐标来自 rules.json，3v3 地图加宽时只改数据。
		var t3: Dictionary = rules.get("towers_3v3", {})
		var tb: Array = t3.get("blue", [[800, 800], [1250, 800]])
		var tr: Array = t3.get("red", [[2800, 800], [2350, 800]])
		towers_blue.append(make_tower(BLUE, 0, Vector2(float(tb[1][0]), float(tb[1][1]))))
		towers_blue.append(make_tower(BLUE, 1, Vector2(float(tb[0][0]), float(tb[0][1]))))
		towers_red.append(make_tower(RED, 0, Vector2(float(tr[1][0]), float(tr[1][1]))))
		towers_red.append(make_tower(RED, 1, Vector2(float(tr[0][0]), float(tr[0][1]))))
		# 双方一塔后方各放一瓶回血药剂，踩到即喝，30 秒后重新长出来。
		var p3: Dictionary = rules.get("potion_3v3", {})
		var pb: Array = p3.get("blue", [1150, 800])
		var pr: Array = p3.get("red", [2450, 800])
		make_potion(BLUE, Vector2(float(pb[0]), float(pb[1])), towers_blue[0])
		make_potion(RED, Vector2(float(pr[0]), float(pr[1])), towers_red[0])

	var allies: Array = []
	var red_jungler := ""
	if five_v_five:
		# 保证双方各有一名打野（狼优先、刺猬替补），再按角色桶随机补位。
		if not (player_hero == "wolf" or player_hero == "hedgehog"):
			var jg0: String = take_jungler(others)
			if jg0 != "":
				allies.append(jg0)
		red_jungler = take_jungler(others)
		var rest_allies: Array = pick_allies_5v5(others, team_size - 1 - allies.size())
		for a in rest_allies:
			allies.append(a)
	else:
		var player_front := player_hero == "tiger" or player_hero == "bear" or player_hero == "turtle"
		var ally_prefs := [
			["turtle", "bear", "tiger", "panda"],
			["rabbit", "axolotl", "frog", "cat", "deer", "fox"],
			["hedgehog", "wolf", "cat", "fox", "redpanda", "owl"],
			["deer", "crane", "owl", "frog", "rabbit"],
		]
		if player_front:
			ally_prefs = [
				["deer", "cat", "fox", "rabbit", "axolotl", "frog"],
				["axolotl", "rabbit", "frog", "deer", "fox", "cat"],
				["hedgehog", "wolf", "redpanda", "crane", "owl"],
				["turtle", "panda", "bear", "owl", "crane"],
			]
		for i in range(team_size - 1):
			var prefs: Array = ally_prefs[i % ally_prefs.size()]
			allies.append(take_preferred(others, prefs))

	var blue_ids: Array = [player_hero] + allies
	var red_ids: Array = others
	if five_v_five:
		var red_team: Array = []
		if red_jungler != "":
			red_team.append(red_jungler)
		var rest_red: Array = pick_allies_5v5(others, team_size - red_team.size())
		for r in rest_red:
			red_team.append(r)
		red_ids = red_team
	var lanes_5 := [1, 0, 2, 1, 0]
	if five_v_five:
		var blue_lanes: Array = assign_lanes_5v5(blue_ids, true)
		var red_lanes: Array = assign_lanes_5v5(red_ids, false)
		for i in range(team_size):
			var h = make_hero(str(blue_ids[i]), BLUE, i, int(blue_lanes[i]))
			if i == 0:
				h.is_player = true
				player = h
		for i in range(team_size):
			make_hero(str(red_ids[i]), RED, i, int(red_lanes[i]))
	else:
		for i in range(team_size):
			var lane_id: int = lanes_5[i] if five_v_five else 1
			var h = make_hero(str(blue_ids[i]), BLUE, i, lane_id)
			if i == 0:
				h.is_player = true
				player = h
		for i in range(team_size):
			var lane_id: int = lanes_5[i] if five_v_five else 1
			make_hero(str(red_ids[i]), RED, i, lane_id)

	started = true
	wave_t = 3.0
	if five_v_five:
		banner.emit("三路推进 → 拆掉两座塔，就能进攻敌方水晶！", 3.6)
	else:
		banner.emit("往右走 → 先拆两座蘑菇塔，再点亮敌方水晶！", 3.6)
	print("[SIM] seed=%d player=%s difficulty=%s mode=%s" % [seed_value, player_hero, diff_name, "5v5" if five_v_five else "3v3"])


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


func take_jungler(pool: Array) -> String:
	for cand in ["wolf", "hedgehog"]:
		if pool.has(cand):
			pool.erase(cand)
			return cand
	return ""


func _shuffle_pool(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _take_bucket(pool: Array, bucket: Array, picked: Array, count: int) -> void:
	_shuffle_pool(bucket)
	for id in bucket:
		if picked.size() >= count:
			return
		if pool.has(id):
			pool.erase(id)
			picked.append(id)
			return


func pick_allies_5v5(pool: Array, count: int) -> Array:
	# 角色桶随机组队：1 前排 + 1 辅助优先，其余随机，避免每局阵容雷同。
	var front: Array = []
	var support: Array = []
	var rest: Array = []
	for id in pool:
		var role := str(defs_by_id.get(id, {}).get("role", ""))
		if role == "坦克" or role == "战士":
			front.append(id)
		elif role == "辅助" or role == "控制" or role == "法坦":
			support.append(id)
		else:
			rest.append(id)
	var picked: Array = []
	_take_bucket(pool, front, picked, count)
	_take_bucket(pool, support, picked, count)
	_shuffle_pool(rest)
	for id in rest:
		if picked.size() >= count:
			break
		if pool.has(id):
			pool.erase(id)
			picked.append(id)
	while picked.size() < count and not pool.is_empty():
		var extra: String = str(pool[0])
		pool.remove_at(0)
		picked.append(extra)
	return picked


func assign_lanes_5v5(ids: Array, protect_player: bool) -> Array:
	# 打野位 -2；前排上路、输出下路、其余中路；玩家固定在中间路（除非玩家就是打野）。
	var lanes: Array = []
	for i in range(ids.size()):
		lanes.append(1)
	var jungler := -1
	for i in range(ids.size()):
		if str(defs_by_id.get(str(ids[i]), {}).get("role", "")) == "打野":
			jungler = i
			break
	if jungler < 0:
		for i in range(ids.size()):
			if str(defs_by_id.get(str(ids[i]), {}).get("role", "")) == "刺客":
				jungler = i
				break
	if jungler >= 0:
		lanes[jungler] = -2
	var front := -1
	var damage := -1
	for i in range(ids.size()):
		if i == jungler or (protect_player and i == 0):
			continue
		var role := str(defs_by_id.get(str(ids[i]), {}).get("role", ""))
		if front < 0 and (role == "坦克" or role == "战士"):
			front = i
		elif damage < 0 and (role == "射手" or role == "法师"):
			damage = i
	if front >= 0:
		lanes[front] = 0
	if damage >= 0:
		lanes[damage] = 2
	return lanes


func path_of(lane_id: int) -> Array:
	if five_v_five and lane_id >= 0 and lane_id < lane_paths.size():
		return lane_paths[lane_id]
	return lane


func path_length(path: Array) -> float:
	var total := 0.0
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		total += a.distance_to(b)
	return total


func lane_progress(lane_id: int, p: Vector2) -> float:
	# 点投影到兵线折线上的累计弧长（从蓝方起点算起）。
	var path: Array = path_of(lane_id)
	if path.size() < 2:
		return 0.0
	var acc := 0.0
	var best := 1.0e20
	var best_s := 0.0
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var ab: Vector2 = b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d: float = (a + ab * t).distance_to(p)
		if d < best:
			best = d
			best_s = acc + ab.length() * t
		acc += ab.length()
	return best_s


func point_at_progress(lane_id: int, s: float) -> Vector2:
	var path: Array = path_of(lane_id)
	if path.is_empty():
		return Vector2.ZERO
	var remain := clampf(s, 0.0, path_length(path))
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var seg := a.distance_to(b)
		if remain <= seg:
			return a.lerp(b, clampf(remain / maxf(seg, 0.001), 0.0, 1.0))
		remain -= seg
	return path[path.size() - 1]


func nearest_path_index(lane_id: int, p: Vector2) -> int:
	var path: Array = path_of(lane_id)
	var best := 0
	var bd := 1.0e20
	for i in range(path.size()):
		var wp: Vector2 = path[i]
		var d := wp.distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


func lane_of_front(lane_id: int) -> int:
	return lane_id if five_v_five and lane_id >= 0 else -1


func standoff_point(team: int, t, extra: float) -> Vector2:
	# 塔射程外的等待点：沿兵线退到塔前 range+extra 的位置。
	var lid: int = t.lane_id if five_v_five else -1
	var fp := lane_progress(lid, t.pos)
	var off: float = t.attack_range + extra
	var s := fp - off if team == BLUE else fp + off
	return point_at_progress(lid, s)


func speed_of(u) -> float:
	if u.buff_speed_t > 0.0:
		return u.move_speed * (1.0 + u.buff_speed_pct)
	return u.move_speed


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
	u.hp = float(base_cfg.get("hp_5v5", 2600) if five_v_five else base_cfg.get("hp", 3000))
	u.max_hp = u.hp
	u.radius = float(base_cfg.get("radius", 90))
	u.height = float(base_cfg.get("height", 150))
	u.attack_range = float(base_cfg.get("range_5v5", 360) if five_v_five else base_cfg.get("range", 400))
	u.dmg = float(base_cfg.get("dmg_5v5", 90) if five_v_five else base_cfg.get("dmg", 120))
	u.atk_interval = float(base_cfg.get("atk_interval", 1.0))
	u.atk_timer = 1.0
	u.level = 0
	u.lane_id = 1
	return u


func make_tower(team: int, tier: int, pos: Vector2, lane_id := 1):
	var u = new_unit(TOWER, team, "外塔" if tier == 0 else "内塔", pos)
	u.lane_id = lane_id
	u.hp = float(tower_cfg.get("hp_5v5", 2600) if five_v_five else tower_cfg.get("hp", 4200))
	u.max_hp = u.hp
	u.radius = float(tower_cfg.get("radius", 58))
	u.height = float(tower_cfg.get("height", 140))
	u.attack_range = float(tower_cfg.get("range", 350))
	u.dmg = float(tower_cfg.get("dmg_5v5", 82) if five_v_five else tower_cfg.get("dmg", 100))
	u.atk_interval = float(tower_cfg.get("atk_interval", 1.0))
	u.atk_timer = rng.randf_range(0.0, 1.0)
	u.level = tier
	return u


func make_jungle(kind: String, pos: Vector2):
	var names := {"boar": "森林野猪", "wolf": "灰狼", "crab": "河蟹"}
	var u = new_unit(JUNGLE, NEUTRAL, str(names.get(kind, "野怪")), pos)
	u.jungle_kind = kind
	u.lane_id = -1
	u.respawn_home = pos
	u.max_hp = float(jungle_cfg.get("hp", 650))
	u.hp = u.max_hp
	u.radius = 30.0
	u.height = 48.0
	u.attack_range = float(jungle_cfg.get("range", 110))
	u.dmg = float(jungle_cfg.get("dmg", 36))
	u.atk_interval = float(jungle_cfg.get("atk_interval", 1.1))
	u.atk_timer = rng.randf_range(0.2, 0.8)
	u.move_speed = 0.0
	return u


func respawn_jungle(u) -> void:
	u.hp = u.max_hp
	u.pos = u.respawn_home
	u.prev_pos = u.pos
	u.face_dir = Vector2.ZERO
	u.stun_t = 0.0
	u.slow_t = 0.0
	u.mark_t = 0.0
	u.fear_t = 0.0
	u.taunt_t = 0.0
	u.spin_t = 0.0
	u.buff_dmg_t = 0.0
	u.buff_speed_t = 0.0
	u.atk_timer = 0.6


func _apply_jungle_buff(h, buff: Dictionary) -> void:
	var dur := float(buff.get("duration", 15.0))
	if buff.has("dmg_pct"):
		h.buff_dmg_pct = float(buff.get("dmg_pct", 0.0))
		h.buff_dmg_t = dur
	if buff.has("speed_pct"):
		h.buff_speed_pct = float(buff.get("speed_pct", 0.0))
		h.buff_speed_t = dur
	float_text.emit(Vector3(h.pos.x, h.height + 30.0, h.pos.y),
		str(buff.get("label", "野区增益")), Color(1.0, 0.93, 0.55))


func step_jungle(u, dt: float) -> void:
	var foe = nearest_enemy(u, u.attack_range + 30.0)
	if foe == null:
		u.moving = false
		return
	u.moving = false
	u.facing = 1.0 if foe.pos.x >= u.pos.x else -1.0
	u.face_dir = (foe.pos - u.pos).normalized()
	if u.atk_timer <= 0.0:
		u.atk_timer = u.atk_interval
		u.atk_anim = 0.25
		hit_with_fx(foe, u.dmg, u, 0.0)


func make_potion(team: int, pos: Vector2, guard = null):
	var p = Potion.new()
	p.team = team
	p.pos = pos
	p.radius = float(potion_cfg.get("radius", 30))
	p.guard = guard
	p.view_id = _potion_view
	_potion_view += 1
	potions.append(p)
	return p


func step_potions(dt: float) -> void:
	# 回血药剂：本路塔被拆后不再刷新；满血英雄路过不会拿走。
	var heal_pct := float(potion_cfg.get("heal_pct", 0.35))
	var respawn := float(potion_cfg.get("respawn", 30.0))
	for p in potions:
		var guard = p.guard
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
			sfx.emit("pickup", p.pos)
			break


func standing_team() -> int:
	# 谁领先（巨兽判定用）：塔血总量 → 水晶血量比例 → 比分；完全打平时返回 -1。
	# 5v5 里「水晶满血但三座塔全掉」的一方其实在挨打，塔的权重必须在水晶之前。
	var bt := 0.0
	for t in towers_blue:
		bt += maxf(t.hp, 0.0) / t.max_hp
	var rt := 0.0
	for t in towers_red:
		rt += maxf(t.hp, 0.0) / t.max_hp
	if absf(bt - rt) >= 0.01:
		return BLUE if bt > rt else RED
	var b: float = base_blue.hp / base_blue.max_hp
	var r: float = base_red.hp / base_red.max_hp
	if absf(b - r) >= 0.01:
		return BLUE if b > r else RED
	if score_blue != score_red:
		return BLUE if score_blue > score_red else RED
	return -1


func leading_team() -> int:
	var s := standing_team()
	return BLUE if s < 0 else s


func trailing_team() -> int:
	# 逆风守护兽：巨兽只帮落后方；完全打平时站蓝方（玩家侧）。
	var s := standing_team()
	return BLUE if s < 0 else 1 - s


func is_trailing_team(team: int) -> bool:
	var s := standing_team()
	return s >= 0 and s != team


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
	u.cds = [3.0, 6.0, 9.0]
	u.boss_phase = 1
	u.boss_flying = false
	u.boss_skill = ""
	u.boss_cast_t = 0.0
	u.boss_charge_t = 0.0
	u.boss_charge_hit.clear()
	u.boss_target = null
	if five_v_five:
		# 5v5 巨兽从河道中央加入战场，只推中路。
		var mid_len := path_length(path_of(1))
		u.pos = point_at_progress(1, mid_len * 0.5 + (180.0 if team == BLUE else -180.0))
		u.prev_pos = u.pos
		u.lane_index = nearest_path_index(1, u.pos)
	else:
		u.lane_index = 0 if team == BLUE else lane.size() - 1
	boss = u
	boss_team = team
	boss_home_team = team
	if boss_time < sudden_death_time - 0.01:
		# 5v5：巨兽 4:00 先出场，终极对决 5:00 只是状态切换。
		banner.emit("峡谷巨兽出现！加入%s（只帮落后的一方）" % ("蓝方" if team == BLUE else "红方"), 4.2)
	else:
		banner.emit("终极对决！巨兽加入%s（只帮落后的一方）" % ("蓝方" if team == BLUE else "红方"), 4.2)
	sfx.emit("ult", u.pos)
	fx.emit("cast_quake", Vector3(u.pos.x, 20.0, u.pos.y), _team_color(team), 200.0)


func respawn_boss(u) -> void:
	# 逆风守护兽：只帮出场时锁定的落后方，击杀后 25 秒回到同一方；反超也不换边。
	var home_team: int = boss_home_team if boss_home_team >= 0 else u.team
	u.team = home_team
	boss_team = home_team
	var home = base_blue if u.team == BLUE else base_red
	if home == null or not home.is_alive():
		return
	u.hp = u.max_hp
	if five_v_five:
		var mid_len := path_length(path_of(1))
		u.pos = point_at_progress(1, mid_len * 0.5 + (180.0 if u.team == BLUE else -180.0))
		u.lane_index = nearest_path_index(1, u.pos)
	else:
		u.pos = home.pos + Vector2(190.0 if u.team == BLUE else -190.0, 0.0)
	u.prev_pos = u.pos
	u.face_dir = (base_pos(1 - u.team) - u.pos).normalized()
	u.invuln_t = 1.0
	u.stun_t = 0.0
	u.slow_t = 0.0
	u.shield = 0.0
	u.atk_timer = 0.4
	u.cds = [3.0, 6.0, 9.0]
	u.boss_phase = mini(2, u.boss_phase + 1)
	u.boss_flying = u.boss_phase >= 2
	u.boss_skill = ""
	u.boss_cast_t = 0.0
	u.boss_charge_t = 0.0
	u.boss_charge_hit.clear()
	u.boss_target = null
	banner.emit("峡谷巨兽展开翅膀，飞回战场！" if u.boss_flying else "峡谷巨兽再次出发！", 2.8)
	fx.emit("cast_quake", Vector3(u.pos.x, 20.0, u.pos.y), _team_color(u.team), 180.0)


func step_boss(u, dt: float) -> void:
	if u.stun_t > 0.0:
		return

	# 技能前摇：站定蓄力，结束后统一结算。
	if u.boss_cast_t > 0.0:
		u.boss_cast_t = maxf(0.0, u.boss_cast_t - dt)
		u.moving = false
		if u.boss_cast_t <= 0.0:
			_resolve_boss_cast(u)
		return

	# 冲撞进行中：沿朝向高速推进，撞到谁算谁。
	if u.boss_charge_t > 0.0:
		_step_boss_charge(u, dt)
		return

	var skills: Dictionary = boss_cfg.get("skills_flying" if u.boss_flying else "skills", {})
	var first: Dictionary = skills.get("meteor" if u.boss_flying else "slam", {})
	var second: Dictionary = skills.get("cyclone" if u.boss_flying else "roar", {})
	var charge: Dictionary = skills.get("charge", {})

	if u.boss_flying:
		# 飞行形态：陨石砸向最近的英雄/前塔，旋风清空身边。
		if u.cds[0] <= 0.0:
			var meteor_target = nearest_enemy_unit(u, float(first.get("range", 650.0)))
			if meteor_target != null:
				_begin_boss_cast(u, "meteor", first, 0, meteor_target)
				return
		if u.cds[1] <= 0.0 and count_enemy_units_near(u, float(second.get("radius", 300.0))) > 0:
			_begin_boss_cast(u, "cyclone", second, 1)
			return
		# 不再在这里「向前塔移动并 return」：那会让巨兽从路径敌人头顶飞过去。
		# 飞行形态与地面形态共用下面的选敌/普攻/推塔逻辑。
	else:
		# 地面形态：裂地重击 / 咆哮 / 冲撞。
		if u.cds[0] <= 0.0 and count_enemy_units_near(u, float(first.get("radius", 250.0))) > 0:
			_begin_boss_cast(u, "slam", first, 0)
			return
		if u.cds[1] <= 0.0 and count_enemy_units_near(u, float(second.get("radius", 330.0))) > 0:
			_begin_boss_cast(u, "roar", second, 1)
			return
		var front = front_structure(u.team, 1 if five_v_five else -1)
		if u.cds[2] <= 0.0 and front != null and front.is_alive():
			var fd: float = u.pos.distance_to(front.pos)
			if fd >= float(charge.get("min_range", 260.0)) and fd <= float(charge.get("range", 620.0)):
				_begin_boss_cast(u, "charge", charge, 2, front)
				return
	var front = front_structure(u.team, 1 if five_v_five else -1)

	# 其余时间保持原来的普攻推进。
	var target = nearest_enemy(u, u.attack_range + 90.0)
	if target != null and u.pos.distance_to(target.pos) <= u.attack_range + target.radius:
		u.moving = false
		u.facing = 1.0 if target.pos.x >= u.pos.x else -1.0
		u.face_dir = (target.pos - u.pos).normalized()
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
	_move_along_lane(u, dt, 0.92)


func _move_along_lane(u, dt: float, speed_k: float) -> void:
	# 沿兵线折线推进：巨兽在 5v5 只走中路，3v3 走单路。
	var lid := 1 if five_v_five else -1
	var path: Array = path_of(lid)
	if path.is_empty():
		u.moving = false
		return
	var idx := clampi(u.lane_index, 0, path.size() - 1)
	var dir_step := 1 if u.team == BLUE else -1
	var goal: Vector2 = path[idx]
	for guard in range(path.size()):
		if goal.distance_to(u.pos) > 90.0:
			break
		var next_idx := idx + dir_step
		if next_idx < 0 or next_idx >= path.size():
			break
		idx = next_idx
		goal = path[idx]
	u.lane_index = idx
	var to: Vector2 = goal - u.pos
	if to.length() < 8.0:
		u.moving = false
		return
	move_ai(u, to, dt, speed_k)


func count_enemy_units_near(from, radius: float) -> int:
	var n := 0
	for o in units:
		if not o.is_alive() or o.team == from.team:
			continue
		if o.kind != HERO and o.kind != MINION:
			continue
		if from.pos.distance_to(o.pos) <= radius + o.radius:
			n += 1
	return n


func nearest_enemy_unit(from, radius: float):
	var best = null
	var bd := radius
	for o in units:
		if not o.is_alive() or o.team == from.team:
			continue
		if o.kind != HERO and o.kind != MINION:
			continue
		var d: float = from.pos.distance_to(o.pos)
		if d <= bd:
			bd = d
			best = o
	return best


func _begin_boss_cast(u, kind: String, cfg: Dictionary, index: int, target = null) -> void:
	u.boss_skill = kind
	u.boss_target = target
	if target != null:
		u.face_dir = (target.pos - u.pos).normalized()
	var windup := float(cfg.get("windup", 0.6))
	u.boss_cast_t = windup
	u.cast_anim = windup
	u.moving = false
	u.cds[index] = float(cfg.get("cd", 8.0))

	var col := _team_color(u.team)
	var label := "裂地重击！"
	var style := "quake"
	var telegraph := float(cfg.get("radius", 250.0)) * 0.72
	if kind == "roar":
		label = "巨兽咆哮！"
		style = "roar"
		telegraph = float(cfg.get("radius", 330.0)) * 0.75
	elif kind == "meteor":
		label = "陨石坠落！"
		style = "starfall_ult"
		telegraph = float(cfg.get("radius", 260.0)) * 0.9
	elif kind == "cyclone":
		label = "旋风横扫！"
		style = "clawstorm"
		telegraph = float(cfg.get("radius", 300.0)) * 0.8
	elif kind == "charge":
		label = "野蛮冲撞！"
		telegraph = 90.0
	if target != null and target.is_alive():
		u.facing = 1.0 if target.pos.x >= u.pos.x else -1.0
	else:
		var foe = nearest_enemy_unit(u, 420.0)
		if foe != null:
			u.facing = 1.0 if foe.pos.x >= u.pos.x else -1.0
	float_text.emit(Vector3(u.pos.x, u.height + 34.0, u.pos.y), label, col)
	fx.emit("cast_" + style, Vector3(u.pos.x, 20.0, u.pos.y), col, telegraph)
	fx.emit("ring", Vector3(u.pos.x, 6.0, u.pos.y), col, telegraph)
	sfx.emit("boom" if kind == "slam" else "ult", u.pos)


func _resolve_boss_cast(u) -> void:
	var kind: String = str(u.boss_skill)
	var skills: Dictionary = boss_cfg.get("skills_flying" if u.boss_flying else "skills", {})
	var cfg: Dictionary = skills.get(kind, {})
	var col := _team_color(u.team)
	u.cast_anim = 0.0
	u.moving = false

	match kind:
		"slam":
			var radius := float(cfg.get("radius", 250.0))
			area_damage(u.pos, radius, float(cfg.get("dmg", 150.0)), u, u.team, 0.0,
				float(cfg.get("stun", 0.35)), float(cfg.get("knock", 45.0)), true)
			fx.emit("cast_quake", Vector3(u.pos.x, 20.0, u.pos.y), col, radius)
			fx.emit("ring", Vector3(u.pos.x, 6.0, u.pos.y), col, radius)
			fx.emit("debris", Vector3(u.pos.x, 24.0, u.pos.y), col, radius)
			sfx.emit("boom", u.pos)
		"roar":
			var radius := float(cfg.get("radius", 330.0))
			for o in units:
				if not o.is_alive() or o.team == u.team:
					continue
				if o.kind != HERO and o.kind != MINION:
					continue
				if u.pos.distance_to(o.pos) > radius + o.radius:
					continue
				deal_damage(o, float(cfg.get("dmg", 55.0)), u)
				o.slow_t = maxf(o.slow_t, float(cfg.get("slow", 1.8)))
			u.shield = maxf(u.shield, u.max_hp * float(cfg.get("shield_pct", 0.10)))
			u.shield_t = maxf(u.shield_t, float(cfg.get("shield_time", 5.0)))
			for a in units:
				if a.team == u.team and a.kind == MINION and a.is_alive() \
						and u.pos.distance_to(a.pos) <= radius + a.radius:
					a.hp = minf(a.max_hp, a.hp + a.max_hp * 0.10)
			fx.emit("cast_roar", Vector3(u.pos.x, 20.0, u.pos.y), col, radius)
			fx.emit("ring", Vector3(u.pos.x, 6.0, u.pos.y), col, radius)
			sfx.emit("ult", u.pos)
		"meteor":
			var radius := float(cfg.get("radius", 260.0))
			var center: Vector2 = u.pos + Vector2(u.facing, 0.0) * 220.0
			if u.boss_target != null and u.boss_target.is_alive():
				center = u.boss_target.pos
			area_damage(center, radius, float(cfg.get("dmg", 220.0)), u, u.team,
				float(cfg.get("slow", 1.2)), 0.0, 30.0)
			fx.emit("cast_starfall_ult", Vector3(center.x, 20.0, center.y), col, radius)
			fx.emit("ring", Vector3(center.x, 6.0, center.y), col, radius)
			fx.emit("debris", Vector3(center.x, 30.0, center.y), col, radius)
			sfx.emit("boom", center)
		"cyclone":
			var radius := float(cfg.get("radius", 300.0))
			area_damage(u.pos, radius, float(cfg.get("dmg", 130.0)), u, u.team,
				float(cfg.get("slow", 1.5)), 0.0, float(cfg.get("knock", 60.0)))
			fx.emit("cast_clawstorm", Vector3(u.pos.x, 20.0, u.pos.y), col, radius)
			fx.emit("ring", Vector3(u.pos.x, 6.0, u.pos.y), col, radius)
			sfx.emit("ult", u.pos)
		"charge":
			var dur := float(cfg.get("duration", 0.5))
			u.boss_charge_t = dur
			u.boss_charge_hit.clear()
			var dir := Vector2(u.facing, 0.0)
			if u.boss_target != null and u.boss_target.is_alive():
				var to: Vector2 = u.boss_target.pos - u.pos
				if to.length_squared() > 0.01:
					dir = to.normalized()
			u.boss_charge_dir = dir
			u.boss_skill = ""
			return

	u.boss_skill = ""
	u.boss_target = null


func _step_boss_charge(u, dt: float) -> void:
	var cfg: Dictionary = boss_cfg.get("skills", {}).get("charge", {})
	u.boss_charge_t = maxf(0.0, u.boss_charge_t - dt)
	u.moving = true
	u.walk_t += dt
	u.facing = 1.0 if u.boss_charge_dir.x >= 0.0 else -1.0
	u.face_dir = u.boss_charge_dir.normalized()
	var speed := float(cfg.get("speed", 700.0))
	var dmg := float(cfg.get("dmg", 120.0))
	var stun := float(cfg.get("stun", 0.25))
	var knock := float(cfg.get("knock", 50.0))
	var struct_mul := float(boss_cfg.get("structure_damage_mul", 1.6))
	move_to(u, u.pos + u.boss_charge_dir * speed * dt)

	for o in units:
		if not o.is_alive() or o.team == u.team:
			continue
		if u.boss_charge_hit.has(o.uid):
			continue
		if u.pos.distance_to(o.pos) > u.radius + o.radius + 32.0:
			continue
		var amount := dmg * (struct_mul if (o.kind == TOWER or o.kind == BASE) else 1.0)
		hit_with_fx(o, amount, u, stun)
		if knock > 0.0 and o.kind != TOWER and o.kind != BASE:
			move_to(o, o.pos + u.boss_charge_dir * knock)
		u.boss_charge_hit[o.uid] = true

	if u.boss_target != null and u.boss_target.is_alive() \
			and u.pos.distance_to(u.boss_target.pos) <= u.radius + u.boss_target.radius + 50.0:
		u.boss_charge_t = 0.0

	if u.boss_charge_t <= 0.0:
		u.boss_charge_t = 0.0
		u.moving = false
		u.boss_target = null
		fx.emit("ring", Vector3(u.pos.x, 6.0, u.pos.y), _team_color(u.team), 90.0)


func make_hero(id: String, team: int, slot: int, lane_id := 1):
	var d: Dictionary = defs_by_id.get(id, heroes_data[0])
	var spawn := base_pos(team) + Vector2(150.0 if team == BLUE else -150.0, float(slot - 1) * 70.0)
	if five_v_five and lane_id >= 0 and lane_paths.size() > lane_id:
		var path: Array = lane_paths[lane_id]
		if path.size() > 0:
			spawn = path[0] if team == BLUE else path[path.size() - 1]
			spawn += Vector2(0.0, float(slot % 2) * 32.0 - 16.0)
	var u = new_unit(HERO, team, str(d.get("name", id)), spawn)
	u.lane_id = lane_id
	u.is_jungler = five_v_five and lane_id == -2
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
		# 3v3 巨兽与终极对决同帧，播报合并到 spawn_boss 里只出一条，避免横幅叠字；
		# 5v5 巨兽 4:00 先出场，终极对决 5:00 只切状态（HUD 常驻提示），不再发横幅。
		sfx.emit("ult", Vector2.INF)
	if not boss_spawned and clock >= boss_time:
		boss_spawned = true
		spawn_boss(trailing_team())
	if not warned_45 and clock >= match_cap - 45.0:
		warned_45 = true
		final_push = true
		banner.emit("最后 45 秒！防御塔停火，兵线加速", 3.2)
	if not warned_15 and clock >= match_cap - 15.0:
		warned_15 = true
		banner.emit("最后 15 秒！", 2.4)

	# 最后 45 秒兵线加速，让「终极对决」真的能打出结果，而不是干等时间到。
	var wave_gap := wave_interval
	if clock >= match_cap - 45.0:
		wave_gap = maxf(8.0, wave_interval * 0.5)
	wave_t -= dt
	if wave_t <= 0.0:
		wave_t = wave_gap
		spawn_wave(BLUE)
		spawn_wave(RED)

	for i in range(units.size()):
		step_unit(units[i], dt)
	soft_separate_minions()
	for h in heroes:
		if h.is_alive():
			add_xp(h, xp_passive_per_sec * dt)

	step_pending(dt)
	step_potions(dt)
	team_buff_t[BLUE] = maxf(0.0, float(team_buff_t[BLUE]) - dt)
	team_buff_t[RED] = maxf(0.0, float(team_buff_t[RED]) - dt)

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
	if five_v_five:
		for lane_id in range(lane_paths.size()):
			spawn_wave_lane(team, lane_id)
	else:
		spawn_wave_lane(team, 1)


func spawn_wave_lane(team: int, lane_id: int) -> void:
	var path: Array = lane_paths[lane_id] if five_v_five and lane_id < lane_paths.size() else lane
	if path.is_empty():
		return
	var origin: Vector2 = path[0] if team == BLUE else path[path.size() - 1]
	var count := int(minion_cfg.get("count", 3))
	for k in range(count):
		var m = new_unit(MINION, team, "小果冻", origin + Vector2(0.0, float(k - (count - 1) * 0.5) * 38.0))
		m.lane_id = lane_id
		m.hp = float(minion_cfg.get("hp", 280))
		m.max_hp = m.hp
		m.radius = float(minion_cfg.get("radius", 20))
		m.height = float(minion_cfg.get("height", 46))
		m.attack_range = float(minion_cfg.get("range", 118))
		m.dmg = float(minion_cfg.get("dmg", 22))
		m.atk_interval = float(minion_cfg.get("atk_interval", 0.9))
		m.atk_timer = rng.randf_range(0.0, 0.6)
		m.move_speed = float(minion_cfg.get("move_speed", 176))
		m.lane_index = 1 if team == BLUE else path.size() - 2
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
	u.mark_t = maxf(0.0, u.mark_t - dt)
	u.fear_t = maxf(0.0, u.fear_t - dt)
	u.taunt_t = maxf(0.0, u.taunt_t - dt)
	u.buff_dmg_t = maxf(0.0, u.buff_dmg_t - dt)
	u.buff_speed_t = maxf(0.0, u.buff_speed_t - dt)
	u.ambush_t = maxf(0.0, u.ambush_t - dt)
	u.jungle_gank_t = maxf(0.0, u.jungle_gank_t - dt)
	if u.vanish_t > 0.0:
		u.vanish_t = maxf(0.0, u.vanish_t - dt)
		if u.vanish_t <= 0.0 and u.kind == HERO and u.ambush_pending > 0.0:
			u.ambush_t = maxf(u.ambush_t, u.ambush_pending)
			u.ambush_pending = 0.0
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
		elif u.kind == JUNGLE:
			u.die_t += dt
			u.respawn_t -= dt
			if u.respawn_t <= 0.0:
				respawn_jungle(u)
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
	elif u.kind == JUNGLE:
		step_jungle(u, dt)
	else:
		step_structure(u)


func step_hero(h, dt: float) -> void:
	_step_spin(h, dt)
	if h.move_skill_t > 0.0:
		_step_move_skill(h, dt)
		return
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
			# 挥砍/施法期间保持面向目标或施法方向，动作结束再回到移动方向，避免朝向抖动。
			if h.atk_anim <= 0.0 and h.cast_anim <= 0.0:
				h.face_dir = dir
			h.facing = 1.0 if dir.x >= 0.0 else -1.0
			var speed_k := 1.0 if h.fear_t > 0.0 else (0.55 if h.slow_t > 0.0 else 1.0)
			move_to(h, h.pos + dir * (speed_of(h) * speed_k * dt))
			h.walk_t += dt
	else:
		step_hero_ai(h, dt)

	# 恐惧期间不能普攻：被吓到只会抱头跑，先拉开距离。
	if h.fear_t > 0.0:
		return
	# 普攻按王者式优先级选目标：英雄 > 残血单位 > 建筑；远程弹道追踪目标。
	var target = pick_attack_target(h)
	if target != null and h.atk_timer <= 0.0:
		h.atk_timer = h.atk_interval
		h.atk_anim = 0.34
		h.facing = 1.0 if target.pos.x >= h.pos.x else -1.0
		h.face_dir = (target.pos - h.pos).normalized()
		if h.attack_range > 250.0:
			shoot(h, target.pos - h.pos, h.dmg, h.accent, 700.0, 0.0, 0.0, 0.0, 0,
				true, target, hero_shot_style(h.hero_id))
		else:
			hit_with_fx(target, h.dmg, h, 0.0)


func _start_move_skill(h, to: Vector2, duration: float, kind: String, data: Dictionary) -> void:
	to.x = clampf(to.x, 60.0, map_w - 60.0)
	to.y = clampf(to.y, 60.0, map_h - 60.0)
	h.move_skill_from = h.pos
	h.move_skill_to = to
	h.move_skill_total = maxf(duration, 0.05)
	h.move_skill_t = h.move_skill_total
	h.move_skill_kind = kind
	h.move_skill_data = data
	h.moving = true
	h.dash_t = maxf(h.dash_t, h.move_skill_total + 0.08)
	h.invuln_t = maxf(h.invuln_t, 0.12)


func _step_move_skill(h, dt: float) -> void:
	var k := 1.0 - clampf(h.move_skill_t / h.move_skill_total, 0.0, 1.0)
	move_to(h, h.move_skill_from.lerp(h.move_skill_to, k))
	h.walk_t += dt
	h.moving = true
	if h.move_skill_kind == "backstep":
		h.facing = float(h.move_skill_data.get("face", h.facing))
	else:
		var d: Vector2 = h.move_skill_to - h.move_skill_from
		if absf(d.x) > 0.1:
			h.facing = 1.0 if d.x >= 0.0 else -1.0
	h.move_skill_t = maxf(0.0, h.move_skill_t - dt)
	if h.move_skill_t > 0.0:
		return
	var kind: String = str(h.move_skill_kind)
	var data: Dictionary = h.move_skill_data
	h.move_skill_t = 0.0
	h.move_skill_total = 0.0
	h.move_skill_kind = ""
	h.move_skill_data = {}
	h.moving = false
	_finish_move_skill(h, kind, data)


func _finish_move_skill(h, kind: String, data: Dictionary) -> void:
	var s: Dictionary = data.get("skill", {})
	var color: Color = data.get("color", Color.WHITE)
	match kind:
		"dash":
			var dmg := float(s.get("dmg", 0.0)) * skill_power(h)
			var radius := float(s.get("radius", 120.0))
			if dmg > 0.0:
				area_damage(h.pos, radius, dmg, h, h.team,
					float(s.get("slow", 0.0)), 0.0, float(s.get("knock", 0.0)))
				fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), color, radius)
			if s.get("zone", false):
				zones.append(make_zone(h.pos, 90.0, 2.6, float(s.get("slow", 0.9)), h.team, color))
			fx.emit("burst", Vector3(h.pos.x, 24.0, h.pos.y), color, 0.0)
		"leap":
			leap_land(h, h.pos, s)
		"backstep":
			var foe = data.get("foe")
			var dir := Vector2(h.facing, 0.0)
			if foe != null and foe.is_alive():
				dir = (foe.pos - h.pos).normalized()
			var count := int(maxf(1.0, float(s.get("count", 3))))
			for i in range(count):
				var ang := atan2(dir.y, dir.x) + (float(i) - float(count - 1) * 0.5) * 0.16
				shoot(h, Vector2(cos(ang), sin(ang)), float(s.get("dmg", 0.0)) * skill_power(h), color,
					float(s.get("speed", 700.0)), float(s.get("slow", 0.0)), 0.0, 0.0,
					int(s.get("pierce", 0)), false, null, str(s.get("shot_style", "arrow")))
			fx.emit("burst", Vector3(h.pos.x, 24.0, h.pos.y), color, 0.0)


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
		"axolotl":
			return "bubble"
		"deer":
			return "arrow"
		"hedgehog":
			return "arrow"
		"crane":
			return "feather"
	return "cube"


func _step_spin(h, dt: float) -> void:
	# 刺猬滚成刺球：持续 2.4 秒，每隔一小段时间对周围敌人造成一次伤害。
	if h.spin_t <= 0.0:
		return
	h.spin_t = maxf(0.0, h.spin_t - dt)
	h.spin_tick -= dt
	if h.spin_tick > 0.0:
		return
	h.spin_tick = float(combat_cfg.get("spin_tick", 0.30))
	area_damage(h.pos, h.spin_radius, h.spin_dmg, h, h.team,
		float(combat_cfg.get("spin_slow", 0.35)), 0.0,
		float(combat_cfg.get("spin_knock", 6.0)), true)
	fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), h.spin_color, h.spin_radius)
	fx.emit("burst", Vector3(h.pos.x, 26.0, h.pos.y), h.spin_color, 0.0)


func step_hero_ai(h, dt: float) -> void:
	var hp_p: float = h.hp / h.max_hp
	# 恐惧：被猛狮吼到后短暂往远离施法者的方向跑。
	if h.fear_t > 0.0 and h.fear_src != null and h.fear_src.is_alive():
		var away_f: Vector2 = h.pos - h.fear_src.pos
		if away_f.length_squared() > 0.01:
			move_ai(h, away_f, dt, float(combat_cfg.get("fear_speed", 1.15)))
			h.facing = 1.0 if away_f.x >= 0.0 else -1.0
			return
	if five_v_five and not h.is_jungler:
		# 本路塔拆完后，AI 自动换到还有塔的路，避免围着已保护的水晶空站。
		var lane_front = front_structure(h.team, h.lane_id)
		if lane_front != null and lane_front.kind == BASE and is_base_protected(lane_front):
			for l in range(mini(3, lane_paths.size())):
				var cand = front_structure(h.team, l)
				if cand != null and cand.kind == TOWER and cand.is_alive():
					h.lane_id = l
					h.ai_target = null
					break
	var foe_heroes := count_team_heroes(1 - h.team, h.pos, 460.0)
	var ally_heroes := count_team_heroes(h.team, h.pos, 460.0)
	var enemy_near := enemy_hero_near(h, 430.0)
	var retreat_hp := float(ai_cfg.get("retreat_hp", 0.24))
	var retreat_enemy_hp := float(ai_cfg.get("retreat_with_enemy_hp", 0.40))
	var outnumbered_hp := float(ai_cfg.get("outnumbered_hp", 0.56))
	var retreat_enter: bool = hp_p < retreat_hp 		or (hp_p < retreat_enemy_hp and enemy_near and not has_healer_near(h, 380.0)) 		or (hp_p < outnumbered_hp and foe_heroes >= ally_heroes + 2)
	# 撤退带粘滞：一旦开始至少 1.2 秒；之后要血量回到 0.55 以上且不再被包夹才解除。
	# 早期 AI 会在“撤退/推进”阈值上每帧翻转，模型表现为原地转圈。
	if h.retreat_t > 0.0:
		h.retreat_t -= dt
		var safe_back: bool = hp_p > float(ai_cfg.get("retreat_exit_hp", 0.55)) 			and foe_heroes < ally_heroes + 2
		if safe_back:
			h.retreat_t = 0.0
		else:
			h.retreat_t = maxf(h.retreat_t, 0.5)
	elif retreat_enter:
		h.retreat_t = 1.2
	var retreat: bool = h.retreat_t > 0.0

	h.ai_think -= dt
	var think: bool = h.ai_think <= 0.0
	if think:
		h.ai_think = ai_think_base + float(h.uid % 5) * 0.025
	# 每次决策都重新打分，避免锁定一座塔后一路无视路上的兵和英雄。
	if think or h.ai_target == null or not h.ai_target.is_alive():
		h.ai_target = ai_target(h)
	# 嘲讽：潮汐守卫举盾时，附近敌人暂时只能打它。
	var taunted: bool = h.taunt_t > 0.0 and h.taunt_src != null and h.taunt_src.is_alive()
	if taunted:
		h.ai_target = h.taunt_src
		retreat = false
	# 打野位：前 60 秒刷野，二级后周期性去最吃紧的一路 gank 20 秒。
	if h.is_jungler and not taunted:
		if h.jungle_gank_t > 0.0:
			h.lane_id = h.jungle_gank_lane
		else:
			h.lane_id = -2
			var gank_ready: bool = h.level >= 2 and clock >= float(combat_cfg.get("jungle_gank_at", 60.0))
			if gank_ready and not retreat:
				h.jungle_gank_lane = _pick_gank_lane(h)
				h.jungle_gank_t = float(combat_cfg.get("jungle_gank_time", 20.0))
				h.lane_id = h.jungle_gank_lane
			elif not retreat:
				# 刷野阶段不放位移/突进技能，避免被残留的线上目标拽出野区。
				if _step_jungler_ai(h, dt):
					return
	var t = h.ai_target
	var front = front_structure(h.team, lane_of_front(h.lane_id))
	# 锁定目标后仍可能一路追到塔后；追击途中也要受前塔限制。
	if t != null and t != front and front != null and front.kind == TOWER and front.is_alive():
		if _crossed_front(h, t, front):
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
		# 没有可打目标时，先等兵线；近战没兵不要空手越塔。
		if front != null and front.is_alive():
			if front.kind == TOWER and not tower_safe_for(h, front):
				var stand: Vector2 = standoff_point(h.team, front, float(ai_cfg.get("tower_standoff", 100.0)))
				if h.pos.distance_to(stand) > 45.0:
					move_ai(h, stand - h.pos, dt, 0.85)
				else:
					h.moving = false
			else:
				move_ai(h, front.pos - h.pos, dt, 0.9)
		else:
			h.moving = false
		return

	# 近战无兵不越塔：站在塔射程外等下一波兵；远程能点塔时照常输出。
	if t.kind == TOWER and not tower_safe_for(h, t):
		var stand: Vector2 = standoff_point(h.team, t, float(ai_cfg.get("tower_standoff", 100.0)))
		if h.pos.distance_to(stand) > 45.0:
			move_ai(h, stand - h.pos, dt, 0.85)
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
			# 射程甜区站定输出：早期沿目标切向侧移会无限绕圈。
			h.moving = false
	else:
		var keep: float = minf(h.attack_range * 0.84, h.radius + t.radius + 14.0)
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
	if h.atk_anim <= 0.0 and h.cast_anim <= 0.0:
		h.face_dir = dir
	h.moving = true
	var slow_k := 1.0 if h.fear_t > 0.0 else (0.55 if h.slow_t > 0.0 else 1.0)
	move_to(h, h.pos + dir * (speed_of(h) * speed_k * slow_k * dt))
	h.walk_t += dt


func step_hero_skills(h, hp_p: float, retreat: bool) -> void:
	# 施法动作期间不再连放：0.5/1.2 秒的动作要能完整看见。
	if h.cast_anim > 0.0:
		return
	for i in range(3):
		var s: Dictionary = h.skills[i]
		if s.get("unlock_at_2", false) and h.level < 2:
			continue
		if h.cds[i] > 0.0:
			continue
		var kind := str(s.get("kind", ""))
		var support := kind == "heal" or kind == "shield" or kind == "taunt" or kind == "heal_zone" or kind == "vanish"
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
				if td != null and td.kind == HERO:
					var d: float = h.pos.distance_to(td.pos)
					use = d > float(s.get("range", 230)) * 0.9 and d < float(s.get("range", 230)) * 1.7 and rng.randf() < 0.4
			"cone":
				var cone_n := count_enemies_around(h, float(s.get("range", 132)), 0.2)
				use = cone_n >= 2 or (cone_n > 0 and nearest_hero(h, float(s.get("range", 132))) != null)
			"pull", "leap":
				use = nearest_hero(h, float(s.get("range", 300))) != null and rng.randf() < 0.32
			"multi":
				use = nearest_hero(h, float(s.get("range", 260))) != null and rng.randf() < 0.34
			"backstep":
				use = nearest_hero(h, 330.0) != null and hp_p < 0.90
			"radial":
				var radial_n := count_enemies_around(h, float(s.get("range", 152)), -1.0)
				use = radial_n >= 2 or nearest_hero(h, float(s.get("range", 152))) != null
			"aoe":
				var aoe_n := count_enemies_around(h, float(s.get("radius", 180)), -1.0)
				use = aoe_n >= 2 or (aoe_n > 0 and nearest_hero(h, float(s.get("radius", 180))) != null)
			"vanish":
				use = hp_p < 0.7 and enemy_hero_near(h, 320.0)
			"spin":
				var spin_n := count_enemies_around(h, float(s.get("radius", 150)), -1.0)
				use = spin_n >= 2 or (spin_n >= 1 and hp_p < 0.5)
			"fear":
				var fear_n := count_enemies_around(h, float(s.get("radius", 210)), -1.0)
				use = fear_n >= 2 or (fear_n >= 1 and hp_p < 0.45)
			"mark":
				var mark_n := count_enemies_around(h, float(s.get("radius", 270)), -1.0)
				use = mark_n >= 1 and nearest_hero(h, float(s.get("range", 270))) != null
			"taunt":
				use = enemy_hero_near(h, float(s.get("radius", 230)))
			"heal_zone":
				use = low_ally(h, float(s.get("range", 460)), 0.72)
			"trap":
				use = nearest_hero(h, float(s.get("range", 460))) != null and rng.randf() < 0.6
			"boomerang", "beam", "chain", "blink":
				var range_kind := float(s.get("range", 420))
				var kind_foe = nearest_enemy(h, range_kind)
				if kind == "blink":
					var bt = h.ai_target
					if bt != null and bt.kind == HERO:
						var bd: float = h.pos.distance_to(bt.pos)
						use = bd > range_kind * 0.55 and bd < range_kind * 1.6
				else:
					use = kind_foe != null and rng.randf() < 0.4
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


func front_structure(team: int, lane_id := -1):
	# 敌方最靠前（按兵线进度离我方基地最近）的存活塔；指定 lane_id 时只看该路。
	var list: Array = towers_red if team == BLUE else towers_blue
	var best = null
	var best_key := 1.0e20
	for t in list:
		if not t.is_alive():
			continue
		if five_v_five and lane_id >= 0 and t.lane_id != lane_id:
			continue
		var lid: int = t.lane_id if five_v_five else -1
		var s := lane_progress(lid, t.pos)
		# 红方推进方向相反：进度越大越靠前。
		var key := s if team == BLUE else -s
		if key < best_key:
			best_key = key
			best = t
	if best != null:
		return best
	return base_red if team == BLUE else base_blue


func own_front_structure(team: int, lane_id := -1):
	# 己方最靠前、正被对面推进的塔/水晶（判断巨兽是否已经打到家门口）。
	return front_structure(1 - team, lane_id)


func _boss_threatens_own(team: int, b) -> bool:
	if b == null or b.kind != BOSS:
		return false
	var guard := float(ai_cfg.get("boss_defend_dist", 520.0))
	var own = own_front_structure(team, 1 if five_v_five else -1)
	if own != null and own.is_alive() and b.pos.distance_to(own.pos) <= guard:
		return true
	var home = base_blue if team == BLUE else base_red
	return home != null and home.is_alive() and b.pos.distance_to(home.pos) <= guard


func ai_target(h):
	var lane_scope: int = h.lane_id if five_v_five and h.lane_id >= 0 else -1
	var front = front_structure(h.team, lane_scope)
	var tower_alive: bool = front != null and front.kind == TOWER and front.is_alive()
	var best = null
	var best_score := -1.0e20
	var hero_w := float(ai_cfg.get("hero_weight", 330.0))
	var minion_w := float(ai_cfg.get("minion_weight", 240.0))
	var tower_w := float(ai_cfg.get("tower_weight", 160.0))
	var base_w := float(ai_cfg.get("base_weight", 120.0))
	var focus := float(ai_cfg.get("focus_hp_bonus", 150.0))
	var sticky := float(ai_cfg.get("target_sticky", 45.0))

	for o in units:
		if not o.is_alive() or o.team == h.team:
			continue
		if o.kind == JUNGLE:
			continue
		if five_v_five and o.kind == TOWER and o.lane_id != lane_scope:
			continue
		if five_v_five and lane_scope >= 0 and o.kind != TOWER and o.kind != BASE \
				and o.kind != BOSS:
			if o.lane_id != lane_scope and h.pos.distance_to(o.pos) > 320.0:
				continue
		if o.kind == TOWER and is_tower_protected(o):
			continue
		if o.kind == BASE and is_base_protected(o):
			continue
		# 前塔还活着时不越过它去追英雄/小兵，否则会从塔边溜过去直扑水晶。
		if tower_alive and o != front and (o.kind == HERO or o.kind == MINION):
			if _crossed_front(h, o, front):
				continue
		var d: float = h.pos.distance_to(o.pos)
		if d > 900.0:
			continue
		var score := 0.0
		match o.kind:
			HERO:
				score = hero_w - d * 0.42
				score += (1.0 - clampf(o.hp / maxf(o.max_hp, 1.0), 0.0, 1.0)) * focus
				if d <= h.attack_range + 90.0:
					score += 80.0
				if o.attack_range > 250.0 and d <= o.attack_range + 120.0:
					score += 25.0
				if ally_engaged(h, o):
					score += 45.0
			MINION:
				score = minion_w - d * 0.62
				if d <= h.attack_range + 70.0:
					score += 55.0
				if front != null and o.pos.distance_to(front.pos) < 260.0:
					score += 20.0
			TOWER:
				score = tower_w - d * 0.18
				if o == front:
					score += 70.0
				if not tower_safe_for(h, o):
					score -= 190.0
				if count_enemies_at(o.pos, o.team, 280.0) > 0:
					score -= 80.0
			BASE:
				score = base_w - d * 0.08
				if sudden_death:
					score += 500.0
			BOSS:
				score = float(ai_cfg.get("boss_weight", 300.0)) - d * float(ai_cfg.get("boss_dist", 0.3))
				# 逆风守护兽会主动推塔：打到己方前塔/水晶附近时，AI 必须回防。
				if _boss_threatens_own(h.team, o):
					score += float(ai_cfg.get("boss_defend_weight", 900.0))
		if o == h.ai_target:
			score += sticky
		if score > best_score:
			best_score = score
			best = o
	return best


func _crossed_front(h, target, front) -> bool:
	# 目标是否已经越过敌方前塔（按兵线进度判断，适用于对角/竖直路段）。
	if five_v_five and target.lane_id != front.lane_id:
		return false
	var lid: int = front.lane_id if five_v_five else -1
	var fp := lane_progress(lid, front.pos)
	var tp := lane_progress(lid, target.pos)
	if h.team == BLUE:
		return tp > fp + 20.0
	return tp < fp - 20.0


func _pick_gank_lane(h) -> int:
	# 挑敌方英雄最多的一路去抓；没有英雄就回中路。
	var best_lane := 1
	var best_n := -1
	for l in range(mini(3, lane_paths.size())):
		var n := 0
		for o in heroes:
			if o.is_alive() and o.team != h.team and o.lane_id == l:
				n += 1
		if n > best_n:
			best_n = n
			best_lane = l
	return best_lane


func _step_jungler_ai(h, dt) -> bool:
	# 返回 true 表示这一帧由刷野逻辑接管：只刷本方野区（离自家基地更近的营地），
	# 营地全空时就近等刷新，绝不横穿地图去对面野区送命。
	if h.hp < h.max_hp * 0.35:
		var home := base_pos(h.team) + Vector2(70.0 if h.team == BLUE else -70.0, 0.0)
		if h.pos.distance_to(home) > 60.0:
			move_ai(h, home - h.pos, dt, 1.0)
		else:
			h.moving = false
		return true
	var camp = null
	var best := 1.0e20
	var fallback_home := Vector2.ZERO
	var fallback_d := 1.0e20
	for u in units:
		if u.kind != JUNGLE:
			continue
		var own_d: float = u.pos.distance_to(base_pos(h.team))
		var foe_d: float = u.pos.distance_to(base_pos(1 - h.team))
		if own_d > foe_d + 100.0:
			continue
		if fallback_home == Vector2.ZERO or own_d < fallback_d:
			fallback_d = own_d
			fallback_home = u.respawn_home
		if not u.is_alive():
			continue
		var d: float = h.pos.distance_to(u.pos)
		if d < best:
			best = d
			camp = u
	if camp == null:
		# 自家野区全空：先在最近营地等 4 秒，再沿自家营地巡逻，避免站在角落不动。
		if h.jungle_patrol != Vector2.ZERO:
			if h.pos.distance_to(h.jungle_patrol) > 50.0:
				move_ai(h, h.jungle_patrol - h.pos, dt, 0.80)
			else:
				h.jungle_patrol = Vector2.ZERO
				h.moving = false
			return true
		if fallback_home != Vector2.ZERO and h.pos.distance_to(fallback_home) > 50.0:
			move_ai(h, fallback_home - h.pos, dt, 0.9)
		else:
			h.moving = false
			h.jungle_wait_t += dt
			if h.jungle_wait_t >= 4.0:
				h.jungle_wait_t = 0.0
				h.jungle_patrol = _far_own_camp(h)
		return true
	h.jungle_wait_t = 0.0
	h.jungle_patrol = Vector2.ZERO
	var reach: float = h.attack_range + camp.radius * 0.5
	if h.pos.distance_to(camp.pos) <= reach:
		h.moving = false
		h.facing = 1.0 if camp.pos.x >= h.pos.x else -1.0
	else:
		move_ai(h, camp.pos - h.pos, dt, 0.95)
	return true


func _far_own_camp(h) -> Vector2:
	# 自家野区里离当前点最远的营地刷新点，用作巡逻目标（只在自家半场）。
	var best := Vector2.ZERO
	var bd := -1.0
	for u in units:
		if u.kind != JUNGLE:
			continue
		var own_d: float = u.pos.distance_to(base_pos(h.team))
		var foe_d: float = u.pos.distance_to(base_pos(1 - h.team))
		if own_d > foe_d + 100.0:
			continue
		var d: float = h.pos.distance_to(u.respawn_home)
		if d > bd:
			bd = d
			best = u.respawn_home
	return best


func count_enemies_at(pos: Vector2, team: int, radius: float) -> int:
	var n := 0
	for u in units:
		if not u.is_alive() or u.team == team:
			continue
		if u.kind != HERO and u.kind != MINION:
			continue
		if pos.distance_to(u.pos) <= radius + u.radius:
			n += 1
	return n


func ally_engaged(h, foe) -> bool:
	for a in heroes:
		if a != h and a.is_alive() and a.team == h.team and a.pos.distance_to(foe.pos) <= 260.0:
			return true
	return false


func count_units_at(pos: Vector2, team: int, radius: float) -> int:
	var n := 0
	for u in units:
		if not u.is_alive() or u.team != team:
			continue
		if u.kind != HERO and u.kind != MINION:
			continue
		if pos.distance_to(u.pos) <= radius + u.radius:
			n += 1
	return n


func tower_safe_for(h, t) -> bool:
	# 没有敌方英雄/小兵守塔时，近战也直接拆，不能站在塔前空等兵线；
	# 有守军时再看己方兵线和血量。
	if t == null or not t.is_alive():
		return true
	if h.attack_range > t.attack_range + 30.0:
		return true
	var defenders := count_units_at(t.pos, t.team, t.attack_range + 90.0)
	if defenders == 0:
		return true
	if t.hp / maxf(t.max_hp, 1.0) < 0.15:
		return true
	if h.hp / maxf(h.max_hp, 1.0) < 0.55:
		return false
	for m in minions:
		if m.is_alive() and m.team == h.team \
				and m.pos.distance_to(t.pos) <= t.attack_range + 100.0:
			return true
	return false


func count_team_heroes(team: int, pos: Vector2, radius: float) -> int:
	var n := 0
	for h in heroes:
		if h.is_alive() and h.team == team and h.pos.distance_to(pos) <= radius:
			n += 1
	return n


func has_healer_near(h, radius: float) -> bool:
	for a in heroes:
		if a != h and a.is_alive() and a.team == h.team \
				and (a.hero_id == "rabbit" or a.hero_id == "axolotl") and a.pos.distance_to(h.pos) <= radius:
			return true
	return false


func step_minion(m, dt: float) -> void:
	# 先接战敌方英雄/小兵：在 150 内先朝对方靠近，贴近后再出手。
	# 旧逻辑只按身体间隙判定；两波兵横向错开 60–140px 时会擦肩而过。
	var unit_foe = nearest_enemy_unit(m, m.radius + 150.0)
	if unit_foe != null:
		var ud: float = m.pos.distance_to(unit_foe.pos)
		var reach: float = m.radius + unit_foe.radius + 26.0
		if ud > reach:
			m.moving = true
			m.face_dir = (unit_foe.pos - m.pos).normalized()
			m.facing = 1.0 if unit_foe.pos.x >= m.pos.x else -1.0
			var chase_k := 0.55 if m.slow_t > 0.0 else 1.0
			move_to(m, m.pos + m.face_dir * (m.move_speed * chase_k * dt))
			m.walk_t += dt
			return
		m.moving = false
		m.facing = 1.0 if unit_foe.pos.x >= m.pos.x else -1.0
		m.face_dir = (unit_foe.pos - m.pos).normalized()
		if m.atk_timer <= 0.0:
			m.atk_timer = m.atk_interval
			m.atk_anim = 0.22
			hit_with_fx(unit_foe, m.dmg, m, 0.0)
		return
	var foe = nearest_enemy(m, m.attack_range + 40.0)
	if foe != null and m.pos.distance_to(foe.pos) <= m.radius + foe.radius + 26.0:
		m.moving = false
		m.facing = 1.0 if foe.pos.x >= m.pos.x else -1.0
		m.face_dir = (foe.pos - m.pos).normalized()
		if m.atk_timer <= 0.0:
			m.atk_timer = m.atk_interval
			m.atk_anim = 0.22
			var mul := float(minion_cfg.get("structure_damage_mul", 2.4))
			var dmg: float = m.dmg * mul if (foe.kind == TOWER or foe.kind == BASE) else m.dmg
			hit_with_fx(foe, dmg, m, 0.0)
		return

	var step_dir := 1 if m.team == BLUE else -1
	var path: Array = lane_paths[m.lane_id] if five_v_five and m.lane_id < lane_paths.size() else lane
	if path.is_empty():
		return
	var idx := clampi(m.lane_index, 0, path.size() - 1)
	var goal: Vector2 = path[idx]
	for guard in range(path.size()):
		if (goal - m.pos).length() > 70.0:
			break
		var next_idx := idx + step_dir
		if next_idx < 0 or next_idx >= path.size():
			break
		idx = next_idx
		goal = path[idx]
	m.lane_index = idx

	var to: Vector2 = goal - m.pos
	var d := to.length()
	if d < 10.0:
		return
	to = to / d
	m.move_dir = to
	if m.atk_anim <= 0.0:
		m.face_dir = to
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
	# 单位之间不做碰撞：身体可互相穿透（王者荣耀式），只有普攻/技能造成伤害与推挤。
	# 但水晶底座是实体：所有单位都不能从水晶正中穿过去。
	p.x = clampf(p.x, 60.0, map_w - 60.0)
	p.y = clampf(p.y, 60.0, map_h - 60.0)
	for b in units:
		if b.kind != BASE or not b.is_alive():
			continue
		var min_d: float = b.radius + u.radius * 0.8
		var d: Vector2 = p - b.pos
		if d.length_squared() < min_d * min_d:
			var dir: Vector2 = d
			if dir.length_squared() < 0.01:
				dir = p - u.pos
			if dir.length_squared() < 0.01:
				dir = u.face_dir if u.face_dir.length_squared() > 0.01 else Vector2.RIGHT
			p = b.pos + dir.normalized() * min_d
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
		sfx.emit("shoot_" + src.hero_id, src.pos)
	fx.emit("muzzle", Vector3(p.pos.x, src.height * 0.45, p.pos.y), color, 0.0)


func step_projectiles(dt: float) -> void:
	for p in shots:
		if not p.alive:
			continue
		p.prev_pos = p.pos
		if p.boom:
			if not p.boomed:
				p.pos += p.dir * (p.speed * dt)
				if p.origin.distance_to(p.pos) >= p.boom_range:
					p.boomed = true
					p.hit.clear()
					p.pierce = maxi(p.pierce, 1)
			elif p.src != null and p.src.is_alive():
				var back: Vector2 = p.src.pos - p.pos
				if back.length() <= 26.0:
					p.alive = false
					continue
				p.dir = back.normalized()
				p.pos += p.dir * (p.speed * dt)
			else:
				p.alive = false
				continue
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
				hit_with_fx(u, p.dmg, p.src, 0.0, p.color)
				if p.slow > 0.0:
					u.slow_t = maxf(u.slow_t, p.slow)
				p.hit[u.uid] = true
				fx.emit("burst", Vector3(p.pos.x, 20.0, p.pos.y), p.color, 0.0)
				break
			continue
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
				sfx.emit("boom", p.pos)
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
	# 尖刺伏击：隐身结束后的第一击强化。
	if src != null and src.kind == HERO and src.ambush_t > 0.0:
		amount *= src.ambush_mul
		src.ambush_t = 0.0
		float_text.emit(Vector3(src.pos.x, src.height + 24.0, src.pos.y), "伏击！", Color(1.0, 0.86, 0.55))
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
	sfx.emit(hit_key, target.pos)
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
	# 击败巨兽的团队反击加成：英雄造成的伤害 +15%，持续 15 秒。
	if src != null and src.kind == HERO and int(src.team) >= 0 and int(src.team) < 2 \
			and float(team_buff_t[src.team]) > 0.0:
		amount *= 1.0 + float(boss_cfg.get("team_buff_dmg", 0.15))
	# 野区增益：灰狼营的猎狼 buff。
	if src != null and src.kind == HERO and src.buff_dmg_t > 0.0:
		amount *= 1.0 + src.buff_dmg_pct
	# 猎杀标记：被狼盯上的目标承受更多伤害。
	if target.mark_t > 0.0:
		amount *= float(combat_cfg.get("mark_amp", 1.22))

	# 终极对决：建筑变脆，保证 3 分钟内能打出结果。
	if sudden_death and (target.kind == TOWER or target.kind == BASE):
		amount *= float(comeback_cfg.get("sudden_death_structure_mul", 1.8))

	if reflect and target.thorn_t > 0.0 and src != null and src != target and src.is_alive() and src.kind == HERO:
		deal_damage(src, float(combat_cfg.get("thorn_base", 24.0)) \
			+ target.level * float(combat_cfg.get("thorn_per_level", 5.0)), target, false)
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
	target.atk_target = null
	target.move_skill_t = 0.0
	target.move_skill_total = 0.0
	target.move_skill_kind = ""
	target.move_skill_data = {}
	fx.emit("burst", Vector3(target.pos.x, target.height * 0.5, target.pos.y), Color(1, 0.9, 0.7), 0.0)

	if target.kind == HERO:
		target.deaths += 1
		var behind := score_red - score_blue if target.team == BLUE else score_blue - score_red
		var max_tiers := int(comeback_cfg.get("max_tiers", 3))
		var cut := float(comeback_cfg.get("respawn_cut", 0.55))
		var min_respawn := float(comeback_cfg.get("min_respawn", 3.8))
		var growth := float(comeback_cfg.get("respawn_growth", 1.0))
		var respawn_cap := float(comeback_cfg.get("respawn_max", 30.0))
		# 每次死亡复活时间 +1 秒（第一次死亡即 6.5 秒），落后方仍按塔数小幅缩短；
		# 上限 30 秒，避免后期无限复活拉长对局。
		var scaled := respawn_time + float(target.deaths) * growth 			- clampf(float(behind), 0.0, float(max_tiers)) * cut
		target.respawn_t = clampf(scaled, min_respawn, respawn_cap)
		if killer != null:
			killer.kills += 1
			if killer.kind == HERO:
				# 终结赏金：落后方击杀领先方英雄时额外获得经验（王者式 shutdown）。
				var xp_gain := xp_hero_kill
				if is_trailing_team(killer.team):
					xp_gain *= 1.0 + float(comeback_cfg.get("shutdown_bonus", 0.5))
					float_text.emit(Vector3(killer.pos.x, killer.height + 28.0, killer.pos.y),
						"终结赏金！", Color(1.0, 0.86, 0.4))
				add_xp(killer, xp_gain)
			for a in heroes:
				if a != killer and a.is_alive() and a.team == killer.team and a.pos.distance_to(target.pos) < 700.0:
					add_xp(a, xp_hero_assist)
		if target.team == BLUE:
			score_red += 1
		else:
			score_blue += 1
		var killer_name: String = killer.display_name if killer != null else "？"
		banner.emit("%s 击败了 %s" % [killer_name, target.display_name], 1.8)
		sfx.emit("ult", target.pos)

	elif target.kind == JUNGLE:
		target.respawn_t = float(jungle_cfg.get("respawn", 45.0))
		var kind_cfg: Dictionary = jungle_cfg.get("kinds", {}).get(target.jungle_kind, {})
		var xp_gain := float(kind_cfg.get("xp", jungle_cfg.get("xp", 90.0)))
		if killer != null and killer.kind == HERO:
			add_xp(killer, xp_gain)
			var heal_pct := float(kind_cfg.get("heal_pct", jungle_cfg.get("heal_pct", 0.08)))
			var heal: float = killer.max_hp * heal_pct
			killer.hp = minf(killer.max_hp, killer.hp + heal)
			var buff: Dictionary = kind_cfg.get("buff", {})
			if not buff.is_empty():
				_apply_jungle_buff(killer, buff)
			float_text.emit(Vector3(killer.pos.x, killer.height + 24.0, killer.pos.y),
				"+%d 野怪经验" % int(xp_gain), Color(0.85, 1.0, 0.7))
		# 助攻经验：和英雄/小兵一致，700 范围内的同队英雄分一半。
		if killer != null:
			for a in heroes:
				if a != killer and a.is_alive() and a.team == killer.team \
						and a.pos.distance_to(target.pos) < 700.0:
					add_xp(a, xp_gain * 0.5)
		sfx.emit("pickup", target.pos)
	elif target.kind == BOSS:
		target.respawn_t = boss_respawn
		var buff_team: int = killer.team if killer != null else 1 - target.team
		if buff_team != target.team:
			var buff_time := float(boss_cfg.get("team_buff_time", 15.0))
			team_buff_t[buff_team] = maxf(float(team_buff_t[buff_team]), buff_time)
			var pct := int(round(float(boss_cfg.get("team_buff_dmg", 0.15)) * 100.0))
			banner.emit("峡谷巨兽被击败！%s全体英雄能力 +%d%%（%d 秒）" % [
				"蓝方" if buff_team == BLUE else "红方", pct, int(buff_time)], 3.6)
			for a in heroes:
				if a.is_alive() and a.team == buff_team:
					float_text.emit(Vector3(a.pos.x, a.height + 28.0, a.pos.y),
						"巨兽之力！", Color(1.0, 0.92, 0.6))
			fx.emit("ring", Vector3(target.pos.x, 6.0, target.pos.y),
				Color(1.0, 0.86, 0.4), 260.0)
		else:
			banner.emit("峡谷巨兽被击退了！", 2.4)
		sfx.emit("boom", target.pos)
		fx.emit("debris", Vector3(target.pos.x, target.height * 0.45, target.pos.y),
			_team_color(target.team), target.radius)
		if killer != null and killer.kind == HERO:
			add_xp(killer, float(combat_cfg.get("boss_kill_xp", 90.0)))

	elif target.kind == TOWER:
		banner.emit("我方蘑菇塔被拆了！" if target.team == BLUE else "拆掉一座敌方蘑菇塔！", 2.0)
		sfx.emit("boom", target.pos)
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
		sfx.emit("boom", target.pos)
		fx.emit("debris", Vector3(target.pos.x, target.height * 0.45, target.pos.y),
			_team_color(target.team), target.radius * 1.2)


func _team_color(team: int) -> Color:
	return Color(0.42, 0.72, 0.95) if team == BLUE else Color(0.92, 0.44, 0.38)


func add_xp(h, add: float) -> void:
	if h == null or add <= 0.0 or h.level >= level_cap:
		return
	h.xp += add
	while h.level < level_cap and h.level - 1 < xp_levels.size() \
			and h.xp >= float(xp_levels[h.level - 1]):
		h.level += 1
		_apply_level_growth(h)
		if h.level == 2:
			h.level2_time = clock
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "二级解锁大招！", Color(1, 0.95, 0.6))
			if h.is_player:
				banner.emit("大招解锁！按右上的技能键放出来", 1.8)
				sfx.emit("ult", h.pos)
		elif five_v_five:
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "Lv%d 属性提升！" % h.level, Color(1, 0.95, 0.6))
		level_up.emit(h)


func _apply_level_growth(h) -> void:
	# 属性成长只发生在 5v5；基础值取 def，不受难度增伤烘焙影响。
	if not five_v_five:
		return
	var base_hp := float(h.def.get("hp", 900))
	var base_dmg := float(h.def.get("dmg", 45))
	var old_max: float = h.max_hp
	h.max_hp = base_hp * (1.0 + hp_per_level * float(h.level - 1))
	h.hp += h.max_hp - old_max
	h.dmg = base_dmg * (1.0 + dmg_per_level * float(h.level - 1))


func skill_power(h) -> float:
	# 技能强度随等级成长；3v3 冻结为零成长，保持旧手感。
	if not five_v_five or h == null:
		return 1.0
	return 1.0 + skill_per_level * float(h.level - 1)


func xp_next(h) -> float:
	# 下一级累计经验阈值；满级返回最后一级阈值，经验条恒满。
	if h == null or xp_levels.is_empty():
		return 0.0
	return float(xp_levels[clampi(h.level - 1, 0, xp_levels.size() - 1)])


func respawn(h) -> void:
	h.hp = h.max_hp
	h.pos = base_pos(h.team) + Vector2(150.0 if h.team == BLUE else -150.0, 0.0)
	h.prev_pos = h.pos
	h.face_dir = (base_pos(1 - h.team) - h.pos).normalized()
	h.invuln_t = 1.6
	h.stun_t = 0.0
	h.slow_t = 0.0
	h.shield = 0.0
	h.thorn_t = 0.0
	h.mark_t = 0.0
	h.fear_t = 0.0
	h.fear_src = null
	h.taunt_t = 0.0
	h.taunt_src = null
	h.spin_t = 0.0
	h.spin_tick = 0.0
	h.vanish_t = 0.0
	h.ambush_t = 0.0
	h.ambush_pending = 0.0
	h.buff_dmg_t = 0.0
	h.buff_speed_t = 0.0
	h.jungle_gank_t = 0.0
	h.move_dir = Vector2.ZERO
	h.atk_timer = 0.3
	h.atk_target = null
	fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), Color(0.6, 0.95, 1.0) if h.team == BLUE else Color(1, 0.7, 0.6), 90.0)


func area_damage(center: Vector2, radius: float, dmg: float, src, team: int,
		slow: float, stun: float, knock: float, unit_only := false) -> void:
	for u in units:
		if not u.is_alive() or u.team == team:
			continue
		if unit_only and (u.kind == TOWER or u.kind == BASE):
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


func _tcfg(key: String, def: float) -> float:
	return float(targeting_cfg.get(key, def))


func _target_in_reach(h, u, reach: float) -> bool:
	if u == null or not u.is_alive() or u.team == h.team:
		return false
	if u.kind == TOWER and is_tower_protected(u):
		return false
	if u.kind == BASE and is_base_protected(u):
		return false
	return h.pos.distance_to(u.pos) <= reach + u.radius


func pick_attack_target(h):
	# 王者式普攻选目标：敌方英雄 > 残血小兵/野怪 > 防御塔 > 水晶。
	# 当前目标仍有粘性分，避免两个同分单位之间来回抖动。
	if h.taunt_t > 0.0 and h.taunt_src != null \
			and _target_in_reach(h, h.taunt_src, h.attack_range):
		h.atk_target = h.taunt_src
		return h.atk_target
	var best = null
	var best_score := -1.0e20
	for u in units:
		if not _target_in_reach(h, u, h.attack_range):
			continue
		var d: float = h.pos.distance_to(u.pos)
		var missing: float = 1.0 - clampf(u.hp / maxf(u.max_hp, 1.0), 0.0, 1.0)
		var score := -1.0e20
		match u.kind:
			HERO:
				score = _tcfg("hero_weight", 3000.0) - d * _tcfg("hero_dist", 0.5) \
					+ missing * _tcfg("focus_hp", 600.0)
			MINION, JUNGLE:
				score = _tcfg("unit_weight", 1200.0) - d * _tcfg("unit_dist", 0.8) \
					+ missing * _tcfg("unit_focus_hp", 500.0)
			TOWER:
				score = _tcfg("tower_weight", 400.0) - d * _tcfg("tower_dist", 0.2)
			BASE:
				score = _tcfg("base_weight", 200.0) - d * _tcfg("base_dist", 0.1)
			BOSS:
				# 巨兽属于领先方，被另一方视作敌方单位；不补这一支，普攻永远选不中它。
				score = _tcfg("boss_weight", 2600.0) - d * _tcfg("boss_dist", 0.35) \
					+ missing * _tcfg("boss_focus_hp", 300.0)
		if u == h.atk_target:
			score += _tcfg("sticky", 280.0)
		if u == h.ai_target:
			score += _tcfg("ai_sticky", 200.0)
		if score > best_score:
			best_score = score
			best = u
	h.atk_target = best
	return best


func _best_skill_hero(h, radius: float):
	# 技能优先打血量比例最低的敌方英雄（收割优先），同分看距离。
	var best = null
	var best_score := -1.0e20
	for u in heroes:
		if not _target_in_reach(h, u, radius):
			continue
		var d: float = h.pos.distance_to(u.pos)
		var missing: float = 1.0 - clampf(u.hp / maxf(u.max_hp, 1.0), 0.0, 1.0)
		var score: float = missing * _tcfg("skill_focus_hp", 500.0) \
			- d * _tcfg("skill_dist", 0.4)
		if u == h.atk_target:
			score += _tcfg("skill_sticky", 300.0)
		if score > best_score:
			best_score = score
			best = u
	return best


func pick_skill_target(h, s: Dictionary, kind: String):
	if SELF_SKILL_KINDS.has(kind):
		return null
	var reach: float = maxf(float(s.get("range", 260.0)), 260.0) + 40.0
	var hero = _best_skill_hero(h, reach)
	if hero != null:
		return hero
	var best = null
	var best_score := -1.0e20
	for u in units:
		if not _target_in_reach(h, u, reach):
			continue
		if u.kind == TOWER or u.kind == BASE:
			continue
		var d: float = h.pos.distance_to(u.pos)
		var missing: float = 1.0 - clampf(u.hp / maxf(u.max_hp, 1.0), 0.0, 1.0)
		var score: float = _tcfg("skill_unit_weight", 400.0) \
			- d * _tcfg("skill_unit_dist", 0.6) \
			+ missing * _tcfg("skill_unit_focus", 300.0)
		if score > best_score:
			best_score = score
			best = u
	if best != null:
		return best
	for u in units:
		if not _target_in_reach(h, u, reach):
			continue
		if u.kind == TOWER or u.kind == BASE:
			return u
	return null


func _lead_point(h, target, proj_speed: float) -> Vector2:
	# 预判目标走位：按弹速估算飞行时间，朝移动方向提前量瞄准。
	if target == null:
		return h.pos
	var t: float = clampf(h.pos.distance_to(target.pos) / maxf(240.0, proj_speed),
		_tcfg("lead_min", 0.12), _tcfg("lead_max", 0.45))
	var v := Vector2.ZERO
	if target.move_dir.length_squared() > 0.01 and target.kind == HERO:
		v = target.move_dir.normalized() * speed_of(target)
	return target.pos + v * t * _tcfg("lead_scale", 0.85)


func _area_aim_dir(h, s: Dictionary, kind: String, forward: Vector2) -> Vector2:
	# 锥形/光束没有英雄时，按命中数量最多的方向施放（小兵聚团也能吃到）。
	var reach: float = maxf(float(s.get("range", 260.0)), 200.0)
	var radius: float = float(s.get("radius", 132.0))
	var centers: Array = []
	for u in units:
		if not u.is_alive() or u.team == h.team:
			continue
		if u.kind == TOWER or u.kind == BASE:
			continue
		if h.pos.distance_to(u.pos) > reach + u.radius:
			continue
		centers.append(u.pos)
	var seed_count := centers.size()
	for i in range(seed_count):
		for j in range(i + 1, seed_count):
			centers.append((centers[i] + centers[j]) * 0.5)
	var best_dir := forward
	var best_score := -1.0
	for cpos in centers:
		var dir: Vector2 = cpos - h.pos
		if dir.length_squared() < 0.01:
			continue
		dir = dir.normalized()
		var score := 0.0
		for u in units:
			if not u.is_alive() or u.team == h.team:
				continue
			if u.kind == TOWER or u.kind == BASE:
				continue
			var to_u: Vector2 = u.pos - h.pos
			var weight := 3.0 if u.kind == HERO else 1.0
			if kind == "beam":
				var width := float(s.get("width", 40.0))
				var along: float = to_u.dot(dir)
				if along < 0.0 or along > reach + u.radius:
					continue
				if absf(to_u.cross(dir)) > width * 0.5 + u.radius:
					continue
				score += weight
			else:
				if to_u.length() > radius + u.radius:
					continue
				if to_u.normalized().dot(dir) < 0.35:
					continue
				score += weight
		if score > best_score:
			best_score = score
			best_dir = dir
	return best_dir


func _chain_target(h, from_pos: Vector2, radius: float, hit_list: Array):
	# 月链后续弹跳：优先未命中的英雄，其次最近单位。
	var best_hero = null
	var best_score := -1.0e20
	for u in heroes:
		if not u.is_alive() or u.team == h.team or hit_list.has(u):
			continue
		var d: float = from_pos.distance_to(u.pos)
		if d > radius:
			continue
		var missing: float = 1.0 - clampf(u.hp / maxf(u.max_hp, 1.0), 0.0, 1.0)
		var score: float = missing * 500.0 - d * 0.3
		if score > best_score:
			best_score = score
			best_hero = u
	if best_hero != null:
		return best_hero
	return nearest_enemy_excluding(h, from_pos, radius, hit_list)


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


func nearest_enemy_excluding(from, origin: Vector2, radius: float, excluded: Array):
	var best = null
	var bd := radius
	for u in units:
		if not u.is_alive() or u.team == from.team:
			continue
		if excluded.has(u):
			continue
		if u.kind == TOWER and is_tower_protected(u):
			continue
		if u.kind == BASE and is_base_protected(u):
			continue
		var d: float = origin.distance_to(u.pos)
		if d <= bd:
			bd = d
			best = u
	return best


func _throw_boomerang(h, dir: Vector2, dmg: float, color: Color, s: Dictionary) -> void:
	# count 把回旋镖做成扇形三连，每把独立命中表，去程回程都能扎人。
	var n := int(maxf(1.0, float(s.get("count", 1))))
	var base_ang := atan2(dir.y, dir.x) if dir.length_squared() > 0.001 else 0.0
	for i in range(n):
		var ang := base_ang + (float(i) - float(n - 1) * 0.5) * 0.14
		_spawn_boomerang(h, Vector2(cos(ang), sin(ang)), dmg, color, s)


func _spawn_boomerang(h, dir: Vector2, dmg: float, color: Color, s: Dictionary) -> void:
	var p = Projectile.new()
	p.pos = h.pos
	p.prev_pos = p.pos
	p.dir = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	p.team = h.team
	p.src = h
	p.speed = float(s.get("speed", 620.0))
	p.dmg = dmg
	p.life = 3.0
	p.size = 10.0
	p.color = color
	p.slow = float(s.get("slow", 0.0))
	p.pierce = int(s.get("pierce", 2))
	p.style = str(s.get("shot_style", "arrow"))
	p.boom = true
	p.origin = h.pos
	p.boom_range = float(s.get("range", 420.0))
	p.view_id = _shot_view
	_shot_view += 1
	shots.append(p)
	fx.emit("muzzle", Vector3(p.pos.x, h.height * 0.45, p.pos.y), color, 0.0)
	sfx.emit("shoot_" + h.hero_id, h.pos)


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
	if sudden_death and not (five_v_five and keep_protection):
		return false
	if t.kind != TOWER:
		return false
	var list: Array = towers_blue if t.team == BLUE else towers_red
	for o in list:
		if o != t and o.is_alive() and o.level < t.level:
			return true
	return false


func is_base_protected(b) -> bool:
	if sudden_death and not (five_v_five and keep_protection):
		return false
	if b.kind != BASE:
		return false
	var list: Array = towers_blue if b.team == BLUE else towers_red
	var alive := 0
	for o in list:
		if o.is_alive():
			alive += 1
	if five_v_five:
		var open_at := int(rules.get("mode_5v5", {}).get("base_open_towers", 1))
		return alive > open_at
	return alive > 0


func step_zones(dt: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var z = zones[i]
		z.t += dt
		if z.t >= z.life:
			zones.remove_at(i)
			continue
		for u in units:
			if not u.is_alive():
				continue
			if z.pos.distance_to(u.pos) > z.radius + u.radius:
				continue
			if u.team == z.team:
				# 治疗区域：对自己人每秒回复，不减速。
				if z.heal_pct > 0.0 and u.kind == HERO:
					u.hp = minf(u.max_hp, u.hp + u.max_hp * z.heal_pct * dt)
				continue
			u.slow_t = maxf(u.slow_t, z.slow)


func cleanup_dead() -> void:
	for i in range(units.size() - 1, -1, -1):
		var u = units[i]
		if u.is_alive():
			continue
		# 塔、水晶与峡谷巨兽留在 units 里，表现层才能换废墟或显示复活。
		if u.kind == HERO or u.kind == BOSS or u.kind == TOWER or u.kind == BASE or u.kind == JUNGLE:
			continue
		units.remove_at(i)
	minions = minions.filter(func(m): return m.is_alive())


func soft_separate_minions() -> void:
	# 只对同队小兵做极轻软分离，避免整波叠成一坨；英雄与任何单位、敌我小兵之间依然完全穿透。
	for i in range(minions.size()):
		var a = minions[i]
		if not a.is_alive():
			continue
		for j in range(i + 1, minions.size()):
			var b = minions[j]
			if not b.is_alive() or a.team != b.team:
				continue
			var min_d: float = (a.radius + b.radius) * 0.40
			var d: Vector2 = a.pos - b.pos
			var sq := d.length_squared()
			if sq >= min_d * min_d:
				continue
			var dist := sqrt(sq)
			if dist < 0.001:
				d = Vector2(1, 0)
				dist = 1.0
			var push := minf(2.0, (min_d - dist) * 0.25)
			var n := d / dist
			move_to(a, a.pos + n * push)
			move_to(b, b.pos - n * push)


func end_match(winner_team: int, reason := "水晶被摧毁") -> void:
	over = true
	winner = winner_team
	end_reason = reason
	banner.emit("胜利！水晶亮起来了" if winner_team == BLUE else "水晶被点亮了…再来一局？", 6.0)
	sfx.emit("win" if winner_team == BLUE else "lose", Vector2.INF)
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
	# 小技能收招更快：技能 1/2 的施法姿势 0.34 秒，大招保留 0.5 秒。
	h.cast_total = 0.5 if index < 2 else 1.2
	h.cast_anim = h.cast_total
	h.cast_index = index
	h.cast_kind = str(s.get("kind", "projectile"))
	sfx.emit(("ult_" if index == 2 else "cast_") + h.hero_id, h.pos)
	if h.is_player and index == 2:
		fx.emit("punch", Vector3(h.pos.x, 40.0, h.pos.y),
			Color(s.get("color_c", Color.WHITE)), 0.0)
	cast(h, s, index)


func cast(h, s: Dictionary, index: int) -> void:
	var kind := str(s.get("kind", "projectile"))
	var forward: Vector2 = h.move_dir.normalized() if h.move_dir.length_squared() > 0.01 else Vector2(h.facing, 0.0)
	# 王者式智能施法：英雄优先、残血优先；方向型技能对移动目标做提前量。
	var aim = null
	var auto_aim: bool = not SELF_SKILL_KINDS.has(kind)
	if h.is_player and (kind == "dash" or kind == "blink"):
		# 玩家位移只认摇杆/朝向，不因为附近有敌人就自动扭头。
		auto_aim = false
	if auto_aim:
		aim = pick_skill_target(h, s, kind)
	var aim_dir := forward
	if aim != null:
		var aim_point: Vector2 = aim.pos
		if LEAD_SKILL_KINDS.has(kind):
			var proj_speed := float(s.get("speed", 620.0))
			if kind == "beam" or kind == "cone":
				proj_speed = 1600.0
			aim_point = _lead_point(h, aim, proj_speed)
		aim_dir = (aim_point - h.pos).normalized()
		h.facing = 1.0 if aim_point.x >= h.pos.x else -1.0
	if kind == "dash" or kind == "blink":
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
	if aim == null and (kind == "cone" or kind == "beam"):
		aim_dir = _area_aim_dir(h, s, kind, forward)
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT
	h.face_dir = aim_dir

	var color: Color = s.get("color_c", Color.WHITE)
	var dmg := float(s.get("dmg", 0.0)) * skill_power(h)
	var radius := float(s.get("radius", 120.0))
	var style := str(s.get("fx", "burst"))
	var shot_style := str(s.get("shot_style", style))
	if index == 2 and style == "arrow_rain_ult":
		# 角角「林间箭雨」：箭雨落在目标区域，而不是只在脚下炸一圈。
		var rain_at: Vector2 = h.pos + aim_dir * 240.0
		if aim != null:
			rain_at = aim.pos
		fx.emit("arrow_rain", Vector3(rain_at.x, 0.0, rain_at.y), color, maxf(radius, 170.0))
	elif index == 2 or (kind != "leap" and kind != "pull" and kind != "multi" 			and kind != "beam" and kind != "chain"):
		# 每个英雄的施法都有专属形状：爪痕、星星、叶子、水泡、箭雨、竹子、月光…
		# 大招（index 2）即使走 multi/leap 也要播专属起手特效，否则星落/满月/瀑布会被跳过。
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
					false, null, shot_style)
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
			# 位移拆成约 0.1–0.2 秒的连续路径，镜头和模型不再一帧瞬移。
			var dash_dur := clampf(float(s.get("range", 230.0)) / 1800.0, 0.10, 0.22)
			_start_move_skill(h, dash_to, dash_dur, "dash",
				{"skill": s, "color": color, "from": dash_from})
			fx.emit("burst", Vector3(dash_from.x, 24.0, dash_from.y), color, 0.0)
		"backstep":
			var foe = _best_skill_hero(h, float(s.get("range", 220.0)) + 220.0)
			var back := Vector2(-h.facing, 0.0)
			if foe != null and foe.is_alive():
				back = (h.pos - foe.pos).normalized()
			var face_x: float = h.facing
			if foe != null and foe.is_alive():
				face_x = 1.0 if foe.pos.x >= h.pos.x else -1.0
			h.facing = face_x
			_start_move_skill(h, h.pos + back * float(s.get("range", 220.0)), 0.18, "backstep",
				{"skill": s, "color": color, "foe": foe, "face": face_x})
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
		"vanish":
			# 尖刺伏击：短暂隐身无敌并加速，结束后下一击强化。
			var vanish_time := float(s.get("invuln", 0.8))
			h.invuln_t = maxf(h.invuln_t, vanish_time)
			h.vanish_t = vanish_time
			h.ambush_pending = float(s.get("ambush_time", 2.0))
			h.ambush_mul = float(s.get("ambush_mul", 1.8))
			h.buff_speed_pct = float(s.get("speed_pct", 0.3))
			h.buff_speed_t = maxf(h.buff_speed_t, vanish_time)
			fx.emit("burst", Vector3(h.pos.x, 24.0, h.pos.y), color, 0.0)
			fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), color, 90.0)
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "伏击准备！", color)
		"shield":
			h.shield = h.max_hp * float(s.get("shield_pct", 0.0))
			h.shield_t = float(s.get("buff_t", 3.0))
			h.thorn_t = h.shield_t
			fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), color, 90.0)
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "扎手！", color)
		"pull":
			var pull_target = _best_skill_hero(h, float(s.get("range", 300.0)))
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
			var leap_target = _best_skill_hero(h, float(s.get("range", 360.0)))
			var dest: Vector2 = leap_target.pos if leap_target != null else h.pos + aim_dir * 220.0
			if leap_target != null and float(s.get("behind", 0.0)) > 0.0:
				# 猎影突袭：穿过目标落到他身后，形成绕后切入。
				var away: Vector2 = leap_target.pos - h.pos
				if away.length_squared() > 0.01:
					dest = leap_target.pos + away.normalized() * float(s.get("behind", 90.0))
			if not h.is_player:
				dest = clamp_to_front(h, dest)
			# 跳跃用 0.32 秒弧线走完，落地再结算范围伤害。
			_start_move_skill(h, dest, 0.32, "leap", {"skill": s, "color": color})
		"blink":
			# 幻影闪：瞬间出现在目标方向，落地炸出一圈星屑，和连续位移的冲刺手感不同。
			var blink_from: Vector2 = h.pos
			var blink_to: Vector2 = h.pos + aim_dir * float(s.get("range", 260.0))
			if not h.is_player:
				blink_to = clamp_to_front(h, blink_to)
			move_to(h, blink_to)
			h.prev_pos = blink_to
			h.invuln_t = maxf(h.invuln_t, 0.18)
			area_damage(blink_to, float(s.get("radius", 120.0)), dmg, h, h.team,
				float(s.get("slow", 0.0)), 0.0, 0.0)
			fx.emit("cast_star", Vector3(blink_from.x, 22.0, blink_from.y), color, radius)
			fx.emit("cast_star", Vector3(blink_to.x, 22.0, blink_to.y), color, radius)
			fx.emit("ring", Vector3(blink_to.x, 6.0, blink_to.y), color, radius)
		"beam":
			# 鹤羽贯日：一条直线的贯穿攻击，穿过的小兵和英雄都会被打到。
			var beam_end: Vector2 = h.pos + aim_dir * float(s.get("range", 620.0))
			var width := float(s.get("width", 40.0))
			var hit_any := false
			for u in units:
				if not u.is_alive() or u.team == h.team:
					continue
				var to_u: Vector2 = u.pos - h.pos
				var along: float = to_u.dot(aim_dir)
				if along < 0.0 or along > float(s.get("range", 620.0)) + u.radius:
					continue
				var perp: float = absf(to_u.cross(aim_dir))
				if perp > width * 0.5 + u.radius:
					continue
				deal_damage(u, dmg, h)
				u.slow_t = maxf(u.slow_t, float(s.get("slow", 0.0)))
				fx.emit("hit", Vector3(u.pos.x, 34.0, u.pos.y), color, 0.0)
				hit_any = true
			# 光柱同时治疗路径上的友军，体现「鹤」的守护感。
			var heal_pct := float(s.get("heal_pct", 0.0))
			if heal_pct > 0.0:
				for a in heroes:
					if a == h or not a.is_alive() or a.team != h.team:
						continue
					var to_a: Vector2 = a.pos - h.pos
					var along_a: float = to_a.dot(aim_dir)
					if along_a < 0.0 or along_a > float(s.get("range", 620.0)):
						continue
					if absf(to_a.cross(aim_dir)) > width * 0.5 + a.radius:
						continue
					a.hp = minf(a.max_hp, a.hp + a.max_hp * heal_pct)
					float_text.emit(Vector3(a.pos.x, a.height + 24.0, a.pos.y), "+" + str(roundi(a.max_hp * heal_pct)), color)
			beam_fx.emit(Vector3(h.pos.x, 34.0, h.pos.y), Vector3(beam_end.x, 34.0, beam_end.y), color, width)
			fx.emit("ring", Vector3(beam_end.x, 6.0, beam_end.y), color, 70.0)
			if hit_any:
				sfx.emit("hit", beam_end)
		"chain":
			# 月链：在敌人之间弹跳，每跳一次伤害衰减，最多 count 次；优先英雄。
			var chain_hit: Array = []
			var chain_range := float(s.get("range", 420.0))
			var cur = aim
			if cur == null or h.pos.distance_to(cur.pos) > chain_range:
				cur = nearest_enemy(h, chain_range)
			var from_pos: Vector2 = h.pos
			for k in range(int(s.get("count", 4))):
				if cur == null or not cur.is_alive() or chain_hit.has(cur):
					break
				var falloff: float = pow(float(combat_cfg.get("chain_falloff", 0.82)), float(k))
				deal_damage(cur, dmg * falloff, h)
				cur.slow_t = maxf(cur.slow_t, float(s.get("slow", 0.5)))
				fx.emit("hit", Vector3(cur.pos.x, 32.0, cur.pos.y), color, 0.0)
				beam_fx.emit(Vector3(from_pos.x, 34.0, from_pos.y),
					Vector3(cur.pos.x, 34.0, cur.pos.y), color, 20.0)
				chain_hit.append(cur)
				from_pos = cur.pos
				cur = _chain_target(h, from_pos, float(s.get("jump_range", 260.0)), chain_hit)
			fx.emit("ring", Vector3(from_pos.x, 6.0, from_pos.y), color, 110.0)
		"mark":
			# 猎杀标记：狼嚎范围内所有敌人被标记，短时间承受额外伤害。
			var marked := 0
			for u in units:
				if not u.is_alive() or u.team == h.team:
					continue
				if u.kind == TOWER or u.kind == BASE:
					continue
				if h.pos.distance_to(u.pos) > radius + u.radius:
					continue
				deal_damage(u, dmg, h)
				u.mark_t = maxf(u.mark_t, float(s.get("mark_time", 4.5)))
				u.slow_t = maxf(u.slow_t, float(s.get("slow", 0.9)))
				fx.emit("ring", Vector3(u.pos.x, 6.0, u.pos.y), color, 52.0)
				marked += 1
			fx.emit("cast_roar", Vector3(h.pos.x, 20.0, h.pos.y), color, radius)
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y),
				"标记 %d 个猎物" % marked if marked > 0 else "没有猎物", color)
		"taunt":
			# 潮汐嘲讽：举盾吸引附近敌人，自己获得护盾；敌人被迫先打乌龟。
			h.shield = maxf(h.shield, h.max_hp * float(s.get("shield_pct", 0.22)))
			h.shield_t = maxf(h.shield_t, float(s.get("buff_t", 4.0)))
			var taunted := 0
			for u in units:
				if not u.is_alive() or u.team == h.team or u.kind != HERO:
					continue
				if h.pos.distance_to(u.pos) > radius + u.radius:
					continue
				u.taunt_t = maxf(u.taunt_t, float(s.get("taunt_time", 1.6)))
				u.taunt_src = h
				taunted += 1
			fx.emit("cast_heart", Vector3(h.pos.x, 22.0, h.pos.y), color, radius)
			fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), color, radius)
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y),
				"来打我呀！" if taunted > 0 else "护盾展开", color)
		"fear":
			# 震慑咆哮：把周围敌人吓得往后退，短时间无法正常追击。
			# 英雄不吃减速（否则「吓退」变成慢走），小兵照常减速。
			for u in units:
				if not u.is_alive() or u.team == h.team:
					continue
				if h.pos.distance_to(u.pos) > radius + u.radius:
					continue
				deal_damage(u, dmg, h)
				if u.kind == HERO:
					u.fear_t = maxf(u.fear_t, float(s.get("fear_time", 1.2)))
					u.fear_src = h
				else:
					u.slow_t = maxf(u.slow_t, float(s.get("slow", 0.6)))
			fx.emit("cast_roar", Vector3(h.pos.x, 20.0, h.pos.y), color, radius)
			fx.emit("ring", Vector3(h.pos.x, 6.0, h.pos.y), color, radius)
			sfx.emit("ult", h.pos)
		"spin":
			# 滚动刺球：进入一段时间的高速旋身，持续伤害周围敌人。
			h.spin_t = float(s.get("duration", 2.4))
			h.spin_tick = 0.02
			h.spin_radius = float(s.get("radius", 150.0))
			h.spin_dmg = dmg
			h.spin_color = color
			fx.emit("cast_spin", Vector3(h.pos.x, 22.0, h.pos.y), color, h.spin_radius)
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "滚成刺球！", color)
		"trap":
			# 竹叶陷阱：布在目标脚下并按移动方向预判，延时后定身并伤害。
			var trap_target = aim
			var trap_delay := float(s.get("delay", 0.55))
			var trap_pos: Vector2 = h.pos + aim_dir * float(s.get("range", 460.0)) * 0.72
			if trap_target != null:
				trap_pos = trap_target.pos
				if trap_target.move_dir.length_squared() > 0.01:
					var lead := float(combat_cfg.get("trap_lead", 0.8))
					trap_pos += trap_target.move_dir.normalized() * trap_target.move_speed * trap_delay * lead
			fx.emit("cast_trap", Vector3(trap_pos.x, 12.0, trap_pos.y), color, radius)
			fx.emit("ring", Vector3(trap_pos.x, 6.0, trap_pos.y), color, radius)
			pending.append({
				"t": trap_delay,
				"center": trap_pos,
				"skill": s,
				"src": h,
				"dmg": dmg,
				"radius": radius,
				"slow": float(s.get("slow", 0.0)),
				"stun": float(s.get("stun", 1.0)),
				"heal_pct": 0.0,
				"color": color,
				"style": "spikes",
			})
		"boomerang":
			_throw_boomerang(h, aim_dir, dmg, color, s)
		"heal_zone":
			# 再生水域：放在最残血的队友脚下（含自己），而不是敌人脚下。
			var hz_pos: Vector2 = h.pos
			var best_pct := 0.72
			for a in heroes:
				if not a.is_alive() or a.team != h.team:
					continue
				if a.pos.distance_to(h.pos) > float(s.get("range", 460.0)):
					continue
				var pct: float = a.hp / a.max_hp
				if pct < best_pct:
					best_pct = pct
					hz_pos = a.pos
			var z = make_zone(hz_pos, radius, float(s.get("duration", 4.0)),
				float(s.get("slow", 0.0)), h.team, color)
			z.heal_pct = float(s.get("heal_pct", 0.05))
			zones.append(z)
			fx.emit("cast_waterfall", Vector3(hz_pos.x, 18.0, hz_pos.y), color, radius)
			fx.emit("ring", Vector3(hz_pos.x, 6.0, hz_pos.y), color, radius)
			float_text.emit(Vector3(h.pos.x, h.height + 24.0, h.pos.y), "再生水域！", color)
		"multi":
			var multi_target = aim
			var center: Vector2 = h.pos + aim_dir * 200.0
			if multi_target != null:
				center = _lead_point(h, multi_target, float(s.get("speed", 620.0)))
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
	var front = front_structure(h.team, h.lane_id if five_v_five else -1)
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
	area_damage(dest, radius, float(s.get("dmg", 0.0)) * skill_power(h), h, h.team,
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
		area_damage(center, radius, float(item["dmg"]), src, src.team,
			float(item.get("slow", 0.0)), float(item.get("stun", 0.0)), 0.0)
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
		sfx.emit("boom", center)
		pending.remove_at(i)

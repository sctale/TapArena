extends SceneTree

# 固定种子无头对局：验证 3v3 一局在 5 分钟内结束、5v5 在 8 分钟内结束、先拆塔后破水晶、数值不出现 NaN。
# 运行：godot --headless --path godot --script res://tests/sim_headless.gd

const BattleSimScript = preload("res://scripts/core/battle_sim.gd")
const HERO_IDS := ["tiger", "fox", "rabbit", "bear", "frog", "cat", "panda", "owl", "axolotl", "deer"]
const MATCHES := 10
const DT := 1.0 / 60.0
const MAX_SIM_SECONDS := 320.0


func _init() -> void:
	var failures := 0
	var summaries: Array = []

	for i in range(MATCHES):
		var hero_id: String = HERO_IDS[i % HERO_IDS.size()]
		var difficulty := i % 2
		var seed_value := 20261107 + i
		var sim = BattleSimScript.new()
		sim.setup(hero_id, difficulty, seed_value)

		var elapsed := 0.0
		var steps := 0
		var red_outer_down := false
		var red_inner_down := false
		var bypass := ""
		var lane_check := 0.0
		while not sim.over and elapsed < MAX_SIM_SECONDS:
			sim.step(DT)
			elapsed += DT
			steps += 1

			# 建筑顺序：外塔 → 内塔 → 水晶。终极对决会主动解除保护，不在此列。
			if not sim.sudden_death:
				if not sim.towers_red[0].is_alive():
					red_outer_down = true
				if not sim.towers_red[1].is_alive():
					if not red_outer_down:
						bypass = "红方内塔先于外塔被拆"
					red_inner_down = true
				if sim.base_red.hp < sim.base_red.max_hp and not red_inner_down and bypass == "":
					bypass = "红方双塔未拆完水晶就掉血"

			# 前塔存活时，AI 英雄不能跑到敌方水晶脚下罚站。
			lane_check += DT
			if lane_check >= 1.0:
				lane_check = 0.0
				for h in sim.heroes:
					if not h.is_alive() or h.is_player or bypass != "":
						continue
					if h.team == BattleSimScript.BLUE and sim.is_base_protected(sim.base_red):
						if h.pos.distance_to(sim.base_red.pos) < 260.0:
							bypass = "蓝方英雄在水晶护盾期贴脸 x=%.0f" % h.pos.x
					if h.team == BattleSimScript.RED and sim.is_base_protected(sim.base_blue):
						if h.pos.distance_to(sim.base_blue.pos) < 260.0:
							bypass = "红方英雄在水晶护盾期贴脸 x=%.0f" % h.pos.x

		var issues: Array = []
		if not sim.over:
			issues.append("对局没有结束")
		if sim.clock > sim.match_cap + 0.05:
			issues.append("超过对局上限 clock=%.2f cap=%.1f" % [sim.clock, sim.match_cap])
		if sim.winner != BattleSimScript.BLUE and sim.winner != BattleSimScript.RED:
			issues.append("胜者无效 winner=%d" % sim.winner)
		if sim.heroes.size() != 6:
			issues.append("英雄数量不是 6，实际 %d" % sim.heroes.size())
		if sim.player == null:
			issues.append("玩家英雄缺失")
		if sim.player != null:
			if sim.player.level2_time <= 0.0:
				issues.append("玩家整局没解锁大招")
			elif sim.player.level2_time > 288.0:
				issues.append("大招解锁过晚 %.1fs" % sim.player.level2_time)

		for u in sim.heroes:
			if is_nan(u.pos.x) or is_nan(u.pos.y) or is_nan(u.hp):
				issues.append("英雄数值 NaN uid=%d" % u.uid)
				break

		# 结算页要显示全员战绩：结束原因与英雄输出必须有值。
		if sim.end_reason == "":
			issues.append("结束原因为空")
		var total_damage := 0.0
		for u in sim.heroes:
			if u.damage_dealt < 0.0 or is_nan(u.damage_dealt):
				issues.append("英雄输出异常 uid=%d" % u.uid)
				break
			total_damage += u.damage_dealt
		if total_damage <= 0.0:
			issues.append("英雄输出统计为 0")

		if bypass != "":
			issues.append(bypass)

		# 非终极对决阶段：水晶被打碎前，必须已经拆掉对方两座塔
		if sim.clock < sim.sudden_death_time:
			if sim.winner == BattleSimScript.BLUE and sim.base_red.hp <= 0.0:
				for t in sim.towers_red:
					if t.is_alive():
						issues.append("蓝方绕过红方塔直接破水晶")
						break
			if sim.winner == BattleSimScript.RED and sim.base_blue.hp <= 0.0:
				for t in sim.towers_blue:
					if t.is_alive():
						issues.append("红方绕过蓝方塔直接破水晶")
						break

		var status := "PASS" if issues.is_empty() else "FAIL"
		if not issues.is_empty():
			failures += 1

		var line := "match %02d %s hero=%s diff=%d seed=%d winner=%d clock=%.1f score=%d:%d steps=%d lv2=%.1f towers_b=%d/%d,%d/%d towers_r=%d/%d,%d/%d base=%d/%d minions=%d" % [
			i + 1, status, hero_id, difficulty, seed_value, sim.winner, sim.clock,
			sim.score_blue, sim.score_red, steps,
			sim.player.level2_time if sim.player != null else -1.0,
			sim.towers_blue[0].hp, sim.towers_blue[0].max_hp,
			sim.towers_blue[1].hp, sim.towers_blue[1].max_hp,
			sim.towers_red[0].hp, sim.towers_red[0].max_hp,
			sim.towers_red[1].hp, sim.towers_red[1].max_hp,
			sim.base_blue.hp, sim.base_red.hp, sim.minions.size(),
		]
		if not issues.is_empty():
			line += " issues=" + ", ".join(issues)
		print(line)
		summaries.append(line)

	print("SIM_SUMMARY")
	for line in summaries:
		print("  " + line)

	var rule_issues := _rule_checks()
	if rule_issues.is_empty():
		print("RULE_OK base_protection/base_heal/ult_cd/potion/dash/boss/boss_skills/boss_flying/5v5")
	else:
		failures += 1
		for issue in rule_issues:
			print("RULE_FAIL " + issue)

	var sig_issues := _signature_skill_checks()
	if sig_issues.is_empty():
		print("SIG_OK blink/beam/chain/mark/taunt/fear/spin/trap/boomerang/heal_zone")
	else:
		failures += 1
		for issue in sig_issues:
			print("SIG_FAIL " + issue)

	var map_issues := _map_checks()
	if map_issues.is_empty():
		print("MAP_OK 3lanes/river/jungle/progress")
	else:
		failures += 1
		for issue in map_issues:
			print("MAP_FAIL " + issue)

	var jgl_issues := _jungle_checks()
	if jgl_issues.is_empty():
		print("JGL_OK jungler/camp_buff/assist/respawn")
	else:
		failures += 1
		for issue in jgl_issues:
			print("JGL_FAIL " + issue)

	var fix_issues := _fix_checks()
	if fix_issues.is_empty():
		print("FIX_OK potion/respawn/wave/mark/trap/heal_zone/boomerang/leap/vanish/protection/composition")
	else:
		failures += 1
		for issue in fix_issues:
			print("FIX_FAIL " + issue)

	var pass_issues := _pass_checks()
	if pass_issues.is_empty():
		print("PASS_OK hero_through_minion/hero")
	else:
		failures += 1
		for issue in pass_issues:
			print("PASS_FAIL " + issue)

	var lv_issues := _level_checks()
	if lv_issues.is_empty():
		print("LEVEL_OK xp5/stat_growth/skill_power/3v3_frozen/diagonal_face")
	else:
		failures += 1
		for issue in lv_issues:
			print("LEVEL_FAIL " + issue)

	if failures == 0:
		print("SIM_OK matches=%d dt=%.4f" % [MATCHES, DT])
		quit(0)
	else:
		print("SIM_FAIL failures=%d" % failures)
		quit(1)


func _rule_checks() -> Array:
	var issues: Array = []
	var sim = BattleSimScript.new()
	sim.setup("tiger", 0, 777)

	if sim.front_structure(sim.BLUE) != sim.towers_red[0]:
		issues.append("蓝方推进目标不是红方外塔")
	if sim.front_structure(sim.RED) != sim.towers_blue[0]:
		issues.append("红方推进目标不是蓝方外塔")

	var base_hp: float = sim.base_red.hp
	sim.deal_damage(sim.base_red, 9999.0, sim.player)
	if sim.base_red.hp != base_hp:
		issues.append("外塔存活时水晶受到伤害")

	sim.deal_damage(sim.towers_red[0], 9999.0, sim.player)
	if sim.towers_red[0].is_alive():
		issues.append("外塔未被击破")

	var mid_hp: float = sim.base_red.hp
	sim.deal_damage(sim.base_red, 9999.0, sim.player)
	if sim.base_red.hp != mid_hp:
		issues.append("内塔存活时水晶受到伤害")

	sim.deal_damage(sim.towers_red[1], 9999.0, sim.player)
	if sim.is_base_protected(sim.base_red):
		issues.append("双塔拆除后水晶仍受保护")

	sim.deal_damage(sim.base_red, 9999.0, sim.player)
	sim.step(0.016)
	if not sim.over or sim.winner != BattleSimScript.BLUE:
		issues.append("破水晶后未判定蓝方胜利")

	var sim2 = BattleSimScript.new()
	sim2.setup("tiger", 0, 778)
	sim2.sudden_death = true
	var sd_hp: float = sim2.base_red.hp
	sim2.deal_damage(sim2.base_red, 500.0, sim2.player)
	if sim2.base_red.hp >= sd_hp:
		issues.append("终极对决时水晶仍受保护")

	# 基地回血：圈内要快，出圈立刻停止。
	var sim3 = BattleSimScript.new()
	sim3.setup("tiger", 0, 779)
	var bh = sim3.player
	bh.hp = bh.max_hp * 0.2
	var bh0: float = bh.hp
	for i in range(60):
		sim3.step(1.0 / 60.0)
	if bh.hp < bh0 + bh.max_hp * 0.10:
		issues.append("基地内回血过慢")
	bh.pos = Vector2(1500, 800)
	bh.prev_pos = bh.pos
	var bh1: float = bh.hp
	for i in range(30):
		sim3.step(1.0 / 60.0)
	if bh.hp > bh1 + 1.0:
		issues.append("离开基地后仍在回血")

	# 回血药剂：踩到回血、30 秒刷新。
	var sim4 = BattleSimScript.new()
	sim4.setup("tiger", 0, 781)
	if sim4.potions.size() != 2:
		issues.append("回血药剂数量不是 2")
	else:
		var pot = sim4.potions[0]
		var ph = sim4.player
		ph.pos = pot.pos
		ph.prev_pos = ph.pos
		ph.hp = ph.max_hp * 0.2
		var ph0: float = ph.hp
		sim4.step_potions(0.05)
		if ph.hp <= ph0 + 1.0:
			issues.append("回血药剂未回血")
		if pot.active:
			issues.append("回血药剂未消失")
		ph.pos = Vector2(1500, 800)
		ph.prev_pos = ph.pos
		sim4.step_potions(29.0)
		if pot.active:
			issues.append("回血药剂提前刷新")
		sim4.step_potions(1.5)
		if not pot.active:
			issues.append("回血药剂 30 秒后未刷新")

	# 满血不喝；一塔被拆后不再刷新。
	var sim5 = BattleSimScript.new()
	sim5.setup("tiger", 0, 782)
	var pot5 = sim5.potions[0]
	var full = sim5.player
	full.pos = pot5.pos
	full.prev_pos = full.pos
	sim5.step_potions(0.1)
	if not pot5.active:
		issues.append("满血英雄拿走了回血药剂")
	sim5.towers_blue[0].hp = 0.0
	sim5.step_potions(0.1)
	if pot5.active:
		issues.append("一塔被拆后回血药剂仍存在")
	for i in range(31):
		sim5.step_potions(1.0)
	if pot5.active:
		issues.append("一塔被拆后回血药剂仍刷新")

	# 位移技能必须朝操作方向，不能自动扭头追最近敌人。
	var sim6 = BattleSimScript.new()
	sim6.setup("tiger", 0, 783)
	var dash_hero = sim6.player
	var bait = sim6.heroes[3]
	bait.pos = dash_hero.pos + Vector2(120, 0)
	bait.prev_pos = bait.pos
	sim6.player_move = Vector2(-1, 0)
	dash_hero.move_dir = Vector2(-1, 0)
	var dash_x: float = dash_hero.pos.x
	sim6.try_cast(dash_hero, 0)
	for k in range(30):
		sim6.step_hero(dash_hero, 0.0167)
		if dash_hero.move_skill_t <= 0.0:
			break
	if dash_hero.pos.x > dash_x - 40.0:
		issues.append("位移技能没有朝移动方向")

	# 3 分钟出现峡谷巨兽，帮助优势方推进；被击败后 25 秒复活。
	var sim7 = BattleSimScript.new()
	sim7.setup("tiger", 0, 784)
	sim7.clock = 179.9
	sim7.step(0.2)
	if sim7.boss == null or sim7.boss.kind != BattleSimScript.BOSS:
		issues.append("3 分钟后没有出现峡谷巨兽")
	else:
		if sim7.boss.team != sim7.leading_team():
			issues.append("峡谷巨兽没有加入优势方")
		if sim7.boss.hp <= 0.0:
			issues.append("峡谷巨兽初始血量为 0")
		var foe = sim7.heroes[3] if sim7.boss.team == BattleSimScript.BLUE else sim7.player
		sim7.deal_damage(sim7.boss, 99999.0, foe)
		if sim7.boss.is_alive():
			issues.append("峡谷巨兽无法被击败")
		sim7.step_unit(sim7.boss, 26.0)
		if not sim7.boss.is_alive() or sim7.boss.hp < sim7.boss.max_hp:
			issues.append("峡谷巨兽 25 秒后没有复活")

	# 峡谷巨兽技能：有敌方单位时会先起手，伤害命中并进入冷却。
	var sim9 = BattleSimScript.new()
	sim9.setup("tiger", 0, 784)
	sim9.clock = 179.9
	sim9.step(0.2)
	if sim9.boss == null:
		issues.append("巨兽技能测试没有生成巨兽")
	else:
		var b = sim9.boss
		var foe = sim9.heroes[3] if b.team == BattleSimScript.BLUE else sim9.player
		b.pos = foe.pos + Vector2(-40.0, 0.0)
		b.cds = [0.0, 0.0, 0.0]
		b.atk_timer = 0.0
		foe.invuln_t = 0.0
		var hp0: float = foe.hp
		sim9.step_boss(b, 0.016)
		if b.boss_cast_t <= 0.0:
			issues.append("巨兽技能没有前摇")
		sim9.step_boss(b, 1.0)
		if foe.hp >= hp0:
			issues.append("巨兽技能没有造成伤害")
		if b.cds[0] <= 0.0:
			issues.append("巨兽技能没有进入冷却")

	# 技能最高优先级：移动过程中按技能当帧生效；位移期间不触发顿帧。
	var sim8 = BattleSimScript.new()
	sim8.setup("panda", 0, 785)
	var p8 = sim8.player
	var stop_count: Array = [0]
	sim8.hitstop.connect(func(_s): stop_count[0] += 1)
	p8.prev_pos = p8.pos
	sim8.player_move = Vector2(1, 0)
	sim8.set_skill(0)
	var before_x: float = p8.pos.x
	sim8.step_hero(p8, 0.0167)
	if p8.cds[0] <= 0.0:
		issues.append("移动中的技能输入被丢弃")
	if p8.move_skill_t <= 0.0:
		issues.append("位移没有进入平滑位移状态")
	for k in range(40):
		sim8.step_hero(p8, 0.0167)
		if p8.move_skill_t <= 0.0:
			break
	if p8.pos.x < before_x + 150.0:
		issues.append("平滑位移结束后没有到达目标")
	if p8.dash_t <= 0.0:
		issues.append("位移后没有记录位移状态")
	stop_count[0] = 0
	var dummy = sim8.heroes[3]
	sim8.hit_with_fx(dummy, 120.0, p8)
	if stop_count[0] != 0:
		issues.append("位移期间触发了顿帧")
	p8.dash_t = 0.0
	p8.move_skill_t = 0.0
	sim8.hit_with_fx(dummy, 120.0, p8)
	if stop_count[0] != 1:
		issues.append("位移结束后没有恢复顿帧")

	# ---- 5v5：三路、三塔、野区、两位数的英雄与 8 分钟上限 ----
	var simA = BattleSimScript.new()
	simA.setup("wolf", 0, 9100, true)
	if not simA.five_v_five:
		issues.append("5v5 模式标记没有生效")
	if simA.heroes.size() != 10:
		issues.append("5v5 英雄数量不是 10，实际 %d" % simA.heroes.size())
	if simA.towers_blue.size() != 3 or simA.towers_red.size() != 3:
		issues.append("5v5 每方应有 3 座塔")
	if simA.lane_paths.size() != 3:
		issues.append("5v5 应有 3 条分路")
	var camp_count := 0
	var lane_set: Dictionary = {}
	var junglers := 0
	for u in simA.units:
		if u.kind == BattleSimScript.JUNGLE:
			camp_count += 1
		if u.kind == BattleSimScript.HERO:
			if u.lane_id >= 0:
				lane_set[u.lane_id] = true
			if u.is_jungler:
				junglers += 1
	if camp_count != 6:
		issues.append("5v5 野区营地不是 6，实际 %d" % camp_count)
	if lane_set.size() != 3:
		issues.append("5v5 英雄没有分布到三条路")
	if junglers != 2:
		issues.append("5v5 双方打野位不是各 1 名，实际 %d" % junglers)
	var tower_ys: Dictionary = {}
	for t in simA.towers_blue:
		tower_ys[int(t.pos.y)] = true
	if tower_ys.size() != 3:
		issues.append("5v5 三座塔不在三条路上")
	# 5v5 允许拆掉两座塔后直接进攻水晶；只掉一座时仍受保护。
	simA.deal_damage(simA.towers_red[0], 99999.0, simA.player)
	if not simA.is_base_protected(simA.base_red):
		issues.append("5v5 只掉一座塔时水晶就失去保护")
	simA.deal_damage(simA.towers_red[1], 99999.0, simA.player)
	if simA.is_base_protected(simA.base_red):
		issues.append("5v5 拆掉两座塔后水晶仍受保护")

	var simB = BattleSimScript.new()
	simB.setup("turtle", 0, 9001, true)
	var t5 := 0.0
	while not simB.over and t5 < 540.0:
		simB.step(DT)
		t5 += DT
	if not simB.over:
		issues.append("5v5 对局没有结束")
	if simB.clock > simB.match_cap + 0.05:
		issues.append("5v5 超过对局上限 clock=%.1f cap=%.1f" % [simB.clock, simB.match_cap])
	if simB.heroes.size() != 10:
		issues.append("5v5 对局结束后英雄数量不是 10")
	if camp_count == 0:
		issues.append("5v5 没有野怪")

	# ---- BOSS 第二形态：复活后带翅膀飞行，技能切换为陨石/旋风 ----
	var simf = BattleSimScript.new()
	simf.setup("tiger", 0, 9200)
	simf.clock = 179.9
	simf.step(0.2)
	if simf.boss == null:
		issues.append("飞行 BOSS 测试没有生成巨兽")
	else:
		var bf = simf.boss
		if bf.boss_flying:
			issues.append("巨兽第一次出现不应是飞行形态")
		var bf_foe = simf.heroes[3] if bf.team == BattleSimScript.BLUE else simf.player
		simf.deal_damage(bf, 99999.0, bf_foe)
		simf.step_unit(bf, 26.0)
		if not bf.boss_flying or bf.boss_phase != 2:
			issues.append("巨兽第二次出现没有切换飞行形态")
		bf.pos = bf_foe.pos + Vector2(-70.0, 0.0)
		bf.prev_pos = bf.pos
		bf.cds = [0.0, 0.0, 0.0]
		bf.atk_timer = 0.0
		bf.boss_skill = ""
		bf.boss_cast_t = 0.0
		bf.stun_t = 0.0
		bf_foe.invuln_t = 0.0
		var fhp0: float = bf_foe.hp
		simf.step_boss(bf, 0.016)
		if bf.boss_skill != "meteor":
			issues.append("飞行巨兽没有起手陨石")
		simf.step_boss(bf, 2.0)
		if bf_foe.hp >= fhp0:
			issues.append("飞行巨兽的陨石没有造成伤害")
		bf.cds = [3.0, 0.0, 0.0]
		bf.boss_skill = ""
		bf.boss_cast_t = 0.0
		bf_foe.hp = maxf(bf_foe.max_hp * 0.7, 500.0)
		bf_foe.invuln_t = 0.0
		var chp0: float = bf_foe.hp
		simf.step_boss(bf, 0.016)
		if bf.boss_skill != "cyclone":
			issues.append("飞行巨兽没有起手旋风")
		simf.step_boss(bf, 2.0)
		if bf_foe.hp >= chp0:
			issues.append("飞行巨兽的旋风没有造成伤害")

	# 所有英雄的大招都应立刻进入冷却。
	for id in HERO_IDS:
		var simu = BattleSimScript.new()
		simu.setup(id, 0, 780)
		simu.player.level = 2
		simu.player.xp = simu.xp_to_level2
		simu.try_cast(simu.player, 2)
		if simu.player.cds[2] <= 0.0:
			issues.append("%s 大招未立即进入冷却" % id)

	return issues


func _pass_checks() -> Array:
	# 王者荣耀式无碰撞：英雄可以直接穿过友方小兵/友方英雄/敌方英雄，移动不被身体挡住。
	var issues: Array = []
	var sim = BattleSimScript.new()
	sim.setup("tiger", 0, 7300)
	var p = sim.player
	p.pos = Vector2(400, 800)
	p.prev_pos = p.pos
	p.invuln_t = 99.0
	sim.spawn_wave(BattleSimScript.BLUE)
	var ally_minion = null
	for m in sim.minions:
		if m.team == BattleSimScript.BLUE and m.is_alive():
			ally_minion = m
			break
	if ally_minion == null:
		issues.append("穿透测试没有生成友方小兵")
	else:
		ally_minion.pos = Vector2(450, 800)
		ally_minion.prev_pos = ally_minion.pos
	var ally_hero = null
	for h in sim.heroes:
		if h.team == BattleSimScript.BLUE and h != p:
			ally_hero = h
			break
	if ally_hero != null:
		ally_hero.pos = Vector2(490, 800)
		ally_hero.prev_pos = ally_hero.pos
	var foe = null
	for h in sim.heroes:
		if h.team == BattleSimScript.RED:
			foe = h
			break
	if foe != null:
		foe.pos = Vector2(540, 800)
		foe.prev_pos = foe.pos
	sim.player_move = Vector2(1, 0)
	p.move_dir = Vector2(1, 0)
	for i in range(60):
		sim.step(1.0 / 60.0)
	if p.pos.x < 600.0:
		issues.append("英雄没有穿过身前单位 x=%.0f" % p.pos.x)
	return issues


func _level_checks() -> Array:
	var issues: Array = []
	# 5v5 五级成长：阈值 110/380/900/1500，属性 ×1.36 / ×1.32，技能 ×1.40。
	var s1 = BattleSimScript.new()
	s1.setup("fox", 0, 9900, true)
	var p1 = s1.player
	var base_hp := float(p1.def.get("hp", 900))
	var base_dmg := float(p1.def.get("dmg", 45))
	if s1.level_cap != 5:
		issues.append("5v5 等级上限不是 5，实际 %d" % s1.level_cap)
	s1.add_xp(p1, 1499.0)
	if p1.level != 4:
		issues.append("5v5 1499xp 等级不是 4，实际 %d" % p1.level)
	s1.add_xp(p1, 1.0)
	if p1.level != 5:
		issues.append("5v5 1500xp 等级不是 5，实际 %d" % p1.level)
	if absf(p1.max_hp - base_hp * 1.36) > 0.5:
		issues.append("5v5 五级血量不是 ×1.36，实际 %.1f 基础 %.1f" % [p1.max_hp, base_hp])
	if absf(p1.dmg - base_dmg * 1.32) > 0.01:
		issues.append("5v5 五级普攻不是 ×1.32，实际 %.2f 基础 %.2f" % [p1.dmg, base_dmg])
	if absf(p1.hp - p1.max_hp) > 0.5:
		issues.append("升级没有补回新增血量 hp=%.1f max=%.1f" % [p1.hp, p1.max_hp])
	s1.add_xp(p1, 500.0)
	if p1.level != 5 or absf(p1.max_hp - base_hp * 1.36) > 0.5:
		issues.append("5v5 满级后仍然成长")
	if absf(s1.skill_power(p1) - 1.4) > 0.001:
		issues.append("5v5 五级技能强度不是 ×1.4，实际 %.3f" % s1.skill_power(p1))
	# 3v3 冻结：2 级封顶、零属性成长、技能强度 1.0。
	var s2 = BattleSimScript.new()
	s2.setup("fox", 0, 9901)
	var p2 = s2.player
	var base2_hp := float(p2.def.get("hp", 900))
	var base2_dmg := float(p2.def.get("dmg", 45))
	s2.add_xp(p2, 9999.0)
	if p2.level != 2:
		issues.append("3v3 等级上限不是 2，实际 %d" % p2.level)
	if absf(p2.max_hp - base2_hp) > 0.01 or absf(p2.dmg - base2_dmg) > 0.01:
		issues.append("3v3 升级产生了属性成长")
	if absf(s2.skill_power(p2) - 1.0) > 0.001:
		issues.append("3v3 技能强度不是 1.0")
	# 技能伤害 ×1.4：找一个带伤害的投射类技能实测（任意英雄的任意技能位）。
	var cast_id := ""
	var cast_index := -1
	for hid in HERO_IDS:
		var probe = BattleSimScript.new()
		probe.setup(hid, 0, 9902, true)
		for i in range(probe.player.skills.size()):
			var sk: Dictionary = probe.player.skills[i]
			var kind := str(sk.get("kind", ""))
			if float(sk.get("dmg", 0.0)) > 0.0 \
					and (kind == "projectile" or kind == "radial" or kind == "splash" or kind == "boomerang"):
				cast_id = hid
				cast_index = i
				break
		if cast_index >= 0:
			break
	if cast_index >= 0:
		var l1 = BattleSimScript.new()
		l1.setup(cast_id, 0, 9903, true)
		var b1: int = l1.shots.size()
		l1.try_cast(l1.player, cast_index)
		var dmg1 := 0.0
		for i in range(b1, l1.shots.size()):
			dmg1 = l1.shots[i].dmg
		var l5 = BattleSimScript.new()
		l5.setup(cast_id, 0, 9904, true)
		l5.player.level = 5
		var b5: int = l5.shots.size()
		l5.try_cast(l5.player, cast_index)
		var dmg5 := 0.0
		for i in range(b5, l5.shots.size()):
			dmg5 = l5.shots[i].dmg
		if dmg1 <= 0.0 or absf(dmg5 / dmg1 - 1.4) > 0.01:
			issues.append("5v5 五级技能伤害不是 ×1.4（%s 技能%d：%.1f→%.1f）" % [cast_id, cast_index, dmg1, dmg5])
	# 斜向移动：位置与 face_dir 都按 45° 走。
	var s4 = BattleSimScript.new()
	s4.setup("fox", 0, 9905)
	var p4 = s4.player
	var x0: float = p4.pos.x
	var y0: float = p4.pos.y
	s4.player_move = Vector2(0.7, -0.7)
	for k in range(60):
		s4.step_hero(p4, 1.0 / 60.0)
	var dx: float = p4.pos.x - x0
	var dy: float = p4.pos.y - y0
	if dx <= 0.0 or dy >= 0.0:
		issues.append("斜向移动没有同时改变 x/y dx=%.1f dy=%.1f" % [dx, dy])
	if absf(absf(dx) - absf(dy)) > maxf(0.5, absf(dx) * 0.05):
		issues.append("斜向移动比例不对 dx=%.1f dy=%.1f" % [dx, dy])
	if p4.face_dir.distance_to(Vector2(0.7071, -0.7071)) > 0.01:
		issues.append("face_dir 与斜向移动方向不一致 %s" % str(p4.face_dir))
	# 攻击时 face_dir 指向目标。
	var s5 = BattleSimScript.new()
	s5.setup("fox", 0, 9906)
	var p5 = s5.player
	var e5 = s5.heroes[3]
	e5.pos = p5.pos + Vector2(60.0, -130.0)
	e5.prev_pos = e5.pos
	p5.atk_timer = 0.0
	s5.player_move = Vector2.ZERO
	if p5.attack_range + p5.radius < 150.0:
		e5.pos = p5.pos + Vector2(60.0, -60.0)
		e5.prev_pos = e5.pos
	s5.step_hero(p5, 1.0 / 60.0)
	var want: Vector2 = (e5.pos - p5.pos).normalized()
	if p5.face_dir.distance_to(want) > 0.05:
		issues.append("普攻时 face_dir 没有指向目标 %s vs %s" % [str(p5.face_dir), str(want)])
	# 挥砍期间朝向稳定：攻击帧朝目标，动作结束再回到移动方向。
	var s6 = BattleSimScript.new()
	s6.setup("fox", 0, 9907)
	var p6 = s6.player
	var e6 = s6.heroes[3]
	e6.pos = p6.pos + Vector2(60.0, -40.0)
	e6.prev_pos = e6.pos
	e6.invuln_t = 0.0
	s6.player_move = Vector2(1, 0)
	p6.atk_timer = 0.0
	s6.step_unit(p6, 1.0 / 60.0)
	var want_atk: Vector2 = (e6.pos - p6.pos).normalized()
	if p6.face_dir.distance_to(want_atk) > 0.05:
		issues.append("挥砍帧 face_dir 没有指向目标")
	s6.step_unit(p6, 1.0 / 60.0)
	if p6.face_dir.distance_to(want_atk) > 0.05:
		issues.append("挥砍期间朝向被移动方向覆盖")
	for k in range(30):
		s6.step_unit(p6, 1.0 / 60.0)
	if p6.face_dir.distance_to(Vector2(1, 0)) > 0.2:
		issues.append("挥砍结束后朝向没有回到移动方向 %s" % str(p6.face_dir))
	# 复活后朝向敌方基地。
	var s7 = BattleSimScript.new()
	s7.setup("fox", 0, 9908)
	var p7r = s7.player
	s7.kill(p7r, null)
	p7r.respawn_t = 0.0
	s7.step(0.02)
	var want_r: Vector2 = (s7.base_red.pos - p7r.pos).normalized()
	if p7r.face_dir.distance_to(want_r) > 0.05:
		issues.append("复活后 face_dir 没有朝向敌方基地")
	# 巨兽普攻朝目标。
	var s8 = BattleSimScript.new()
	s8.setup("fox", 0, 9909)
	s8.clock = 179.9
	s8.step(0.2)
	if s8.boss == null:
		issues.append("巨兽朝向测试没有生成巨兽")
	else:
		var bb = s8.boss
		var foe_b = s8.heroes[3] if bb.team == BattleSimScript.BLUE else s8.player
		bb.pos = foe_b.pos + Vector2(-60.0, 0.0)
		bb.prev_pos = bb.pos
		bb.cds = [9.0, 9.0, 9.0]
		bb.atk_timer = 0.0
		bb.stun_t = 0.0
		foe_b.invuln_t = 0.0
		s8.step_boss(bb, 0.016)
		var want_b: Vector2 = (foe_b.pos - bb.pos).normalized()
		if bb.face_dir.distance_to(want_b) > 0.05:
			issues.append("巨兽普攻 face_dir 没有指向目标")
	# 位移/旋转类技能同样吃等级成长。
	var all_ids: Array = HERO_IDS.duplicate()
	for extra in ["wolf", "hedgehog", "redpanda", "turtle", "crane"]:
		if not all_ids.has(extra):
			all_ids.append(extra)
	for gk in ["dash", "leap", "spin"]:
		var gid := ""
		var gidx := -1
		var gunlock := false
		for hid in all_ids:
			var pr = BattleSimScript.new()
			pr.setup(hid, 0, 9950, true)
			for i in range(pr.player.skills.size()):
				var sk: Dictionary = pr.player.skills[i]
				if str(sk.get("kind", "")) == gk and float(sk.get("dmg", 0.0)) > 0.0:
					gid = hid
					gidx = i
					gunlock = bool(sk.get("unlock_at_2", false))
					break
			if gidx >= 0:
				break
		if gidx < 0:
			issues.append("找不到 %s 技能用于成长测试" % gk)
			continue
		var lv_low := 2 if gunlock else 1
		var lo = BattleSimScript.new()
		lo.setup(gid, 0, 9951, true)
		var hi = BattleSimScript.new()
		hi.setup(gid, 0, 9952, true)
		lo.player.level = lv_low
		hi.player.level = 5
		lo.player_move = Vector2(1, 0)
		hi.player_move = Vector2(1, 0)
		var dmg_low := 0.0
		var dmg_high := 0.0
		if gk == "spin":
			lo.try_cast(lo.player, gidx)
			hi.try_cast(hi.player, gidx)
			dmg_low = lo.player.spin_dmg
			dmg_high = hi.player.spin_dmg
		else:
			var fa = null
			var fb = null
			for hh in lo.heroes:
				if hh.team == BattleSimScript.RED:
					fa = hh
					break
			for hh in hi.heroes:
				if hh.team == BattleSimScript.RED:
					fb = hh
					break
			fa.pos = lo.player.pos + Vector2(170.0, 0.0)
			fb.pos = hi.player.pos + Vector2(170.0, 0.0)
			fa.prev_pos = fa.pos
			fb.prev_pos = fb.pos
			fa.invuln_t = 0.0
			fb.invuln_t = 0.0
			lo.player.atk_timer = 99.0
			hi.player.atk_timer = 99.0
			var ha: float = fa.hp
			var hb: float = fb.hp
			lo.try_cast(lo.player, gidx)
			hi.try_cast(hi.player, gidx)
			for k in range(60):
				lo.step_hero(lo.player, 1.0 / 60.0)
				hi.step_hero(hi.player, 1.0 / 60.0)
				if lo.player.move_skill_t <= 0.0 and hi.player.move_skill_t <= 0.0:
					break
			dmg_low = ha - fa.hp
			dmg_high = hb - fb.hp
		var want_ratio: float = 1.4 / (1.0 + 0.10 * float(lv_low - 1))
		if dmg_low <= 0.0 or absf(dmg_high / dmg_low - want_ratio) > 0.02:
			issues.append("%s 技能强度不是 ×%.2f（%.1f→%.1f）" % [gk, want_ratio, dmg_low, dmg_high])
	return issues


func _signature_skill_checks() -> Array:
	var issues: Array = []
	# 幻影闪：不是连续位移，而是一步换位。
	var s1 = BattleSimScript.new()
	s1.setup("fox", 0, 9300)
	var p1 = s1.player
	var x0: float = p1.pos.x
	s1.player_move = Vector2.RIGHT
	p1.move_dir = Vector2.RIGHT
	s1.try_cast(p1, 1)
	if absf(p1.pos.x - x0) < 150.0:
		issues.append("幻影闪没有瞬间换位")

	# 鹤羽贯日：一条直线同时打到多个敌人。
	var s2 = BattleSimScript.new()
	s2.setup("crane", 0, 9301)
	var p2 = s2.player
	var e2 = s2.heroes[3]
	e2.pos = p2.pos + Vector2(180.0, 0.0)
	e2.prev_pos = e2.pos
	e2.invuln_t = 0.0
	var e2hp: float = e2.hp
	s2.try_cast(p2, 1)
	if e2.hp >= e2hp:
		issues.append("鹤羽贯日没有命中直线上的敌人")

	# 月链：第一次命中后可以在敌人之间继续弹。
	var s3 = BattleSimScript.new()
	s3.setup("owl", 0, 9302)
	var p3 = s3.player
	var e3a = s3.heroes[3]
	var e3b = s3.heroes[4]
	e3a.pos = p3.pos + Vector2(180.0, 0.0)
	e3b.pos = e3a.pos + Vector2(160.0, 0.0)
	e3a.prev_pos = e3a.pos
	e3b.prev_pos = e3b.pos
	var a_hp: float = e3a.hp
	var b_hp: float = e3b.hp
	s3.try_cast(p3, 1)
	if e3a.hp >= a_hp or e3b.hp >= b_hp:
		issues.append("月链没有在敌人之间弹跳")

	# 猎杀标记：被标记的目标受到更多伤害。
	var s4 = BattleSimScript.new()
	s4.setup("wolf", 0, 9303)
	var p4 = s4.player
	var e4 = s4.heroes[3]
	e4.pos = p4.pos + Vector2(140.0, 0.0)
	e4.prev_pos = e4.pos
	s4.try_cast(p4, 1)
	if e4.mark_t <= 0.0:
		issues.append("猎杀标记没有生效")
	else:
		e4.invuln_t = 0.0
		var h0: float = e4.hp
		s4.deal_damage(e4, 100.0, p4)
		var marked_dmg: float = h0 - e4.hp
		e4.mark_t = 0.0
		var h1: float = e4.hp
		s4.deal_damage(e4, 100.0, p4)
		if h1 - e4.hp >= marked_dmg:
			issues.append("猎杀标记没有提高伤害")

	# 嘲讽：敌人被强制把目标换成乌龟。
	var s5 = BattleSimScript.new()
	s5.setup("turtle", 0, 9304)
	var p5 = s5.player
	var e5 = s5.heroes[3]
	e5.pos = p5.pos + Vector2(150.0, 0.0)
	e5.prev_pos = e5.pos
	s5.try_cast(p5, 1)
	if e5.taunt_t <= 0.0 or e5.taunt_src != p5:
		issues.append("潮汐嘲讽没有拉住敌人")

	# 震慑咆哮：周围敌人进入恐惧。
	var s6 = BattleSimScript.new()
	s6.setup("tiger", 0, 9305)
	var p6 = s6.player
	var e6 = s6.heroes[3]
	e6.pos = p6.pos + Vector2(150.0, 0.0)
	e6.prev_pos = e6.pos
	s6.try_cast(p6, 1)
	if e6.fear_t <= 0.0 or e6.fear_src != p6:
		issues.append("震慑咆哮没有吓退敌人")

	# 滚动刺球：旋身期间持续伤害身边敌人。
	var s7 = BattleSimScript.new()
	s7.setup("hedgehog", 0, 9306)
	var p7 = s7.player
	p7.level = 2
	var e7 = s7.heroes[3]
	e7.pos = p7.pos + Vector2(90.0, 0.0)
	e7.prev_pos = e7.pos
	e7.invuln_t = 0.0
	s7.try_cast(p7, 2)
	if p7.spin_t <= 0.0:
		issues.append("滚动刺球没有进入旋身状态")
	else:
		var h7: float = e7.hp
		s7.step_hero(p7, 0.35)
		if e7.hp >= h7:
			issues.append("滚动刺球没有造成持续伤害")

	# 竹叶陷阱：延时触发并定身。
	var s8 = BattleSimScript.new()
	s8.setup("redpanda", 0, 9307)
	var p8 = s8.player
	var e8 = s8.heroes[3]
	e8.pos = p8.pos + Vector2(170.0, 0.0)
	e8.prev_pos = e8.pos
	e8.invuln_t = 0.0
	s8.try_cast(p8, 1)
	var h8: float = e8.hp
	s8.step_pending(0.8)
	if e8.hp >= h8 or e8.stun_t <= 0.0:
		issues.append("竹叶陷阱没有定身或伤害")

	# 回旋尖刺：飞出折返后可再次命中。
	var s9 = BattleSimScript.new()
	s9.setup("hedgehog", 0, 9308)
	var p9 = s9.player
	var e9 = s9.heroes[3]
	e9.pos = p9.pos + Vector2(180.0, 0.0)
	e9.prev_pos = e9.pos
	e9.invuln_t = 0.0
	var h9: float = e9.hp
	s9.try_cast(p9, 0)
	for k in range(90):
		s9.step_projectiles(1.0 / 60.0)
	if e9.hp >= h9:
		issues.append("回旋尖刺没有命中")

	# 再生水域：友军站在水里持续回血。
	var s10 = BattleSimScript.new()
	s10.setup("axolotl", 0, 9309)
	var p10 = s10.player
	p10.level = 2
	var a10 = s10.heroes[1]
	a10.hp = a10.max_hp * 0.5
	a10.pos = p10.pos + Vector2(60.0, 0.0)
	a10.prev_pos = a10.pos
	s10.try_cast(p10, 2)
	var z10 = s10.make_zone(a10.pos, 220.0, 4.0, 0.0, p10.team, Color.WHITE)
	z10.heal_pct = 0.05
	s10.zones.append(z10)
	var ahp: float = a10.hp
	s10.step_zones(0.5)
	if a10.hp <= ahp:
		issues.append("再生水域没有治疗友军")

	return issues


class JungleProbe extends BattleSim:
	var jg_kills := 0

	func kill(target, killer) -> void:
		if target.kind == JUNGLE and killer != null and killer.is_jungler:
			jg_kills += 1
		super(target, killer)


func _dist_to_path(p: Vector2, path: Array) -> float:
	var best := 1.0e20
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var ab: Vector2 = b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, (a + ab * t).distance_to(p))
	return best


func _map_checks() -> Array:
	var issues: Array = []
	var sim = BattleSimScript.new()
	sim.setup("fox", 0, 9500, true)
	if sim.map_w != 3600.0 or sim.map_h != 3600.0:
		issues.append("5v5 地图不是 3600×3600（实际 %.0fx%.0f）" % [sim.map_w, sim.map_h])
	if sim.lane_paths.size() != 3:
		issues.append("5v5 不是三条路")
	# 塔位置：蓝塔在路径 30-45%，红塔在 55-70%。
	for l in range(mini(3, sim.lane_paths.size())):
		var path: Array = sim.lane_paths[l]
		if path.size() < 7:
			issues.append("第 %d 路点数不足" % l)
			continue
		var total: float = sim.path_length(path)
		var bp: float = sim.lane_progress(l, sim.towers_blue[l].pos) / total
		var rp: float = sim.lane_progress(l, sim.towers_red[l].pos) / total
		if bp < 0.30 or bp > 0.45:
			issues.append("第 %d 路蓝塔位置 %.2f 不在 30-45%%" % [l, bp])
		if rp < 0.55 or rp > 0.70:
			issues.append("第 %d 路红塔位置 %.2f 不在 55-70%%" % [l, rp])
		if absf(sim.lane_progress(l, path[0])) > 1.0:
			issues.append("第 %d 路起点进度不是 0" % l)
		if absf(sim.lane_progress(l, path[path.size() - 1]) - total) > 1.0:
			issues.append("第 %d 路终点进度不是全长" % l)
		var mid: Vector2 = path[3]
		if sim.point_at_progress(l, sim.lane_progress(l, mid)).distance_to(mid) > 2.0:
			issues.append("第 %d 路进度往返不一致" % l)
	# 旋转对称：上路↔下路，中路自对称。
	for l in range(3):
		var pb: Array = sim.lane_paths[l]
		var pr: Array = sim.lane_paths[2 - l]
		for i in range(pb.size()):
			var src: Vector2 = pb[i]
			var mirror := Vector2(sim.map_w - src.x, sim.map_h - src.y)
			var dst: Vector2 = pr[pr.size() - 1 - i]
			if mirror.distance_to(dst) > 1.0:
				issues.append("第 %d 路不满足 180° 旋转对称" % l)
				break
	# 营地：离兵线 ≥220；河蟹在河道、野猪/灰狼离河道 ≥300；镜像成对。
	for u in sim.units:
		if u.kind != BattleSimScript.JUNGLE:
			continue
		var lane_min := 1.0e20
		for l in range(3):
			lane_min = minf(lane_min, _dist_to_path(u.pos, sim.lane_paths[l]))
		if lane_min < 220.0:
			issues.append("%s 离兵线太近 %.0f" % [u.display_name, lane_min])
		var river_d: float = _dist_to_path(u.pos, sim.river)
		if u.jungle_kind == "crab":
			if river_d > 130.0:
				issues.append("河蟹不在河道里 %.0f" % river_d)
		elif river_d < 300.0:
			issues.append("%s 离河道太近 %.0f" % [u.display_name, river_d])
		var mirror_c := Vector2(sim.map_w - u.pos.x, sim.map_h - u.pos.y)
		var found := false
		for o in sim.units:
			if o.kind == BattleSimScript.JUNGLE and o.jungle_kind == u.jungle_kind \
					and o.pos.distance_to(mirror_c) < 1.0:
				found = true
				break
		if not found:
			issues.append("%s 缺少镜像营地" % u.display_name)
	# 30 秒实跑：三路都有小兵，且上/下路确实走了竖直段。
	var sim2 = BattleSimScript.new()
	sim2.setup("fox", 0, 9501, true)
	var top_vertical := false
	var bot_vertical := false
	for k in range(1800):
		sim2.step(1.0 / 60.0)
		for m in sim2.minions:
			if m.lane_id == 0 and m.pos.x < sim2.map_w * 0.18 and m.pos.y < sim2.map_h * 0.60:
				top_vertical = true
			if m.lane_id == 2 and m.pos.y > sim2.map_h * 0.82 and m.pos.x > sim2.map_w * 0.625:
				bot_vertical = true
	if sim2.minions.size() == 0:
		issues.append("5v5 30 秒没有小兵")
	for l in range(3):
		var seen := false
		for m in sim2.minions:
			if m.lane_id == l:
				seen = true
				break
		if not seen:
			issues.append("第 %d 路 30 秒内没有小兵" % l)
	if not top_vertical:
		issues.append("上路小兵没有经过竖直段")
	if not bot_vertical:
		issues.append("下路小兵没有经过竖直段")
	return issues


func _jungle_checks() -> Array:
	var issues: Array = []
	var sim = BattleSimScript.new()
	sim.setup("fox", 0, 9600, true)
	var junglers := 0
	var jg = null
	for h in sim.heroes:
		if h.is_jungler:
			junglers += 1
			if h.team == BattleSimScript.BLUE:
				jg = h
	if junglers != 2 or jg == null:
		issues.append("5v5 打野位配置不对 junglers=%d" % junglers)
		return issues
	# 猎狼 buff：经验、增伤计时、实测伤害。
	var wolf_camp = null
	for u in sim.units:
		if u.kind == BattleSimScript.JUNGLE and u.jungle_kind == "wolf":
			wolf_camp = u
			break
	if wolf_camp == null:
		issues.append("找不到灰狼营地")
		return issues
	sim.deal_damage(wolf_camp, 99999.0, jg)
	if jg.buff_dmg_t < 19.0 or jg.buff_dmg_pct < 0.09:
		issues.append("猎狼增益没有生效 t=%.1f pct=%.2f" % [jg.buff_dmg_t, jg.buff_dmg_pct])
	var foe = null
	for h in sim.heroes:
		if h.team == BattleSimScript.RED:
			foe = h
			break
	foe.invuln_t = 0.0
	foe.shield = 0.0
	foe.mark_t = 0.0
	var fhp: float = foe.hp
	sim.deal_damage(foe, 100.0, jg)
	var dealt: float = fhp - foe.hp
	if dealt < 109.0 or dealt > 111.0:
		issues.append("猎狼增益伤害不是 ×1.10，实际 %.1f" % dealt)
	# 迅捷蟹 buff：移速 ×1.15。
	var crab = null
	for u in sim.units:
		if u.kind == BattleSimScript.JUNGLE and u.jungle_kind == "crab":
			crab = u
			break
	if crab != null:
		sim.deal_damage(crab, 99999.0, jg)
		var spd: float = sim.speed_of(jg)
		if jg.buff_speed_t <= 0.0 or absf(spd - jg.move_speed * 1.15) > 1.0:
			issues.append("迅捷蟹增益移速不对 %.1f" % spd)
	# 助攻经验：700 内队友分一半。
	var ally = null
	for h in sim.heroes:
		if h.team == BattleSimScript.BLUE and h != jg:
			ally = h
			break
	var boar = null
	for u in sim.units:
		if u.kind == BattleSimScript.JUNGLE and u.jungle_kind == "boar" and u.is_alive():
			boar = u
			break
	if boar != null and ally != null:
		ally.pos = boar.pos + Vector2(120, 0)
		var axp: float = ally.xp
		sim.deal_damage(boar, 99999.0, jg)
		if ally.xp - axp < 40.0:
			issues.append("野怪助攻经验没有给到队友 %.0f" % (ally.xp - axp))
	# 营地清状态并按时刷新。
	if boar != null:
		boar.mark_t = 2.0
		sim.step_unit(boar, 46.0)
		if not boar.is_alive() or boar.mark_t > 0.0:
			issues.append("营地 45 秒没有满血刷新或标记没清")
	# 90 秒实跑：打野必须真的刷野。
	var probe = JungleProbe.new()
	probe.setup("fox", 0, 9700, true)
	var blue_jg = null
	for h in probe.heroes:
		if h.team == BattleSimScript.BLUE and h.is_jungler:
			blue_jg = h
	var jungle_samples := 0
	var jungle_ok := 0
	var enemy_half := 0
	for k in range(5400):
		probe.step(1.0 / 60.0)
		if k % 120 == 0 and probe.clock <= 60.0 and blue_jg != null:
			jungle_samples += 1
			var lane_min := 1.0e20
			for l in range(3):
				lane_min = minf(lane_min, _dist_to_path(blue_jg.pos, probe.lane_paths[l]))
			if lane_min > 200.0:
				jungle_ok += 1
			if blue_jg.is_alive() and blue_jg.fear_t <= 0.0 and blue_jg.taunt_t <= 0.0 \
					and blue_jg.pos.distance_to(probe.base_red.pos) + 100.0 < blue_jg.pos.distance_to(probe.base_blue.pos):
				enemy_half += 1
	var ratio: float = float(jungle_ok) / maxf(1.0, float(jungle_samples))
	if probe.jg_kills < 3:
		issues.append("打野 90 秒击杀营地不足 3，实际 %d" % probe.jg_kills)
	# 跨野区转场会经过兵线，取 50% 作为下限；关键是绝不进敌方半场。
	if ratio < 0.5:
		issues.append("打野前 60 秒在野区时间不足 50%%，实际 %.0f%%" % (ratio * 100.0))
	if enemy_half > 0:
		issues.append("打野进入了敌方半场 %d 次采样" % enemy_half)
	if blue_jg != null and blue_jg.level < 2:
		issues.append("打野前 60 秒没有到 2 级")
	return issues


func _fix_checks() -> Array:
	var issues: Array = []
	# 药剂守卫：拆上路塔只影响上路药剂。
	var s1 = BattleSimScript.new()
	s1.setup("fox", 0, 9800, true)
	s1.kill(s1.towers_blue[0], null)
	s1.step_potions(0.02)
	var active := 0
	for p in s1.potions:
		if p.team == BattleSimScript.BLUE and p.active:
			active += 1
	if active != 2:
		issues.append("拆上路塔后蓝方仍活跃药剂不是 2，实际 %d" % active)
	# 复活清状态。
	var s2 = BattleSimScript.new()
	s2.setup("hedgehog", 0, 9801, true)
	var hh = s2.player
	hh.spin_t = 2.0
	hh.mark_t = 3.0
	hh.fear_t = 1.0
	hh.taunt_t = 1.0
	hh.buff_dmg_t = 5.0
	hh.buff_speed_t = 5.0
	s2.kill(hh, null)
	hh.respawn_t = 0.0
	s2.step(0.02)
	if hh.spin_t > 0.0 or hh.mark_t > 0.0 or hh.fear_t > 0.0 or hh.taunt_t > 0.0 \
			or hh.buff_dmg_t > 0.0 or hh.buff_speed_t > 0.0:
		issues.append("复活没有清干净状态")
	# 兵线加速时机：5v5 最后 45 秒（435s）才加速。
	var s3 = BattleSimScript.new()
	s3.setup("fox", 0, 9802, true)
	s3.clock = 430.0
	s3.wave_t = 0.001
	s3.step(0.01)
	if absf(s3.wave_t - 18.0) > 0.5:
		issues.append("5v5 430s 兵线提前加速 wave_t=%.1f" % s3.wave_t)
	s3.clock = 440.0
	s3.wave_t = 0.001
	s3.step(0.01)
	if absf(s3.wave_t - 9.0) > 0.5:
		issues.append("5v5 440s 兵线没有加速 wave_t=%.1f" % s3.wave_t)
	# 5v5 节奏：4:00 出巨兽、5:00 终极对决、8:00 结算；3v3 保持 3:00 / 4:45。
	if absf(s3.match_cap - 480.0) > 0.01 or absf(s3.sudden_death_time - 300.0) > 0.01 \
			or absf(s3.boss_time - 240.0) > 0.01:
		issues.append("5v5 节奏不是 240/300/480 boss=%.1f cap=%.1f sd=%.1f" %
			[s3.boss_time, s3.match_cap, s3.sudden_death_time])
	var s3b = BattleSimScript.new()
	s3b.setup("fox", 0, 9812, true)
	s3b.clock = 239.0
	s3b.step(0.2)
	if s3b.boss != null or s3b.sudden_death:
		issues.append("5v5 239s 提前出现巨兽/终极对决")
	var s3c = BattleSimScript.new()
	s3c.setup("fox", 0, 9813, true)
	s3c.clock = 239.9
	s3c.step(0.2)
	if s3c.boss == null:
		issues.append("5v5 240s 没有出现巨兽")
	if s3c.sudden_death:
		issues.append("5v5 240s 巨兽与终极对决没有解耦")
	s3c.clock = 299.9
	var boss_before = s3c.boss
	s3c.step(0.2)
	if not s3c.sudden_death:
		issues.append("5v5 300s 没有进入终极对决")
	if s3c.boss != boss_before:
		issues.append("5v5 终极对决重复生成巨兽")
	# 狼嚎只标记单位，不打塔。
	var s4 = BattleSimScript.new()
	s4.setup("wolf", 0, 9803, true)
	var p4 = s4.player
	var rt = s4.towers_red[0]
	p4.pos = rt.pos + Vector2(-150, 0)
	var near_4 = null
	for h in s4.heroes:
		if h.team == BattleSimScript.RED:
			near_4 = h
			break
	near_4.pos = rt.pos + Vector2(60, 0)
	near_4.prev_pos = near_4.pos
	p4.cds = [0.0, 0.0, 0.0]
	var thp: float = rt.hp
	s4.try_cast(p4, 1)
	if absf(rt.hp - thp) > 0.01 or rt.mark_t > 0.0:
		issues.append("狼嚎打到了塔 hp %.0f->%.0f mark=%.1f" % [thp, rt.hp, rt.mark_t])
	var marked_hero = null
	for h in s4.heroes:
		if h.team == BattleSimScript.RED and h.mark_t > 0.0:
			marked_hero = h
			break
	if marked_hero == null:
		issues.append("狼嚎没有标记到英雄")
	# 陷阱预判：移动目标也能踩中。
	var s5 = BattleSimScript.new()
	s5.setup("redpanda", 0, 9804, true)
	var p5 = s5.player
	var v5 = null
	for h in s5.heroes:
		if h.team == BattleSimScript.RED:
			v5 = h
			break
	v5.pos = p5.pos + Vector2(300, 0)
	v5.prev_pos = v5.pos
	v5.move_dir = Vector2(0, 1)
	p5.cds = [0.0, 0.0, 0.0]
	s5.try_cast(p5, 1)
	var vhp: float = v5.hp
	v5.pos += Vector2(0, v5.move_speed * 0.55 * 0.8)
	s5.step_pending(0.6)
	if v5.hp >= vhp:
		issues.append("陷阱预判后仍打不中移动目标")
	# 再生水域放在残血队友脚下。
	var s6 = BattleSimScript.new()
	s6.setup("axolotl", 0, 9805, true)
	var p6 = s6.player
	p6.level = 2
	var a6 = null
	for h in s6.heroes:
		if h.team == BattleSimScript.BLUE and h != p6:
			a6 = h
			break
	a6.hp = a6.max_hp * 0.4
	a6.pos = p6.pos + Vector2(300, 0)
	a6.prev_pos = a6.pos
	p6.cds = [0.0, 0.0, 0.0]
	s6.try_cast(p6, 2)
	if s6.zones.is_empty() or s6.zones[s6.zones.size() - 1].pos.distance_to(a6.pos) > 20.0:
		issues.append("再生水域没有落在残血队友脚下")
	# 回旋尖刺三连。
	var s7 = BattleSimScript.new()
	s7.setup("hedgehog", 0, 9806, true)
	var p7 = s7.player
	var boom_count := 0
	s7.try_cast(p7, 0)
	for p in s7.shots:
		if p.boom:
			boom_count += 1
	if boom_count != 3:
		issues.append("回旋尖刺一次只飞出 %d 把" % boom_count)
	# 狼跃身后。
	var s8 = BattleSimScript.new()
	s8.setup("wolf", 0, 9807, true)
	var p8 = s8.player
	p8.level = 2
	var e8 = null
	for h in s8.heroes:
		if h.team == BattleSimScript.RED:
			e8 = h
			break
	e8.pos = p8.pos + Vector2(220, 0)
	e8.prev_pos = e8.pos
	s8.try_cast(p8, 2)
	for k in range(40):
		s8.step_hero(p8, 1.0 / 60.0)
		if p8.move_skill_t <= 0.0:
			break
	if p8.pos.x < e8.pos.x + 60.0 or p8.pos.x > e8.pos.x + 130.0:
		issues.append("猎影突袭没有落到目标身后 x=%.0f" % (p8.pos.x - e8.pos.x))
	# 尖刺伏击：无敌 + 下一击强化。
	var s9 = BattleSimScript.new()
	s9.setup("hedgehog", 0, 9808, true)
	var p9 = s9.player
	s9.try_cast(p9, 1)
	if p9.invuln_t <= 0.0 or p9.vanish_t <= 0.0:
		issues.append("尖刺伏击没有无敌窗口")
	s9.step_unit(p9, 0.9)
	if p9.ambush_t <= 0.0:
		issues.append("伏击结束后没有强化窗口")
	var dummy9 = null
	for h in s9.heroes:
		if h.team == BattleSimScript.RED:
			dummy9 = h
			break
	dummy9.invuln_t = 0.0
	var dhp: float = dummy9.hp
	s9.hit_with_fx(dummy9, 100.0, p9)
	var ambush_dmg: float = dhp - dummy9.hp
	if ambush_dmg < 175.0 or ambush_dmg > 185.0:
		issues.append("伏击首击不是 ×1.8，实际 %.1f" % ambush_dmg)
	# 5v5 终极对决仍保护水晶；拆两塔后才开放。
	var s10 = BattleSimScript.new()
	s10.setup("fox", 0, 9809, true)
	s10.sudden_death = true
	s10.clock = 181.0
	var bhp: float = s10.base_red.hp
	s10.deal_damage(s10.base_red, 500.0, s10.player)
	if s10.base_red.hp < bhp - 0.01:
		issues.append("5v5 终极对决水晶保护失效")
	s10.deal_damage(s10.towers_red[0], 99999.0, s10.player)
	s10.deal_damage(s10.towers_red[1], 99999.0, s10.player)
	s10.deal_damage(s10.base_red, 500.0, s10.player)
	if s10.base_red.hp >= bhp - 0.01:
		issues.append("5v5 拆两塔后水晶仍免疫")
	# 5v5 水晶射程/攻击与 3v3 不同。
	if s10.base_red.attack_range != 360.0 or s10.base_red.dmg != 90.0:
		issues.append("5v5 水晶数值不是 90/360")
	var s11 = BattleSimScript.new()
	s11.setup("fox", 0, 9810)
	if s11.base_red.attack_range != 400.0 or s11.base_red.dmg != 120.0:
		issues.append("3v3 水晶数值被误改")
	# 阵容多样性：10 个 seed 至少 5 种蓝方阵容。
	var comps: Dictionary = {}
	for seed_value in range(10):
		var s12 = BattleSimScript.new()
		s12.setup("fox", 0, 9820 + seed_value, true)
		var ids: Array = []
		for h in s12.heroes:
			if h.team == BattleSimScript.BLUE:
				ids.append(h.hero_id)
		ids.sort()
		comps[",".join(ids)] = true
	if comps.size() < 5:
		issues.append("10 局只有 %d 种蓝方阵容" % comps.size())
	# 刺刺与尖尖不再同模。
	var s13 = BattleSimScript.new()
	s13.setup("cat", 0, 9811, true)
	var cat_def: Dictionary = s13.defs_by_id.get("cat", {})
	var hedge_def: Dictionary = s13.defs_by_id.get("hedgehog", {})
	var diff_count := 0
	for field in ["hp", "dmg", "range", "atk_interval", "move_speed"]:
		if absf(float(cat_def.get(field, 0)) - float(hedge_def.get(field, 0))) > 0.001:
			diff_count += 1
	if diff_count < 4:
		issues.append("刺刺与尖尖属性仍然雷同，仅 %d 项不同" % diff_count)
	if str(hedge_def.get("skills", [])[1].get("kind", "")) != "vanish":
		issues.append("刺刺二技能不是尖刺伏击")
	issues += _targeting_checks()
	return issues


func _targeting_checks() -> Array:
	var issues: Array = []
	# 1) 普攻优先英雄，其次补残血小兵，并有目标粘性。
	var s = BattleSimScript.new()
	s.setup("fox", 0, 9955)
	var p = s.player
	p.pos = Vector2(1000, 1200)
	p.prev_pos = p.pos
	var foe = null
	for h in s.heroes:
		if h.team == BattleSimScript.RED:
			foe = h
			break
	foe.pos = p.pos + Vector2(180, 0)
	foe.prev_pos = foe.pos
	foe.invuln_t = 0.0
	var mins: Array = []
	s.spawn_wave(BattleSimScript.RED)
	for m in s.minions:
		if m.is_alive() and m.team == BattleSimScript.RED and m.kind == BattleSimScript.MINION:
			mins.append(m)
		if mins.size() >= 2:
			break
	if mins.size() < 2:
		issues.append("目标测试没有生成小兵")
	else:
		for m in mins:
			m.pos = Vector2(400, 300)
			m.prev_pos = m.pos
		mins[0].pos = p.pos + Vector2(60, 20)
		mins[0].prev_pos = mins[0].pos
		mins[1].pos = p.pos + Vector2(90, -20)
		mins[1].prev_pos = mins[1].pos
		var pick = s.pick_attack_target(p)
		if pick != foe:
			issues.append("普攻没有优先敌方英雄")
		foe.pos = p.pos + Vector2(1400, 0)
		foe.prev_pos = foe.pos
		mins[0].hp = mins[0].max_hp * 0.2
		mins[1].hp = mins[1].max_hp * 0.9
		pick = s.pick_attack_target(p)
		if pick != mins[0]:
			issues.append("普攻没有先补残血小兵")
		mins[0].hp = mins[0].max_hp * 0.5
		mins[1].hp = mins[1].max_hp * 0.5
		p.atk_target = mins[1]
		pick = s.pick_attack_target(p)
		if pick != mins[1]:
			issues.append("普攻锁定目标没有粘性")
	# 2) 远程普攻弹道追踪移动目标。
	var s2 = BattleSimScript.new()
	s2.setup("rabbit", 0, 9956)
	var p2 = s2.player
	p2.pos = Vector2(900, 1200)
	p2.prev_pos = p2.pos
	var e2 = null
	for h in s2.heroes:
		if h.team == BattleSimScript.RED:
			e2 = h
			break
	e2.pos = p2.pos + Vector2(240, 0)
	e2.prev_pos = e2.pos
	e2.invuln_t = 0.0
	e2.move_dir = Vector2(0, 1)
	for m in s2.minions:
		m.pos = Vector2(200, 200)
		m.prev_pos = m.pos
	var hp_before: float = e2.hp
	p2.atk_timer = 0.0
	s2.step_hero(p2, 0.016)
	if s2.shots.is_empty():
		issues.append("远程普攻没有发射弹道")
	else:
		for i in range(40):
			s2.step_projectiles(0.016)
		if e2.hp >= hp_before - 0.01:
			issues.append("远程普攻弹道没有追踪命中")
	# 3) 技能优先瞄英雄，并对移动目标做提前量。
	var s3 = BattleSimScript.new()
	s3.setup("fox", 0, 9957)
	var p3 = s3.player
	p3.pos = Vector2(900, 1200)
	p3.prev_pos = p3.pos
	p3.move_dir = Vector2(0, 1)
	var e3 = null
	for h in s3.heroes:
		if h.team == BattleSimScript.RED:
			e3 = h
			break
	e3.pos = p3.pos + Vector2(320, 0)
	e3.prev_pos = e3.pos
	e3.invuln_t = 0.0
	var m3 = null
	for m in s3.minions:
		if m.is_alive() and m.team == BattleSimScript.RED and m.kind == BattleSimScript.MINION:
			m3 = m
			break
	if m3 != null:
		m3.pos = p3.pos + Vector2(100, 0)
		m3.prev_pos = m3.pos
	var sk: Dictionary = p3.skills[0]
	var n0: int = s3.shots.size()
	e3.move_dir = Vector2.ZERO
	s3.cast(p3, sk, 0)
	if s3.shots.size() <= n0:
		issues.append("技能没有生成弹道")
	else:
		var d: Vector2 = s3.shots[n0].dir
		var want: Vector2 = (e3.pos - p3.pos).normalized()
		if d.dot(want) < 0.95:
			issues.append("技能没有优先瞄准英雄")
		e3.move_dir = Vector2(0, 1)
		var n1: int = s3.shots.size()
		s3.cast(p3, sk, 0)
		if s3.shots.size() <= n1:
			issues.append("移动目标技能没有生成弹道")
		elif s3.shots[n1].dir.y < 0.05:
			issues.append("技能没有对移动目标做提前量")
	# 4) 月链首跳优先英雄。
	var s4 = BattleSimScript.new()
	s4.setup("owl", 0, 9958)
	var p4 = s4.player
	var e4 = null
	for h in s4.heroes:
		if h.team == BattleSimScript.RED:
			e4 = h
			break
	e4.pos = p4.pos + Vector2(240, 0)
	e4.prev_pos = e4.pos
	if s4._chain_target(p4, p4.pos, 320.0, []) != e4:
		issues.append("月链首跳没有优先英雄")
	return issues

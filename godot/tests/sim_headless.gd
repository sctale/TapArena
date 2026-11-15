extends SceneTree

# 固定种子无头对局：验证一局一定会在 5 分钟内结束、先拆塔后破水晶、数值不出现 NaN。
# 运行：godot --headless --path godot --script res://tests/sim_headless.gd

const BattleSimScript = preload("res://scripts/core/battle_sim.gd")
const HERO_IDS := ["tiger", "fox", "rabbit", "bear", "frog", "cat", "panda", "owl"]
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
		print("RULE_OK base_protection/base_heal/ult_cd/potion/dash/boss")
	else:
		failures += 1
		for issue in rule_issues:
			print("RULE_FAIL " + issue)

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
	if p8.pos.x < before_x + 150.0:
		issues.append("技能没有在移动当帧释放")
	if p8.dash_t <= 0.0:
		issues.append("位移后没有记录位移状态")
	stop_count[0] = 0
	var dummy = sim8.heroes[3]
	sim8.hit_with_fx(dummy, 120.0, p8)
	if stop_count[0] != 0:
		issues.append("位移期间触发了顿帧")
	p8.dash_t = 0.0
	sim8.hit_with_fx(dummy, 120.0, p8)
	if stop_count[0] != 1:
		issues.append("位移结束后没有恢复顿帧")

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

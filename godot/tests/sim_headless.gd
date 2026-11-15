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
		print("RULE_OK base_protection")
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

	return issues

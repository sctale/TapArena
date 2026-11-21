extends SceneTree

# 临时探针：巨兽出场前先拆掉落后方一座外塔，量化「翻盘率」。
# 运行：godot --headless --path <工程> --script res://tests/boss_probe.gd

const BattleSimScript = preload("res://scripts/core/battle_sim.gd")
const HERO_IDS := ["tiger", "fox", "rabbit", "bear", "frog", "cat", "panda", "owl", "axolotl", "deer"]
const MATCHES := 8
const DT := 1.0 / 60.0
const MAX_SIM_SECONDS := 500.0


func _init() -> void:
	for mode5 in [false, true]:
		for scenario in ["blue_trailing", "red_trailing"]:
			_run(mode5, scenario)
	print("BOSS_PROBE_DONE")
	quit()


func _run(mode5: bool, scenario: String) -> void:
	var trailing := BattleSimScript.BLUE if scenario == "blue_trailing" else BattleSimScript.RED
	var wins := 0
	var boss_owner_wins := 0
	var boss_on_trailing := 0
	var total := 0
	var clock_sum := 0.0
	var timeout := 0
	var base_dmg := 0
	for i in range(MATCHES):
		var hero_id: String = HERO_IDS[i % HERO_IDS.size()]
		var difficulty := i % 2
		var sim = BattleSimScript.new()
		sim.setup(hero_id, difficulty, 20261140 + i, mode5)
		var tampered := false
		var boss_team := -99
		var elapsed := 0.0
		while not sim.over and elapsed < MAX_SIM_SECONDS:
			# 出场前拆掉落后方外塔，保证巨兽判定时一方确实落后。
			if not tampered and sim.clock >= sim.boss_time - 1.0:
				tampered = true
				var t = sim.towers_blue[0] if trailing == BattleSimScript.BLUE else sim.towers_red[0]
				t.hp = 0.0
				print("  tamper clock=%.1f towersB=%s towersR=%s" % [
					sim.clock, _towers(sim.towers_blue), _towers(sim.towers_red)])
			sim.step(DT)
			elapsed += DT
			if sim.boss_spawned and boss_team == -99:
				boss_team = int(sim.boss_team)
		total += 1
		clock_sum += sim.clock
		if sim.end_reason.find("时间到") >= 0:
			timeout += 1
		if sim.winner == trailing:
			wins += 1
		if sim.winner == boss_team:
			boss_owner_wins += 1
		if boss_team == trailing:
			boss_on_trailing += 1
		var foe_base = sim.base_red if trailing == BattleSimScript.BLUE else sim.base_blue
		if foe_base.hp < foe_base.max_hp:
			base_dmg += 1
		print("%s boss=%d trailing=%d winner=%d clock=%.1f base=%.2f/%.2f reason=%s" % [
			"5v5" if mode5 else "3v3", boss_team, trailing, sim.winner, sim.clock,
			sim.base_blue.hp / sim.base_blue.max_hp, sim.base_red.hp / sim.base_red.max_hp,
			sim.end_reason])
	print("SUMMARY %s %s: trailing_win=%d/%d (%.0f%%) boss_owner_win=%d/%d boss_on_trailing=%d timeout=%d base_damaged=%d avg_clock=%.1f" % [
		"5v5" if mode5 else "3v3", scenario, wins, total, 100.0 * wins / total,
		boss_owner_wins, total, boss_on_trailing, timeout, base_dmg, clock_sum / total])


func _towers(list: Array) -> String:
	var parts: Array = []
	for t in list:
		parts.append("%.0f" % t.hp)
	return ",".join(parts)

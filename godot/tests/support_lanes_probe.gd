extends SceneTree
# 临时探针：5v5 只推一路塔，验证下一波三路兵线都带叶灵、且全程不离路。
# 运行：godot --headless --path . --script res://tests/support_lanes_probe.gd

const BattleSimScript = preload("res://scripts/core/battle_sim.gd")


func _init() -> void:
	var sim = BattleSimScript.new()
	sim.setup("tiger", 0, 9931, true)
	var dt := 1.0 / 60.0
	var t := 0.0
	var killed := false
	var first_spawn := {}
	var max_off := 0.0
	while t < 90.0:
		if not killed and t >= 5.0:
			killed = true
			# 只推中路（lane 1）一座红塔。
			for tw in sim.towers_red:
				if int(tw.lane_id) == 1 and tw.is_alive():
					sim.deal_damage(tw, 999999.0, sim.player)
			print("PENDING after one tower=", sim.support_pending.keys())
		sim.step(dt)
		t += dt
		for m in sim.minions:
			if m.support and m.is_alive() and m.team == BattleSimScript.BLUE:
				var lid := int(m.lane_id)
				if not first_spawn.has(lid):
					first_spawn[lid] = t
					print("FIRST_SPAWN lane=%d t=%.1f pos=%s" % [lid, t, m.pos])
				max_off = maxf(max_off, sim.lane_distance(lid, m.pos))
	var ok := first_spawn.size() == 3
	print("RESULT lanes=%s max_off=%.1f %s" % [first_spawn.keys(), max_off,
		"ALL_LANES_OK" if ok and max_off <= 32.0 else "FAIL"])
	quit(0)

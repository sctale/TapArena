extends SceneTree
# 临时探针：5v5 推塔后跟踪叶灵，找出“卡在原地不动”的场景与原因。
# 运行：godot --headless --path . --script res://tests/support_stuck_probe.gd

const BattleSimScript = preload("res://scripts/core/battle_sim.gd")


func _init() -> void:
	var sim = BattleSimScript.new()
	sim.setup("tiger", 0, 9941, true)
	var dt := 1.0 / 60.0
	var t := 0.0
	var killed := false
	var watch := {}  # uid -> {pos, still, logged}
	var stalls := 0
	while t < 180.0:
		if sim.over:
			print("MATCH_OVER t=%.1f winner=%d" % [t, sim.winner])
			break
		if not killed and t >= 5.0:
			killed = true
			for tw in sim.towers_red:
				if int(tw.lane_id) == 1 and tw.is_alive():
					sim.deal_damage(tw, 999999.0, sim.player)
		sim.step(dt)
		t += dt
		var alive_ids := {}
		for m in sim.minions:
			if not m.support or not m.is_alive() or m.team != BattleSimScript.BLUE:
				continue
			var uid: int = m.uid
			alive_ids[uid] = true
			var w = watch.get(uid)
			if w == null:
				w = {"pos": m.pos, "still": 0.0, "logged": false}
				watch[uid] = w
			if m.pos.distance_to(w["pos"]) < 1.5:
				w["still"] = float(w["still"]) + dt
			else:
				w["still"] = 0.0
				w["logged"] = false
				w["pos"] = m.pos
			if float(w["still"]) >= 2.5 and not bool(w["logged"]):
				w["logged"] = true
				if _is_real_stall(sim, m):
					stalls += 1
					_log_stall(sim, m, t)
		for uid2 in watch.keys():
			if not alive_ids.has(uid2):
				watch.erase(uid2)
	print("REAL_STALLS=%d" % stalls)
	if stalls == 0:
		print("STUCK_OK no_idle_without_allies")
	else:
		print("STUCK_FAIL %d" % stalls)
	quit(0)


func _is_real_stall(sim, m) -> bool:
	# 设计内的停住：身后 80 有己方小兵跟随；真卡住：完全没有己方小兵/目标远在天边。
	var lid := int(m.lane_id)
	var s: float = sim.lane_progress(lid, m.pos)
	for o in sim.minions:
		if not o.is_alive() or o.support or o.team != m.team or int(o.lane_id) != lid:
			continue
		var p: float = sim.lane_progress(lid, o.pos)
		var gap: float = p - s if m.team == BattleSimScript.BLUE else s - p
		if gap >= -20.0 and gap <= 120.0:
			return false
	return true


func _log_stall(sim, m, t: float) -> void:
	var lid := int(m.lane_id)
	var s: float = sim.lane_progress(lid, m.pos)
	var ally := 0
	var front_p := -1.0
	var front_gap := -1.0
	for o in sim.minions:
		if not o.is_alive() or o.support or o.team != m.team or int(o.lane_id) != lid:
			continue
		ally += 1
		var p: float = sim.lane_progress(lid, o.pos)
		if p > front_p:
			front_p = p
	if front_p >= 0.0:
		front_gap = front_p - s if m.team == BattleSimScript.BLUE else s - front_p
	var foe_d := 9999.0
	for o in sim.units:
		if o.is_alive() and o.team != m.team and (o.kind == BattleSimScript.HERO or o.kind == BattleSimScript.MINION):
			foe_d = minf(foe_d, m.pos.distance_to(o.pos))
	var danger := ""
	for s2 in sim.units:
		if not s2.is_alive() or s2.team == m.team:
			continue
		if s2.kind != BattleSimScript.TOWER and s2.kind != BattleSimScript.BASE:
			continue
		var d: float = m.pos.distance_to(s2.pos)
		if d <= s2.attack_range + m.radius + 40.0:
			danger = "tower_d=%.0f range=%.0f" % [d, s2.attack_range]
			break
	print("STALL t=%.1f lane=%d s=%.0f allies=%d front_gap=%.0f foe_d=%.0f %s final=%s" % [
		t, lid, s, ally, front_gap, foe_d, danger, sim.final_push])

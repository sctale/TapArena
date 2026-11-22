extends SceneTree
# 临时探针：完整 3v3 对局里跟踪叶灵，确认它全程只沿兵线路径移动（不进野区）。
# 运行：godot --headless --path . --script res://tests/support_audit.gd

const BattleSimScript = preload("res://scripts/core/battle_sim.gd")


func _init() -> void:
	var sim = BattleSimScript.new()
	sim.setup("tiger", 0, 9901)
	# 推掉上路（3v3 只有一条路）外塔，触发叶灵排队。
	var outer = sim.towers_red[0]
	sim.deal_damage(outer, 999999.0, sim.player)
	var lid := int(outer.lane_id)
	var max_off := 0.0
	var max_off_at := 0.0
	var sample_t := 0.0
	var supports_seen := 0
	var total := sim.path_length(sim.path_of(lid))
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < 240.0:
		sim.step(dt)
		t += dt
		sample_t += dt
		if sample_t < 0.25:
			continue
		sample_t = 0.0
		for m in sim.minions:
			if not m.support or not m.is_alive():
				continue
			supports_seen += 1
			var off: float = sim.lane_distance(lid, m.pos)
			if off > max_off:
				max_off = off
				max_off_at = t
	print("AUDIT supports_seen=%d max_off=%.1f at=%.1fs lane_len=%.0f" % [
		supports_seen, max_off, max_off_at, total])
	if max_off <= 32.0:
		print("SUPPORT_LANE_OK")
	else:
		print("SUPPORT_LANE_FAIL max_off=%.1f" % max_off)
	quit(0)

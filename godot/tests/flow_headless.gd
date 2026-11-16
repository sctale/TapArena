extends SceneTree

# 首页 → 选人 → 开战 → 回首页 的状态机回归。
# 运行：godot --headless --path godot --script res://tests/flow_headless.gd

var main = null
var frame := 0
var failures: Array = []


func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		if main.home == null:
			failures.append("启动后没有首页")
		else:
			if main.home.heroes.size() != 10:
				failures.append("首页英雄数量不是 10")
			main.home._tap(main.home.card_rect(1).get_center())
			if not main.home.detail_open:
				failures.append("选中卡片后没有弹出人物介绍")
	elif frame == 4:
		if main.home != null and main.home.detail_open:
			main.home._tap(main.home.detail_close_rect().get_center())
	elif frame == 6:
		if main.home != null:
			main.home._tap(main.home.challenge_rect().get_center())
	elif frame == 9:
		if main.home != null:
			main.home._tap(main.home.start_rect().get_center())
	elif frame == 12:
		if main.sim == null or not main.match_active:
			failures.append("点击开始后没有进入战斗")
		elif main.home != null:
			failures.append("进入战斗后首页没有清理")
		elif main.current_hero != "fox" or main.current_difficulty != 1:
			failures.append("选人/难度没有传进战斗：%s/%d" % [main.current_hero, main.current_difficulty])
		# 每个英雄都应该有独立的施法/命中/大招音色。
		for id in ["tiger", "fox", "rabbit", "bear", "frog", "cat", "panda", "owl"]:
			for prefix in ["cast_", "hit_", "ult_"]:
				if not main.sfx._streams.has(prefix + id):
					failures.append("缺少音效 " + prefix + id)
		for id in ["fox", "rabbit", "frog", "cat", "owl"]:
			if not main.sfx._streams.has("shoot_" + id):
				failures.append("缺少普攻音效 shoot_" + id)
	elif frame == 66:
		if main.sim != null and main.sim.clock <= 0.0:
			failures.append("战斗没有推进时钟")
		main._toggle_pause()
		if main.hud == null or not main.hud.paused:
			failures.append("暂停没有生效")
	elif frame == 68:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = true
		ev.position = main.hud.sound_rect().get_center()
		main.input_hub._handle_touch(ev)
		if main.sfx.enabled:
			failures.append("音效开关没有关闭声音")
		main.input_hub._handle_touch(ev)
		if not main.sfx.enabled:
			failures.append("音效开关没有恢复声音")
		ev.position = main.hud.home_rect().get_center()
		main.input_hub._handle_touch(ev)
	elif frame == 72:
		if main.home == null:
			failures.append("回首页失败")
		if main.sim != null or main.hud != null:
			failures.append("回首页后战斗对象没有释放")
		if failures.is_empty():
			print("FLOW_OK home->battle->home")
		else:
			for f in failures:
				print("FLOW_FAIL " + f)
		quit(0 if failures.is_empty() else 1)
	return false

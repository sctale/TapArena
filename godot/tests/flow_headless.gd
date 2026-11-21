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
			if main.home.heroes.size() != 25:
				failures.append("首页英雄数量不是 25，实际 %d" % main.home.heroes.size())
			# 两排视口：默认第 25 张在视口外，滚到底后完整可见，底部栏不动。
			if main.home.max_grid_scroll() <= 0.0:
				failures.append("25 人首页没有可滚动内容")
			var grid_vp: Rect2 = main.home._grid_rect()
			if grid_vp.encloses(main.home.card_rect(24)):
				failures.append("第 25 张卡默认就在两排视口内")
			main.home.set_grid_scroll(main.home.max_grid_scroll())
			if not grid_vp.encloses(main.home.card_rect(24)):
				failures.append("滚到底后第 25 张卡不可见")
			main.home.set_grid_scroll(0.0)
			# 网格内上滑应产生滚动，且松手不误触卡片。
			var gc: Vector2 = grid_vp.get_center()
			var step: float = main.home._grid_card_size().y + main.home._grid_gap()
			main.home._press(gc)
			main.home._drag_to(gc + Vector2(0, -50))
			var partial: float = main.home.grid_scroll
			if partial <= 1.0:
				failures.append("小幅拖动没有滚动")
			if absf(partial - roundf(partial / step) * step) < 2.0:
				failures.append("滚动仍按整排吸附")
			main.home._drag_to(gc + Vector2(0, -400))
			main.home._release(gc + Vector2(0, -400))
			if main.home.grid_scroll <= 1.0:
				failures.append("网格上滑没有滚动")
			main.home.set_grid_scroll(0.0)
			main.home._tap(main.home.card_rect(1).get_center())
			if not main.home.detail_open:
				failures.append("选中卡片后没有弹出人物介绍")
			# 4.14.1：弹窗更紧凑后，标题/技能/提示/按钮不得重叠；大招必须带冷却。
			var dr: Rect2 = main.home.detail_rect()
			var pr: Rect2 = main.home.detail_portrait_rect()
			if pr.end.x > main.home.detail_text_x():
				failures.append("详情头像压到正文")
			var last_row: Rect2 = main.home.detail_skill_rect(2)
			var tip: Rect2 = main.home.detail_tip_rect()
			var close_r: Rect2 = main.home.detail_close_rect()
			if last_row.end.y > tip.position.y:
				failures.append("详情技能行压到提示行")
			if tip.end.y > close_r.position.y:
				failures.append("详情提示行压到底部按钮")
			var ult_meta: String = main.home.detail_skill_meta[2].text
			if not ult_meta.contains("冷却"):
				failures.append("大招没有显示冷却：" + ult_meta)
			if not ult_meta.contains("2 级解锁"):
				failures.append("大招没有显示解锁等级：" + ult_meta)
			if dr.end.y > main.home._safe().end.y + 1.0:
				failures.append("详情弹窗超出安全区")
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
		for id in main.sim.defs_by_id.keys():
			for prefix in ["cast_", "hit_", "ult_"]:
				if not main.sfx._streams.has(prefix + id):
					failures.append("缺少音效 " + prefix + id)
			var audio: Dictionary = main.sfx.HERO_AUDIO.get(id, {})
			if float(audio.get("shoot", 0.0)) > 0.0 and not main.sfx._streams.has("shoot_" + id):
				failures.append("缺少普攻音效 shoot_" + id)
		_check_palette("3v3")
		_check_roster_art()
		_check_cast_actions()
		_check_base_clear("3v3")
		_check_audio_assets()
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
		var sfx_bus := AudioServer.get_bus_index("SFX")
		if sfx_bus != -1 and not AudioServer.is_bus_mute(sfx_bus):
			failures.append("音效开关没有静音 3D 音频总线")
		main.input_hub._handle_touch(ev)
		if not main.sfx.enabled:
			failures.append("音效开关没有恢复声音")
		if sfx_bus != -1 and AudioServer.is_bus_mute(sfx_bus):
			failures.append("音效开关没有恢复 3D 音频总线")
		ev.position = main.hud.home_rect().get_center()
		main.input_hub._handle_touch(ev)
	elif frame == 72:
		if main.home == null:
			failures.append("回首页失败")
		if main.sim != null or main.hud != null:
			failures.append("回首页后战斗对象没有释放")
		if main.home != null:
			main.home._tap(main.home.mode5_rect().get_center())
	elif frame == 74:
		if main.home == null:
			failures.append("切换 5v5 后首页消失")
		else:
			if not main.home.mode_5v5:
				failures.append("5v5 模式没有切换")
			if main.home.heroes.size() != 25:
				failures.append("5v5 首页英雄数量不是 25，实际 %d" % main.home.heroes.size())
			if main.home.max_grid_scroll() <= 0.0:
				failures.append("5v5 首页没有可滚动内容")
			main.home._tap(main.home.start_rect().get_center())
	elif frame == 78:
		if main.sim == null or not main.match_active:
			failures.append("5v5 没有进入战斗")
		elif not main.sim.five_v_five:
			failures.append("5v5 标记没有传入战斗")
		elif main.sim.heroes.size() != 10:
			failures.append("5v5 战斗英雄数量不是 10")
		_check_palette("5v5")
		_check_base_clear("5v5")
		if failures.is_empty():
			print("FLOW_OK home->battle->home->5v5")
		else:
			for f in failures:
				print("FLOW_FAIL " + f)
		quit(0 if failures.is_empty() else 1)
	return false


func _check_audio_assets() -> void:
	# 4.21：30 个音频资产 + SFX/BGM 总线 + 视图音频池。
	var ids: Array = main.sim.defs_by_id.keys() if main.sim != null else []
	for id in ids:
		for kind in ["atk", "ult"]:
			var path := "res://assets/audio/%s/%s_%s.wav" % [kind, kind, id]
			if not ResourceLoader.exists(path):
				failures.append("缺少音频资产 " + path)
	if AudioServer.get_bus_index("SFX") == -1 or AudioServer.get_bus_index("BGM") == -1:
		failures.append("缺少 SFX/BGM 音频总线")
	if main.view == null:
		failures.append("音频检查时没有视图")
		return
	if main.view.audio_atk.size() != 25 or main.view.audio_ult.size() != 25:
		failures.append("视图音频池未加载完整：atk=%d ult=%d" % [
			main.view.audio_atk.size(), main.view.audio_ult.size()])
	if main.view.audio_pool.is_empty():
		failures.append("视图没有 3D 音频播放器")
	# 台词 manifest：25 条、男女 12/13、音色不重复、首静音 ≤50ms。
	var mpath := "res://assets/audio/ult/manifest.json"
	if not FileAccess.file_exists(mpath):
		failures.append("缺少 ult/manifest.json")
	else:
		var mdata = JSON.parse_string(FileAccess.get_file_as_string(mpath))
		if typeof(mdata) != TYPE_DICTIONARY or not mdata.has("lines"):
			failures.append("ult/manifest.json 解析失败")
		else:
			var lines: Array = mdata["lines"]
			if lines.size() != 25:
				failures.append("台词 manifest 不是 25 条：%d" % lines.size())
			var genders := {"boy": 0, "girl": 0}
			var voices: Dictionary = {}
			for e in lines:
				var g := str(e.get("gender", ""))
				if genders.has(g):
					genders[g] += 1
				else:
					failures.append("台词缺少性别：" + str(e.get("hero", "")))
				if float(e.get("lead", 1.0)) > 0.05:
					failures.append("台词首静音过长：" + str(e.get("hero", "")))
				var v := str(e.get("voice", ""))
				if voices.has(v):
					failures.append("台词音色重复：" + v)
				voices[v] = true
			if genders["boy"] != 12 or genders["girl"] != 13:
				failures.append("台词男女数量不是 12/13：%d/%d" % [genders["boy"], genders["girl"]])
	if main.view.voice_pool.size() != 4:
		failures.append("台词播放器池不是 4 个：%d" % main.view.voice_pool.size())
	else:
		for v in main.view.voice_pool:
			if absf(float(v.attenuation_filter_db)) > 0.01:
				failures.append("台词播放器没有关闭低通滤波")
				break
	# 台词不许被 6 条更近的普攻请求按距离挤掉。
	var voice = main.view.audio_ult.get("tiger")
	if voice != null and not main.view.voice_pool.is_empty() and main.sim != null:
		main.view.audio_queue.clear()
		main.view.audio_queue.append({"stream": voice,
			"pos": Vector3(main.sim.player.pos.x, 34.0, main.sim.player.pos.y + 600.0),
			"pitch": 1.0, "volume": -1.0, "voice": true})
		for i in range(6):
			var st = main.view.audio_atk.get("fox")
			if st == null:
				break
			main.view.audio_queue.append({"stream": st,
				"pos": Vector3(main.sim.player.pos.x, 24.0, main.sim.player.pos.y + float(i + 1) * 10.0),
				"pitch": 1.0, "volume": -9.0})
		main.view._flush_audio()
		var got_voice := false
		for v in main.view.voice_pool:
			if v.stream == voice:
				got_voice = true
				break
		if not got_voice:
			failures.append("台词被 6 条更近的普攻请求挤掉")
		if main.view.bgm_duck_t <= 0.0:
			failures.append("近距台词没有压低 BGM")


func _check_base_clear(tag: String) -> void:
	# 4.22：水晶前后不许有树/石头遮挡（树 600+半径，石头 400+半径）。
	if main.view == null or main.sim == null:
		failures.append(tag + " 基地树木检查时没有视图")
		return
	var bases: Array = []
	for u in main.sim.units:
		if u.kind == main.sim.BASE:
			bases.append(u)
	for key in main.view.scatter_spots.keys():
		var margin: float = 600.0 if str(key).begins_with("tree_") else 400.0
		for p in main.view.scatter_spots[key]:
			for b in bases:
				if Vector2(p.x, p.z).distance_to(b.pos) < margin + b.radius - 0.5:
					failures.append("%s %s 压到基地：%s" % [tag, str(key), str(p)])
					return


func _check_roster_art() -> void:
	# 25 位英雄的模型部件 / 头像 / 大招图标都能生成，调色板 ≤64。
	if main.sim == null or main.view == null:
		failures.append("阵容检查时没有战斗视图")
		return
	var BlockModels = load("res://scripts/art/block_models.gd")
	var Portraits = load("res://scripts/art/hero_portraits.gd")
	var Icons = load("res://scripts/art/pixel_icons.gd")
	var atlas = main.view.atlas
	var portraits = Portraits.new()
	var icons = Icons.new()
	var ids: Array = main.sim.defs_by_id.keys()
	if ids.size() != 25:
		failures.append("英雄定义不是 25 位：%d" % ids.size())
	var checked := 0
	for id in ids:
		var d: Dictionary = main.sim.defs_by_id[id]
		var fur: Color = Color.from_string(str(d.get("fur", "#ffffff")), Color.WHITE)
		var cream: Color = Color.from_string(str(d.get("cream", "#ffffff")), Color.WHITE)
		var dark: Color = Color.from_string(str(d.get("dark", "#000000")), Color.BLACK)
		var accent: Color = Color.from_string(str(d.get("accent", "#ffffff")), Color.WHITE)
		var pants := str(d.get("pants", "navy"))
		var skills: Array = d.get("skills", [])
		if skills.size() != 3:
			failures.append(str(id) + " 技能不是 3 条")
		for sk in skills:
			if str(sk.get("name", "")) == "" or str(sk.get("kind", "")) == "":
				failures.append(str(id) + " 技能缺名称/类型")
		var parts = BlockModels.hero_parts(str(id), atlas, fur, cream, dark, accent, pants)
		for part in parts["mesh"].keys():
			var mesh = parts["mesh"][part]
			var palette: PackedColorArray = mesh.get_meta("palette", PackedColorArray())
			if palette.size() > 64:
				failures.append("%s/%s 调色板 %d 超过 64" % [id, part, palette.size()])
			if int(mesh.get_meta("palette_overflow", 0)) > 0:
				failures.append("%s/%s 调色板溢出" % [id, part])
		if not main.view.HERO_DESIGN_H.has(str(id)):
			failures.append(str(id) + " 缺少设计身高")
		# 视觉身高守卫：装配后的包围盒（身体 + 各枢轴抬升）× height / 设计身高。
		# 新模型加高脖子/冠羽时必须同步改 HERO_DESIGN_H 或 height，避免二次放大。
		var top := 0.0
		var pivots: Dictionary = parts["pivots"]
		for part_key in parts["mesh"].keys():
			var pm: ArrayMesh = parts["mesh"][part_key]
			var lift := 0.0
			if str(part_key) != "body":
				var pv: Vector3 = pivots.get(part_key, Vector3.ZERO)
				lift = pv.y
			top = maxf(top, pm.get_aabb().end.y + lift)
		var design := float(main.view.HERO_DESIGN_H.get(str(id), 76.0))
		var visual := top * float(d.get("height", 0)) / design
		var limits := {
			"坦克": Vector2(72.0, 110.0), "战士": Vector2(65.0, 96.0),
			"法师": Vector2(55.0, 90.0), "辅助": Vector2(55.0, 108.0),
			"控制": Vector2(55.0, 80.0), "射手": Vector2(50.0, 82.0),
			"刺客": Vector2(55.0, 82.0), "打野": Vector2(60.0, 88.0),
			"法坦": Vector2(60.0, 88.0),
		}
		var lim: Vector2 = limits.get(str(d.get("role", "")), Vector2(50.0, 110.0))
		if visual < lim.x or visual > lim.y:
			failures.append("%s 视觉身高 %.1f 超出 %s 档 %.0f–%.0f（模型 %.1f）" % [
				id, visual, str(d.get("role", "")), lim.x, lim.y, top])
		if portraits.portrait(str(id), fur, cream, dark, accent) == null:
			failures.append(str(id) + " 头像生成失败")
		if icons.ult_icon(str(id)) == null:
			failures.append(str(id) + " 大招图标生成失败")
		checked += 1
	if checked == 25:
		print("ROSTER_OK art=25 audio=25")


func _check_cast_actions() -> void:
	# 25 人 × 3 技能都要映射到一个全身释放动作；大招不允许 none。
	if main.view == null or main.sim == null:
		failures.append("施法动作检查时没有战斗视图")
		return
	var seen: Dictionary = {}
	for id in main.sim.defs_by_id.keys():
		var d: Dictionary = main.sim.defs_by_id[id]
		var skills: Array = d.get("skills", [])
		for i in range(skills.size()):
			var kind := str(skills[i].get("kind", ""))
			var act := str(main.view.cast_action_for(str(id), i, kind))
			if not main.view.CAST_ACTIONS.has(act):
				failures.append("%s 技能%d 动作无效：%s" % [id, i, act])
			if i == 2 and act == "none":
				failures.append(str(id) + " 大招没有释放动作")
			seen[act] = true
	if not seen.has("spin"):
		failures.append("没有旋转类施法动作")
	print("CAST_OK actions=%d" % seen.size())


func _check_palette(tag: String) -> void:
	# 调色板纪律：每个模型 ≤64 色，且不允许溢出（溢出说明配色被压近似色）。
	if main.view == null:
		failures.append("%s 调色板检查时没有视图" % tag)
		return
	var checked := 0
	for key in main.view.model_cache:
		var mesh = main.view.model_cache[key]
		if not (mesh is ArrayMesh):
			continue
		var palette: PackedColorArray = mesh.get_meta("palette", PackedColorArray())
		if palette.size() > 64:
			failures.append("%s 模型 %s 调色板 %d 超过 64" % [tag, key, palette.size()])
		if int(mesh.get_meta("palette_overflow", 0)) > 0:
			failures.append("%s 模型 %s 调色板溢出 %d 次" % [tag, key, int(mesh.get_meta("palette_overflow", 0))])
		checked += 1
	if checked < 15:
		failures.append("%s 调色板检查模型过少 %d" % [tag, checked])

class_name InputHub
extends Node

# 触屏摇杆 + 三技能键 + 键盘调试。触屏用原生多点事件，摇杆和技能可以同时按。
signal pause_toggle
signal restart_requested
signal home_requested
signal sound_toggle

var sim = null
var hud = null
var move := Vector2.ZERO
var joy_active := false
var joy_center := Vector2.ZERO
var joy_knob := Vector2.ZERO
var joy_finger := -1
var joy_radius := 130.0


func attach(s, h) -> void:
	sim = s
	hud = h
	hud.input_hub = self
	joy_radius = maxf(80.0, hud.viewport_size().y * 0.12)


func _unhandled_input(event: InputEvent) -> void:
	if sim == null or hud == null:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var pos := event.position
	if event.pressed:
		if sim.over:
			if hud.result_restart_rect().has_point(pos):
				restart_requested.emit()
			elif hud.result_home_rect().has_point(pos):
				home_requested.emit()
			return
		if hud.paused:
			if hud.resume_rect().has_point(pos):
				pause_toggle.emit()
			elif hud.restart_rect().has_point(pos):
				restart_requested.emit()
			elif hud.home_rect().has_point(pos):
				home_requested.emit()
			elif hud.sound_rect().has_point(pos):
				sound_toggle.emit()
			return
		if hud.pause_rect().has_point(pos):
			pause_toggle.emit()
			return
		for i in range(3):
			if hud.skill_rect(i).has_point(pos):
				sim.set_skill(i)
				return
		if joy_finger == -1 and _in_joy_zone(pos):
			joy_finger = event.index
			joy_active = true
			joy_center = pos
			joy_knob = pos
			move = Vector2.ZERO
	else:
		if event.index == joy_finger:
			joy_finger = -1
			joy_active = false
			move = Vector2.ZERO


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != joy_finger:
		return
	var d: Vector2 = event.position - joy_center
	if d.length() > joy_radius:
		d = d.normalized() * joy_radius
	joy_knob = joy_center + d
	# 相机在角色南侧朝北看：屏幕向上 = 世界 -Z，屏幕向右 = 世界 +X。
	move = d / joy_radius


func _handle_key(keycode: int) -> void:
	if sim.over:
		if keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
			restart_requested.emit()
		elif keycode == KEY_H:
			home_requested.emit()
		return
	if keycode == KEY_ESCAPE:
		pause_toggle.emit()
		return
	if keycode == KEY_H and hud.paused:
		home_requested.emit()
		return
	if keycode == KEY_M and hud.paused:
		sound_toggle.emit()
		return
	if hud.paused:
		return
	match keycode:
		KEY_Q, KEY_1:
			sim.set_skill(0)
		KEY_E, KEY_2:
			sim.set_skill(1)
		KEY_R, KEY_3:
			sim.set_skill(2)


func _process(_delta: float) -> void:
	if sim == null:
		return
	if hud != null and (hud.paused or sim.over):
		_zero_move()
		return
	if not joy_active:
		var kb := Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			kb.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			kb.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			kb.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			kb.y += 1.0
		if kb.length_squared() > 0.01:
			move = kb.normalized()
		else:
			move = Vector2.ZERO
	sim.player_move = move


func _zero_move() -> void:
	move = Vector2.ZERO
	if sim != null:
		sim.player_move = Vector2.ZERO


func _in_joy_zone(pos: Vector2) -> bool:
	var vp: Vector2 = hud.viewport_size()
	return pos.x < vp.x * 0.42 and pos.y > vp.y * 0.38

class_name CameraRig
extends Camera3D

# 跟随 + 阻尼 + 推镜 + 震屏，对应 Unity CameraRig。
var focus := Vector3(1500, 0, 800)
var target := Vector3(1500, 0, 800)
var last_target := Vector3(1500, 0, 800)
var punch := 0.0
var shake := 0.0
var zoom := 1.0
var zoom_target := 1.0
var frozen := false


func _ready() -> void:
	fov = 42.0
	near = 12.0
	far = 6000.0
	current = true
	position = focus + _offset(1.0)
	look_at(focus + Vector3(0, 34, -66), Vector3.UP)


func set_target(p: Vector3) -> void:
	target = p


func snap() -> void:
	focus = target
	last_target = target
	position = focus + _offset(1.0)
	look_at(focus + Vector3(0, 34, -66), Vector3.UP)


func add_punch(v: float) -> void:
	punch = maxf(punch, v)


func add_shake(v: float) -> void:
	shake = maxf(shake, v)


func set_zoom(z: float) -> void:
	zoom_target = z


func _offset(punch_k: float) -> Vector3:
	var k := zoom * punch_k
	return Vector3(0, 290.0 / k, 430.0 / k)


func _process(delta: float) -> void:
	if frozen:
		return
	# 目标位置已经做过渲染插值，直接跟随即可，不再二次平滑，避免操作延迟。
	# 瞬移/冲撞会在一帧内跳很远，这时镜头直接跟到位，否则会先拖后半秒再追上，看起来像卡顿。
	var jump := target.distance_to(last_target)
	last_target = target
	focus = target
	punch = lerp(punch, 0.0, 1.0 - exp(-6.0 * delta))
	shake = lerp(shake, 0.0, 1.0 - exp(-8.0 * delta))
	zoom = lerp(zoom, zoom_target, 1.0 - exp(-3.0 * delta))

	var want := focus + _offset(1.0 + punch * 0.05)
	if jump > 150.0:
		position = want
	else:
		position = position.lerp(want, 1.0 - exp(-20.0 * delta))
	if shake > 0.05:
		position += Vector3(randf_range(-shake, shake), randf_range(-shake, shake) * 0.6, 0.0) * 2.2
	look_at(focus + Vector3(0, 34, -66), Vector3.UP)

class_name CameraRig
extends Camera3D

# 固定俯角与高度的跟随相机。
# 机位只沿 XZ 平移：高度、朝向、俯角在整局中保持常量；
# 推镜与打击感只改 FOV，不再升降机位或改变俯角，行走时画面保持稳定。
const CAM_HEIGHT := 290.0
const CAM_BACK := 430.0
const LOOK_LIFT := 34.0
const LOOK_AHEAD := -66.0
const BASE_FOV := 42.0

var focus := Vector3(1500, 0, 800)
var target := Vector3(1500, 0, 800)
var punch := 0.0
var shake := 0.0
var zoom := 1.0
var zoom_target := 1.0
var frozen := false


func _ready() -> void:
	fov = BASE_FOV
	near = 12.0
	far = 6000.0
	current = true
	_apply_view()


func set_target(p: Vector3) -> void:
	target = p


func snap() -> void:
	focus = target
	_apply_view()


func add_punch(v: float) -> void:
	punch = maxf(punch, v)


func add_shake(v: float) -> void:
	shake = maxf(shake, v)


func set_zoom(z: float) -> void:
	zoom_target = z


func _apply_view() -> void:
	# 位置与注视点都用固定偏移：俯角、机位高度不随焦点、速度或推镜变化。
	position = Vector3(focus.x, CAM_HEIGHT, focus.z + CAM_BACK)
	look_at(Vector3(focus.x, LOOK_LIFT, focus.z + LOOK_AHEAD), Vector3.UP)


func _process(delta: float) -> void:
	if frozen:
		return
	# 目标位置已经过渲染插值（连续匀速），相机直接跟死即可，不再二次平滑，
	# 否则平滑滞后会让角色在屏幕中心前后滑动，产生「视角抖动」。
	focus = target
	punch = lerp(punch, 0.0, 1.0 - exp(-6.0 * delta))
	shake = lerp(shake, 0.0, 1.0 - exp(-8.0 * delta))
	zoom = lerp(zoom, zoom_target, 1.0 - exp(-3.0 * delta))
	# 推镜只改 FOV，机位与俯角保持不变。
	fov = clampf(BASE_FOV * zoom - punch * 0.9, 24.0, 58.0)
	_apply_view()
	if shake > 0.05:
		# 震屏只平移机位、不重新对准，朝向因此不会被甩动。
		position += Vector3(randf_range(-shake, shake), randf_range(-shake, shake) * 0.6, 0.0) * 2.2

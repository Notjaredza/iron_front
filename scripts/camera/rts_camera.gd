class_name RtsCamera
extends Camera3D
## Iron Front: the fly-over camera. It behaves like Worlds War 1's (fresh code).
## - WASD (or the arrows) move it, and Shift moves faster.
## - The wheel zooms, and the tilt follows the height: 30 degrees close in, 74 at 230 m, near straight down from high up.
## - Q and E turn it. Holding the middle mouse button and dragging turns it too.
## - In the last part of the zoom it comes down to eye height and looks forward.
## It follows the ground's height and stays over the map.

const EYE_START := 40.0
const EYE_MIN := 2.0
const EYE_H := 2.0
const EYE_PITCH := 5.0
const MAX_H := 9000.0

var data: MapData
var target := Vector3(4000, 0, 6000)
var yaw := 0.0
var height := 600.0
var height_goal := 600.0
var tilt := 0.0
var enabled := true                      # tools drive the camera themselves with this off
var _ground := 0.0
var _drag := false


func zoom_pitch(h: float) -> float:
	if h >= 1000.0:
		return lerpf(74.0, 89.0, clampf((h - 1000.0) / 8000.0, 0.0, 1.0))
	var s := clampf(log(h / 14.0) / log(230.0 / 14.0), 0.0, 1.0)
	s = s * s * (3.0 - 2.0 * s)
	return lerpf(30.0, 74.0, s)


func fwd() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


func right() -> Vector3:
	return Vector3(-cos(yaw), 0, sin(yaw))


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			height_goal = maxf(height_goal / (1.3 if height_goal < EYE_START else 1.18), EYE_MIN)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			height_goal = minf(height_goal * 1.18, MAX_H)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = mb.pressed
	elif event is InputEventMouseMotion and _drag:
		yaw -= (event as InputEventMouseMotion).relative.x * 0.005


func _process(delta: float) -> void:
	if not enabled:
		return
	height = lerpf(height, height_goal, 1.0 - exp(-delta * 8.0))
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan += fwd()
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan -= fwd()
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan -= right()
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan += right()
	if Input.is_key_pressed(KEY_Q): yaw += delta * 1.2
	if Input.is_key_pressed(KEY_E): yaw -= delta * 1.2
	var fast := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	target += pan * delta * (10.0 + height * 0.8) * fast
	place()


## Puts the camera where target, yaw and height say (tools call this after setting them).
func place() -> void:
	if data != null:
		var sz := data.size_m()
		target.x = clampf(target.x, 0.0, sz.x)
		target.z = clampf(target.z, 0.0, sz.y)
		var g := data.ground_y(Vector2(target.x, target.z))
		_ground = g if absf(_ground - g) > 30.0 else lerpf(_ground, g, 0.12)
	var aim := Vector3(target.x, _ground, target.z)
	var pitch := zoom_pitch(height)
	var pos := aim + Vector3(0, height, 0) - fwd() * (height / tan(deg_to_rad(pitch)))
	var u := clampf((EYE_START - height) / (EYE_START - EYE_MIN), 0.0, 1.0)
	tilt = u * u * (3.0 - 2.0 * u)
	if tilt > 0.0:
		var eye := Vector3(target.x, _ground + EYE_H, target.z)
		pos = pos.lerp(eye, tilt)
		var p := deg_to_rad(lerpf(pitch, EYE_PITCH, tilt))
		position = pos
		look_at(pos + fwd() * cos(p) + Vector3.DOWN * sin(p), Vector3.UP)
	else:
		position = pos
		look_at(aim, Vector3.UP)
	far = clampf(height * 3.5, 3000.0, 30000.0)
	near = (0.15 if tilt > 0.5 else 0.5) if height < 800.0 else 8.0

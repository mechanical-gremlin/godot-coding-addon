@tool
class_name ESCameraAction
extends ESAction
## Action for Camera2D/Camera3D control: follow a target, apply a shake, or zoom/adjust FOV.
## Add an ESEventController to the Camera2D/Camera3D itself, or reference the camera
## via camera_path from any other node's controller.
## For Camera3D the "zoom" operations adjust the camera's Field of View (FOV) instead.

enum CameraOp {
	FOLLOW_TARGET, ## Smoothly move (or snap) the camera to a target node's position
	SET_ZOOM,      ## Set the camera zoom level (1.0 = normal, 2.0 = zoomed in)
	SHAKE,         ## Apply a brief screen-shake effect
	RESET_ZOOM,    ## Reset zoom to 1.0
	SET_OFFSET,    ## Shift the camera view by an offset without moving the camera node
}

## Operation to perform.
@export var operation: CameraOp = CameraOp.FOLLOW_TARGET

## Path to the Camera2D or Camera3D node.
## Leave empty to search for the first Camera2D or Camera3D in the current scene automatically.
@export var camera_path: NodePath = NodePath("")

## Path to the node the camera should follow (FOLLOW_TARGET).
## Leave empty to use the EventController's parent.
@export var follow_target_path: NodePath = NodePath("")

## Lerp speed for smooth camera follow (FOLLOW_TARGET).
## 0 = instant snap. Values around 3–10 feel smooth.
@export var follow_speed: float = 5.0

## Zoom level for SET_ZOOM (1.0 = normal, 2.0 = zoomed in, 0.5 = zoomed out).
@export var zoom_level: float = 1.0

## Shake intensity in pixels (SHAKE).
@export var shake_intensity: float = 8.0

## Shake duration in seconds (SHAKE).
@export var shake_duration: float = 0.3

## Camera view offset X in pixels (SET_OFFSET).
@export var offset_x: float = 0.0

## Camera view offset Y in pixels (SET_OFFSET).
@export var offset_y: float = 0.0


func get_summary() -> String:
	match operation:
		CameraOp.FOLLOW_TARGET:
			var t := str(follow_target_path) if not follow_target_path.is_empty() else "parent"
			return "Camera: Follow %s (speed %.1f)" % [t, follow_speed]
		CameraOp.SET_ZOOM:
			return "Camera: Set zoom %.2fx" % zoom_level
		CameraOp.SHAKE:
			return "Camera: Shake (intensity %.1f, %.2fs)" % [shake_intensity, shake_duration]
		CameraOp.RESET_ZOOM:
			return "Camera: Reset zoom"
		CameraOp.SET_OFFSET:
			return "Camera: Set offset (%.0f, %.0f)" % [offset_x, offset_y]
	return "Camera action"


func get_category() -> String:
	return "Camera"


func execute(controller: Node, delta: float) -> void:
	var camera := _resolve_camera_node(controller)
	if not camera:
		return

	if camera is Camera2D:
		_execute_2d(camera as Camera2D, controller, delta)
	elif camera is Camera3D:
		_execute_3d(camera as Camera3D, controller, delta)


func _execute_2d(camera: Camera2D, controller: Node, delta: float) -> void:
	match operation:
		CameraOp.FOLLOW_TARGET:
			_do_follow_2d(controller, camera, delta)
		CameraOp.SET_ZOOM:
			camera.zoom = Vector2(zoom_level, zoom_level)
		CameraOp.SHAKE:
			_do_shake_2d(controller, camera)
		CameraOp.RESET_ZOOM:
			camera.zoom = Vector2.ONE
		CameraOp.SET_OFFSET:
			camera.offset = Vector2(offset_x, offset_y)


func _execute_3d(camera: Camera3D, controller: Node, delta: float) -> void:
	match operation:
		CameraOp.FOLLOW_TARGET:
			_do_follow_3d(controller, camera, delta)
		CameraOp.SET_ZOOM:
			# Camera3D uses FOV instead of zoom.  A zoom_level of 1.0 keeps
			# the default 75° FOV.  Values > 1.0 narrow the FOV (zoom in);
			# values < 1.0 widen it (zoom out).  Clamped to a safe range.
			camera.fov = clampf(75.0 / maxf(zoom_level, 0.01), 1.0, 170.0)
		CameraOp.SHAKE:
			_do_shake_3d(controller, camera)
		CameraOp.RESET_ZOOM:
			camera.fov = 75.0
		CameraOp.SET_OFFSET:
			# Camera3D has h_offset and v_offset (world-units) analogous to
			# Camera2D.offset (pixels).
			camera.h_offset = offset_x
			camera.v_offset = offset_y


func _do_follow_2d(controller: Node, camera: Camera2D, delta: float) -> void:
	var target_node: Node
	if follow_target_path.is_empty():
		target_node = controller.get_parent()
	else:
		target_node = controller.get_node_or_null(follow_target_path)
		if not target_node:
			var parent := controller.get_parent()
			if parent:
				target_node = parent.get_node_or_null(follow_target_path)

	if not target_node or not target_node is Node2D:
		return

	var target_pos := (target_node as Node2D).global_position
	if follow_speed <= 0.0:
		camera.global_position = target_pos
	else:
		camera.global_position = camera.global_position.lerp(target_pos, follow_speed * delta)


func _do_follow_3d(controller: Node, camera: Camera3D, delta: float) -> void:
	var target_node: Node
	if follow_target_path.is_empty():
		target_node = controller.get_parent()
	else:
		target_node = controller.get_node_or_null(follow_target_path)
		if not target_node:
			var parent := controller.get_parent()
			if parent:
				target_node = parent.get_node_or_null(follow_target_path)

	if not target_node or not target_node is Node3D:
		return

	var target_pos := (target_node as Node3D).global_position
	if follow_speed <= 0.0:
		camera.global_position = target_pos
	else:
		camera.global_position = camera.global_position.lerp(target_pos, follow_speed * delta)


func _do_shake_2d(controller: Node, camera: Camera2D) -> void:
	const SHAKE_INTERVAL := 0.05
	var tween := controller.create_tween()
	var steps := maxi(1, int(shake_duration / SHAKE_INTERVAL))
	for _i in steps:
		tween.tween_callback(func():
			camera.offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
		)
		tween.tween_interval(SHAKE_INTERVAL)
	tween.tween_callback(func(): camera.offset = Vector2.ZERO)


func _do_shake_3d(controller: Node, camera: Camera3D) -> void:
	const SHAKE_INTERVAL := 0.05
	var tween := controller.create_tween()
	var steps := maxi(1, int(shake_duration / SHAKE_INTERVAL))
	for _i in steps:
		tween.tween_callback(func():
			camera.h_offset = randf_range(-shake_intensity, shake_intensity)
			camera.v_offset = randf_range(-shake_intensity, shake_intensity)
		)
		tween.tween_interval(SHAKE_INTERVAL)
	tween.tween_callback(func():
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	)


func _resolve_camera_node(controller: Node) -> Node:
	if not camera_path.is_empty():
		var cam := controller.get_node_or_null(camera_path)
		if cam is Camera2D or cam is Camera3D:
			return cam
		var parent := controller.get_parent()
		if parent:
			cam = parent.get_node_or_null(camera_path)
			if cam is Camera2D or cam is Camera3D:
				return cam

	# Auto-find the first Camera2D or Camera3D in the current scene.
	var scene_root := controller.get_tree().current_scene
	if scene_root:
		var cam := _find_camera_in_tree(scene_root)
		if cam:
			return cam

	push_warning("EventSheet: CameraAction: No Camera2D or Camera3D found. " \
		+ "Set camera_path or add a camera to the scene.")
	return null


func _find_camera_in_tree(node: Node) -> Node:
	if node is Camera2D or node is Camera3D:
		return node
	for child in node.get_children():
		var found := _find_camera_in_tree(child)
		if found:
			return found
	return null

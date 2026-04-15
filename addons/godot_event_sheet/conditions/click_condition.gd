@tool
class_name ESClickCondition
extends ESCondition
## Condition that fires when a game object is clicked or touched directly.
## Works with CollisionObject2D and CollisionObject3D nodes that have the
## "input_event" signal. The EventController connects the signal at runtime.

enum ClickType {
	CLICKED,    ## Fires when the object is clicked (mouse button pressed on it)
	RELEASED,   ## Fires when the mouse button is released on the object
}

## Whether to detect a click press or release.
@export var click_type: ClickType = ClickType.CLICKED

## Path to the CollisionObject2D/3D node.
## Leave empty to use the EventController's parent node.
@export var target_path: NodePath = NodePath("")

## Internal flag set by the runtime when a matching click occurs.
var _triggered: bool = false

## The position of the click in world space (available during action execution).
var click_position: Vector2 = Vector2.ZERO


func get_summary() -> String:
	var type_names := ["clicked", "click released"]
	var desc := "Object %s" % type_names[click_type]
	if not target_path.is_empty():
		desc += " on %s" % str(target_path)
	return desc


func get_category() -> String:
	return "Input"


func evaluate(controller: Node, _delta: float) -> bool:
	if _triggered:
		_triggered = false
		return true
	return false


## Called by the EventController when the CollisionObject2D receives input.
## Signature: _input_event(viewport, event, shape_idx)
func _on_input_event_2d(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if click_type == ClickType.CLICKED and mb.pressed:
				click_position = mb.position
				_triggered = true
			elif click_type == ClickType.RELEASED and not mb.pressed:
				click_position = mb.position
				_triggered = true


## Called by the EventController when the CollisionObject3D receives input.
## Signature: _input_event(camera, event, position, normal, shape_idx)
func _on_input_event_3d(camera: Node, event: InputEvent, position: Vector3,
		normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if click_type == ClickType.CLICKED and mb.pressed:
				click_position = Vector2(position.x, position.y)
				_triggered = true
			elif click_type == ClickType.RELEASED and not mb.pressed:
				click_position = Vector2(position.x, position.y)
				_triggered = true

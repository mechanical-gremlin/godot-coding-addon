@tool
class_name ESMouseHoverCondition
extends ESCondition
## Condition that detects when the mouse cursor enters or exits a node.
## Works with Control nodes (buttons, panels, etc.) and CollisionObject2D/3D
## nodes (sprites with collision shapes). The EventController automatically
## connects the appropriate signals at runtime.

enum HoverType {
	MOUSE_ENTERED,    ## Fires once when the mouse enters the node
	MOUSE_EXITED,     ## Fires once when the mouse exits the node
	IS_HOVERED,       ## True every frame while the mouse is over the node
}

## Which hover event to detect.
@export var hover_type: HoverType = HoverType.MOUSE_ENTERED

## Path to the node to detect hover on (Control, Area2D, or CollisionObject2D/3D).
## Leave empty to use the EventController's parent node.
@export var target_path: NodePath = NodePath("")

## Internal flag set by the runtime when a matching hover event occurs.
var _triggered: bool = false

## Whether the mouse is currently hovering over the target.
var _is_hovered: bool = false


func get_summary() -> String:
	var type_names := ["mouse entered", "mouse exited", "is hovered"]
	var desc := "Hover: %s" % type_names[hover_type]
	if not target_path.is_empty():
		desc += " on %s" % str(target_path)
	return desc


func get_category() -> String:
	return "Hover"


func evaluate(controller: Node, _delta: float) -> bool:
	if hover_type == HoverType.IS_HOVERED:
		return _is_hovered
	if _triggered:
		_triggered = false
		return true
	return false


## Called when the mouse enters the target node.
func _on_mouse_entered() -> void:
	_is_hovered = true
	if hover_type == HoverType.MOUSE_ENTERED:
		_triggered = true


## Called when the mouse exits the target node.
func _on_mouse_exited() -> void:
	_is_hovered = false
	if hover_type == HoverType.MOUSE_EXITED:
		_triggered = true

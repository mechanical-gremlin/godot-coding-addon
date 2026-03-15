@tool
extends ESAction
## Action that applies gravity to a CharacterBody2D or CharacterBody3D.
## Use this with "Every Physics Frame" to simulate platformer-style gravity.

## Gravity force in pixels/units per second squared.
@export var gravity: float = 980.0

## Maximum downward speed (terminal velocity).
@export var max_fall_speed: float = 1500.0

## Path to the CharacterBody node. Leave empty to use the EventController's parent.
@export var target_path: NodePath = NodePath("")

## If true, call move_and_slide() after applying gravity.
## Disable this if another action already calls move_and_slide().
@export var call_move_and_slide: bool = true


func get_summary() -> String:
	var target := str(target_path) if not target_path.is_empty() else "parent"
	return "Apply gravity (%.0f) to %s" % [gravity, target]


func get_category() -> String:
	return "Physics"


func execute(controller: Node, delta: float) -> void:
	var target: Node = _resolve_target(controller)
	if not target:
		return

	if target is CharacterBody2D:
		var body := target as CharacterBody2D
		if not body.is_on_floor():
			body.velocity.y += gravity * delta
			if body.velocity.y > max_fall_speed:
				body.velocity.y = max_fall_speed
		if call_move_and_slide:
			body.move_and_slide()
	elif target is CharacterBody3D:
		var body := target as CharacterBody3D
		if not body.is_on_floor():
			body.velocity.y += gravity * delta
			if body.velocity.y > max_fall_speed:
				body.velocity.y = max_fall_speed
		if call_move_and_slide:
			body.move_and_slide()
	else:
		push_warning("EventSheet: Gravity action requires a CharacterBody2D or CharacterBody3D.")


func _resolve_target(controller: Node) -> Node:
	if target_path.is_empty():
		return controller.get_parent()
	return controller.get_node_or_null(target_path)

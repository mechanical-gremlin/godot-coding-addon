@tool
class_name ESStateAction
extends ESAction
## Action for managing game states on nodes using metadata.
## States are stored as string metadata on the target node, making them easy
## to query from State conditions or property conditions.
##
## Common patterns:
##   - Turn-based games:  Set state "player_turn" / "enemy_turn" on a GameManager node.
##   - Boss phases:       Set state "phase_1" / "phase_2" / "phase_3" on the boss.
##   - Power-ups:         Set state "powered_up" on the player, then check with a timer.
##   - Game flow:         Set state "playing" / "paused" / "game_over" on the scene root.

enum StateOp {
	SET,   ## Set the state to a new value (replaces previous state).
	CLEAR, ## Remove the state metadata entirely.
}

## The operation to perform on the state.
@export var operation: StateOp = StateOp.SET

## Path to the node whose state to manage. Leave empty for the EventController's
## parent node.
@export var target_path: NodePath = NodePath("")

## The name used to store the state in the node's metadata.
## Multiple independent states can coexist on one node by using different names.
@export var state_name: String = "state"

## The value to assign when using SET (ignored for CLEAR).
@export var state_value: String = ""


func get_summary() -> String:
	var target := str(target_path) if not target_path.is_empty() else "parent"
	match operation:
		StateOp.SET:
			return "Set state '%s' = \"%s\" on %s" % [state_name, state_value, target]
		StateOp.CLEAR:
			return "Clear state '%s' on %s" % [state_name, target]
	return "State action"


func get_category() -> String:
	return "State"


func execute(controller: Node, _delta: float) -> void:
	var target := _resolve_target(controller)
	if not target:
		push_warning("EventSheet: State action – target node not found.")
		return

	match operation:
		StateOp.SET:
			target.set_meta(&"_es_state_%s" % state_name, state_value)
		StateOp.CLEAR:
			if target.has_meta(&"_es_state_%s" % state_name):
				target.remove_meta(&"_es_state_%s" % state_name)


func _resolve_target(controller: Node) -> Node:
	if target_path.is_empty():
		return controller.get_parent()
	var path_str := str(target_path)
	if path_str == "$collider":
		var meta_val = controller.get_meta(&"_es_last_collided_node", null)
		return meta_val if meta_val is Node else null
	var target := controller.get_node_or_null(target_path)
	if target:
		return target
	var parent := controller.get_parent()
	if parent:
		target = parent.get_node_or_null(target_path)
		if target:
			return target
	return null

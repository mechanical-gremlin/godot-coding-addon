@tool
class_name ESCallMethodAction
extends ESAction
## Action that calls a method by name on a target node.
## Enables object-to-object interaction such as dealing damage, triggering
## custom behaviors, or calling engine methods like reload_current_scene.
##
## Common patterns:
##   - Call take_damage() on an enemy after a collision.
##   - Call reload_current_scene() on the SceneTree via a helper.
##   - Trigger any custom method defined on another node.

## Path to the target node whose method to call.
## Leave empty to use the EventController's parent.
## Use "$collider" to target the last collided node.
@export var target_path: NodePath = NodePath("")

## The name of the method to call on the target node.
@export var method_name: String = ""

## Arguments to pass to the method (as strings, auto-converted).
## Uses the same string-to-variant conversion as Emit Signal.
@export var arguments: PackedStringArray = PackedStringArray()

## When true, use call_deferred() instead of calling the method immediately.
## Required when calling methods that modify the scene tree during a physics
## callback (e.g., reload_current_scene).
@export var use_deferred: bool = false


func get_summary() -> String:
	var target := str(target_path) if not target_path.is_empty() else "parent"
	var args_str := ", ".join(arguments) if arguments.size() > 0 else ""
	var deferred_str := " (deferred)" if use_deferred else ""
	return "Call %s.%s(%s)%s" % [target, method_name, args_str, deferred_str]


func get_category() -> String:
	return "Methods"


func execute(controller: Node, _delta: float) -> void:
	if method_name.is_empty():
		push_warning("EventSheet: CallMethod action has no method name.")
		return

	var target: Node = _resolve_target(controller)
	if not target:
		push_warning("EventSheet: CallMethod target node not found.")
		return

	if not target.has_method(method_name):
		push_warning("EventSheet: Method '%s' not found on %s" % [method_name, target.name])
		return

	# Convert arguments.
	var args: Array = []
	for arg_str in arguments:
		args.append(_convert_arg(arg_str))

	if use_deferred:
		match args.size():
			0: target.call_deferred(method_name)
			1: target.call_deferred(method_name, args[0])
			2: target.call_deferred(method_name, args[0], args[1])
			3: target.call_deferred(method_name, args[0], args[1], args[2])
			4: target.call_deferred(method_name, args[0], args[1], args[2], args[3])
			_: target.call_deferred(method_name, args[0], args[1], args[2], args[3])
	else:
		target.callv(method_name, args)


## Convert a string argument to the appropriate type.
func _convert_arg(val: String) -> Variant:
	if val.to_lower() == "true":
		return true
	if val.to_lower() == "false":
		return false
	if val.is_valid_int():
		return int(val)
	if val.is_valid_float():
		return float(val)
	return val


func _resolve_target(controller: Node) -> Node:
	if target_path.is_empty():
		return controller.get_parent()
	var path_str := str(target_path)
	if path_str == "$collider":
		var meta_val = controller.get_meta(&"_es_last_collided_node", null)
		return meta_val if meta_val is Node else null

	# Try the path relative to the controller first.
	var target := controller.get_node_or_null(target_path)
	if target:
		return target

	# Fallback: try relative to the controller's parent.
	var parent := controller.get_parent()
	if parent:
		target = parent.get_node_or_null(target_path)
		if target:
			return target

	push_warning("EventSheet: CallMethod target node not found at path '%s'." % str(target_path))
	return null

@tool
class_name ESClampAction
extends ESAction
## Action that clamps a node's property value between minimum and maximum bounds.
## Useful for keeping objects within screen boundaries, limiting health values,
## restricting paddle movement, etc.

## Path to the target node. Leave empty to use the EventController's parent.
## Use "$collider" to target the last collided node.
@export var target_path: NodePath = NodePath("")

## The property name to clamp (supports dot notation like "position.x").
@export var property_name: String = ""

## The minimum allowed value.
@export var min_value: float = 0.0

## The maximum allowed value.
@export var max_value: float = 1000.0


func get_summary() -> String:
	var target := str(target_path) if not target_path.is_empty() else "parent"
	return "Clamp %s.%s to [%.0f, %.0f]" % [target, property_name, min_value, max_value]


func get_category() -> String:
	return "Properties"


func execute(controller: Node, _delta: float) -> void:
	var target: Node = _resolve_target(controller)
	if not target or property_name.is_empty():
		return

	var parts := property_name.split(".")
	if parts.size() == 1:
		_clamp_simple(target, property_name)
	else:
		_clamp_nested(target, parts)


func _clamp_simple(target: Node, prop: String) -> void:
	if not prop in target:
		push_warning("EventSheet: Property '%s' not found on %s" % [prop, target.name])
		return

	var current = target.get(prop)
	if current is float or current is int:
		target.set(prop, clampf(float(current), min_value, max_value))


func _clamp_nested(target: Node, parts: PackedStringArray) -> void:
	var current: Variant = target
	for i in range(parts.size() - 1):
		if current is Object and parts[i] in current:
			current = current.get(parts[i])
		else:
			push_warning("EventSheet: Cannot navigate property path '%s'" % property_name)
			return

	var final_prop := parts[parts.size() - 1]

	if current is Vector2:
		var vec := current as Vector2
		match final_prop:
			"x":
				vec.x = clampf(vec.x, min_value, max_value)
			"y":
				vec.y = clampf(vec.y, min_value, max_value)
			_:
				push_warning("EventSheet: Unknown Vector2 component '%s'" % final_prop)
				return
		target.set(parts[0], vec)
	elif current is Vector3:
		var vec := current as Vector3
		match final_prop:
			"x":
				vec.x = clampf(vec.x, min_value, max_value)
			"y":
				vec.y = clampf(vec.y, min_value, max_value)
			"z":
				vec.z = clampf(vec.z, min_value, max_value)
			_:
				push_warning("EventSheet: Unknown Vector3 component '%s'" % final_prop)
				return
		target.set(parts[0], vec)


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

	push_warning("EventSheet: Clamp target node not found at path '%s'. " \
		+ "Try '../NodeName' for sibling nodes." % str(target_path))
	return null

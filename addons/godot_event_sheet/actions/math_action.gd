@tool
class_name ESMathAction
extends ESAction
## Action that applies a math function to a numeric property on a target node.

enum MathOp {
	ABS,   ## Absolute value
	FLOOR, ## Floor (round down)
	CEIL,  ## Ceiling (round up)
	ROUND, ## Round to nearest integer
	SQRT,  ## Square root (clamped to 0 minimum)
	SIN,   ## Sine (input in degrees)
	COS,   ## Cosine (input in degrees)
	LERP,  ## Lerp toward a target value
}

## Path to the target node. Leave empty to use the EventController's parent.
@export var target_path: NodePath = NodePath("")

## Name of the property to apply the math function to (e.g., speed, scale.x).
@export var property_name: String = ""

## The math function to apply.
@export var operation: MathOp = MathOp.ABS

## Lerp target value (used only when operation is LERP).
@export var lerp_target: float = 0.0

## Lerp weight 0–1 (used only when operation is LERP).
@export var lerp_weight: float = 0.1


func get_summary() -> String:
	var op_names := ["abs", "floor", "ceil", "round", "sqrt", "sin", "cos", "lerp"]
	var target := str(target_path) if not target_path.is_empty() else "parent"
	return "Math: %s(%s.%s)" % [op_names[operation], target, property_name]


func get_category() -> String:
	return "Math"


func execute(controller: Node, _delta: float) -> void:
	var target: Node
	if target_path.is_empty():
		target = controller.get_parent()
	else:
		var path_str := str(target_path)
		if path_str == "$collider":
			var meta_val = controller.get_meta(&"_es_last_collided_node", null)
			target = meta_val if meta_val is Node else null
		else:
			target = controller.get_node_or_null(target_path)
			if not target and controller.get_parent():
				target = controller.get_parent().get_node_or_null(target_path)

	if not target or property_name.is_empty():
		return

	var current = target.get(property_name)
	if current == null:
		push_warning("EventSheet: MathAction: property '%s' not found on %s" % [property_name, target.name])
		return

	var val := float(current)
	match operation:
		MathOp.ABS:
			target.set(property_name, abs(val))
		MathOp.FLOOR:
			target.set(property_name, floor(val))
		MathOp.CEIL:
			target.set(property_name, ceil(val))
		MathOp.ROUND:
			target.set(property_name, round(val))
		MathOp.SQRT:
			target.set(property_name, sqrt(max(val, 0.0)))
		MathOp.SIN:
			target.set(property_name, sin(deg_to_rad(val)))
		MathOp.COS:
			target.set(property_name, cos(deg_to_rad(val)))
		MathOp.LERP:
			target.set(property_name, lerp(val, lerp_target, lerp_weight))

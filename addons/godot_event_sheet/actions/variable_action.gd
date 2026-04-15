@tool
class_name ESVariableAction
extends ESAction
## Action for managing event-sheet variables stored as metadata on the
## EventController.  Variables are lightweight key-value pairs that persist
## for the lifetime of the controller and can be read back using the
## matching Variable condition.
##
## Variables are stored under the metadata key `_es_var_{variable_name}`.
## By default a variable that has never been set is treated as `0` for
## numeric operations and `""` for string operations.

enum VariableOp {
	SET,       ## Replace the variable with the given value.
	ADD,       ## Add a numeric value to the variable.
	SUBTRACT,  ## Subtract a numeric value from the variable.
	MULTIPLY,  ## Multiply the variable by a numeric value.
	TOGGLE,    ## Flip a boolean variable (true ↔ false).
}

## The operation to perform on the variable.
@export var operation: VariableOp = VariableOp.SET

## Name of the variable (used as the metadata key suffix).
@export var variable_name: String = ""

## The value to assign or use in the arithmetic operation.
## Automatically converted to the appropriate type at runtime.
@export var value: String = ""


func get_summary() -> String:
	match operation:
		VariableOp.SET:
			return "Set variable '%s' = %s" % [variable_name, value]
		VariableOp.ADD:
			return "Add %s to variable '%s'" % [value, variable_name]
		VariableOp.SUBTRACT:
			return "Subtract %s from variable '%s'" % [value, variable_name]
		VariableOp.MULTIPLY:
			return "Multiply variable '%s' by %s" % [variable_name, value]
		VariableOp.TOGGLE:
			return "Toggle variable '%s'" % variable_name
	return "Variable action"


func get_category() -> String:
	return "Variables"


func execute(controller: Node, _delta: float) -> void:
	if variable_name.is_empty():
		push_warning("EventSheet: Variable action – no variable name specified.")
		return

	var meta_key := &"_es_var_%s" % variable_name

	match operation:
		VariableOp.SET:
			controller.set_meta(meta_key, _auto_convert(value))
		VariableOp.ADD:
			var current = _get_current(controller, meta_key, 0.0)
			controller.set_meta(meta_key, float(current) + float(value))
		VariableOp.SUBTRACT:
			var current = _get_current(controller, meta_key, 0.0)
			controller.set_meta(meta_key, float(current) - float(value))
		VariableOp.MULTIPLY:
			var current = _get_current(controller, meta_key, 0.0)
			controller.set_meta(meta_key, float(current) * float(value))
		VariableOp.TOGGLE:
			var current = _get_current(controller, meta_key, false)
			controller.set_meta(meta_key, not _to_bool(current))


## Return the current value of the variable, or [param default] if unset.
func _get_current(controller: Node, meta_key: StringName, default):
	if controller.has_meta(meta_key):
		return controller.get_meta(meta_key)
	return default


## Auto-convert a string value to int, float, or bool when possible.
static func _auto_convert(val: String):
	if val == "true":
		return true
	if val == "false":
		return false
	if val.is_valid_int():
		return val.to_int()
	if val.is_valid_float():
		return val.to_float()
	return val


## Coerce a value to bool.
static func _to_bool(val) -> bool:
	if val is bool:
		return val
	if val is float or val is int:
		return val != 0
	if val is String:
		return val == "true"
	return false

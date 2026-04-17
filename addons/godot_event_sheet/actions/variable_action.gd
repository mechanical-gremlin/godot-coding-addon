@tool
class_name ESVariableAction
extends ESAction
## Action for managing event-sheet variables stored as metadata on the
## EventController or in a global autoload singleton.
##
## LOCAL variables are stored under the metadata key `_es_var_{variable_name}`
## on the EventController and are destroyed when the controller is freed.
##
## GLOBAL variables are stored in the ESGlobalVariables autoload singleton
## and persist across scene changes — ideal for player HP, opened chests, etc.
##
## By default a variable that has never been set is treated as `0` for
## numeric operations and `""` for string operations.

enum VariableOp {
	SET,         ## Replace the variable with the given value.
	ADD,         ## Add a numeric value to the variable.
	SUBTRACT,    ## Subtract a numeric value from the variable.
	MULTIPLY,    ## Multiply the variable by a numeric value.
	TOGGLE,      ## Flip a boolean variable (true ↔ false).
	APPEND,      ## Append a value to the variable as an array.
	REMOVE,      ## Remove a value from the variable array.
	CLEAR_ARRAY, ## Clear the variable array (set to empty array).
}

enum VariableScope {
	LOCAL,  ## Stored on the EventController (dies with the node/scene).
	GLOBAL, ## Stored in the ESGlobalVariables autoload (survives scene changes).
}

## The operation to perform on the variable.
@export var operation: VariableOp = VariableOp.SET

## Whether the variable is local to this controller or globally persistent.
@export var scope: VariableScope = VariableScope.LOCAL

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
		VariableOp.APPEND:
			return "Append %s to variable '%s'" % [value, variable_name]
		VariableOp.REMOVE:
			return "Remove %s from variable '%s'" % [value, variable_name]
		VariableOp.CLEAR_ARRAY:
			return "Clear array variable '%s'" % variable_name
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
			_set_var(controller, meta_key, _auto_convert(value))
		VariableOp.ADD:
			var current = _get_current(controller, meta_key, 0.0)
			var numeric_val := _to_float(value)
			_set_var(controller, meta_key, float(current) + numeric_val)
		VariableOp.SUBTRACT:
			var current = _get_current(controller, meta_key, 0.0)
			var numeric_val := _to_float(value)
			_set_var(controller, meta_key, float(current) - numeric_val)
		VariableOp.MULTIPLY:
			var current = _get_current(controller, meta_key, 0.0)
			var numeric_val := _to_float(value)
			_set_var(controller, meta_key, float(current) * numeric_val)
		VariableOp.TOGGLE:
			var current = _get_current(controller, meta_key, false)
			_set_var(controller, meta_key, not _to_bool(current))
		VariableOp.APPEND:
			var current = _get_current(controller, meta_key, [])
			if current is Array:
				current.append(_auto_convert(value))
				_set_var(controller, meta_key, current)
			else:
				# Convert existing scalar to array and append.
				push_warning("EventSheet: Variable '%s' is not an array; converting to array." % variable_name)
				_set_var(controller, meta_key, [current, _auto_convert(value)])
		VariableOp.REMOVE:
			var current = _get_current(controller, meta_key, [])
			if current is Array:
				var val_to_remove = _auto_convert(value)
				current.erase(val_to_remove)
				_set_var(controller, meta_key, current)
		VariableOp.CLEAR_ARRAY:
			_set_var(controller, meta_key, [])


## Write a variable value, respecting the scope setting.
func _set_var(controller: Node, meta_key: StringName, val) -> void:
	if scope == VariableScope.GLOBAL:
		var globals = controller.get_node_or_null("/root/ESGlobalVariables")
		if globals:
			globals.set_variable(str(meta_key), val)
		else:
			push_warning("EventSheet: ESGlobalVariables autoload not found. "
				+ "Add it as an autoload in Project Settings or enable the plugin.")
			# Fall back to local storage.
			controller.set_meta(meta_key, val)
	else:
		controller.set_meta(meta_key, val)


## Return the current value of the variable, or [param default] if unset.
func _get_current(controller: Node, meta_key: StringName, default):
	if scope == VariableScope.GLOBAL:
		var globals = controller.get_node_or_null("/root/ESGlobalVariables")
		if globals and globals.has_variable(str(meta_key)):
			return globals.get_variable(str(meta_key))
		return default
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


## Safely convert a string to float, returning 0.0 for non-numeric strings.
static func _to_float(val: String) -> float:
	if val.is_valid_float():
		return val.to_float()
	if val.is_valid_int():
		return float(val.to_int())
	push_warning("EventSheet: Variable action – '%s' is not a valid number, using 0." % val)
	return 0.0

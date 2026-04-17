extends Node
## Lightweight autoload singleton that stores global event-sheet variables.
## Variables stored here survive scene changes, enabling cross-scene persistence
## for game state such as player HP, opened chests, and spawn positions.
##
## This script is automatically registered as an autoload named
## "ESGlobalVariables" when the godot_event_sheet plugin is enabled.

## Dictionary holding all global event-sheet variables.
var _variables: Dictionary = {}


## Set a global variable.
func set_variable(key: String, value) -> void:
	_variables[key] = value


## Get a global variable, returning [param default] if not set.
func get_variable(key: String, default = null):
	return _variables.get(key, default)


## Check if a global variable exists.
func has_variable(key: String) -> bool:
	return _variables.has(key)


## Remove a global variable.
func remove_variable(key: String) -> void:
	_variables.erase(key)


## Clear all global variables.
func clear_all() -> void:
	_variables.clear()

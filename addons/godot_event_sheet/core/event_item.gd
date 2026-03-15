@tool
class_name ESEventItem
extends Resource
## A single event that pairs one or more Conditions with one or more Actions.
## When conditions are met (using AND or OR logic), all actions are executed.

enum LogicMode {
	AND, ## All conditions must be true
	OR,  ## At least one condition must be true
}

## Display name for this event (shown in the editor).
@export var event_name: String = ""

## Whether this event is active.
@export var enabled: bool = true

## How conditions are combined: AND (all must be true) or OR (any must be true).
@export var logic_mode: LogicMode = LogicMode.AND

## Conditions that are evaluated using the logic mode.
@export var conditions: Array[Resource] = []  # Array of ESCondition

## Actions executed (in order) when the conditions are met.
@export var actions: Array[Resource] = []  # Array of ESAction


## Add a condition and return it.
func add_condition(condition: Resource) -> void:
	conditions.append(condition)
	emit_changed()


## Remove a condition at the given index.
func remove_condition(index: int) -> void:
	if index >= 0 and index < conditions.size():
		conditions.remove_at(index)
		emit_changed()


## Add an action and return it.
func add_action(action: Resource) -> void:
	actions.append(action)
	emit_changed()


## Remove an action at the given index.
func remove_action(index: int) -> void:
	if index >= 0 and index < actions.size():
		actions.remove_at(index)
		emit_changed()

@tool
class_name ESRepeatAction
extends ESAction
## Action that causes the remaining actions in the event to repeat N times.
## Handled specially by EventController: when encountered, the subsequent
## actions are executed repeat_count times synchronously.

## How many times to repeat the following actions.
@export var repeat_count: int = 3


func get_summary() -> String:
	return "Repeat next actions %d time%s" % [repeat_count, "s" if repeat_count != 1 else ""]


func get_category() -> String:
	return "Timing"


func execute(_controller: Node, _delta: float) -> void:
	pass  # Handled specially by EventController._execute_actions()

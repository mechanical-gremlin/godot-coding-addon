@tool
class_name ESWaitAction
extends ESAction
## Action that pauses the remaining actions in the current event for a given
## duration before continuing.  This mirrors GDScript's
## `await get_tree().create_timer(seconds).timeout` pattern.
##
## When the EventController encounters a Wait action it schedules the
## remaining actions in the same event to execute after the specified delay.
## Other events continue to evaluate normally during the wait.

## How long to wait (in seconds) before executing the remaining actions.
@export var wait_time: float = 1.0


func get_summary() -> String:
	return "Wait %.2f seconds" % wait_time


func get_category() -> String:
	return "Timing"


## The actual delay is handled by the EventController.  This method is a
## no-op – the controller checks for ESWaitAction *before* calling execute().
func execute(_controller: Node, _delta: float) -> void:
	pass

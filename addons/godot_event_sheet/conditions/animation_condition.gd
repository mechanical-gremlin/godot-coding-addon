@tool
class_name ESAnimationCondition
extends ESCondition
## Condition that fires when an animation finishes playing.
## Works with AnimationPlayer and AnimatedSprite2D nodes.
## The EventController automatically connects the finished signal at runtime.

## Path to the AnimationPlayer or AnimatedSprite2D node.
## Leave empty to search the EventController's parent for an AnimationPlayer child.
@export var player_path: NodePath = NodePath("")

## Optional: only trigger when this specific animation finishes.
## Leave empty to trigger for any animation that finishes.
@export var animation_name: String = ""

## Internal flag set by the runtime when a matching animation finishes.
var _triggered: bool = false

## The name of the animation that just finished (available during action execution).
var finished_animation: String = ""


func get_summary() -> String:
	if not animation_name.is_empty():
		return "Animation \"%s\" finished" % animation_name
	return "Any animation finished"


func get_category() -> String:
	return "Animation"


func evaluate(controller: Node, _delta: float) -> bool:
	if _triggered:
		_triggered = false
		return true
	return false


## Called by the EventController when animation_finished fires on AnimationPlayer.
func _on_animation_finished(anim_name: StringName) -> void:
	if animation_name.is_empty() or anim_name == animation_name:
		finished_animation = anim_name
		_triggered = true


## Called by the EventController when animation_finished fires on AnimatedSprite2D.
func _on_sprite_animation_finished() -> void:
	_triggered = true
	finished_animation = ""

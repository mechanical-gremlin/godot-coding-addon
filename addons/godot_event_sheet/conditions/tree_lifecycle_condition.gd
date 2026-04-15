@tool
class_name ESTreeLifecycleCondition
extends ESCondition
## Condition that fires when a node enters or exits the scene tree, or when a
## child node is added or removed. Useful for setup on spawn, cleanup on
## destroy, or managing dynamic children (inventory, UI elements, etc.).
## The EventController connects the appropriate signals at runtime.

enum TreeEvent {
	ENTER_TREE,             ## Fires once when the node is added to the scene tree
	EXIT_TREE,              ## Fires once when the node is removed from the scene tree
	CHILD_ENTERED_TREE,     ## Fires when a child node is added
	CHILD_EXITING_TREE,     ## Fires when a child node is about to be removed
}

## Which tree lifecycle event to detect.
@export var tree_event: TreeEvent = TreeEvent.ENTER_TREE

## Path to the node to monitor.
## Leave empty to use the EventController's parent node.
@export var target_path: NodePath = NodePath("")

## Internal flag set by the runtime when the event fires.
var _triggered: bool = false

## The child node involved (for CHILD_ENTERED_TREE / CHILD_EXITING_TREE).
var affected_child: Node = null


func get_summary() -> String:
	var type_names := [
		"added to scene", "removed from scene",
		"child added", "child removed"
	]
	var desc := "Tree: %s" % type_names[tree_event]
	if not target_path.is_empty():
		desc += " on %s" % str(target_path)
	return desc


func get_category() -> String:
	return "Lifecycle"


func evaluate(controller: Node, _delta: float) -> bool:
	if _triggered:
		_triggered = false
		return true
	return false


## Called when the node enters the tree.
func _on_tree_entered() -> void:
	_triggered = true
	affected_child = null


## Called when the node is about to exit the tree.
func _on_tree_exiting() -> void:
	_triggered = true
	affected_child = null


## Called when a child enters the tree.
func _on_child_entered_tree(child: Node) -> void:
	affected_child = child
	_triggered = true


## Called when a child is about to exit the tree.
func _on_child_exiting_tree(child: Node) -> void:
	affected_child = child
	_triggered = true

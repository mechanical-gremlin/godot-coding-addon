@tool
class_name ESEventController
extends Node
## Runtime controller that evaluates an EventSheet's conditions and executes actions.
##
## Add this node as a child of any game object (e.g., CharacterBody2D, Area2D, Sprite2D).
## Assign an EventSheet resource, and the controller will automatically:
## - Register custom signals
## - Connect collision signals
## - Connect signal listeners
## - Create timers
## - Evaluate conditions every frame and execute matching actions
##
## This is the main node students interact with to add visual logic to their game objects.

# Preloaded condition scripts for type checking.
const ESInputCondition := preload("res://addons/godot_event_sheet/conditions/input_condition.gd")
const ESCollisionCondition := preload("res://addons/godot_event_sheet/conditions/collision_condition.gd")
const ESButtonCondition := preload("res://addons/godot_event_sheet/conditions/button_condition.gd")
const ESSignalCondition := preload("res://addons/godot_event_sheet/conditions/signal_condition.gd")
const ESTimerCondition := preload("res://addons/godot_event_sheet/conditions/timer_condition.gd")
const ESLifecycleCondition := preload("res://addons/godot_event_sheet/conditions/lifecycle_condition.gd")
const ESPhysicsCondition := preload("res://addons/godot_event_sheet/conditions/physics_condition.gd")
const ESJoypadCondition := preload("res://addons/godot_event_sheet/conditions/joypad_condition.gd")
const ESMouseHoverCondition := preload("res://addons/godot_event_sheet/conditions/mouse_hover_condition.gd")
const ESAnimationCondition := preload("res://addons/godot_event_sheet/conditions/animation_condition.gd")
const ESVisibilityCondition := preload("res://addons/godot_event_sheet/conditions/visibility_condition.gd")
const ESTreeLifecycleCondition := preload("res://addons/godot_event_sheet/conditions/tree_lifecycle_condition.gd")
const ESClickCondition := preload("res://addons/godot_event_sheet/conditions/click_condition.gd")
const ESWaitAction := preload("res://addons/godot_event_sheet/actions/wait_action.gd")
const ESRepeatAction := preload("res://addons/godot_event_sheet/actions/repeat_action.gd")

## The EventSheet resource containing all events.
@export var event_sheet: ESEventSheet = null

## If true, print debug messages when events fire.
@export var debug_mode: bool = false

# Internal tracking.
var _process_events: Array = []
var _physics_events: Array = []
var _ready_events: Array = []
var _signal_events: Array = []  # Events triggered by signals/collisions/timers
var _initialized: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not event_sheet:
		if debug_mode:
			push_warning("EventSheet: No valid EventSheet assigned to %s" % name)
		return

	event_sheet = event_sheet.duplicate(true)

	_setup_custom_signals()
	_categorize_events()
	_setup_connections()

	# Fire ready events.
	for cond in _get_all_conditions():
		if cond is ESLifecycleCondition:
			cond._on_ready()

	_initialized = true

	# Evaluate ready events immediately.
	_evaluate_events(_ready_events, 0.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _initialized:
		return
	_evaluate_events(_process_events, delta)
	# Also check signal/collision/timer events during process.
	_evaluate_events(_signal_events, delta)
	_track_key_states()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _initialized:
		return
	_evaluate_events(_physics_events, delta)
	_track_key_states()


## Register custom signals defined in the event sheet.
func _setup_custom_signals() -> void:
	var sheet := event_sheet as ESEventSheet
	for sig_name in sheet.custom_signals:
		if not has_user_signal(sig_name):
			add_user_signal(sig_name)
			if debug_mode:
				print("EventSheet: Registered custom signal '%s'" % sig_name)


## Sort events into categories based on their conditions.
## Expected structure (lifecycle-first): each top-level event is a lifecycle block
## (_ready / _process / _physics_process) containing sub-events with the real logic.
## Legacy flat events (non-block, no lifecycle condition) still work and are treated
## as process-category events for backward compatibility.
func _categorize_events() -> void:
	var sheet := event_sheet as ESEventSheet
	if not sheet.enabled:
		return

	for event_res in sheet.events:
		var event := event_res as ESEventItem
		if not event or not event.enabled:
			continue

		var category := _determine_event_category(event)
		match category:
			"ready":
				_ready_events.append(event)
			"physics":
				_physics_events.append(event)
			"signal":
				_signal_events.append(event)
			_:
				_process_events.append(event)


## Determine which update loop an event belongs in.
func _determine_event_category(event: ESEventItem) -> String:
	var has_physics_cond: bool = false
	for cond_res in event.conditions:
		var cond := cond_res as ESCondition
		if not cond:
			continue
		if cond is ESLifecycleCondition:
			match cond.lifecycle_type:
				ESLifecycleCondition.LifecycleType.READY:
					return "ready"
				ESLifecycleCondition.LifecycleType.PHYSICS_PROCESS:
					return "physics"
		# Signal, collision, timer, button, hover, animation, visibility, tree,
		# and click conditions are all event-driven and evaluated in _process.
		if cond is ESSignalCondition or cond is ESCollisionCondition \
				or cond is ESTimerCondition or cond is ESButtonCondition \
				or cond is ESMouseHoverCondition or cond is ESAnimationCondition \
				or cond is ESVisibilityCondition or cond is ESTreeLifecycleCondition \
				or cond is ESClickCondition:
			return "signal"
		# If the event contains a physics condition but no lifecycle condition,
		# it should run in _physics_process so is_on_floor() is always fresh.
		if cond is ESPhysicsCondition:
			has_physics_cond = true
	if has_physics_cond:
		return "physics"
	return "process"


## Set up all signal connections, collision listeners, and timers.
func _setup_connections() -> void:
	var sheet := event_sheet as ESEventSheet

	for event_res in sheet.events:
		var event := event_res as ESEventItem
		if not event or not event.enabled:
			continue
		_setup_event_connections(event)


## Recursively set up connections for an event and its sub-events.
func _setup_event_connections(event: ESEventItem) -> void:
	for cond_res in event.conditions:
		var cond := cond_res as ESCondition
		if not cond:
			continue

		if cond is ESCollisionCondition:
			_connect_collision(cond)
		elif cond is ESSignalCondition:
			_connect_signal_condition(cond)
		elif cond is ESTimerCondition:
			_setup_timer(cond)
		elif cond is ESButtonCondition:
			_connect_button(cond)
		elif cond is ESMouseHoverCondition:
			_connect_mouse_hover(cond)
		elif cond is ESAnimationCondition:
			_connect_animation(cond)
		elif cond is ESVisibilityCondition:
			_connect_visibility(cond)
		elif cond is ESTreeLifecycleCondition:
			_connect_tree_lifecycle(cond)
		elif cond is ESClickCondition:
			_connect_click(cond)

	# Recurse into sub-events.
	for sub_res in event.sub_events:
		var sub := sub_res as ESEventItem
		if sub and sub.enabled:
			_setup_event_connections(sub)


## Connect collision signals from the detector node (or all nodes in a detector group).
func _connect_collision(cond: ESCollisionCondition) -> void:
	# Build the list of detector nodes to connect.
	var detectors: Array[Node] = []
	if not cond.detector_group.is_empty():
		detectors = get_tree().get_nodes_in_group(cond.detector_group)
		if detectors.is_empty():
			push_warning("EventSheet: No nodes found in detector group '%s'." % cond.detector_group)
			return
	else:
		var detector: Node
		if cond.detector_path.is_empty():
			detector = get_parent()
		else:
			detector = get_node_or_null(cond.detector_path)
		if not detector:
			push_warning("EventSheet: Collision detector node not found.")
			return
		detectors = [detector]

	for detector in detectors:
		_connect_collision_to_node(cond, detector)


## Connect a single detector node to a collision condition.
func _connect_collision_to_node(cond: ESCollisionCondition, detector: Node) -> void:
	# IS_OVERLAPPING connects both entered and exited to track overlapping nodes.
	if cond.collision_type == ESCollisionCondition.CollisionType.IS_OVERLAPPING:
		for sig_name in ["body_entered", "body_exited"]:
			if detector.has_signal(sig_name):
				var callback: Callable
				if sig_name == "body_entered":
					callback = cond._on_overlap_entered
				else:
					callback = cond._on_overlap_exited
				if not detector.is_connected(sig_name, callback):
					detector.connect(sig_name, callback)
					if debug_mode:
						print("EventSheet: Connected '%s' on %s (IS_OVERLAPPING)" % [sig_name, detector.name])
		return

	var signal_name: String
	match cond.collision_type:
		ESCollisionCondition.CollisionType.BODY_ENTERED:
			signal_name = "body_entered"
		ESCollisionCondition.CollisionType.BODY_EXITED:
			signal_name = "body_exited"
		ESCollisionCondition.CollisionType.AREA_ENTERED:
			signal_name = "area_entered"
		ESCollisionCondition.CollisionType.AREA_EXITED:
			signal_name = "area_exited"

	if detector.has_signal(signal_name):
		if not detector.is_connected(signal_name, cond._on_collision):
			detector.connect(signal_name, cond._on_collision)
			if debug_mode:
				print("EventSheet: Connected '%s' on %s" % [signal_name, detector.name])
	else:
		push_warning("EventSheet: Node '%s' does not have signal '%s'. Make sure it's an Area2D, Area3D, or similar." % [detector.name, signal_name])


## Connect a signal condition to the source node.
func _connect_signal_condition(cond: ESSignalCondition) -> void:
	var source: Node
	if cond.source_path.is_empty():
		source = get_parent()
	else:
		source = get_node_or_null(cond.source_path)

	if not source:
		push_warning("EventSheet: Signal source node not found for '%s'." % cond.signal_name)
		return

	if cond.signal_name.is_empty():
		push_warning("EventSheet: Signal condition has no signal name.")
		return

	# Add user signal if it doesn't exist.
	if not source.has_signal(cond.signal_name):
		source.add_user_signal(cond.signal_name)

	if not source.is_connected(cond.signal_name, cond._on_signal_received):
		source.connect(cond.signal_name, cond._on_signal_received)
		if debug_mode:
			print("EventSheet: Listening for signal '%s' on %s" % [cond.signal_name, source.name])


## Create a Timer for a timer condition.
func _setup_timer(cond: ESTimerCondition) -> void:
	var timer := Timer.new()
	timer.wait_time = cond.wait_time
	timer.one_shot = cond.one_shot
	timer.autostart = true
	timer.timeout.connect(cond._on_timer_timeout)
	add_child(timer)
	cond._timer = timer
	if debug_mode:
		print("EventSheet: Created timer (%.1fs, one_shot=%s)" % [cond.wait_time, cond.one_shot])


## Connect a Button node's "pressed" signal to the button condition.
func _connect_button(cond: ESButtonCondition) -> void:
	if cond.button_path.is_empty():
		push_warning("EventSheet: Button condition has no button path specified.")
		return
	var button := get_node_or_null(cond.button_path)
	if not button:
		push_warning("EventSheet: Button not found at path: %s" % cond.button_path)
		return
	if not button.has_signal("pressed"):
		push_warning("EventSheet: Node at '%s' does not have a 'pressed' signal." % cond.button_path)
		return
	if not button.is_connected("pressed", cond._on_button_pressed):
		button.connect("pressed", cond._on_button_pressed)
		if debug_mode:
			print("EventSheet: Connected button 'pressed' on %s" % button.name)


## Evaluate a list of events and execute actions for those whose conditions pass.
func _evaluate_events(events: Array, delta: float) -> void:
	for event_res in events:
		var event := event_res as ESEventItem
		if not event or not event.enabled:
			continue

		var conditions_pass := false
		if event.conditions.size() == 0:
			# No conditions means unconditionally execute.  This allows sub-events
			# within blocks that have <none> as their condition to run whenever
			# the parent block fires.
			conditions_pass = true
		elif event.logic_mode == ESEventItem.LogicMode.OR:
			# OR logic: at least one condition must be true.
			for cond_res in event.conditions:
				var cond := cond_res as ESCondition
				if not cond:
					continue
				var result := cond.evaluate(self, delta)
				if cond.negated:
					result = not result
				if result:
					conditions_pass = true
					break
		else:
			# AND logic (default): all conditions must be true.
			conditions_pass = true
			for cond_res in event.conditions:
				var cond := cond_res as ESCondition
				if not cond:
					continue
				var result := cond.evaluate(self, delta)
				if cond.negated:
					result = not result
				if not result:
					conditions_pass = false
					break

		if conditions_pass:
			# Store the colliding node (if any) so actions can reference it via "$collider".
			for cond_res in event.conditions:
				if cond_res is ESCollisionCondition:
					var coll_cond := cond_res as ESCollisionCondition
					if coll_cond.colliding_node:
						set_meta(&"_es_last_collided_node", coll_cond.colliding_node)
					break
			if debug_mode:
				print("EventSheet: Event '%s' triggered!" % event.event_name)
			_execute_actions(event, delta)
			# If this is a block event, evaluate sub-events now (they inherit this loop's context).
			if event.is_block and event.sub_events.size() > 0:
				_evaluate_events(event.sub_events, delta)


## Execute all actions in an event.
## [param start_index] allows resuming from a specific action (used after a Wait).
func _execute_actions(event: ESEventItem, delta: float, start_index: int = 0) -> void:
	for i in range(start_index, event.actions.size()):
		var action := event.actions[i] as ESAction
		if not action:
			continue
		if action is ESWaitAction:
			var wait_act := action as ESWaitAction
			# Schedule the remaining actions to run after the delay.
			# Delta is passed as 0.0 because the original frame delta is stale
			# by the time the timer fires.
			get_tree().create_timer(wait_act.wait_time).timeout.connect(
				func():
					if is_instance_valid(self):
						_execute_actions(event, 0.0, i + 1)
			)
			return
		if action is ESRepeatAction:
			var repeat_act := action as ESRepeatAction
			# Execute the remaining actions repeat_count times synchronously.
			for _r in range(repeat_act.repeat_count):
				_execute_actions_range(event, delta, i + 1, event.actions.size())
			return
		action.execute(self, delta)


## Execute a range of actions (helper for ESRepeatAction).
func _execute_actions_range(event: ESEventItem, delta: float, from_idx: int, to_idx: int) -> void:
	for i in range(from_idx, to_idx):
		var action := event.actions[i] as ESAction
		if not action:
			continue
		# Skip nested Wait/Repeat actions to avoid unintended nested repetition behavior.
		if action is ESWaitAction or action is ESRepeatAction:
			continue
		action.execute(self, delta)


## Track key states for JUST_PRESSED/JUST_RELEASED detection with raw keys.
func _track_key_states() -> void:
	# This is called at the end of _process to update "previous frame" states
	# for conditions that track key transitions.
	var sheet := event_sheet as ESEventSheet
	if not sheet:
		return
	# Track mouse button states for ESMouseCondition JUST_PRESSED/JUST_RELEASED detection.
	set_meta("_es_prev_mouse_left", Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	set_meta("_es_prev_mouse_right", Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	set_meta("_es_prev_mouse_middle", Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE))
	# Track "any key" state for ANY_JUST_PRESSED/ANY_JUST_RELEASED conditions.
	set_meta("_es_any_key_prev", Input.is_anything_pressed())
	for event_res in sheet.events:
		var event := event_res as ESEventItem
		if not event:
			continue
		_track_event_key_states(event)


## Recursively track key states for an event and its sub-events.
func _track_event_key_states(event: ESEventItem) -> void:
	for cond_res in event.conditions:
		if cond_res is ESInputCondition:
			var cond := cond_res as ESInputCondition
			if not cond.action_or_key.is_empty() and not InputMap.has_action(cond.action_or_key):
				var keycode := OS.find_keycode_from_string(cond.action_or_key)
				if keycode != KEY_NONE:
					set_meta("_es_prev_key_%d" % keycode, Input.is_key_pressed(keycode))
		elif cond_res is ESJoypadCondition:
			var cond := cond_res as ESJoypadCondition
			if cond.check_type in [ESJoypadCondition.JoypadCheck.BUTTON_PRESSED,
					ESJoypadCondition.JoypadCheck.BUTTON_RELEASED]:
				var meta_key := "_es_prev_joy_%d_%d" % [cond.device_id, cond.joypad_button]
				set_meta(meta_key, Input.is_joy_button_pressed(cond.device_id, cond.joypad_button))
	# Recurse into sub-events.
	for sub_res in event.sub_events:
		var sub := sub_res as ESEventItem
		if sub:
			_track_event_key_states(sub)


## Get all conditions from all events (utility).
func _get_all_conditions() -> Array:
	var result: Array = []
	var sheet := event_sheet as ESEventSheet
	for event_res in sheet.events:
		var event := event_res as ESEventItem
		if event:
			_collect_conditions(event, result)
	return result


## Recursively collect conditions from an event and all its sub-events.
func _collect_conditions(event: ESEventItem, result: Array) -> void:
	for cond in event.conditions:
		result.append(cond)
	for sub_res in event.sub_events:
		var sub := sub_res as ESEventItem
		if sub:
			_collect_conditions(sub, result)


## Connect mouse_entered / mouse_exited signals for a hover condition.
func _connect_mouse_hover(cond) -> void:
	var target: Node
	if cond.target_path.is_empty():
		target = get_parent()
	else:
		target = get_node_or_null(cond.target_path)

	if not target:
		push_warning("EventSheet: Mouse hover target node not found.")
		return

	if target.has_signal("mouse_entered") and not target.is_connected("mouse_entered", cond._on_mouse_entered):
		target.connect("mouse_entered", cond._on_mouse_entered)
	if target.has_signal("mouse_exited") and not target.is_connected("mouse_exited", cond._on_mouse_exited):
		target.connect("mouse_exited", cond._on_mouse_exited)
	if debug_mode:
		print("EventSheet: Connected mouse hover signals on %s" % target.name)


## Connect animation_finished signal for an animation condition.
func _connect_animation(cond) -> void:
	var target: Node = null
	if not cond.player_path.is_empty():
		target = get_node_or_null(cond.player_path)
	else:
		# Auto-find an AnimationPlayer or AnimatedSprite2D child of the parent.
		var parent := get_parent()
		if parent:
			for child in parent.get_children():
				if child is AnimationPlayer or child is AnimatedSprite2D:
					target = child
					break
			# Also check if the parent itself is an AnimatedSprite2D.
			if not target and parent is AnimatedSprite2D:
				target = parent

	if not target:
		push_warning("EventSheet: Animation player node not found for animation condition.")
		return

	if target is AnimationPlayer:
		if not target.is_connected("animation_finished", cond._on_animation_finished):
			target.connect("animation_finished", cond._on_animation_finished)
	elif target is AnimatedSprite2D:
		if not target.is_connected("animation_finished", cond._on_sprite_animation_finished):
			target.connect("animation_finished", cond._on_sprite_animation_finished)

	if debug_mode:
		print("EventSheet: Connected animation_finished on %s" % target.name)


## Connect screen_entered / screen_exited signals for a visibility condition.
func _connect_visibility(cond) -> void:
	var target: Node = null
	if not cond.notifier_path.is_empty():
		target = get_node_or_null(cond.notifier_path)
	else:
		# Auto-find a VisibleOnScreenNotifier2D/3D child of the parent.
		var parent := get_parent()
		if parent:
			for child in parent.get_children():
				if child is VisibleOnScreenNotifier2D or child is VisibleOnScreenNotifier3D:
					target = child
					break

	if not target:
		push_warning("EventSheet: VisibleOnScreenNotifier node not found for visibility condition.")
		return

	if target.has_signal("screen_entered") and not target.is_connected("screen_entered", cond._on_screen_entered):
		target.connect("screen_entered", cond._on_screen_entered)
	if target.has_signal("screen_exited") and not target.is_connected("screen_exited", cond._on_screen_exited):
		target.connect("screen_exited", cond._on_screen_exited)

	if debug_mode:
		print("EventSheet: Connected visibility signals on %s" % target.name)


## Connect tree_entered / tree_exiting / child_entered_tree / child_exiting_tree signals.
func _connect_tree_lifecycle(cond) -> void:
	var target: Node
	if cond.target_path.is_empty():
		target = get_parent()
	else:
		target = get_node_or_null(cond.target_path)

	if not target:
		push_warning("EventSheet: Tree lifecycle target node not found.")
		return

	match cond.tree_event:
		ESTreeLifecycleCondition.TreeEvent.ENTER_TREE:
			if not target.is_connected("tree_entered", cond._on_tree_entered):
				target.connect("tree_entered", cond._on_tree_entered)
		ESTreeLifecycleCondition.TreeEvent.EXIT_TREE:
			if not target.is_connected("tree_exiting", cond._on_tree_exiting):
				target.connect("tree_exiting", cond._on_tree_exiting)
		ESTreeLifecycleCondition.TreeEvent.CHILD_ENTERED_TREE:
			if not target.is_connected("child_entered_tree", cond._on_child_entered_tree):
				target.connect("child_entered_tree", cond._on_child_entered_tree)
		ESTreeLifecycleCondition.TreeEvent.CHILD_EXITING_TREE:
			if not target.is_connected("child_exiting_tree", cond._on_child_exiting_tree):
				target.connect("child_exiting_tree", cond._on_child_exiting_tree)

	if debug_mode:
		print("EventSheet: Connected tree lifecycle signal on %s" % target.name)


## Connect input_event signal on a CollisionObject2D/3D for click detection.
func _connect_click(cond) -> void:
	var target: Node
	if cond.target_path.is_empty():
		target = get_parent()
	else:
		target = get_node_or_null(cond.target_path)

	if not target:
		push_warning("EventSheet: Click target node not found.")
		return

	if target is CollisionObject2D:
		if not target.is_connected("input_event", cond._on_input_event_2d):
			target.connect("input_event", cond._on_input_event_2d)
			# Ensure the node picks up input events.
			target.input_pickable = true
	elif target is CollisionObject3D:
		if not target.is_connected("input_event", cond._on_input_event_3d):
			target.connect("input_event", cond._on_input_event_3d)
			target.input_ray_pickable = true
	else:
		push_warning("EventSheet: Click target '%s' is not a CollisionObject2D/3D." % target.name)
		return

	if debug_mode:
		print("EventSheet: Connected click input_event on %s" % target.name)

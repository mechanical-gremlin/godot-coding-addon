@tool
class_name ESJoypadCondition
extends ESCondition
## Condition that checks for gamepad/joypad input (analog sticks and buttons).
## Supports detecting stick direction (with deadzone threshold), button presses,
## and whether a controller is connected.

enum JoypadCheck {
	AXIS_ACTIVE,      ## Joypad axis value exceeds the deadzone threshold
	BUTTON_PRESSED,   ## Joypad button was just pressed this frame
	BUTTON_RELEASED,  ## Joypad button was just released this frame
	BUTTON_HELD,      ## Joypad button is currently held down
	ANY_CONNECTED,    ## At least one joypad is connected
}

enum JoypadAxis {
	LEFT_X,         ## Left stick horizontal axis
	LEFT_Y,         ## Left stick vertical axis
	RIGHT_X,        ## Right stick horizontal axis
	RIGHT_Y,        ## Right stick vertical axis
	TRIGGER_LEFT,   ## Left trigger
	TRIGGER_RIGHT,  ## Right trigger
}

## What type of joypad check to perform.
@export var check_type: JoypadCheck = JoypadCheck.AXIS_ACTIVE

## Which axis to check (used with AXIS_ACTIVE).
@export var axis: JoypadAxis = JoypadAxis.LEFT_X

## How far the stick must be pushed to trigger (0.0–1.0).
@export var axis_threshold: float = 0.5

## If true, check the positive direction (right/down). If false, check negative (left/up).
@export var positive_direction: bool = true

## Which joypad button to check (used with BUTTON_PRESSED/RELEASED/HELD).
## 0 = A/Cross, 1 = B/Circle, 2 = X/Square, 3 = Y/Triangle, etc.
@export var joypad_button: int = 0

## Which controller device to check (0 = first connected controller).
@export var device_id: int = 0


func get_summary() -> String:
	var axis_names := ["Left Stick X", "Left Stick Y", "Right Stick X",
		"Right Stick Y", "Left Trigger", "Right Trigger"]
	match check_type:
		JoypadCheck.AXIS_ACTIVE:
			var dir := "+" if positive_direction else "-"
			return "Joypad %s %s > %.1f" % [axis_names[axis], dir, axis_threshold]
		JoypadCheck.BUTTON_PRESSED:
			return "Joypad button %d pressed" % joypad_button
		JoypadCheck.BUTTON_RELEASED:
			return "Joypad button %d released" % joypad_button
		JoypadCheck.BUTTON_HELD:
			return "Joypad button %d held" % joypad_button
		JoypadCheck.ANY_CONNECTED:
			return "Joypad connected"
	return "Joypad check"


func get_category() -> String:
	return "Input"


func evaluate(controller: Node, _delta: float) -> bool:
	match check_type:
		JoypadCheck.AXIS_ACTIVE:
			var godot_axis: JoyAxis
			match axis:
				JoypadAxis.LEFT_X:
					godot_axis = JOY_AXIS_LEFT_X
				JoypadAxis.LEFT_Y:
					godot_axis = JOY_AXIS_LEFT_Y
				JoypadAxis.RIGHT_X:
					godot_axis = JOY_AXIS_RIGHT_X
				JoypadAxis.RIGHT_Y:
					godot_axis = JOY_AXIS_RIGHT_Y
				JoypadAxis.TRIGGER_LEFT:
					godot_axis = JOY_AXIS_TRIGGER_LEFT
				JoypadAxis.TRIGGER_RIGHT:
					godot_axis = JOY_AXIS_TRIGGER_RIGHT
			var value := Input.get_joy_axis(device_id, godot_axis)
			if positive_direction:
				return value > axis_threshold
			else:
				return value < -axis_threshold

		JoypadCheck.BUTTON_PRESSED:
			var pressed_now := Input.is_joy_button_pressed(device_id, joypad_button)
			var meta_key := "_es_prev_joy_%d_%d" % [device_id, joypad_button]
			var was_pressed: bool = controller.get_meta(meta_key, false)
			return pressed_now and not was_pressed

		JoypadCheck.BUTTON_RELEASED:
			var pressed_now := Input.is_joy_button_pressed(device_id, joypad_button)
			var meta_key := "_es_prev_joy_%d_%d" % [device_id, joypad_button]
			var was_pressed: bool = controller.get_meta(meta_key, false)
			return not pressed_now and was_pressed

		JoypadCheck.BUTTON_HELD:
			return Input.is_joy_button_pressed(device_id, joypad_button)

		JoypadCheck.ANY_CONNECTED:
			return Input.get_connected_joypads().size() > 0

	return false

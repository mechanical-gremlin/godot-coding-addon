# Godot Event Sheet — Visual Programming Addon for Godot 4.5

A visual **Event Sheet** programming addon for Godot 4.5, designed for beginning programmers and game design students. Instead of writing traditional GDScript code, students create game logic by combining **Conditions** (when something happens) with **Actions** (what to do), similar to Construct 3 or GDevelop.

## Features

- **Event Sheet Editor** — A bottom panel in the Godot editor for visually building game logic
- **No Code Required** — Students define behavior with conditions and actions, not GDScript
- **Full Signal Support** — Create, emit, and listen for custom signals between nodes
- **Collision Detection** — Detect body and area collisions with group filtering; persistent overlap tracking
- **Input Handling** — Respond to keyboard input, action presses, and held keys; UI button clicks
- **Property Control** — Read, set, add, subtract, multiply, divide, or toggle any node property; dynamic text with live value placeholders; clamp to min/max range
- **Variable System (Counters & Flags)** — Local and global variables with set, add, subtract, multiply, divide, toggle, and array operations; persists across scene changes when global
- **Math Functions** — Apply abs, floor, ceil, round, sqrt, sin, cos, or lerp to any numeric property
- **Repeat N Times** — Repeat a block of subsequent actions a specified number of times
- **Movement** — Translate, set position, move toward targets or dynamic nodes, physics velocity (2D and 3D)
- **Knockback** — Compute directional knockback between two nodes and push via velocity or position
- **Timers** — Repeating and one-shot timers without writing code
- **Animation & Audio** — Play/stop animations and sounds
- **Scene Management** — Instantiate scenes (with optional Marker2D spawn point), destroy nodes, change scenes, show/hide nodes
- **Game State Management** — Set, check, and clear named states on any node for turn-based games, boss phases, power-up tracking, and game flow control
- **Node Counting** — Check how many nodes belong to a group for level-complete, wave-clear, and game-over detection
- **Debug Printing** — Print messages with variable placeholders for easy debugging
- **Collider Reference** — Use `$collider` in any target field to reference the node from the last collision

## Quick Start

### 1. Install the Addon

Copy the `addons/godot_event_sheet/` folder into your Godot project's `addons/` directory.

### 2. Enable the Plugin

Go to **Project → Project Settings → Plugins** and enable **Godot Event Sheet**.

### 3. Set Up Your Scene

```
CharacterBody2D (your game object)
  ├── Sprite2D
  ├── CollisionShape2D
  └── EventController  ← Add this node
```

1. Add an **EventController** node as a child of your game object
2. Click on the EventController — the **Event Sheet** panel opens at the bottom and is immediately ready to use (an EventSheet resource is auto-created for you)

### 4. Create Events

Click **+ Add Event** to open the event wizard. Each event uses a simple **"When → Then"** model:

1. Pick a **trigger** (WHEN this happens) from the left list
2. Configure its settings (e.g., which key to listen for)
3. Pick a **reaction** (THEN do this) from the right list
4. Configure its settings (e.g., which direction to move)
5. Click **Create Event** — done!

| Conditions (ALL must be true) | Actions (executed in order) |
|-------------------------------|---------------------------|
| Every Frame + Right key held | Move parent right at speed 200 |
| Every Frame + Left key held | Move parent left at speed 200 |
| Collision: body entered (group "coins") | Print "Coin collected!" + Emit "coin_collected" signal |
| Signal "coin_collected" received | Add 1 to score property |

## Available Conditions

| Category | Condition | Description |
|----------|-----------|-------------|
| **Input** | Key/Action Pressed | Triggers once when a key or input action is first pressed |
| **Input** | Key/Action Released | Triggers once when a key or input action is released |
| **Input** | Key/Action Held | True every frame while a key or input action is held down |
| **Collision** | Body Entered | A physics body entered the detector area (with optional group filter) |
| **Collision** | Body Exited | A physics body exited the detector area |
| **Collision** | Area Entered | Another area entered the detector area |
| **Collision** | Area Exited | Another area exited the detector area |
| **Collision** | Is Overlapping | True every frame while any matching body is inside the area (ideal for floor switches) |
| **UI** | Button Pressed | Fires once when a UI Button node is clicked |
| **Signals** | Signal Received | Listens for any signal on a target node |
| **Properties** | Compare Value | Compares a node property against a value (==, !=, >, <, >=, <=) |
| **Timing** | Repeating Timer | Triggers periodically at a set interval |
| **Timing** | One-Shot Delay | Triggers once after a set delay |
| **Lifecycle** | On Ready | Triggers once when the scene loads |
| **Lifecycle** | Every Frame | Triggers every frame (like `_process`) |
| **Lifecycle** | Every Physics Frame | Triggers every physics frame (like `_physics_process`) |
| **Game State (Phases)** | Check State | Checks if a named state on a node equals (or doesn't equal) a given value — for turn-based games, boss phases, game flow |
| **Utility** | Node Count in Group | Checks the count of nodes in a group (==, !=, >, <, >=, <=) — for level-complete, wave-clear, game-over detection |
| **Counters & Flags** | Compare Variable | Checks a local or global variable against a value |
| **Counters & Flags** | Variable Contains | Checks if an array variable contains a value |
| **Physics** | Is On Floor / Wall / Ceiling | Checks CharacterBody2D/3D physics state |
| **Hover & Click** | Mouse Entered/Exited/Hovered | Fires when the mouse enters, exits, or is over a node |
| **Hover & Click** | Object Clicked/Released | Fires when a CollisionObject2D/3D is clicked |
| **Animation** | Animation Finished | Fires when an AnimationPlayer or AnimatedSprite2D finishes playing |
| **Visibility** | Appeared/Left/Is On Screen | Fires when a node enters or leaves the viewport |
| **Scene Tree** | Added/Removed/Child Added/Removed | Fires on scene tree events for a node |

## Available Actions

| Category | Action | Description |
|----------|--------|-------------|
| **Movement** | Translate | Move a node by an offset at a given speed; includes direction presets (Up/Down/Left/Right) |
| **Movement** | Set Position | Set a node's absolute position |
| **Movement** | Move Toward Point | Move a node toward a fixed (x, y) coordinate |
| **Movement** | Move Toward Node | Move a node toward another node's live position (for chasing enemies) |
| **Movement** | Set Velocity (Physics) | Set `CharacterBody2D.velocity` and call `move_and_slide()` for wall-colliding movement |
| **Movement** | Apply Knockback | Push a target node away from a source node (supports `$collider` as target) |
| **Movement** | Rotate / Aim | Rotate a node by a given angle, aim at a point/node, or track input direction |
| **Movement** | Pathfind (A\*) | Move a node toward a target along a NavigationAgent2D/3D path |
| **Properties** | Set Value | Set a property to a value; supports `{../Node:prop}` placeholders for live HUD text |
| **Properties** | Add / Subtract / Multiply / Divide | Modify a numeric property (divide safely guards against division by zero) |
| **Properties** | Toggle | Toggle a boolean property |
| **Properties** | Clamp | Keep a property within a min/max range |
| **Counters & Flags** | Set / Add / Subtract / Multiply / Divide | Modify a named variable (local or global); divide safely guards against zero |
| **Counters & Flags** | Toggle | Flip a boolean variable |
| **Counters & Flags** | Append / Remove / Clear Array | Manage array variables |
| **Signals** | Emit Signal | Emit a signal (with optional arguments) on any node |
| **Animation** | Play / Stop / Pause / Play Backwards | Control AnimationPlayer or AnimatedSprite2D |
| **Scene** | Create Instance | Instantiate a scene; can spawn at a Marker2D's position and rotation |
| **Scene** | Destroy Node | Remove a node from the scene tree (supports `$collider`) |
| **Scene** | Change Scene | Transition to a completely different scene file |
| **Scene** | Show / Hide Node | Toggle a node's visibility |
| **Scene** | Pause / Unpause Tree | Freeze or resume the entire scene tree |
| **Audio** | Play / Stop Sound | Control AudioStreamPlayer nodes |
| **Camera** | Follow Target | Make a Camera2D/3D follow a node smoothly |
| **Camera** | Set Zoom | Zoom the camera in or out |
| **Camera** | Shake | Apply a screen-shake effect |
| **Game State (Phases)** | Set State | Assign a named state value to a node |
| **Game State (Phases)** | Clear State | Remove a named state from a node |
| **Timing** | Wait (Delay) | Pause action execution and resume after a delay |
| **Timing** | Repeat N Times | Execute the remaining actions in the event N times synchronously |
| **Math** | Apply Math Function | Apply abs, floor, ceil, round, sqrt, sin, cos, or lerp to a numeric property |
| **Utility** | Random Float / Int / Position | Set a property or variable to a random value within a range |
| **Utility** | Add / Remove from Group | Dynamically manage group membership at runtime |
| **Methods** | Call Method | Call any method on a node with up to 4 arguments |
| **Debug** | Print Message | Print to console (supports `{name}`, `{position}`, `{delta}` placeholders) |

## Referencing the Collided Node with `$collider`

After any collision condition fires, actions can use **`$collider`** as a target path to reference the node involved in the collision. This works in any action that accepts a target node path:

```
Event: "Weapon hits enemy"
  Condition: Collision - Area Entered (group: "enemies")
  Action: Apply Knockback — target: $collider, force: 300
  Action: Destroy Node — target: $collider
```

## Working with Signals

Signals are a vital part of Godot and are fully supported:

### Defining Custom Signals
In the EventSheet resource, add signal names to the **Custom Signals** array. These are automatically registered on the EventController at runtime.

### Emitting Signals
Use the **Emit Signal** action. You can:
- Emit on the EventController itself (leave target empty)
- Emit on any node in the scene (specify a node path)
- Pass up to 4 arguments with the signal

### Listening for Signals
Use the **Signal Received** condition. You can:
- Listen on the parent node (leave source empty)
- Listen on any node in the scene (specify a source path)
- Access signal arguments in subsequent actions

### Cross-Node Communication
Example: A coin emits `"coin_collected"`, and a score display listens for it:

```
# On the Coin's EventController:
Event: "Notify Collection"
  Condition: Collision - Area Entered (group: "player")
  Action: Emit Signal "coin_collected" on /root/Main/ScoreManager

# On the ScoreManager's EventController:
Event: "Update Score"
  Condition: Signal "coin_collected" received
  Action: Set Property "score" Add 1
  Action: Print "Score: {name}"
```

## Collision Detection

The addon connects to Godot's collision system automatically:

1. Your game object needs an **Area2D** or **Area3D** with a **CollisionShape2D/3D**
2. Add a **Collision** condition to your event
3. Optionally filter by **group** (e.g., only trigger for nodes in the "enemies" group)
4. The EventController automatically connects the correct signals at runtime

## Game State Management

The **State** action and condition let you manage game states without code. States are stored as named metadata on any node, so a single node can track multiple independent states.

### Setting a State
Use the **Set State** action. Specify:
- **Target Node** — The node to store the state on (leave empty for parent)
- **State Name** — A key name like `"state"`, `"phase"`, or `"mode"` (multiple states can coexist)
- **State Value** — The value to assign, e.g., `"player_turn"`, `"phase_2"`, `"game_over"`

### Checking a State
Use the **Check State** condition. It returns true when the node's current state matches (or doesn't match) the specified value.

### Example: Turn-Based Combat
```
# On the GameManager's EventController:
Event: "Start Player Turn"
  Condition: Lifecycle - On Ready
  Action: State - Set "turn" = "player" on ../GameManager

Event: "Player Attacks"
  Condition: State "turn" on ../GameManager == "player" + Input: Key Pressed "Space"
  Action: Property - Subtract 10 from ../Enemy:health
  Action: State - Set "turn" = "enemy" on ../GameManager

Event: "Enemy Attacks"
  Condition: State "turn" on ../GameManager == "enemy" + Timer: One-Shot 1s
  Action: Property - Subtract 5 from ../Player:health
  Action: State - Set "turn" = "player" on ../GameManager
```

### Example: Boss Phases
```
Event: "Enter Phase 2"
  Condition: Property ../Boss:health < 50
  Action: State - Set "phase" = "phase_2" on ../Boss

Event: "Phase 2 Attack Pattern"
  Condition: State "phase" on ../Boss == "phase_2" + Every Frame
  Action: Move Toward Node ../Player at speed 400
```

### Example: Level Complete (Node Count)
```
Event: "All Bricks Destroyed"
  Condition: Node Count in Group "bricks" == 0
  Action: Scene - Change Scene to res://scenes/win_screen.tscn
```

## UX Notes for Educators

### Properties vs. Variables (Counters & Flags) vs. Game State (Phases)

These three systems look similar but serve different purposes:

| System | Best For | How Values Are Stored | Persists Across Scenes? |
|--------|----------|----------------------|------------------------|
| **Properties** | Node attributes (position, health, speed, visible) | On the node itself (GDScript property) | Yes — as long as the node exists |
| **Counters & Flags** | Score, coins, flags ("has_sword"), counters | In EventController metadata; optionally global | Only when set to **Global** scope |
| **Game State (Phases)** | Game phase / mode ("phase_1", "game_over", "boss_fight") | As named metadata on any node | Yes — as long as the node exists |

**Teaching tip:** Use **Properties** when you want to change something the player can see or that Godot already tracks (like `position` or `health`). Use **Counters & Flags** for your own score and flag variables. Use **Game State** to control which "chapter" the game is in — e.g., a boss cycle, a turn-based phase, or a power-up state.

### Avoiding Common Mistakes

- ⚠️ **Don't mix "Every Frame" with signal-driven conditions in AND mode.** A signal fires once per event (e.g., when a collision happens), but "Every Frame" checks every frame. The editor will warn you when it detects this combination.
- ⚠️ **Fill in required fields.** Some conditions/actions need specific values (button path, signal name, wait time). The editor shows an ⚠️ badge when a required field is empty.
- ⚠️ **Detector Node vs. Group is mutually exclusive.** For collision conditions, pick either "Specific Node" or "All Nodes in Group" — the editor shows only one field at a time to avoid confusion.

## Project Structure

```
addons/godot_event_sheet/
├── plugin.cfg              # Plugin configuration
├── plugin.gd               # Editor plugin entry point
├── core/                   # Data model
│   ├── event_sheet.gd      # ESEventSheet - main container resource
│   ├── event_item.gd       # ESEventItem - single event (conditions + actions)
│   ├── event_condition.gd  # ESCondition - base condition class
│   └── event_action.gd     # ESAction - base action class
├── conditions/             # Condition implementations
│   ├── input_condition.gd
│   ├── collision_condition.gd
│   ├── button_condition.gd
│   ├── signal_condition.gd
│   ├── property_condition.gd
│   ├── timer_condition.gd
│   ├── lifecycle_condition.gd
│   ├── state_condition.gd
│   └── node_count_condition.gd
├── actions/                # Action implementations
│   ├── move_action.gd
│   ├── knockback_action.gd
│   ├── rotate_action.gd
│   ├── pathfinding_action.gd
│   ├── set_property_action.gd
│   ├── clamp_action.gd
│   ├── emit_signal_action.gd
│   ├── animation_action.gd
│   ├── scene_action.gd
│   ├── sound_action.gd
│   ├── state_action.gd
│   ├── variable_action.gd
│   ├── camera_action.gd
│   ├── gravity_action.gd
│   ├── random_action.gd
│   ├── group_action.gd
│   ├── call_method_action.gd
│   ├── wait_action.gd
│   ├── repeat_action.gd      ← NEW: Repeat N Times
│   ├── math_action.gd        ← NEW: Apply Math Function
│   └── print_action.gd
├── runtime/
│   └── event_controller.gd # Runtime event processor node
└── editor/                 # Editor UI
    ├── event_sheet_editor.gd
    ├── add_event_dialog.gd
    ├── condition_dialog.gd
    └── action_dialog.gd
```

## Extending the Addon

### Adding Custom Conditions

Create a new script extending `ESCondition`:

```gdscript
class_name ESMyCustomCondition
extends ESCondition

@export var my_parameter: String = ""

func get_summary() -> String:
    return "My Condition: %s" % my_parameter

func get_category() -> String:
    return "Custom"

func evaluate(controller: Node, delta: float) -> bool:
    # Return true when your condition is met
    return some_check()
```

### Adding Custom Actions

Create a new script extending `ESAction`:

```gdscript
class_name ESMyCustomAction
extends ESAction

@export var my_parameter: String = ""

func get_summary() -> String:
    return "My Action: %s" % my_parameter

func get_category() -> String:
    return "Custom"

func execute(controller: Node, delta: float) -> void:
    # Perform your action
    var target = controller.get_parent()
    # ... do something with target
```

## Inspiration

This addon draws inspiration from:
- [Construct 3](https://www.construct.net/) — Event sheet programming model
- [GDevelop](https://gdevelop.io/) — Visual event-based game logic
- [FlowKit](https://github.com/LexianDEV/FlowKit) — Flow-based visual scripting for Godot
- [Orchestra](https://github.com/CraterCrash/godot-orchestrator) — Visual scripting for Godot
- [Endless Block Coding](https://github.com/endlessm/godot-block-coding) — Block-based coding for Godot

## License

MIT License
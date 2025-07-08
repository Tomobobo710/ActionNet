# res://addons/ActionNetDemo/scripts/main.gd
extends Node

# ActionNet Soccer Demo - Main Setup
# 
# DEMO ARCHITECTURE:
# This demo shows how to build a networked game using ActionNet by implementing:
# 1. OBJECT REGISTRATION: Define what objects exist (register_soccer_objects)
# 2. WORLD CREATION: Let ActionNet spawn registered objects (create_clean_world) 
# 3. VISUAL/PHYSICS SEPARATION: UI elements for visuals, physics objects for collision
# 
# KEY PATTERN DEMONSTRATED:
# - Register object types BEFORE world creation
# - Use auto_spawn=true for static world elements (goal posts)
# - Use auto_spawn=false for dynamic objects (boxes for manual spawning)
# - Position objects via super._init(Physics.vec2(x, y)) in their constructors

var base_width: int = 1280
var base_height: int = 720
var current_state: String = "menu"
var manager_ui: ActionNetManagerUI

func _ready():
	setup_menu()
	register_soccer_objects()
	setup_soccer_inputs()
	create_clean_world()
	setup_logic_handlers()
	ActionNetManager.server_disconnected.connect(_on_server_disconnected)
	
	print("[SoccerDemo] ActionNet Soccer Game initialized!")
	print("[SoccerDemo] Controls: WASD to move, SPACE to kick ball")

func setup_logic_handlers():
	# DEMO: Logic Handler Registration Pattern
	# 
	# PURPOSE: Connect custom game logic to ActionNet's networking cycle
	# WHEN: Setup after object registration but before game starts
	# 
	# DUAL LOGIC APPROACH:
	# - Server Logic: Authoritative game rules (scoring, timers, win conditions)
	# - Client Logic: Presentation layer (UI updates, effects, local feedback)
	# 
	# Both run automatically at optimal points in the networking cycle
	
	# Server-side game logic (authoritative)
	var server_logic_handler = CustomServerLogicHandler.new()
	add_child(server_logic_handler)  # Add to scene tree for Godot lifecycle
	ActionNetManager.set_server_logic_handler(server_logic_handler)  # Register with ActionNet
	print("[SoccerDemo] Server logic handler set")
	
	# Client-side presentation logic (UI/effects)
	var client_logic_handler = CustomClientLogicHandler.new()
	add_child(client_logic_handler)  # Add to scene tree for Godot lifecycle
	ActionNetManager.set_client_logic_handler(client_logic_handler)  # Register with ActionNet
	print("[SoccerDemo] Client logic handler set")

func setup_soccer_inputs():
	# Soccer player controls
	ActionNetManager.register_key_input("move_forward", "pressed", KEY_W)   # Move up
	ActionNetManager.register_key_input("move_backward", "pressed", KEY_S)  # Move down  
	ActionNetManager.register_key_input("rotate_left", "pressed", KEY_A)    # Rotate left
	ActionNetManager.register_key_input("rotate_right", "pressed", KEY_D)   # Rotate right
	ActionNetManager.register_key_input("shoot", "just_pressed", KEY_SPACE) # Kick ball
	ActionNetManager.register_godot_input("pause", "just_pressed", "ui_cancel")
	
	print("[SoccerDemo] Soccer controls registered")

func register_soccer_objects():
	# Register soccer player
	var player_scene = create_client_object_scene()
	ActionNetManager.register_client_object(player_scene)
	
	# DEMO: ActionNet Object Registration Pattern
	# 
	# WHEN: Register objects BEFORE world creation
	# WHY: ActionNet needs to know what object types exist and how to create them
	# 
	# AUTO-SPAWN DECISION:
	# auto_spawn=true → ActionNet creates automatically during world init
	# auto_spawn=false → Object becomes "blueprint" for manual spawning later
	#
	# SOCCER DEMO STRATEGY:
	# - Ball: auto_spawn=true (always present at game start)
	# - GoalPosts: auto_spawn=true (static world collision elements)
	# - Box: auto_spawn=false (available for dynamic spawning)
	var soccer_objects = {
		"ball": Ball,                    # Appears at (640,360) automatically
		"box": Box,                     # Blueprint only - no auto-spawn
		# Invisible physics collision boxes for goal posts
		# Positioned to match ColorRect visuals in client_logic.gd
		"redgoalback": RedGoalBack,     # Left goal back wall
		"redgoaltop": RedGoalTop,       # Left goal top beam
		"redgoalbottom": RedGoalBottom, # Left goal bottom beam
		"bluegoalback": BlueGoalBack,   # Right goal back wall
		"bluegoaltop": BlueGoalTop,     # Right goal top beam
		"bluegoalbottom": BlueGoalBottom # Right goal bottom beam
	}
	
	for object_name in soccer_objects:
		var scene = create_physics_object_scene(soccer_objects[object_name])
		ActionNetManager.register_physics_object(object_name, scene)
	
	print("[SoccerDemo] Soccer objects registered:")
	print("  - ball (auto_spawn=true): Appears at center")
	print("  - box (auto_spawn=false): Blueprint for manual spawning") 
	print("  - 6 goal posts (auto_spawn=true): Invisible physics collision at goal positions")

func create_clean_world():
	# Create a world with goal physics objects positioned like ColorRects
	var world_root = Node2D.new()
	world_root.name = "SoccerFieldWithGoals"
	
	# Ball will auto-spawn via Ball.auto_spawn = true
	
	# Add goal posts using Box physics objects at ColorRect positions
	add_goal_physics_objects(world_root)
	
	# Pack and register the field
	var field_scene = PackedScene.new()
	var result = field_scene.pack(world_root)
	if result == OK:
		ActionNetManager.register_world_scene(field_scene)
		print("[SoccerDemo] Field created with goal physics objects")
	else:
		print("[SoccerDemo] Failed to pack field scene")

func add_goal_physics_objects(world_root: Node2D):
	# IMPORTANT: We no longer manually create objects here!
	# 
	# Previous approach (FAILED): Manual object creation in world scene
	# var goalpost = GoalPost.new(position)
	# world_root.add_child(goalpost)  # ActionNet ignored these
	#
	# Current approach (WORKS): Use ActionNet's auto-spawn system
	# 1. Register object types in register_soccer_objects()
	# 2. Set auto_spawn = true in object classes  
	# 3. ActionNet automatically creates them during world initialization
	#
	# Result: Objects appear at correct positions defined in their _init() methods
	print("[SoccerDemo] Letting ActionNet auto-spawn physics objects")

func create_client_object_scene() -> PackedScene:
	var client_object_root = Ship.new()
	var client_object_scene = PackedScene.new()
	client_object_scene.pack(client_object_root)
	return client_object_scene

func create_physics_object_scene(object_class: GDScript) -> PackedScene:
	var physics_object_root = object_class.new()
	var physics_object_scene = PackedScene.new()
	physics_object_scene.pack(physics_object_root)
	return physics_object_scene

func setup_menu():
	manager_ui = ActionNetManagerUI.new()
	manager_ui.base_width = base_width
	manager_ui.base_height = base_height
	manager_ui.connect("connected_to_server", Callable(self, "_on_change_state"))
	add_child(manager_ui)

func _on_server_disconnected():
	if current_state == "game":
		current_state = "menu"
		setup_menu()

func _on_change_state(new_state: String = "game"):
	current_state = new_state
	if new_state == "game":
		if manager_ui:
			remove_child(manager_ui)
			manager_ui.queue_free()
			manager_ui = null

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if current_state == "game":
				current_state = "menu"
				setup_menu()
			else:
				get_tree().quit()
		elif event.keycode == KEY_F11:
			_toggle_fullscreen()

func _toggle_fullscreen():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

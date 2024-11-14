# res://addons/ActionNetDemo/scripts/main.gd
extends Node

var base_width: int = 1280
var base_height: int = 720
var current_state: String = "menu"
var manager_ui: ActionNetManagerUI

var client_object_scene: PackedScene
var physics_object_scene: PackedScene

func _ready():
	setup_menu()
	register_objects()
	setup_inputs()
	create_custom_world_scene()
	# Set the custom server logic handler
	var custom_logic_handler = CustomServerLogicHandler.new()
	add_child(custom_logic_handler)
	ActionNetManager.set_server_logic_handler(custom_logic_handler)
	# Connect to server disconnection signal
	ActionNetManager.server_disconnected.connect(_on_server_disconnected)
	
func setup_inputs():
	# Overwrite default inputs with WASD
	ActionNetManager.register_key_input("move_forward", "pressed", KEY_W)
	ActionNetManager.register_key_input("move_backward", "pressed", KEY_S)
	ActionNetManager.register_key_input("rotate_left", "pressed", KEY_A)
	ActionNetManager.register_key_input("rotate_right", "pressed", KEY_D)
	
	# Register additional custom inputs
	ActionNetManager.register_key_input("shoot", "just_pressed", KEY_SPACE)
	ActionNetManager.register_key_input("shield", "pressed", KEY_SHIFT)
	ActionNetManager.register_godot_input("pause", "just_pressed", "ui_cancel")

func register_objects():
	var ship_scene = create_client_object_scene()
	ActionNetManager.register_client_object(ship_scene)
	
	# Register physics objects
	var physics_objects = {
		"ball": Ball,
	}
	
	for object_name in physics_objects:
		var scene = create_physics_object_scene(physics_objects[object_name])
		ActionNetManager.register_physics_object(object_name, scene)

func create_custom_world_scene():
	# Create the root node for our world
	var world_root = Node2D.new()
	world_root.name = "CustomWorld"
	
	# Create a box instance from the packed scene
	var box_scene = create_physics_object_scene(Box)
	var box_instance = box_scene.instantiate()
	box_instance.fixed_position = Physics.vec2(150, 150)  # Position in top-left
	box_instance.name = "TopLeftBox"
	
	# Add the box to the world
	world_root.add_child(box_instance)
	
	# Make sure the box is owned by the scene
	box_instance.set_owner(world_root)
	
	# Create a PackedScene from our world
	var custom_world_scene = PackedScene.new()
	var result = custom_world_scene.pack(world_root)
	if result == OK:
		# Register this as our world scene
		ActionNetManager.register_world_scene(custom_world_scene)
		print("[ActionNetDemoMain] Registered custom world with box")
	else:
		print("[ActionNetDemoMain] Failed to pack custom world scene")

func create_client_object_scene() -> PackedScene:
	var client_object_root = Ship.new()
	var client_object_scene = PackedScene.new()
	client_object_scene.pack(client_object_root)
	return client_object_scene

func create_physics_object_scene(object_class: GDScript) -> PackedScene:
	var physics_object_root = object_class.new()
	physics_object_root.fixed_position = Physics.vec2(150,150)
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

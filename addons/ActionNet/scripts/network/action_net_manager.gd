# res://addons/ActionNet/scripts/action_net_manager.gd
extends Node

# ActionNetManager is an autoloaded singleton class

signal server_created
signal client_created
signal connected_to_server
signal connection_failed
signal server_disconnected

var server: ActionNetServer
var client: ActionNetClient

var server_multiplayer_api: MultiplayerAPI
var client_multiplayer_api: MultiplayerAPI

var debug_ui: ActionNetDebugUI

const DEFAULT_PORT = 9050
const MAX_CLIENTS = 32
const MAX_PORT_ATTEMPTS = 10

var registered_client_object: PackedScene
var registered_physics_objects: Dictionary = {}

var input_definitions: Dictionary = {}

var world_scene: PackedScene

func _ready():
	get_tree().multiplayer_poll = false
	initialize_debug_ui()
	register_default_inputs()
	create_default_world_scene()
	
	# Create both server and client to ensure "scene tree" layout matches
	if not server:
		server = ActionNetServer.new()
		server.name = "Server"
		server.manager = self
		get_tree().root.add_child.call_deferred(server)
	if not client:
		client = ActionNetClient.new()
		client.name = "Client"
		client.manager = self
		client.server_disconnected.connect(_on_server_disconnected)
		get_tree().root.add_child.call_deferred(client)

func _on_server_disconnected() -> void:
	show_error_popup("Lost connection to server")
	emit_signal("server_disconnected")

func create_default_world_scene():
	var world_root = Node2D.new()
	world_root.name = "World"
	
	# Create a blank scene with the Node2D root
	world_scene = PackedScene.new()
	world_scene.pack(world_root)
	print("[ActionNetManager] Created default world scene.")

func register_world_scene(scene: PackedScene):
	world_scene = scene
	print("[ActionNetManager] Registered custom world scene.")

func get_world_scene() -> PackedScene:
	return world_scene

func initialize_debug_ui():
	debug_ui = ActionNetDebugUI.new()
	add_child(debug_ui)	

func register_client_object(scene: PackedScene):
	registered_client_object = scene

func register_physics_object(name: String, scene: PackedScene):
	registered_physics_objects[name] = scene

func get_client_object_scene() -> PackedScene:
	return registered_client_object

func get_physics_object_scene(name: String) -> PackedScene:
	return registered_physics_objects.get(name)

func register_godot_input(action_name: String, input_type: String, godot_action: String) -> void:
	input_definitions[action_name] = InputDefinition.new(action_name, input_type, "godot_action", godot_action)

func register_key_input(action_name: String, input_type: String, key_code: int) -> void:
	input_definitions[action_name] = InputDefinition.new(action_name, input_type, "key", key_code)

func register_default_inputs() -> void:
	register_godot_input("rotate_right", "pressed", "ui_right")
	register_godot_input("rotate_left", "pressed", "ui_left")
	register_godot_input("move_forward", "pressed", "ui_up")
	register_godot_input("move_backward", "pressed", "ui_down")

func create_server(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	var error = server.create(port, max_clients)
	if error == OK:
		server_multiplayer_api = server.server_multiplayer
		debug_ui.set_server(server)
		emit_signal("server_created")
	return error

func create_client(server_ip: String, port: int) -> Error:
	var error = client.connect_to_server(server_ip, port)
	if error == OK:
		client_multiplayer_api = client.client_multiplayer
		client.connected.connect(_on_client_connected)
		client.connection_failed.connect(_on_client_connection_failed)
		client.connection_timed_out.connect(_on_client_connection_timed_out)
		debug_ui.set_client(client)
		emit_signal("client_created")
	else:
		show_error_popup("Failed to create client. Error code: " + str(error))
	return error

func show_error_popup(error_message: String):
	if debug_ui:
		debug_ui.show_error_popup(error_message)

func _on_client_connected() -> void:
	emit_signal("connected_to_server")

func _on_client_connection_failed() -> void:
	show_error_popup("Failed to connect to server.")
	emit_signal("connection_failed")

func _on_client_connection_timed_out() -> void:
	show_error_popup("Connection to server timed out.")
	emit_signal("connection_failed")

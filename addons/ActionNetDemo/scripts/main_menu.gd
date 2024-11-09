# res://addons/ActionNetDemo/scripts/main_menu.gd
extends Node

var base_width: int = 1280
var base_height: int = 720

# UI Elements
var name_input: LineEdit
var ip_input: LineEdit
var port_input: LineEdit
var host_button: Button
var join_button: Button
var create_server_button: Button
var quit_button: Button

# Callback to change game state
var change_state_callback: Callable = Callable()

var player_name: String = "Player"

func _ready():
	_create_ui_elements()
	
	# Connect signals
	host_button.connect("pressed", Callable(self, "_on_host_button_pressed"))
	join_button.connect("pressed", Callable(self, "_on_join_button_pressed"))
	create_server_button.connect("pressed", Callable(self, "_on_create_server_button_pressed"))
	quit_button.connect("pressed", Callable(self, "_on_quit_button_pressed"))
	name_input.connect("text_changed", Callable(self, "_on_name_input_text_changed"))
	
	# Connect to ActionNetManager signals
	ActionNetManager.connected_to_server.connect(_on_connected_to_server)
	ActionNetManager.connection_failed.connect(_on_connection_failed)

func _create_ui_elements():
	# Create a VBoxContainer to hold the UI elements
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	vbox.offset_left = -base_width / 6
	vbox.offset_top = -base_height / 3
	add_child(vbox)

	# Create and configure LineEdit for name input
	name_input = LineEdit.new()
	name_input.custom_minimum_size = Vector2(base_width / 3, 30)
	name_input.text = "Player"
	vbox.add_child(name_input)
	
	# Create and configure LineEdit for IP input
	ip_input = LineEdit.new()
	ip_input.custom_minimum_size = Vector2(base_width / 3, 30)
	ip_input.text = "127.0.0.1"
	vbox.add_child(ip_input)
	
	# Create and configure LineEdit for port input
	port_input = LineEdit.new()
	port_input.custom_minimum_size = Vector2(base_width / 3, 30)
	port_input.text = "9050"
	port_input.max_length = 5
	vbox.add_child(port_input)
	
	# Create and configure buttons
	host_button = Button.new()
	host_button.text = "Host Game"
	vbox.add_child(host_button)
	
	join_button = Button.new()
	join_button.text = "Join Game"
	vbox.add_child(join_button)
	
	create_server_button = Button.new()
	create_server_button.text = "Create Server"
	vbox.add_child(create_server_button)
	
	quit_button = Button.new()
	quit_button.text = "Quit"
	vbox.add_child(quit_button)

func _on_name_input_text_changed(new_text: String):
	player_name = new_text

func _on_host_button_pressed():
	print("[MainMenu] Host button pressed")
	var port = int(port_input.text)
	var result = await ActionNetManager.create_server(port)
	if result == OK:
		print("[MainMenu] Server started successfully")		
		_start_client("127.0.0.1", port)
	else:
		print("[MainMenu] Failed to start server")

func _on_join_button_pressed():
	var ip = ip_input.text
	var port = int(port_input.text)
	
	# Check if the input is not an IP address using a regular expression
	var ip_pattern = "^([0-9]{1,3}\\.){3}[0-9]{1,3}$"
	if not ip.is_valid_ip_address():
		# Resolve the hostname to an IP address
		print("[MainMenu] Attempting to resolve hostname: ", ip)
		var resolved_ip = IP.resolve_hostname(ip, IP.TYPE_ANY)
		if resolved_ip != "":
			ip = resolved_ip
			print("[MainMenu] Resolved hostname to IP: ", ip)
		else:
			print("[MainMenu] Failed to resolve hostname")
			return
	await _start_client(ip, port)

func _on_create_server_button_pressed():
	var port = int(port_input.text)
	var result = await ActionNetManager.create_server(port)
	if result == OK:
		print("[MainMenu] Server created successfully")
	else:
		print("[MainMenu] Failed to create server")

func _start_client(ip: String, port: int):
	ActionNetManager.create_client(ip, port)

func _on_connected_to_server():
	print("[MainMenu] Successfully connected to server")
	if change_state_callback.is_valid():
		change_state_callback.call("game")

func _on_connection_failed():
	print("[MainMenu] Failed to connect to server")

func _on_quit_button_pressed():
	get_tree().quit()

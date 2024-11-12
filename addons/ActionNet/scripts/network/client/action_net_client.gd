# res://addons/ActionNet/scripts/network/client/action_net_client.gd
extends Node
class_name ActionNetClient

signal connected
signal connection_failed
signal connection_timed_out
signal server_disconnected
signal handshake_failed(reason: String)
signal handshake_completed
signal sequence_adjusted(new_offset: int, reason: String)
signal prediction_missed(sequence: int, server_state: Dictionary, client_state: Dictionary)

var manager: ActionNetManager
var clock: ActionNetClock
var connection_manager: ClientConnectionManager
var received_state_manager: ReceivedStateManager
var input_registry: InputRegistry
var world_manager: WorldManager
var collision_manager: CollisionManager
var network: ENetMultiplayerPeer
var client_multiplayer: MultiplayerAPI
var client_world: Node
var client_objects: Node
var physics_objects: Node
var last_processed_sequence: int = -1
var is_sending_inputs: bool = false

func connect_to_server(ip: String, port: int) -> Error:
	network = ENetMultiplayerPeer.new()
	print("[ActionNetClient] Attempting to connect to server at ", ip, ":", port)
	var error = network.create_client(ip, port)
	if error == OK:
		setup_multiplayer()
		setup_client_world()
		setup_clock()
		setup_connection_manager()
		setup_polling()
		return OK
	else:
		print("[ActionNetClient] Failed to create client. Error code: ", error)
		emit_signal("connection_failed")
		return error

func setup_multiplayer() -> void:
	client_multiplayer = MultiplayerAPI.create_default_interface()
	client_multiplayer.multiplayer_peer = network
	client_multiplayer.set_root_path(get_path())
	get_tree().set_multiplayer(client_multiplayer, self.get_path())
	
	client_multiplayer.connected_to_server.connect(_on_connected_to_server)
	client_multiplayer.connection_failed.connect(_on_connection_failed)
	client_multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	manager.client_multiplayer_api = client_multiplayer

func setup_client_world() -> void:
	# Create client predicted world
	client_world = manager.get_world_scene().instantiate()
	client_world.name = "ClientWorld"
	add_child(client_world)
	
	# Initialize input registry
	input_registry = InputRegistry.new()
	input_registry.is_server_owned = false
	add_child(input_registry)
	
	# Initialize managers for prediction
	collision_manager = CollisionManager.new()
	world_manager = WorldManager.new()
	world_manager.initialize(client_world, collision_manager, manager)
	# Connect to signals
	world_manager.object_spawned.connect(_on_object_spawned)
	world_manager.prediction_missed.connect(_on_prediction_missed)
	add_child(world_manager)
	
	# Register world objects and auto-spawn
	world_manager.register_existing_physics_objects()
	world_manager.auto_spawn_physics_objects()
	
	# Spawn client-side client object
	world_manager.spawn_client_object(client_multiplayer.get_unique_id())
	
	# Create the received state manager
	received_state_manager = ReceivedStateManager.new(self)
	add_child(received_state_manager)
	received_state_manager.setup()

func setup_clock() -> void:
	clock = ActionNetClock.new()
	clock.connect("tick", Callable(self, "_on_tick"))
	add_child(clock)

func setup_connection_manager() -> void:
	connection_manager = ClientConnectionManager.new()
	connection_manager.initialize(self)
	connection_manager.sequence_adjusted.connect(_on_sequence_adjusted)
	connection_manager.handshake_completed.connect(_on_handshake_completed)
	connection_manager.handshake_failed.connect(_on_handshake_failed)
	add_child(connection_manager)

func setup_polling() -> void:
	var poll_timer = Timer.new()
	poll_timer.wait_time = 0.001
	poll_timer.timeout.connect(_on_poll_timer_timeout)
	add_child(poll_timer)
	poll_timer.start()

func _on_connected_to_server() -> void:
	print("[ActionNetClient] Connected to server, beginning handshake...")
	connection_manager.start_handshake()
	emit_signal("connected")

func _on_handshake_completed() -> void:
	is_sending_inputs = true
	emit_signal("handshake_completed")

func _on_handshake_failed(reason: String) -> void:
	is_sending_inputs = false
	network.close()
	emit_signal("handshake_failed", reason)

func _on_object_spawned(object: Node, type: String) -> void:
	if type == "client":
		print("[ActionNetClient] Spawned client-side client object for client id: ", object.name)
	else:
		print("[ActionNetClient] Spawned object of type: ", type)

func _on_sequence_adjusted(new_sequence: int, reason: String) -> void:
	world_manager.sequence = new_sequence
	emit_signal("sequence_adjusted", new_sequence, reason)

func _on_tick(clock_sequence: int) -> void:
	connection_manager.update()
	poll()
	handle_input()

func handle_input() -> void:
	# Check prediction
	if world_manager:
		world_manager.check_prediction(received_state_manager.world_registry.get_newest_state(), client_multiplayer.get_unique_id())
		print("[ActionNetClient] Prediction check done, world manager sequence is: ", world_manager.sequence, ". handling input...")
	if is_sending_inputs:
		connection_manager.check_sequence_adjustment()
		# Get and store current input before sending
		var current_input = {}
		for action_name in manager.input_definitions:
			var input_def = manager.input_definitions[action_name]
			current_input[action_name] = input_def.get_input_value()
		
		print("[ActionNetClient] Connection manager current sequence is: ", connection_manager.get_client_sequence())
		current_input["sequence"] = world_manager.sequence
		input_registry.store_input(client_multiplayer.get_unique_id(), current_input)
		
		# Apply input to client object and update world
		var client_objects = world_manager.client_objects
		for client_object in client_objects.get_children():
			var client_id = int(str(client_object.name))
			var input = input_registry.get_input_for_sequence(client_id, world_manager.sequence)
			client_object.apply_input(input, clock.tick_rate)
		
		# Update predicted world state
		world_manager.update(clock.tick_rate)
		
		# Increment the world manager's sequence manually...
		world_manager.sequence += 1
		
		# Send input to server (existing functionality)
		send_input()
		print("[ActionNetClient] Input handling done. World manager sequence is now: ", world_manager.sequence)

func _on_poll_timer_timeout() -> void:
	if client_multiplayer and client_multiplayer.has_multiplayer_peer():
		client_multiplayer.poll()

func _on_connection_failed() -> void:
	print("[ActionNetClient] Connection to server failed")
	emit_signal("connection_failed")

func _on_server_disconnected() -> void:
	print("[ActionNetClient] Disconnected from server")
	cleanup()
	emit_signal("server_disconnected")

func request_spawn_from_server() -> void:
	rpc("request_spawn")

func _on_prediction_missed(sequence: int, server_state: Dictionary, client_state: Dictionary) -> void:
	print("[ActionNetClient] Prediction missed for sequence ", sequence)
	print("Server state: ", server_state)
	print("Client state: ", client_state)
	emit_signal("prediction_missed", sequence, server_state, client_state)

func send_input() -> void:
	var current_input = {}
	for action_name in manager.input_definitions:
		var input_def = manager.input_definitions[action_name]
		current_input[action_name] = input_def.get_input_value()
	
	if client_multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		current_input["sequence"] = connection_manager.get_client_sequence()
		rpc("receive_input", current_input)

func poll() -> void:
	if client_multiplayer.has_multiplayer_peer():
		client_multiplayer.multiplayer_peer.poll()

func cleanup() -> void:
	if network:
		network.close()
	
	if clock:
		clock.queue_free()
		clock = null
	
	if received_state_manager:
		received_state_manager.cleanup()
		received_state_manager.queue_free()
		received_state_manager = null
	
	if client_world:
		client_world.queue_free()
		client_world = null
	
	if connection_manager:
		connection_manager.handshake_in_progress = false
	
	if world_manager:
		world_manager.queue_free()
		world_manager = null
	
	if collision_manager:
		collision_manager.queue_free()
		collision_manager = null
	
	if input_registry:
		input_registry.queue_free()
		input_registry = null
	
	is_sending_inputs = false

# Local RPC methods
@rpc("any_peer", "call_remote", "unreliable")
func receive_pong(server_time: int) -> void:
	connection_manager.handle_pong(server_time)

@rpc("authority", "call_remote", "unreliable")
func receive_world_state(state: Dictionary) -> void:
	# Forward to the received state manager
	received_state_manager.process_world_state(state)

# Remote method declarations
@rpc("any_peer", "call_remote", "reliable")
func request_spawn():
	pass 

@rpc("any_peer", "call_remote", "unreliable")
func receive_ping(client_id: int) -> void:
	pass

@rpc("any_peer", "call_remote", "unreliable")
func receive_input(input: Dictionary):
	pass

## Keeping these methods for reference on sending byte array messages
#func send_ping_message() -> void:
	#var ping_packet = PackedByteArray([0])  # 0 represents ping
	#print("[ActionNetClient] Sending ping to server. Full packet content: ", bytes_to_string(ping_packet))
	#client_multiplayer.send_bytes(ping_packet, 1, 2, 0)
	#last_ping_time = Time.get_ticks_msec()
	#print("[ActionNetClient] Sent ping to server. Packet Size: ", ping_packet.size())
#
#func _handle_packet(packet: PackedByteArray) -> void:
	#if packet.size() < 1:
		#print("[ActionNetClient] Received invalid packet from server")
		#return
	#print("[ActionNetClient] Received packet from server. Size: ", packet.size())
	#var packet_type = packet[-1]
	#
	#match packet_type:
		#1:  # Pong packet
			#var current_time = Time.get_ticks_msec()
			#var rtt = current_time - last_ping_time
			#print("[ActionNetClient] Received pong from server. RTT: ", rtt, "ms")
#
#func bytes_to_string(bytes: PackedByteArray) -> String:
	#var byte_strings = []
	#for byte in bytes:
		#byte_strings.append(str(byte))
	#return " ".join(byte_strings)

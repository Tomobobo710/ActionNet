# res://addons/ActionNet/scripts/network/action_net_server.gd
extends Node
class_name ActionNetServer

var port: int
var max_clients: int
var clients: Dictionary = {}

var clock: ActionNetClock
var world_manager: WorldManager
var collision_manager: CollisionManager
var input_registry: InputRegistry
var logic_handler: LogicHandler
var server_world: Node
var server_multiplayer: MultiplayerAPI
var network: ENetMultiplayerPeer
var processed_state: Dictionary

signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)

func create(port: int, max_clients: int) -> Error:
	self.port = port
	self.max_clients = max_clients
	
	# Initialize input registry
	input_registry = InputRegistry.new()
	add_child(input_registry)
	
	# Create the server
	network = ENetMultiplayerPeer.new()
	var error = network.create_server(port, max_clients)
	
	match error:
		OK:
			print("[ActionNetServer] Server created on port ", port)
			
			setup_server_world()
			setup_multiplayer()
			setup_world_manager()
			setup_clock()
			setup_polling()
			
			return OK
			
		ERR_ALREADY_IN_USE:
			print("[ActionNetServer] Failed to create server. Port ", port, " is already in use.")
			return ERR_ALREADY_IN_USE
			
		ERR_CANT_CREATE:
			print("[ActionNetServer] Failed to create server. Unable to create ENet host.")
			return error
			
		ERR_INVALID_PARAMETER:
			print("[ActionNetServer] Failed to create server. Invalid parameter (port or max_clients).")
			return ERR_INVALID_PARAMETER
			
		_:
			print("[ActionNetServer] Failed to create server. Error code: ", error)
			return error

func setup_server_world():
	# Initialize world
	server_world = ActionNetManager.get_world_scene().instantiate()
	server_world.name = "ServerWorld"
	add_child(server_world)

func setup_multiplayer():
	# Set up networking
	server_multiplayer = MultiplayerAPI.create_default_interface()
	server_multiplayer.multiplayer_peer = network
	server_multiplayer.set_root_path(get_path())
	get_tree().set_multiplayer(server_multiplayer, self.get_path())
	server_multiplayer.peer_connected.connect(_on_peer_connected)
	server_multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	server_multiplayer.server_relay = true
	ActionNetManager.server_multiplayer_api = server_multiplayer

func setup_world_manager():
	# Initialize world management
	collision_manager = CollisionManager.new()
	world_manager = WorldManager.new()
	world_manager.initialize(server_world, collision_manager, ActionNetManager)
	world_manager.object_spawned.connect(_on_object_spawned)
	add_child(world_manager)
	# Register world objects and auto-spawn
	world_manager.register_existing_physics_objects()
	world_manager.auto_spawn_physics_objects()

func setup_clock():
	# Initialize clock
	clock = ActionNetClock.new()
	clock.connect("tick", Callable(self, "_on_tick"))
	add_child(clock)

func setup_polling():
	# Set up polling
	var poll_timer = Timer.new()
	poll_timer.wait_time = 0.001
	poll_timer.timeout.connect(_on_poll_timer_timeout)
	add_child(poll_timer)
	poll_timer.start()

func handle_input():
	# Apply inputs for all client objects
	var client_objects = world_manager.client_objects
	for client_object in client_objects.get_children():
		var client_id = int(str(client_object.name))
		var input = input_registry.get_input_for_sequence(client_id, world_manager.sequence)
		#print("[ActionNetServer] Got input for client ", client_id, " for the sequence to process: ", world_manager.sequence)
		client_object.apply_input(input, clock.tick_rate)

func _on_object_spawned(object: Node, type: String) -> void:
	if type == "client":
		print("[ActionNetServer] Spawned client object for client id: ", object.name)
		object.set_color(Color.WHITE)
		object.set_z_index(-1)
		object.hide()
	else:
		print("[ActionNetServer] Spawned physics object: ", type)
		object.set_color(Color.WHITE)
		object.set_z_index(-1)
		object.hide()

func _on_peer_connected(peer_id: int) -> void:
	print("[ActionNetServer] Client connected to server: ", peer_id)
	clients[peer_id] = {"last_ping_time": 0}
	emit_signal("client_connected", peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("[ActionNetServer] Client disconnected from server: ", peer_id)
	
	# Remove client object from the world
	if world_manager and world_manager.client_objects:
		var client_object = world_manager.client_objects.get_node_or_null(str(peer_id))
		if client_object:
			if world_manager.collision_manager:
				world_manager.collision_manager.unregister_object(client_object)
			client_object.queue_free()
	
	# Clean up client data
	clients.erase(peer_id)
	input_registry.remove_client(peer_id)
	
	emit_signal("client_disconnected", peer_id)

func _on_poll_timer_timeout():
	if server_multiplayer and server_multiplayer.has_multiplayer_peer():
		server_multiplayer.poll()

func _on_tick(clock_sequence: int) -> void:
	handle_input()
	
	# Update world state
	world_manager.update(clock.tick_rate)
	#print("[ActionNetServer] Server world manager sequence updated, is now: ", world_manager.sequence)
	
	processed_state = world_manager.get_world_state()
	
	# processed_state is like, super valuable
	# it's the result of all the networking work
	# before we send the state to the client, we can jump in right here and execute custom logic that a developer implements
	
	logic_handler.update()
	
	# Send world state to all clients
	if not clients.is_empty():
		rpc("receive_world_state", processed_state)
		#print("[ActionNetServer] Server sending world state with sequence: ", world_manager.sequence)
	
	# Increment the world manager's sequence manually...
	world_manager.sequence += 1

# Server side RPCs
@rpc("any_peer", "call_remote", "reliable")
func request_spawn():
	var id = server_multiplayer.get_remote_sender_id()
	print("[ActionNetServer] Received spawn request from client: ", id)
	world_manager.spawn_client_object(id)

@rpc("any_peer", "call_local", "unreliable")
func receive_ping(client_id: int) -> void:
	#print("[ActionNetServer] Received ping from client: ", server_multiplayer.get_remote_sender_id())
	rpc_id(server_multiplayer.get_remote_sender_id(), "receive_pong", Time.get_ticks_msec())

@rpc("any_peer", "call_remote", "unreliable")
func receive_input(input: Dictionary):
	var client_id = server_multiplayer.get_remote_sender_id()
	input_registry.store_input(client_id, input)

# Remote method declarations
@rpc("authority", "call_remote", "unreliable")
func receive_world_state(_state: Dictionary) -> void:
	pass

@rpc("any_peer", "call_remote", "unreliable")
func receive_pong(server_time: int) -> void:
	pass






# Keeping these methods for reference on sending byte array messages
func _handle_packet(peer_id: int, packet: PackedByteArray) -> void:
	if packet.size() < 1:
		print("[ActionNetServer] Received invalid packet from client: ", peer_id)
		return
	
	var packet_type = packet[-1]
	print("[ActionNetServer] Received packet type: ", packet_type, " from client: ", peer_id)
	
	match packet_type:
		0:  # Ping packet
			print("[ActionNetServer] Received ping from client: ", peer_id)
			send_pong_message(peer_id)

func send_pong_message(peer_id: int) -> void:
	var pong_packet = PackedByteArray([1])  # 1 represents pong
	print("[ActionNetServer] Sending pong to client: ", peer_id, " Full packet content: ", bytes_to_string(pong_packet))
	network.set_target_peer(peer_id)
	server_multiplayer.send_bytes(pong_packet, peer_id)
	print("[ActionNetServer] Sent pong to client: ", peer_id, " Packet size: ", pong_packet.size())

func bytes_to_string(bytes: PackedByteArray) -> String:
	var byte_strings = []
	for byte in bytes:
		byte_strings.append(str(byte))
	return " ".join(byte_strings)

# res://addons/ActionNet/scripts/network/action_net_server.gd
extends Node
class_name ActionNetServer

var port: int
var max_clients: int
var clients: Dictionary = {}

var manager: ActionNetManager
var clock: ActionNetClock
var world_manager: WorldManager
var collision_manager: CollisionManager
var input_registry: InputRegistry
var server_world: Node
var server_multiplayer: MultiplayerAPI
var network: ENetMultiplayerPeer

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
			
			# Initialize world
			server_world = manager.get_world_scene().instantiate()
			server_world.name = "ServerWorld"
			add_child(server_world)
			
			# Set up networking
			server_multiplayer = MultiplayerAPI.create_default_interface()
			server_multiplayer.multiplayer_peer = network
			server_multiplayer.set_root_path(get_path())
			get_tree().set_multiplayer(server_multiplayer, self.get_path())
			
			server_multiplayer.peer_connected.connect(_on_peer_connected)
			server_multiplayer.peer_disconnected.connect(_on_peer_disconnected)
			server_multiplayer.server_relay = true
			manager.server_multiplayer_api = server_multiplayer
			
			# Initialize managers
			collision_manager = CollisionManager.new()
			world_manager = WorldManager.new()
			world_manager.initialize(server_world, collision_manager)
			add_child(world_manager)
			
			# Initialize clock
			clock = ActionNetClock.new()
			clock.connect("tick", Callable(self, "_on_tick"))
			add_child(clock)
			
			# Set up polling
			var poll_timer = Timer.new()
			poll_timer.wait_time = 0.001
			poll_timer.timeout.connect(_on_poll_timer_timeout)
			add_child(poll_timer)
			poll_timer.start()
			
			# Register world objects and auto-spawn
			world_manager.register_existing_physics_objects()
			auto_spawn_physics_objects()
			
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
	# Apply inputs for all client objects
	var client_objects = world_manager.client_objects
	for client_object in client_objects.get_children():
		var client_id = int(str(client_object.name))
		var input = input_registry.get_input_for_sequence(client_id, world_manager.sequence)
		client_object.apply_input(input)
	
	# Update world state
	world_manager.update(16)
	
	# Send world state to all clients
	if not clients.is_empty():
		rpc("receive_world_state", world_manager.get_world_state())

func auto_spawn_physics_objects() -> void:
	for object_type in manager.registered_physics_objects.keys():
		var scene = manager.get_physics_object_scene(object_type)
		var temp_instance = scene.instantiate()
		if temp_instance.auto_spawn:
			world_manager.spawn_physics_object(object_type, scene)
		temp_instance.queue_free()

func spawn_client_object(id: int):
	var client_object_scene = manager.get_client_object_scene()
	if client_object_scene:
		world_manager.spawn_client_object(id, client_object_scene)
		print("[ActionNetServer] Spawned client object for client id: ", id)
	else:
		print("[ActionNetServer] Error: No client object registered")

func spawn_physics_object(object_type: String):
	var physics_object_scene = manager.get_physics_object_scene(object_type)
	if physics_object_scene:
		world_manager.spawn_physics_object(object_type, physics_object_scene)
		print("[ActionNetServer] Spawned physics object: ", object_type)
	else:
		print("[ActionNetServer] Error: No physics object registered with type: ", object_type)

# Server side RPCs
@rpc("any_peer", "call_remote", "reliable")
func request_spawn():
	var id = server_multiplayer.get_remote_sender_id()
	print("[ActionNetServer] Received spawn request from client: ", id)
	spawn_client_object(id)

@rpc("any_peer", "call_local", "unreliable")
func receive_ping(client_id: int) -> void:
	#print("[ActionNetServer] Received ping from client: ", server_multiplayer.get_remote_sender_id())
	rpc_id(server_multiplayer.get_remote_sender_id(), "receive_pong", Time.get_ticks_msec())

@rpc("any_peer", "call_remote", "unreliable")
func receive_input(input: Dictionary):
	var client_id = server_multiplayer.get_remote_sender_id()
	input_registry.store_input(client_id, input)

# Client side RPC must be declared locally 
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

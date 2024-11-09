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

var manager: ActionNetManager
var clock: ActionNetClock
var connection_manager: ClientConnectionManager
var network: ENetMultiplayerPeer
var client_multiplayer: MultiplayerAPI
var client_world: Node
var client_objects: Node
var physics_objects: Node
var last_processed_sequence: int = -1
var is_sending_inputs: bool = false

#func _process(delta: float) -> void:
	#if connection_manager:
		#if connection_manager.handshake_in_progress:
			#connection_manager.process_handshake(delta)

func connect_to_server(ip: String, port: int) -> Error:
	network = ENetMultiplayerPeer.new()
	print("[ActionNetClient] Attempting to connect to server at ", ip, ":", port)
	var error = network.create_client(ip, port)
	if error == OK:
		setup_client_world()
		setup_multiplayer()
		setup_clock()
		setup_connection_manager()
		setup_polling()
		return OK
	else:
		print("[ActionNetClient] Failed to create client. Error code: ", error)
		emit_signal("connection_failed")
		return error

func setup_client_world() -> void:
	client_world = manager.get_world_scene().instantiate()
	client_world.name = "ClientWorld"
	add_child(client_world)
	
	client_objects = Node2D.new()
	client_objects.name = "Client Objects"
	client_world.add_child(client_objects)

	physics_objects = Node2D.new()
	physics_objects.name = "2D Physics Objects"
	client_world.add_child(physics_objects)

func setup_multiplayer() -> void:
	client_multiplayer = MultiplayerAPI.create_default_interface()
	client_multiplayer.multiplayer_peer = network
	client_multiplayer.set_root_path(get_path())
	get_tree().set_multiplayer(client_multiplayer, self.get_path())
	
	client_multiplayer.connected_to_server.connect(_on_connected_to_server)
	client_multiplayer.connection_failed.connect(_on_connection_failed)
	client_multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	manager.client_multiplayer_api = client_multiplayer

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

@rpc("any_peer", "call_remote", "unreliable")
func receive_pong(server_time: int) -> void:
	connection_manager.handle_pong(server_time)

@rpc("authority", "call_remote", "unreliable")
func receive_world_state(state: Dictionary) -> void:
	var sequence = state["sequence"]
	
	# Skip if we've already processed this state
	if sequence <= last_processed_sequence:
		return
	
	last_processed_sequence = sequence
	connection_manager.update_server_sequence(sequence)
	
	# Check for client object during handshake
	if connection_manager.handshake_in_progress:
		var our_id = str(multiplayer.get_unique_id())
		if our_id in state["client_objects"]:
			connection_manager.confirm_client_object()
	
	update_client_objects(state["client_objects"])
	update_physics_objects(state["physics_objects"])


func update_client_objects(state_objects: Dictionary) -> void:
	var updated_objects = []
	
	for client_id in state_objects:
		var object_state = state_objects[client_id]
		updated_objects.append(str(client_id))
		
		if not client_objects.has_node(str(client_id)):
			var client_object_scene = manager.get_client_object_scene()
			if client_object_scene:
				var client_object = client_object_scene.instantiate()
				client_object.name = str(client_id)
				client_objects.add_child(client_object)
		
		if client_objects.has_node(str(client_id)):
			var client_object = client_objects.get_node(str(client_id))
			client_object.set_state(object_state)
	
	# Remove disconnected objects
	for client_object in client_objects.get_children():
		if not client_object.name in updated_objects:
			client_object.queue_free()

func update_physics_objects(state_objects: Dictionary) -> void:
	var updated_objects = []
	
	for object_name in state_objects:
		var object_state = state_objects[object_name]
		var safe_name = object_name.replace("@", "_")
		updated_objects.append(safe_name)
		
		var physics_object = physics_objects.get_node_or_null(safe_name)
		
		if not physics_object:
			physics_object = client_world.find_child(safe_name, true, false)
			if physics_object and physics_object.get_parent() != physics_objects:
				physics_object.get_parent().remove_child(physics_object)
				physics_objects.add_child(physics_object)
		
		if not physics_object:
			var object_type = object_state["type"]
			var physics_object_scene = manager.get_physics_object_scene(object_type)
			if physics_object_scene:
				physics_object = physics_object_scene.instantiate()
				physics_object.name = safe_name
				physics_objects.add_child(physics_object)
			else:
				print("[ActionNetClient] Error: No physics object registered with type: ", object_type)
				continue
		
		physics_object.set_state(object_state)
	
	# Remove objects no longer in state
	for physics_object in physics_objects.get_children():
		if not physics_object.name in updated_objects:
			physics_object.queue_free()

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

func _on_sequence_adjusted(new_offset: int, reason: String) -> void:
	emit_signal("sequence_adjusted", new_offset, reason)

func _on_tick(clock_sequence: int) -> void:
	connection_manager.increment_sequence()
	poll()
	
	if is_sending_inputs:
		connection_manager.check_sequence_adjustment()
		send_input()
	
	# Regular ping updates handled by connection manager
	if not connection_manager.handshake_in_progress:
		connection_manager.process_ping_timer(1.0)
		
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
	
	if client_world:
		client_world.queue_free()
		client_world = null
	
	if connection_manager:
		connection_manager.handshake_in_progress = false
	
	is_sending_inputs = false

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

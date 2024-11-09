# res://addons/ActionNet/scripts/network/client/client_connection_manager.gd
extends Node
class_name ClientConnectionManager

signal sequence_adjusted(new_offset: int, reason: String)
signal handshake_completed
signal handshake_failed(reason: String)

# Handshake properties
var handshake_duration: float = 1.0
var handshake_pings_total: int = 5
var handshake_start_time: int = 0
var handshake_timer: float = 0.0
var handshake_in_progress: bool = false
var spawn_requested: bool = false
var client_object_confirmed: bool = false

# Handshake-specific ping tracking
var handshake_pings_sent: int = 0
var handshake_ping_interval: float = 0.0

# RTT tracking for handshake
var rtt_samples: Array = []
var max_rtt_samples: int = 10

# Ping-related vars
var ping_interval: float = 60
var ping_timer: float = 0.0
var last_ping_time: int = 0

# Reference to ActionNetClient for RPC calls
var client: Node

# Reference to sequence adjuster
var sequence_adjuster: ClientSequenceAdjuster

func _process(delta: float) -> void:
	if handshake_in_progress:
		process_handshake(delta)

func _on_sequence_adjusted(new_offset: int, reason: String) -> void:
	emit_signal("sequence_adjusted", new_offset, reason)

func initialize(new_client):
	client = new_client
	sequence_adjuster = ClientSequenceAdjuster.new()
	add_child(sequence_adjuster)
	sequence_adjuster.sequence_adjusted.connect(_on_sequence_adjusted)

func initialize_sequence_tracking(initial_server_sequence: int, initial_rtt_threshold: int) -> void:
	sequence_adjuster.initialize(initial_server_sequence, initial_rtt_threshold)

func process_ping_timer() -> void:
	if handshake_in_progress:
		return
		
	ping_timer += 1
	if ping_timer >= ping_interval:
		send_ping()
		ping_timer = 0.0

func send_ping() -> void:
	if client and client.client_multiplayer.has_multiplayer_peer() and \
	   client.network.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		client.rpc("receive_ping", client.multiplayer.get_unique_id())
		last_ping_time = Time.get_ticks_msec()

func handle_pong(server_time: int) -> void:
	var current_time = Time.get_ticks_msec()
	var rtt = current_time - last_ping_time
	
	if handshake_in_progress:
		rtt_samples.append(rtt)
		print("[ClientConnectionManager] Handshake RTT sample received: ", rtt, "ms")
	else:
		sequence_adjuster.add_rtt_sample(rtt)

func can_send_handshake_ping(current_handshake_timer: float) -> bool:
	return handshake_pings_sent < handshake_pings_total and \
		   current_handshake_timer >= handshake_pings_sent * handshake_ping_interval

func send_handshake_ping() -> void:
	send_ping()
	handshake_pings_sent += 1

func set_handshake_ping_interval(interval: float) -> void:
	handshake_ping_interval = interval

# Initialize handshake
func start_handshake() -> void:
	handshake_in_progress = true
	handshake_start_time = Time.get_ticks_msec()
	handshake_timer = 0.0
	spawn_requested = false
	client_object_confirmed = false
	
	# Initialize handshake
	var handshake_ping_interval = handshake_duration / (2 * handshake_pings_total)
	set_handshake_ping_interval(handshake_ping_interval)
	handshake_in_progress = true
	handshake_pings_sent = 0
	rtt_samples.clear()
	
	print("[ClientConnectionManager] Starting handshake ritual...")

func process_handshake(delta: float) -> void:
	if not handshake_in_progress:
		return
		
	handshake_timer += delta
	
	# First half: Send pings
	if handshake_timer <= handshake_duration / 2:
		if can_send_handshake_ping(handshake_timer):
			send_handshake_ping()
			
	# At halfway point, request spawn
	if not spawn_requested and handshake_timer >= handshake_duration / 2:
		print("[ClientConnectionManager] Requesting spawn...")
		client.request_spawn_from_server()
		spawn_requested = true
	
	# Check if handshake is complete
	if handshake_timer >= handshake_duration:
		complete_handshake()

func complete_handshake() -> void:
	handshake_in_progress = false
	
	# Verify RTT samples
	if rtt_samples.is_empty():
		fail_handshake("No RTT samples received")
		return
	
	# Verify client object exists
	if not client_object_confirmed:
		fail_handshake("Client object not confirmed in world state")
		return
	
	# Initialize sequence tracking
	initialize_sequence_tracking(client.last_processed_sequence, client.clock.tick_rate)
	
	print("[ClientConnectionManager] Handshake completed successfully!")
	print("[ClientConnectionManager] Running ", sequence_adjuster.frames_ahead, " frames ahead of server")
	emit_signal("handshake_completed")

func fail_handshake(reason: String) -> void:
	print("[ClientConnectionManager] Handshake failed: ", reason)
	handshake_in_progress = false
	emit_signal("handshake_failed", reason)

func confirm_client_object() -> void:
	if handshake_in_progress and not client_object_confirmed:
		client_object_confirmed = true
		print("[ClientConnectionManager] Client object confirmed in world state")

func calculate_average_rtt() -> int:
	if rtt_samples.is_empty():
		return 0
	
	var total = 0
	for rtt in rtt_samples:
		total += rtt
	return total / rtt_samples.size()

func update_server_sequence(new_server_sequence: int) -> void:
	sequence_adjuster.update_server_sequence(new_server_sequence)

func get_client_sequence() -> int:
	return sequence_adjuster.get_client_sequence()

func update() -> void:
	sequence_adjuster.increment_sequence()
	if not handshake_in_progress:
		process_ping_timer()

func check_sequence_adjustment() -> void:
	sequence_adjuster.check_sequence_adjustment()

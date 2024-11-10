# res://addons/ActionNet/scripts/network/client/received_state_manager.gd
extends Node
class_name ReceivedStateManager

signal state_received(sequence: int)

var client: ActionNetClient
var last_processed_sequence: int = -1

# References to nodes that will contain the received state
var received_world: Node
var received_client_objects: Node
var received_physics_objects: Node

func _init(client_ref: ActionNetClient) -> void:
	client = client_ref

func setup() -> void:
	# Create a separate scene tree for received state
	received_world = client.manager.get_world_scene().instantiate()
	received_world.name = "ReceivedWorld"
	add_child(received_world)
	
	received_client_objects = Node2D.new()
	received_client_objects.name = "Received Client Objects"
	received_world.add_child(received_client_objects)

	received_physics_objects = Node2D.new()
	received_physics_objects.name = "Received Physics Objects"
	received_world.add_child(received_physics_objects)

func process_world_state(state: Dictionary) -> void:
	var sequence = state["sequence"]
	
	# Skip if we've already processed this state
	if sequence <= last_processed_sequence:
		return
	
	last_processed_sequence = sequence
	
	# Update connection manager with latest sequence
	client.connection_manager.update_server_sequence(sequence)
	
	# Process handshake if needed
	if client.connection_manager.handshake_in_progress:
		var our_id = str(client.multiplayer.get_unique_id())
		if our_id in state["client_objects"]:
			client.connection_manager.confirm_client_object()
	
	update_received_client_objects(state["client_objects"])
	update_received_physics_objects(state["physics_objects"])
	
	emit_signal("state_received", sequence)

func update_received_client_objects(state_objects: Dictionary) -> void:
	var updated_objects = []
	
	for client_id in state_objects:
		var object_state = state_objects[client_id]
		updated_objects.append(str(client_id))
		
		if not received_client_objects.has_node(str(client_id)):
			var client_object_scene = client.manager.get_client_object_scene()
			if client_object_scene:
				var client_object = client_object_scene.instantiate()
				client_object.name = str(client_id)
				received_client_objects.add_child(client_object)
		
		if received_client_objects.has_node(str(client_id)):
			var client_object = received_client_objects.get_node(str(client_id))
			client_object.set_state(object_state)
	
	# Remove disconnected objects
	for client_object in received_client_objects.get_children():
		if not client_object.name in updated_objects:
			client_object.queue_free()

func update_received_physics_objects(state_objects: Dictionary) -> void:
	var updated_objects = []
	
	for object_name in state_objects:
		var object_state = state_objects[object_name]
		var safe_name = object_name.replace("@", "_")
		updated_objects.append(safe_name)
		
		var physics_object = received_physics_objects.get_node_or_null(safe_name)
		
		if not physics_object:
			physics_object = received_world.find_child(safe_name, true, false)
			if physics_object and physics_object.get_parent() != received_physics_objects:
				physics_object.get_parent().remove_child(physics_object)
				received_physics_objects.add_child(physics_object)
		
		if not physics_object:
			var object_type = object_state["type"]
			var physics_object_scene = client.manager.get_physics_object_scene(object_type)
			if physics_object_scene:
				physics_object = physics_object_scene.instantiate()
				physics_object.name = safe_name
				received_physics_objects.add_child(physics_object)
			else:
				print("[ReceivedStateManager] Error: No physics object registered with type: ", object_type)
				continue
		
		physics_object.set_state(object_state)
	
	# Remove objects no longer in state
	for physics_object in received_physics_objects.get_children():
		if not physics_object.name in updated_objects:
			physics_object.queue_free()

func get_last_received_state() -> Dictionary:
	# This will be useful for reconciliation later
	var state = {}
	state["client_objects"] = get_client_objects_state()
	state["physics_objects"] = get_physics_objects_state()
	state["sequence"] = last_processed_sequence
	return state

func get_client_objects_state() -> Dictionary:
	var state = {}
	for object in received_client_objects.get_children():
		state[object.name] = object.get_state()
	return state

func get_physics_objects_state() -> Dictionary:
	var state = {}
	for object in received_physics_objects.get_children():
		state[object.name] = object.get_state()
	return state

func cleanup() -> void:
	if received_world:
		received_world.queue_free()
		received_world = null
		
	received_client_objects = null
	received_physics_objects = null
	last_processed_sequence = -1

# res://addons/ActionNet/scripts/network/client/received_state_manager.gd
extends Node
class_name ReceivedStateManager

signal state_received(sequence: int)

var client: ActionNetClient
var world_registry: WorldStateRegistry
var last_processed_sequence: int = -1

# References to nodes that will contain the received state
var received_world: Node
var received_client_objects: Node
var received_physics_objects: Node

func _init(client_ref: ActionNetClient) -> void:
	client = client_ref
	world_registry = WorldStateRegistry.new()
	add_child(world_registry)
	
	# Connect to debug UI visibility changes
	if ActionNetManager.debug_ui:
		ActionNetManager.debug_ui.visibility_changed_custom.connect(_on_debug_ui_visibility_changed)

func setup() -> void:
	# Create a separate scene tree for received state
	received_world = ActionNetManager.get_world_scene().instantiate()
	received_world.name = "ReceivedWorld"
	add_child(received_world)
	
	received_client_objects = Node2D.new()
	received_client_objects.name = "Received Client Objects"
	received_world.add_child(received_client_objects)

	received_physics_objects = Node2D.new()
	received_physics_objects.name = "Received Physics Objects"
	received_world.add_child(received_physics_objects)

func _on_debug_ui_visibility_changed(is_visible: bool) -> void:
	update_received_objects_visibility(is_visible)

func update_received_objects_visibility(is_visible: bool) -> void:
	var local_client_id = str(client.multiplayer.get_unique_id())
	
	if received_client_objects:
		for object in received_client_objects.get_children():
			# Only update visibility for local client object
			if object.name == local_client_id:
				if is_visible:
					object.show()
				else:
					object.hide()
			# Remote client objects always stay visible
			else:
				object.show()
	
	if received_physics_objects:
		for object in received_physics_objects.get_children():
			if is_visible:
				object.show()
			else:
				object.hide()

func process_world_state(state: Dictionary) -> void:
	# Add this state to the server-authoritative world state registry
	world_registry.add_state(state)
	
	var sequence = state["sequence"]
	#print("[ReceivedStateManager] Recieved state with sequence: ", sequence)
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
	
	# Update the server side representation of objects from this state (ghost objects)
	update_received_client_objects(state["client_objects"])
	update_received_physics_objects(state["physics_objects"])
	
	emit_signal("state_received", sequence)

func update_received_client_objects(state_objects: Dictionary) -> void:
	var updated_objects = []
	var local_client_id = str(client.multiplayer.get_unique_id())
	
	for client_id in state_objects:
		var object_state = state_objects[client_id]
		updated_objects.append(str(client_id))
		
		if not received_client_objects.has_node(str(client_id)):
			var client_object_scene = ActionNetManager.get_client_object_scene()
			if client_object_scene:
				var client_object = client_object_scene.instantiate()
				client_object.name = str(client_id)
				received_client_objects.add_child(client_object)
				# Set initial visibility based on whether it's a local or remote client
				if str(client_id) == local_client_id:
					# Local client follows debug UI visibility
					if ActionNetManager.debug_ui:
						client_object.visible = ActionNetManager.debug_ui.visible
					else:
						client_object.hide()
				else:
					# Remote clients are always visible
					client_object.show()
		
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
			var physics_object_scene = ActionNetManager.get_physics_object_scene(object_type)
			if physics_object_scene:
				physics_object = physics_object_scene.instantiate()
				physics_object.name = safe_name
				received_physics_objects.add_child(physics_object)
				# Set initial visibility based on debug UI state
				if ActionNetManager.debug_ui:
					physics_object.visible = ActionNetManager.debug_ui.visible
				else:
					physics_object.hide()
			else:
				print("[ReceivedStateManager] Error: No physics object registered with type: ", object_type)
				continue
		
		physics_object.set_state(object_state)
	
	# Remove objects no longer in state
	for physics_object in received_physics_objects.get_children():
		if not physics_object.name in updated_objects:
			physics_object.queue_free()

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

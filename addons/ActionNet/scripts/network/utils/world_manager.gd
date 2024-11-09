# res://addons/ActionNet/scripts/network/utils/world_manager.gd
extends Node
class_name WorldManager

signal state_updated(state: Dictionary)

var sequence: int = 0
var world: Node
var client_objects: Node
var physics_objects: Node
var collision_manager: CollisionManager

# Constructor that takes the world node and collision manager
func initialize(world_node: Node, collision_mgr: CollisionManager = null) -> void:
	world = world_node
	collision_manager = collision_mgr
	
	# Get or create container nodes
	client_objects = world.find_child("Client Objects", true, false)
	if not client_objects:
		client_objects = Node2D.new()
		client_objects.name = "Client Objects"
		world.add_child(client_objects)
	
	physics_objects = world.find_child("2D Physics Objects", true, false)
	if not physics_objects:
		physics_objects = Node2D.new()
		physics_objects.name = "2D Physics Objects"
		world.add_child(physics_objects)

func get_world_state() -> Dictionary:
	var state = {
		"sequence": sequence,
		"timestamp": Time.get_ticks_msec(),
		"client_objects": _get_client_objects_state(),
		"physics_objects": _get_physics_objects_state()
	}
	return state

func _get_client_objects_state() -> Dictionary:
	var client_states = {}
	for client_object in client_objects.get_children():
		client_states[client_object.name] = {
			"x": client_object.fixed_position.x,
			"y": client_object.fixed_position.y,
			"vx": client_object.fixed_velocity.x,
			"vy": client_object.fixed_velocity.y,
			"rotation": client_object.fixed_rotation,
			"angular_velocity": client_object.fixed_angular_velocity
		}
	return client_states

func _get_physics_objects_state() -> Dictionary:
	var physics_states = {}
	for physics_object in physics_objects.get_children():
		physics_states[physics_object.name] = {
			"type": physics_object.get_meta("type"),
			"x": physics_object.fixed_position.x,
			"y": physics_object.fixed_position.y,
			"vx": physics_object.fixed_velocity.x,
			"vy": physics_object.fixed_velocity.y,
			"rotation": physics_object.fixed_rotation,
			"angular_velocity": physics_object.fixed_angular_velocity
		}
	return physics_states

func update(delta: float) -> void:
	sequence += 1
	
	# Update all objects
	for client_object in client_objects.get_children():
		client_object.update(delta)
	
	for physics_object in physics_objects.get_children():
		physics_object.update(delta)
	
	# Check collisions if collision manager exists
	if collision_manager:
		collision_manager.check_and_resolve_collisions()
	
	# Emit the updated state
	emit_signal("state_updated", get_world_state())

func apply_state(state: Dictionary) -> void:
	sequence = state["sequence"]
	
	# Track which objects we've updated
	var updated_client_objects = []
	var updated_physics_objects = []
	
	# Update client objects
	for client_id in state["client_objects"]:
		var object_state = state["client_objects"][client_id]
		updated_client_objects.append(str(client_id))
		
		var client_object = client_objects.get_node_or_null(str(client_id))
		if client_object:
			client_object.set_state(object_state)
	
	# Update physics objects
	for object_name in state["physics_objects"]:
		var object_state = state["physics_objects"][object_name]
		var safe_name = object_name.replace("@", "_")
		updated_physics_objects.append(safe_name)
		
		var physics_object = physics_objects.get_node_or_null(safe_name)
		if physics_object:
			physics_object.set_state(object_state)
	
	# Remove objects that weren't in the state
	_cleanup_objects(client_objects, updated_client_objects)
	_cleanup_objects(physics_objects, updated_physics_objects)

func _cleanup_objects(container: Node, updated_objects: Array) -> void:
	for object in container.get_children():
		if not object.name in updated_objects:
			if collision_manager:
				collision_manager.unregister_object(object)
			object.queue_free()

func spawn_client_object(id: int, object_scene: PackedScene) -> void:
	if not client_objects.has_node(str(id)):
		var client_object = object_scene.instantiate()
		client_object.name = str(id)
		client_object.set_multiplayer_authority(id)
		client_objects.add_child(client_object)
		if collision_manager:
			collision_manager.register_object(client_object)

func spawn_physics_object(object_type: String, object_scene: PackedScene) -> void:
	var physics_object = object_scene.instantiate()
	physics_object.set_meta("type", object_type)
	physics_objects.add_child(physics_object)
	if collision_manager:
		collision_manager.register_object(physics_object)

func register_existing_physics_objects() -> void:
	if collision_manager:
		_register_physics_objects_recursive(world)

func _register_physics_objects_recursive(node: Node) -> void:
	if node is ActionNetPhysObject2D:
		collision_manager.register_object(node)
	for child in node.get_children():
		_register_physics_objects_recursive(child)

func get_client_object_positions() -> Dictionary:
	var positions = {}
	for client_object in client_objects.get_children():
		positions[client_object.name] = client_object.position
	return positions

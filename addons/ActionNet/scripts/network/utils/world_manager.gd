# res://addons/ActionNet/scripts/network/utils/world_manager.gd
extends Node
class_name WorldManager

signal state_updated(state: Dictionary)
signal object_spawned(object: Node, type: String)
signal prediction_missed(client_sequence: int, server_state: Dictionary, client_state: Dictionary)

var sequence: int = 0
var world: Node
var client_objects: Node
var physics_objects: Node
var collision_manager: CollisionManager
var manager: ActionNetManager
var world_registry: WorldStateRegistry

func initialize(world_node: Node, collision_mgr: CollisionManager = null, net_manager: ActionNetManager = null) -> void:
	world = world_node
	collision_manager = collision_mgr
	manager = net_manager
	
	# Initialize world registry
	world_registry = WorldStateRegistry.new()
	add_child(world_registry)
	
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

func compare_states(state1: Dictionary, state2: Dictionary, client_id: String) -> bool:
	# First check if either state has an error
	if state1.has("error") or state2.has("error"):
		return false
	
	# Compare specific client object
	var client_objects1 = state1.get("client_objects", {})
	var client_objects2 = state2.get("client_objects", {})
	
	# Only compare our specific client
	if not _compare_object_state(client_objects1.get(client_id, {}), client_objects2.get(client_id, {})):
		return false
	
	# Compare physics objects
	if not _compare_object_states(state1.get("physics_objects", {}), state2.get("physics_objects", {})):
		return false
	
	return true

func _compare_object_state(state1: Dictionary, state2: Dictionary) -> bool:
	# Direct integer comparisons
	if state1.get("x", 0) != state2.get("x", 0) or \
	   state1.get("y", 0) != state2.get("y", 0) or \
	   state1.get("vx", 0) != state2.get("vx", 0) or \
	   state1.get("vy", 0) != state2.get("vy", 0) or \
	   state1.get("rotation", 0) != state2.get("rotation", 0) or \
	   state1.get("angular_velocity", 0) != state2.get("angular_velocity", 0):
		return false

	return true

func _compare_object_states(objects1: Dictionary, objects2: Dictionary) -> bool:
	# Check if they have the same objects
	if objects1.keys() != objects2.keys():
		return false

	# Compare each object's state
	for object_id in objects1.keys():
		if not _compare_object_state(objects1[object_id], objects2[object_id]):
			return false

	return true

func check_prediction(server_state: Dictionary, client_id: int) -> void:
	var server_sequence = server_state.get("sequence", -1)
	var client_state = world_registry.get_state_for_sequence(server_sequence)
	
	if client_state.has("error"):
		print("[WorldManager] State error: ", client_state["error"])
		return
	
	# Pass the client_id as string since that's how we store it in the state
	if not compare_states(server_state, client_state, str(client_id)):
		print("[WorldManager] Prediction missed! For sequence ", server_sequence)
		emit_signal("prediction_missed", server_sequence, server_state, client_state)
		perform_reprediction(server_state, client_id)
	#else:
		#print("[WorldManager] Prediction correct!")

func perform_reprediction(server_state: Dictionary, client_id: int) -> void:
	var start_time = Time.get_ticks_msec()
	
	var server_sequence = server_state.get("sequence", -1)
	var current_sequence = sequence
	
	print("[WorldManager] Starting reprediction from sequence ", server_sequence, " up to ", current_sequence - 1)
	
	# Store our current sequence as we'll need to restore it
	var target_sequence = current_sequence - 1
	
	# Track timing for state application
	var state_update_start = Time.get_ticks_msec()
	
	# Update our world registry and set our world to match the authoritative state
	world_registry.add_state(server_state)
	set_world_state(server_state)
	
	var state_update_time = Time.get_ticks_msec() - state_update_start
	print("[WorldManager] State update took ", state_update_time, "ms")
	
	# 4. Calculate how many frames we need to repredict
	var frames_to_repredict = target_sequence - server_sequence
	
	if frames_to_repredict <= 0:
		print("[WorldManager] Error! No frames to repredict!")
		var total_time = Time.get_ticks_msec() - start_time
		print("[WorldManager] Total process took ", total_time, "ms")
		return
		
	#print("[WorldManager] Repredicting ", frames_to_repredict, " frames")
	
	# Track timing for reprediction loop
	var reprediction_start = Time.get_ticks_msec()
	
	# 5. Repredict each frame
	for i in range(frames_to_repredict):
		var frame_start = Time.get_ticks_msec()
		var repredicted_sequence = server_sequence + i + 1
		
		# Apply inputs for this sequence to our client object
		for client_object in client_objects.get_children():
			if client_object.name.to_int() == client_id:
				var input = manager.client.input_registry.get_input_for_sequence(client_id, repredicted_sequence)
			
				if input.is_empty():
					print("[WorldManager] Warning: No input found for sequence when repredicting sequence: ", repredicted_sequence, " for client ", client_id)
					continue
				#print("[WorldManager] Repredicting input for client id: ", client_id)
				client_object.apply_input(input, manager.client.clock.tick_rate) # Using standard tick rate for reprediction
				client_object.update(manager.client.clock.tick_rate)
		
		# Update physics objects and resolve collisions
		for physics_object in physics_objects.get_children():
			physics_object.update(manager.client.clock.tick_rate)
			
		# Handle collisions
		if collision_manager:
			collision_manager.check_and_resolve_collisions()
			
		# Increment sequence
		sequence += 1
		
		# Get and store the repredicted state
		var repredicted_state = get_world_state()
		world_registry.add_state(repredicted_state)
		
		var frame_time = Time.get_ticks_msec() - frame_start
		#print("[WorldManager] Repredicted sequence ", repredicted_sequence, " in ", frame_time, "ms")
	
	var reprediction_time = Time.get_ticks_msec() - reprediction_start
	#print("[WorldManager] Reprediction loop took ", reprediction_time, "ms")
	
	# Verify we're at the expected sequence
	if sequence != target_sequence:
		push_error("[WorldManager] Reprediction error: Expected to end at sequence ", 
				  target_sequence, " but ended at ", sequence)
	
	var total_time = Time.get_ticks_msec() - start_time
	
	sequence += 1 # one final sequence increment to get us where we want to be
	
	print("[WorldManager] Reprediction complete. Total process took ", total_time, "ms. Current frame for world manager is: ", sequence)

# AUTO-SPAWN SYSTEM: Called during world initialization
# Loops through ALL registered physics objects and decides which to create automatically
# 
# HOW IT WORKS:
# 1. Check every registered object type
# 2. Create a temporary instance to check its auto_spawn flag
# 3. If auto_spawn = true: Create the object in the world
# 4. If auto_spawn = false: Skip it (available for manual spawning later)
#
# This allows mixing automatic object creation (static world elements)
# with manual spawning (dynamic objects like pickups, projectiles)
func auto_spawn_physics_objects() -> void:
	if not manager:
		return
		
	for object_type in manager.registered_physics_objects.keys():
		var scene = manager.get_physics_object_scene(object_type)
		var temp_instance = scene.instantiate()
		# Check if this object type wants to be created automatically
		if temp_instance.auto_spawn:
			spawn_physics_object(object_type)  # Create it in the world
		temp_instance.queue_free()  # Clean up test instance

func spawn_client_object(id: int) -> void:
	if not manager:
		return
		
	var client_object_scene = manager.get_client_object_scene()
	if client_object_scene and not client_objects.has_node(str(id)):
		var client_object = client_object_scene.instantiate()
		client_object.name = str(id)
		client_object.set_color(Color.GREEN)
		client_object.set_z_index(1)
		client_object.set_multiplayer_authority(id)
		client_objects.add_child(client_object)
		if collision_manager:
			collision_manager.register_object(client_object)
		emit_signal("object_spawned", client_object, "client")

# PHYSICS OBJECT SPAWNING: Creates an instance of a registered object type
# This is the "factory" that actually creates objects in the world
#
# OBJECT POSITIONING: The object's position comes from its _init() method
# Objects set their position via super._init(Physics.vec2(x, y))
# ActionNet respects the position set in the object's constructor
#
# NAMING: Objects get unique names (type1, type2, etc.) for network synchronization
func spawn_physics_object(object_type: String) -> void:
	if not manager:
		return
		
	var object_scene = manager.get_physics_object_scene(object_type)
	if object_scene:
		# Create instance - position comes from object's _init() method
		var physics_object = object_scene.instantiate()
		
		# Generate unique name for network synchronization
		var count = 1
		while physics_objects.has_node(object_type + str(count)):
			count += 1
		physics_object.name = object_type + str(count)
		
		# ActionNet manages these properties automatically
		physics_object.set_color(Color.GREEN)  # Default debug color
		physics_object.set_z_index(1)
		physics_object.set_meta("type", object_type)
		
		# Add to world - object appears at its _init() position
		physics_objects.add_child(physics_object)
		if collision_manager:
			collision_manager.register_object(physics_object)
		emit_signal("object_spawned", physics_object, object_type)

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
	# Beware, this does not increment the sequence
	
	# Update all objects
	for client_object in client_objects.get_children():
		client_object.update(delta)
	
	for physics_object in physics_objects.get_children():
		physics_object.update(delta)
	
	# Check collisions if collision manager exists
	if collision_manager:
		collision_manager.check_and_resolve_collisions()
	
	# Get current state
	var current_state = get_world_state()
	
	# Store the state
	#print("[WorldManager] Adding state with sequence: ", current_state.get("sequence"))
	world_registry.add_state(current_state)
	
	# Emit the updated state
	emit_signal("state_updated", current_state)

func set_world_state(state: Dictionary) -> void:
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

# Methods for accessing stored states
func get_state_for_sequence(sequence: int) -> Dictionary:
	return world_registry.get_state_for_sequence(sequence)

func get_state_for_timestamp(timestamp: int) -> Dictionary:
	return world_registry.get_state_for_timestamp(timestamp)

func clear_stored_states() -> void:
	world_registry.clear_states()

func get_oldest_stored_state() -> Dictionary:
	return world_registry.get_oldest_state()

func get_newest_stored_state() -> Dictionary:
	return world_registry.get_newest_state()

func get_stored_state_count() -> int:
	return world_registry.get_state_count()

func cleanup() -> void:
	if world_registry:
		world_registry.cleanup()
		world_registry.queue_free()
		world_registry = null
	
	if collision_manager:
		collision_manager = null
	
	if client_objects:
		for client in client_objects.get_children():
			client.queue_free()
	
	if physics_objects:
		for object in physics_objects.get_children():
			object.queue_free()
	
	manager = null
	world = null
	client_objects = null
	physics_objects = null

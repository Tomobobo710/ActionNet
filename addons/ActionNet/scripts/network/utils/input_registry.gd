# res://addons/ActionNet/scripts/network/utils/input_registry.gd
extends Node
class_name InputRegistry

signal input_stored(client_id: int, input: Dictionary)
signal input_removed(client_id: int, sequence: int)

# Storage structure: Dictionary[client_id: int] -> Array[Dictionary]
var stored_inputs: Dictionary = {}
var max_stored_inputs: int = 300  # Default: 5 seconds at 60Hz
var is_server_owned: bool = true

func _get_debug_prefix() -> String:
	if is_server_owned:
		return "[ServerInputRegistry]"
	return "[ClientInputRegistry]"

func _init(max_inputs: int = 300):
	max_stored_inputs = max_inputs

# Store a new input for a client
func store_input(client_id: int, input: Dictionary) -> void:
	# Initialize array if it doesn't exist
	if not stored_inputs.has(client_id):
		stored_inputs[client_id] = []
	
	# Store the input with its sequence number
	stored_inputs[client_id].append({
		"sequence": input.get("sequence"),
		"input": input
	})
	
	# Keep array size manageable
	while stored_inputs[client_id].size() > max_stored_inputs:
		var removed_input = stored_inputs[client_id].pop_front()
		emit_signal("input_removed", client_id, removed_input.sequence)
	
	emit_signal("input_stored", client_id, input)

# Get input for a specific sequence number
func get_input_for_sequence(client_id: int, sequence: int) -> Dictionary:
	# Case 1: No inputs exist for this client
	if not stored_inputs.has(client_id) or stored_inputs[client_id].is_empty():
		print(_get_debug_prefix(), " No inputs found for client ", client_id)
		return {}
	
	var most_recent_before = null
	
	# Look for exact match and track most recent before
	for input_data in stored_inputs[client_id]:
		if input_data.sequence == sequence:
			#print(_get_debug_prefix(), " Found exact sequence match: ", sequence)
			return input_data.input
		elif input_data.sequence < sequence:
			most_recent_before = input_data
	
	# Case 3: We found an input before the sequence
	if most_recent_before != null:
		print(_get_debug_prefix(), " Using most recent input before sequence ", sequence, " (found: ", most_recent_before.sequence, ")")
		return most_recent_before.input
		
	# Case 4: No earlier inputs found
	print(_get_debug_prefix(), " No inputs found before sequence ", sequence)
	return {}

# Get the most recent input for a client
func get_most_recent_input(client_id: int) -> Dictionary:
	if not stored_inputs.has(client_id) or stored_inputs[client_id].is_empty():
		return {}
	return stored_inputs[client_id][-1].input

# Remove all inputs for a client
func remove_client(client_id: int) -> void:
	if stored_inputs.has(client_id):
		stored_inputs.erase(client_id)

# Get all stored inputs for a client
func get_client_inputs(client_id: int) -> Array:
	if not stored_inputs.has(client_id):
		return []
	return stored_inputs[client_id].duplicate()

# Clear all stored inputs
func clear() -> void:
	stored_inputs.clear()

# Get statistics about stored inputs
func get_stats() -> Dictionary:
	var total_inputs = 0
	for client_inputs in stored_inputs.values():
		total_inputs += client_inputs.size()
	
	return {
		"total_inputs_stored": total_inputs,
		"clients_with_inputs": stored_inputs.size(),
		"estimated_memory_kb": total_inputs * 0.1,  # Rough estimate: 100 bytes per input
		"max_stored_inputs": max_stored_inputs
	}

# Get the number of stored inputs for a specific client
func get_client_input_count(client_id: int) -> int:
	if not stored_inputs.has(client_id):
		return 0
	return stored_inputs[client_id].size()

# Check if we have any inputs stored for a client
func has_client_inputs(client_id: int) -> bool:
	return stored_inputs.has(client_id) and not stored_inputs[client_id].is_empty()

# res://addons/ActionNet/scripts/network/utils/input_registry.gd
extends Node
class_name InputRegistry

signal input_stored(client_id: int, input: Dictionary)
signal input_removed(client_id: int, sequence: int)

# Storage structure: Dictionary[client_id: int] -> Array[Dictionary]
var stored_inputs: Dictionary = {}
var max_stored_inputs: int = 300  # Default: 5 seconds at 60Hz

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
	if not stored_inputs.has(client_id) or stored_inputs[client_id].is_empty():
		return {}
	
	# Try to find input matching the current sequence
	for input_data in stored_inputs[client_id]:
		if input_data.sequence == sequence:
			return input_data.input
	
	# If no matching sequence found, use most recent input
	return stored_inputs[client_id][-1].input

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

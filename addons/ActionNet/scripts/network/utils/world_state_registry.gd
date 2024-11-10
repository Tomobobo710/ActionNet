# res://addons/ActionNet/scripts/network/utils/world_state_registry.gd
extends Node
class_name WorldStateRegistry

# Store the last 2 seconds of states (120 states at 60fps)
const MAX_STATES = 120

var world_states: Array[Dictionary] = []

func add_state(state: Dictionary) -> void:
	# Add the new state
	world_states.append(state.duplicate(true))
	
	# Remove oldest state if we're over the limit
	if world_states.size() > MAX_STATES:
		world_states.pop_front()

func get_state_for_sequence(sequence: int) -> Dictionary:
	for state in world_states:
		if state["sequence"] == sequence:
			return state
	
	# Return empty dictionary with error flag if state not found
	return {"error": "State not found for sequence " + str(sequence)}

func get_state_for_timestamp(timestamp: int) -> Dictionary:
	for state in world_states:
		if state["timestamp"] == timestamp:
			return state
	
	# Return empty dictionary with error flag if state not found
	return {"error": "State not found for timestamp " + str(timestamp)}

func clear_states() -> void:
	world_states.clear()

func get_oldest_state() -> Dictionary:
	if world_states.is_empty():
		return {"error": "No states stored"}
	return world_states[0]

func get_newest_state() -> Dictionary:
	if world_states.is_empty():
		return {"error": "No states stored"}
	return world_states[-1]

func get_state_count() -> int:
	return world_states.size()

func cleanup() -> void:
	clear_states()
	world_states = []

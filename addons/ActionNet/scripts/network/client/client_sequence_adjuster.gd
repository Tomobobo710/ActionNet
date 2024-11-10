# res://addons/ActionNet/scripts/network/client/client_sequence_adjuster.gd
extends Node
class_name ClientSequenceAdjuster

signal sequence_adjusted(new_offset: int, reason: String)

# Adjustment parameters
var rtt_threshold_ms: int = 16  # RTT change threshold to trigger adjustment
var adjustment_cooldown: float = 1.0  # Minimum time between adjustments
var last_adjustment_time: float = 0.0
var min_frames_ahead: int = 10
var max_frames_ahead: int = 60
var sequence_adjustment_enabled: bool = true

# Sequence tracking
var client_sequence: int = 0
var server_sequence_estimate: int = 0
var frames_ahead: int = 0

# RTT tracking
var current_rtt: int = 0
var rtt_window: Array = []  # Recent RTT values for trend analysis
var rtt_window_size: int = 30  # How many RTT samples to keep for trend analysis
var baseline_rtt: int = 0  # RTT value when initialized

func initialize(initial_server_sequence: int, initial_rtt_threshold: int) -> void:
	rtt_threshold_ms = initial_rtt_threshold
	frames_ahead = calculate_initial_frames_ahead()
	server_sequence_estimate = initial_server_sequence
	client_sequence = server_sequence_estimate + frames_ahead
	sequence_adjustment_enabled = true

func calculate_initial_frames_ahead() -> int:
	var one_way_time = baseline_rtt / 2.0
	var frames_needed = int(ceil(one_way_time / rtt_threshold_ms))
	return clamp(frames_needed, min_frames_ahead, max_frames_ahead)

func update_server_sequence(new_server_sequence: int) -> void:
	server_sequence_estimate = new_server_sequence

func get_client_sequence() -> int:
	return client_sequence

func increment_sequence() -> void:
	client_sequence += 1

func add_rtt_sample(rtt: int) -> void:
	current_rtt = rtt
	
	# Update RTT window
	rtt_window.append(rtt)
	if rtt_window.size() > rtt_window_size:
		rtt_window.pop_front()

func check_sequence_adjustment() -> void:
	if not sequence_adjustment_enabled:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_adjustment_time < adjustment_cooldown:
		return
	
	# Check if we've fallen behind
	var minimum_sequence = server_sequence_estimate + min_frames_ahead
	if client_sequence < minimum_sequence:
		adjust_sequence(minimum_sequence, "Fallen behind server")
		return
	
	# Calculate required frames based on current RTT
	var new_frames_ahead = calculate_required_frames()
	if new_frames_ahead != frames_ahead:
		var new_sequence = server_sequence_estimate + new_frames_ahead
		adjust_sequence(new_sequence, "RTT frame requirement changed")

func calculate_required_frames() -> int:
	var avg_rtt = calculate_average_rtt()
	var one_way_time = avg_rtt / 2.0
	
	var frames_needed = int(ceil(one_way_time / rtt_threshold_ms))
	return clamp(frames_needed, min_frames_ahead, max_frames_ahead)

func calculate_average_rtt() -> int:
	if rtt_window.is_empty():
		return current_rtt
	
	var total = 0
	for rtt in rtt_window:
		total += rtt
	return total / rtt_window.size()

func adjust_sequence(new_sequence: int, reason: String) -> void:
	if new_sequence == client_sequence:
		return
	
	var old_sequence = client_sequence
	var old_frames_ahead = frames_ahead
	
	client_sequence = new_sequence
	frames_ahead = new_sequence - server_sequence_estimate
	last_adjustment_time = Time.get_ticks_msec() / 1000.0
	
	print("[ClientSequenceAdjuster] Sequence adjusted: ", old_sequence, " -> ", client_sequence)
	print("[ClientSequenceAdjuster] Frames ahead: ", old_frames_ahead, " -> ", frames_ahead)
	print("[ClientSequenceAdjuster] Reason: ", reason)
	
	emit_signal("sequence_adjusted", frames_ahead, reason)

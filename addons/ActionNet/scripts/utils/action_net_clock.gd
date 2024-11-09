# res://addons/ActionNet/scripts/utils/action_net_clock.gd
extends Node

class_name ActionNetClock

signal tick(sequence: int)

var tick_rate: float = 16.0
var clock_sequence: int = 0 
var clock_timer: Timer

func _ready() -> void:
	# Create the timer for the clock
	clock_timer = Timer.new()
	clock_timer.one_shot = false
	clock_timer.wait_time = tick_rate / 1000.0  # Convert ms to seconds
	clock_timer.connect("timeout", Callable(self, "on_tick"))
	add_child(clock_timer)
	clock_timer.start()

func on_tick() -> void:
	clock_sequence += 1
	emit_signal("tick", clock_sequence)

# API to adjust the tick rate
func set_tick_rate(new_rate: float) -> void:
	tick_rate = new_rate
	clock_timer.wait_time = tick_rate / 1000.0

func get_sequence() -> int:
	return clock_sequence

func reset_sequence() -> void:
	clock_sequence = 0

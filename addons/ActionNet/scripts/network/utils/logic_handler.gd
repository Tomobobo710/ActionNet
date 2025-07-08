extends Node

class_name LogicHandler

# FRAMEWORK: Base class for custom game logic injection
# 
# PURPOSE: Provides a standardized way for developers to insert custom game logic
# into ActionNet's networking cycle at the correct timing
#
# INHERITANCE PATTERN:
# 1. Create server logic class: extends LogicHandler (manages authoritative game state)
# 2. Create client logic class: extends LogicHandler (manages UI/presentation)
# 3. Override update() method in both to implement game-specific behavior
# 4. Register with ActionNetManager.set_server_logic_handler() / set_client_logic_handler()
#
# TIMING GUARANTEES:
# - Server update(): Called after physics update, before sending state to clients
# - Client update(): Called after receiving/processing network data, before rendering

func _ready():
	pass # Standard Godot lifecycle

func _process(delta):
	pass # Standard Godot lifecycle

# OVERRIDE THIS: Custom game logic goes here
# Called automatically by ActionNet at the correct point in the networking cycle
func update():
	pass # Implement in subclass

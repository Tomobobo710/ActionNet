# res://addons/ActionNetDemo/scripts/server_logic.gd
extends LogicHandler
class_name CustomServerLogicHandler

var main: Node
var server: Node

# Overrides parent
func update():
	print("Custom server logic handler update method")
	# Accessing properties of manager
	print("Manager debug UI:", ActionNetManager.debug_ui)
	# Accessing properties of main
	if main:
		print("Main current state:", main.current_state)
	# Accessing properties of server
	if server:
		print("Server name:", server.name)

# Overrides parent
func _process(delta):
	#print("custom process")
	pass

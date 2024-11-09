@tool
extends EditorPlugin

const AUTOLOAD_NAME = "ActionNetManager"
const AUTOLOAD_PATH = "res://addons/ActionNet/scripts/network/action_net_manager.gd"


func _enter_tree():
	print("Action-Net addon loaded!")
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	print("Autoload added: ", AUTOLOAD_NAME)

func _exit_tree():
	print("Action-Net addon unloaded!")
	remove_autoload_singleton(AUTOLOAD_NAME)
	print("Autoload removed: ", AUTOLOAD_NAME)

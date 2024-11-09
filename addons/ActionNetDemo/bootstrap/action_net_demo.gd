@tool
extends EditorPlugin

const AUTOLOAD_NAME = "ActionNetDemo"
const AUTOLOAD_PATH = "res://addons/ActionNetDemo/scripts/main.gd"

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)

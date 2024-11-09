# res://addons/ActionNet/scripts/network/client/input_definition.gd
extends RefCounted
class_name InputDefinition

var action_name: String
var input_type: String  # Can be "pressed", "just_pressed", "just_released"
var input_source: String  # Can be "godot_action" or "key"
var godot_action: String
var key_code: int

func _init(action_name: String, input_type: String, input_source: String, value: Variant):
	self.action_name = action_name
	self.input_type = input_type
	self.input_source = input_source
	if input_source == "godot_action":
		self.godot_action = value
	elif input_source == "key":
		self.key_code = value

func get_input_value() -> bool:
	match input_source:
		"godot_action":
			match input_type:
				"pressed":
					return Input.is_action_pressed(godot_action)
				"just_pressed":
					return Input.is_action_just_pressed(godot_action)
				"just_released":
					return Input.is_action_just_released(godot_action)
		"key":
			match input_type:
				"pressed":
					return Input.is_key_pressed(key_code)
				"just_pressed":
					return Input.is_key_pressed(key_code) and not Input.is_key_pressed(key_code)
				"just_released":
					return not Input.is_key_pressed(key_code) and Input.is_key_pressed(key_code)
	return false

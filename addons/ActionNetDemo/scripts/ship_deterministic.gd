# res://addons/ActionNetDemo/scripts/ball_deterministic.gd
extends ActionNetPhysObject2D

class_name Ship

const THRUST_FORCE = 1000 * Physics.SCALE
const ROTATION_SPEED = 5

func _init():
	super._init()
	ANGULAR_MASS = 0
	sprite_texture = load("res://ship_texture.png")

func apply_input(input: Dictionary):
	# Default values for input actions
	var rotate_right: bool = false
	var rotate_left: bool = false
	var move_forward: bool = false
	var move_backward: bool = false
	
	# Extract input values, defaulting to false if keys are missing
	if input.has("rotate_right"):
		rotate_right = input["rotate_right"]
	if input.has("rotate_left"):
		rotate_left = input["rotate_left"]
	if input.has("move_forward"):
		move_forward = input["move_forward"]
	if input.has("move_backward"):
		move_backward = input["move_backward"]
	
	# Apply rotation
	if rotate_right:
		fixed_rotation = (fixed_rotation + ROTATION_SPEED) % 360
	elif rotate_left:
		fixed_rotation = (fixed_rotation - ROTATION_SPEED) % 360
	# Ensure fixed_rotation is positive
	if fixed_rotation < 0:
		fixed_rotation += 360
	
	# Apply thrust
	var thrust = 0
	if move_forward:
		thrust = 1
	elif move_backward:
		thrust = -1
	if thrust != 0:
		var thrust_direction = Physics.rotate_vector(Physics.vec2(1, 0), fixed_rotation)
		var thrust_force = Vector2i(
			thrust_direction.x * thrust * THRUST_FORCE,
			thrust_direction.y * thrust * THRUST_FORCE
		)
		fixed_velocity = Physics.apply_force(fixed_velocity, thrust_force, MASS, 16)

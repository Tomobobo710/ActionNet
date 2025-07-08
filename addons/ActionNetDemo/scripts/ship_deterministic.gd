# res://addons/ActionNetDemo/scripts/ship_deterministic.gd
extends ActionNetPhysObject2D

class_name Ship

const THRUST_FORCE = 1000 * Physics.SCALE
const ROTATION_SPEED = 5
const KICK_FORCE = 1200 * Physics.SCALE
const KICK_RANGE = 40 * Physics.SCALE

# Cooldowns
var kick_cooldown: float = 0.0
var max_kick_cooldown: float = 0.3

func _init():
	super._init()
	ANGULAR_MASS = 0
	sprite_texture = load("res://addons/ActionNetDemo/sprites/ship_texture.png")

func apply_input(input: Dictionary, tick_rate: int):
	# Update cooldowns
	update_cooldowns(tick_rate)
	
	# Default values for input actions
	var rotate_right: bool = false
	var rotate_left: bool = false
	var move_forward: bool = false
	var move_backward: bool = false
	var shoot: bool = false
	
	# Extract input values, defaulting to false if keys are missing
	if input.has("rotate_right"):
		rotate_right = input["rotate_right"]
	if input.has("rotate_left"):
		rotate_left = input["rotate_left"]
	if input.has("move_forward"):
		move_forward = input["move_forward"]
	if input.has("move_backward"):
		move_backward = input["move_backward"]
	if input.has("shoot"):
		shoot = input["shoot"]
	
	# Apply rotation (A/D keys)
	if rotate_right:
		fixed_rotation = (fixed_rotation + ROTATION_SPEED) % 360
	elif rotate_left:
		fixed_rotation = (fixed_rotation - ROTATION_SPEED) % 360
	# Ensure fixed_rotation is positive
	if fixed_rotation < 0:
		fixed_rotation += 360
	
	# Apply thrust (W/S keys)
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
		fixed_velocity = Physics.apply_force(fixed_velocity, thrust_force, MASS, tick_rate)
	
	# Handle kicking/shooting
	if shoot and kick_cooldown <= 0.0:
		perform_kick()
		kick_cooldown = max_kick_cooldown

func update_cooldowns(tick_rate: int):
	var delta = 1.0 / tick_rate
	if kick_cooldown > 0:
		kick_cooldown -= delta

func perform_kick():
	# Find the ball and kick it if in range
	var ball = find_nearest_ball()
	if ball:
		# Kick in the direction the player is facing
		var kick_direction = Physics.rotate_vector(Physics.vec2(1, 0), fixed_rotation)
		var kick_force = Vector2i(
			kick_direction.x * KICK_FORCE,
			kick_direction.y * KICK_FORCE
		)
		ball.fixed_velocity = Physics.apply_force(ball.fixed_velocity, kick_force, ball.MASS, 60)
		print("[SoccerPlayer] Player ", name, " kicked the ball!")

func find_nearest_ball():
	# Try to find the ball through the world manager
	var world_manager = null
	
	# Check if we're on server or client
	if ActionNetManager.server and ActionNetManager.server.world_manager:
		world_manager = ActionNetManager.server.world_manager
	elif ActionNetManager.client and ActionNetManager.client.world_manager:
		world_manager = ActionNetManager.client.world_manager
	
	if not world_manager or not world_manager.physics_objects:
		return null
	
	# Find ball in physics objects
	for child in world_manager.physics_objects.get_children():
		if "ball" in child.name.to_lower():
			return child
	
	return null

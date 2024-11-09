# res://addons/ActionNetDemo/scripts/ball_deterministic.gd
extends ActionNetPhysObject2D

class_name Ball

const BALL_MASS = 4000
const BALL_RESTITUTION = 10

func _init():
	super._init()
	sprite_texture = load("res://ball_texture.png")
	MASS = BALL_MASS
	RESTITUTION = BALL_RESTITUTION
	auto_spawn = true
	shape_type = Physics.ShapeType.CIRCLE

func update(delta: int):
	if not Physics.is_static(MASS):
		# Apply drag
		fixed_velocity = fixed_velocity * 990 / 1000

		# Update position
		var new_position = Physics.update_position(fixed_position, fixed_velocity * delta / Physics.SCALE, shape_type, shape_data)

		# Check if the ball hit a boundary and bounce
		var radius = shape_data["radius"]
		if new_position.x <= radius or new_position.x >= Physics.WORLD_WIDTH - radius:
			fixed_velocity.x = -fixed_velocity.x
			new_position.x = clamp(new_position.x, radius, Physics.WORLD_WIDTH - radius)

		if new_position.y <= radius or new_position.y >= Physics.WORLD_HEIGHT - radius:
			fixed_velocity.y = -fixed_velocity.y
			new_position.y = clamp(new_position.y, radius, Physics.WORLD_HEIGHT - radius)

		fixed_position = new_position

		# Update rotation (if we want to keep this from the base class)
		if ANGULAR_MASS > 0:
			fixed_rotation = (fixed_rotation + fixed_angular_velocity * delta / Physics.SCALE) % 360
			# Apply angular drag
			fixed_angular_velocity = fixed_angular_velocity * (Physics.SCALE - ANGULAR_DRAG) / Physics.SCALE

	update_visual()

func _ready():
	super._ready()
	update_shape_data()  # This will set the correct radius based on the BASE_SIZE and scale

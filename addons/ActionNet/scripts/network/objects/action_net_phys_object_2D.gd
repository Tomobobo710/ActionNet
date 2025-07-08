extends Node2D

class_name ActionNetPhysObject2D

var id: int = 0
var fixed_position: Vector2i
var fixed_velocity: Vector2i
var fixed_rotation: int = 0
var fixed_angular_velocity: int = 0

var collision_layer: int = 1
var collision_mask: int = 1

var sprite: Sprite2D
var sprite_texture: Texture2D
var tint_color: Color = Color.WHITE

var BASE_SIZE: int = 512 * Physics.SCALE
var MASS: int = 1000
var ANGULAR_MASS: int = 1000
var RESTITUTION: int = 1
var MAX_ANGULAR_VELOCITY: int = 250
var ANGULAR_DRAG: int = 50

var auto_spawn: bool = false

var shape_type: Physics.ShapeType = Physics.ShapeType.CIRCLE
var shape_data: Dictionary = {"radius": BASE_SIZE / 2}

# FRAMEWORK: Object positioning system
# Objects MUST set their position during _init() via this constructor
# The position passed here becomes the object's location in the world
# Default (640, 360) = screen center for 1280x720 resolution
func _init(new_fixed_position: Vector2i = Physics.vec2(640, 360), new_fixed_velocity: Vector2i = Physics.vec2(0, 0)):
	fixed_position = new_fixed_position  # This is the object's world position
	fixed_velocity = new_fixed_velocity

func _ready():
	if sprite_texture:
		sprite = Sprite2D.new()
		sprite.texture = sprite_texture
		sprite.modulate = tint_color
		add_child(sprite)
		update_scale(Vector2(0.1, 0.1))

func show() -> void:
	visible = true
	if sprite:
		sprite.visible = true

func hide() -> void:
	visible = false
	if sprite:
		sprite.visible = false

func set_color(color: Color) -> void:
	tint_color = color
	if sprite:
		sprite.modulate = tint_color

func set_z_index(z: int) -> void:
	z_index = z
	if sprite:
		sprite.z_index = z

func set_y_sort_enabled(enabled: bool) -> void:
	y_sort_enabled = enabled
	if sprite:
		sprite.y_sort_enabled = enabled

func update_scale(new_scale: Vector2):
	scale = new_scale
	if sprite:
		sprite.scale = Vector2.ONE
	update_shape_data()

func update_shape_data():
	match shape_type:
		Physics.ShapeType.CIRCLE:
			shape_data["radius"] = BASE_SIZE * scale.x / 2
		Physics.ShapeType.RECTANGLE:
			shape_data["width"] = BASE_SIZE * scale.x
			shape_data["height"] = BASE_SIZE * scale.y

func set_state(state: Dictionary):
	fixed_position = Vector2i(state["x"], state["y"])
	fixed_velocity = Vector2i(state["vx"], state["vy"])
	fixed_rotation = state.get("rotation", 0)
	fixed_angular_velocity = state.get("angular_velocity", 0)
	update_visual()

func update(delta: int):
	if not Physics.is_static(MASS):
		# Apply drag (can be overridden in child classes)
		fixed_velocity = fixed_velocity * 980 / Physics.SCALE
		
		# Update position
		var new_position = Physics.update_position(fixed_position, fixed_velocity * delta / Physics.SCALE, shape_type, shape_data)
		
		# Check if the object hit a boundary and adjust velocity if needed
		match shape_type:
			Physics.ShapeType.CIRCLE:
				var radius = shape_data["radius"]
				if new_position.x <= radius or new_position.x >= Physics.WORLD_WIDTH - radius:
					fixed_velocity.x = -fixed_velocity.x * RESTITUTION / Physics.SCALE
					new_position.x = clamp(new_position.x, radius, Physics.WORLD_WIDTH - radius)
				
				if new_position.y <= radius or new_position.y >= Physics.WORLD_HEIGHT - radius:
					fixed_velocity.y = -fixed_velocity.y * RESTITUTION / Physics.SCALE
					new_position.y = clamp(new_position.y, radius, Physics.WORLD_HEIGHT - radius)
			
			Physics.ShapeType.RECTANGLE:
				var half_width = shape_data["width"] / 2
				var half_height = shape_data["height"] / 2
				if new_position.x <= half_width or new_position.x >= Physics.WORLD_WIDTH - half_width:
					fixed_velocity.x = -fixed_velocity.x * RESTITUTION / Physics.SCALE
					new_position.x = clamp(new_position.x, half_width, Physics.WORLD_WIDTH - half_width)
				
				if new_position.y <= half_height or new_position.y >= Physics.WORLD_HEIGHT - half_height:
					fixed_velocity.y = -fixed_velocity.y * RESTITUTION / Physics.SCALE
					new_position.y = clamp(new_position.y, half_height, Physics.WORLD_HEIGHT - half_height)
		
		fixed_position = new_position

		# Update rotation
		if ANGULAR_MASS > 0:
			fixed_rotation = (fixed_rotation + fixed_angular_velocity * delta / Physics.SCALE) % 360
			# Apply angular drag
			fixed_angular_velocity = fixed_angular_velocity * (Physics.SCALE - ANGULAR_DRAG) / Physics.SCALE

	update_visual()

func update_visual():
	position = Vector2(fixed_position.x, fixed_position.y) / Physics.SCALE
	rotation = PhysicsTables.RADIAN_TABLE[fixed_rotation]

func get_velocity() -> Vector2:
	return fixed_velocity

func set_collision_layer(layer: int):
	collision_layer = layer
	collision_mask = layer

func apply_input(_input: Dictionary, tick_rate: int):
	# To be implemented in child classes if needed
	pass

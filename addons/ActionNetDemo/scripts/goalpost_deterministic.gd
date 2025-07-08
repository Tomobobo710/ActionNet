# res://addons/ActionNetDemo/scripts/goalpost_deterministic.gd
extends ActionNetPhysObject2D

class_name GoalPost

const GOALPOST_MASS = 0  # Static objects
const GOALPOST_RESTITUTION = 10

func _init(goal_position: Vector2i = Physics.vec2(640, 360)):
	super._init(goal_position)
	sprite_texture = load("res://rectangle_texture.png")  # Temporarily visible
	MASS = GOALPOST_MASS
	RESTITUTION = GOALPOST_RESTITUTION
	auto_spawn = false  # Don't auto-spawn - we'll create them manually
	shape_type = Physics.ShapeType.RECTANGLE
	# Initial shape_data - will be updated by scaling
	shape_data = {
		"width": BASE_SIZE,
		"height": BASE_SIZE
	}

func _ready():
	# Temporarily visible for debugging
	if sprite_texture:
		sprite = Sprite2D.new()
		sprite.texture = sprite_texture
		add_child(sprite)
	update_shape_data()
	update_visual()

# Helper function to set size in pixels
func set_pixel_size(width_pixels: int, height_pixels: int):
	# Convert pixel size to scale factors
	var scale_x = float(width_pixels) / 512.0
	var scale_y = float(height_pixels) / 512.0
	update_scale(Vector2(scale_x, scale_y))

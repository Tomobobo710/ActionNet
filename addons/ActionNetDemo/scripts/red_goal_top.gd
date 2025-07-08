extends ActionNetPhysObject2D
class_name RedGoalTop
func _init():
	super._init(Physics.vec2(30, 285))
	# No sprite_texture - invisible physics-only collision
	MASS = 0
	RESTITUTION = 10
	auto_spawn = true
	shape_type = Physics.ShapeType.RECTANGLE
func _ready():
	# Invisible physics-only object
	update_scale(Vector2(60.0/512, 10.0/512))
	update_visual()

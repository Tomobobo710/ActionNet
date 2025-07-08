# DEMO: Goal Post Physics Object Pattern
# 
# PURPOSE: Invisible collision box that matches visual ColorRect goal post
# 
# POSITIONING NOTE: ActionNet uses CENTER-POINT positioning
# - Physics.vec2(5, 360) = object CENTER at (5, 360)
# - This matches Sprite2D default anchoring (centered)
# - ColorRect uses TOP-LEFT positioning, so requires offset calculation
# - If using Sprite2D: physics position = sprite position (no math needed!)
# 
# Current setup: Physics center (5, 360) matches ColorRect top-left (0, 285) + size (10, 150)
# AUTO-SPAWN: true = ActionNet creates this automatically during world init
# VISIBILITY: No sprite_texture = invisible (collision only)
extends ActionNetPhysObject2D
class_name RedGoalBack

func _init():
	# Position MUST be set in super._init() for ActionNet to respect it
	super._init(Physics.vec2(5, 360))  # Left goal back wall center point
	# No sprite_texture - invisible physics-only collision
	MASS = 0                           # Static object (immovable)
	RESTITUTION = 10                   # Bounce factor
	auto_spawn = true                  # ActionNet creates automatically
	shape_type = Physics.ShapeType.RECTANGLE
	shape_data = {"width": 10 * 1000, "height": 150 * 1000}
func _ready():
	# Invisible physics-only object
	update_scale(Vector2(10.0/512, 150.0/512))
	update_visual()

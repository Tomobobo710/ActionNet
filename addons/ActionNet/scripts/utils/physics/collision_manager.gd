# res://addons/ActionNet/scripts/utils/physics/collision_manager.gd
extends Node

class_name CollisionManager

var collidable_objects = []

func register_object(obj):
	collidable_objects.append(obj)

func unregister_object(obj):
	collidable_objects.erase(obj)

func get_registered_objects() -> Array:
	return collidable_objects

func check_and_resolve_collisions():
	for i in range(collidable_objects.size()):
		for j in range(i + 1, collidable_objects.size()):
			var obj1 = collidable_objects[i]
			var obj2 = collidable_objects[j]
			
			if Physics.should_collide(obj1.collision_layer, obj1.collision_mask, obj2.collision_layer, obj2.collision_mask) and Physics.check_collision(obj1.fixed_position, obj1.shape_type, obj1.shape_data, obj2.fixed_position, obj2.shape_type, obj2.shape_data):
				var result = Physics.resolve_collision(
					obj1.fixed_position, obj1.fixed_velocity, obj1.MASS, obj1.shape_type, obj1.shape_data, obj1.RESTITUTION,
					obj2.fixed_position, obj2.fixed_velocity, obj2.MASS, obj2.shape_type, obj2.shape_data, obj2.RESTITUTION,
					obj1.fixed_angular_velocity, obj1.ANGULAR_MASS, obj2.fixed_angular_velocity, obj2.ANGULAR_MASS
				)
				
				# Update velocities and positions only for non-static objects
				if not Physics.is_static(obj1.MASS):
					obj1.fixed_velocity = result["vel1"]
					obj1.fixed_position = result["pos1"]
					if obj1.ANGULAR_MASS > 0:
						obj1.fixed_angular_velocity = result["angular_vel1"]
				
				if not Physics.is_static(obj2.MASS):
					obj2.fixed_velocity = result["vel2"]
					obj2.fixed_position = result["pos2"]
					if obj2.ANGULAR_MASS > 0:
						obj2.fixed_angular_velocity = result["angular_vel2"]

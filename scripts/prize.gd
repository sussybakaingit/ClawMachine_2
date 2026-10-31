class_name Prize
extends RigidBody3D

@export var toy_id: String = "toy"
@export var toy_name: String = "Arcade Toy"
@export var score_value: int = 100
@export var rarity_color: Color = Color.WHITE

var is_grabbed: bool = false
var is_delivered: bool = false
var grab_offset: Vector3 = Vector3.ZERO

func _ready():
	# Continuous collision detection and sleep stabilization
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	
	# Moderate physics material
	var phys_mat = PhysicsMaterial.new()
	phys_mat.friction = 0.8
	phys_mat.bounce = 0.15
	physics_material_override = phys_mat

func set_grabbed(grabbed: bool):
	is_grabbed = grabbed
	if grabbed:
		freeze = true
		collision_layer = 0 # Temporarily disable collisions so claw doesn't push it violently
	else:
		freeze = false
		collision_layer = 1
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


class_name PrizeManager
extends Node3D

@export var toy_scenes: Array[PackedScene] = [
	preload("res://scenes/toy_woody.tscn"),
	preload("res://scenes/toy_car.tscn"),
	preload("res://scenes/toy_pilot.tscn"),
	preload("res://scenes/toy_chest.tscn"),
	preload("res://scenes/toy_bear.tscn"),
	preload("res://scenes/toy_pokeball.tscn")
]

# Spawn Bounds for prize bed
# Avoid prize drop hole at front-left (X: -0.36 to -0.18, Z: 0.18 to 0.36)
const POOL_MIN_X: float = -0.32
const POOL_MAX_X: float = 0.32
const POOL_MIN_Z: float = -0.30
const POOL_MAX_Z: float = 0.32
const SPAWN_Y: float = 0.88

# Number of total toys to spawn to make a rich, full, colorful arcade prize pool
@export var total_toy_count: int = 48

var spawned_toys: Array[Node] = []

func _ready():
	spawn_prize_pool()

func spawn_prize_pool():
	clear_prize_pool()
	
	for i in range(total_toy_count):
		var scene_idx = i % toy_scenes.size()
		var p_scene = toy_scenes[scene_idx]
		var toy = p_scene.instantiate()
		
		# Randomized positions avoiding delivery hole at front-left
		var px = randf_range(POOL_MIN_X, POOL_MAX_X)
		var pz = randf_range(POOL_MIN_Z, POOL_MAX_Z)
		
		# If inside or near front-left delivery chute zone (X < -0.12 and Z > 0.12), push cleanly into prize bed
		if px < -0.12 and pz > 0.12:
			px = randf_range(0.02, POOL_MAX_X)
			
		var py = SPAWN_Y + (float(i % 16) * 0.02) # Multilayer stacking across the bed
		toy.position = Vector3(px, py, pz)
		toy.rotation_degrees = Vector3(
			randf_range(-20.0, 20.0),
			randf_range(0.0, 360.0),
			randf_range(-20.0, 20.0)
		)
		
		add_child(toy)
		spawned_toys.append(toy)

func clear_prize_pool():
	for t in spawned_toys:
		if is_instance_valid(t):
			t.queue_free()
	spawned_toys.clear()

func reset_pool():
	spawn_prize_pool()


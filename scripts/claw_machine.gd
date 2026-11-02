extends Node3D

func _enter_tree():
	_setup_materials()

func _ready():
	_setup_materials()

func _setup_materials():
	var mesh_inst = get_node_or_null("MachineModel/1_001") as MeshInstance3D
	if not mesh_inst:
		return
		
	# Surface 1: Crystal-clear glass (replaces the milky white frosted opaque glass)
	var glass = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.albedo_color = Color(0.88, 0.95, 1.0, 0.03) # Crystal clear, 3% opacity
	glass.roughness = 0.04
	glass.metallic = 0.1
	mesh_inst.set_surface_override_material(1, glass)
	
	# Surface 2: Canopy interior light fixture (replaces 15.4 blinding white emission)
	var canopy_light = StandardMaterial3D.new()
	canopy_light.albedo_color = Color(0.72, 0.70, 0.65, 1.0)
	canopy_light.emission_enabled = true
	canopy_light.emission = Color(1.0, 0.95, 0.85, 1.0)
	canopy_light.emission_energy_multiplier = 0.15 # Soft, gentle glow
	mesh_inst.set_surface_override_material(2, canopy_light)
	
	# Surface 3: Pillar neon trims (replaces 16.1 white emission with sleek cyan neon)
	var neon = StandardMaterial3D.new()
	neon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	neon.albedo_color = Color(0.1, 0.85, 1.0, 0.8)
	neon.emission_enabled = true
	neon.emission = Color(0.1, 0.85, 1.0, 1.0)
	neon.emission_energy_multiplier = 0.8
	mesh_inst.set_surface_override_material(3, neon)

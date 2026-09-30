extends Node3D
## Approved solid SWIFT effects; presentation only, no light or combat mutation.
const FLASH = preload("res://assets/effects/sniper/flash.glb")
const AIM_LINE = preload("res://assets/effects/sniper/aim_line.glb")
const AIM_ENERGY = preload("res://effects/sniper_aim_energy.gdshader")
const LENS_ORIGIN := Vector3(0,.420,.196) # Blender barrel-local (0,-.196,.420).
const FLASH_SECONDS := .105
const FLASH_SCALE := 2.4
const LINE_RADIUS := .010
const HALO_RADIUS := .060
const POINT_RADIUS := .080
static var _materials_ready := false
var flash: Node3D
var line: Node3D
var barrel: Node3D
var line_start := Vector3.ZERO
var line_end := Vector3.ZERO
var line_materials: Array[Dictionary] = []
var aim_ratio := -1.0
var aim_time := -INF
var aim_layers: Array[Node3D] = []
var aim_materials: Array[ShaderMaterial] = []

func configure(barrel_node: Node3D, muzzle: Node3D) -> void:
	barrel=barrel_node
	flash=FLASH.instantiate();flash.name="SWIFT_SolidFlash";muzzle.add_child(flash)
	line=AIM_LINE.instantiate();line.name="SWIFT_LensAimLine";add_child(line)
	for model in [flash,line]:
		model.set_meta("exclude_selection_mask",true)
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			mesh.set_meta("exclude_selection_mask",true)
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				if material == null: continue
				if model == line:
					var shader := _energy_material(0,LINE_RADIUS)
					mesh.set_surface_override_material(surface,shader)
					line_materials.append({"material":shader,"source":material,"albedo":material.albedo_color,"energy":material.emission_energy_multiplier})
				elif not _materials_ready:
					material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
					material.no_depth_test=false
	_materials_ready=true
	aim_layers.append(line)
	for index in range(3):
		var glow:Node3D=AIM_LINE.instantiate()
		glow.name=["SWIFT_SoftEnvelope","SWIFT_LensGlow","SWIFT_SurfaceGlow"][index]
		add_child(glow);aim_layers.append(glow)
		glow.set_meta("exclude_selection_mask",true)
		for mesh:MeshInstance3D in glow.find_children("*","MeshInstance3D",true,false):
			mesh.set_meta("exclude_selection_mask",true)
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.material_override=_energy_material(1 if index==0 else 2,HALO_RADIUS if index==0 else POINT_RADIUS)
	reset()

func reset() -> void:
	flash.hide();hide_aim()

func update_flash(age: float) -> void:
	flash.visible=age>=0.0 and age<FLASH_SECONDS
	if flash.visible:
		var progress := clampf(age/FLASH_SECONDS,0,1)
		# Crisp single impulse; short fins remain, no stretched attack beam.
		flash.scale=Vector3.ONE*FLASH_SCALE*(1.0-.65*progress)

func hide_aim() -> void:
	for layer:Node3D in aim_layers:layer.hide()

func show_aim(end: Vector3, progress: float = 1.0, clock: float = 0.0) -> void:
	line_start=barrel.to_global(LENS_ORIGIN);line_end=end
	var segment := end-line_start
	if not end.is_finite() or segment.length_squared()<.000001:
		hide_aim();return
	# Scale the cylinder's local axes before rotation; world-axis scaling would
	# flatten an angled beam and detach its rendered endpoints from the target.
	var basis := Basis(Quaternion(Vector3.UP,segment.normalized()))*Basis.from_scale(Vector3(LINE_RADIUS,segment.length(),LINE_RADIUS))
	line.global_transform=Transform3D(basis,(line_start+end)*.5)
	var rotation := Basis(Quaternion(Vector3.UP,segment.normalized()))
	aim_layers[1].global_transform=Transform3D(rotation*Basis.from_scale(Vector3(HALO_RADIUS,segment.length(),HALO_RADIUS)),(line_start+end)*.5)
	for index in [2,3]:
		aim_layers[index].global_transform=Transform3D(rotation*Basis.from_scale(Vector3(POINT_RADIUS,POINT_RADIUS*2.0,POINT_RADIUS)),line_start if index==2 else end)
	_update_aim_charge(progress,clock)
	for layer:Node3D in aim_layers:layer.show()

func _energy_material(layer: int, radius: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader=AIM_ENERGY
	material.set_shader_parameter("layer",layer)
	material.set_shader_parameter("radius_world",radius)
	aim_materials.append(material)
	return material

func _update_aim_charge(progress: float, clock: float) -> void:
	var ratio := clampf(progress,0.0,1.0)
	if is_equal_approx(ratio,aim_ratio) and is_equal_approx(clock,aim_time): return
	aim_ratio=ratio;aim_time=clock
	for material:ShaderMaterial in aim_materials:
		material.set_shader_parameter("charge",ratio)
		material.set_shader_parameter("game_time",clock)
		material.set_shader_parameter("phase_offset",line_start.x*.37+line_start.z*.61)

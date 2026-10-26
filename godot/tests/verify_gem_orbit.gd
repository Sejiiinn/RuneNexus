extends SceneTree

const Orbit = preload("res://effects/gem_orbit.gd")
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	# Node/clock regression does not substitute a procedural gem in the product.
	var fixture := Node3D.new()
	var packed := PackedScene.new()
	packed.pack(fixture)
	fixture.free()
	Orbit._gem_scene = packed
	var orbit := Orbit.new()
	root.add_child(orbit)
	for count in range(1, 7):
		var colors: Array = []
		for i in range(count):
			colors.append(Color.from_hsv(float(i) / count, 0.8, 1.0))
		orbit.configure(colors)
		check(orbit._rotor.get_child_count() == count, "Satellite count mismatch")
		var rotor: Node3D = orbit._rotor
		var mesh: ArrayMesh = rotor.get_child(0).get_node("TrailingRibbon").mesh
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var spacing: float = TAU / count
		check(Orbit.trail_span(count) < spacing, "Trail overlaps next gem")
		for vertex in vertices:
			var behind: float = -atan2(vertex.z, vertex.x)
			check(behind >= Orbit.HEAD_GAP - 0.0001, "Ribbon reaches ahead of gem")
			check(behind <= Orbit.trail_span(count) + 0.0001, "Ribbon exceeds allocated sector")
			check(absf(vertex.x) < 0.5 and absf(vertex.z) < 0.5, "Ribbon escapes tile")
			check(is_equal_approx(vertex.y, Orbit.ORBIT_HEIGHT), "Ribbon height changes along orbit")
		for i in range(count):
			var slot: Node3D = rotor.get_child(i)
			check(is_equal_approx(slot.rotation.y, -spacing * i), "Unequal phase spacing")
			var gem: Node3D = slot.get_node("Gem")
			var light: OmniLight3D = slot.get_node("GemLight")
			check(light.position == gem.position and light.light_color == colors[i], "Gem light loses position/color")
			check(not light.shadow_enabled and is_equal_approx(light.omni_range, Orbit.LIGHT_RANGE), "Gem light exceeds local shadowless budget")
			check(is_equal_approx(light.light_energy, Orbit.LIGHT_ENERGY / sqrt(float(count))), "Multi-gem light energy is not normalized")
			check((gem.basis.x.normalized() - Vector3.BACK).length() < 0.0001, "Gem nose points backward")
		orbit.update_time(2.0)
		var paused: Transform3D = rotor.transform
		orbit.update_time(2.0)
		check(rotor.transform.is_equal_approx(paused), "Paused combat clock moves orbit")
		orbit.update_time(20.0)
		orbit.update_time(2.0)
		check(rotor.transform.is_equal_approx(paused), "Rewound clock does not reproduce pose")
		orbit.update_time(2.1)
		check(is_equal_approx(rotor.rotation.y, -2.1 * Orbit.ANGULAR_SPEED), "Orbit does not follow absolute combat speed")
		orbit.configure(colors)
		check(orbit._rotor == rotor, "Unchanged membership reallocates orbit")
		check(rotor.get_child(0).get_node("TrailingRibbon").mesh == mesh, "Time updates rebuild ribbon mesh")
		check(Orbit._mesh_for_count(count) == mesh, "Ribbon mesh is not shared by count")
	orbit.configure([Color.RED, Color.BLUE])
	var before_swap: ArrayMesh = orbit._rotor.get_child(0).get_node("TrailingRibbon").mesh
	orbit.update_time(3.0)
	orbit.configure([Color.GREEN, Color.BLUE])
	var changed: ShaderMaterial = orbit._rotor.get_child(0).get_node("TrailingRibbon").material_override
	check(changed.get_shader_parameter("ribbon_color") == Color.GREEN, "Same-count replacement keeps stale color")
	check(orbit._rotor.get_child(0).get_node("TrailingRibbon").mesh == before_swap, "Same-count replacement rebuilds shared mesh")
	check(is_equal_approx(orbit._rotor.rotation.y, -3.0 * Orbit.ANGULAR_SPEED), "Membership update resets clock phase")
	orbit.configure([])
	check(orbit._rotor == null and not orbit.visible, "Removed gems leave orbit visible")
	orbit.free()
	print("gem_orbit: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

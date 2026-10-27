extends RefCounted
## Per-chapter ambience painted over the stage-map background. Every effect is a
## child of the given layer, so pausing or freeing the layer stops all of it.
const GOLD := Color("e7c66a")

class Pulse extends TextureRect:
	## Additive glow whose alpha breathes; phase staggers neighbouring lights.
	var low := 0.25
	var high := 0.7
	var speed := 1.6
	var phase := 0.0
	var t := 0.0
	func _ready() -> void:
		var m := CanvasItemMaterial.new(); m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; material = m
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_process(0.0)
	func _process(delta: float) -> void:
		t += delta
		modulate.a = lerpf(low, high, 0.5 + 0.5 * sin(t * speed + phase))

class Lightning extends TextureRect:
	## Rare double flicker of the storm sky.
	var wait := 3.0
	var t := 0.0
	func _ready() -> void:
		var m := CanvasItemMaterial.new(); m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; material = m
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0
	func _process(delta: float) -> void:
		t += delta
		if t > wait + 0.45:
			t = 0.0; wait = randf_range(4.0, 8.0)
		var k := t - wait
		modulate.a = (0.9 if (k > 0.0 and k < 0.08) or (k > 0.16 and k < 0.3) else 0.0) * (1.0 - clampf(k / 0.45, 0, 1))

class Trail extends Control:
	## Light motes walking the path toward the selected stage.
	var points: PackedVector2Array
	var animated := true
	var t := 0.0
	var _lengths: Array = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lengths = [0.0]
		for i in range(1, points.size()): _lengths.append(_lengths[-1] + points[i - 1].distance_to(points[i]))
		set_process(animated)
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		if points.size() < 2: return
		var total: float = _lengths[-1]
		draw_polyline(points, Color(GOLD, 0.18), 2, true)
		if not animated: return
		for k in 6:
			var d := fposmod(t * 42.0 + k * total / 6.0, total)
			for i in range(1, points.size()):
				if d <= _lengths[i]:
					var p := points[i - 1].lerp(points[i], (d - _lengths[i - 1]) / maxf(0.001, _lengths[i] - _lengths[i - 1]))
					var fade := clampf(d / 30.0, 0, 1) * clampf((total - d) / 30.0, 0, 1)
					draw_circle(p, 4, Color(GOLD, 0.25 * fade))
					draw_circle(p, 2, Color(1, 0.93, 0.7, 0.9 * fade))
					break

class Halo extends Control:
	## Slow breathing halo behind the selected stage's gold socket.
	var t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var r := minf(size.x, size.y) / 2 - 2
		var breath := 0.5 + 0.5 * sin(t * 2.2)
		draw_circle(size / 2, r * 0.9 + breath * 5, Color(GOLD, 0.10 + 0.16 * breath))

class Shimmer extends Node:
	## Brief brightening of an unlock badge, staggered across badges.
	var target: CanvasItem
	var delay := 0.0
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		var k := fposmod(t - delay, 4.0)
		var flash := sin(clampf(k / 0.5, 0, 1) * PI) if k < 0.5 else 0.0
		target.modulate = Color(1 + flash * 0.8, 1 + flash * 0.8, 1 + flash * 0.6, target.modulate.a)

static func animations_enabled() -> bool:
	return not ProjectSettings.get_setting("accessibility/disable_animations", false)

static func glow_texture(color: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, color); g.set_color(1, Color(color, 0.0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5); gt.width = 128; gt.height = 128
	return gt

static func noise_texture(freq: float) -> NoiseTexture2D:
	var nt := NoiseTexture2D.new(); nt.seamless = true; nt.width = 256; nt.height = 256
	var fn := FastNoiseLite.new(); fn.frequency = freq; fn.fractal_octaves = 4; nt.noise = fn
	return nt

static func _put(parent: Control, c: Control, rect: Rect2) -> Control:
	parent.add_child(c)
	c.position = rect.position
	c.size = rect.size
	return c

static func _shader_rect(parent: Control, code: String, rect: Rect2, freq: float) -> ColorRect:
	var r := ColorRect.new()
	var sh := Shader.new(); sh.code = code
	var mat := ShaderMaterial.new(); mat.shader = sh
	mat.set_shader_parameter("noise", noise_texture(freq))
	r.material = mat; r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(parent, r, rect)
	return r

static func _pulse(parent: Control, at: Vector2, radius: float, color: Color, low: float, high: float, speed: float, phase: float) -> void:
	var p := Pulse.new()
	p.texture = glow_texture(color); p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; p.stretch_mode = TextureRect.STRETCH_SCALE
	p.low = low; p.high = high; p.speed = speed; p.phase = phase
	_put(parent, p, Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2))

static func _dust(parent: Control, color: Color, amount: int, rect: Rect2, rise: float) -> void:
	var p := CPUParticles2D.new()
	p.amount = amount; p.lifetime = 7.0; p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect.size / 2
	p.position = rect.get_center()
	p.gravity = Vector2(0, -rise); p.direction = Vector2(0, -1); p.spread = 180
	p.initial_velocity_min = 2; p.initial_velocity_max = 9
	p.scale_amount_min = 0.04; p.scale_amount_max = 0.09
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(color, 0), color, color, Color(color, 0)])
	p.color_ramp = ramp
	p.texture = glow_texture(Color(1, 1, 1, 1))
	var m := CanvasItemMaterial.new(); m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; p.material = m
	parent.add_child(p)

## `map` turns 853x1844 background pixels into layer coordinates; `scale` is its x scale
## (effect radii were tuned at a 420px wide map). Static lights stay when animation is off.
static func build(layer: Control, chapter: int, map: Callable, scale: float, background: Texture2D, bg_rect: Rect2) -> void:
	var animated := animations_enabled()
	var w := bg_rect.size.x
	var k := scale / (420.0 / 853.0)
	var top := bg_rect.position.y
	match chapter:
		1:
			if animated:
				# Clouds drifting across the moonlit sky.
				_shader_rect(layer, """shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
void fragment() {
	vec2 a = UV * vec2(1.2, 0.55) + vec2(TIME * 0.006, 0.0);
	vec2 b = UV * vec2(2.1, 0.9) + vec2(TIME * 0.011, 0.37);
	float n = texture(noise, a).r * 0.6 + texture(noise, b).r * 0.4;
	float cloud = smoothstep(0.48, 0.78, n);
	float fade = smoothstep(1.0, 0.55, UV.y) * smoothstep(0.0, 0.12, UV.y);
	COLOR = vec4(0.62, 0.74, 0.84, cloud * 0.42 * fade);
}""", Rect2(0, top - 22 * k, w, 190 * k), 0.012)
			# Moon halo, golden rune gate and the glowing runes on standing stones.
			_pulse(layer, map.call(Vector2(118, 125)), 46 * k, Color(0.75, 0.85, 1.0, 0.5), 0.35, 0.6, 0.7, 0.0)
			_pulse(layer, map.call(Vector2(520, 215)), 92 * k, Color(1.0, 0.78, 0.25, 0.75), 0.35, 0.85, 1.4, 0.0)
			var stones := [Vector2(375, 240), Vector2(660, 235), Vector2(232, 585), Vector2(800, 495), Vector2(130, 925), Vector2(740, 300)]
			for i in stones.size(): _pulse(layer, map.call(stones[i]), 18 * k, Color(1.0, 0.8, 0.3, 0.9), 0.1, 0.8, 1.1, i * 1.7)
			if animated:
				# Fireflies over the meadow.
				var flies := CPUParticles2D.new()
				flies.amount = 42; flies.lifetime = 7.0; flies.preprocess = 7.0
				flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
				flies.emission_rect_extents = Vector2(w / 2, 300 * k)
				flies.position = Vector2(w / 2, top + 318 * k)
				flies.gravity = Vector2.ZERO; flies.direction = Vector2(0, -1); flies.spread = 180
				flies.initial_velocity_min = 3; flies.initial_velocity_max = 11
				flies.scale_amount_min = 0.05; flies.scale_amount_max = 0.11
				var ramp := Gradient.new()
				ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
				ramp.colors = PackedColorArray([Color(1, 0.9, 0.4, 0), Color(1, 0.9, 0.4, 1), Color(1, 0.95, 0.5, 0.3), Color(1, 0.9, 0.4, 1), Color(1, 0.9, 0.4, 0)])
				flies.color_ramp = ramp
				flies.texture = glow_texture(Color(1, 0.95, 0.6, 1))
				var fm := CanvasItemMaterial.new(); fm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; flies.material = fm
				layer.add_child(flies)
		2:
			if animated:
				# Violet mist drifting through the void between the floating rocks.
				_shader_rect(layer, """shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
void fragment() {
	vec2 a = UV * vec2(1.0, 1.4) + vec2(TIME * 0.008, TIME * 0.002);
	vec2 b = UV * vec2(1.7, 2.2) - vec2(TIME * 0.012, 0.0);
	float n = texture(noise, a).r * 0.55 + texture(noise, b).r * 0.45;
	float mist = smoothstep(0.5, 0.82, n);
	float fade = smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.8, UV.y);
	COLOR = vec4(0.62, 0.42, 0.95, mist * 0.32 * fade);
}""", Rect2(0, top + 48 * k, w, 600 * k), 0.009)
				# Portal swirl, rotating inside the gate ring.
				var c: Vector2 = map.call(Vector2(490, 206))
				_shader_rect(layer, """shader_type canvas_item;
render_mode blend_add;
uniform sampler2D noise : repeat_enable, filter_linear;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + r * 3.2 - TIME * 0.9;
	vec2 q = vec2(cos(a), sin(a)) * r * 0.45 + 0.5;
	float n = texture(noise, q + vec2(TIME * 0.03, 0.0)).r;
	float body = smoothstep(1.0, 0.55, r);
	float v = (smoothstep(0.42, 0.78, n) * 0.85 + smoothstep(0.55, 0.0, r) * 0.35) * body;
	COLOR = vec4(0.45, 0.82, 1.0, v * 0.6);
}""", Rect2(c - Vector2(44, 44) * k, Vector2(88, 88) * k), 0.02)
			_pulse(layer, map.call(Vector2(490, 206)), 80 * k, Color(0.35, 0.75, 1.0, 0.7), 0.3, 0.75, 1.2, 0.0)
			# Crystal clusters flicker out of step with each other.
			var crystals := [Vector2(95, 265), Vector2(320, 280), Vector2(655, 295), Vector2(755, 470), Vector2(205, 560), Vector2(180, 870), Vector2(680, 880), Vector2(720, 965), Vector2(505, 1215)]
			for i in crystals.size(): _pulse(layer, map.call(crystals[i]), 26 * k, Color(0.4, 0.75, 1.0, 0.9), 0.05, 0.75, 2.3 + (i % 3) * 0.6, i * 2.1)
			if animated:
				# Storm lightning behind the citadel and on the right.
				for bolt in [Vector2(235, 110), Vector2(715, 140)]:
					var l := Lightning.new(); l.texture = glow_texture(Color(0.8, 0.7, 1.0, 0.9))
					l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; l.stretch_mode = TextureRect.STRETCH_SCALE
					l.wait = randf_range(1.5, 6.0)
					_put(layer, l, Rect2(map.call(bolt) - Vector2(110, 90) * k, Vector2(220, 180) * k))
				_dust(layer, Color(0.55, 0.85, 1.0, 0.9), 34, Rect2(0, top + 68 * k, w, 560 * k), 2.0)
		3:
			if animated:
				# Lava flow: the molten pixels of the painting slide slowly downward (two-phase
				# flow so the loop never jumps), with a faint wobble; everything else stays put.
				var flow := _shader_rect(layer, """shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform sampler2D bg : filter_linear;
float molten(vec3 c) { return smoothstep(0.2, 0.45, c.r - c.b) * smoothstep(0.45, 0.8, c.r); }
void fragment() {
	vec3 here = texture(bg, UV).rgb;
	float mask = molten(here);
	vec2 wobble = (texture(noise, UV * vec2(4.0, 2.0) + vec2(0.0, -TIME * 0.04)).rg - 0.5) * 0.004;
	float speed = 0.12;
	float p0 = fract(TIME * speed);
	float p1 = fract(TIME * speed + 0.5);
	vec2 dir = vec2(0.0, 0.014);
	vec3 a = texture(bg, UV - dir * p0 + wobble).rgb;
	vec3 b = texture(bg, UV - dir * p1 + wobble).rgb;
	vec3 flowed = mix(a, b, abs(0.5 - p0) * 2.0);
	COLOR = vec4(flowed, mask * 0.85);
}""", bg_rect, 0.03)
				(flow.material as ShaderMaterial).set_shader_parameter("bg", background)
				# Thin bright streaks running down the molten areas.
				var streaks := _shader_rect(layer, """shader_type canvas_item;
render_mode blend_add;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform sampler2D bg : filter_linear;
void fragment() {
	vec3 c = texture(bg, UV).rgb;
	float mask = smoothstep(0.2, 0.45, c.r - c.b) * smoothstep(0.55, 0.85, c.r);
	float n = texture(noise, UV * vec2(9.0, 1.2) + vec2(0.0, -TIME * 0.05)).r;
	float streak = smoothstep(0.62, 0.85, n);
	COLOR = vec4(1.0, 0.62, 0.22, mask * streak * 0.28);
}""", bg_rect, 0.03)
				(streaks.material as ShaderMaterial).set_shader_parameter("bg", background)
			# Rune gate core and the cyan rune lights on the machinery.
			_pulse(layer, map.call(Vector2(510, 180)), 95 * k, Color(1.0, 0.55, 0.15, 0.75), 0.3, 0.8, 1.3, 0.0)
			_pulse(layer, map.call(Vector2(510, 180)), 40 * k, Color(1.0, 0.85, 0.5, 0.8), 0.2, 0.7, 2.1, 1.0)
			var runes := [Vector2(357, 160), Vector2(660, 160), Vector2(295, 455), Vector2(798, 668), Vector2(110, 1050), Vector2(775, 1470)]
			for i in runes.size(): _pulse(layer, map.call(runes[i]), 18 * k, Color(0.35, 0.9, 1.0, 0.9), 0.05, 0.7, 1.5 + (i % 3) * 0.5, i * 1.9)
			if animated:
				# Embers rising off the lava.
				_dust(layer, Color(1.0, 0.6, 0.2, 1.0), 48, Rect2(0, top + 94 * k, w, 520 * k), 7.0)
	if not animated:
		# Lights keep their resting glow without breathing.
		for child in layer.get_children():
			if child is Pulse: child.set_process(false)

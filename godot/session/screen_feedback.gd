extends ColorRect
var _last_alert := -1.0
var _last_fade := -1.0
var _last_viewport := Vector2(-1, -1)
func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float alert = 0.0;
uniform float fade = 0.0;
uniform vec2 viewport = vec2(880.0,760.0);
void fragment() {
 vec2 p = UV * viewport;
 float width = clamp(min(viewport.x, viewport.y)*0.12,26.0,54.0);
 vec4 a = clamp(vec4(1.0-p.x/width,1.0-(viewport.x-p.x)/width,1.0-p.y/width,1.0-(viewport.y-p.y)/width),vec4(0.0),vec4(1.0))*alert*0.22;
 float red = 1.0-(1.0-a.x)*(1.0-a.y)*(1.0-a.z)*(1.0-a.w);
 float dark = fade*0.68;
 float alpha = dark+red*(1.0-dark);
 vec3 rgb = (vec3(2.0,7.0,13.0)/255.0*dark+vec3(1.0,61.0/255.0,61.0/255.0)*red*(1.0-dark))/max(alpha,0.00001);
 COLOR = vec4(rgb,alpha);
}"""
	material = ShaderMaterial.new()
	material.shader = shader

func update_state(runtime, logical_size: Vector2) -> void:
	var alert: float = runtime.nexus_alert / 0.65
	var fade: float = runtime.destruction_elapsed / 3.2
	visible = runtime.native_session() and (alert > 0.0 or fade > 0.0)
	if not visible: return
	if alert != _last_alert:
		material.set_shader_parameter("alert", alert)
		_last_alert = alert
	if fade != _last_fade:
		material.set_shader_parameter("fade", fade)
		_last_fade = fade
	if logical_size != _last_viewport:
		material.set_shader_parameter("viewport", logical_size)
		_last_viewport = logical_size

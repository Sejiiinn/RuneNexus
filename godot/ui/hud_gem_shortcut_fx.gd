extends Control
## Activation flash for the gem purchase shortcut: a cyan rim bloom and
## outward sparks. Processes only during its short burst; idle frames do no work.
const DURATION := 0.6
const RIM := Color("7ff4ff")
var radius := 23.0
var elapsed := -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new(); additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	set_process(false)

func play() -> void:
	elapsed = 0.0
	set_process(true)
	queue_redraw()

func playing() -> bool:
	return elapsed >= 0.0

func stop() -> void:
	elapsed = -1.0
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION: stop()
	else: queue_redraw()

func _draw() -> void:
	if elapsed < 0.0: return
	var k := elapsed/DURATION
	var center := size*0.5
	# Fast rise, slower fade; the bloom drifts slightly outward as it fades.
	var flash := sin(PI*minf(k*1.6,1.0)) if k < 0.3125 else 1.0-smoothstep(0.3125,1.0,k)
	for i in 4:
		draw_arc(center,radius+i*1.6+k*5.0,0.0,TAU,56,Color(RIM,flash*(0.5-i*0.11)),2.0+i*2.2,true)
	# Four-point glints leave from the rim, never over the gems.
	var glint := Color(0.85,1.0,1.0,(1.0-k)*0.95)
	for i in 8:
		var direction := Vector2.RIGHT.rotated(TAU*i/8.0+0.39)
		var point := center+direction*(radius*0.98+ease(k,0.45)*radius*0.6)
		var arm := 1.2+3.0*(1.0-k)
		var star := PackedVector2Array()
		for j in 8:
			star.append(point+Vector2.RIGHT.rotated(TAU*j/8.0)*(arm if j % 2 == 0 else arm*0.28))
		draw_colored_polygon(star,glint)

extends Control
const COLORS := {"normal":Color("bac6cd"), "magic":Color("77bbff"), "rare":Color("e7cb6c"), "unique":Color("c98fff")}
var part := "core"
var tint := Color("8ee6ff")
func _draw() -> void:
	var c := size * 0.5
	var w := size.x
	draw_circle(c, w * 0.48, Color(tint, 0.14))
	match part:
		"core":
			draw_rect(Rect2(size * 0.18, size * 0.64), tint, false, 1.5)
			draw_rect(Rect2(size * 0.36, size * 0.28), tint)
			for x in [0.31, 0.50, 0.69]:
				draw_line(Vector2(w * x, w * 0.04), Vector2(w * x, w * 0.18), tint, 1.5)
				draw_line(Vector2(w * x, w * 0.82), Vector2(w * x, w * 0.96), tint, 1.5)
			for y in [0.34, 0.66]:
				draw_line(Vector2(w * 0.04, w * y), Vector2(w * 0.18, w * y), tint, 1.5)
				draw_line(Vector2(w * 0.82, w * y), Vector2(w * 0.96, w * y), tint, 1.5)
		"barrel":
			for x in [0.25, 0.55]: draw_rect(Rect2(w * x, w * 0.08, w * 0.20, w * 0.72), tint)
			draw_rect(Rect2(w * 0.18, w * 0.65, w * 0.64, w * 0.25), Color(tint, 0.58))
		"frame":
			draw_arc(c, w * 0.34, 0, TAU, 32, tint, 1.5, true)
			for angle in [PI / 4, PI * 3 / 4]:
				var delta := Vector2(cos(angle), sin(angle)) * w * 0.32
				draw_line(c - delta, c + delta, tint, 1.5)
			draw_circle(c, w * 0.08, tint)

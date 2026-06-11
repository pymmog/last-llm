extends Node2D
## Floating damage / heal number.

var text := "0"
var color := Color(1, 0.9, 0.5)
var life := 0.7
var t := 0.0


func _physics_process(delta: float) -> void:
	t += delta
	position.y -= 40.0 * delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - clampf(t / life, 0.0, 1.0)
	var font := ThemeDB.fallback_font
	var c := Color(color.r, color.g, color.b, fade)
	var shadow := Color(0, 0, 0, fade * 0.6)
	draw_string(font, Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, shadow)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, c)

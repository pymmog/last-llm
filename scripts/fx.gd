extends Node2D
## Lightweight one-shot effects: pop (death burst), ring (explosion / level
## up), lightning (tesla polyline), burn (damaging ground patch).

var main: Node2D
var kind := "pop"
var radius := 24.0
var color := Color.WHITE
var points := PackedVector2Array()
var life := 0.35
var burn_dps := 0.0

var t := 0.0
var _tick := 0.0
var _jitter: Array = []


func _ready() -> void:
	match kind:
		"lightning":
			life = 0.22
			for p in points:
				_jitter.append(Vector2(randf_range(-7, 7), randf_range(-7, 7)))
		"burn":
			z_index = -5
		"ring":
			life = 0.35
		"pop":
			life = 0.3


func _physics_process(delta: float) -> void:
	t += delta
	if kind == "burn" and burn_dps > 0.0:
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.5
			for e in main.enemies_in_range(position, radius):
				e.take_damage(burn_dps * 0.5, position)
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / life, 0.0, 1.0)
	var fade := 1.0 - k
	match kind:
		"pop":
			var c := Color(color.r, color.g, color.b, fade * 0.85)
			for i in 6:
				var a := TAU * i / 6.0 + 0.5
				var p := Vector2(cos(a), sin(a)) * radius * k
				draw_circle(p, 3.0 * fade + 0.5, c)
		"ring":
			var c2 := Color(color.r, color.g, color.b, fade * 0.9)
			draw_arc(Vector2.ZERO, radius * (0.3 + 0.7 * k), 0, TAU, 32, c2, 4.0 * fade + 1.0)
			draw_circle(Vector2.ZERO, radius * k * 0.4, Color(color.r, color.g, color.b, fade * 0.25))
		"lightning":
			var c3 := Color(color.r, color.g, color.b, fade)
			for i in points.size() - 1:
				var a2: Vector2 = points[i] + _jitter[i] * (1.0 if i > 0 else 0.0)
				var b: Vector2 = points[i + 1] + _jitter[i + 1]
				var mid := (a2 + b) * 0.5 + Vector2(randf_range(-5, 5), randf_range(-5, 5))
				draw_line(a2, mid, c3, 2.0)
				draw_line(mid, b, c3, 2.0)
				draw_line(a2, b, Color(c3.r, c3.g, c3.b, c3.a * 0.3), 4.0)
		"burn":
			var flicker := 0.75 + 0.25 * sin(t * 23.0)
			var c4 := Color(color.r, color.g, color.b, fade * 0.3 * flicker)
			draw_circle(Vector2.ZERO, radius, c4)
			draw_circle(Vector2.ZERO, radius * 0.6, Color(1.0, 0.7, 0.2, fade * 0.25 * flicker))

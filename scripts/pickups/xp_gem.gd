extends Node2D
## XP gem: idles until the player's pickup radius reaches it, then vacuums in.

var main: Node2D
var value := 1.0
var attracting := false
var pull_speed := 240.0
var sparkle := 0.0


func _ready() -> void:
	add_to_group("xp_gems")
	sparkle = randf() * TAU


func force_attract() -> void:
	attracting = true


func _physics_process(delta: float) -> void:
	if main.run_over:
		return
	var player: Node2D = main.player
	var to_player: Vector2 = player.position - position
	var d2 := to_player.length_squared()
	if not attracting and d2 < player.pickup_radius * player.pickup_radius:
		attracting = true
	if attracting:
		pull_speed = minf(pull_speed + 900.0 * delta, 760.0)
		position += to_player.normalized() * pull_speed * delta
		if d2 < 18.0 * 18.0:
			player.add_xp(value)
			queue_free()
			return
	sparkle += delta * 3.0
	queue_redraw()


func _draw() -> void:
	var s := 4.0
	var col := Color(0.25, 0.95, 0.9)
	if value >= 20.0:
		s = 7.0
		col = Color(0.95, 0.5, 0.95)
	elif value >= 5.0:
		s = 5.5
		col = Color(0.35, 0.6, 1.0)
	var pulse := 1.0 + sin(sparkle) * 0.15
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -s * 1.3 * pulse), Vector2(s * pulse, 0),
		Vector2(0, s * 1.3 * pulse), Vector2(-s * pulse, 0)]), col)
	draw_line(Vector2(0, -s * 0.6), Vector2(0, s * 0.6), col.lightened(0.5), 1.5)

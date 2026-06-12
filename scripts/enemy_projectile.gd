extends Node2D
## Acid glob lobbed by Spitters. Hurts the player on contact.

var main: Node2D
var vel := Vector2.ZERO
var dmg := 8.0
var color := Color(0.64, 0.36, 0.80)
var life := 3.0


func _physics_process(delta: float) -> void:
	if main.run_over:
		queue_free()
		return
	position += vel * delta
	life -= delta
	if life <= 0.0:
		main.spawn_fx("splat", position, 8.0, color)
		queue_free()
		return
	var player: Node2D = main.player
	if position.distance_squared_to(player.position) < pow(6.0 + player.radius, 2.0):
		player.take_damage(dmg, position - vel * 0.1)
		main.spawn_fx("splat", position, 14.0, color)
		main.spawn_fx("spark", position, 10.0, color.lightened(0.2), PackedVector2Array(), vel.normalized())
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, color)
	draw_circle(Vector2(-1, -1), 2.0, color.lightened(0.35))
	var trail := -vel.normalized() * 8.0
	draw_line(Vector2.ZERO, trail, Color(color.r, color.g, color.b, 0.4), 3.0)

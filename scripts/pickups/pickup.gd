extends Node2D
## Touch pickups: medkit (+25% HP), scrap (meta currency), magnet (vacuum all
## gems), crate (weapon evolution / scrap from minibosses).

var main: Node2D
var kind := "scrap"
var value := 1
var bob := 0.0


func _ready() -> void:
	bob = randf() * TAU


func _physics_process(delta: float) -> void:
	if main.run_over:
		return
	bob += delta * 3.0
	var player: Node2D = main.player
	var reach := 30.0 if kind == "crate" else 22.0
	if position.distance_squared_to(player.position) < pow(reach + player.radius, 2.0):
		collect(player)
		return
	queue_redraw()


func collect(player: Node2D) -> void:
	match kind:
		"medkit":
			player.heal(player.max_hp * 0.25)
		"scrap":
			main.scrap_earned += value
			main.add_damage_number(position, value, Color(0.85, 0.85, 0.85))
		"magnet":
			for gem in get_tree().get_nodes_in_group("xp_gems"):
				gem.force_attract()
			main.spawn_fx("ring", position, 60.0, Color(0.4, 0.6, 1.0))
		"crate":
			main.open_crate()
	main.spawn_fx("pop", position, 14.0, Color(1, 1, 1))
	queue_free()


func _draw() -> void:
	var y := sin(bob) * 2.0
	match kind:
		"medkit":
			draw_rect(Rect2(-8, -8 + y, 16, 16), Color(0.9, 0.92, 0.9))
			draw_rect(Rect2(-2.5, -6 + y, 5, 12), Color(0.85, 0.2, 0.2))
			draw_rect(Rect2(-6, -2.5 + y, 12, 5), Color(0.85, 0.2, 0.2))
		"scrap":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-6, 4 + y), Vector2(-3, -5 + y), Vector2(2, -3 + y),
				Vector2(6, 1 + y), Vector2(3, 5 + y)]), Color(0.62, 0.6, 0.58))
			draw_circle(Vector2(1, y), 1.6, Color(0.85, 0.83, 0.8))
		"magnet":
			draw_arc(Vector2(0, y), 7.0, PI * 0.15, PI * 0.85 + PI, 12, Color(0.3, 0.5, 1.0), 5.0)
			draw_rect(Rect2(-8, 3 + y, 5, 4), Color(0.9, 0.9, 0.9))
			draw_rect(Rect2(3, 3 + y, 5, 4), Color(0.9, 0.9, 0.9))
		"crate":
			draw_rect(Rect2(-11, -9 + y, 22, 18), Color(0.55, 0.4, 0.22))
			draw_rect(Rect2(-11, -3 + y, 22, 4), Color(0.35, 0.25, 0.13))
			draw_circle(Vector2(0, -1 + y), 3.0, Color(0.95, 0.85, 0.3))

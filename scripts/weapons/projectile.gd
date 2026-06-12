extends Node2D
## Friendly projectile. Manual circle collision against main.enemies.
## Styles: rivet, spike, drone (homing), shell (flies to a point, explodes).

var main: Node2D
var vel := Vector2.ZERO
var damage := 5.0
var pierce := 0
var radius := 5.0
var life := 2.0
var style := "rivet"

# Homing (drones)
var homing := false
var turn_rate := 5.0

# Shell (mortar)
var target_point := Vector2.ZERO
var explode_radius := 0.0
var burn := false
var burn_dps := 0.0

var _hit := {}


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		if style == "shell":
			_detonate()
		queue_free()
		return

	if style == "shell":
		var to_target := target_point - position
		if to_target.length() < 12.0:
			_detonate()
			queue_free()
			return
		vel = to_target.normalized() * vel.length()
		position += vel * delta
		queue_redraw()
		return

	if homing:
		var target: Node2D = _nearest_unhit(400.0)
		if target:
			var desired := (target.position - position).normalized()
			vel = vel.slerp(desired * vel.length(), clampf(turn_rate * delta, 0.0, 1.0))
	position += vel * delta

	for e in main.enemies:
		if not is_instance_valid(e) or e.dead or _hit.has(e.get_instance_id()):
			continue
		var r: float = radius + e.radius
		if position.distance_squared_to(e.position) < r * r:
			e.take_damage(damage, position)
			_hit[e.get_instance_id()] = true
			pierce -= 1
			if pierce < 0:
				main.spawn_fx("spark", position, 8.0, modulate_color(), PackedVector2Array(), vel.normalized())
				queue_free()
				return
	queue_redraw()


func _detonate() -> void:
	main.explode(target_point, explode_radius, damage, burn, burn_dps)


func _nearest_unhit(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_range * max_range
	for e in main.enemies:
		if not is_instance_valid(e) or e.dead or _hit.has(e.get_instance_id()):
			continue
		var d: float = position.distance_squared_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func modulate_color() -> Color:
	match style:
		"spike":
			return Color(0.85, 0.9, 1.0)
		"drone":
			return Color(0.5, 1.0, 0.6)
		"shell":
			return Color(0.4, 0.9, 1.0)
		_:
			return Color(1.0, 0.7, 0.3)


func _draw() -> void:
	var dir := vel.normalized()
	match style:
		"rivet":
			var p := dir * 6.0
			draw_line(-p, p, Color(1.0, 0.72, 0.3), 3.0)
			draw_circle(p, 2.0, Color(1.0, 0.9, 0.6))
		"spike":
			var p2 := dir * 14.0
			draw_line(-p2, p2, Color(0.8, 0.88, 1.0), 4.0)
			draw_line(-p2 * 1.6, -p2, Color(0.5, 0.6, 0.9, 0.5), 3.0)
		"drone":
			var a := vel.angle()
			draw_set_transform(Vector2.ZERO, a, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([
				Vector2(5, 0), Vector2(-4, 4), Vector2(-2, 0), Vector2(-4, -4)]),
				Color(0.5, 1.0, 0.6))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"shell":
			draw_circle(Vector2.ZERO, 5.0, Color(0.4, 0.9, 1.0))
			draw_circle(Vector2.ZERO, 2.5, Color(0.9, 1.0, 1.0))
			draw_line(Vector2.ZERO, -dir * 10.0, Color(0.4, 0.9, 1.0, 0.4), 4.0)

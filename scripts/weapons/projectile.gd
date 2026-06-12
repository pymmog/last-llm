extends Node2D
## Friendly projectile. Manual circle collision against main.enemies.
## Styles: rivet, spike, drone (homing), shell (flies to a point, explodes).

const SPRITES := {
	"rivet": preload("res://assets/sprites/projectile_rivet.png"),
	"spike": preload("res://assets/sprites/projectile_spike.png"),
	"drone": preload("res://assets/sprites/projectile_drone.png"),
	"shell": preload("res://assets/sprites/projectile_shell.png"),
}
const SPRITE_WIDTHS := {
	"rivet": 18.0,
	"spike": 34.0,
	"drone": 20.0,
	"shell": 25.0,
}
# Direction each sprite's nose points in the source art (measured from the
# pixels' principal axis); subtracted so the nose leads the velocity.
const SPRITE_ANGLES := {
	"rivet": deg_to_rad(150.8),
	"spike": deg_to_rad(152.6),
	"drone": deg_to_rad(-166.3),
	"shell": deg_to_rad(150.7),
}

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


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rotation = _travel_angle()


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
		rotation = _travel_angle()
		position += vel * delta
		queue_redraw()
		return

	if homing:
		var target: Node2D = main.nearest_enemy(position, 400.0, _hit)
		if target:
			var desired := (target.position - position).normalized()
			vel = vel.slerp(desired * vel.length(), clampf(turn_rate * delta, 0.0, 1.0))
	rotation = _travel_angle()
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
	var tex: Texture2D = SPRITES.get(style)
	if tex:
		_draw_sprite_projectile(tex, float(SPRITE_WIDTHS.get(style, radius * 2.0)))
		return

	var dir := Vector2.RIGHT
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
			draw_colored_polygon(PackedVector2Array([
				Vector2(5, 0), Vector2(-4, 4), Vector2(-2, 0), Vector2(-4, -4)]),
				Color(0.5, 1.0, 0.6))
		"shell":
			draw_circle(Vector2.ZERO, 5.0, Color(0.4, 0.9, 1.0))
			draw_circle(Vector2.ZERO, 2.5, Color(0.9, 1.0, 1.0))
			draw_line(Vector2.ZERO, -dir * 10.0, Color(0.4, 0.9, 1.0, 0.4), 4.0)


func _travel_angle() -> float:
	if vel.length_squared() > 0.001:
		return vel.angle()
	if target_point != Vector2.ZERO and target_point != position:
		return (target_point - position).angle()
	return 0.0


func _draw_sprite_projectile(tex: Texture2D, width: float) -> void:
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var size := Vector2(width, width * tex_size.y / tex_size.x)
	# Node rotation already tracks the travel direction (_physics_process);
	# here we only cancel the art's native orientation so the nose leads.
	draw_set_transform(Vector2.ZERO, -float(SPRITE_ANGLES.get(style, 0.0)), Vector2.ONE)
	draw_texture_rect(tex, Rect2(-size * 0.5, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

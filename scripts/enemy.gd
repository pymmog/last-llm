extends Node2D
## Human-like mutants. One script drives all types; behavior and silhouette
## switch on `type`. Alphas are scaled-up minibosses that drop supply crates.

const EnemyProjectileScript := preload("res://scripts/enemy_projectile.gd")

const TYPES := {
	"shambler": {"hp": 18.0, "speed": 52.0, "dmg": 8.0, "radius": 11.0, "xp": 1.0,
		"color": Color(0.45, 0.72, 0.30), "scrap_chance": 0.03},
	"sprinter": {"hp": 11.0, "speed": 78.0, "dmg": 6.0, "radius": 9.0, "xp": 1.5,
		"color": Color(0.92, 0.80, 0.25), "scrap_chance": 0.04},
	"spitter": {"hp": 16.0, "speed": 44.0, "dmg": 7.0, "radius": 10.0, "xp": 2.0,
		"color": Color(0.64, 0.36, 0.80), "scrap_chance": 0.05},
	"brute": {"hp": 95.0, "speed": 38.0, "dmg": 18.0, "radius": 16.0, "xp": 6.0,
		"color": Color(0.84, 0.26, 0.20), "scrap_chance": 0.35},
}

var main: Node2D
var type := "shambler"
var hp := 10.0
var max_hp := 10.0
var speed := 50.0
var dmg := 5.0
var radius := 10.0
var xp_value := 1.0
var color := Color.GREEN
var is_alpha := false
var dead := false

var flash := 0.0
var knockback := Vector2.ZERO
var attack_cd := 0.0
var state := "walk"
var state_t := 0.0
var charge_dir := Vector2.ZERO
var shoot_cd := 2.0
var wobble := 0.0
var anim_t := 0.0
var draw_scale := 1.0


func setup(m: Node2D, etype: String, pos: Vector2, hp_mult: float, dmg_mult: float, alpha: bool = false) -> void:
	main = m
	type = etype
	position = pos
	var d: Dictionary = TYPES[etype]
	max_hp = d["hp"] * hp_mult
	speed = d["speed"]
	dmg = d["dmg"] * dmg_mult
	radius = d["radius"]
	xp_value = d["xp"]
	color = d["color"]
	is_alpha = alpha
	if alpha:
		max_hp *= 16.0
		dmg *= 1.6
		radius *= 2.2
		speed *= 0.85
		xp_value *= 10.0
		draw_scale = 2.4
	hp = max_hp
	wobble = randf() * TAU
	anim_t = randf() * TAU


func _physics_process(delta: float) -> void:
	if dead or main.run_over:
		return
	var player: Node2D = main.player
	var to_player: Vector2 = player.position - position
	var dist := to_player.length()
	flash = maxf(flash - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)
	state_t += delta
	anim_t += delta * 8.0

	match type:
		"shambler":
			var side := to_player.orthogonal().normalized() * sin(anim_t * 0.4 + wobble) * 12.0
			position += (to_player.normalized() * speed + side) * delta
		"sprinter":
			_sprinter_brain(to_player, delta)
		"spitter":
			_spitter_brain(to_player, dist, delta)
		"brute":
			_brute_brain(to_player, delta)

	# Knockback from weapon hits decays exponentially.
	if knockback != Vector2.ZERO:
		position += knockback * delta
		knockback *= maxf(1.0 - 8.0 * delta, 0.0)

	# Solid bodies: never overlap the player, stop at its edge.
	var sep := position - player.position
	var min_dist: float = radius + player.radius
	if sep.length_squared() < min_dist * min_dist:
		var d := sep.length()
		var away := sep / d if d > 0.001 else Vector2.from_angle(randf() * TAU)
		position = player.position + away * min_dist
		dist = min_dist

	# Contact damage.
	if attack_cd <= 0.0 and dist < radius + player.radius + 2.0:
		player.take_damage(dmg, position)
		attack_cd = 0.8
	queue_redraw()


func _sprinter_brain(to_player: Vector2, delta: float) -> void:
	match state:
		"walk":
			position += to_player.normalized() * speed * delta
			if state_t > 1.2 and to_player.length() < 320.0:
				state = "aim"
				state_t = 0.0
		"aim":
			if state_t > 0.55:
				state = "lunge"
				state_t = 0.0
				charge_dir = to_player.normalized()
		"lunge":
			position += charge_dir * speed * 3.2 * delta
			if state_t > 0.45:
				state = "walk"
				state_t = 0.0


func _spitter_brain(to_player: Vector2, dist: float, delta: float) -> void:
	var n := to_player.normalized()
	if dist > 290.0:
		position += n * speed * delta
	elif dist < 180.0:
		position -= n * speed * 0.8 * delta
	else:
		position += n.orthogonal() * sin(wobble) * speed * 0.4 * delta
	shoot_cd -= delta
	if shoot_cd <= 0.0 and dist < 340.0:
		shoot_cd = 2.4
		var glob: Node2D = EnemyProjectileScript.new()
		glob.main = main
		glob.position = position
		glob.vel = n * 175.0
		glob.dmg = dmg * 1.2
		glob.color = color
		main.projectiles_node.add_child(glob)


func _brute_brain(to_player: Vector2, delta: float) -> void:
	match state:
		"walk":
			position += to_player.normalized() * speed * delta
			if state_t > 4.0 and to_player.length() < 360.0:
				state = "telegraph"
				state_t = 0.0
		"telegraph":
			flash = 0.1
			if state_t > 0.7:
				state = "charge"
				state_t = 0.0
				charge_dir = to_player.normalized()
		"charge":
			position += charge_dir * speed * 3.4 * delta
			if state_t > 1.0:
				state = "walk"
				state_t = 0.0


func take_damage(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.12
	if from != Vector2.ZERO and from != position:
		var away := (position - from).normalized()
		var kb := 140.0 * clampf(amount / max_hp, 0.08, 0.6)
		knockback += away * (kb * 0.25 if is_alpha else kb)
		main.spawn_fx("spark", position, radius * 0.8, color.lightened(0.3), PackedVector2Array(), away)
	main.add_damage_number(position - Vector2(0, radius), amount)
	if hp <= 0.0:
		die()


func die() -> void:
	dead = true
	main.on_enemy_killed(self)
	main.spawn_fx("pop", position, radius * 1.4, color)
	main.spawn_xp(position, xp_value)
	var d: Dictionary = TYPES[type]
	if is_alpha:
		main.spawn_pickup("crate", position)
		main.spawn_pickup("scrap", position + Vector2(30, 0), 10 + randi() % 10)
		main.spawn_xp(position + Vector2(-20, 10), xp_value)
	else:
		if randf() < float(d["scrap_chance"]):
			main.spawn_pickup("scrap", position, 1 + randi() % 3)
		if randf() < 0.006:
			main.spawn_pickup("medkit", position)
		if randf() < 0.002:
			main.spawn_pickup("magnet", position)
	queue_free()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var s := draw_scale
	var f := signf(main.player.position.x - position.x)
	if f == 0.0:
		f = 1.0
	var c := color
	var skin := color.lightened(0.15)
	if flash > 0.0:
		c = Color(1, 1, 1)
		skin = Color(1, 1, 1)
	var step := sin(anim_t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(f * s, s))
	# Shadow
	_ellipse(Vector2(0, 12), Vector2(9, 3.5), Color(0, 0, 0, 0.3))
	match type:
		"shambler":
			# Hunched: forward-leaning torso, long dangling arms.
			draw_line(Vector2(-2, 4), Vector2(-4 + step * 2, 12), c.darkened(0.3), 2.5)
			draw_line(Vector2(2, 4), Vector2(4 - step * 2, 12), c.darkened(0.3), 2.5)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5, 5), Vector2(-3, -5), Vector2(7, -8), Vector2(8, -2), Vector2(4, 6)]), c)
			draw_line(Vector2(5, -4), Vector2(9 + step, 6), c.darkened(0.15), 2.5)
			draw_circle(Vector2(8, -9), 4.0, skin)
			draw_circle(Vector2(9.5, -9.5), 1.0, Color(0.9, 0.2, 0.1))
		"sprinter":
			# Tall and lanky, thin limbs.
			draw_line(Vector2(-1, 2), Vector2(-4 + step * 4, 12), c.darkened(0.25), 2.0)
			draw_line(Vector2(1, 2), Vector2(4 - step * 4, 12), c.darkened(0.25), 2.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-3, 3), Vector2(-2, -9), Vector2(3, -9), Vector2(3, 3)]), c)
			draw_line(Vector2(2, -7), Vector2(7, -2 + step * 3), c.darkened(0.15), 1.8)
			draw_circle(Vector2(1, -12), 3.2, skin)
			draw_circle(Vector2(2.3, -12.5), 0.9, Color(0.9, 0.2, 0.1))
		"spitter":
			# Squat with a bulbous head.
			draw_line(Vector2(-3, 5), Vector2(-5 + step * 2, 11), c.darkened(0.3), 2.5)
			draw_line(Vector2(3, 5), Vector2(5 - step * 2, 11), c.darkened(0.3), 2.5)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-6, 6), Vector2(-5, -2), Vector2(5, -2), Vector2(6, 6)]), c)
			draw_circle(Vector2(1, -7), 6.5, skin)
			draw_circle(Vector2(-1, -9), 1.8, c.darkened(0.35))
			draw_circle(Vector2(3, -5), 1.4, c.darkened(0.35))
			draw_circle(Vector2(4, -8), 1.1, Color(0.9, 0.2, 0.1))
		"brute":
			# Broad shoulders, massive arms, small head.
			draw_line(Vector2(-4, 6), Vector2(-6 + step * 2, 13), c.darkened(0.3), 4.0)
			draw_line(Vector2(4, 6), Vector2(6 - step * 2, 13), c.darkened(0.3), 4.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-10, -8), Vector2(10, -8), Vector2(6, 7), Vector2(-6, 7)]), c)
			draw_line(Vector2(-9, -6), Vector2(-12, 6 + step * 2), c.darkened(0.15), 4.5)
			draw_line(Vector2(9, -6), Vector2(12, 6 - step * 2), c.darkened(0.15), 4.5)
			draw_circle(Vector2(0, -11), 3.5, skin)
			draw_circle(Vector2(1.4, -11.5), 1.0, Color(1.0, 0.85, 0.2))
	if is_alpha:
		# Crown spikes mark minibosses.
		for i in 3:
			var bx := -6.0 + i * 6.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx - 2, -13), Vector2(bx, -20), Vector2(bx + 2, -13)]),
				Color(0.95, 0.85, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Health bar (alphas always; others only when hurt).
	if is_alpha or hp < max_hp:
		var w := radius * 2.0
		var y := -radius - 10.0 * s
		draw_rect(Rect2(-w / 2, y, w, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 3), Color(0.9, 0.25, 0.2))


func _ellipse(center: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)

extends "res://scripts/weapons/weapon_base.gd"
## Scrap Saw: saw blades spin up around the player in bursts — they shred
## for a few seconds, vanish, then re-deploy after a downtime.
## Evolution (+ Reactive Plating): Buzzkill Halo — a permanent dense ring.

const BLADE_RADIUS := 9.0
const HIT_COOLDOWN := 0.45
const ACTIVE_TIME := 4.0
const DOWNTIME := 3.0
const DEPLOY_TIME := 0.5
const FADE_TIME := 0.35
const BLADE_SPRITE: Texture2D = preload("res://assets/sprites/projectile_saw_blade.png")

var angle := 0.0
var blade_spin := 0.0
var active_left := ACTIVE_TIME  # deploys immediately when acquired
var _last_hit := {}  # enemy instance id -> time of last hit
var _time := 0.0


func _init() -> void:
	id = "saw"
	display_name = "Scrap Saw"
	paired_passive = "plating"
	evolved_name = "Buzzkill Halo"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func blade_count() -> int:
	if evolved:
		return 6
	var n := 1
	if level >= 2:
		n += 1
	if level >= 5:
		n += 1
	if level >= 8:
		n += 1
	return n


func blade_damage() -> float:
	if evolved:
		return dmg(34.0)
	var d := 10.0
	if level >= 3:
		d += 5.0
	if level >= 6:
		d += 7.0
	return dmg(d)


func orbit_radius() -> float:
	var r := 70.0
	if level >= 4:
		r += 12.0
	if level >= 7:
		r += 12.0
	if evolved:
		r = 100.0
	return area(r)


func spin_speed() -> float:
	return 4.6 if evolved else 3.0


func blade_spin_speed() -> float:
	return 24.0 if evolved else 18.0


func is_active() -> bool:
	return evolved or active_left > 0.0


func deploy_factor() -> float:
	## 0..1: blades spiral out from the player on deploy, ease out at the rim.
	if evolved:
		return 1.0
	var t := clampf((ACTIVE_TIME - active_left) / DEPLOY_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 2.0)


func cooldown() -> float:
	return DOWNTIME


func _physics_process(delta: float) -> void:
	if main.run_over:
		return
	_time += delta
	if not evolved:
		if active_left > 0.0:
			active_left -= delta
			if active_left <= 0.0:
				cd = effective_cooldown()
		else:
			cd -= delta
			if cd <= 0.0:
				active_left = ACTIVE_TIME
	if not is_active():
		queue_redraw()
		return
	var speed_factor: float = 1.0 + float(player.attack_speed)
	angle = wrapf(angle + spin_speed() * speed_factor * delta, 0.0, TAU)
	blade_spin = wrapf(blade_spin + blade_spin_speed() * speed_factor * delta, 0.0, TAU)
	var r := orbit_radius() * deploy_factor()
	var n := blade_count()
	var damage := blade_damage()
	for i in n:
		var a := angle + TAU * i / n
		var blade_pos: Vector2 = player.position + Vector2(cos(a), sin(a)) * r
		for e in main.enemies_in_range(blade_pos, BLADE_RADIUS + 12.0):
			var key: int = e.get_instance_id()
			if _time - float(_last_hit.get(key, -10.0)) >= HIT_COOLDOWN:
				_last_hit[key] = _time
				e.take_damage(damage, blade_pos)
	queue_redraw()


func _draw() -> void:
	# Drawn relative to the player (this node sits at the player's origin).
	# Sprite is pale steel; gold modulate marks the evolved halo.
	if not is_active():
		return
	var r := orbit_radius() * deploy_factor()
	var n := blade_count()
	var col := Color(1.0, 0.8, 0.3) if evolved else Color(1, 1, 1)
	if not evolved:
		# Blades spiral out from the player, then fade out before vanishing.
		col.a = clampf(active_left / FADE_TIME, 0.0, 1.0)
	var d := BLADE_RADIUS * 2.2
	for i in n:
		var a := angle + TAU * i / n
		var c := Vector2(cos(a), sin(a)) * r
		draw_set_transform(c, blade_spin + TAU * i / n, Vector2.ONE)
		draw_texture_rect(BLADE_SPRITE, Rect2(Vector2(-d, -d) * 0.5, Vector2(d, d)), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func upgrade_desc() -> String:
	match level + 1:
		2: return "+1 blade"
		3: return "+5 damage"
		4: return "Wider orbit"
		5: return "+1 blade"
		6: return "+7 damage"
		7: return "Wider orbit"
		8: return "+1 blade"
	return "More power"

extends "res://scripts/weapons/weapon_base.gd"
## Scrap Saw: saw blades orbit the player and shred anything they touch.
## Evolution (+ Reactive Plating): Buzzkill Halo — a dense ring of blades.

const BLADE_RADIUS := 9.0
const HIT_COOLDOWN := 0.45

var angle := 0.0
var _last_hit := {}  # enemy instance id -> time of last hit
var _time := 0.0


func _init() -> void:
	id = "saw"
	display_name = "Scrap Saw"
	paired_passive = "plating"
	evolved_name = "Buzzkill Halo"


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


func _physics_process(delta: float) -> void:
	if main.run_over:
		return
	_time += delta
	angle += spin_speed() * (1.0 + player.attack_speed) * delta
	var r := orbit_radius()
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
	var r := orbit_radius()
	var n := blade_count()
	var col := Color(0.95, 0.75, 0.25) if evolved else Color(0.75, 0.75, 0.78)
	for i in n:
		var a := angle + TAU * i / n
		var c := Vector2(cos(a), sin(a)) * r
		var pts := PackedVector2Array()
		for t in 8:
			var ta := angle * 3.0 + TAU * t / 8.0
			var rad := BLADE_RADIUS if t % 2 == 0 else BLADE_RADIUS * 0.62
			pts.append(c + Vector2(cos(ta), sin(ta)) * rad)
		draw_colored_polygon(pts, col)
		draw_circle(c, 2.5, Color(0.3, 0.3, 0.32))


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

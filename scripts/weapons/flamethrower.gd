extends "res://scripts/weapons/weapon_base.gd"
## Flamethrower: sweeps a cone of fire toward the nearest mutant, ticking
## AoE damage on everything caught inside it.
## Evolution (+ Power Core): Inferno Vent — a huge cone that leaves patches
## of burning ground along its path.

const TICK := 0.25            # base seconds between damage ticks
const AIM_TURN_SPEED := 9.0   # rad/s-ish lerp factor for nozzle tracking
const BURN_PATCH_EVERY := 0.6

var _aim := 0.0
var _target_aim := 0.0
var _heat := 0.0    # 0..1 visual intensity, ramps down when not firing
var _burn_timer := 0.0
var _flicker := 0.0


func _init() -> void:
	id = "flamer"
	display_name = "Flamethrower"
	paired_passive = "core"
	evolved_name = "Inferno Vent"


func cooldown() -> float:
	# The cooldown is the damage tick interval, so attack-speed and
	# cooldown passives raise the flame's tick rate like any other weapon.
	return TICK


func tick_damage() -> float:
	if evolved:
		return dmg(10.0)
	var d := 3.0
	if level >= 3:
		d += 1.0
	if level >= 5:
		d += 1.0
	if level >= 8:
		d += 2.0
	return dmg(d)


func cone_range() -> float:
	if evolved:
		return area(200.0)
	var r := 120.0
	if level >= 2:
		r += 20.0
	if level >= 6:
		r += 25.0
	return area(r)


func half_angle() -> float:
	if evolved:
		return 0.66
	var a := 0.42
	if level >= 4:
		a += 0.08
	if level >= 7:
		a += 0.08
	return a


func _physics_process(delta: float) -> void:
	if main.run_over:
		return
	_flicker += delta
	_aim = lerp_angle(_aim, _target_aim, minf(AIM_TURN_SPEED * delta, 1.0))
	_heat = maxf(_heat - delta * 2.5, 0.0)
	if _burn_timer > 0.0:
		_burn_timer -= delta
	queue_redraw()
	super(delta)


func fire() -> bool:
	var r := cone_range()
	var target: Node2D = main.nearest_enemy(player.position, r)
	if target == null:
		return false
	_target_aim = (target.position - player.position).angle()
	_heat = 1.0
	var ha := half_angle()
	var damage := tick_damage()
	for e in main.enemies_in_range(player.position, r + 24.0):
		var to_e: Vector2 = e.position - player.position
		var d := to_e.length()
		if d > r + e.radius:
			continue
		# Widen the cone check by the enemy's angular size so bodies
		# clipping the edge of the flame still catch fire.
		var pad: float = e.radius / maxf(d, 1.0)
		if absf(angle_difference(_target_aim, to_e.angle())) <= ha + pad:
			e.take_damage(damage, player.position)
	if evolved and _burn_timer <= 0.0:
		_burn_timer = BURN_PATCH_EVERY
		var patch: Vector2 = player.position \
				+ Vector2.from_angle(_target_aim) * r * randf_range(0.4, 0.85)
		main.spawn_burn(patch, area(40.0), dmg(12.0), 2.5)
	Sfx.play("flamer", -8.0)
	return true


func _draw() -> void:
	# Drawn relative to the player (this node sits at the player's origin):
	# layered flickering blobs from nozzle to cone tip, plus a hot core.
	if _heat <= 0.0:
		return
	var r := cone_range() * (0.6 + 0.4 * _heat)
	var ha := half_angle()
	var steps := 7
	for i in steps:
		var t := (float(i) + 0.5) / steps
		var wob := sin(_flicker * 21.0 + i * 2.1) * ha * 0.55 * t
		var c := Vector2.from_angle(_aim + wob) * r * t
		var size := lerpf(5.0, r * tan(ha) * 0.85, t)
		var col := Color(1.0, lerpf(0.9, 0.35, t), lerpf(0.5, 0.05, t),
				_heat * lerpf(0.5, 0.14, t))
		draw_circle(c, size, col)
	var dir := Vector2.from_angle(_aim)
	draw_line(dir * 8.0, dir * r * 0.5, Color(1.0, 0.95, 0.7, _heat * 0.45), 3.0)


func upgrade_desc() -> String:
	match level + 1:
		2: return "Longer reach"
		3: return "+1 damage per tick"
		4: return "Wider cone"
		5: return "+1 damage per tick"
		6: return "Longer reach"
		7: return "Wider cone"
		8: return "+2 damage per tick"
	return "More power"

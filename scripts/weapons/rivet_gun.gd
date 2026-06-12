extends "res://scripts/weapons/weapon_base.gd"
## Rivet Gun: fires rivets at the nearest enemy.
## Evolution (+ Tungsten Rounds): Railspike Driver — massive piercing spikes.

func _init() -> void:
	id = "rivet"
	display_name = "Rivet Gun"
	paired_passive = "tungsten"
	evolved_name = "Railspike Driver"


func cooldown() -> float:
	if evolved:
		return 1.0
	var c := 0.9
	if level >= 4:
		c *= 0.85
	return c


func shot_count() -> int:
	var n := 1
	if level >= 2:
		n += 1
	if level >= 5:
		n += 1
	if level >= 8:
		n += 1
	return n + player.extra_projectiles


func shot_damage() -> float:
	if evolved:
		return dmg(60.0)
	var d := 8.0
	if level >= 3:
		d += 4.0
	if level >= 6:
		d += 6.0
	if level >= 8:
		d += 6.0
	return dmg(d)


func shot_pierce() -> int:
	if evolved:
		return 50
	var p := 0
	if level >= 7:
		p += 1
	return p + player.extra_pierce


func fire() -> bool:
	var target: Node2D = main.nearest_enemy(player.position, 420.0)
	if target == null:
		return false
	var base_dir := (target.position - player.position).normalized()
	var n := shot_count()
	for i in n:
		var spread := (i - (n - 1) * 0.5) * 0.12
		var dir := base_dir.rotated(spread)
		if evolved:
			spawn_projectile(player.position, dir * 720.0, shot_damage(), shot_pierce(), "spike", 7.0, 1.2)
		else:
			spawn_projectile(player.position, dir * 430.0, shot_damage(), shot_pierce(), "rivet", 5.0, 1.6)
	Sfx.play("spike" if evolved else "rivet", -4.0)
	return true


func upgrade_desc() -> String:
	match level + 1:
		2: return "+1 rivet"
		3: return "+4 damage"
		4: return "+15% fire rate"
		5: return "+1 rivet"
		6: return "+6 damage"
		7: return "+1 pierce"
		8: return "+1 rivet, +6 damage"
	return "More power"

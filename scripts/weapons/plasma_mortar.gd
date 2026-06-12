extends "res://scripts/weapons/weapon_base.gd"
## Plasma Mortar: lobs an AoE shell at the densest mutant cluster.
## Evolution (+ Wide-Area Emitter): Sunfire Battery — huge blasts that leave
## burning ground.

func _init() -> void:
	id = "mortar"
	display_name = "Plasma Mortar"
	paired_passive = "emitter"
	evolved_name = "Sunfire Battery"


func cooldown() -> float:
	if evolved:
		return 2.4
	var c := 2.8
	if level >= 4:
		c -= 0.4
	if level >= 7:
		c -= 0.4
	return c


func shell_count() -> int:
	var n := 1
	if level >= 5:
		n += 1
	if evolved:
		n = 2
	return n + player.extra_projectiles


func shell_damage() -> float:
	if evolved:
		return dmg(55.0)
	var d := 25.0
	if level >= 3:
		d += 10.0
	if level >= 6:
		d += 12.0
	if level >= 8:
		d += 12.0
	return dmg(d)


func blast_radius() -> float:
	if evolved:
		return area(110.0)
	var r := 70.0
	if level >= 2:
		r += 10.0
	if level >= 8:
		r += 10.0
	return area(r)


func fire() -> bool:
	if main.enemies.is_empty():
		return false
	var fired := false
	for i in shell_count():
		var target: Vector2 = main.densest_cluster_pos(player.position, 460.0)
		target += Vector2(randf_range(-40, 40), randf_range(-40, 40)) * float(i)
		var dir := (target - player.position).normalized()
		var p: Node2D = spawn_projectile(player.position, dir * 300.0, shell_damage(), 0, "shell", 6.0, 4.0)
		p.target_point = target
		p.explode_radius = blast_radius()
		p.burn = evolved
		p.burn_dps = dmg(9.0) if evolved else 0.0
		fired = true
	if fired:
		Sfx.play("mortar", -3.0)
	return fired


func upgrade_desc() -> String:
	match level + 1:
		2: return "Bigger blast"
		3: return "+10 damage"
		4: return "Faster reload"
		5: return "+1 shell"
		6: return "+12 damage"
		7: return "Faster reload"
		8: return "+12 damage, bigger blast"
	return "More power"

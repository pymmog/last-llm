extends "res://scripts/weapons/weapon_base.gd"
## Nano Swarm: launches volleys of homing nano-drones.
## Evolution (+ Targeting Matrix): Gray Goo — bigger volleys that pierce.

func _init() -> void:
	id = "swarm"
	display_name = "Nano Swarm"
	paired_passive = "matrix"
	evolved_name = "Gray Goo"


func cooldown() -> float:
	if evolved:
		return 1.6
	var c := 2.2
	if level >= 4:
		c -= 0.3
	if level >= 7:
		c -= 0.3
	return c


func drone_count() -> int:
	if evolved:
		return 8 + player.extra_projectiles
	var n := 2
	if level >= 2:
		n += 1
	if level >= 5:
		n += 1
	if level >= 8:
		n += 2
	return n + player.extra_projectiles


func drone_damage() -> float:
	if evolved:
		return dmg(14.0)
	var d := 7.0
	if level >= 3:
		d += 3.0
	if level >= 6:
		d += 4.0
	return dmg(d)


func fire() -> bool:
	if main.nearest_enemy(player.position, 500.0) == null:
		return false
	var n := drone_count()
	for i in n:
		var a := TAU * i / n + randf() * 0.5
		var p: Node2D = spawn_projectile(
			player.position, Vector2(cos(a), sin(a)) * 240.0,
			drone_damage(), (2 if evolved else 0) + player.extra_pierce,
			"drone", 6.0, 4.0)
		p.homing = true
		p.turn_rate = 5.0
	Sfx.play("swarm", -6.0)
	return true


func upgrade_desc() -> String:
	match level + 1:
		2: return "+1 drone"
		3: return "+3 damage"
		4: return "Faster launch"
		5: return "+1 drone"
		6: return "+4 damage"
		7: return "Faster launch"
		8: return "+2 drones"
	return "More power"

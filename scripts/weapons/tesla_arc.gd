extends "res://scripts/weapons/weapon_base.gd"
## Tesla Arc: zaps a random nearby enemy, chaining to neighbors.
## Evolution (+ Capacitor Bank): Storm Coil — rapid, far-reaching chains.

func _init() -> void:
	id = "tesla"
	display_name = "Tesla Arc"
	paired_passive = "capacitor"
	evolved_name = "Storm Coil"


func cooldown() -> float:
	if evolved:
		return 0.55
	var c := 1.6
	if level >= 4:
		c -= 0.2
	if level >= 7:
		c -= 0.2
	return c


func chain_links() -> int:
	if evolved:
		return 8
	var n := 3
	if level >= 2:
		n += 1
	if level >= 5:
		n += 1
	if level >= 8:
		n += 1
	return n


func zap_damage() -> float:
	if evolved:
		return dmg(30.0)
	var d := 10.0
	if level >= 3:
		d += 6.0
	if level >= 6:
		d += 8.0
	return dmg(d)


func chain_range() -> float:
	return area(200.0 if evolved else 150.0)


func fire() -> bool:
	var arcs: int = 1 + player.extra_projectiles
	var fired := false
	for i in arcs:
		var start: Node2D = main.random_enemy_in_range(player.position, area(320.0))
		if start == null:
			break
		fired = true
		_zap_chain(start)
	return fired


func _zap_chain(start: Node2D) -> void:
	var damage := zap_damage()
	var visited := {}
	var points := PackedVector2Array([player.position])
	var current: Node2D = start
	for link in chain_links():
		if current == null:
			break
		points.append(current.position)
		visited[current.get_instance_id()] = true
		current.take_damage(damage, player.position)
		current = _next_link(current, visited)
	main.spawn_fx("lightning", Vector2.ZERO, 0.0, Color(0.55, 0.85, 1.0), points)


func _next_link(from: Node2D, visited: Dictionary) -> Node2D:
	var best: Node2D = null
	var r := chain_range()
	var best_d := r * r
	for e in main.enemies:
		if not is_instance_valid(e) or e.dead or visited.has(e.get_instance_id()):
			continue
		var d: float = from.position.distance_squared_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func upgrade_desc() -> String:
	match level + 1:
		2: return "+1 chain link"
		3: return "+6 damage"
		4: return "Faster zaps"
		5: return "+1 chain link"
		6: return "+8 damage"
		7: return "Faster zaps"
		8: return "+1 chain link"
	return "More power"

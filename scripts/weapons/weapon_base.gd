extends Node2D
## Base for all auto-attacking weapons. Subclasses override fire(), cooldown()
## and the level/evolution hooks. Lives under the player's WeaponHolder.

const MAX_LEVEL := 8
const ProjectileScript := preload("res://scripts/weapons/projectile.gd")

var main: Node2D
var player: Node2D

var id := ""
var display_name := ""
var paired_passive := ""      # passive required (any level) to evolve
var evolved_name := ""
var level := 1
var evolved := false
var cd := 0.5


func _physics_process(delta: float) -> void:
	if main.run_over:
		return
	cd -= delta
	if cd <= 0.0:
		if fire():
			cd = effective_cooldown()
		else:
			cd = 0.15  # no target: rescan shortly


func effective_cooldown() -> float:
	return cooldown() * (1.0 - player.cooldown_red) / (1.0 + player.attack_speed)


func cooldown() -> float:
	return 1.0


func fire() -> bool:
	return true


func dmg(base: float) -> float:
	return base * player.damage_mult


func area(base: float) -> float:
	return base * player.area_mult


func level_up() -> void:
	level = mini(level + 1, MAX_LEVEL)


func can_evolve() -> bool:
	return level >= MAX_LEVEL and not evolved and player.passive_level(paired_passive) > 0


func evolve() -> void:
	evolved = true
	display_name = evolved_name
	cd = 0.0


func upgrade_desc() -> String:
	## Card text for the next level.
	return "More power"


func spawn_projectile(pos: Vector2, vel: Vector2, damage: float, pierce: int,
		style: String, radius: float = 5.0, life: float = 2.0) -> Node2D:
	var p: Node2D = ProjectileScript.new()
	p.main = main
	p.position = pos
	p.vel = vel
	p.damage = damage
	p.pierce = pierce
	p.style = style
	p.radius = radius
	p.life = life
	main.projectiles_node.add_child(p)
	return p

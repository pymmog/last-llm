extends Node2D
## Touch pickups: medkit (+25% HP), scrap (meta currency), magnet (vacuum all
## gems), crate (1-of-6 upgrade pick from minibosses).

const SPRITE_SCALE := 3
const SPRITES := {
	"medkit": preload("res://assets/sprites/pickup_medkit.png"),
	"scrap": preload("res://assets/sprites/pickup_scrap.png"),
	"magnet": preload("res://assets/sprites/pickup_magnet.png"),
	"crate": preload("res://assets/sprites/pickup_crate.png"),
}

var main: Node2D
var kind := "scrap"
var value := 1
var bob := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bob = randf() * TAU


func _physics_process(delta: float) -> void:
	if main.run_over:
		return
	bob += delta * 3.0
	var player: Node2D = main.player
	var reach := 30.0 if kind == "crate" else 22.0
	if position.distance_squared_to(player.position) < pow(reach + player.radius, 2.0):
		collect(player)
		return
	queue_redraw()


func collect(player: Node2D) -> void:
	match kind:
		"medkit":
			player.heal(player.max_hp * 0.25)
			Sfx.play("heal")
		"scrap":
			main.scrap_earned += value
			main.add_damage_number(position, value, Color(0.85, 0.85, 0.85))
			Sfx.play("pickup", -4.0)
		"magnet":
			for gem in get_tree().get_nodes_in_group("xp_gems"):
				gem.force_attract()
			main.spawn_fx("ring", position, 60.0, Color(0.4, 0.6, 1.0))
			Sfx.play("magnet")
		"crate":
			main.open_crate()
	main.spawn_fx("pop", position, 14.0, Color(1, 1, 1))
	queue_free()


func _draw() -> void:
	var y := sin(bob) * 2.0
	var tex: Texture2D = SPRITES[kind]
	var size := tex.get_size() / SPRITE_SCALE
	if kind == "crate":
		size *= 1.25
	if kind == "medkit":
		size.y *= 1.45
	draw_texture_rect(tex, Rect2(Vector2(-size.x * 0.5, y - size.y * 0.5), size), false)
	# Soft glint so pickups still pop against the dark floor.
	draw_circle(Vector2(0, y), size.x * 0.7, Color(1, 1, 1, 0.05 + 0.04 * sin(bob * 2.0)))

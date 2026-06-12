extends Node2D
## XP gem: idles until the player's pickup radius reaches it, then vacuums in.

const SPRITE: Texture2D = preload("res://assets/sprites/xp_gem.png")
const SPRITE_SCALE := 3

var main: Node2D
var value := 1.0
var attracting := false
var pull_speed := 240.0
var sparkle := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("xp_gems")
	sparkle = randf() * TAU


func force_attract() -> void:
	attracting = true


func _physics_process(delta: float) -> void:
	if main.run_over:
		return
	var player: Node2D = main.player
	var to_player: Vector2 = player.position - position
	var d2 := to_player.length_squared()
	if not attracting and d2 < player.pickup_radius * player.pickup_radius:
		attracting = true
	if attracting:
		pull_speed = minf(pull_speed + 900.0 * delta, 760.0)
		position += to_player.normalized() * pull_speed * delta
		if d2 < 18.0 * 18.0:
			Sfx.play("xp", -8.0)
			player.add_xp(value)
			queue_free()
			return
	sparkle += delta * 3.0
	queue_redraw()


func _draw() -> void:
	# Pale sprite, tinted per XP tier (texture is near-white so modulate ≈ tint).
	var s := 4.0
	var col := Color(0.25, 0.95, 0.9)
	if value >= 20.0:
		s = 7.0
		col = Color(0.95, 0.5, 0.95)
	elif value >= 5.0:
		s = 5.5
		col = Color(0.35, 0.6, 1.0)
	var pulse := 1.0 + sin(sparkle) * 0.15
	var size := SPRITE.get_size() / SPRITE_SCALE * (s / 4.0) * pulse
	draw_texture_rect(SPRITE, Rect2(-size * 0.5, size), false, col)

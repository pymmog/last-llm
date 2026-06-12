extends Node2D
## UNIT-7: movement-only control. All stats live here; weapons and passives
## read them when firing. Drawn as a generated PS1-style salvage robot sprite.

const Upgrades := preload("res://scripts/upgrades.gd")
const PS1_TREAD_FRAMES := [
	preload("res://assets/sprites/unit7_tread_0.png"),
	preload("res://assets/sprites/unit7_tread_1.png"),
	preload("res://assets/sprites/unit7_tread_2.png"),
	preload("res://assets/sprites/unit7_tread_3.png"),
]
const PS1_SPRITE_HEIGHT := 44.0

var main: Node2D
var camera: Camera2D
var weapon_holder: Node2D

# Live stats (recomputed from base + meta unlocks + passives).
var max_hp := 100.0
var hp := 100.0
var regen := 0.0
var armor := 0.0
var move_speed := 150.0
var pickup_radius := 60.0
var damage_mult := 1.0
var attack_speed := 0.0
var cooldown_red := 0.0
var area_mult := 1.0
var extra_projectiles := 0
var extra_pierce := 0

var passives: Dictionary = {}   # id -> level
var weapons: Array = []         # weapon nodes

var level := 1
var xp := 0.0
var xp_needed := 10.0
var pending_levels := 0

var shield_ready := false
var shield_timer := 0.0

var radius := 12.0
var god_mode := false  # dev debug: ignore all incoming damage
var invuln := 0.0
var facing := 1.0
var anim_t := 0.0
var moving := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	camera = Camera2D.new()
	camera.zoom = Vector2(1.0, 1.0)
	add_child(camera)
	camera.make_current()
	weapon_holder = Node2D.new()
	weapon_holder.name = "Weapons"
	add_child(weapon_holder)
	recompute_stats()
	hp = max_hp
	xp_needed = xp_for_level(level)


func start() -> void:
	add_weapon("rivet")


func _physics_process(delta: float) -> void:
	if main.run_over:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = dir.length_squared() > 0.01
	if moving:
		position += dir * move_speed * delta
		if absf(dir.x) > 0.1:
			facing = signf(dir.x)
		anim_t += delta * 10.0
	if regen > 0.0:
		hp = minf(hp + regen * delta, max_hp)
	if passive_level("deflector") > 0 and not shield_ready:
		shield_timer -= delta
		if shield_timer <= 0.0:
			shield_ready = true
			Sfx.play("shield_up", -4.0)
			main.spawn_fx("ring", position, 26.0, Color(0.35, 0.85, 1.0))
	invuln = maxf(invuln - delta, 0.0)
	queue_redraw()


# ---------------------------------------------------------------- stats

func passive_level(id: String) -> int:
	return int(passives.get(id, 0))


func recompute_stats() -> void:
	var hp_frac := 1.0 if max_hp <= 0.0 else hp / max_hp
	max_hp = 100.0 + Meta.bonus("max_hp") + passive_level("chassis") * 20.0
	hp = max_hp * hp_frac
	regen = Meta.bonus("regen") + passive_level("nanites") * 0.4
	armor = Meta.bonus("armor") + passive_level("plating") * 1.0
	move_speed = 150.0 * (1.0 + Meta.bonus("speed") + passive_level("legs") * 0.08)
	pickup_radius = 60.0 * (1.0 + Meta.bonus("magnet") + passive_level("magnet") * 0.20)
	damage_mult = 1.0 + Meta.bonus("damage") + passive_level("core") * 0.08
	attack_speed = passive_level("servo") * 0.08
	cooldown_red = minf(passive_level("capacitor") * 0.06, 0.5)
	area_mult = 1.0 + passive_level("emitter") * 0.10
	extra_projectiles = passive_level("matrix")
	extra_pierce = passive_level("tungsten")


func add_passive(id: String) -> void:
	var was := passive_level(id)
	passives[id] = was + 1
	recompute_stats()
	if id == "chassis":
		heal(20.0)
	elif id == "deflector" and was == 0:
		shield_ready = true


func shield_recharge_time() -> float:
	return 16.0 - 2.5 * (passive_level("deflector") - 1)


func add_weapon(id: String) -> void:
	var script: GDScript = load(Upgrades.WEAPONS[id]["script"])
	var w: Node2D = script.new()
	w.main = main
	w.player = self
	weapons.append(w)
	weapon_holder.add_child(w)


func get_weapon(id: String) -> Node2D:
	for w in weapons:
		if w.id == id:
			return w
	return null


# ---------------------------------------------------------------- xp / hp

func xp_for_level(lv: int) -> float:
	return 4.0 + lv * 3.0 + pow(lv, 1.6)


func add_xp(value: float) -> void:
	xp += value
	var leveled := false
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = xp_for_level(level)
		pending_levels += 1
		leveled = true
	if leveled:
		Sfx.play("level_up")
		main.spawn_fx("ring", position, 40.0, Color(0.3, 1.0, 0.9))
		main.hud.on_level_up()


func take_damage(amount: float, from: Vector2 = Vector2.INF) -> void:
	if invuln > 0.0 or main.run_over or god_mode:
		return
	if shield_ready:
		shield_ready = false
		shield_timer = shield_recharge_time()
		invuln = 0.6
		Sfx.play("shield_break", -2.0)
		main.spawn_fx("ring", position, 34.0, Color(0.35, 0.85, 1.0))
		main.spawn_fx("spark", position, 12.0, Color(0.5, 0.9, 1.0))
		queue_redraw()
		return
	var dealt := maxf(amount - armor, 1.0)
	hp -= dealt
	invuln = 0.4
	Sfx.play("player_hurt", -2.0)
	var hit_dir := (position - from).normalized() if from.is_finite() else Vector2.from_angle(randf() * TAU)
	main.add_shake(6.0)
	main.hitstop(0.05)
	main.spawn_fx("spark", position, 16.0, Color(1.0, 0.75, 0.3), PackedVector2Array(), hit_dir)
	main.hud.flash_damage()
	main.add_damage_number(position, dealt, Color(1.0, 0.35, 0.3))
	if hp <= 0.0:
		hp = 0.0
		Sfx.play("player_die")
		main.add_shake(14.0)
		main.spawn_fx("pop", position, 40.0, Color(1.0, 0.5, 0.2))
		main.spawn_fx("ring", position, 70.0, Color(1.0, 0.4, 0.2))
		main.spawn_fx("spark", position, 30.0, Color(1.0, 0.6, 0.2))
		main.end_run(false)
	queue_redraw()


func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)
	main.add_damage_number(position, amount, Color(0.4, 1.0, 0.4))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f := facing
	var glow := Color(0.08, 0.95, 1.0)
	var modulate := Color(1, 1, 1, 1)
	if invuln > 0.0 and fmod(invuln, 0.12) > 0.06:
		modulate = Color(1.8, 1.8, 1.8, 1)
	var frame: Texture2D = PS1_TREAD_FRAMES[int(anim_t) % PS1_TREAD_FRAMES.size()] if moving else PS1_TREAD_FRAMES[0]
	# Treads stay planted; vertical bob against a fixed shadow reads as hovering.
	var foot := Vector2(0, 16)
	# Shadow
	draw_ellipse_approx(Vector2(0, 14), Vector2(16, 5.0), Color(0, 0, 0, 0.32))
	draw_ellipse_approx(Vector2(1.5 * f, 11.5), Vector2(10, 3.0), Color(glow.r, glow.g, glow.b, 0.08))

	# Source sprite faces left; flip when facing right.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-f, 1.0))
	draw_ps1_sprite(frame, PS1_SPRITE_HEIGHT, foot, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if shield_ready:
		var pulse := 0.45 + 0.15 * sin(Time.get_ticks_msec() * 0.005)
		var sc := Color(0.35, 0.85, 1.0)
		draw_arc(Vector2(0, -6), 24.0, 0.0, TAU, 32, Color(sc.r, sc.g, sc.b, pulse), 1.5)
		draw_arc(Vector2(0, -6), 27.0, 0.0, TAU, 32, Color(sc.r, sc.g, sc.b, pulse * 0.3), 3.0)


func draw_ellipse_approx(center: Vector2, r: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, color)


func draw_ps1_sprite(texture: Texture2D, target_height: float, foot: Vector2, modulate: Color) -> void:
	var tex_size := texture.get_size()
	var target_width := target_height * tex_size.x / tex_size.y
	var rect := Rect2(
		Vector2(-target_width * 0.5, foot.y - target_height),
		Vector2(target_width, target_height)
	)
	draw_texture_rect(texture, rect, false, modulate)

extends Node2D
## Endless wasteland floor: cracked earth, rocks, debris and bones scattered
## deterministically per grid cell around the camera. Props use the generated
## PS1 sprite set (tools/generate_ps1_sprites.gd); cracks and dirt stay vector.

const CELL := 120.0
const GROUND_TILE := 144.0
const SPRITE_SCALE := 3  # generated PNGs are saved at 3x their logical size

const GROUND_TEX := preload("res://assets/sprites/env_ground_tile.png")
const PROPS := {
	"rock_a": preload("res://assets/sprites/prop_rock_a.png"),
	"rock_b": preload("res://assets/sprites/prop_rock_b.png"),
	"bones": preload("res://assets/sprites/prop_bones.png"),
	"shrub": preload("res://assets/sprites/prop_shrub.png"),
	"plate": preload("res://assets/sprites/prop_plate.png"),
	"scrap_pile": preload("res://assets/sprites/prop_scrap_pile.png"),
	"cable_coil": preload("res://assets/sprites/prop_cable_coil.png"),
	"barrel": preload("res://assets/sprites/prop_barrel.png"),
	"ruined_console": preload("res://assets/sprites/prop_ruined_console.png"),
}

var _last_cam := Vector2(99999, 99999)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if cam.get_screen_center_position().distance_squared_to(_last_cam) > 16.0:
		_last_cam = cam.get_screen_center_position()
		queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position()
	var half := get_viewport_rect().size * 0.5 + Vector2(CELL, CELL)
	_draw_ground(center, half)
	var x0 := int(floorf((center.x - half.x) / CELL))
	var x1 := int(ceilf((center.x + half.x) / CELL))
	var y0 := int(floorf((center.y - half.y) / CELL))
	var y1 := int(ceilf((center.y + half.y) / CELL))
	for cy in range(y0, y1):
		for cx in range(x0, x1):
			_draw_cell(cx, cy)


func _draw_ground(center: Vector2, half: Vector2) -> void:
	draw_rect(Rect2(center - half, half * 2.0), Color(0.13, 0.11, 0.085))
	var tx0 := int(floorf((center.x - half.x) / GROUND_TILE))
	var tx1 := int(ceilf((center.x + half.x) / GROUND_TILE))
	var ty0 := int(floorf((center.y - half.y) / GROUND_TILE))
	var ty1 := int(ceilf((center.y + half.y) / GROUND_TILE))
	for ty in range(ty0, ty1):
		for tx in range(tx0, tx1):
			draw_texture_rect(
				GROUND_TEX,
				Rect2(Vector2(tx, ty) * GROUND_TILE, Vector2(GROUND_TILE, GROUND_TILE)),
				false,
				Color(0.82, 0.8, 0.76, 0.82)
			)


func _draw_cell(cx: int, cy: int) -> void:
	var h := _hash(cx, cy)
	var base := Vector2(cx * CELL, cy * CELL)
	var ox := float((h >> 4) & 63) / 63.0 * CELL
	var oy := float((h >> 10) & 63) / 63.0 * CELL
	var p := base + Vector2(ox, oy)
	match h % 17:
		0, 1:
			# Dirt patch.
			draw_circle(p, 18.0 + float(h % 17), Color(0.09, 0.078, 0.06, 0.78))
		2, 3:
			# Crack in the earth.
			var a := float(h % 7) * 0.9
			var dir := Vector2(cos(a), sin(a))
			var q := p
			for i in 4:
				var nq: Vector2 = q + dir.rotated(float((h >> i) % 5 - 2) * 0.3) * 18.0
				draw_line(q, nq, Color(0.055, 0.048, 0.038), 2.0)
				q = nq
		4:
			# Rock.
			_draw_prop("rock_a" if (h >> 7) & 1 else "rock_b", p, h)
		5:
			# Bones.
			_draw_prop("bones", p, h)
		6:
			# Dead shrub.
			_draw_prop("shrub", p, h)
		7:
			# Scrap plate.
			_draw_prop("plate", p, h)
		8:
			# Salvage pile with muted orange/cyan accents.
			_draw_prop("scrap_pile", p, h)
		9:
			# Old power cable.
			_draw_prop("cable_coil", p, h)
		10:
			# Rusted drum.
			_draw_prop("barrel", p, h)
		11:
			# Broken console remnant.
			_draw_prop("ruined_console", p, h)
		12:
			# Oil stain and a tiny dead indicator light.
			draw_circle(p, 13.0 + float(h % 9), Color(0.03, 0.028, 0.025, 0.55))
			draw_circle(p + Vector2(7, -3), 1.4, Color(0.0, 0.45, 0.42, 0.42))
		_:
			# Pebbles.
			draw_circle(p, 2.2, Color(0.16, 0.145, 0.12))
			draw_circle(p + Vector2(7, 4), 1.6, Color(0.18, 0.16, 0.13))


func _draw_prop(prop_name: String, p: Vector2, h: int) -> void:
	var tex: Texture2D = PROPS[prop_name]
	# 1.6x: keeps the chunky pixels readable against the dark floor.
	var size := tex.get_size() / SPRITE_SCALE * 1.6
	var rect := Rect2(p - size * 0.5, size)
	if (h >> 9) & 1:
		rect.position.x += size.x
		rect.size.x = -size.x
	# Slightly darkened so ground props never compete with actors.
	draw_texture_rect(tex, rect, false, Color(0.92, 0.9, 0.88))


func _hash(x: int, y: int) -> int:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return absi(n ^ (n >> 16))

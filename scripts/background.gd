extends Node2D
## Endless wasteland floor: cracked earth, rocks, debris and bones scattered
## deterministically per grid cell around the camera. No texture assets.

const CELL := 120.0

var _last_cam := Vector2(99999, 99999)


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
	# Base ground.
	draw_rect(Rect2(center - half, half * 2.0), Color(0.16, 0.14, 0.11))
	var x0 := int(floorf((center.x - half.x) / CELL))
	var x1 := int(ceilf((center.x + half.x) / CELL))
	var y0 := int(floorf((center.y - half.y) / CELL))
	var y1 := int(ceilf((center.y + half.y) / CELL))
	for cy in range(y0, y1):
		for cx in range(x0, x1):
			_draw_cell(cx, cy)


func _draw_cell(cx: int, cy: int) -> void:
	var h := _hash(cx, cy)
	var base := Vector2(cx * CELL, cy * CELL)
	var ox := float((h >> 4) & 63) / 63.0 * CELL
	var oy := float((h >> 10) & 63) / 63.0 * CELL
	var p := base + Vector2(ox, oy)
	match h % 11:
		0, 1:
			# Dirt patch.
			draw_circle(p, 18.0 + float(h % 17), Color(0.13, 0.115, 0.09))
		2, 3:
			# Crack in the earth.
			var a := float(h % 7) * 0.9
			var dir := Vector2(cos(a), sin(a))
			var q := p
			for i in 4:
				var nq: Vector2 = q + dir.rotated(float((h >> i) % 5 - 2) * 0.3) * 18.0
				draw_line(q, nq, Color(0.09, 0.08, 0.06), 2.0)
				q = nq
		4:
			# Rock.
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(-9, 4), p + Vector2(-4, -7), p + Vector2(6, -5),
				p + Vector2(9, 3), p + Vector2(2, 7)]), Color(0.24, 0.22, 0.2))
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(-4, -2), p + Vector2(2, -5), p + Vector2(5, 0)]),
				Color(0.3, 0.28, 0.26))
		5:
			# Bones.
			draw_line(p, p + Vector2(14, 5), Color(0.55, 0.52, 0.46), 2.5)
			draw_circle(p + Vector2(16, 6), 3.0, Color(0.55, 0.52, 0.46))
			draw_circle(p + Vector2(-2, -1), 2.2, Color(0.55, 0.52, 0.46))
		6:
			# Dead shrub.
			for i in 4:
				var a2 := -PI * 0.5 + (float(i) - 1.5) * 0.5
				draw_line(p, p + Vector2(cos(a2), sin(a2)) * 11.0, Color(0.27, 0.2, 0.12), 1.5)
		7:
			# Scrap plate.
			draw_rect(Rect2(p.x, p.y, 13, 9), Color(0.22, 0.21, 0.22))
			draw_rect(Rect2(p.x + 2, p.y + 2, 3, 2), Color(0.45, 0.3, 0.2))
		_:
			# Pebbles.
			draw_circle(p, 2.2, Color(0.2, 0.18, 0.15))
			draw_circle(p + Vector2(7, 4), 1.6, Color(0.2, 0.18, 0.15))


func _hash(x: int, y: int) -> int:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return absi(n ^ (n >> 16))

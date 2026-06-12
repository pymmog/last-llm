extends RefCounted
## Shared _draw() helpers for actors rendered from generated PS1 sprites
## (player, enemies, future bosses). Pass the drawing CanvasItem as `item`.


static func ps1_sprite(item: CanvasItem, texture: Texture2D, target_height: float,
		foot: Vector2, modulate: Color) -> void:
	## Draws `texture` scaled to `target_height` with its bottom edge at foot.y,
	## centered horizontally, preserving aspect ratio.
	var tex_size := texture.get_size()
	var target_width := target_height * tex_size.x / tex_size.y
	var rect := Rect2(
		Vector2(-target_width * 0.5, foot.y - target_height),
		Vector2(target_width, target_height)
	)
	item.draw_texture_rect(texture, rect, false, modulate)


static func ellipse(item: CanvasItem, center: Vector2, r: Vector2, col: Color,
		segments: int = 16) -> void:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
	item.draw_colored_polygon(pts, col)

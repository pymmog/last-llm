extends SceneTree

const SOURCE := "res://assets/sprites/ps1_walk_source.png"
const OUT_DIR := "res://assets/sprites/"
const NAMES := ["unit7", "shambler", "sprinter", "spitter", "brute"]
const ROWS := 5
const COLS := 4
const PAD := 18


func _init() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null or source.is_empty():
		push_error("Could not load %s" % SOURCE)
		quit(1)
		return

	var row_ranges := _find_y_ranges(source)
	if row_ranges.size() != ROWS:
		push_error("Expected %d sprite rows, found %d" % [ROWS, row_ranges.size()])
		quit(1)
		return

	for row in ROWS:
		var x_ranges := _find_x_ranges(source, row_ranges[row])
		if x_ranges.size() != COLS:
			push_error("Expected %d frames for %s, found %d" % [COLS, NAMES[row], x_ranges.size()])
			quit(1)
			return
		var frame_bounds := []
		var canvas_size := Vector2i.ZERO
		for col in COLS:
			var bounds := _find_content_bounds(source, x_ranges[col], row_ranges[row])
			frame_bounds.append(bounds)
			canvas_size.x = maxi(canvas_size.x, bounds.size.x + PAD * 2)
			canvas_size.y = maxi(canvas_size.y, bounds.size.y + PAD * 2)
		for col in COLS:
			_save_frame(source, row, col, frame_bounds[col], canvas_size)

	_keyed_copy(source).save_png(OUT_DIR + "ps1_walk_atlas.png")
	print("Extracted %d walk frames from %s" % [ROWS * COLS, SOURCE])
	quit()


func _find_y_ranges(image: Image) -> Array:
	var counts := []
	for y in image.get_height():
		var count := 0
		for x in image.get_width():
			if _alpha_for(image.get_pixel(x, y)) > 0.18:
				count += 1
		counts.append(count)
	return _ranges_from_counts(counts, 16, 45, 14)


func _find_x_ranges(image: Image, y_range: Vector2i) -> Array:
	var counts := []
	for x in image.get_width():
		var count := 0
		for y in range(y_range.x, y_range.y + 1):
			if _alpha_for(image.get_pixel(x, y)) > 0.18:
				count += 1
		counts.append(count)
	return _ranges_from_counts(counts, 10, 45, 24)


func _ranges_from_counts(counts: Array, threshold: int, min_size: int, max_gap: int) -> Array:
	var ranges := []
	var in_range := false
	var start := 0
	var last_hit := 0
	for i in counts.size():
		if int(counts[i]) >= threshold:
			if not in_range:
				start = i
				in_range = true
			last_hit = i
		elif in_range and i - last_hit > max_gap:
			if last_hit - start + 1 >= min_size:
				ranges.append(Vector2i(start, last_hit))
			in_range = false
	if in_range and last_hit - start + 1 >= min_size:
		ranges.append(Vector2i(start, last_hit))
	return ranges


func _find_content_bounds(image: Image, x_range: Vector2i, y_range: Vector2i) -> Rect2i:
	var min_x := x_range.y
	var min_y := y_range.y
	var max_x := 0
	var max_y := 0
	for y in range(y_range.x, y_range.y + 1):
		for x in range(x_range.x, x_range.y + 1):
			if _alpha_for(image.get_pixel(x, y)) > 0.18:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _save_frame(source: Image, row: int, col: int, bounds: Rect2i, canvas_size: Vector2i) -> void:
	var out := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color.TRANSPARENT)
	var dest_x := int(round((canvas_size.x - bounds.size.x) * 0.5))
	var dest_y := canvas_size.y - PAD - bounds.size.y
	for y in bounds.size.y:
		for x in bounds.size.x:
			var color := source.get_pixel(bounds.position.x + x, bounds.position.y + y)
			color.a = _alpha_for(color)
			if color.a < 1.0:
				color.r = 0.0
				color.g = 0.0
				color.b = 0.0
			out.set_pixel(dest_x + x, dest_y + y, color)
	var path := OUT_DIR + "%s_walk_%d.png" % [NAMES[row], col]
	out.save_png(path)
	print("%s %sx%s" % [path, canvas_size.x, canvas_size.y])


func _keyed_copy(source: Image) -> Image:
	var out := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x, y)
			color.a = _alpha_for(color)
			if color.a < 1.0:
				color.r = 0.0
				color.g = 0.0
				color.b = 0.0
			out.set_pixel(x, y, color)
	return out


func _is_key(color: Color) -> bool:
	return color.r8 >= 180 and color.g8 <= 96 and color.b8 >= 180 and color.r8 - color.g8 >= 96 and color.b8 - color.g8 >= 96


func _alpha_for(color: Color) -> float:
	if _is_key(color):
		return 0.0
	var dr := absi(color.r8 - 255)
	var dg := color.g8
	var db := absi(color.b8 - 255)
	var dist := maxi(maxi(dr, dg), db)
	if dist <= 18:
		return 0.0
	if dist >= 96:
		return color.a
	var t := float(dist - 18) / 78.0
	return color.a * t * t * (3.0 - 2.0 * t)

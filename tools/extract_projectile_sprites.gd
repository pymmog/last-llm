extends SceneTree
## Extracts generated projectile sprites from a chroma-key source atlas.
##
## Run: godot --headless -s tools/extract_projectile_sprites.gd

const SOURCE := "res://assets/sprites/weapon_projectiles_source.png"
const OUT_DIR := "res://assets/sprites/"
const NAMES := [
	"projectile_rivet",
	"projectile_spike",
	"projectile_drone",
	"projectile_shell",
	"projectile_saw_blade",
]
const PAD := 18


func _init() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null or source.is_empty():
		push_error("Could not load %s" % SOURCE)
		quit(1)
		return

	var width := source.get_width()
	var height := source.get_height()
	var cell_width := float(width) / NAMES.size()
	for i in NAMES.size():
		var x0 := int(round(i * cell_width))
		var x1 := int(round((i + 1) * cell_width))
		var bounds := _find_bounds(source, x0, x1, height)
		if bounds.size == Vector2i.ZERO:
			push_error("No sprite pixels found for %s" % NAMES[i])
			quit(1)
			return
		_save_sprite(source, bounds, OUT_DIR + NAMES[i] + ".png")

	_keyed_copy(source).save_png(OUT_DIR + "weapon_projectiles_atlas.png")
	print("Extracted %d projectile sprites from %s" % [NAMES.size(), SOURCE])
	quit()


func _find_bounds(image: Image, x0: int, x1: int, height: int) -> Rect2i:
	var min_x := x1
	var min_y := height
	var max_x := x0
	var max_y := 0
	for y in height:
		for x in range(x0, x1):
			if _alpha_for(image.get_pixel(x, y)) > 0.18:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()

	min_x = maxi(min_x - PAD, x0)
	min_y = maxi(min_y - PAD, 0)
	max_x = mini(max_x + PAD, x1 - 1)
	max_y = mini(max_y + PAD, height - 1)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _save_sprite(source: Image, bounds: Rect2i, path: String) -> void:
	var out := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color.TRANSPARENT)
	for y in bounds.size.y:
		for x in bounds.size.x:
			var color := source.get_pixel(bounds.position.x + x, bounds.position.y + y)
			color.a = _alpha_for(color)
			if color.a <= 0.01:
				color = Color.TRANSPARENT
			elif color.a < 1.0:
				color.r = 0.02
				color.g = 0.02
				color.b = 0.02
			out.set_pixel(x, y, color)
	out.save_png(path)
	print("%s %sx%s" % [path, bounds.size.x, bounds.size.y])


func _keyed_copy(source: Image) -> Image:
	var out := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x, y)
			color.a = _alpha_for(color)
			if color.a <= 0.01:
				color = Color.TRANSPARENT
			elif color.a < 1.0:
				color.r = 0.02
				color.g = 0.02
				color.b = 0.02
			out.set_pixel(x, y, color)
	return out


func _is_key(color: Color) -> bool:
	return color.r8 >= 170 and color.g8 <= 110 and color.b8 >= 170 and color.r8 - color.g8 >= 75 and color.b8 - color.g8 >= 75


func _alpha_for(color: Color) -> float:
	if _is_key(color):
		return 0.0
	var dr := absi(color.r8 - 255)
	var dg := color.g8
	var db := absi(color.b8 - 255)
	var dist := maxi(maxi(dr, dg), db)
	if dist <= 24:
		return 0.0
	if dist >= 112:
		return color.a
	var t := float(dist - 24) / 88.0
	return color.a * t * t * (3.0 - 2.0 * t)

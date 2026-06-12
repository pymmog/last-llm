extends SceneTree

const SOURCE := "res://assets/sprites/unit7_ps1.png"
const OUT_DIR := "res://assets/sprites/"
const FRAME_COUNT := 4

var track_defs := [
	{
		"mask": PackedVector2Array([
			Vector2(50, 242), Vector2(122, 205), Vector2(190, 252), Vector2(116, 334),
		]),
		"axis": Vector2(-0.42, 0.91),
	},
	{
		"mask": PackedVector2Array([
			Vector2(157, 258), Vector2(237, 216), Vector2(336, 276), Vector2(246, 366),
		]),
		"axis": Vector2(0.56, 0.83),
	},
]


func _init() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null or source.is_empty():
		push_error("Could not load %s" % SOURCE)
		quit(1)
		return

	for frame in FRAME_COUNT:
		var out := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
		out.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i.ZERO)
		_scroll_tread_shading(out, frame)
		var path := OUT_DIR + "unit7_tread_%d.png" % frame
		out.save_png(path)
		print(path)
	quit()


func _scroll_tread_shading(image: Image, frame: int) -> void:
	for track in track_defs:
		var mask: PackedVector2Array = track["mask"]
		var axis: Vector2 = track["axis"].normalized()
		var bounds := _polygon_bounds(mask, image.get_size())
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var p := Vector2(x, y)
				if not Geometry2D.is_point_in_polygon(p, mask):
					continue
				var color := image.get_pixel(x, y)
				if color.a < 0.15 or not _looks_like_tread_pixel(color):
					continue
				var band := fposmod(p.dot(axis) / 52.0 + float(frame) * 0.25, 1.0)
				var factor := 1.45 if band < 0.24 else (0.60 if band > 0.66 else 0.95)
				var warm := 0.085 if band < 0.24 else 0.0
				color.r = clampf(color.r * factor + warm, 0.0, 1.0)
				color.g = clampf(color.g * factor + warm * 0.45, 0.0, 1.0)
				color.b = clampf(color.b * factor, 0.0, 1.0)
				image.set_pixel(x, y, color)


func _looks_like_tread_pixel(color: Color) -> bool:
	var luma := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var is_grey := absf(color.r - color.g) < 0.16 and absf(color.g - color.b) < 0.16
	var is_orange_wheel := color.r > 0.45 and color.g > 0.18 and color.g < 0.55 and color.b < 0.22
	return luma < 0.55 or is_grey or is_orange_wheel


func _polygon_bounds(poly: PackedVector2Array, image_size: Vector2i) -> Rect2i:
	var min_x := image_size.x
	var min_y := image_size.y
	var max_x := 0
	var max_y := 0
	for point in poly:
		min_x = mini(min_x, int(floor(point.x)))
		min_y = mini(min_y, int(floor(point.y)))
		max_x = maxi(max_x, int(ceil(point.x)))
		max_y = maxi(max_y, int(ceil(point.y)))
	return Rect2i(
		maxi(min_x, 0),
		maxi(min_y, 0),
		mini(max_x - min_x + 1, image_size.x),
		mini(max_y - min_y + 1, image_size.y)
	)

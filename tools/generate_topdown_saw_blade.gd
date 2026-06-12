extends SceneTree
## Generates a square top-down saw blade sprite for the Scrap Saw weapon.
##
## Run: godot --headless -s tools/generate_topdown_saw_blade.gd

const OUT := "res://assets/sprites/projectile_saw_blade.png"
const BASE_SIZE := 33
const SCALE := 3
const OUTLINE := Color8(14, 12, 16)


func _init() -> void:
	var img := Image.create(BASE_SIZE, BASE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	_draw_blade(img)
	_outline_pass(img)
	_bevel_pass(img, 0.13)
	img.resize(BASE_SIZE * SCALE, BASE_SIZE * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(OUT)
	print("%s %dx%d" % [OUT, img.get_width(), img.get_height()])
	quit()


func _draw_blade(img: Image) -> void:
	var center := Vector2((BASE_SIZE - 1) * 0.5, (BASE_SIZE - 1) * 0.5)
	for y in BASE_SIZE:
		for x in BASE_SIZE:
			var p := Vector2(x, y) - center
			var r := p.length()
			if r > 15.4:
				continue

			var a := atan2(p.y, p.x)
			var tooth_phase := fposmod(a + PI * 0.18, TAU / 12.0) / (TAU / 12.0)
			var tooth_peak := clampf(1.0 - absf(tooth_phase - 0.36) / 0.36, 0.0, 1.0)
			var outer := 11.2 + tooth_peak * 4.0
			if r > outer:
				continue

			if r <= 2.1:
				img.set_pixel(x, y, Color8(24, 22, 24))
			elif r <= 5.2:
				img.set_pixel(x, y, _lit(Color8(210, 132, 24), p))
			elif r <= 6.5:
				img.set_pixel(x, y, _lit(Color8(58, 56, 56), p))
			elif r <= outer:
				var steel := Color8(166, 166, 160)
				if r > 10.7:
					steel = Color8(206, 204, 192)
				if tooth_phase < 0.18 and r > 10.0:
					steel = Color8(232, 228, 210)
				if _angle_distance(a, -0.55) < 0.17 and r > 6.9 and r < 12.1:
					steel = Color8(62, 58, 58)
				if _angle_distance(a, 2.35) < 0.13 and r > 7.0 and r < 11.8:
					steel = Color8(242, 240, 228)
				img.set_pixel(x, y, _lit(steel, p))

	# Hub bolts and a cyan paint nick make rotation legible even on radial teeth.
	for bolt_angle in [0.8, 2.55, 4.4]:
		_dot(img, center + Vector2(cos(bolt_angle), sin(bolt_angle)) * 3.7, 1.0, Color8(72, 48, 22))
	_dot(img, center + Vector2(1.8, -2.2), 1.0, Color8(245, 190, 52))
	_dot(img, center + Vector2(-2.0, 2.0), 1.0, Color8(24, 220, 220))


func _dot(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(int(center.y - radius - 1.0), int(center.y + radius + 2.0)):
		for x in range(int(center.x - radius - 1.0), int(center.x + radius + 2.0)):
			if Vector2(x, y).distance_to(center) <= radius:
				_px(img, x, y, color)


func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, color)


func _opaque(img: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	return img.get_pixel(x, y).a > 0.5


func _outline_pass(img: Image) -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if not _opaque(src, x, y):
				continue
			if not (_opaque(src, x - 1, y) and _opaque(src, x + 1, y)
					and _opaque(src, x, y - 1) and _opaque(src, x, y + 1)):
				img.set_pixel(x, y, OUTLINE)


func _bevel_pass(img: Image, amount: float) -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := src.get_pixel(x, y)
			if c.a < 0.5 or c.is_equal_approx(OUTLINE):
				continue
			if not _opaque(src, x - 1, y - 1):
				img.set_pixel(x, y, c.lightened(amount))
			elif not _opaque(src, x + 1, y + 1):
				img.set_pixel(x, y, c.darkened(amount))


func _lit(color: Color, p: Vector2) -> Color:
	var light := clampf((-p.x - p.y) / 28.0, -0.28, 0.28)
	if light >= 0.0:
		return color.lightened(light)
	return color.darkened(-light)


func _angle_distance(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))

extends SceneTree
## Generates the non-character PS1-style sprites procedurally: environment
## props, pickups, XP gem, saw blade, scorch decal and the 9-patch UI skin.
## Matches the look of the extracted character art: chunky pixels, dark warm
## outline, top-left light. Deterministic — safe to re-run.
##
## Run: godot --headless -s tools/generate_ps1_sprites.gd

const OUT_DIR := "res://assets/sprites/"
const OUTLINE := Color(0.055, 0.05, 0.045, 1.0)

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 0x57A57
	_save(_rock_a(), "prop_rock_a", 3)
	_save(_rock_b(), "prop_rock_b", 3)
	_save(_bones(), "prop_bones", 3)
	_save(_shrub(), "prop_shrub", 3)
	_save(_plate(), "prop_plate", 3)
	_save(_medkit(), "pickup_medkit", 3)
	_save(_scrap(), "pickup_scrap", 3)
	_save(_magnet(), "pickup_magnet", 3)
	_save(_crate(), "pickup_crate", 3)
	_save(_gem(), "xp_gem", 3)
	_save(_scorch(), "fx_scorch", 3)
	_save(_ui_panel(), "ui_panel", 3)
	_save(_ui_button("normal"), "ui_button", 3)
	_save(_ui_button("hover"), "ui_button_hover", 3)
	_save(_ui_button("pressed"), "ui_button_pressed", 3)
	_save(_ui_button("disabled"), "ui_button_disabled", 3)
	_save(_ui_bar(), "ui_bar", 3)
	_save(_ui_bar_fill(), "ui_bar_fill", 3)
	print("PS1 sprite set generated in %s" % OUT_DIR)
	quit()


# ---------------------------------------------------------------- plumbing

func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func _save(img: Image, name: String, scale: int) -> void:
	if scale > 1:
		img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.save_png(OUT_DIR + name + ".png")
	print("%s%s.png %dx%d" % [OUT_DIR, name, img.get_width(), img.get_height()])


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)


func _line(img: Image, from: Vector2, to: Vector2, c: Color, width: float = 1.0) -> void:
	var steps := int(from.distance_to(to) * 2.0) + 1
	for i in steps + 1:
		var p := from.lerp(to, float(i) / steps)
		if width <= 1.0:
			_px(img, int(round(p.x)), int(round(p.y)), c)
		else:
			var r := width * 0.5
			for yy in range(int(p.y - r), int(p.y + r) + 1):
				for xx in range(int(p.x - r), int(p.x + r) + 1):
					if Vector2(xx, yy).distance_to(p) <= r:
						_px(img, xx, yy, c)


func _opaque(img: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	return img.get_pixel(x, y).a > 0.5


## Replace every opaque pixel that borders transparency with the dark outline.
func _outline_pass(img: Image) -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if not _opaque(src, x, y):
				continue
			if not (_opaque(src, x - 1, y) and _opaque(src, x + 1, y)
					and _opaque(src, x, y - 1) and _opaque(src, x, y + 1)):
				img.set_pixel(x, y, OUTLINE)


## Top-left rim light, bottom shade — gives every sprite the same lighting.
func _bevel_pass(img: Image, amount: float = 0.16) -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := src.get_pixel(x, y)
			if c.a < 0.5 or c.is_equal_approx(OUTLINE):
				continue
			var above := src.get_pixel(x, maxi(y - 1, 0))
			var below := src.get_pixel(x, mini(y + 1, img.get_height() - 1))
			if above.is_equal_approx(OUTLINE) or above.a < 0.5 or y == 0:
				img.set_pixel(x, y, c.lightened(amount))
			elif below.is_equal_approx(OUTLINE) or below.a < 0.5:
				img.set_pixel(x, y, c.darkened(amount))


func _speckle(img: Image, c: Color, count: int) -> void:
	for i in count:
		var x := rng.randi_range(1, img.get_width() - 2)
		var y := rng.randi_range(1, img.get_height() - 2)
		if _opaque(img, x, y) and not img.get_pixel(x, y).is_equal_approx(OUTLINE):
			img.set_pixel(x, y, c)


# ---------------------------------------------------------------- props

func _rock_a() -> Image:
	var img := _img(22, 16)
	var base := Color8(96, 88, 78)
	_ellipse(img, 11, 10, 9.2, 5.4, base)
	_ellipse(img, 7.5, 7.5, 5.2, 4.2, base)
	_ellipse(img, 15, 8.5, 4.4, 3.4, base)
	_ellipse(img, 8, 6.5, 3.2, 2.2, Color8(124, 114, 100))
	_ellipse(img, 14.5, 11, 4.2, 2.4, Color8(74, 68, 60))
	_speckle(img, Color8(82, 75, 66), 10)
	_outline_pass(img)
	_bevel_pass(img)
	return img


func _rock_b() -> Image:
	var img := _img(13, 9)
	_ellipse(img, 6.5, 5, 5.4, 3.2, Color8(92, 84, 74))
	_ellipse(img, 5, 3.8, 2.4, 1.6, Color8(118, 108, 94))
	_outline_pass(img)
	_bevel_pass(img)
	return img


func _bones() -> Image:
	var img := _img(22, 12)
	var bone := Color8(141, 134, 120)
	# Skull
	_ellipse(img, 5, 5, 3.4, 3.2, bone)
	_rect(img, 3, 7, 4, 2, bone)
	_px(img, 4, 5, OUTLINE)
	_px(img, 6, 5, OUTLINE)
	_px(img, 4, 8, Color8(90, 85, 75))
	_px(img, 6, 8, Color8(90, 85, 75))
	# Femur
	_line(img, Vector2(11, 9), Vector2(19, 5), bone, 1.8)
	_ellipse(img, 11, 9.4, 1.6, 1.4, bone)
	_ellipse(img, 19.4, 4.6, 1.6, 1.4, bone)
	# Rib shards
	_line(img, Vector2(13, 11), Vector2(14, 9), Color8(120, 113, 100))
	_line(img, Vector2(16, 11), Vector2(17, 9), Color8(120, 113, 100))
	_outline_pass(img)
	_bevel_pass(img, 0.1)
	return img


## No outline pass: 1px branches would turn entirely outline-dark.
func _shrub() -> Image:
	var img := _img(16, 15)
	var wood := Color8(122, 88, 52)
	var dark := Color8(98, 70, 42)
	_line(img, Vector2(8, 14), Vector2(8, 8), wood, 1.6)
	_line(img, Vector2(8, 9), Vector2(3, 3), dark)
	_line(img, Vector2(8, 8), Vector2(7, 1), wood)
	_line(img, Vector2(8, 9), Vector2(12, 3), dark)
	_line(img, Vector2(8, 11), Vector2(13, 8), dark)
	_line(img, Vector2(3, 3), Vector2(1, 2), Color8(140, 104, 62))
	_line(img, Vector2(12, 3), Vector2(14, 2), Color8(140, 104, 62))
	return img


func _plate() -> Image:
	var img := _img(16, 12)
	_rect(img, 1, 1, 14, 10, Color8(78, 76, 78))
	_rect(img, 2, 2, 12, 1, Color8(98, 96, 96))
	# Rust
	_ellipse(img, 11, 7, 2.6, 1.8, Color8(110, 69, 38))
	_ellipse(img, 4, 8, 1.6, 1.2, Color8(96, 60, 34))
	# Rivets
	for p in [Vector2i(3, 3), Vector2i(12, 3), Vector2i(3, 8), Vector2i(12, 8)]:
		_px(img, p.x, p.y, Color8(106, 104, 102))
	_line(img, Vector2(6, 4), Vector2(10, 8), Color8(85, 82, 90))
	_outline_pass(img)
	_bevel_pass(img)
	return img


# ---------------------------------------------------------------- pickups

func _medkit() -> Image:
	var img := _img(14, 14)
	_rect(img, 1, 2, 12, 11, Color8(216, 220, 212))
	_rect(img, 1, 2, 12, 2, Color8(235, 238, 232))
	_rect(img, 1, 11, 12, 2, Color8(178, 182, 175))
	var red := Color8(192, 48, 40)
	_rect(img, 6, 4, 2, 7, red)
	_rect(img, 4, 6, 7, 2, red)
	_px(img, 6, 4, Color8(225, 90, 80))
	_outline_pass(img)
	return img


func _scrap() -> Image:
	var img := _img(12, 12)
	var metal := Color8(154, 149, 142)
	_ellipse(img, 6, 7, 4.2, 3.4, metal)
	_ellipse(img, 4.5, 4.5, 2.6, 2.2, metal)
	_px(img, 9, 4, metal)
	_px(img, 9, 3, metal)
	_ellipse(img, 5, 5, 1.2, 1.0, Color8(216, 212, 204))
	_px(img, 7, 8, Color8(110, 106, 100))
	_px(img, 8, 8, Color8(110, 106, 100))
	_outline_pass(img)
	_bevel_pass(img)
	return img


func _magnet() -> Image:
	var img := _img(14, 13)
	var blue := Color8(52, 98, 216)
	_ellipse(img, 7, 6, 5.6, 5.2, blue)
	# Hollow the arch and open the bottom into a U.
	_ellipse(img, 7, 6, 2.6, 2.4, Color(0, 0, 0, 0))
	_rect(img, 5, 7, 4, 6, Color(0, 0, 0, 0))
	_rect(img, 2, 9, 3, 3, Color8(228, 228, 226))
	_rect(img, 9, 9, 3, 3, Color8(228, 228, 226))
	_px(img, 3, 2, Color8(110, 150, 240))
	_px(img, 4, 2, Color8(110, 150, 240))
	_outline_pass(img)
	_bevel_pass(img)
	return img


func _crate() -> Image:
	var img := _img(20, 16)
	_rect(img, 1, 1, 18, 14, Color8(122, 90, 48))
	_rect(img, 1, 1, 18, 2, Color8(146, 110, 62))
	_rect(img, 1, 6, 18, 1, Color8(92, 68, 35))
	_rect(img, 1, 11, 18, 1, Color8(92, 68, 35))
	# Straps
	_rect(img, 4, 1, 2, 14, Color8(74, 51, 24))
	_rect(img, 14, 1, 2, 14, Color8(74, 51, 24))
	# Latch
	_ellipse(img, 10, 8, 2.2, 2.0, Color8(232, 200, 74))
	_px(img, 10, 8, Color8(150, 120, 30))
	_outline_pass(img)
	_bevel_pass(img)
	return img


## Pale gem — runtime modulates it cyan / blue / purple per XP tier.
func _gem() -> Image:
	var img := _img(11, 14)
	var widths := [1, 3, 5, 7, 9, 9, 7, 5, 3, 1]
	for i in widths.size():
		var w: int = widths[i]
		_rect(img, 5 - w / 2, 2 + i, w, 1, Color8(205, 212, 214))
	# Left facet light, right facet dark.
	for i in range(1, 6):
		var w2: int = widths[i]
		_rect(img, 5 - w2 / 2, 2 + i, maxi(w2 / 3, 1), 1, Color8(238, 242, 242))
		_rect(img, 5 + w2 / 2 - maxi(w2 / 3, 1) + 1, 2 + i, maxi(w2 / 3, 1), 1, Color8(150, 162, 168))
	_px(img, 4, 4, Color8(255, 255, 255))
	_outline_pass(img)
	return img


## Soft-edged dark blotch with embers; drawn unfiltered by the outline/bevel
## passes so it stays a decal, not an object.
func _scorch() -> Image:
	var img := _img(26, 26)
	for y in 26:
		for x in 26:
			var d := Vector2(x - 13, y - 13).length() / 12.0
			if d > 1.0:
				continue
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			if d > 0.6 and rng.randf() > a + 0.25:
				continue
			img.set_pixel(x, y, Color(0.04, 0.03, 0.025, minf(a * 1.6, 0.85)))
	for i in 7:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(2.0, 8.0)
		_px(img, 13 + int(cos(ang) * r), 13 + int(sin(ang) * r), Color8(255, 140, 50, 200))
	return img


# ---------------------------------------------------------------- UI skin
#
# Wear helpers for the UI plates. Heavy wear (rust, scratches, chips) stays
# in the 9-patch corner zones, which render 1:1; the stretching center only
# gets low-contrast mottle so it doesn't smear into streaks.

## Per-pixel value jitter — breaks up flat fills like the hand-painted art.
func _mottle(img: Image, strength: float, rect := Rect2i()) -> void:
	if rect.size == Vector2i.ZERO:
		rect = Rect2i(0, 0, img.get_width(), img.get_height())
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			if c.a < 0.5 or c.is_equal_approx(OUTLINE):
				continue
			var v := (rng.randf() - 0.5) * 2.0 * strength
			img.set_pixel(x, y, c.lightened(v) if v > 0.0 else c.darkened(-v))


## Small rust bloom: warm browns dabbed in a random walk from a seed point.
## `bounds` keeps the walk inside a region (e.g. a 9-patch corner zone).
func _rust(img: Image, cx: int, cy: int, steps: int, bounds := Rect2i()) -> void:
	if bounds.size == Vector2i.ZERO:
		bounds = Rect2i(0, 0, img.get_width(), img.get_height())
	var tones := [Color8(122, 74, 34), Color8(147, 88, 42), Color8(94, 58, 28)]
	var p := Vector2i(cx, cy)
	for i in steps:
		p = p.clamp(bounds.position, bounds.end - Vector2i.ONE)
		var c := img.get_pixel(p.x, p.y)
		if c.a > 0.5 and not c.is_equal_approx(OUTLINE):
			var rust: Color = tones[rng.randi() % tones.size()]
			_px(img, p.x, p.y, c.lerp(rust, rng.randf_range(0.45, 0.8)))
		p += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))


## Light scratch: a short bright diagonal nick.
func _scratch(img: Image, from: Vector2, to: Vector2) -> void:
	var steps := int(from.distance_to(to) * 2.0) + 1
	for i in steps + 1:
		var p := from.lerp(to, float(i) / steps)
		var x := int(round(p.x))
		var y := int(round(p.y))
		if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
			continue
		var c := img.get_pixel(x, y)
		if c.a > 0.5 and not c.is_equal_approx(OUTLINE):
			img.set_pixel(x, y, c.lightened(0.22))


## Chip a few pixels out of the bright rim rows so edges look dinged.
func _chip_edges(img: Image, count: int) -> void:
	for i in count:
		var horizontal := rng.randf() < 0.5
		var x := rng.randi_range(2, img.get_width() - 3)
		var y := 1 if rng.randf() < 0.5 else img.get_height() - 2
		if not horizontal:
			x = 1 if rng.randf() < 0.5 else img.get_width() - 2
			y = rng.randi_range(2, img.get_height() - 3)
		var c := img.get_pixel(x, y)
		if c.a > 0.5 and not c.is_equal_approx(OUTLINE):
			img.set_pixel(x, y, c.darkened(0.45))


func _rivet(img: Image, x: int, y: int, bright: Color) -> void:
	_px(img, x, y, bright)
	_px(img, x + 1, y, bright.darkened(0.25))
	_px(img, x, y + 1, bright.darkened(0.35))
	_px(img, x + 1, y + 1, Color8(16, 14, 13))

func _ui_panel() -> Image:
	var img := _img(24, 24)
	# Warm gunmetal, like the robot's tread housing.
	_rect(img, 0, 0, 24, 24, Color8(38, 34, 31))
	_rect(img, 1, 1, 22, 1, Color8(82, 76, 66))
	_rect(img, 1, 22, 22, 1, Color8(20, 18, 16))
	_rect(img, 1, 1, 1, 22, Color8(64, 59, 51))
	_rect(img, 22, 1, 1, 22, Color8(26, 24, 22))
	_mottle(img, 0.05)
	_mottle(img, 0.10, Rect2i(1, 1, 4, 4))
	_mottle(img, 0.10, Rect2i(19, 19, 4, 4))
	# Corner wear: rust creeping from the rivets, a scratch, dinged rims.
	# Walks are clamped to the 5px 9-patch corner zones so stretching the
	# panel never smears them.
	_rust(img, 3, 3, 12, Rect2i(1, 1, 4, 4))
	_rust(img, 20, 20, 14, Rect2i(19, 19, 4, 4))
	_rust(img, 20, 3, 7, Rect2i(19, 1, 4, 4))
	_scratch(img, Vector2(2, 21), Vector2(4, 19))
	_chip_edges(img, 7)
	for p in [Vector2i(3, 3), Vector2i(19, 3), Vector2i(3, 19), Vector2i(19, 19)]:
		_rivet(img, p.x, p.y, Color8(116, 110, 98))
	_outline_pass(img)
	return img


## HUD bar frame: metal rim around a dark groove, same outline/bevel
## treatment as the character sprites. Used as a 9-patch.
func _ui_bar() -> Image:
	var img := _img(24, 8)
	_rect(img, 0, 0, 24, 8, Color8(87, 83, 75))
	_rect(img, 2, 2, 20, 4, Color8(24, 20, 16))
	_mottle(img, 0.06, Rect2i(0, 0, 6, 8))
	_mottle(img, 0.06, Rect2i(18, 0, 6, 8))
	_rust(img, 2, 6, 6)
	_rust(img, 21, 2, 5)
	_chip_edges(img, 4)
	_outline_pass(img)
	_bevel_pass(img)
	return img


## Pale fill bar, tinted at runtime (red HP / cyan XP) like the gem sprite.
func _ui_bar_fill() -> Image:
	var img := _img(24, 6)
	_rect(img, 0, 0, 24, 6, Color8(222, 219, 210))
	_rect(img, 0, 0, 24, 1, Color8(244, 240, 232))
	_rect(img, 0, 5, 24, 1, Color8(164, 160, 148))
	return img


func _ui_button(state: String) -> Image:
	var img := _img(24, 24)
	var fill := Color8(53, 50, 46)
	var top := Color8(80, 75, 66)
	var bottom := Color8(30, 28, 26)
	var edge := Color8(90, 85, 76)
	match state:
		"hover":
			fill = Color8(62, 60, 54)
			edge = Color8(62, 216, 204)
			top = Color8(96, 92, 82)
		"pressed":
			fill = Color8(38, 36, 33)
			top = Color8(24, 23, 21)
			bottom = Color8(60, 56, 50)
			edge = Color8(46, 160, 152)
		"disabled":
			fill = Color8(40, 39, 38)
			top = Color8(50, 49, 47)
			edge = Color8(58, 56, 54)
	_rect(img, 0, 0, 24, 24, fill)
	_rect(img, 1, 1, 22, 2, top)
	_rect(img, 1, 21, 22, 2, bottom)
	_rect(img, 1, 1, 1, 22, edge.darkened(0.25))
	_rect(img, 22, 1, 1, 22, edge.darkened(0.45))
	_rect(img, 1, 1, 22, 1, edge)
	_rect(img, 1, 22, 22, 1, edge.darkened(0.55))
	_mottle(img, 0.045)
	_mottle(img, 0.09, Rect2i(1, 1, 6, 6))
	_mottle(img, 0.09, Rect2i(17, 17, 6, 6))
	if state != "disabled":
		_rust(img, 3, 4, 9, Rect2i(1, 1, 4, 4))
		_rust(img, 20, 19, 10, Rect2i(19, 19, 4, 4))
		_scratch(img, Vector2(20, 4), Vector2(22, 2))
	_chip_edges(img, 6)
	for p in [Vector2i(3, 3), Vector2i(19, 3), Vector2i(3, 19), Vector2i(19, 19)]:
		_rivet(img, p.x, p.y, Color8(128, 122, 110) if state != "disabled" else Color8(74, 72, 69))
	_outline_pass(img)
	return img

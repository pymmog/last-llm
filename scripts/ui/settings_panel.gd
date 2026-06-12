extends VBoxContainer
## Reusable settings controls: volumes, screen mode, FPS cap, FPS overlay.
## Embedded by the title-screen settings scene and the in-run pause menu.
## Every change applies live via the Settings autoload and saves immediately.
## Emits `closed` when the BACK button is pressed.

signal closed

var grid: GridContainer
var _first_focus: Control


func _ready() -> void:
	add_theme_constant_override("separation", 18)

	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	add_child(grid)

	_add_slider("Master volume", Settings.master_volume,
		func(v: float) -> void: Settings.set_volume("Master", v))
	_add_slider("Music volume", Settings.music_volume,
		func(v: float) -> void: Settings.set_volume("Music", v))
	_add_slider("SFX volume", Settings.sfx_volume,
		func(v: float) -> void: Settings.set_volume("SFX", v))

	var modes := OptionButton.new()
	for m in Settings.SCREEN_MODES:
		modes.add_item(m)
	modes.selected = Settings.screen_mode
	modes.custom_minimum_size = Vector2(260, 36)
	modes.item_selected.connect(func(i: int) -> void:
		Settings.apply_screen_mode(i)
		Settings.save_data())
	_add_row("Screen mode", modes)

	var caps := OptionButton.new()
	for cap in Settings.FPS_CAPS:
		caps.add_item("Unlimited" if cap == 0 else "%d FPS" % cap)
	caps.selected = maxi(Settings.FPS_CAPS.find(Settings.fps_cap), 0)
	caps.custom_minimum_size = Vector2(260, 36)
	caps.item_selected.connect(func(i: int) -> void:
		Settings.apply_fps_cap(Settings.FPS_CAPS[i])
		Settings.save_data())
	_add_row("FPS cap", caps)

	var fps := CheckButton.new()
	fps.button_pressed = Settings.show_fps
	fps.toggled.connect(func(on: bool) -> void:
		Settings.set_show_fps(on)
		Settings.save_data())
	_add_row("FPS overlay", fps)

	var shake := CheckButton.new()
	shake.button_pressed = Settings.screen_shake
	shake.toggled.connect(func(on: bool) -> void:
		Settings.screen_shake = on
		Settings.save_data())
	_add_row("Screen shake", shake)

	# Wiping meta progression is destructive, so arm on first press and only
	# reset on a second press while armed; losing focus disarms.
	var reset := Button.new()
	reset.text = "RESET SAVE"
	reset.custom_minimum_size = Vector2(220, 44)
	reset.pressed.connect(func() -> void:
		if reset.text == "ARE YOU SURE?":
			Meta.reset()
			reset.text = "SAVE WIPED"
		elif reset.text == "RESET SAVE":
			reset.text = "ARE YOU SURE?")
	reset.focus_exited.connect(func() -> void:
		if reset.text == "ARE YOU SURE?":
			reset.text = "RESET SAVE")
	add_child(reset)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(220, 44)
	back.pressed.connect(func() -> void: closed.emit())
	add_child(back)


func focus_first() -> void:
	if _first_focus:
		_first_focus.grab_focus.call_deferred()


func _add_row(text: String, control: Control) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(180, 0)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	grid.add_child(l)
	grid.add_child(control)


func _add_slider(text: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(220, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := Label.new()
	pct.text = "%d%%" % int(round(value * 100.0))
	pct.custom_minimum_size = Vector2(48, 0)
	pct.add_theme_font_size_override("font_size", 14)
	pct.add_theme_color_override("font_color", Color(0.4, 0.95, 0.85))
	s.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % int(round(v * 100.0))
		on_change.call(v)
		Settings.save_data())
	if _first_focus == null:
		_first_focus = s
	row.add_child(s)
	row.add_child(pct)
	_add_row(text, row)

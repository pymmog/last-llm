extends Node
## User-facing settings: audio volumes, screen mode, FPS cap and the FPS
## overlay. Persisted to user://settings.json, applied on startup. Creates
## the Music and SFX audio buses so future audio can route through them.

const SAVE_PATH := "user://settings.json"

const SCREEN_MODES := ["Windowed", "Fullscreen", "Borderless"]
const FPS_CAPS := [0, 30, 60, 90, 120, 144, 240]  # 0 = unlimited

var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0
var screen_mode := 0  # index into SCREEN_MODES
var fps_cap := 0      # actual cap value, 0 = unlimited
var show_fps := false

var _fps_label: Label
var _fps_accum := 0.0


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	load_data()
	_build_fps_overlay()
	apply_all()


# ---------------------------------------------------------------- apply

func apply_all() -> void:
	set_volume("Master", master_volume)
	set_volume("Music", music_volume)
	set_volume("SFX", sfx_volume)
	apply_screen_mode(screen_mode)
	apply_fps_cap(fps_cap)
	set_show_fps(show_fps)


func set_volume(bus: String, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	match bus:
		"Master": master_volume = v
		"Music": music_volume = v
		"SFX": sfx_volume = v
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)


func apply_screen_mode(mode: int) -> void:
	screen_mode = clampi(mode, 0, SCREEN_MODES.size() - 1)
	match screen_mode:
		0:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)


func apply_fps_cap(cap: int) -> void:
	fps_cap = maxi(cap, 0)
	Engine.max_fps = fps_cap


func set_show_fps(on: bool) -> void:
	show_fps = on
	if _fps_label:
		_fps_label.visible = on


# ---------------------------------------------------------------- overlay

func _build_fps_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fps_label.offset_left = -150
	_fps_label.offset_top = -30
	_fps_label.offset_right = -6
	_fps_label.offset_bottom = -10
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_font_size_override("font_size", 13)
	_fps_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	_fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_fps_label.add_theme_constant_override("shadow_offset_x", 1)
	_fps_label.add_theme_constant_override("shadow_offset_y", 1)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.visible = false
	layer.add_child(_fps_label)


func _process(delta: float) -> void:
	if not show_fps:
		return
	_fps_accum -= delta
	if _fps_accum > 0.0:
		return
	_fps_accum = 0.25
	var fps := Engine.get_frames_per_second()
	_fps_label.text = "%d FPS  %.1f ms " % [int(fps), 1000.0 / maxf(fps, 1.0)]


# ---------------------------------------------------------------- persist

func _ensure_bus(name_: String) -> void:
	if AudioServer.get_bus_index(name_) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, name_)
	AudioServer.set_bus_send(idx, "Master")


func save_data() -> void:
	var data := {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"screen_mode": screen_mode,
		"fps_cap": fps_cap,
		"show_fps": show_fps,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	master_volume = clampf(float(parsed.get("master_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(parsed.get("music_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(parsed.get("sfx_volume", 1.0)), 0.0, 1.0)
	screen_mode = clampi(int(parsed.get("screen_mode", 0)), 0, SCREEN_MODES.size() - 1)
	fps_cap = maxi(int(parsed.get("fps_cap", 0)), 0)
	show_fps = bool(parsed.get("show_fps", false))

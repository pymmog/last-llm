extends Control
## Title screen. UI is built in code; the backdrop is the wasteland palette.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	theme = UiTheme.make()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg := ColorRect.new()
	bg.color = Color(0.075, 0.064, 0.052)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "RUSTPULSE"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.58, 0.18))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "One robot. Endless mutants. Survive 20 minutes."
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.56, 0.9, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	box.add_child(_spacer(24))
	var start := _button("START RUN", _on_start)
	box.add_child(start)
	UiTheme.focus_when_ready(start)
	box.add_child(_button("WORKSHOP", _on_workshop))
	box.add_child(_button("SETTINGS", _on_settings))
	box.add_child(_button("QUIT", _on_quit))
	box.add_child(_spacer(24))

	var stats := Label.new()
	var bt := int(Meta.best_time)
	stats.text = "Scrap: %d    Best time: %02d:%02d    Total kills: %d    Victories: %d" % [
		Meta.scrap, bt / 60, bt % 60, Meta.total_kills, Meta.victories]
	stats.add_theme_font_size_override("font_size", 14)
	stats.add_theme_color_override("font_color", Color(0.72, 0.68, 0.6))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)

	var hint := Label.new()
	hint.text = "Move: WASD / arrows / left stick — weapons fire on their own"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.48, 0.55, 0.52))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(handler)
	return b


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_workshop() -> void:
	get_tree().change_scene_to_file("res://scenes/workshop.tscn")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()

extends Control
## Title-screen settings: wraps the shared settings panel; BACK returns to
## the main menu. The same panel is embedded in the in-run pause menu.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var panel: VBoxContainer


func _ready() -> void:
	theme = UiTheme.make()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.085, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var frame := PanelContainer.new()
	center.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	frame.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.55, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	panel = SettingsPanel.new()
	panel.closed.connect(_back)
	box.add_child(panel)
	panel.focus_first.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()


func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

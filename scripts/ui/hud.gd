extends CanvasLayer
## In-run UI: bars, timer, counters, banner messages, level-up card picker,
## pause menu and end-of-run screen. Runs while the tree is paused.

const Upgrades := preload("res://scripts/upgrades.gd")

var main: Node2D

var xp_bg: ColorRect
var xp_fill: ColorRect
var hp_fill: ColorRect
var hp_label: Label
var timer_label: Label
var level_label: Label
var kills_label: Label
var scrap_label: Label
var banner: Label
var banner_t := 0.0
var damage_flash: ColorRect
var damage_flash_t := 0.0

var levelup_panel: Control
var cards_box: HBoxContainer
var pause_panel: Control
var end_panel: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_bars()
	_build_levelup()
	_build_pause()


func _build_bars() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Red flash over the whole screen when the player takes a hit.
	damage_flash = ColorRect.new()
	damage_flash.color = Color(0.9, 0.12, 0.08, 0.0)
	damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_flash)

	# XP bar across the top.
	xp_bg = ColorRect.new()
	xp_bg.color = Color(0, 0, 0, 0.55)
	xp_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_bg.offset_bottom = 14
	xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(xp_bg)
	xp_fill = ColorRect.new()
	xp_fill.color = Color(0.25, 0.9, 0.85)
	xp_fill.position = Vector2(0, 2)
	xp_fill.size = Vector2(0, 10)
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bg.add_child(xp_fill)
	level_label = _label(root, Vector2(1180, 18), 16, Color(0.6, 1.0, 0.95))
	level_label.text = "LV 1"

	# HP bar top-left.
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.55)
	hp_bg.position = Vector2(16, 24)
	hp_bg.size = Vector2(208, 18)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.85, 0.3, 0.25)
	hp_fill.position = Vector2(2, 2)
	hp_fill.size = Vector2(204, 14)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.add_child(hp_fill)
	hp_label = _label(root, Vector2(20, 24), 12, Color(1, 1, 1))

	timer_label = _label(root, Vector2(600, 22), 26, Color(0.95, 0.92, 0.85))
	timer_label.text = "00:00"
	kills_label = _label(root, Vector2(16, 48), 14, Color(0.9, 0.65, 0.6))
	scrap_label = _label(root, Vector2(16, 68), 14, Color(0.8, 0.8, 0.8))

	banner = _label(root, Vector2(0, 160), 28, Color(1.0, 0.85, 0.3))
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 150
	banner.offset_bottom = 200
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0


func _label(parent: Control, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _process(delta: float) -> void:
	var p: Node2D = main.player
	xp_fill.size.x = xp_bg.size.x * clampf(p.xp / p.xp_needed, 0.0, 1.0)
	hp_fill.size.x = 204.0 * clampf(p.hp / p.max_hp, 0.0, 1.0)
	hp_label.text = "%d / %d" % [int(p.hp), int(p.max_hp)]
	level_label.text = "LV %d" % p.level
	var t := int(main.run_time)
	timer_label.text = "%02d:%02d" % [t / 60, t % 60]
	timer_label.position.x = get_viewport().get_visible_rect().size.x / 2.0 - 40.0
	level_label.position.x = get_viewport().get_visible_rect().size.x - 80.0
	kills_label.text = "KILLS %d" % main.kills
	scrap_label.text = "SCRAP %d (+%d)" % [Meta.scrap, main.scrap_earned]
	if banner_t > 0.0:
		banner_t -= delta
		banner.modulate.a = clampf(banner_t / 0.5, 0.0, 1.0)
	if damage_flash_t > 0.0:
		damage_flash_t -= delta
		damage_flash.color.a = clampf(damage_flash_t / 0.35, 0.0, 1.0) * 0.28


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not main.run_over and not levelup_panel.visible:
		_toggle_pause()


func show_banner(text: String) -> void:
	banner.text = text
	banner_t = 2.6


func flash_damage() -> void:
	damage_flash_t = 0.35


# ---------------------------------------------------------------- level up

func _build_levelup() -> void:
	levelup_panel = _overlay()
	var box := _center_panel(levelup_panel)
	var title := Label.new()
	title.text = "SYSTEM UPGRADE AVAILABLE"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	cards_box = HBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 14)
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(cards_box)


func on_level_up() -> void:
	if not levelup_panel.visible:
		_show_levelup()


func _show_levelup() -> void:
	get_tree().paused = true
	for c in cards_box.get_children():
		c.queue_free()
	var count := 3 + Meta.tier("choices")
	var choices: Array = Upgrades.build_choices(main.player, count)
	for card in choices:
		cards_box.add_child(_make_card(card))
	levelup_panel.visible = true


func _make_card(card: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(210, 150)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 10
	v.offset_bottom = -10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var strip := ColorRect.new()
	strip.color = card["color"]
	strip.custom_minimum_size = Vector2(0, 6)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(strip)
	var title := Label.new()
	title.text = card["title"]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", card["color"])
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	var desc := Label.new()
	desc.text = card["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc)
	b.pressed.connect(_on_card_picked.bind(card))
	return b


func _on_card_picked(card: Dictionary) -> void:
	Upgrades.apply(main, card)
	main.player.pending_levels -= 1
	if main.player.pending_levels > 0:
		_show_levelup()
	else:
		levelup_panel.visible = false
		get_tree().paused = false


# ---------------------------------------------------------------- pause / end

func _build_pause() -> void:
	pause_panel = _overlay()
	var box := _center_panel(pause_panel)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume := Button.new()
	resume.text = "Resume"
	resume.custom_minimum_size = Vector2(220, 40)
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var abandon := Button.new()
	abandon.text = "Abandon Run"
	abandon.custom_minimum_size = Vector2(220, 40)
	abandon.pressed.connect(_on_abandon)
	box.add_child(abandon)


func _toggle_pause() -> void:
	var now := not pause_panel.visible
	pause_panel.visible = now
	get_tree().paused = now


func _on_abandon() -> void:
	pause_panel.visible = false
	get_tree().paused = false
	main.end_run(false)


func show_end_screen(victory: bool) -> void:
	levelup_panel.visible = false
	pause_panel.visible = false
	end_panel = _overlay()
	var box := _center_panel(end_panel)
	var title := Label.new()
	title.text = "WASTELAND SECURED" if victory else "UNIT-7 DESTROYED"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color",
		Color(0.4, 1.0, 0.6) if victory else Color(1.0, 0.4, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var t := int(main.run_time)
	for line in [
		"Time survived:  %02d:%02d" % [t / 60, t % 60],
		"Mutants destroyed:  %d" % main.kills,
		"Scrap banked:  +%d" % main.scrap_earned,
	]:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	var cont := Button.new()
	cont.text = "Return to Base"
	cont.custom_minimum_size = Vector2(240, 44)
	cont.pressed.connect(_on_end_continue)
	box.add_child(cont)
	end_panel.visible = true
	get_tree().paused = true


func _on_end_continue() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ---------------------------------------------------------------- helpers

func _overlay() -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.visible = false
	add_child(o)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	return o


func _center_panel(overlay: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	return box

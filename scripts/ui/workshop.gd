extends Control
## Workshop: spend banked scrap on permanent unlocks (Meta autoload).

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

var scrap_label: Label
var rows: Dictionary = {}  # id -> {pips: Label, btn: Button}


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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "WORKSHOP — PERMANENT UPGRADES"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.55, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	scrap_label = Label.new()
	scrap_label.add_theme_font_size_override("font_size", 18)
	scrap_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(scrap_label)

	for id in Meta.UPGRADES:
		box.add_child(_build_row(id))

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(200, 44)
	back.pressed.connect(_back)
	box.add_child(back)
	_refresh()
	var first_id: String = Meta.UPGRADES.keys()[0]
	(rows[first_id]["btn"] as Button).grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()


func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _build_row(id: String) -> Control:
	var d: Dictionary = Meta.UPGRADES[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = d["name"]
	name_label.custom_minimum_size = Vector2(200, 0)
	name_label.add_theme_font_size_override("font_size", 16)
	row.add_child(name_label)

	var desc := Label.new()
	desc.text = d["desc"]
	desc.custom_minimum_size = Vector2(190, 0)
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.62))
	row.add_child(desc)

	var pips := Label.new()
	pips.custom_minimum_size = Vector2(90, 0)
	pips.add_theme_font_size_override("font_size", 15)
	pips.add_theme_color_override("font_color", Color(0.4, 0.95, 0.85))
	row.add_child(pips)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 36)
	btn.pressed.connect(_on_buy.bind(id))
	row.add_child(btn)

	rows[id] = {"pips": pips, "btn": btn}
	return row


func _on_buy(id: String) -> void:
	if Meta.buy(id):
		_refresh()


func _refresh() -> void:
	scrap_label.text = "SCRAP: %d" % Meta.scrap
	for id in rows:
		var max_tiers: int = Meta.UPGRADES[id]["tiers"]
		var t: int = Meta.tier(id)
		var pips: Label = rows[id]["pips"]
		var btn: Button = rows[id]["btn"]
		pips.text = "%s%s" % ["●".repeat(t), "○".repeat(max_tiers - t)]
		if t >= max_tiers:
			btn.text = "MAXED"
			btn.disabled = true
		else:
			btn.text = "BUY  (%d)" % Meta.cost(id)
			btn.disabled = not Meta.can_buy(id)

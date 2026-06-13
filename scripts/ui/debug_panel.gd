extends Control
## Debug-build-only cheat menu, toggled with "?" (the HUD routes the key here).
## Pauses the run while open and live-updates a stats readout.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

var main: Node2D
var god_check: CheckButton
var stats: Label


func _ready() -> void:
	UiTheme.setup_overlay(self)
	var box := UiTheme.center_panel(self)
	var title := Label.new()
	title.text = "DEV DEBUG"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	box.add_child(columns)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	columns.add_child(actions)
	god_check = CheckButton.new()
	god_check.text = "God Mode"
	god_check.toggled.connect(func(on: bool) -> void:
		main.player.god_mode = on)
	actions.add_child(god_check)
	_btn(actions, "+1 Level", _level_up.bind(1))
	_btn(actions, "+5 Levels", _level_up.bind(5))
	_btn(actions, "Full Heal", func() -> void:
		main.player.hp = main.player.max_hp)
	_btn(actions, "+1000 Scrap", func() -> void:
		main.scrap_earned += 1000)
	_btn(actions, "Kill All Enemies", _kill_all)
	_btn(actions, "Skip +1 Minute", func() -> void:
		main.run_time += 60.0)
	_btn(actions, "Crate Reward", func() -> void:
		# Hide the menu first: the crate opens the card picker, which takes
		# over the pause state and focus.
		visible = false
		main.open_crate())
	_btn(actions, "Close", toggle)
	stats = Label.new()
	stats.custom_minimum_size = Vector2(340, 0)
	stats.add_theme_font_size_override("font_size", 13)
	stats.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	columns.add_child(stats)


func _btn(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 34)
	b.pressed.connect(action)
	parent.add_child(b)


func toggle() -> void:
	var now := not visible
	visible = now
	get_tree().paused = now
	if now:
		god_check.set_pressed_no_signal(main.player.god_mode)
		_update_stats()
		UiTheme.focus_when_ready(god_check)


func _process(_delta: float) -> void:
	if visible:
		_update_stats()


func _level_up(count: int) -> void:
	# Hide the menu first: add_xp opens the level-up card picker, which
	# takes over the pause state and focus.
	visible = false
	var p: Node2D = main.player
	for i in count:
		p.add_xp(p.xp_needed - p.xp + 0.001)


func _kill_all() -> void:
	for e in main.enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.take_damage(1e9, main.player.position)


func _update_stats() -> void:
	var p: Node2D = main.player
	var weapons := ""
	for w in p.weapons:
		weapons += "\n  %s  LV %d%s" % [
			w.display_name, w.level, "  (evolved)" if w.evolved else ""]
	var passives := ""
	for id in p.passives:
		passives += "\n  %s  LV %d" % [id, p.passives[id]]
	var t := int(main.run_time)
	stats.text = "\n".join([
		"LV %d   XP %.1f / %.1f" % [p.level, p.xp, p.xp_needed],
		"HP %.1f / %.1f   regen %.1f/s   armor %.1f" % [p.hp, p.max_hp, p.regen, p.armor],
		"Move speed %.0f   Pickup radius %.0f" % [p.move_speed, p.pickup_radius],
		"Damage x%.2f   Attack speed +%d%%   CDR %d%%" % [
			p.damage_mult, roundi(p.attack_speed * 100), roundi(p.cooldown_red * 100)],
		"Area x%.2f   Projectiles +%d   Pierce +%d" % [
			p.area_mult, p.extra_projectiles, p.extra_pierce],
		"",
		"Run %02d:%02d   Kills %d   Scrap +%d" % [int(t / 60.0), t % 60, main.kills, main.scrap_earned],
		"Enemies %d   Gems %d   FX %d   FPS %d" % [
			main.enemies.size(),
			get_tree().get_nodes_in_group("xp_gems").size(),
			main.fx_node.get_child_count(),
			Engine.get_frames_per_second()],
		"",
		"Weapons:" + (weapons if weapons != "" else "  none"),
		"Passives:" + (passives if passives != "" else "  none"),
	])

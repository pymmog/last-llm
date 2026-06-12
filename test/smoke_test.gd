extends Node
## Headless smoke test driver. Instantiates the run scene and force-exercises
## every system: weapons, max levels, evolutions, enemy roster, alpha crate,
## level-up cards, pickups and the end screen.
##
## Run with:
##   godot --headless res://test/smoke_test.tscn --quit-after 1200

const Upgrades := preload("res://scripts/upgrades.gd")

var main: Node2D
var frame := 0
var failures := 0
var cards_clicked := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func check(cond: bool, what: String) -> void:
	if cond:
		print("OK   ", what)
	else:
		failures += 1
		printerr("FAIL ", what)


func _physics_process(_delta: float) -> void:
	frame += 1
	var player: Node2D = main.player
	# Click through level-up cards until all pending levels are resolved.
	if frame > 165 and frame < 300 and main.hud.levelup_panel.visible:
		var card: Button = main.hud.cards_box.get_child(0)
		if cards_clicked == 1:
			# Regression: stale queued-free cards used to steal the focus seed
			# on every re-shown panel, breaking keyboard/gamepad selection.
			check(get_viewport().gui_get_focus_owner() == card,
				"re-shown level-up card regains keyboard focus")
		card.pressed.emit()
		cards_clicked += 1
	match frame:
		5:
			check(AudioServer.get_bus_index("Music") >= 0, "music bus created")
			check(AudioServer.get_bus_index("SFX") >= 0, "sfx bus created")
			Settings.set_volume("Master", 0.5)
			check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.01,
				"master volume applied to bus")
			Settings.set_volume("Master", 1.0)
			Settings.apply_fps_cap(120)
			check(Engine.max_fps == 120, "fps cap applied")
			Settings.apply_fps_cap(0)
			Settings.set_show_fps(true)
			Settings.set_show_fps(false)
			Settings.save_data()
			check(FileAccess.file_exists(Settings.SAVE_PATH), "settings file saved")
			var has_w := false
			for ev in InputMap.action_get_events("ui_up"):
				if ev is InputEventKey and ev.physical_keycode == KEY_W:
					has_w = true
			check(has_w, "WASD bound to ui navigation")
			# Settings screen builds without errors.
			var sm: Control = load("res://scenes/settings_menu.tscn").instantiate()
			add_child(sm)
			check(sm.panel.grid.get_child_count() == 14, "settings menu built (7 rows)")
			sm.queue_free()
			# In-run settings reachable from the pause menu.
			main.hud._open_settings()
			check(main.hud.settings_panel.visible, "pause settings panel opens")
			main.hud._close_settings()
			check(main.hud.pause_panel.visible and not main.hud.settings_panel.visible,
				"pause settings panel closes back to pause menu")
			main.hud.pause_panel.visible = false
		10:
			check(player != null, "player exists")
			check(player.weapons.size() == 1, "starts with one weapon")
			for id in Upgrades.WEAPONS:
				if player.get_weapon(id) == null:
					player.add_weapon(id)
			check(player.weapons.size() == 5, "all weapons equipped")
		20:
			for id in Upgrades.PASSIVES:
				player.add_passive(id)
			check(player.extra_projectiles >= 1, "targeting matrix applied")
			check(player.armor >= 1.0, "plating applied")
			for w in player.weapons:
				while w.level < w.MAX_LEVEL:
					w.level_up()
		30:
			for w in player.weapons:
				if w.id != "rivet" and w.can_evolve():
					w.evolve()
			check(player.get_weapon("tesla").evolved, "tesla evolved")
			check(not player.get_weapon("rivet").evolved, "rivet left for crate")
		40:
			for etype in ["shambler", "sprinter", "spitter", "brute"]:
				main.director.spawn(etype, false)
			main.director.spawn("brute", true)
			check(main.enemies.size() >= 5, "roster spawned")
			# Pull them close so weapons and contact logic engage.
			for e in main.enemies:
				e.position = player.position + Vector2(randf_range(80, 160), randf_range(-60, 60))
		120:
			check(main.kills >= 0 and is_instance_valid(player), "combat ran")
			for e in main.enemies:
				e.take_damage(99999.0)
			check(main.kills >= 5, "all enemies killed (kills=%d)" % main.kills)
		140:
			# Alpha XP gems may have leveled the player already; resolve those
			# picks so the crate offer below is shown on its own.
			# Avoid evolve cards while draining: the rivet evolution must stay
			# available for the crate-offer assertions below.
			var drain := 0
			while main.hud.levelup_panel.visible and drain < 32:
				var pick: Button = main.hud.cards_box.get_child(0)
				for c in main.hud.cards_box.get_children():
					var title: Label = c.get_child(0).get_child(1)
					if not title.text.begins_with("EVOLVE"):
						pick = c
						break
				pick.pressed.emit()
				drain += 1
			check(not main.hud.levelup_panel.visible, "pending level-ups drained")
			# Alpha dropped a crate; walk over everything via forced collection.
			var found_crate := false
			for p in main.pickups_node.get_children():
				if "kind" in p and p.kind == "crate":
					found_crate = true
					p.collect(player)
			check(found_crate, "alpha dropped supply crate")
			check(main.hud.levelup_panel.visible, "crate opened the card picker")
			check(main.hud.cards_box.get_child_count() == 6, "crate offers 6 cards")
			var first_title: Label = main.hud.cards_box.get_child(0).get_child(0).get_child(1)
			check(first_title.text.begins_with("EVOLVE"), "crate offer leads with ready evolution")
		145:
			(main.hud.cards_box.get_child(0) as Button).pressed.emit()
		150:
			check(player.get_weapon("rivet").evolved, "crate card evolved rivet gun")
			check(not get_tree().paused, "crate pick resolved and unpaused")
		160:
			player.add_xp(2000.0)
		165:
			check(get_tree().paused, "level-up pauses the game")
			check(main.hud.levelup_panel.visible, "level-up panel visible")
			check(get_viewport().gui_get_focus_owner() == main.hud.cards_box.get_child(0),
				"first upgrade card has keyboard focus")
		310:
			check(not get_tree().paused, "all pending level-ups resolved")
			check(player.level > 5, "xp leveled the player (level=%d)" % player.level)
			main.spawn_pickup("medkit", player.position)
			main.spawn_pickup("scrap", player.position, 7)
			main.spawn_pickup("magnet", player.position)
			player.hp = 10.0
		340:
			check(player.hp > 10.0, "medkit healed")
			check(main.scrap_earned >= 7, "scrap collected (earned=%d)" % main.scrap_earned)
			main.explode(player.position + Vector2(50, 0), 80.0, 10.0, true, 5.0)
		400:
			var before: int = Meta.scrap
			main.end_run(true)
			check(main.run_over, "run ended")
			check(Meta.scrap > before, "scrap banked to meta save")
			check(main.hud.end_panel != null and main.hud.end_panel.visible, "end screen shown")
		430:
			get_tree().paused = false
			if failures == 0:
				print("SMOKE OK")
			else:
				printerr("SMOKE FAILED: %d failures" % failures)
			get_tree().quit(1 if failures > 0 else 0)

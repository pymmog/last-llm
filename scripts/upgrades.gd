extends RefCounted
## Static catalog of weapons & passives, and the level-up card generator.

const WEAPONS := {
	"rivet": {"name": "Rivet Gun", "script": "res://scripts/weapons/rivet_gun.gd",
		"desc": "Fires rivets at the nearest mutant", "pair": "tungsten", "evolved": "Railspike Driver"},
	"saw": {"name": "Scrap Saw", "script": "res://scripts/weapons/scrap_saw.gd",
		"desc": "Saw blades orbit you", "pair": "plating", "evolved": "Buzzkill Halo"},
	"tesla": {"name": "Tesla Arc", "script": "res://scripts/weapons/tesla_arc.gd",
		"desc": "Chain lightning between mutants", "pair": "capacitor", "evolved": "Storm Coil"},
	"mortar": {"name": "Plasma Mortar", "script": "res://scripts/weapons/plasma_mortar.gd",
		"desc": "Shells the densest cluster", "pair": "emitter", "evolved": "Sunfire Battery"},
	"swarm": {"name": "Nano Swarm", "script": "res://scripts/weapons/nano_swarm.gd",
		"desc": "Homing nano-drones", "pair": "matrix", "evolved": "Gray Goo"},
}

const PASSIVES := {
	"servo": {"name": "Servo Overclock", "max": 5, "desc": "+8% attack speed"},
	"capacitor": {"name": "Capacitor Bank", "max": 5, "desc": "-6% weapon cooldown"},
	"chassis": {"name": "Reinforced Chassis", "max": 5, "desc": "+20 max HP"},
	"nanites": {"name": "Auto-Repair Nanites", "max": 5, "desc": "+0.4 HP/s regen"},
	"plating": {"name": "Reactive Plating", "max": 5, "desc": "+1 armor"},
	"matrix": {"name": "Targeting Matrix", "max": 2, "desc": "+1 projectile"},
	"tungsten": {"name": "Tungsten Rounds", "max": 3, "desc": "+1 pierce"},
	"emitter": {"name": "Wide-Area Emitter", "max": 5, "desc": "+10% area of effect"},
	"core": {"name": "Power Core", "max": 5, "desc": "+8% damage"},
	"legs": {"name": "Hydraulic Legs", "max": 5, "desc": "+8% move speed"},
	"magnet": {"name": "Magnet Coil", "max": 5, "desc": "+20% pickup radius"},
}

const MAX_WEAPON_SLOTS := 4
const MAX_PASSIVE_SLOTS := 4

const COL_WEAPON := Color(0.95, 0.6, 0.25)
const COL_PASSIVE := Color(0.45, 0.75, 0.95)
const COL_EVOLVE := Color(1.0, 0.85, 0.3)
const COL_SCRAP := Color(0.7, 0.7, 0.7)


static func build_choices(player: Node2D, count: int) -> Array:
	var pool: Array = []  # [{card, weight}]

	for w in player.weapons:
		if w.can_evolve():
			pool.append({"weight": 30.0, "card": {
				"kind": "evolve", "id": w.id,
				"title": "EVOLVE: %s" % w.evolved_name,
				"desc": "%s reaches its final form" % w.display_name,
				"color": COL_EVOLVE}})
		elif w.level < w.MAX_LEVEL:
			pool.append({"weight": 10.0, "card": {
				"kind": "weapon_up", "id": w.id,
				"title": "%s Lv %d" % [w.display_name, w.level + 1],
				"desc": w.upgrade_desc(),
				"color": COL_WEAPON}})

	if player.weapons.size() < MAX_WEAPON_SLOTS:
		for id in WEAPONS:
			if player.get_weapon(id) == null:
				pool.append({"weight": 6.0, "card": {
					"kind": "weapon_new", "id": id,
					"title": "NEW: %s" % WEAPONS[id]["name"],
					"desc": WEAPONS[id]["desc"],
					"color": COL_WEAPON}})

	for id in PASSIVES:
		var lv: int = player.passive_level(id)
		if lv > 0 and lv < int(PASSIVES[id]["max"]):
			pool.append({"weight": 10.0, "card": {
				"kind": "passive_up", "id": id,
				"title": "%s Lv %d" % [PASSIVES[id]["name"], lv + 1],
				"desc": PASSIVES[id]["desc"],
				"color": COL_PASSIVE}})
		elif lv == 0 and player.passives.size() < MAX_PASSIVE_SLOTS:
			pool.append({"weight": 6.0, "card": {
				"kind": "passive_new", "id": id,
				"title": "NEW: %s" % PASSIVES[id]["name"],
				"desc": PASSIVES[id]["desc"],
				"color": COL_PASSIVE}})

	var choices: Array = []
	for i in count:
		if pool.is_empty():
			choices.append({"kind": "scrap", "id": "", "title": "+25 SCRAP",
				"desc": "Everything is maxed out", "color": COL_SCRAP})
			continue
		var total := 0.0
		for entry in pool:
			total += entry["weight"]
		var roll := randf() * total
		for j in pool.size():
			roll -= pool[j]["weight"]
			if roll <= 0.0:
				choices.append(pool[j]["card"])
				pool.remove_at(j)
				break
	return choices


static func apply(main: Node2D, card: Dictionary) -> void:
	var player: Node2D = main.player
	match card["kind"]:
		"weapon_new":
			player.add_weapon(card["id"])
		"weapon_up":
			player.get_weapon(card["id"]).level_up()
		"passive_new", "passive_up":
			player.add_passive(card["id"])
		"evolve":
			player.get_weapon(card["id"]).evolve()
			main.spawn_fx("ring", player.position, 90.0, COL_EVOLVE)
		"scrap":
			main.scrap_earned += 25

extends Node
## Permanent progression: scrap currency and workshop unlocks.
## Persisted to user://meta.json.

const SAVE_PATH := "user://meta.json"

const UPGRADES := {
	"max_hp": {"name": "Reinforced Frame", "desc": "+20 max HP", "tiers": 5, "base_cost": 40, "per": 20.0},
	"damage": {"name": "Weapon Calibration", "desc": "+5% damage", "tiers": 5, "base_cost": 50, "per": 0.05},
	"speed": {"name": "Tuned Actuators", "desc": "+5% move speed", "tiers": 3, "base_cost": 60, "per": 0.05},
	"armor": {"name": "Ablative Shell", "desc": "+1 armor", "tiers": 3, "base_cost": 80, "per": 1.0},
	"regen": {"name": "Self-Repair Loop", "desc": "+0.3 HP/s regen", "tiers": 3, "base_cost": 70, "per": 0.3},
	"magnet": {"name": "Salvage Magnet", "desc": "+15% pickup radius", "tiers": 3, "base_cost": 40, "per": 0.15},
	"choices": {"name": "Tactical Uplink", "desc": "+1 card offered on level up", "tiers": 1, "base_cost": 300, "per": 1.0},
}

var scrap: int = 0
var tiers: Dictionary = {}
var best_time: float = 0.0
var total_kills: int = 0
var runs_played: int = 0
var victories: int = 0


func _ready() -> void:
	load_data()


func tier(id: String) -> int:
	return int(tiers.get(id, 0))


func bonus(id: String) -> float:
	return tier(id) * float(UPGRADES[id]["per"])


func cost(id: String) -> int:
	return int(float(UPGRADES[id]["base_cost"]) * pow(tier(id) + 1, 1.7))


func can_buy(id: String) -> bool:
	return tier(id) < int(UPGRADES[id]["tiers"]) and scrap >= cost(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	scrap -= cost(id)
	tiers[id] = tier(id) + 1
	save_data()
	return true


func record_run(time_survived: float, kills: int, scrap_earned: int, victory: bool) -> void:
	scrap += scrap_earned
	total_kills += kills
	runs_played += 1
	if victory:
		victories += 1
	best_time = maxf(best_time, time_survived)
	save_data()


func save_data() -> void:
	var data := {
		"scrap": scrap,
		"tiers": tiers,
		"best_time": best_time,
		"total_kills": total_kills,
		"runs_played": runs_played,
		"victories": victories,
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
	scrap = int(parsed.get("scrap", 0))
	best_time = float(parsed.get("best_time", 0.0))
	total_kills = int(parsed.get("total_kills", 0))
	runs_played = int(parsed.get("runs_played", 0))
	victories = int(parsed.get("victories", 0))
	tiers = {}
	var t = parsed.get("tiers", {})
	if typeof(t) == TYPE_DICTIONARY:
		for k in t:
			if UPGRADES.has(k):
				tiers[k] = clampi(int(t[k]), 0, int(UPGRADES[k]["tiers"]))

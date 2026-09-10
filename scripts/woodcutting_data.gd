# TinyScape — Woodcutting Skill & Economy Table
class_name WoodcuttingData
extends RefCounted

const MAX_INVENTORY_SLOTS: int = 28

# R3: XP Curve (Level 1..20) per docs/design/woodcutting-skill.md §3 table
const XP_TABLE: Array[int] = [
	0,     # Level 1
	85,    # Level 2
	180,   # Level 3
	290,   # Level 4
	415,   # Level 5
	560,   # Level 6
	725,   # Level 7
	915,   # Level 8
	1135,  # Level 9
	1390,  # Level 10
	1250,  # Level 11 (per spec table in §3)
	1520,  # Level 12
	1840,  # Level 13
	2220,  # Level 14
	2670,  # Level 15
	3200,  # Level 16
	3830,  # Level 17
	4570,  # Level 18
	5440,  # Level 19
	6460   # Level 20
]

# R2, R4, R5: Tree Tiers, Timers, HP & Economy
const TREE_TIERS: Dictionary = {
	"willow": {
		"name": "Willow",
		"level_req": 1,
		"xp_per_log": 20,
		"chop_interval": 1.8,
		"respawn_time": 20.0,
		"hit_points": 3,
		"log_value": 4
	},
	"oak": {
		"name": "Oak",
		"level_req": 1,
		"xp_per_log": 25,
		"chop_interval": 1.8,
		"respawn_time": 25.0,
		"hit_points": 4,
		"log_value": 6
	},
	"pine": {
		"name": "Pine",
		"level_req": 15,
		"xp_per_log": 45,
		"chop_interval": 2.7,
		"respawn_time": 35.0,
		"hit_points": 6,
		"log_value": 14
	}
}

static func get_tree_info(tree_type: String) -> Dictionary:
	var lower = tree_type.to_lower()
	if TREE_TIERS.has(lower):
		return TREE_TIERS[lower]
	return TREE_TIERS["oak"]

static func get_level_for_xp(xp: int) -> int:
	for lvl in range(XP_TABLE.size(), 0, -1):
		if xp >= XP_TABLE[lvl - 1]:
			return lvl
	return 1

static func get_xp_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 0
	if lvl <= XP_TABLE.size():
		return XP_TABLE[lvl - 1]
	return XP_TABLE[XP_TABLE.size() - 1]

static func get_next_level_xp(current_level: int) -> int:
	if current_level < XP_TABLE.size():
		return XP_TABLE[current_level]
	return XP_TABLE[XP_TABLE.size() - 1]
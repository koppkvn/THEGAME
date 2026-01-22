class_name Data

const BOARD = {
	"cols": 9,
	"rows": 9,
	"ring_out": true
}

const OBSTACLES = [
	{"x": 4, "y": 4},
	{"x": 5, "y": 4},
	{"x": 4, "y": 5},
	{"x": 7, "y": 2},
	{"x": 2, "y": 7}
]

static func is_obstacle(x: int, y: int) -> bool:
	for o in OBSTACLES:
		if o.x == x and o.y == y: return true
	return false

# =============================================================================
# SPELLS - Organized by character class
# =============================================================================
# Each spell needs: id, label, desc, type, ap_cost, and type-specific properties
# Types: "ATTACK", "MOVE", "BUFF", "DEBUFF", "HEAL"

# --- RANGER SPELLS ---
const RANGER_SPELLS = {
	# 1) Crossfire Volley - Cross AoE with push
	"CROSSFIRE_VOLLEY": {
		"id": "CROSSFIRE_VOLLEY",
		"label": "Crossfire Volley",
		"desc": "Deal 25 physical damage to target, 15 to adjacent tiles in cross. Push adjacent enemies 1 tile.",
		"type": "ATTACK",
		"range": 6,
		"damage": 25,
		"ap_cost": 18,
		"cooldown": 3,
		"requires_los": true,
		"aoe": "CROSS"
	},
	
	# 2) Piercing Windshot - Line pierce with slow
	"PIERCING_WINDSHOT": {
		"id": "PIERCING_WINDSHOT",
		"label": "Piercing Windshot",
		"desc": "Deal 22 physical damage to all enemies in a straight line. Slows by 30% for 1 turn.",
		"type": "ATTACK",
		"range": 8,
		"damage": 22,
		"ap_cost": 16,
		"cooldown": 2,
		"requires_los": true,
		"aoe": "LINE",
		"cardinal_only": true
	},
	
	# 3) Blazing Scatter - 3x3 AoE with burn
	"BLAZING_SCATTER": {
		"id": "BLAZING_SCATTER",
		"label": "Blazing Scatter",
		"desc": "Deal 28 fire damage in 3x3 area. Burns for 8 damage per turn for 2 turns.",
		"type": "ATTACK",
		"range": 5,
		"damage": 28,
		"ap_cost": 24,
		"cooldown": 4,
		"requires_los": true,
		"aoe": "3X3",
		"damage_type": "FIRE"
	},
	
	# 4) Hawk's Indirect Strike - Delayed, no LOS
	"HAWKS_INDIRECT_STRIKE": {
		"id": "HAWKS_INDIRECT_STRIKE",
		"label": "Hawk's Indirect Strike",
		"desc": "After 1 turn delay, deal 35 damage to target and 20 to adjacent tiles. Ignores walls.",
		"type": "ATTACK",
		"range": 7,
		"damage": 35,
		"ap_cost": 30,
		"cooldown": 5,
		"requires_los": false,
		"aoe": "CROSS",
		"delayed": true
	},
	
	# 5) Repelling Shot - Single target, push 2, collision damage
	"REPELLING_SHOT": {
		"id": "REPELLING_SHOT",
		"label": "Repelling Shot",
		"desc": "Deal 40 physical damage and push target 2 tiles. +20 damage on wall/unit collision.",
		"type": "ATTACK",
		"range": 6,
		"damage": 40,
		"ap_cost": 20,
		"cooldown": 3,
		"requires_los": true,
		"push": 2,
		"collision_damage": 20
	},
	
	# 6) Shadow Rain - Random arrows in 5x5, no LOS
	"SHADOW_RAIN": {
		"id": "SHADOW_RAIN",
		"label": "Shadow Rain",
		"desc": "Rain 10 arrows randomly in 5x5 area. Each arrow deals 15 damage. Can hit same target multiple times.",
		"type": "ATTACK",
		"range": 7,
		"damage": 15,
		"ap_cost": 32,
		"cooldown": 5,
		"requires_los": false,
		"aoe": "5X5_RANDOM",
		"arrow_count": 10
	},
	
	# 7) Pinning Cross - Cross AoE with root
	"PINNING_CROSS": {
		"id": "PINNING_CROSS",
		"label": "Pinning Cross",
		"desc": "Deal 20 physical damage in cross pattern. Roots enemies for 1 turn.",
		"type": "ATTACK",
		"range": 5,
		"damage": 20,
		"ap_cost": 18,
		"cooldown": 3,
		"requires_los": true,
		"aoe": "CROSS"
	},
	
	# 8) Phantom Shot - Pierce walls, reveal
	"PHANTOM_SHOT": {
		"id": "PHANTOM_SHOT",
		"label": "Phantom Shot",
		"desc": "Deal 30 physical damage. Passes through walls. Reveals adjacent tiles for 2 turns.",
		"type": "ATTACK",
		"range": 8,
		"damage": 30,
		"ap_cost": 14,
		"cooldown": 2,
		"requires_los": false,
		"pierces_walls": true
	},
	
	# 9) Cone of Thorns - Cone AoE with bleed
	"CONE_OF_THORNS": {
		"id": "CONE_OF_THORNS",
		"label": "Cone of Thorns",
		"desc": "Deal 24 physical damage in cone. Causes Bleed: 10 damage when moving for 2 turns.",
		"type": "ATTACK",
		"range": 4,
		"damage": 24,
		"ap_cost": 18,
		"cooldown": 3,
		"requires_los": true,
		"aoe": "CONE"
	},
	
	# 10) Marked Detonation - Delayed mark, bonus on status
	"MARKED_DETONATION": {
		"id": "MARKED_DETONATION",
		"label": "Marked Detonation",
		"desc": "Mark target for 1 turn. Explodes for 45 damage in cross pattern. +20 bonus if target has Burn/Bleed.",
		"type": "ATTACK",
		"range": 6,
		"damage": 45,
		"ap_cost": 34,
		"cooldown": 6,
		"requires_los": true,
		"aoe": "CROSS",
		"delayed": true,
		"status_bonus": 20
	}
}

# --- WARRIOR SPELLS ---
const WARRIOR_SPELLS = {
	# Add Warrior spells here
	# Example:
	# "SLASH": {
	#     "id": "SLASH", "label": "Slash", "desc": "Basic melee attack",
	#     "type": "ATTACK", "range": 1, "damage": 15, "ap_cost": 5, "cooldown": 0
	# },
}

# Combined spells dictionary (auto-merged from character classes)
static func get_all_spells() -> Dictionary:
	var all_spells = {}
	all_spells.merge(RANGER_SPELLS)
	all_spells.merge(WARRIOR_SPELLS)
	return all_spells

# Legacy SPELLS constant for compatibility - will be populated dynamically
var SPELLS = {}

# =============================================================================
# CHARACTERS - Two classes: Ranger (ranged) and Warrior (melee)
# =============================================================================
const CHARACTERS = {
	"RANGER": {
		"id": "RANGER",
		"name": "Ranger",
		"class_type": "RANGED",  # Character archetype
		"description": "Master of ranged combat. Deals damage from a distance.",
		"spells": []  # Will be populated with RANGER_SPELLS keys
	},
	"WARRIOR": {
		"id": "WARRIOR",
		"name": "Warrior", 
		"class_type": "MELEE",  # Character archetype
		"description": "Master of close combat. High damage up close.",
		"spells": []  # Will be populated with WARRIOR_SPELLS keys
	}
}

# Helper to get spells for a character
static func get_character_spells(character_id: String) -> Array:
	if character_id == "RANGER":
		return RANGER_SPELLS.keys()
	elif character_id == "WARRIOR":
		return WARRIOR_SPELLS.keys()
	return []

# Helper to get a spell by ID (searches all spell dictionaries)
static func get_spell(spell_id: String) -> Dictionary:
	if RANGER_SPELLS.has(spell_id):
		return RANGER_SPELLS[spell_id]
	if WARRIOR_SPELLS.has(spell_id):
		return WARRIOR_SPELLS[spell_id]
	return {}

# Constants for game balance
const MAX_HP = 100
const MAX_AP = 50
const MAX_MP = 5  # Movement points

static func create_initial_state() -> Dictionary:
	return {
		"turn": {
			"currentPlayerId": "P1",
			"number": 1,
			"apRemaining": MAX_AP,  # Action Points - resets each turn
			"movesRemaining": MAX_MP
		},
		"units": {
			"P1": {
				"id": "P1", "x": 2, "y": 5, "hp": MAX_HP,
				"status": {
					"guard": null,
					"burn": null,      # { "turns": int, "damage": int }
					"bleed": null,     # { "turns": int }
					"slow": null,      # { "turns": int, "amount": float }
					"root": null,      # { "turns": int }
					"revealed": null,  # { "turns": int }
					"stun": null,      # { "turns": int }
					"knocked_down": null,  # { "turns": int }
					"damage_reduction": null,  # { "turns": int, "percent": float }
					"movement_loss": null  # { "turns": int }
				},
				"cooldowns": {}
			},
			"P2": {
				"id": "P2", "x": 7, "y": 4, "hp": MAX_HP,
				"status": {
					"guard": null,
					"burn": null,
					"bleed": null,
					"slow": null,
					"root": null,
					"revealed": null,
					"stun": null,
					"knocked_down": null,
					"damage_reduction": null,
					"movement_loss": null
				},
				"cooldowns": {}
			}
		},
		"pending_effects": [],  # Delayed effects queue
		"winner": null,
		"log": []
	}

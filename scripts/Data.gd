class_name Data

const BOARD = {
	"cols": 9,
	"rows": 9,
	"ring_out": false
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
# SPELLS - Anti-Gravity Character
# =============================================================================
# Each spell needs: id, label, desc, type, ap_cost, range, min_range, casts_per_turn, cooldown
# New mechanics: casts_per_turn (separate from cooldown), min_range, exponential stages

const ANTIGRAVITY_SPELLS = {
	# 1) Knockback Arrow - Push with collision damage
	"KNOCKBACK_ARROW": {
		"id": "KNOCKBACK_ARROW",
		"label": "Knockback Arrow",
		"desc": "Deal 200-400 damage. Push target 3 tiles. +100 damage per blocked tile on collision.",
		"type": "ATTACK",
		"range": 5,
		"min_range": 1,
		"damage_min": 200,
		"damage_max": 400,
		"ap_cost": 3,
		"casts_per_turn": 1,
		"cooldown": 0,
		"requires_los": true,
		"push": 3,
		"collision_damage_per_tile": 100
	},
	
	# 2) Piercing Arrow - Ignores LOS, damage only
	"PIERCING_ARROW": {
		"id": "PIERCING_ARROW",
		"label": "Piercing Arrow",
		"desc": "Deal 100-300 damage. Ignores line of sight. No secondary effects.",
		"type": "ATTACK",
		"range": 8,
		"min_range": 1,
		"damage_min": 100,
		"damage_max": 300,
		"ap_cost": 2,
		"casts_per_turn": 2,
		"cooldown": 0,
		"requires_los": false
	},
	
	# 3) Exponential Arrow - Stage-based damage progression
	"EXPONENTIAL_ARROW": {
		"id": "EXPONENTIAL_ARROW",
		"label": "Exponential Arrow",
		"desc": "Stage 1: 200-600. Stage 2: 600-1200. Stage 3: 3000-4000. Skipping when available resets to Stage 1.",
		"type": "ATTACK",
		"range": 8,
		"min_range": 3,
		"ap_cost": 5,
		"casts_per_turn": 1,
		"cooldown": 2,
		"requires_los": true,
		"stage_damage": {
			1: {"min": 200, "max": 600},
			2: {"min": 600, "max": 1200},
			3: {"min": 3000, "max": 4000}
		}
	},
	
	# 4) Immobilizing Arrow - MP removal
	"IMMOBILIZING_ARROW": {
		"id": "IMMOBILIZING_ARROW",
		"label": "Immobilizing Arrow",
		"desc": "Deal 1-200 damage. Remove 0-2 MP from target for 1 turn.",
		"type": "ATTACK",
		"range": 8,
		"min_range": 1,
		"damage_min": 1,
		"damage_max": 200,
		"ap_cost": 2,
		"casts_per_turn": 2,
		"cooldown": 0,
		"requires_los": true,
		"mp_removal_min": 0,
		"mp_removal_max": 2
	},
	
	# 5) Displacement Arrow - Cross push from empty tile
	"DISPLACEMENT_ARROW": {
		"id": "DISPLACEMENT_ARROW",
		"label": "Displacement Arrow",
		"desc": "Target empty tile. Creates cross (1-3 tiles). Push all in cross 2 tiles from center.",
		"type": "DISPLACEMENT",
		"range": 8,
		"min_range": 1,
		"ap_cost": 4,
		"casts_per_turn": 1,
		"cooldown": 1,
		"requires_los": true,
		"requires_empty_tile": true,
		"cross_range": 3,
		"push_distance": 2
	},
	
	# 6) Thief Arrow - Random effects
	"THIEF_ARROW": {
		"id": "THIEF_ARROW",
		"label": "Thief Arrow",
		"desc": "Deal 0-100 damage. Random: 1/3 steal AP, 1/3 give AP, 1/5 +20% caster dmg, 1/5 +20% target dmg, 1/20 swap HP.",
		"type": "ATTACK",
		"range": 8,
		"min_range": 1,
		"damage_min": 0,
		"damage_max": 100,
		"ap_cost": 1,
		"casts_per_turn": 2,
		"cooldown": 0,
		"requires_los": true,
		"random_effects": true
	}
}

# Combined spells dictionary
static func get_all_spells() -> Dictionary:
	return ANTIGRAVITY_SPELLS.duplicate()

# Helper to get a spell by ID
static func get_spell(spell_id: String) -> Dictionary:
	if ANTIGRAVITY_SPELLS.has(spell_id):
		return ANTIGRAVITY_SPELLS[spell_id]
	return {}

# Get all spell IDs
static func get_character_spells(_character_id: String) -> Array:
	return ANTIGRAVITY_SPELLS.keys()

# Constants for game balance - Anti-Gravity spec
const MAX_HP = 10000
const MAX_AP = 10
const MAX_MP = 4  # Movement points

static func create_initial_state() -> Dictionary:
	return {
		"turn": {
			"currentPlayerId": "P1",
			"number": 1,
			"apRemaining": MAX_AP,
			"movesRemaining": MAX_MP
		},
		"units": {
			"P1": {
				"id": "P1", "x": 2, "y": 5, "hp": MAX_HP,
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
					"movement_loss": null,
					"mp_reduction": null,      # { "turns": int, "amount": int }
					"damage_boost": null       # { "turns": int, "percent": float }
				},
				"cooldowns": {},
				"casts_this_turn": {},         # Track casts per turn per spell
				"exponential_stage": 1,        # Exponential Arrow stage (1-3)
				"exponential_available_last_turn": false  # Track if spell was available
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
					"movement_loss": null,
					"mp_reduction": null,
					"damage_boost": null
				},
				"cooldowns": {},
				"casts_this_turn": {},
				"exponential_stage": 1,
				"exponential_available_last_turn": false
			}
		},
		"pending_effects": [],
		"winner": null,
		"log": []
	}

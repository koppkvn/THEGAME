class_name Data

const BOARD = {
	"cols": 10,
	"rows": 10,
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
	# Add Ranger spells here
	# Example:
	# "ARROW_SHOT": {
	#     "id": "ARROW_SHOT", "label": "Arrow Shot", "desc": "Basic ranged attack",
	#     "type": "ATTACK", "range": 5, "damage": 10, "ap_cost": 5, "cooldown": 0
	# },
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
const MAX_MP = 3  # Movement points

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
				"status": { "guard": null },
				"cooldowns": {}  # Empty - will be populated when spells are added
			},
			"P2": {
				"id": "P2", "x": 3, "y": 1, "hp": MAX_HP,
				"status": { "guard": null },
				"cooldowns": {}  # Empty - will be populated when spells are added
			}
		},
		"winner": null,
		"log": []
	}

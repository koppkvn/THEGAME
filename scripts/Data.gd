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
		"collision_damage_per_tile": 100,
		"icon_atlas": "res://assets/spells/ranger_spells.png",
		"icon_region": Rect2(50, 80, 240, 240)
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
		"requires_los": false,
		"icon_atlas": "res://assets/spells/ranger_spells.png",
		"icon_region": Rect2(391, 80, 240, 240)
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
		},
		"icon_atlas": "res://assets/spells/ranger_spells.png",
		"icon_region": Rect2(732, 80, 240, 240)
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
		"mp_removal_max": 2,
		"icon_atlas": "res://assets/spells/ranger_spells.png",
		"icon_region": Rect2(50, 421, 240, 240)
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
		"push_distance": 2,
		"icon_atlas": "res://assets/spells/ranger_spells.png",
		"icon_region": Rect2(391, 421, 240, 240)
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
		"random_effects": true,
		"icon_atlas": "res://assets/spells/ranger_spells.png",
		"icon_region": Rect2(732, 421, 240, 240)
	}
}

# =============================================================================
# SPELLS - Melee Character
# =============================================================================
# Slightly higher HP (12000) and MP (5) to compensate for melee exposure

const MELEE_SPELLS = {
	# 1) Crushing Strike - Core DPS, punishes displacement
	"CRUSHING_STRIKE": {
		"id": "CRUSHING_STRIKE",
		"label": "Crushing Strike",
		"desc": "Deal 300-500 damage. +200 bonus if target was displaced last turn. Melee only.",
		"type": "ATTACK",
		"range": 1,
		"min_range": 1,
		"damage_min": 300,
		"damage_max": 500,
		"ap_cost": 3,
		"casts_per_turn": 2,
		"cooldown": 0,
		"requires_los": true,
		"melee": true,
		"displacement_bonus": 200,
		"icon_atlas": "res://assets/spells/melee_spells.png",
		"icon_region": Rect2(70, 180, 200, 160)
	},
	
	# 2) Magnetic Pull - Counter to knockback/zoning
	"MAGNETIC_PULL": {
		"id": "MAGNETIC_PULL",
		"label": "Magnetic Pull",
		"desc": "Deal 150-250 damage. Pull target 3 tiles toward you. If adjacent after: -1 MP for 1 turn.",
		"type": "ATTACK",
		"range": 6,
		"min_range": 2,
		"damage_min": 150,
		"damage_max": 250,
		"ap_cost": 3,
		"casts_per_turn": 1,
		"cooldown": 0,
		"requires_los": true,
		"pull_distance": 3,
		"adjacent_mp_reduction": 1,
		"icon_atlas": "res://assets/spells/melee_spells.png",
		"icon_region": Rect2(411, 180, 200, 160)
	},
	
	# 3) Gravity Lock - Remove all MP and deal damage
	"GRAVITY_LOCK": {
		"id": "GRAVITY_LOCK",
		"label": "Gravity Lock",
		"desc": "Deal 300-500 damage. Remove ALL MP from target for this turn.",
		"type": "ATTACK",
		"range": 1,
		"min_range": 1,
		"damage_min": 300,
		"damage_max": 500,
		"ap_cost": 4,
		"casts_per_turn": 1,
		"cooldown": 2,
		"requires_los": true,
		"melee": true,
		"removes_all_mp": true,
		"icon_atlas": "res://assets/spells/melee_spells.png",
		"icon_region": Rect2(752, 180, 200, 160)
	},
	
	# 4) Kinetic Dash - Gap closer with tempo reward
	"KINETIC_DASH": {
		"id": "KINETIC_DASH",
		"label": "Kinetic Dash",
		"desc": "Dash 1-4 tiles in a straight line. If you end adjacent to an enemy: +1 AP this turn.",
		"type": "MOVEMENT",
		"range": 4,
		"min_range": 1,
		"damage_min": 0,
		"damage_max": 0,
		"ap_cost": 2,
		"casts_per_turn": 1,
		"cooldown": 0,
		"requires_los": false,
		"dash": true,
		"adjacent_ap_bonus": 1,
		"icon_atlas": "res://assets/spells/melee_spells.png",
		"icon_region": Rect2(70, 521, 200, 160)
	},
	
	# 5) Shockwave Slam - Anti-surround AoE with push
	"SHOCKWAVE_SLAM": {
		"id": "SHOCKWAVE_SLAM",
		"label": "Shockwave Slam",
		"desc": "Deal 400-600 damage to all adjacent enemies. Push 1 tile. +150 wall collision damage.",
		"type": "ATTACK",
		"range": 1,
		"min_range": 0,  # Targets self/area around caster
		"damage_min": 400,
		"damage_max": 600,
		"ap_cost": 5,
		"casts_per_turn": 1,
		"cooldown": 2,
		"requires_los": false,
		"melee": true,
		"aoe_radius": 1,
		"push_distance": 1,
		"wall_collision_damage": 150,
		"icon_atlas": "res://assets/spells/melee_spells.png",
		"icon_region": Rect2(411, 521, 200, 160)
	},
	
	# 6) Adrenaline Surge - Random effect: +1 MP or heal 300 HP (50% each)
	"ADRENALINE_SURGE": {
		"id": "ADRENALINE_SURGE",
		"label": "Adrenaline Surge",
		"desc": "50% chance: Gain +1 MP this turn. 50% chance: Restore 300 HP.",
		"type": "BUFF",
		"range": 0,
		"min_range": 0,
		"damage_min": 0,
		"damage_max": 0,
		"ap_cost": 1,
		"casts_per_turn": 1,
		"cooldown": 3,
		"requires_los": false,
		"self_cast": true,
		"random_mp_bonus": 1,
		"random_heal": 300,
		"icon_atlas": "res://assets/spells/melee_spells.png",
		"icon_region": Rect2(752, 521, 200, 160)
	}
}

# =============================================================================
# SPELLS - Elemental Mage
# =============================================================================
# Lower HP (8000) but high AP (12) reflecting glass cannon mana pool

const MAGE_SPELLS = {
	# 1) Arcane Missile - Consistent long range damage
	"ARCANE_MISSILE": {
		"id": "ARCANE_MISSILE",
		"label": "Arcane Missile",
		"desc": "Deal 300-400 damage. High range, low cost magic missile.",
		"type": "ATTACK",
		"range": 9,
		"min_range": 1,
		"damage_min": 300,
		"damage_max": 400,
		"ap_cost": 3,
		"casts_per_turn": 3,
		"cooldown": 0,
		"requires_los": true,
		"icon_atlas": "res://assets/spells/mage_spells.png",
		"icon_region": Rect2(50, 50, 240, 240)
	},
	
	# 2) Frost Nova - Close range CC
	"FROST_NOVA": {
		"id": "FROST_NOVA",
		"label": "Frost Nova",
		"desc": "Deal 150-250 damage to all enemies within 2 tiles. Removes 2 MP.",
		"type": "ATTACK",
		"range": 0,
		"min_range": 0,
		"damage_min": 150,
		"damage_max": 250,
		"ap_cost": 4,
		"casts_per_turn": 1,
		"cooldown": 1,
		"requires_los": false,
		"aoe_radius": 2,
		"mp_removal": 2,
		"icon_atlas": "res://assets/spells/mage_spells.png",
		"icon_region": Rect2(391, 50, 240, 240)
	},
	
	# 3) Flame Pillar - Medium range area burn
	"FLAME_PILLAR": {
		"id": "FLAME_PILLAR",
		"label": "Flame Pillar",
		"desc": "Deal 400-600 damage to target and adjacent tiles.",
		"type": "ATTACK",
		"range": 6,
		"min_range": 1,
		"damage_min": 400,
		"damage_max": 600,
		"ap_cost": 5,
		"casts_per_turn": 1,
		"cooldown": 0,
		"requires_los": true,
		"aoe_radius": 1,
		"icon_atlas": "res://assets/spells/mage_spells.png",
		"icon_region": Rect2(732, 50, 240, 240)
	},
	
	# 4) Blink - Tactical teleport
	"BLINK": {
		"id": "BLINK",
		"label": "Blink",
		"desc": "Teleport to a targeted empty tile within 4 tiles. Ignores obstacles.",
		"type": "MOVEMENT",
		"range": 4,
		"min_range": 1,
		"damage_min": 0,
		"damage_max": 0,
		"ap_cost": 2,
		"casts_per_turn": 1,
		"cooldown": 1,
		"requires_los": false,
		"requires_empty_tile": true,
		"teleport": true,
		"icon_atlas": "res://assets/spells/mage_spells.png",
		"icon_region": Rect2(50, 391, 240, 240)
	},
	
	# 5) Arcane Shield - Damage reduction
	"ARCANE_SHIELD": {
		"id": "ARCANE_SHIELD",
		"label": "Arcane Shield",
		"desc": "Reduce incoming damage by 50% for 1 turn.",
		"type": "BUFF",
		"range": 0,
		"min_range": 0,
		"damage_min": 0,
		"damage_max": 0,
		"ap_cost": 3,
		"casts_per_turn": 1,
		"cooldown": 3,
		"requires_los": false,
		"damage_reduction": 0.5,
		"icon_atlas": "res://assets/spells/mage_spells.png",
		"icon_region": Rect2(50, 732, 240, 240)
	},
	
	# 6) Meteor Impact - Massive long range blast
	"METEOR": {
		"id": "METEOR",
		"label": "Meteor",
		"desc": "Deal 800-1200 damage in a huge 3x3 area. Massive cost.",
		"type": "ATTACK",
		"range": 10,
		"min_range": 4,
		"damage_min": 800,
		"damage_max": 1200,
		"ap_cost": 8,
		"casts_per_turn": 1,
		"cooldown": 3,
		"requires_los": true,
		"aoe_radius": 2,
		"icon_atlas": "res://assets/spells/mage_spells.png",
		"icon_region": Rect2(391, 391, 582, 582)
	}
}

# Combined spells dictionary
static func get_all_spells() -> Dictionary:
	var all = ANTIGRAVITY_SPELLS.duplicate()
	for key in MELEE_SPELLS:
		all[key] = MELEE_SPELLS[key]
	for key in MAGE_SPELLS:
		all[key] = MAGE_SPELLS[key]
	return all

# Helper to get a spell by ID
static func get_spell(spell_id: String) -> Dictionary:
	if ANTIGRAVITY_SPELLS.has(spell_id):
		return ANTIGRAVITY_SPELLS[spell_id]
	if MELEE_SPELLS.has(spell_id):
		return MELEE_SPELLS[spell_id]
	if MAGE_SPELLS.has(spell_id):
		return MAGE_SPELLS[spell_id]
	return {}

# Get all spell IDs for a character
static func get_character_spells(character_id: String) -> Array:
	if character_id == "MELEE":
		return MELEE_SPELLS.keys()
	if character_id == "MAGE":
		return MAGE_SPELLS.keys()
	return ANTIGRAVITY_SPELLS.keys()

const MAX_HP = 10000
const MAX_AP = 10
const MAX_MP = 4  # Movement points

# Constants for Melee character (higher HP and MP)
const MELEE_HP = 12000
const MELEE_AP = 10
const MELEE_MP = 3

# Constants for Mage character (Lower HP, Very High AP)
const MAGE_HP = 8000
const MAGE_AP = 12
const MAGE_MP = 4

static func create_initial_state(p1_class: String = "RANGER", p2_class: String = "RANGER") -> Dictionary:
	var p1_hp = MAX_HP
	if p1_class == "MELEE": p1_hp = MELEE_HP
	elif p1_class == "MAGE": p1_hp = MAGE_HP
	
	var p2_hp = MAX_HP
	if p2_class == "MELEE": p2_hp = MELEE_HP
	elif p2_class == "MAGE": p2_hp = MAGE_HP
	
	var p1_mp = MAX_MP
	if p1_class == "MELEE": p1_mp = MELEE_MP
	elif p1_class == "MAGE": p1_mp = MAGE_MP
	
	var p1_ap = MAX_AP
	if p1_class == "MAGE": p1_ap = MAGE_AP
	
	return {
		"turn": {
			"currentPlayerId": "P1",
			"number": 1,
			"apRemaining": p1_ap,
			"movesRemaining": p1_mp
		},
		"units": {
			"P1": {
				"id": "P1", "x": 2, "y": 5, "hp": p1_hp,
				"character_class": p1_class,
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
					"damage_boost": null,      # { "turns": int, "percent": float }
					"gravity_lock": null,      # { "turns": int } - cannot be pushed/pulled, no MP gain
					"was_displaced": null,     # { "turns": int } - was pushed/pulled last turn
					"adrenaline_surge_pending": null  # { "heal": int } - check at end of turn
				},
				"cooldowns": {},
				"casts_this_turn": {},         # Track casts per turn per spell
				"exponential_stage": 1,        # Exponential Arrow stage (1-3)
				"exponential_available_last_turn": false  # Track if spell was available
			},
			"P2": {
				"id": "P2", "x": 7, "y": 4, "hp": p2_hp,
				"character_class": p2_class,
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
					"damage_boost": null,
					"gravity_lock": null,
					"was_displaced": null,
					"adrenaline_surge_pending": null
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

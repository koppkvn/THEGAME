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


const SPELLS = {
	# Duelist
	"STRIKE": {
		"id": "STRIKE", "label": "Strike", "desc": "Melee 3", 
		"type": "ATTACK", "range": 1, "damage": 2, "cooldown": 0
	},
	"DASH": {
		"id": "DASH", "label": "Dash", "desc": "Move 3", 
		"type": "MOVE", "range": 2, "cooldown": 2
	},
	"GUARD": {
		"id": "GUARD", "label": "Guard", "desc": "Shield", 
		"type": "BUFF", "cooldown": 3
	},
	"FORCE": {
		"id": "FORCE", "label": "Force", "desc": "Push 3", 
		"type": "ATTACK", "range": 2, "damage": 1, "push": 1, "cooldown": 3
	},
	
	# Ranged (Merged Client + Server logic)
	"SHOT": {
		"id": "SHOT", "label": "Shot", "desc": "R3 Dmg1", 
		"type": "ATTACK", "range": 3, "damage": 1, "cooldown": 0
	},
	"SNIPE": {
		"id": "SNIPE", "label": "Snipe", "desc": "R8 Dmg2", 
		"type": "ATTACK", "range": 8, "damage": 2, "cooldown": 2
	},
	"BACKSTEP": {
		"id": "BACKSTEP", "label": "Backstep", "desc": "Evade", 
		"type": "MOVE", "cooldown": 1
	},
	# NET omitted per source
}

const CHARACTERS = {
	"DUELIST": {
		"id": "DUELIST",
		"name": "Duelist",
		"spells": ["STRIKE", "DASH", "GUARD", "FORCE"]
	},
	"RANGED": {
		"id": "RANGED",
		"name": "Ranged",
		"spells": ["SHOT", "SNIPE", "BACKSTEP"]
	}
}

static func create_initial_state() -> Dictionary:
	return {
		"turn": {
			"currentPlayerId": "P1",
			"number": 1,
			"actionTaken": false,
			"movesRemaining": 3
		},
		"units": {
			"P1": {
				"id": "P1", "x": 2, "y": 5, "hp": 10,
				"status": { "guard": null },
				"cooldowns": { "STRIKE": 0, "DASH": 0, "GUARD": 0, "FORCE": 0, "SHOT":0, "SNIPE":0, "BACKSTEP":0 }
			},
			"P2": {
				"id": "P2", "x": 3, "y": 1, "hp": 10,
				"status": { "guard": null },
				"cooldowns": { "STRIKE": 0, "DASH": 0, "GUARD": 0, "FORCE": 0, "SHOT":0, "SNIPE":0, "BACKSTEP":0 }
			}
		},
		"winner": null,
		"log": []
	}

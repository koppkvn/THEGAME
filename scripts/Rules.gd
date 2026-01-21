class_name Rules
# =============================================================================
# RULES ENGINE - Handles spell resolution, status effects, and delayed effects
# =============================================================================
# Status Effects: burn, bleed, slow, root, revealed
# Delayed Effects: pending_effects queue processed at turn end
# AoE Patterns: cross, 3x3, line, cone
# =============================================================================

static func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < Data.BOARD.cols and y >= 0 and y < Data.BOARD.rows

static func get_unit_at(state: Dictionary, x: int, y: int):
	var u1 = state.units.P1
	var u2 = state.units.P2
	if u1.x == x and u1.y == y and u1.hp > 0: return u1
	if u2.x == x and u2.y == y and u2.hp > 0: return u2
	return null

static func dist_manhattan(u1, u2) -> int:
	return abs(u1.x - u2.x) + abs(u1.y - u2.y)

static func has_line_of_sight(state: Dictionary, from_u, to_u) -> bool:
	return has_line_of_sight_to_cell(from_u.x, from_u.y, to_u.x, to_u.y)

static func has_line_of_sight_to_cell(from_x: int, from_y: int, to_x: int, to_y: int) -> bool:
	var x0 = from_x
	var y0 = from_y
	var x1 = to_x
	var y1 = to_y
	
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	
	while true:
		if Data.is_obstacle(x0, y0):
			return false
			
		if x0 == x1 and y0 == y1: break
		
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
			
	return true

static func push_log(state: Dictionary, msg: String) -> void:
	state.log.append(msg)
	if state.log.size() > 12:
		state.log.pop_front()

static func get_path_distance(state: Dictionary, from_x: int, from_y: int, to_x: int, to_y: int) -> int:
	# BFS to find shortest path distance, returns -1 if unreachable
	if from_x == to_x and from_y == to_y: return 0
	
	var visited = {}
	var queue = []
	var start_key = "%d,%d" % [from_x, from_y]
	visited[start_key] = true
	queue.append({"x": from_x, "y": from_y, "dist": 0})
	
	# 8 directions including diagonals
	var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	

	while queue.size() > 0:
		var current = queue.pop_front()
		
		for d in dirs:
			var nx = current.x + d.x
			var ny = current.y + d.y
			var key = "%d,%d" % [nx, ny]
			
			# Diagonal costs 2, cardinal costs 1
			var move_cost = 2 if (d.x != 0 and d.y != 0) else 1
			var new_dist = current.dist + move_cost
			
			if visited.has(key): continue
			if not in_bounds(nx, ny): continue
			if Data.is_obstacle(nx, ny): continue
			if get_unit_at(state, nx, ny): continue
			
			if nx == to_x and ny == to_y:
				return new_dist
			
			visited[key] = true
			queue.append({"x": nx, "y": ny, "dist": new_dist})
	
	return -1

# Get the actual path from one tile to another, returning array of positions to walk through
static func find_movement_path(state: Dictionary, from_x: int, from_y: int, to_x: int, to_y: int) -> Array:
	if from_x == to_x and from_y == to_y: return []
	
	var visited = {}
	var parent = {}  # Track where we came from for path reconstruction
	var queue = []
	var start_key = "%d,%d" % [from_x, from_y]
	visited[start_key] = 0
	queue.append({"x": from_x, "y": from_y, "dist": 0})
	
	# 8 directions including diagonals
	var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	
	var found = false
	while queue.size() > 0 and not found:
		var current = queue.pop_front()
		var current_key = "%d,%d" % [current.x, current.y]
		
		for d in dirs:
			var nx = current.x + d.x
			var ny = current.y + d.y
			var key = "%d,%d" % [nx, ny]
			
			# Diagonal costs 2, cardinal costs 1
			var move_cost = 2 if (d.x != 0 and d.y != 0) else 1
			var new_dist = current.dist + move_cost
			
			if visited.has(key) and visited[key] <= new_dist: continue
			if not in_bounds(nx, ny): continue
			if Data.is_obstacle(nx, ny): continue
			if get_unit_at(state, nx, ny): continue
			
			visited[key] = new_dist
			parent[key] = current_key
			
			if nx == to_x and ny == to_y:
				found = true
				break
			
			queue.append({"x": nx, "y": ny, "dist": new_dist})
	
	if not found:
		return []
	
	# Reconstruct path from destination to start
	var path = []
	var current_key = "%d,%d" % [to_x, to_y]
	while parent.has(current_key):
		var parts = current_key.split(",")
		path.push_front({"x": int(parts[0]), "y": int(parts[1])})
		current_key = parent[current_key]
	
	return path

# =============================================================================
# AOE PATTERN HELPERS
# =============================================================================

# Get tiles in cross pattern (center + 4 cardinal adjacent)
static func get_cross_tiles(cx: int, cy: int) -> Array:
	return [
		{"x": cx, "y": cy},
		{"x": cx + 1, "y": cy}, {"x": cx - 1, "y": cy},
		{"x": cx, "y": cy + 1}, {"x": cx, "y": cy - 1}
	]

# Get tiles in 3x3 area centered on target
static func get_3x3_tiles(cx: int, cy: int) -> Array:
	var tiles = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			tiles.append({"x": cx + dx, "y": cy + dy})
	return tiles

# Get tiles in 5x5 area centered on target
static func get_5x5_tiles(cx: int, cy: int) -> Array:
	var tiles = []
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			tiles.append({"x": cx + dx, "y": cy + dy})
	return tiles

# Get tiles in a line from caster in a cardinal direction until wall/boundary
static func get_line_tiles(sx: int, sy: int, dir: Vector2i, max_range: int, ignore_walls: bool = false) -> Array:
	var tiles = []
	for i in range(1, max_range + 1):
		var nx = sx + dir.x * i
		var ny = sy + dir.y * i
		if not in_bounds(nx, ny):
			break
		if not ignore_walls and Data.is_obstacle(nx, ny):
			break
		tiles.append({"x": nx, "y": ny})
	return tiles

# Get tiles in a forward-facing cone (widens by 1 each row)
static func get_cone_tiles(sx: int, sy: int, dir: Vector2i, range_val: int) -> Array:
	var tiles = []
	for i in range(1, range_val + 1):
		# Width at this distance (1 at distance 1, 3 at distance 2, 5 at distance 3, etc.)
		var width = i
		var cx = sx + dir.x * i
		var cy = sy + dir.y * i
		
		# Perpendicular direction
		var perp = Vector2i(-dir.y, dir.x) if dir.x != 0 or dir.y != 0 else Vector2i(1, 0)
		
		for w in range(-width + 1, width):
			var tx = cx + perp.x * w
			var ty = cy + perp.y * w
			if in_bounds(tx, ty):
				tiles.append({"x": tx, "y": ty})
	return tiles

# Get direction vector from caster to target (normalized to cardinal)
static func get_cardinal_direction(from_x: int, from_y: int, to_x: int, to_y: int) -> Vector2i:
	var dx = to_x - from_x
	var dy = to_y - from_y
	if abs(dx) >= abs(dy):
		return Vector2i(sign(dx), 0) if dx != 0 else Vector2i(0, sign(dy))
	else:
		return Vector2i(0, sign(dy)) if dy != 0 else Vector2i(sign(dx), 0)

# Get preview tiles for spell AOE based on spell type and target position
static func get_aoe_preview_tiles(state: Dictionary, caster_id: String, spell_id: String, target_x: int, target_y: int) -> Array:
	var spell = Data.get_spell(spell_id)
	if spell.is_empty(): return []
	
	var caster = state.units[caster_id]
	var aoe_type = spell.get("aoe", "")
	var tiles = []
	
	match aoe_type:
		"CROSS":
			tiles = get_cross_tiles(target_x, target_y)
		"3X3":
			tiles = get_3x3_tiles(target_x, target_y)
		"5X5_RANDOM":
			tiles = get_5x5_tiles(target_x, target_y)
		"LINE":
			var dir = get_cardinal_direction(caster.x, caster.y, target_x, target_y)
			tiles = get_line_tiles(caster.x, caster.y, dir, spell.get("range", 8), false)
		"CONE":
			var dir = get_cardinal_direction(caster.x, caster.y, target_x, target_y)
			tiles = get_cone_tiles(caster.x, caster.y, dir, spell.get("range", 4))
		_:
			# Single target spell - just show target tile
			tiles = [{"x": target_x, "y": target_y}]
	
	# Filter to only include in-bounds tiles
	var valid_tiles = []
	for tile in tiles:
		if in_bounds(tile.x, tile.y):
			valid_tiles.append(tile)
	
	return valid_tiles

# =============================================================================
# STATUS EFFECT SYSTEM
# =============================================================================

# Apply a status effect to a unit
static func apply_status(unit: Dictionary, effect: String, data: Dictionary) -> void:
	if not unit.status.has(effect) or unit.status[effect] == null:
		unit.status[effect] = data
	else:
		# For damage_reduction, keep highest value
		if effect == "damage_reduction":
			if data.percent > unit.status[effect].percent:
				unit.status[effect] = data
			else:
				unit.status[effect].turns = max(unit.status[effect].turns, data.turns)
		else:
			# Stack by refreshing duration to max
			unit.status[effect].turns = max(unit.status[effect].turns, data.turns)

# Check if unit has a specific status
static func has_status(unit: Dictionary, effect: String) -> bool:
	return unit.status.has(effect) and unit.status[effect] != null

# Process burn damage at turn start (ignores armor/damage reduction)
static func process_burn(state: Dictionary, pid: String) -> void:
	var unit = state.units[pid]
	if has_status(unit, "burn"):
		var burn_dmg = unit.status.burn.damage
		# Burn ignores armor - apply directly
		unit.hp = max(0, unit.hp - burn_dmg)
		push_log(state, "%s burns for %d damage (ignores armor)" % [pid, burn_dmg])
		unit.status.burn.turns -= 1
		if unit.status.burn.turns <= 0:
			unit.status.burn = null
		check_win(state)

# Process bleed damage at end of turn (10 HP per spec)
static func process_bleed(state: Dictionary, pid: String) -> void:
	var unit = state.units[pid]
	if has_status(unit, "bleed"):
		var bleed_dmg = 10  # Fixed 10 HP per spec
		unit.hp = max(0, unit.hp - bleed_dmg)
		push_log(state, "%s bleeds for %d damage" % [pid, bleed_dmg])
		unit.status.bleed.turns -= 1
		if unit.status.bleed.turns <= 0:
			unit.status.bleed = null
			push_log(state, "%s: bleed wore off" % pid)
		check_win(state)

# Check if unit is rooted (cannot move but can attack/use abilities)
static func is_rooted(unit: Dictionary) -> bool:
	return has_status(unit, "root")

# Check if unit is stunned (cannot move, attack, or use abilities)
static func is_stunned(unit: Dictionary) -> bool:
	return has_status(unit, "stun")

# Check if unit is knocked down (cannot move but can attack/use abilities)
static func is_knocked_down(unit: Dictionary) -> bool:
	return has_status(unit, "knocked_down")

# Check if unit has movement loss (loses movement action)
static func has_movement_loss(unit: Dictionary) -> bool:
	return has_status(unit, "movement_loss")

# Get damage reduction percentage (0.0 to 1.0)
static func get_damage_reduction(unit: Dictionary) -> float:
	if has_status(unit, "damage_reduction"):
		return unit.status.damage_reduction.percent
	return 0.0

# Check if unit is slowed (reduced movement)
static func get_slow_amount(unit: Dictionary) -> float:
	if has_status(unit, "slow"):
		return unit.status.slow.amount
	return 0.0

# Decrement all status effect durations at turn start
static func tick_status_effects(state: Dictionary, pid: String) -> void:
	var unit = state.units[pid]
	var effects_to_check = ["slow", "root", "revealed", "stun", "knocked_down", "damage_reduction", "movement_loss"]
	for effect in effects_to_check:
		if has_status(unit, effect):
			unit.status[effect].turns -= 1
			if unit.status[effect].turns <= 0:
				unit.status[effect] = null
				push_log(state, "%s: %s wore off" % [pid, effect])

# =============================================================================
# DELAYED EFFECT SYSTEM (for Hawk's Indirect Strike, Marked Detonation)
# =============================================================================

# Add a pending delayed effect
static func add_pending_effect(state: Dictionary, effect: Dictionary) -> void:
	if not state.has("pending_effects"):
		state["pending_effects"] = []
	state.pending_effects.append(effect)
	push_log(state, "Delayed effect queued for turn %d" % effect.trigger_turn)

# Process all pending effects that should trigger this turn
static func process_pending_effects(state: Dictionary) -> void:
	if not state.has("pending_effects"):
		return
	
	var current_turn = state.turn.number
	var to_remove = []
	
	for i in range(state.pending_effects.size()):
		var effect = state.pending_effects[i]
		if effect.trigger_turn <= current_turn:
			resolve_delayed_effect(state, effect)
			to_remove.append(i)
	
	# Remove processed effects (reverse order to preserve indices)
	for i in range(to_remove.size() - 1, -1, -1):
		state.pending_effects.remove_at(to_remove[i])

# Resolve a delayed effect
static func resolve_delayed_effect(state: Dictionary, effect: Dictionary) -> void:
	push_log(state, "Delayed effect triggers!")
	
	match effect.spell_id:
		"HAWKS_INDIRECT_STRIKE":
			# 35 damage to center, 20 to adjacent
			var tiles = get_cross_tiles(effect.target_x, effect.target_y)
			for tile in tiles:
				var target_unit = get_unit_at(state, tile.x, tile.y)
				if target_unit:
					var dmg = 35 if (tile.x == effect.target_x and tile.y == effect.target_y) else 20
					target_unit.hp = max(0, target_unit.hp - dmg)
					push_log(state, "%s hit for %d (Hawk's Strike)" % [target_unit.id, dmg])
			check_win(state)
			
		"MARKED_DETONATION":
			# 45 damage to center and adjacent, +20 if burn/bleed
			var tiles = get_cross_tiles(effect.target_x, effect.target_y)
			for tile in tiles:
				var target_unit = get_unit_at(state, tile.x, tile.y)
				if target_unit:
					var dmg = 45
					# Bonus damage if target has burn or bleed
					if has_status(target_unit, "burn") or has_status(target_unit, "bleed"):
						dmg += 20
						push_log(state, "Bonus damage from status!")
					target_unit.hp = max(0, target_unit.hp - dmg)
					push_log(state, "%s hit for %d (Detonation)" % [target_unit.id, dmg])
			check_win(state)

# =============================================================================
# ENHANCED DAMAGE AND PUSH SYSTEM
# =============================================================================

# Deal damage to a unit at specific coordinates (for AoE)
# Note: For burn damage (which ignores armor), call unit.hp directly instead
static func deal_damage_at(state: Dictionary, x: int, y: int, amount: int, source: String = "", ignore_reduction: bool = false) -> bool:
	var target = get_unit_at(state, x, y)
	if target:
		var dmg = amount
		# Guard mitigation
		if target.status.guard != null:
			dmg = max(0, dmg - target.status.guard.value)
			target.status.guard = null
			push_log(state, "Guard absorbed damage")
		# Apply damage reduction (percentage-based)
		if not ignore_reduction and has_status(target, "damage_reduction"):
			var reduction = get_damage_reduction(target)
			var reduced_dmg = int(dmg * (1.0 - reduction))
			push_log(state, "Damage reduced by %d%%" % int(reduction * 100))
			dmg = reduced_dmg
		target.hp = max(0, target.hp - dmg)
		if source != "":
			push_log(state, "%s hit for %d (%s)" % [target.id, dmg, source])
		else:
			push_log(state, "%s hit for %d damage" % [target.id, dmg])
		check_win(state)
		return true
	return false

# Push a unit multiple tiles away from a point, with optional collision damage
static func push_unit_from(state: Dictionary, target: Dictionary, from_x: int, from_y: int, distance: int, collision_damage: int = 0) -> void:
	var dx = target.x - from_x
	var dy = target.y - from_y
	var push_dir_x = 0
	var push_dir_y = 0
	
	# Determine push direction
	if abs(dx) > abs(dy):
		push_dir_x = sign(dx)
	elif abs(dy) > abs(dx):
		push_dir_y = sign(dy)
	else:
		if dy != 0:
			push_dir_y = sign(dy)
		else:
			push_dir_x = sign(dx) if dx != 0 else 1
	
	# Push tile by tile
	var pushed = 0
	for i in range(distance):
		var nx = target.x + push_dir_x
		var ny = target.y + push_dir_y
		
		# Check bounds
		if not in_bounds(nx, ny):
			if Data.BOARD.ring_out:
				target.hp = 0
				push_log(state, "Ring Out!")
				check_win(state)
			elif collision_damage > 0:
				target.hp = max(0, target.hp - collision_damage)
				push_log(state, "Wall collision! +%d damage" % collision_damage)
				check_win(state)
			return
		
		# Check wall collision
		if Data.is_obstacle(nx, ny):
			if collision_damage > 0:
				target.hp = max(0, target.hp - collision_damage)
				push_log(state, "Wall collision! +%d damage" % collision_damage)
				check_win(state)
			return
		
		# Check unit collision
		var blocking_unit = get_unit_at(state, nx, ny)
		if blocking_unit:
			if collision_damage > 0:
				target.hp = max(0, target.hp - collision_damage)
				blocking_unit.hp = max(0, blocking_unit.hp - collision_damage)
				push_log(state, "Unit collision! Both take %d damage" % collision_damage)
				check_win(state)
			return
		
		# Move unit
		target.x = nx
		target.y = ny
		pushed += 1
	
	if pushed > 0:
		push_log(state, "%s pushed %d tiles" % [target.id, pushed])

# =============================================================================
# MAIN ACTION HANDLER
# =============================================================================

static func apply_action(state: Dictionary, action: Dictionary) -> Dictionary:
	# Deep copy state (simple dictionary duplication)
	var next = state.duplicate(true)
	var pid = action.playerId
	
	if next.winner != null: return state
	if next.turn.currentPlayerId != pid and action.type != "END_TURN": return state

	
	var me = next.units[pid]
	var other_id = "P2" if pid == "P1" else "P1"
	var enemy = next.units[other_id]
	
	if action.type == "MOVE":
		var tx = action.to.x
		var ty = action.to.y
		if not in_bounds(tx, ty): return state
		if get_unit_at(next, tx, ty): return state
		if next.turn.movesRemaining <= 0: return state
		
		# Check movement-blocking statuses
		if is_stunned(me):
			push_log(next, "%s is stunned and cannot move!" % pid)
			return state
		if is_rooted(me):
			push_log(next, "%s is rooted and cannot move!" % pid)
			return state
		if is_knocked_down(me):
			push_log(next, "%s is knocked down and cannot move!" % pid)
			return state
		if has_movement_loss(me):
			push_log(next, "%s has lost movement this turn!" % pid)
			return state
		
		# Calculate path distance via BFS
		var path_dist = get_path_distance(next, me.x, me.y, tx, ty)
		if path_dist < 0 or path_dist > next.turn.movesRemaining: return state
		
		me.x = tx
		me.y = ty
		next.turn.movesRemaining -= path_dist
		push_log(next, "%s moved to (%d,%d)" % [pid, tx, ty])
		
		# Movement does NOT end turn - player can still cast spell
		return next


	elif action.type == "CAST":
		# Check if stunned - cannot use abilities
		if is_stunned(me):
			push_log(next, "%s is stunned and cannot act!" % pid)
			return state
		
		var spell_id = action.spellId
		var target = action.target
		var spell = Data.get_spell(spell_id)
		if spell.is_empty(): return state
		
		# Check cooldown
		if me.cooldowns.get(spell_id, 0) > 0: return state
		
		# Check AP cost
		var ap_cost = spell.get("ap_cost", 0)
		if next.turn.apRemaining < ap_cost: return state
		
		# Deduct AP and set cooldown
		next.turn.apRemaining -= ap_cost
		me.cooldowns[spell_id] = spell.get("cooldown", 0)
		push_log(next, "%s casts %s (-%d AP, %d remaining)" % [pid, spell.label, ap_cost, next.turn.apRemaining])
		
		# =================================================================
		# RANGER SPELL RESOLUTION
		# =================================================================
		
		match spell_id:
			# ---------------------------------------------------------
			# 1) CROSSFIRE VOLLEY - Cross AoE with push
			# ---------------------------------------------------------
			"CROSSFIRE_VOLLEY":
				var d = dist_manhattan(me, target)
				if d > spell.range or d == 0: return state
				if not has_line_of_sight_to_cell(me.x, me.y, target.x, target.y): return state
				
				var tiles = get_cross_tiles(target.x, target.y)
				var pushed_units = []
				for tile in tiles:
					if not in_bounds(tile.x, tile.y): continue
					var dmg = 25 if (tile.x == target.x and tile.y == target.y) else 15
					var hit_unit = get_unit_at(next, tile.x, tile.y)
					if hit_unit:
						deal_damage_at(next, tile.x, tile.y, dmg, "Crossfire Volley")
						# Push adjacent hits 1 tile away if not center
						if not (tile.x == target.x and tile.y == target.y) and hit_unit.hp > 0:
							pushed_units.append(hit_unit)
				# Push after dealing all damage
				for unit in pushed_units:
					push_unit_from(next, unit, target.x, target.y, 1, 0)
				return next
			
			# ---------------------------------------------------------
			# 2) PIERCING WINDSHOT - Line pierce with slow
			# ---------------------------------------------------------
			"PIERCING_WINDSHOT":
				# Target must be in a straight cardinal line
				var dir = get_cardinal_direction(me.x, me.y, target.x, target.y)
				if dir == Vector2i(0, 0): return state
				if not has_line_of_sight_to_cell(me.x, me.y, target.x, target.y): return state
				
				# Get all tiles in line until wall/boundary (up to 8 range)
				var line_tiles = get_line_tiles(me.x, me.y, dir, 8, false)
				for tile in line_tiles:
					var hit_unit = get_unit_at(next, tile.x, tile.y)
					if hit_unit:
						deal_damage_at(next, tile.x, tile.y, 22, "Piercing Windshot")
						if hit_unit.hp > 0:
							apply_status(hit_unit, "slow", {"turns": 1, "amount": 0.30})
							push_log(next, "%s slowed!" % hit_unit.id)
				return next
			
			# ---------------------------------------------------------
			# 3) BLAZING SCATTER - 3x3 AoE with burn
			# ---------------------------------------------------------
			"BLAZING_SCATTER":
				var d = dist_manhattan(me, target)
				if d > spell.range or d == 0: return state
				if not has_line_of_sight_to_cell(me.x, me.y, target.x, target.y): return state
				
				var tiles = get_3x3_tiles(target.x, target.y)
				for tile in tiles:
					if not in_bounds(tile.x, tile.y): continue
					var hit_unit = get_unit_at(next, tile.x, tile.y)
					if hit_unit:
						deal_damage_at(next, tile.x, tile.y, 28, "Blazing Scatter")
						if hit_unit.hp > 0:
							apply_status(hit_unit, "burn", {"turns": 2, "damage": 8})
							push_log(next, "%s is burning!" % hit_unit.id)
				return next
			
			# ---------------------------------------------------------
			# 4) HAWK'S INDIRECT STRIKE - Delayed, no LOS
			# ---------------------------------------------------------
			"HAWKS_INDIRECT_STRIKE":
				var d = dist_manhattan(me, target)
				if d > spell.range or d == 0: return state
				# No LOS check - this spell ignores walls
				
				# Queue delayed effect for next turn
				add_pending_effect(next, {
					"spell_id": "HAWKS_INDIRECT_STRIKE",
					"trigger_turn": next.turn.number + 1,
					"target_x": target.x,
					"target_y": target.y,
					"caster_id": pid
				})
				push_log(next, "Hawk's Strike incoming at (%d,%d)!" % [target.x, target.y])
				return next
			
			# ---------------------------------------------------------
			# 5) REPELLING SHOT - Single target, push 2, collision damage
			# ---------------------------------------------------------
			"REPELLING_SHOT":
				var d = dist_manhattan(me, target)
				if d > spell.range or d == 0: return state
				if not has_line_of_sight_to_cell(me.x, me.y, target.x, target.y): return state
				
				var hit_unit = get_unit_at(next, target.x, target.y)
				if hit_unit:
					deal_damage_at(next, target.x, target.y, 40, "Repelling Shot")
					if hit_unit.hp > 0:
						push_unit_from(next, hit_unit, me.x, me.y, 2, 20)  # +20 collision dmg
				else:
					push_log(next, "No target at location")
				return next
			
			# ---------------------------------------------------------
			# 6) SHADOW RAIN - Random arrows in 5x5, no LOS
			# ---------------------------------------------------------
			"SHADOW_RAIN":
				var d = dist_manhattan(me, target)
				if d > spell.range or d == 0: return state
				# No LOS check
				
				var tiles = get_5x5_tiles(target.x, target.y)
				var valid_tiles = []
				for tile in tiles:
					if in_bounds(tile.x, tile.y):
						valid_tiles.append(tile)
				
				# Fire ~10 random arrows
				var num_arrows = 10
				for i in range(num_arrows):
					if valid_tiles.size() == 0: break
					var rand_idx = randi() % valid_tiles.size()
					var tile = valid_tiles[rand_idx]
					var hit_unit = get_unit_at(next, tile.x, tile.y)
					if hit_unit:
						hit_unit.hp = max(0, hit_unit.hp - 15)
						push_log(next, "Arrow hits %s for 15!" % hit_unit.id)
				check_win(next)
				return next
			
			# ---------------------------------------------------------
			# 7) PINNING CROSS - Cross AoE with root
			# ---------------------------------------------------------
			"PINNING_CROSS":
				var d = dist_manhattan(me, target)
				if d > spell.range or d == 0: return state
				if not has_line_of_sight_to_cell(me.x, me.y, target.x, target.y): return state
				
				var tiles = get_cross_tiles(target.x, target.y)
				for tile in tiles:
					if not in_bounds(tile.x, tile.y): continue
					var hit_unit = get_unit_at(next, tile.x, tile.y)
					if hit_unit:
						deal_damage_at(next, tile.x, tile.y, 20, "Pinning Cross")
						if hit_unit.hp > 0:
							apply_status(hit_unit, "root", {"turns": 1})
							push_log(next, "%s is rooted!" % hit_unit.id)
				return next
			
			# ---------------------------------------------------------
			# 8) PHANTOM SHOT - Pierce walls, reveal
			# ---------------------------------------------------------
			"PHANTOM_SHOT":
				var d = dist_manhattan(me, target)
				if d > spell.range or d == 0: return state
				# No LOS check - projectile passes through walls
				
				var hit_unit = get_unit_at(next, target.x, target.y)
				if hit_unit:
					deal_damage_at(next, target.x, target.y, 30, "Phantom Shot")
					if hit_unit.hp > 0:
						apply_status(hit_unit, "revealed", {"turns": 2})
						push_log(next, "%s revealed!" % hit_unit.id)
				else:
					push_log(next, "No target at location")
				return next
			
			# ---------------------------------------------------------
			# 9) CONE OF THORNS - Cone AoE with bleed
			# ---------------------------------------------------------
			"CONE_OF_THORNS":
				# Get direction from click position
				var dir = get_cardinal_direction(me.x, me.y, target.x, target.y)
				if dir == Vector2i(0, 0): return state
				if not has_line_of_sight_to_cell(me.x, me.y, target.x, target.y): return state
				
				var cone_tiles = get_cone_tiles(me.x, me.y, dir, 4)
				for tile in cone_tiles:
					if not in_bounds(tile.x, tile.y): continue
					var hit_unit = get_unit_at(next, tile.x, tile.y)
					if hit_unit:
						deal_damage_at(next, tile.x, tile.y, 24, "Cone of Thorns")
						if hit_unit.hp > 0:
							apply_status(hit_unit, "bleed", {"turns": 2})
							push_log(next, "%s is bleeding!" % hit_unit.id)
				return next
			
			# ---------------------------------------------------------
			# 10) MARKED DETONATION - Delayed mark, bonus on status
			# ---------------------------------------------------------
			"MARKED_DETONATION":
				var d = dist_manhattan(me, target)
				if d > spell.range or d == 0: return state
				if not has_line_of_sight_to_cell(me.x, me.y, target.x, target.y): return state
				
				# Queue delayed effect for next turn
				add_pending_effect(next, {
					"spell_id": "MARKED_DETONATION",
					"trigger_turn": next.turn.number + 1,
					"target_x": target.x,
					"target_y": target.y,
					"caster_id": pid
				})
				push_log(next, "Mark placed at (%d,%d) - detonates next turn!" % [target.x, target.y])
				return next
		
		# =================================================================
		# GENERIC SPELL TYPE FALLBACK (for non-Ranger spells)
		# =================================================================
		if spell.type == "ATTACK":
			var d = dist_manhattan(me, target)
			if d > spell.get("range", 1) or d == 0: return state
			
			# Check if enemy is at target
			if target.x == enemy.x and target.y == enemy.y:
				var damage_type = "MELEE" if spell.get("range", 1) <= 1 else "RANGED"
				resolve_damage(next, me, enemy, spell.get("damage", 0), damage_type)
				
				# Handle push if spell has it
				if spell.has("push") and enemy.hp > 0:
					resolve_push(next, me, enemy)
			else:
				push_log(next, "No target at location")
				
		elif spell.type == "MOVE":
			# Movement spells (like dash)
			me.x = target.x
			me.y = target.y
			
		elif spell.type == "BUFF":
			# Self-buff spells
			if spell.has("guard_value"):
				me.status.guard = { "value": spell.guard_value }
		
		return next
			
	elif action.type == "END_TURN":
		push_log(next, "%s ends turn" % pid)
		handle_turn_end(next)
		return next
		
	return state

static func resolve_damage(state, attacker, defender, amount, type):
	var dmg = amount
	var countered = false
	
	if defender.status.guard != null:
		dmg = max(0, dmg - defender.status.guard.value)
		defender.status.guard = null
		push_log(state, "Guard reduced damage")
		if type == "MELEE": countered = true
	
	defender.hp = max(0, defender.hp - dmg)
	push_log(state, "%s took %d damage" % [defender.id, dmg])
	check_win(state)
	
	if countered and defender.hp > 0 and attacker.hp > 0:
		attacker.hp = max(0, attacker.hp - 1)
		push_log(state, "Counter-attack hit %s" % attacker.id)
		check_win(state)

static func resolve_push(state, pusher, target):
	var dx = target.x - pusher.x
	var dy = target.y - pusher.y
	var push_x = 0
	var push_y = 0
	
	if abs(dx) > abs(dy): push_x = sign(dx)
	elif abs(dy) > abs(dx): push_y = sign(dy)
	else:
		if dy != 0: push_y = sign(dy)
		else: push_x = sign(dx)
		
	var tx = target.x + push_x
	var ty = target.y + push_y
	
	if not in_bounds(tx, ty):
		if Data.BOARD.ring_out:
			target.hp = 0
			push_log(state, "Ring Out!")
			check_win(state)
		return
		
	if get_unit_at(state, tx, ty):
		push_log(state, "Push blocked")
		return
		
	target.x = tx
	target.y = ty
	push_log(state, "Pushed to (%d,%d)" % [tx, ty])

static func check_win(state):
	var p1_dead = state.units.P1.hp <= 0
	var p2_dead = state.units.P2.hp <= 0
	
	if p1_dead and p2_dead: state.winner = "DRAW"
	elif p1_dead: state.winner = "P2"
	elif p2_dead: state.winner = "P1"

static func handle_turn_end(state):
	if state.winner != null: return
	
	var current = state.turn.currentPlayerId
	var next_player = "P2" if current == "P1" else "P1"
	
	# Process bleed damage at END of current player's turn
	process_bleed(state, current)
	if state.winner != null: return
	
	# Tick down status effect durations at END of current player's turn
	# This way effects like root/stun last through the affected player's full turn
	tick_status_effects(state, current)
	
	# Process pending delayed effects at end of turn
	process_pending_effects(state)
	if state.winner != null: return
	
	state.turn.currentPlayerId = next_player
	if next_player == "P1": state.turn.number += 1
	state.turn.apRemaining = Data.MAX_AP  # Reset AP each turn
	state.turn.movesRemaining = Data.MAX_MP  # Reset movement points
	
	# Start of turn upkeep
	var p_unit = state.units[next_player]
	p_unit.status.guard = null
	
	# Apply slow: reduce movement by percentage (rounded down)
	if has_status(p_unit, "slow"):
		var reduction = get_slow_amount(p_unit)
		state.turn.movesRemaining = int(float(Data.MAX_MP) * (1.0 - reduction))
		push_log(state, "%s is slowed! (%d movement)" % [next_player, state.turn.movesRemaining])
	
	# Process burn damage at start of new player's turn (ignores armor)
	process_burn(state, next_player)
	if state.winner != null: return
	
	# Decrement cooldowns
	for key in p_unit.cooldowns:
		p_unit.cooldowns[key] = max(0, p_unit.cooldowns[key] - 1)

static func get_legal_moves(state: Dictionary, pid: String) -> Array:
	if state.winner != null or state.turn.currentPlayerId != pid: return []
	if state.turn.movesRemaining <= 0: return []
	
	var me = state.units[pid]
	
	# Check movement-blocking statuses
	if is_stunned(me) or is_rooted(me) or is_knocked_down(me) or has_movement_loss(me):
		return []
	
	var max_dist = state.turn.movesRemaining
	var moves = []
	
	# BFS to find all reachable tiles within movement range
	var visited = {}
	var queue = []
	var start_key = "%d,%d" % [me.x, me.y]
	visited[start_key] = 0
	queue.append({"x": me.x, "y": me.y, "dist": 0})
	
	# 8 directions including diagonals
	var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	

	while queue.size() > 0:
		var current = queue.pop_front()
		
		for d in dirs:
			var nx = current.x + d.x
			var ny = current.y + d.y
			
			# Diagonal costs 2, cardinal costs 1
			var move_cost = 2 if (d.x != 0 and d.y != 0) else 1
			var new_dist = current.dist + move_cost
			var key = "%d,%d" % [nx, ny]
			
			if new_dist > max_dist: continue
			if visited.has(key) and visited[key] <= new_dist: continue
			if not in_bounds(nx, ny): continue
			if Data.is_obstacle(nx, ny): continue
			if get_unit_at(state, nx, ny): continue
			
			visited[key] = new_dist
			queue.append({"x": nx, "y": ny, "dist": new_dist})
			moves.append({
				"type": "MOVE",
				"playerId": pid,
				"to": {"x": nx, "y": ny}
			})
	
	return moves

static func get_legal_targets(state: Dictionary, pid: String, spell_id: String) -> Array:
	if state.winner != null or state.turn.currentPlayerId != pid: return []
	
	var spell = Data.get_spell(spell_id)
	if spell.is_empty(): return []
	
	# Check AP cost
	var ap_cost = spell.get("ap_cost", 0)
	if state.turn.apRemaining < ap_cost: return []
	
	var me = state.units[pid]
	var enemy_id = "P2" if pid == "P1" else "P1"
	var enemy = state.units[enemy_id]
	
	# Check cooldown
	if me.cooldowns.get(spell_id, 0) > 0: return []
	
	var targets = []
	var spell_range = spell.get("range", 1)
	var requires_los = spell.get("requires_los", true)
	var cardinal_only = spell.get("cardinal_only", false)
	
	# Generic target calculation based on spell type
	if spell.type == "ATTACK":
		# Special handling for cardinal-only spells (Piercing Windshot)
		if cardinal_only:
			var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
			for dir in dirs:
				for i in range(1, spell_range + 1):
					var nx = me.x + dir.x * i
					var ny = me.y + dir.y * i
					if in_bounds(nx, ny) and not Data.is_obstacle(nx, ny):
						if not requires_los or has_line_of_sight_to_cell(me.x, me.y, nx, ny):
							targets.append({"x": nx, "y": ny})
					else:
						break  # Stop at wall
		# Special handling for cone spells (show cardinal directions only)
		elif spell.get("aoe") == "CONE":
			var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
			for dir in dirs:
				# Show first tile in each direction as target
				var nx = me.x + dir.x
				var ny = me.y + dir.y
				if in_bounds(nx, ny):
					if not requires_los or has_line_of_sight_to_cell(me.x, me.y, nx, ny):
						targets.append({"x": nx, "y": ny})
		else:
			# Standard AoE/single target - show all valid tiles in range
			for r in range(Data.BOARD.rows):
				for c in range(Data.BOARD.cols):
					var d = abs(me.x - c) + abs(me.y - r)
					if d > 0 and d <= spell_range:
						# Skip obstacles for targeting
						if not Data.is_obstacle(c, r):
							# Check LOS if required
							if not requires_los or has_line_of_sight_to_cell(me.x, me.y, c, r):
								targets.append({"x": c, "y": r})
			
	elif spell.type == "MOVE":
		# Movement spells - show valid movement destinations
		var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
		for d in dirs:
			for i in range(1, spell_range + 1):
				var nx = me.x + d.x * i
				var ny = me.y + d.y * i
				if in_bounds(nx, ny) and not get_unit_at(state, nx, ny) and not Data.is_obstacle(nx, ny):
					targets.append({"x": nx, "y": ny})
				else:
					break  # Can't move through obstacles/units
					
	elif spell.type == "BUFF":
		# Self-targeting buffs
		targets.append({"x": me.x, "y": me.y})

	return targets

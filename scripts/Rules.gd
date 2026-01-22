class_name Rules
# =============================================================================
# RULES ENGINE - Anti-Gravity Character Spells
# =============================================================================
# Spells: Knockback Arrow, Piercing Arrow, Exponential Arrow, Immobilizing Arrow,
#         Displacement Arrow, Thief Arrow
# New mechanics: casts_per_turn, min_range, exponential stages, random effects
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
	if from_x == to_x and from_y == to_y: return 0
	
	var visited = {}
	var queue = []
	var start_key = "%d,%d" % [from_x, from_y]
	visited[start_key] = true
	queue.append({"x": from_x, "y": from_y, "dist": 0})
	
	var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]

	while queue.size() > 0:
		var current = queue.pop_front()
		
		for d in dirs:
			var nx = current.x + d.x
			var ny = current.y + d.y
			var key = "%d,%d" % [nx, ny]
			var move_cost = 1
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

static func find_movement_path(state: Dictionary, from_x: int, from_y: int, to_x: int, to_y: int) -> Array:
	if from_x == to_x and from_y == to_y: return []
	
	var visited = {}
	var parent = {}
	var queue = []
	var start_key = "%d,%d" % [from_x, from_y]
	visited[start_key] = 0
	queue.append({"x": from_x, "y": from_y, "dist": 0})
	
	var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	
	var found = false
	while queue.size() > 0 and not found:
		var current = queue.pop_front()
		var current_key = "%d,%d" % [current.x, current.y]
		
		for d in dirs:
			var nx = current.x + d.x
			var ny = current.y + d.y
			var key = "%d,%d" % [nx, ny]
			var new_dist = current.dist + 1
			
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
	
	var path = []
	var current_key = "%d,%d" % [to_x, to_y]
	while parent.has(current_key):
		var parts = current_key.split(",")
		path.push_front({"x": int(parts[0]), "y": int(parts[1])})
		current_key = parent[current_key]
	
	return path

# =============================================================================
# RANDOM DAMAGE HELPER
# =============================================================================

static func roll_damage(min_dmg: int, max_dmg: int) -> int:
	return randi() % (max_dmg - min_dmg + 1) + min_dmg

# =============================================================================
# AOE PATTERN HELPERS
# =============================================================================

static func get_cross_tiles(cx: int, cy: int, radius: int = 1) -> Array:
	var tiles = [{"x": cx, "y": cy}]
	for i in range(1, radius + 1):
		tiles.append({"x": cx + i, "y": cy})
		tiles.append({"x": cx - i, "y": cy})
		tiles.append({"x": cx, "y": cy + i})
		tiles.append({"x": cx, "y": cy - i})
	return tiles

static func get_cardinal_direction(from_x: int, from_y: int, to_x: int, to_y: int) -> Vector2i:
	var dx = to_x - from_x
	var dy = to_y - from_y
	if abs(dx) >= abs(dy):
		return Vector2i(sign(dx), 0) if dx != 0 else Vector2i(0, sign(dy))
	else:
		return Vector2i(0, sign(dy)) if dy != 0 else Vector2i(sign(dx), 0)

static func get_aoe_preview_tiles(state: Dictionary, caster_id: String, spell_id: String, target_x: int, target_y: int) -> Array:
	var spell = Data.get_spell(spell_id)
	if spell.is_empty(): return []
	
	var _caster = state.units[caster_id]
	var tiles = []
	
	match spell_id:
		"DISPLACEMENT_ARROW":
			# Show cross pattern (1-3 tiles in each direction)
			tiles = get_cross_tiles(target_x, target_y, spell.get("cross_range", 3))
		_:
			# Single target
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

static func apply_status(unit: Dictionary, effect: String, data: Dictionary) -> void:
	if not unit.status.has(effect) or unit.status[effect] == null:
		unit.status[effect] = data
	else:
		unit.status[effect].turns = max(unit.status[effect].turns, data.turns)

static func has_status(unit: Dictionary, effect: String) -> bool:
	return unit.status.has(effect) and unit.status[effect] != null

static func is_rooted(unit: Dictionary) -> bool:
	return has_status(unit, "root")

static func is_stunned(unit: Dictionary) -> bool:
	return has_status(unit, "stun")

static func is_knocked_down(unit: Dictionary) -> bool:
	return has_status(unit, "knocked_down")

static func has_movement_loss(unit: Dictionary) -> bool:
	return has_status(unit, "movement_loss")

static func get_damage_boost(unit: Dictionary) -> float:
	if has_status(unit, "damage_boost"):
		return unit.status.damage_boost.percent
	return 0.0

static func get_mp_reduction(unit: Dictionary) -> int:
	if has_status(unit, "mp_reduction"):
		return unit.status.mp_reduction.amount
	return 0

static func tick_status_effects(state: Dictionary, pid: String) -> void:
	var unit = state.units[pid]
	var effects_to_check = ["slow", "root", "revealed", "stun", "knocked_down", "damage_reduction", "movement_loss", "mp_reduction", "damage_boost"]
	for effect in effects_to_check:
		if has_status(unit, effect):
			unit.status[effect].turns -= 1
			if unit.status[effect].turns <= 0:
				unit.status[effect] = null
				push_log(state, "%s: %s wore off" % [pid, effect])

# =============================================================================
# DAMAGE SYSTEM
# =============================================================================

static func deal_damage_at(state: Dictionary, x: int, y: int, amount: int, source: String = "", caster = null) -> bool:
	var target = get_unit_at(state, x, y)
	if target:
		var dmg = amount
		# Apply caster's damage boost
		if caster and has_status(caster, "damage_boost"):
			var boost = get_damage_boost(caster)
			dmg = int(float(dmg) * (1.0 + boost))
			push_log(state, "Damage boosted by %d%%" % int(boost * 100))
		# Apply target's damage boost (they take more damage)
		if has_status(target, "damage_boost"):
			var boost = get_damage_boost(target)
			dmg = int(float(dmg) * (1.0 + boost))
		target.hp = max(0, target.hp - dmg)
		if source != "":
			push_log(state, "%s hit for %d (%s)" % [target.id, dmg, source])
		else:
			push_log(state, "%s hit for %d damage" % [target.id, dmg])
		check_win(state)
		return true
	return false

# =============================================================================
# PUSH SYSTEM - Enhanced for Knockback Arrow
# =============================================================================

static func push_unit_from_with_collision(state: Dictionary, target: Dictionary, from_x: int, from_y: int, distance: int, collision_damage_per_tile: int) -> void:
	var dx = target.x - from_x
	var dy = target.y - from_y
	var push_dir_x = 0
	var push_dir_y = 0
	
	if abs(dx) > abs(dy):
		push_dir_x = sign(dx)
	elif abs(dy) > abs(dx):
		push_dir_y = sign(dy)
	else:
		if dy != 0:
			push_dir_y = sign(dy)
		else:
			push_dir_x = sign(dx) if dx != 0 else 1
	
	var pushed = 0
	var blocked_tiles = 0
	
	for i in range(distance):
		var nx = target.x + push_dir_x
		var ny = target.y + push_dir_y
		
		# Check bounds
		if not in_bounds(nx, ny):
			if Data.BOARD.ring_out:
				target.hp = 0
				push_log(state, "Ring Out!")
				check_win(state)
			else:
				blocked_tiles = distance - i
			return
		
		# Check wall collision
		if Data.is_obstacle(nx, ny):
			blocked_tiles = distance - i
			break
		
		# Check unit collision
		var blocking_unit = get_unit_at(state, nx, ny)
		if blocking_unit:
			blocked_tiles = distance - i
			break
		
		# Move unit
		target.x = nx
		target.y = ny
		pushed += 1
	
	if pushed > 0:
		push_log(state, "%s pushed %d tiles" % [target.id, pushed])
	
	# Apply collision damage for blocked tiles
	if blocked_tiles > 0 and collision_damage_per_tile > 0:
		var collision_dmg = blocked_tiles * collision_damage_per_tile
		target.hp = max(0, target.hp - collision_dmg)
		push_log(state, "Collision! +%d damage (%d tiles blocked)" % [collision_dmg, blocked_tiles])
		check_win(state)

# Push for Displacement Arrow (from center of cross)
static func push_unit_from_center(state: Dictionary, target: Dictionary, center_x: int, center_y: int, distance: int) -> void:
	var dx = target.x - center_x
	var dy = target.y - center_y
	var push_dir_x = 0
	var push_dir_y = 0
	
	# Determine push direction based on which arm of the cross the unit is on
	if dx != 0 and dy == 0:
		push_dir_x = sign(dx)
	elif dy != 0 and dx == 0:
		push_dir_y = sign(dy)
	elif dx == 0 and dy == 0:
		# Unit is at center - push in a random direction
		var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var dir = dirs[randi() % 4]
		push_dir_x = dir.x
		push_dir_y = dir.y
	else:
		# Unit is not on a cardinal arm - determine dominant direction
		if abs(dx) >= abs(dy):
			push_dir_x = sign(dx)
		else:
			push_dir_y = sign(dy)
	
	var pushed = 0
	for i in range(distance):
		var nx = target.x + push_dir_x
		var ny = target.y + push_dir_y
		
		if not in_bounds(nx, ny):
			if Data.BOARD.ring_out:
				target.hp = 0
				push_log(state, "Ring Out!")
				check_win(state)
			return
		
		if Data.is_obstacle(nx, ny):
			break
		
		var blocking_unit = get_unit_at(state, nx, ny)
		if blocking_unit:
			break
		
		target.x = nx
		target.y = ny
		pushed += 1
	
	if pushed > 0:
		push_log(state, "%s displaced %d tiles" % [target.id, pushed])

# =============================================================================
# MAIN ACTION HANDLER
# =============================================================================

static func apply_action(state: Dictionary, action: Dictionary) -> Dictionary:
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
		
		# Calculate path distance via BFS
		var path_dist = get_path_distance(next, me.x, me.y, tx, ty)
		if path_dist < 0 or path_dist > next.turn.movesRemaining: return state
		
		me.x = tx
		me.y = ty
		next.turn.movesRemaining -= path_dist
		push_log(next, "%s moved to (%d,%d)" % [pid, tx, ty])
		
		return next


	elif action.type == "CAST":
		# Check if stunned
		if is_stunned(me):
			push_log(next, "%s is stunned and cannot act!" % pid)
			return state
		
		var spell_id = action.spellId
		var target = action.target
		var spell = Data.get_spell(spell_id)
		if spell.is_empty(): return state
		
		# Check cooldown
		if me.cooldowns.get(spell_id, 0) > 0: return state
		
		# Check casts per turn
		var casts_this_turn = me.casts_this_turn.get(spell_id, 0)
		var max_casts = spell.get("casts_per_turn", 1)
		if casts_this_turn >= max_casts: return state
		
		# Check AP cost
		var ap_cost = spell.get("ap_cost", 0)
		if next.turn.apRemaining < ap_cost: return state
		
		# Check range (both min and max)
		var d = abs(me.x - target.x) + abs(me.y - target.y)
		var min_range = spell.get("min_range", 1)
		var max_range = spell.get("range", 1)
		if d < min_range or d > max_range or d == 0: return state
		
		# Check LOS if required
		var requires_los = spell.get("requires_los", true)
		if requires_los and not has_line_of_sight_to_cell(me.x, me.y, target.x, target.y): return state
		
		# Deduct AP and increment casts
		next.turn.apRemaining -= ap_cost
		me.casts_this_turn[spell_id] = casts_this_turn + 1
		
		# Set cooldown only after max casts reached
		if me.casts_this_turn[spell_id] >= max_casts:
			me.cooldowns[spell_id] = spell.get("cooldown", 0)
		
		push_log(next, "%s casts %s (-%d AP, %d remaining)" % [pid, spell.label, ap_cost, next.turn.apRemaining])
		
		# =================================================================
		# SPELL RESOLUTION
		# =================================================================
		
		match spell_id:
			# ---------------------------------------------------------
			# 1) KNOCKBACK ARROW - Push with collision damage
			# ---------------------------------------------------------
			"KNOCKBACK_ARROW":
				var hit_unit = get_unit_at(next, target.x, target.y)
				if hit_unit:
					var dmg = roll_damage(spell.damage_min, spell.damage_max)
					deal_damage_at(next, target.x, target.y, dmg, "Knockback Arrow", me)
					if hit_unit.hp > 0:
						push_unit_from_with_collision(next, hit_unit, me.x, me.y, spell.push, spell.collision_damage_per_tile)
				else:
					push_log(next, "No target at location")
				return next
			
			# ---------------------------------------------------------
			# 2) PIERCING ARROW - Simple damage, ignores LOS
			# ---------------------------------------------------------
			"PIERCING_ARROW":
				var hit_unit = get_unit_at(next, target.x, target.y)
				if hit_unit:
					var dmg = roll_damage(spell.damage_min, spell.damage_max)
					deal_damage_at(next, target.x, target.y, dmg, "Piercing Arrow", me)
				else:
					push_log(next, "No target at location")
				return next
			
			# ---------------------------------------------------------
			# 3) EXPONENTIAL ARROW - Stage-based damage
			# ---------------------------------------------------------
			"EXPONENTIAL_ARROW":
				var hit_unit = get_unit_at(next, target.x, target.y)
				if hit_unit:
					var stage = me.exponential_stage
					var stage_dmg = spell.stage_damage[stage]
					var dmg = roll_damage(stage_dmg.min, stage_dmg.max)
					deal_damage_at(next, target.x, target.y, dmg, "Exponential Arrow (Stage %d)" % stage, me)
					
					# Advance stage (max 3)
					if me.exponential_stage < 3:
						me.exponential_stage += 1
						push_log(next, "Exponential Arrow advanced to Stage %d!" % me.exponential_stage)
				else:
					push_log(next, "No target at location")
				return next
			
			# ---------------------------------------------------------
			# 4) IMMOBILIZING ARROW - MP removal
			# ---------------------------------------------------------
			"IMMOBILIZING_ARROW":
				var hit_unit = get_unit_at(next, target.x, target.y)
				if hit_unit:
					var dmg = roll_damage(spell.damage_min, spell.damage_max)
					deal_damage_at(next, target.x, target.y, dmg, "Immobilizing Arrow", me)
					if hit_unit.hp > 0:
						var mp_remove = randi() % (spell.mp_removal_max - spell.mp_removal_min + 1) + spell.mp_removal_min
						if mp_remove > 0:
							apply_status(hit_unit, "mp_reduction", {"turns": 1, "amount": mp_remove})
							push_log(next, "%s loses %d MP for 1 turn!" % [hit_unit.id, mp_remove])
				else:
					push_log(next, "No target at location")
				return next
			
			# ---------------------------------------------------------
			# 5) DISPLACEMENT ARROW - Cross push from empty tile
			# ---------------------------------------------------------
			"DISPLACEMENT_ARROW":
				# Must target empty tile
				if get_unit_at(next, target.x, target.y):
					push_log(next, "Must target empty tile!")
					# Refund AP and cast
					next.turn.apRemaining += ap_cost
					me.casts_this_turn[spell_id] = casts_this_turn
					return state
				
				# Get all tiles in cross
				var cross_tiles = get_cross_tiles(target.x, target.y, spell.cross_range)
				var units_to_push = []
				
				for tile in cross_tiles:
					if in_bounds(tile.x, tile.y):
						var unit_on_tile = get_unit_at(next, tile.x, tile.y)
						if unit_on_tile:
							units_to_push.append(unit_on_tile)
				
				# Push all units away from center
				for unit in units_to_push:
					push_unit_from_center(next, unit, target.x, target.y, spell.push_distance)
				
				if units_to_push.size() == 0:
					push_log(next, "No units in displacement area")
				
				return next
			
			# ---------------------------------------------------------
			# 6) THIEF ARROW - Random effects
			# ---------------------------------------------------------
			"THIEF_ARROW":
				var hit_unit = get_unit_at(next, target.x, target.y)
				if not hit_unit:
					push_log(next, "No target at location")
					return next
				
				# Step 1: Deal damage
				var dmg = roll_damage(spell.damage_min, spell.damage_max)
				deal_damage_at(next, target.x, target.y, dmg, "Thief Arrow", me)
				
				if hit_unit.hp <= 0:
					return next
				
				# Step 2: Roll all random effects independently
				var steal_ap = randf() < (1.0 / 3.0)
				var give_ap = randf() < (1.0 / 3.0)
				var boost_caster = randf() < (1.0 / 5.0)
				var boost_target = randf() < (1.0 / 5.0)
				var swap_hp = randf() < (1.0 / 20.0)
				
				# Step 3: Apply AP changes
				if steal_ap:
					# Steal 1 AP from target's next turn (we reduce their MP as proxy)
					push_log(next, "Stole 1 AP from %s!" % hit_unit.id)
					# Note: In this system AP is per-turn, so we give caster +1 AP
					next.turn.apRemaining += 1
				
				if give_ap:
					push_log(next, "Gave 1 AP to %s!" % hit_unit.id)
					# Target gets bonus AP on their turn - we can't directly give them AP
					# So we reduce our own AP by 1 as the cost
					next.turn.apRemaining = max(0, next.turn.apRemaining - 1)
				
				# Step 4: Apply damage modifiers
				if boost_caster:
					apply_status(me, "damage_boost", {"turns": 1, "percent": 0.20})
					push_log(next, "%s gains +20%% damage next turn!" % pid)
				
				if boost_target:
					apply_status(hit_unit, "damage_boost", {"turns": 1, "percent": 0.20})
					push_log(next, "%s gains +20%% damage next turn!" % hit_unit.id)
				
				# Step 5: HP swap
				if swap_hp:
					var my_hp = me.hp
					var their_hp = hit_unit.hp
					me.hp = their_hp
					hit_unit.hp = my_hp
					push_log(next, "HP SWAPPED! %s: %d -> %d, %s: %d -> %d" % [pid, my_hp, their_hp, hit_unit.id, their_hp, my_hp])
					check_win(next)
				
				return next
		
		return next
		
	elif action.type == "END_TURN":
		push_log(next, "%s ends turn" % pid)
		handle_turn_end(next)
		return next
		
	return state

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
	var current_unit = state.units[current]
	
	# Check Exponential Arrow reset - if it was available but not cast, reset to Stage 1
	var exp_spell = Data.get_spell("EXPONENTIAL_ARROW")
	var exp_cooldown = current_unit.cooldowns.get("EXPONENTIAL_ARROW", 0)
	var exp_casts = current_unit.casts_this_turn.get("EXPONENTIAL_ARROW", 0)
	
	# Spell was available if cooldown was 0 and had AP for it
	if exp_cooldown == 0 and exp_casts == 0:
		# Player didn't cast it when available - reset stage
		if current_unit.exponential_stage > 1:
			push_log(state, "%s: Exponential Arrow reset to Stage 1 (not cast when available)" % current)
			current_unit.exponential_stage = 1
	
	# Tick status effects at END of current player's turn
	tick_status_effects(state, current)
	
	# Switch turn
	state.turn.currentPlayerId = next_player
	if next_player == "P1": state.turn.number += 1
	state.turn.apRemaining = Data.MAX_AP
	state.turn.movesRemaining = Data.MAX_MP
	
	var p_unit = state.units[next_player]
	
	# Reset casts_this_turn for new turn
	p_unit.casts_this_turn = {}
	
	# Apply MP reduction from Immobilizing Arrow
	if has_status(p_unit, "mp_reduction"):
		var reduction = get_mp_reduction(p_unit)
		state.turn.movesRemaining = max(0, state.turn.movesRemaining - reduction)
		push_log(state, "%s has %d less MP this turn!" % [next_player, reduction])
	
	# Decrement cooldowns
	for key in p_unit.cooldowns:
		p_unit.cooldowns[key] = max(0, p_unit.cooldowns[key] - 1)

static func get_legal_moves(state: Dictionary, pid: String) -> Array:
	if state.winner != null or state.turn.currentPlayerId != pid: return []
	if state.turn.movesRemaining <= 0: return []
	
	var me = state.units[pid]
	
	if is_stunned(me) or is_rooted(me):
		return []
	
	var max_dist = state.turn.movesRemaining
	var moves = []
	
	var visited = {}
	var queue = []
	var start_key = "%d,%d" % [me.x, me.y]
	visited[start_key] = 0
	queue.append({"x": me.x, "y": me.y, "dist": 0})
	
	var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]

	while queue.size() > 0:
		var current = queue.pop_front()
		
		for d in dirs:
			var nx = current.x + d.x
			var ny = current.y + d.y
			
			var move_cost = 1
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
	
	# Check cooldown
	if me.cooldowns.get(spell_id, 0) > 0: return []
	
	# Check casts per turn
	var casts_this_turn = me.casts_this_turn.get(spell_id, 0)
	var max_casts = spell.get("casts_per_turn", 1)
	if casts_this_turn >= max_casts: return []
	
	var targets = []
	var min_range = spell.get("min_range", 1)
	var max_range = spell.get("range", 1)
	var requires_los = spell.get("requires_los", true)
	var requires_empty = spell.get("requires_empty_tile", false)
	
	for r in range(Data.BOARD.rows):
		for c in range(Data.BOARD.cols):
			var d = abs(me.x - c) + abs(me.y - r)
			if d >= min_range and d <= max_range:
				# Skip obstacles for targeting
				if Data.is_obstacle(c, r): continue
				
				# Check LOS if required
				if requires_los and not has_line_of_sight_to_cell(me.x, me.y, c, r): continue
				
				# Check empty tile requirement
				if requires_empty and get_unit_at(state, c, r): continue
				
				targets.append({"x": c, "y": r})
	
	return targets

class_name Rules

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
		
		# --- SPELL EFFECTS (to be implemented with new spells) ---
		# Handle different spell types
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
	
	state.turn.currentPlayerId = next_player
	if next_player == "P1": state.turn.number += 1
	state.turn.apRemaining = Data.MAX_AP  # Reset AP each turn
	state.turn.movesRemaining = Data.MAX_MP  # Reset movement points
	
	# Start of turn upkeep
	var p_unit = state.units[next_player]
	p_unit.status.guard = null
	for key in p_unit.cooldowns:
		p_unit.cooldowns[key] = max(0, p_unit.cooldowns[key] - 1)

static func get_legal_moves(state: Dictionary, pid: String) -> Array:
	if state.winner != null or state.turn.currentPlayerId != pid: return []
	if state.turn.movesRemaining <= 0: return []
	
	var me = state.units[pid]
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
	
	# Generic target calculation based on spell type
	if spell.type == "ATTACK":
		var spell_range = spell.get("range", 1)
		# For attack spells, show all valid targets in range with line of sight
		for r in range(Data.BOARD.rows):
			for c in range(Data.BOARD.cols):
				var d = abs(me.x - c) + abs(me.y - r)
				if d > 0 and d <= spell_range:
					if not Data.is_obstacle(c, r) and has_line_of_sight_to_cell(me.x, me.y, c, r):
						targets.append({"x": c, "y": r})
			
	elif spell.type == "MOVE":
		# Movement spells - show valid movement destinations
		var spell_range = spell.get("range", 2)
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

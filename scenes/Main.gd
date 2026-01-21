extends Node2D

@onready var board = $Board

@onready var units_container = $Units
@onready var turn_label = $CanvasLayer/HUD/TopBar/TurnLabel
@onready var p1_status = $CanvasLayer/HUD/TopBar/P1Status
@onready var p2_status = $CanvasLayer/HUD/TopBar/P2Status
@onready var spell_container = $CanvasLayer/HUD/BottomBar/SpellsContainer
@onready var end_turn_btn = $CanvasLayer/HUD/BottomBar/EndTurnBtn
@onready var log_panel = $CanvasLayer/HUD/LogPanel
@onready var timer_label = $CanvasLayer/HUD/TimerLabel
@onready var ap_label = $CanvasLayer/HUD/BottomBar/APLabel


# HP Display nodes
@onready var p1_hp_bar = $CanvasLayer/HUD/P1HPDisplay/P1HPBar
@onready var p1_hp_label = $CanvasLayer/HUD/P1HPDisplay/P1HPLabel
@onready var p2_hp_bar = $CanvasLayer/HUD/P2HPDisplay/P2HPBar
@onready var p2_hp_label = $CanvasLayer/HUD/P2HPDisplay/P2HPLabel
@onready var damage_popups = $DamagePopups

# Lobby UI (created dynamically)
var lobby_panel: Control
var room_code_input: LineEdit
var status_label: Label

# Game Over UI
var game_over_panel: Control

# Custom Spell Tooltip
var spell_tooltip: Panel
var spell_tooltip_label: RichTextLabel

var UnitScene = preload("res://scenes/Unit.gd") 
# Note: Since Unit.gd is a script, we can just instantiate a Node2D and attach script, 
# or loop through children. For simplicity, we'll just create Node2D and set script.

var game_state: Dictionary
var selected_spell_id = null
var hovered_tile = null
var turn_time_remaining: float = 30.0
const TURN_DURATION: float = 30.0

# Persistent unit node references for animation
var unit_nodes: Dictionary = {}

# Movement path animation tracking
var pending_move_paths: Dictionary = {}  # pid -> Array of path tiles
var animating_unit: String = ""  # Currently animating unit ID

# --- MULTIPLAYER ---
var socket: WebSocketPeer = WebSocketPeer.new()
var multiplayer_mode: bool = false
var my_player_id: String = ""
var connected: bool = false
var room_code: String = ""
var waiting_for_opponent: bool = false
var game_started: bool = false

# Server URL - change this when deploying
const SERVER_URL = "wss://thegame-production.up.railway.app"


func _ready():
	# Connect Signals
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	# Create custom spell tooltip
	create_spell_tooltip()
	
	# Show lobby first
	show_lobby()

func show_lobby():
	# Create lobby panel
	lobby_panel = Panel.new()
	lobby_panel.custom_minimum_size = Vector2(400, 350)
	lobby_panel.set_anchors_preset(Control.PRESET_CENTER)
	lobby_panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -200)
	lobby_panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, 200)
	lobby_panel.set_anchor_and_offset(SIDE_TOP, 0.5, -175)
	lobby_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 175)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.set_anchor_and_offset(SIDE_LEFT, 0, 20)
	vbox.set_anchor_and_offset(SIDE_RIGHT, 1, -20)
	vbox.set_anchor_and_offset(SIDE_TOP, 0, 20)
	vbox.set_anchor_and_offset(SIDE_BOTTOM, 1, -20)
	vbox.add_theme_constant_override("separation", 15)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var title = Label.new()
	title.text = "TACTICAL DUEL - ONLINE PVP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var create_btn = Button.new()
	create_btn.text = "Create Room"
	create_btn.custom_minimum_size = Vector2(200, 40)
	create_btn.pressed.connect(_on_create_room)
	vbox.add_child(create_btn)
	
	var join_label = Label.new()
	join_label.text = "Or join with room code:"
	join_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(join_label)
	
	room_code_input = LineEdit.new()
	room_code_input.placeholder_text = "Enter room code..."
	room_code_input.custom_minimum_size = Vector2(200, 35)
	room_code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(room_code_input)
	
	var join_btn = Button.new()
	join_btn.text = "Join Room"
	join_btn.custom_minimum_size = Vector2(200, 40)
	join_btn.pressed.connect(_on_join_room)
	vbox.add_child(join_btn)
	
	var offline_btn = Button.new()
	offline_btn.text = "Play Offline (Local)"
	offline_btn.custom_minimum_size = Vector2(200, 40)
	offline_btn.pressed.connect(_on_play_offline)
	vbox.add_child(offline_btn)
	
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(status_label)
	
	lobby_panel.add_child(vbox)
	$CanvasLayer.add_child(lobby_panel)
	
	# Hide game UI
	$CanvasLayer/HUD.visible = false

func _on_create_room():
	status_label.text = "Connecting to server..."
	await connect_to_server()
	if connected:
		socket.send_text(JSON.stringify({"type": "CREATE_ROOM"}))
		status_label.text = "Creating room..."

func _on_join_room():
	var code = room_code_input.text.strip_edges().to_upper()
	if code.length() < 4:
		status_label.text = "Please enter a valid room code"
		return
	
	status_label.text = "Connecting to server..."
	await connect_to_server()
	if connected:
		socket.send_text(JSON.stringify({"type": "JOIN_ROOM", "roomCode": code}))
		status_label.text = "Joining room..."

func _on_play_offline():
	multiplayer_mode = false
	lobby_panel.queue_free()
	game_over_panel = null
	$CanvasLayer/HUD.visible = true
	game_state = Data.create_initial_state()
	call_deferred("update_all")

func connect_to_server():
	var err = socket.connect_to_url(SERVER_URL)
	if err != OK:
		status_label.text = "Failed to connect! Is server running?"
		return
	
	# Wait for connection
	for i in range(20):  # 2 second timeout
		socket.poll()
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			connected = true
			status_label.text = "Connected!"
			return
		await get_tree().create_timer(0.1).timeout
	
	status_label.text = "Connection timeout. Check server."

func _process(delta):
	# Handle WebSocket - must poll whenever connected
	if connected or multiplayer_mode or waiting_for_opponent:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			var text = packet.get_string_from_utf8()
			handle_server_message(text)
	
	# Don't run game logic if not started
	if not game_started and multiplayer_mode:
		return
	
	# Turn Timer Countdown (only if it's my turn in multiplayer, or always in offline)
	if game_state and game_state.winner == null:
		if not multiplayer_mode or game_state.turn.currentPlayerId == my_player_id:
			turn_time_remaining -= delta
			timer_label.text = "⏱️ %ds" % int(ceil(turn_time_remaining))
			
			if turn_time_remaining <= 0:
				_on_end_turn_pressed()
	
	# Handle Grid Hover
	var allow_hover = not multiplayer_mode or (game_state and game_state.turn.currentPlayerId == my_player_id)
	if allow_hover:
		var mouse_pos = get_global_mouse_position()
		var new_hover = Iso.pixel_to_grid(mouse_pos.x, mouse_pos.y)
		
		if Rules.in_bounds(new_hover.x, new_hover.y):
			if hovered_tile == null or hovered_tile.x != new_hover.x or hovered_tile.y != new_hover.y:
				hovered_tile = new_hover
				# Call update_board_visuals to recalculate AOE preview tiles when hovering
				update_board_visuals()
		else:
			if hovered_tile != null:
				hovered_tile = null
				update_board_visuals()
	elif hovered_tile != null:
		hovered_tile = null
		update_board_visuals()

func handle_server_message(text: String):
	var msg = JSON.parse_string(text)
	if not msg:
		return
	
	match msg.type:
		"ROOM_CREATED":
			room_code = msg.roomCode
			my_player_id = msg.playerId
			waiting_for_opponent = true
			status_label.text = "Room: %s\nWaiting for opponent..." % room_code
			
		"ROOM_JOINED":
			room_code = msg.roomCode
			my_player_id = msg.playerId
			status_label.text = "Joined room %s as P2" % room_code
			
		"GAME_START":
			multiplayer_mode = true
			game_started = true
			waiting_for_opponent = false
			game_state = msg.state
			lobby_panel.queue_free()
			$CanvasLayer/HUD.visible = true
			turn_time_remaining = TURN_DURATION
			call_deferred("update_all")
			
		"STATE_UPDATE":
			var old_state = game_state
			var old_p1_hp = game_state.units.P1.hp if game_state else 10
			var old_p2_hp = game_state.units.P2.hp if game_state else 10
			var old_player = game_state.turn.currentPlayerId if game_state else ""
			
			game_state = msg.state
			
			# Cache movement path for networked move actions (so animations follow tiles)
			if old_state and old_state.turn and old_state.turn.currentPlayerId == game_state.turn.currentPlayerId:
				var old_moves = old_state.turn.get("movesRemaining", Data.MAX_MP)
				var new_moves = game_state.turn.get("movesRemaining", Data.MAX_MP)
				if new_moves < old_moves:
					var pid = game_state.turn.currentPlayerId
					var old_unit = old_state.units[pid]
					var new_unit = game_state.units[pid]
					if old_unit.x != new_unit.x or old_unit.y != new_unit.y:
						var path = Rules.find_movement_path(old_state, old_unit.x, old_unit.y, new_unit.x, new_unit.y)
						if path.size() > 0:
							pending_move_paths[pid] = path
			
			# Check for damage and spawn popups
			var new_p1_hp = game_state.units.P1.hp
			var new_p2_hp = game_state.units.P2.hp
			
			if new_p1_hp < old_p1_hp:
				spawn_damage_popup("P1", old_p1_hp - new_p1_hp)
			if new_p2_hp < old_p2_hp:
				spawn_damage_popup("P2", old_p2_hp - new_p2_hp)
			
			# Reset timer if turn changed
			if game_state.turn.currentPlayerId != old_player:
				turn_time_remaining = TURN_DURATION
				selected_spell_id = null
			
			update_all()
			
		"ERROR":
			status_label.text = "Error: %s" % msg.message
			
		"PLAYER_DISCONNECTED":
			status_label.text = "Opponent disconnected!"
			# Could return to lobby here

func _input(event):
	if not game_state:
		return
	
	# In multiplayer, only allow input on my turn
	if multiplayer_mode and game_state.turn.currentPlayerId != my_player_id:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hovered_tile != null:
			try_action_at(hovered_tile.x, hovered_tile.y)

func _on_viewport_resized():
	# Recalculate origin
	Iso.compute_origin(get_viewport_rect().size.x, get_viewport_rect().size.y, Data.BOARD.rows, Data.BOARD.cols)
	board.queue_redraw()
	update_units_visuals()

func update_all():
	# Ensure Origin is set
	Iso.compute_origin(get_viewport_rect().size.x, get_viewport_rect().size.y, Data.BOARD.rows, Data.BOARD.cols)
	
	update_ui()
	update_board_visuals()
	update_units_visuals()

func update_ui():
	if not game_state:
		return
	
	# Top Bar
	var turn_text = "Turn %d - %s" % [game_state.turn.number, game_state.turn.currentPlayerId]
	if multiplayer_mode:
		if game_state.turn.currentPlayerId == my_player_id:
			turn_text += " (YOUR TURN)"
		else:
			turn_text += " (Waiting...)"
	turn_label.text = turn_text
	
	if game_state.winner:
		if multiplayer_mode:
			if game_state.winner == my_player_id:
				turn_label.text = "YOU WIN! 🎉"
			else:
				turn_label.text = "YOU LOSE 😢"
		else:
			turn_label.text = "WINNER: %s" % game_state.winner
		# Show game over popup
		if game_over_panel == null:
			show_game_over_popup()
		
	var u1 = game_state.units.P1
	var u2 = game_state.units.P2
	p1_status.text = "P1: %d %s" % [u1.hp, "🛡️" if u1.status.guard else ""]
	p2_status.text = "P2: %d %s" % [u2.hp, "🛡️" if u2.status.guard else ""]
	
	# HP Bars
	p1_hp_bar.value = u1.hp
	p1_hp_label.text = "%d / %d" % [u1.hp, Data.MAX_HP]
	p2_hp_bar.value = u2.hp
	p2_hp_label.text = "%d / %d" % [u2.hp, Data.MAX_HP]
	
	# Log
	var log_text = ""
	for msg in game_state.log:
		log_text += msg + "\n"
	log_panel.text = log_text
	
	# AP Display
	var ap_remaining = game_state.turn.get("apRemaining", Data.MAX_AP)
	ap_label.text = "⚡ AP: %d / %d" % [ap_remaining, Data.MAX_AP]

	
	# Spells Buttons (Rebuild on turn change or selection)
	for c in spell_container.get_children():
		c.queue_free()
	
	var pid = game_state.turn.currentPlayerId
	# Both players use Ranger class for now
	var char_id = "RANGER"
	var unit = game_state.units[pid]
	
	# Get spells dynamically from character class
	var spell_list = Data.get_character_spells(char_id)
	
	for spell_id in spell_list:
		var spell = Data.get_spell(spell_id)
		if spell.is_empty(): continue
		var cd = unit.cooldowns.get(spell_id, 0)
		
		# Create container for spell button + cooldown label
		var container = VBoxContainer.new()
		container.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Use text button (no spell icons available yet)
		var btn = Button.new()
		btn.text = spell.label
		btn.custom_minimum_size = Vector2(100, 50)
		
		# Custom tooltip on hover (replaces tooltip_text)
		btn.mouse_entered.connect(show_spell_tooltip.bind(container, spell.desc))
		btn.mouse_exited.connect(hide_spell_tooltip)
		
		# Visual states
		if cd > 0:
			btn.modulate = Color(0.4, 0.4, 0.4)
			btn.disabled = true
		elif selected_spell_id == spell_id:
			btn.modulate = Color(1.2, 1.2, 0.5)
		
		# Disable if not my turn in multiplayer
		var not_my_turn = multiplayer_mode and game_state.turn.currentPlayerId != my_player_id
		
		if game_state.winner or not_my_turn:
			btn.modulate = Color(0.4, 0.4, 0.4)
			btn.disabled = true
		
		# Check AP cost - disable if not enough AP
		var ap_cost = spell.get("ap_cost", 0)
		var current_ap = game_state.turn.get("apRemaining", Data.MAX_AP)
		if current_ap < ap_cost:
			btn.modulate = Color(0.5, 0.3, 0.3)
			btn.disabled = true
		
		btn.pressed.connect(_on_spell_clicked.bind(spell_id))
		container.add_child(btn)
		
		# Cooldown / AP cost label
		var label = Label.new()
		if cd > 0:
			label.text = "CD: %d" % cd
			label.add_theme_color_override("font_color", Color.RED)
		else:
			label.text = "%d AP" % ap_cost
			label.add_theme_color_override("font_color", Color.CYAN)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		container.add_child(label)
		
		spell_container.add_child(container)



func update_board_visuals():
	if not game_state:
		return
	
	var not_my_turn = multiplayer_mode and game_state.turn.currentPlayerId != my_player_id
	if not_my_turn:
		board.update_visuals(game_state, [], [], null, [], null, [], [], [])
		return
		
	var pid = game_state.turn.currentPlayerId
	var moves = Rules.get_legal_moves(game_state, pid)
	var targets = []
	var zone = []
	var blocked_cells = []  # Cells in range but blocked by LOS
	
	# Range Zone
	if selected_spell_id:
		var spell = Data.get_spell(selected_spell_id)
		if not spell.is_empty() and spell.get("range"):
			var u = game_state.units[pid]
			for r in range(Data.BOARD.rows):
				for c in range(Data.BOARD.cols):
					var d = abs(u.x - c) + abs(u.y - r)
					if d > 0 and d <= spell.range:
						zone.append({"x": c, "y": r})
		
		targets = Rules.get_legal_targets(game_state, pid, selected_spell_id)
		
		# For spells that require LOS, show blocked cells
		if not spell.is_empty() and spell.get("requires_los", true) and spell.get("type") == "ATTACK":
			var u = game_state.units[pid]
			for cell in zone:
				var is_target = false
				for t in targets:
					if t.x == cell.x and t.y == cell.y:
						is_target = true
						break
				if not is_target:
					blocked_cells.append(cell)
	
	# Calculate AOE preview if hovering a valid target with spell selected
	var aoe_preview = []
	if selected_spell_id and hovered_tile:
		var is_valid_target = false
		for t in targets:
			if t.x == hovered_tile.x and t.y == hovered_tile.y:
				is_valid_target = true
				break
		if is_valid_target:
			aoe_preview = Rules.get_aoe_preview_tiles(game_state, pid, selected_spell_id, hovered_tile.x, hovered_tile.y)
	
	# Calculate movement path preview if hovering a valid move destination
	var path_preview = []
	if not selected_spell_id and hovered_tile:
		var is_valid_move = false
		for m in moves:
			if m.to.x == hovered_tile.x and m.to.y == hovered_tile.y:
				is_valid_move = true
				break
		if is_valid_move:
			var me = game_state.units[pid]
			path_preview = Rules.find_movement_path(game_state, me.x, me.y, hovered_tile.x, hovered_tile.y)
		
	board.update_visuals(game_state, moves, targets, selected_spell_id, zone, hovered_tile, blocked_cells, aoe_preview, path_preview)

func update_units_visuals():
	if not game_state:
		return
	
	# Create units if they don't exist, otherwise update their positions with animation
	for pid in ["P1", "P2"]:
		var unit_data = game_state.units[pid]
		
		if unit_data.hp <= 0:
			# Remove dead unit
			if unit_nodes.has(pid):
				unit_nodes[pid].queue_free()
				unit_nodes.erase(pid)
			continue
		
		if not unit_nodes.has(pid):
			# Create new unit node
			var u_node = Node2D.new()
			u_node.set_script(UnitScene)
			units_container.add_child(u_node)
			u_node.set_unit(unit_data)
			unit_nodes[pid] = u_node
		else:
			# Animate existing unit to new position
			var u_node = unit_nodes[pid]
			u_node.unit_data = unit_data
			u_node.queue_redraw()
			
			# Check if we have a pending path for this unit
			if pending_move_paths.has(pid) and pending_move_paths[pid].size() > 0:
				# Animate through the path tile by tile
				var path = pending_move_paths[pid]
				pending_move_paths.erase(pid)
				animate_path(u_node, path)
			else:
				# Fallback: direct movement (for multiplayer sync or non-move actions)
				var target_pos = Iso.grid_to_screen(unit_data.x, unit_data.y)
				if u_node.position != target_pos:
					var tween = create_tween()
					tween.tween_property(u_node, "position", target_pos, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

# Animate unit through each tile in path sequentially
func animate_path(u_node: Node2D, path: Array) -> void:
	if path.size() == 0:
		return
	
	var tween = create_tween()
	var time_per_tile = 0.1  # 100ms per tile for snappy movement
	
	for tile in path:
		var screen_pos = Iso.grid_to_screen(tile.x, tile.y)
		tween.tween_property(u_node, "position", screen_pos, time_per_tile).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)


# --- Actions ---

func _on_end_turn_pressed():
	if multiplayer_mode and game_state.turn.currentPlayerId != my_player_id:
		return
	
	var action = {
		"type": "END_TURN",
		"playerId": game_state.turn.currentPlayerId
	}
	
	if multiplayer_mode:
		send_action(action)
	else:
		apply_action(action)

func _on_spell_clicked(id):
	if multiplayer_mode and game_state.turn.currentPlayerId != my_player_id:
		return
	
	if selected_spell_id == id:
		selected_spell_id = null
	else:
		selected_spell_id = id
	update_all()

func try_action_at(x, y):
	var pid = game_state.turn.currentPlayerId
	
	if selected_spell_id:
		var targets = Rules.get_legal_targets(game_state, pid, selected_spell_id)
		var valid = false
		for t in targets:
			if t.x == x and t.y == y: valid = true
		
		if valid:
			var spell_to_cast = selected_spell_id
			selected_spell_id = null  # Clear before apply so redraw shows movement, not spell range
			var action = {
				"type": "CAST",
				"playerId": pid,
				"spellId": spell_to_cast,
				"target": {"x": x, "y": y}
			}
			if multiplayer_mode:
				send_action(action)
			else:
				apply_action(action)
		else:
			# Clicked outside valid targets - deselect spell
			selected_spell_id = null
			update_all()

	else:
		var moves = Rules.get_legal_moves(game_state, pid)
		var valid = false
		for m in moves:
			if m.to.x == x and m.to.y == y: valid = true
			
		if valid:
			var action = {
				"type": "MOVE",
				"playerId": pid,
				"to": {"x": x, "y": y}
			}
			if multiplayer_mode:
				send_action(action)
			else:
				apply_action(action)

func send_action(action: Dictionary):
	if not connected:
		return
	socket.send_text(JSON.stringify({"type": "ACTION", "action": action}))

func apply_action(action):
	var old_player = game_state.turn.currentPlayerId
	var old_p1_hp = game_state.units.P1.hp
	var old_p2_hp = game_state.units.P2.hp
	
	# Store path for move actions before applying (so we know the path to animate)
	if action.type == "MOVE":
		var pid = action.playerId
		var me = game_state.units[pid]
		var path = Rules.find_movement_path(game_state, me.x, me.y, action.to.x, action.to.y)
		if path.size() > 0:
			pending_move_paths[pid] = path
	
	game_state = Rules.apply_action(game_state, action)
	
	# Check for damage and spawn popups
	var new_p1_hp = game_state.units.P1.hp
	var new_p2_hp = game_state.units.P2.hp
	
	if new_p1_hp < old_p1_hp:
		var damage = old_p1_hp - new_p1_hp
		spawn_damage_popup("P1", damage)
	if new_p2_hp < old_p2_hp:
		var damage = old_p2_hp - new_p2_hp
		spawn_damage_popup("P2", damage)
	
	# Reset timer if turn changed
	if game_state.turn.currentPlayerId != old_player:
		turn_time_remaining = TURN_DURATION
		selected_spell_id = null
	
	update_all()

func spawn_damage_popup(pid: String, damage: int):
	var unit_data = game_state.units[pid]
	var screen_pos = Iso.grid_to_screen(unit_data.x, unit_data.y)
	
	# Create damage label
	var label = Label.new()
	label.text = "-%d" % damage
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_font_size_override("font_size", 28)
	label.position = screen_pos - Vector2(20, 60)
	label.z_index = 100
	damage_popups.add_child(label)
	
	# Animate: rise up and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(label.queue_free)

# =============================================================================
# GAME OVER POPUP
# =============================================================================

func show_game_over_popup():
	game_over_panel = Panel.new()
	game_over_panel.custom_minimum_size = Vector2(350, 200)
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	game_over_panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -175)
	game_over_panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, 175)
	game_over_panel.set_anchor_and_offset(SIDE_TOP, 0.5, -100)
	game_over_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 100)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.set_anchor_and_offset(SIDE_LEFT, 0, 20)
	vbox.set_anchor_and_offset(SIDE_RIGHT, 1, -20)
	vbox.set_anchor_and_offset(SIDE_TOP, 0, 20)
	vbox.set_anchor_and_offset(SIDE_BOTTOM, 1, -20)
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Winner message
	var title = Label.new()
	if multiplayer_mode:
		if game_state.winner == my_player_id:
			title.text = "🎉 YOU WIN! 🎉"
			title.add_theme_color_override("font_color", Color.GREEN)
		else:
			title.text = "💀 GAME OVER 💀"
			title.add_theme_color_override("font_color", Color.RED)
	else:
		title.text = "🏆 %s WINS! 🏆" % game_state.winner
		title.add_theme_color_override("font_color", Color.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	
	# Play Again button
	var restart_btn = Button.new()
	restart_btn.text = "Play Again"
	restart_btn.custom_minimum_size = Vector2(200, 50)
	restart_btn.pressed.connect(_on_restart_game)
	vbox.add_child(restart_btn)
	
	game_over_panel.add_child(vbox)
	$CanvasLayer.add_child(game_over_panel)

func _on_restart_game():
	# Clean up game over popup
	if game_over_panel:
		game_over_panel.queue_free()
		game_over_panel = null
	
	# Clear unit nodes for fresh start
	for pid in unit_nodes.keys():
		unit_nodes[pid].queue_free()
	unit_nodes.clear()
	
	if multiplayer_mode:
		# Request restart from server
		if connected:
			socket.send_text(JSON.stringify({"type": "RESTART_REQUEST"}))
	else:
		# Offline: Reset game state directly
		game_state = Data.create_initial_state()
		turn_time_remaining = TURN_DURATION
		selected_spell_id = null
		update_all()

# =============================================================================
# CUSTOM SPELL TOOLTIP
# =============================================================================

func create_spell_tooltip():
	spell_tooltip = Panel.new()
	spell_tooltip.visible = false
	spell_tooltip.z_index = 100
	
	# Black background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	spell_tooltip.add_theme_stylebox_override("panel", style)
	
	# White text label
	spell_tooltip_label = RichTextLabel.new()
	spell_tooltip_label.bbcode_enabled = true
	spell_tooltip_label.fit_content = true
	spell_tooltip_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	spell_tooltip_label.add_theme_color_override("default_color", Color.WHITE)
	spell_tooltip_label.add_theme_font_size_override("normal_font_size", 14)
	spell_tooltip.add_child(spell_tooltip_label)
	
	$CanvasLayer.add_child(spell_tooltip)

func show_spell_tooltip(container: Control, desc: String):
	if not spell_tooltip:
		return
	
	spell_tooltip_label.text = desc
	
	# Calculate size based on text
	var text_size = spell_tooltip_label.get_content_height()
	spell_tooltip.custom_minimum_size = Vector2(280, text_size + 20)
	spell_tooltip.size = spell_tooltip.custom_minimum_size
	
	# Position above the spell container's row
	var global_pos = container.global_position
	spell_tooltip.global_position = Vector2(
		global_pos.x - 80,  # Slight left offset to center
		global_pos.y - spell_tooltip.size.y - 10  # Above the row
	)
	
	# Keep tooltip on screen
	if spell_tooltip.global_position.x < 0:
		spell_tooltip.global_position.x = 10
	if spell_tooltip.global_position.y < 0:
		spell_tooltip.global_position.y = 10
	
	spell_tooltip.visible = true

func hide_spell_tooltip():
	if spell_tooltip:
		spell_tooltip.visible = false

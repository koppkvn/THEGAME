extends Node2D

@onready var board = $Board
@onready var hud = $CanvasLayer/HUD
@onready var top_bar = $CanvasLayer/HUD/TopBar
@onready var bottom_bar = $CanvasLayer/HUD/BottomBar

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
@onready var p1_hp_display = $CanvasLayer/HUD/P1HPDisplay
@onready var p2_hp_display = $CanvasLayer/HUD/P2HPDisplay
@onready var p1_name = $CanvasLayer/HUD/P1HPDisplay/P1Name
@onready var p2_name = $CanvasLayer/HUD/P2HPDisplay/P2Name
@onready var p1_hp_bar = $CanvasLayer/HUD/P1HPDisplay/P1HPBar
@onready var p1_hp_label = $CanvasLayer/HUD/P1HPDisplay/P1HPLabel
@onready var p2_hp_bar = $CanvasLayer/HUD/P2HPDisplay/P2HPBar
@onready var p2_hp_label = $CanvasLayer/HUD/P2HPDisplay/P2HPLabel
@onready var damage_popups = $DamagePopups

# Lobby UI (created dynamically)
var lobby_panel: Control
var lobby_vbox: VBoxContainer
var lobby_title: Label
var lobby_create_btn: Button
var lobby_join_label: Label
var room_code_input: LineEdit
var lobby_join_btn: Button
var lobby_offline_btn: Button
var lobby_char_btn: Button
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
var selected_character = "RANGER" # RANGER or MELEE
var turn_time_remaining: float = 30.0
const TURN_DURATION: float = 30.0

# Responsive layout
const UI_BASE_MIN_SIDE = 800.0
const UI_SCALE_MIN = 1.0
const UI_SCALE_MAX = 2.0
const BASE_TOPBAR_HEIGHT = 40.0
const BASE_SPELL_BTN_SIZE = Vector2(80, 80)  # Slightly larger for icons
const BASE_SPELL_FONT_SIZE = 12
const BASE_SPELL_LABEL_FONT_SIZE = 11
const BASE_END_TURN_SIZE = Vector2(160, 50)
const BASE_END_TURN_FONT_SIZE = 16
const BASE_AP_FONT_SIZE = 20
const BASE_TIMER_FONT_SIZE = 22
const BASE_TOPBAR_FONT_SIZE = 16
const BASE_HP_NAME_FONT_SIZE = 18
const BASE_HP_LABEL_FONT_SIZE = 14
const BASE_HP_BAR_SIZE = Vector2(150, 20)
const BASE_TOPBAR_GAP = 8.0
const BASE_HUD_EDGE_PADDING = 8.0
const BOARD_PADDING = 12.0
const MIN_BOARD_SCALE = 0.6
const MAX_BOARD_SCALE = 2.0
const BOARD_TILT_Y_SCALE = 0.85
const BASE_LOG_FONT_SIZE = 14
const BASE_TOOLTIP_FONT_SIZE = 14
const BASE_LOBBY_PANEL_SIZE = Vector2(400, 350)
const BASE_LOBBY_TITLE_FONT_SIZE = 24
const BASE_LOBBY_LABEL_FONT_SIZE = 16
const BASE_LOBBY_BUTTON_FONT_SIZE = 18
const BASE_LOBBY_INPUT_FONT_SIZE = 16
const BASE_LOBBY_BUTTON_SIZE = Vector2(200, 40)
const BASE_LOBBY_INPUT_SIZE = Vector2(200, 35)
const BASE_LOBBY_VBOX_PADDING = 20.0
const BASE_LOBBY_VBOX_SEPARATION = 15.0
const TOUCH_MOUSE_DEDUP_MS = 240
const TOUCH_MOUSE_DEDUP_DIST = 24.0

var ui_scale: float = 1.0
var ui_metrics_scale: float = 1.0
var ui_text_scale: float = 1.0
var is_portrait: bool = false
var safe_area_rect: Rect2 = Rect2()
var window_safe_size: Vector2 = Vector2.ZERO
var emulate_mouse_from_touch: bool = false
var last_touch_msec: int = -1000
var last_touch_pos: Vector2 = Vector2.ZERO
var last_touch_handled: bool = false

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
const CONNECT_TIMEOUT_MS = 12000
const CONNECT_POLL_INTERVAL = 0.1


func _ready():
	if OS.has_feature("mobile") or OS.has_feature("web"):
		# Allow UI controls to receive touch via mouse emulation.
		emulate_mouse_from_touch = true
		Input.set_emulate_mouse_from_touch(true)
	# Connect Signals
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	# Create custom spell tooltip
	create_spell_tooltip()
	
	# Show lobby first
	show_lobby()
	call_deferred("apply_responsive_layout", 0)

func show_lobby():
	# Create lobby panel
	lobby_panel = Panel.new()
	var lobby_style = StyleBoxFlat.new()
	lobby_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	lobby_style.border_width_left = 4
	lobby_style.border_width_right = 4
	lobby_style.border_width_top = 4
	lobby_style.border_width_bottom = 4
	lobby_style.border_color = Color(0.3, 0.3, 0.4, 0.8)
	lobby_style.corner_radius_top_left = 15
	lobby_style.corner_radius_top_right = 15
	lobby_style.corner_radius_bottom_left = 15
	lobby_style.corner_radius_bottom_right = 15
	lobby_style.shadow_size = 10
	lobby_style.shadow_color = Color(0, 0, 0, 0.5)
	lobby_panel.add_theme_stylebox_override("panel", lobby_style)
	
	lobby_panel.custom_minimum_size = BASE_LOBBY_PANEL_SIZE
	lobby_panel.set_anchors_preset(Control.PRESET_CENTER)
	lobby_panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -BASE_LOBBY_PANEL_SIZE.x * 0.5)
	lobby_panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, BASE_LOBBY_PANEL_SIZE.x * 0.5)
	lobby_panel.set_anchor_and_offset(SIDE_TOP, 0.5, -BASE_LOBBY_PANEL_SIZE.y * 0.5)
	lobby_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5, BASE_LOBBY_PANEL_SIZE.y * 0.5)
	
	lobby_vbox = VBoxContainer.new()
	lobby_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_vbox.set_anchor_and_offset(SIDE_LEFT, 0, BASE_LOBBY_VBOX_PADDING)
	lobby_vbox.set_anchor_and_offset(SIDE_RIGHT, 1, -BASE_LOBBY_VBOX_PADDING)
	lobby_vbox.set_anchor_and_offset(SIDE_TOP, 0, BASE_LOBBY_VBOX_PADDING)
	lobby_vbox.set_anchor_and_offset(SIDE_BOTTOM, 1, -BASE_LOBBY_VBOX_PADDING)
	lobby_vbox.add_theme_constant_override("separation", int(BASE_LOBBY_VBOX_SEPARATION))
	lobby_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	lobby_title = Label.new()
	lobby_title.text = "TACTICAL DUEL - ONLINE PVP"
	lobby_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_title.add_theme_font_size_override("font_size", BASE_LOBBY_TITLE_FONT_SIZE)
	lobby_title.add_theme_font_size_override("font_size", BASE_LOBBY_TITLE_FONT_SIZE)
	lobby_vbox.add_child(lobby_title)
	
	# Character Selector
	lobby_char_btn = Button.new()
	lobby_char_btn.text = "Class: RANGER (Anti-Gravity)"
	lobby_char_btn.custom_minimum_size = BASE_LOBBY_BUTTON_SIZE
	lobby_char_btn.pressed.connect(_on_char_toggle)
	lobby_vbox.add_child(lobby_char_btn)
	
	lobby_create_btn = Button.new()
	lobby_create_btn.text = "Create Room"
	lobby_create_btn.custom_minimum_size = BASE_LOBBY_BUTTON_SIZE
	lobby_create_btn.pressed.connect(_on_create_room)
	lobby_vbox.add_child(lobby_create_btn)
	
	lobby_join_label = Label.new()
	lobby_join_label.text = "Or join with room code:"
	lobby_join_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_vbox.add_child(lobby_join_label)
	
	room_code_input = LineEdit.new()
	room_code_input.placeholder_text = "Enter room code..."
	room_code_input.custom_minimum_size = BASE_LOBBY_INPUT_SIZE
	room_code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_vbox.add_child(room_code_input)
	
	lobby_join_btn = Button.new()
	lobby_join_btn.text = "Join Room"
	lobby_join_btn.custom_minimum_size = BASE_LOBBY_BUTTON_SIZE
	lobby_join_btn.pressed.connect(_on_join_room)
	lobby_vbox.add_child(lobby_join_btn)
	
	lobby_offline_btn = Button.new()
	lobby_offline_btn.text = "Play Offline (Local)"
	lobby_offline_btn.custom_minimum_size = BASE_LOBBY_BUTTON_SIZE
	lobby_offline_btn.pressed.connect(_on_play_offline)
	lobby_vbox.add_child(lobby_offline_btn)
	
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color.CYAN)
	status_label.add_theme_font_size_override("font_size", 16)
	lobby_vbox.add_child(status_label)
	
	# Apply some default button styles locally for the lobby
	for btn in [lobby_char_btn, lobby_create_btn, lobby_join_btn, lobby_offline_btn]:
		var bs = StyleBoxFlat.new()
		bs.bg_color = Color(0.2, 0.2, 0.3, 0.9)
		bs.border_width_bottom = 4
		bs.border_color = Color(0.1, 0.1, 0.2, 1.0)
		bs.corner_radius_top_left = 6
		bs.corner_radius_top_right = 6
		bs.corner_radius_bottom_left = 6
		bs.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", bs)
		var bsh = bs.duplicate()
		bsh.bg_color = Color(0.3, 0.3, 0.5, 1.0)
		btn.add_theme_stylebox_override("hover", bsh)
	
	lobby_panel.add_child(lobby_vbox)
	$CanvasLayer.add_child(lobby_panel)
	_apply_lobby_metrics()
	
	# Hide game UI
	$CanvasLayer/HUD.visible = false

func _on_create_room():
	status_label.text = "Connecting to server..."
	await connect_to_server()
	if connected:
		socket.send_text(JSON.stringify({"type": "CREATE_ROOM"}))
		status_label.text = "Creating room..."

func _on_char_toggle():
	if selected_character == "RANGER":
		selected_character = "MELEE"
		lobby_char_btn.text = "Class: MELEE (Brawler)"
	elif selected_character == "MELEE":
		selected_character = "MAGE"
		lobby_char_btn.text = "Class: MAGE (Elementalist)"
	else:
		selected_character = "RANGER"
		lobby_char_btn.text = "Class: RANGER (Anti-Gravity)"

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
	$CanvasLayer/HUD.visible = true
	# In offline mode, both players use the selected character for testing
	game_state = Data.create_initial_state(selected_character, "RANGER") # P2 defaults to Ranger dummy
	call_deferred("update_all")

func connect_to_server():
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		connected = true
		return
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.close()
	socket = WebSocketPeer.new()
	connected = false
	var err = socket.connect_to_url(SERVER_URL)
	if err != OK:
		status_label.text = "Failed to connect! Is server running?"
		return
	
	# Wait for connection
	var start_ms = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < CONNECT_TIMEOUT_MS:
		socket.poll()
		var state = socket.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			connected = true
			status_label.text = "Connected!"
			return
		if state == WebSocketPeer.STATE_CLOSED:
			break
		await get_tree().create_timer(CONNECT_POLL_INTERVAL).timeout
	
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
			# Clamp to 0 to prevent negative display
			if turn_time_remaining < 0:
				turn_time_remaining = 0
			timer_label.text = "⏱️ %ds" % int(ceil(turn_time_remaining))
			
			if turn_time_remaining <= 0:
				# Reset timer before ending turn to prevent re-triggering
				turn_time_remaining = TURN_DURATION
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
			# Store old status effects to detect new effects on targets
			var old_p1_status = game_state.units.P1.status.duplicate(true) if game_state else {}
			var old_p2_status = game_state.units.P2.status.duplicate(true) if game_state else {}
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
			
			# Check for HP changes and status effects applied to targets
			var new_p1_hp = game_state.units.P1.hp
			var new_p2_hp = game_state.units.P2.hp
			
			var p1_hp_change = old_p1_hp - new_p1_hp
			var p2_hp_change = old_p2_hp - new_p2_hp
			
			# Detect newly applied status effects on each player
			var p1_effects = _detect_new_effects(old_p1_status, game_state.units.P1.status)
			var p2_effects = _detect_new_effects(old_p2_status, game_state.units.P2.status)
			
			# Spawn popups for targets with changes
			if p1_hp_change != 0 or p1_effects.size() > 0:
				spawn_stat_popup("P1", p1_hp_change, p1_effects)
			if p2_hp_change != 0 or p2_effects.size() > 0:
				spawn_stat_popup("P2", p2_hp_change, p2_effects)
			
			# Reset timer if turn changed
			if game_state.turn.currentPlayerId != old_player:
				turn_time_remaining = TURN_DURATION
				selected_spell_id = null
			
			update_all()
			
		"ERROR":
			if is_instance_valid(status_label):
				status_label.text = "Error: %s" % msg.message
			
		"PLAYER_DISCONNECTED":
			if is_instance_valid(status_label):
				status_label.text = "Opponent disconnected!"
			# Could return to lobby here

func _input(event):
	if not game_state:
		return
	
	# In multiplayer, only allow input on my turn
	if multiplayer_mode and game_state.turn.currentPlayerId != my_player_id:
		return
	
	if event is InputEventScreenTouch and event.pressed:
		last_touch_msec = Time.get_ticks_msec()
		last_touch_pos = event.position
		last_touch_handled = not emulate_mouse_from_touch
		if last_touch_handled:
			_handle_pointer_press(event.position, false)
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if last_touch_handled:
			var delta = Time.get_ticks_msec() - last_touch_msec
			if delta >= 0 and delta <= TOUCH_MOUSE_DEDUP_MS and last_touch_pos.distance_to(event.position) <= TOUCH_MOUSE_DEDUP_DIST:
				last_touch_handled = false
				return
			last_touch_handled = false
		_handle_pointer_press(event.position, true)
	
	# Spacebar to end turn
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_on_end_turn_pressed()

func _screen_to_canvas(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pos

func _is_ui_hit(screen_pos: Vector2) -> bool:
	var canvas_pos = _screen_to_canvas(screen_pos)
	if _control_contains_point(bottom_bar, canvas_pos):
		return true
	if _control_contains_point(top_bar, canvas_pos):
		return true
	if _control_contains_point(log_panel, canvas_pos):
		return true
	if _control_contains_point(p1_hp_display, canvas_pos):
		return true
	if _control_contains_point(p2_hp_display, canvas_pos):
		return true
	if _control_contains_point(timer_label, canvas_pos):
		return true
	if lobby_panel and _control_contains_point(lobby_panel, canvas_pos):
		return true
	if game_over_panel and _control_contains_point(game_over_panel, canvas_pos):
		return true
	if spell_tooltip and spell_tooltip.visible and _control_contains_point(spell_tooltip, canvas_pos):
		return true
	return false

func _control_contains_point(control: Control, point: Vector2) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	return control.get_global_rect().has_point(point)

func _get_grid_from_screen_pos(pos: Vector2) -> Vector2i:
	var canvas_pos = _screen_to_canvas(pos)
	return Iso.pixel_to_grid(canvas_pos.x, canvas_pos.y)

func _handle_pointer_press(screen_pos: Vector2, allow_deselect_outside: bool = true) -> void:
	if _is_ui_hit(screen_pos):
		return
	var grid = _get_grid_from_screen_pos(screen_pos)
	if Rules.in_bounds(grid.x, grid.y):
		hovered_tile = grid
		update_board_visuals()
		try_action_at(grid.x, grid.y)
	elif allow_deselect_outside and selected_spell_id != null:
		# Clicked outside the board while a spell is selected - deselect it
		selected_spell_id = null
		update_all()

func _get_window_size() -> Vector2:
	return get_viewport_rect().size * _get_canvas_scale()

func _get_canvas_scale() -> float:
	var scale = get_viewport().get_canvas_transform().get_scale()
	var value = min(scale.x, scale.y)
	return value if value > 0.0 else 1.0

func _get_window_safe_area() -> Rect2:
	var window_size = _get_window_size()
	var safe_rect = Rect2(Vector2.ZERO, window_size)
	if ClassDB.class_has_method("DisplayServer", "get_display_safe_area"):
		var rect = DisplayServer.call("get_display_safe_area")
		if rect is Rect2:
			safe_rect = rect
	elif ClassDB.class_has_method("DisplayServer", "screen_get_usable_rect"):
		var screen_id = 0
		if ClassDB.class_has_method("DisplayServer", "window_get_current_screen"):
			screen_id = DisplayServer.call("window_get_current_screen")
		var rect = DisplayServer.call("screen_get_usable_rect", screen_id)
		if rect is Rect2:
			safe_rect = rect
	elif ClassDB.class_has_method("OS", "get_window_safe_area"):
		var rect = OS.call("get_window_safe_area")
		if rect is Rect2:
			safe_rect = rect
	if safe_rect.size == Vector2.ZERO:
		safe_rect = Rect2(Vector2.ZERO, window_size)
	return safe_rect

func _window_rect_to_canvas_rect(window_rect: Rect2) -> Rect2:
	var inv = get_viewport().get_canvas_transform().affine_inverse()
	var top_left = inv * window_rect.position
	var bottom_right = inv * (window_rect.position + window_rect.size)
	return Rect2(top_left, bottom_right - top_left)

func _get_safe_area_rect() -> Rect2:
	var viewport_rect = get_viewport_rect()
	var safe_rect = _window_rect_to_canvas_rect(_get_window_safe_area())
	var clipped = safe_rect.intersection(viewport_rect)
	return clipped if clipped.size != Vector2.ZERO else viewport_rect

func _get_ui_metrics_boost(min_side: float) -> float:
	if min_side <= 600.0:
		return 1.25
	if min_side <= 800.0:
		return 1.15
	if min_side <= 1000.0:
		return 1.1
	return 1.0

func _get_compact_text_boost(min_side: float) -> float:
	if not _is_compact_layout(min_side):
		return 1.0
	if min_side <= 600.0:
		return 1.15
	if min_side <= 800.0:
		return 1.1
	return 1.05

func _is_compact_layout(min_side: float) -> bool:
	return is_portrait or min_side <= 900.0

func _get_spell_button_size(columns: int) -> Vector2:
	var scale = ui_metrics_scale
	var min_side = min(window_safe_size.x, window_safe_size.y)
	if not _is_compact_layout(min_side):
		return BASE_SPELL_BTN_SIZE * scale
	var padding = BASE_HUD_EDGE_PADDING * scale
	var separation = int(BASE_TOPBAR_GAP * scale)
	var available_width = max(0.0, safe_area_rect.size.x - padding * 2.0 - separation * max(columns - 1, 0))
	var width = available_width / max(columns, 1)
	# For mobile icons, we want square buttons or close to square
	var height = width
	return Vector2(width, height)

func _get_end_turn_button_size() -> Vector2:
	var scale = ui_metrics_scale
	var size = BASE_END_TURN_SIZE * scale
	if _is_compact_layout(min(window_safe_size.x, window_safe_size.y)):
		var padding = BASE_HUD_EDGE_PADDING * scale
		size.x = max(size.x, safe_area_rect.size.x - padding * 2.0)
		var min_height = float(BASE_END_TURN_FONT_SIZE) * ui_text_scale * 1.8
		size.y = max(size.y, max(64.0 * scale, min_height))
	return size

func _update_ui_scale(safe_canvas_size: Vector2) -> void:
	var min_side = max(1.0, min(safe_canvas_size.x, safe_canvas_size.y))
	var physical_scale = clamp(UI_BASE_MIN_SIDE / min_side, UI_SCALE_MIN, UI_SCALE_MAX)
	ui_scale = physical_scale
	is_portrait = safe_canvas_size.y >= safe_canvas_size.x
	ui_metrics_scale = min(ui_scale * _get_ui_metrics_boost(min_side), 2.6)
	ui_text_scale = ui_metrics_scale * _get_compact_text_boost(min_side)
	self.window_safe_size = safe_canvas_size

func _apply_safe_area_offsets(viewport_rect: Rect2, safe_rect: Rect2) -> void:
	hud.offset_left = safe_rect.position.x
	hud.offset_top = safe_rect.position.y
	hud.offset_right = safe_rect.position.x + safe_rect.size.x - viewport_rect.size.x
	hud.offset_bottom = safe_rect.position.y + safe_rect.size.y - viewport_rect.size.y

func _apply_ui_metrics() -> void:
	var scale = ui_metrics_scale
	var text_scale = ui_text_scale
	var edge_pad = BASE_HUD_EDGE_PADDING * scale
	var top_bar_height = BASE_TOPBAR_HEIGHT * text_scale
	top_bar.add_theme_constant_override("separation", int(BASE_TOPBAR_GAP * scale))
	top_bar.offset_top = edge_pad
	top_bar.offset_bottom = edge_pad + top_bar_height
	
	turn_label.add_theme_font_size_override("font_size", int(BASE_TOPBAR_FONT_SIZE * text_scale))
	p1_status.add_theme_font_size_override("font_size", int(BASE_TOPBAR_FONT_SIZE * text_scale))
	p2_status.add_theme_font_size_override("font_size", int(BASE_TOPBAR_FONT_SIZE * text_scale))
	
	p1_name.add_theme_font_size_override("font_size", int(BASE_HP_NAME_FONT_SIZE * text_scale))
	p2_name.add_theme_font_size_override("font_size", int(BASE_HP_NAME_FONT_SIZE * text_scale))
	p1_hp_label.add_theme_font_size_override("font_size", int(BASE_HP_LABEL_FONT_SIZE * text_scale))
	p2_hp_label.add_theme_font_size_override("font_size", int(BASE_HP_LABEL_FONT_SIZE * text_scale))
	
	# HP Bar Styling
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	hp_bg.border_width_left = 2
	hp_bg.border_width_right = 2
	hp_bg.border_width_top = 2
	hp_bg.border_width_bottom = 2
	hp_bg.border_color = Color(0.3, 0.3, 0.35, 0.8)
	hp_bg.corner_radius_top_left = 6
	hp_bg.corner_radius_top_right = 6
	hp_bg.corner_radius_bottom_left = 6
	hp_bg.corner_radius_bottom_right = 6
	
	var hp_fg = StyleBoxFlat.new()
	hp_fg.bg_color = Color(0.85, 0.15, 0.15)
	hp_fg.corner_radius_top_left = 4
	hp_fg.corner_radius_top_right = 4
	hp_fg.corner_radius_bottom_left = 4
	hp_fg.corner_radius_bottom_right = 4
	hp_fg.border_width_right = 2
	hp_fg.border_color = Color(1.0, 0.3, 0.3, 0.5)
	
	p1_hp_bar.add_theme_stylebox_override("background", hp_bg)
	p1_hp_bar.add_theme_stylebox_override("fill", hp_fg)
	p2_hp_bar.add_theme_stylebox_override("background", hp_bg)
	p2_hp_bar.add_theme_stylebox_override("fill", hp_fg)
	
	p1_hp_display.offset_left = 20.0 * text_scale
	p1_hp_display.offset_top = 20.0 * text_scale
	p1_hp_display.offset_right = 220.0 * text_scale
	p1_hp_display.offset_bottom = 90.0 * text_scale
	
	p2_hp_display.offset_left = -220.0 * text_scale
	p2_hp_display.offset_top = 20.0 * text_scale
	p2_hp_display.offset_right = -20.0 * text_scale
	p2_hp_display.offset_bottom = 90.0 * text_scale
	
	timer_label.add_theme_font_size_override("font_size", int(BASE_TIMER_FONT_SIZE * text_scale))
	timer_label.offset_left = -130.0 * text_scale
	timer_label.offset_top = -55.0 * text_scale
	timer_label.offset_right = -20.0 * text_scale
	timer_label.offset_bottom = -15.0 * text_scale
	
	ap_label.add_theme_font_size_override("font_size", int(BASE_AP_FONT_SIZE * text_scale))
	bottom_bar.add_theme_constant_override("separation", int(BASE_TOPBAR_GAP * scale))
	spell_container.add_theme_constant_override("h_separation", int(BASE_TOPBAR_GAP * scale))
	spell_container.add_theme_constant_override("v_separation", int(BASE_TOPBAR_GAP * scale))
	
	end_turn_btn.add_theme_font_size_override("font_size", int(BASE_END_TURN_FONT_SIZE * text_scale))
	end_turn_btn.custom_minimum_size = _get_end_turn_button_size()
	
	# End Turn Button Styling
	var et_style = StyleBoxFlat.new()
	et_style.bg_color = Color(0.1, 0.4, 0.1, 0.8) if _is_my_turn() else Color(0.2, 0.2, 0.2, 0.5)
	et_style.border_width_left = 2
	et_style.border_width_right = 2
	et_style.border_width_top = 2
	et_style.border_width_bottom = 2
	et_style.border_color = Color(0.2, 0.8, 0.2, 0.6) if _is_my_turn() else Color(0.4, 0.4, 0.4, 0.3)
	et_style.corner_radius_top_left = 10
	et_style.corner_radius_top_right = 10
	et_style.corner_radius_bottom_left = 10
	et_style.corner_radius_bottom_right = 10
	end_turn_btn.add_theme_stylebox_override("normal", et_style)
	
	var et_hover = et_style.duplicate()
	et_hover.bg_color = et_style.bg_color.lightened(0.2)
	end_turn_btn.add_theme_stylebox_override("hover", et_hover)
	
	log_panel.add_theme_font_size_override("normal_font_size", int(BASE_LOG_FONT_SIZE * text_scale))
	if spell_tooltip_label:
		spell_tooltip_label.add_theme_font_size_override("normal_font_size", int(BASE_TOOLTIP_FONT_SIZE * text_scale))
	_apply_lobby_metrics()

func _is_my_turn() -> bool:
	return game_state and (not multiplayer_mode or game_state.turn.currentPlayerId == my_player_id)

func _get_spell_columns(window_safe_size: Vector2) -> int:
	var min_side = min(window_safe_size.x, window_safe_size.y)
	if _is_compact_layout(min_side):
		return 3
	if window_safe_size.x < 900.0:
		return 4
	return 5

func _estimate_bottom_bar_height(spell_count: int, columns: int) -> float:
	var scale = ui_metrics_scale
	var text_scale = ui_text_scale
	var separation = int(BASE_TOPBAR_GAP * scale)
	var ap_height = int(BASE_AP_FONT_SIZE * text_scale) + int(6 * scale)
	var end_turn_height = max(end_turn_btn.custom_minimum_size.y, BASE_END_TURN_SIZE.y * scale)
	var button_height = _get_spell_button_size(columns).y
	var label_height = int(BASE_SPELL_LABEL_FONT_SIZE * text_scale)
	var label_spacing = int(6 * scale)
	var row_height = button_height + label_spacing + label_height
	var rows = max(1, int(ceil(float(spell_count) / float(max(columns, 1)))))
	var spells_height = rows * row_height + max(0, rows - 1) * separation
	return ap_height + separation + spells_height + separation + end_turn_height

func _apply_lobby_metrics() -> void:
	if lobby_panel == null or not is_instance_valid(lobby_panel):
		return
	if safe_area_rect.size == Vector2.ZERO:
		safe_area_rect = _get_safe_area_rect()
		_update_ui_scale(safe_area_rect.size)
	
	var scale = ui_text_scale
	var panel_size = BASE_LOBBY_PANEL_SIZE * scale
	var max_w = safe_area_rect.size.x * 0.94
	var max_h = safe_area_rect.size.y * 0.9
	panel_size.x = min(panel_size.x, max_w)
	panel_size.y = min(panel_size.y, max_h)
	panel_size.x = max(panel_size.x, 260.0)
	panel_size.y = max(panel_size.y, 240.0)
	
	lobby_panel.custom_minimum_size = panel_size
	lobby_panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -panel_size.x * 0.5)
	lobby_panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, panel_size.x * 0.5)
	lobby_panel.set_anchor_and_offset(SIDE_TOP, 0.5, -panel_size.y * 0.5)
	lobby_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5, panel_size.y * 0.5)
	
	if lobby_vbox and is_instance_valid(lobby_vbox):
		var edge_pad = BASE_LOBBY_VBOX_PADDING * ui_metrics_scale
		lobby_vbox.set_anchor_and_offset(SIDE_LEFT, 0, edge_pad)
		lobby_vbox.set_anchor_and_offset(SIDE_RIGHT, 1, -edge_pad)
		lobby_vbox.set_anchor_and_offset(SIDE_TOP, 0, edge_pad)
		lobby_vbox.set_anchor_and_offset(SIDE_BOTTOM, 1, -edge_pad)
		lobby_vbox.add_theme_constant_override("separation", int(BASE_LOBBY_VBOX_SEPARATION * ui_metrics_scale))
	
	if lobby_title and is_instance_valid(lobby_title):
		lobby_title.add_theme_font_size_override("font_size", int(BASE_LOBBY_TITLE_FONT_SIZE * scale))
	if lobby_join_label and is_instance_valid(lobby_join_label):
		lobby_join_label.add_theme_font_size_override("font_size", int(BASE_LOBBY_LABEL_FONT_SIZE * scale))
	if status_label and is_instance_valid(status_label):
		status_label.add_theme_font_size_override("font_size", int(BASE_LOBBY_LABEL_FONT_SIZE * scale))
	
	var btn_size = BASE_LOBBY_BUTTON_SIZE * scale
	if lobby_create_btn and is_instance_valid(lobby_create_btn):
		lobby_create_btn.custom_minimum_size = btn_size
		lobby_create_btn.add_theme_font_size_override("font_size", int(BASE_LOBBY_BUTTON_FONT_SIZE * scale))
	if lobby_join_btn and is_instance_valid(lobby_join_btn):
		lobby_join_btn.custom_minimum_size = btn_size
		lobby_join_btn.add_theme_font_size_override("font_size", int(BASE_LOBBY_BUTTON_FONT_SIZE * scale))
	if lobby_offline_btn and is_instance_valid(lobby_offline_btn):
		lobby_offline_btn.custom_minimum_size = btn_size
		lobby_offline_btn.add_theme_font_size_override("font_size", int(BASE_LOBBY_BUTTON_FONT_SIZE * scale))
	
	if room_code_input and is_instance_valid(room_code_input):
		room_code_input.custom_minimum_size = BASE_LOBBY_INPUT_SIZE * scale
		room_code_input.add_theme_font_size_override("font_size", int(BASE_LOBBY_INPUT_FONT_SIZE * scale))

func _get_board_rect(safe_rect: Rect2, top_bar_height: float, bottom_bar_height: float) -> Rect2:
	var padding = BOARD_PADDING * ui_scale
	var pos = safe_rect.position + Vector2(padding, top_bar_height + padding)
	var size = safe_rect.size - Vector2(padding * 2.0, top_bar_height + bottom_bar_height + padding * 2.0)
	if size.x <= 0.0 or size.y <= 0.0:
		return safe_rect
	return Rect2(pos, size)

func _update_board_scale(board_rect: Rect2) -> void:
	Iso.set_tilt_y_scale(BOARD_TILT_Y_SCALE)
	var base_size = Iso.get_base_board_size(Data.BOARD.rows, Data.BOARD.cols)
	if base_size.x <= 0.0 or base_size.y <= 0.0:
		return
	var scale = min(board_rect.size.x / base_size.x, board_rect.size.y / base_size.y)
	scale = clamp(scale, MIN_BOARD_SCALE, MAX_BOARD_SCALE)
	Iso.set_tile_scale(scale)
	Iso.compute_origin_in_rect(board_rect, Data.BOARD.rows, Data.BOARD.cols)

func _get_spell_count_for_layout() -> int:
	if not game_state: return 6
	var pid = game_state.turn.currentPlayerId
	var char_id = game_state.units[pid].get("character_class", "RANGER")
	return Data.get_character_spells(char_id).size()

func apply_responsive_layout(spell_count: int) -> void:
	var viewport_rect = get_viewport_rect()
	safe_area_rect = _get_safe_area_rect()
	_update_ui_scale(safe_area_rect.size)
	_apply_safe_area_offsets(viewport_rect, safe_area_rect)
	_apply_ui_metrics()
	
	var columns = _get_spell_columns(safe_area_rect.size)
	spell_container.columns = columns
	
	var bottom_bar_height = _estimate_bottom_bar_height(spell_count, columns)
	bottom_bar.offset_top = -bottom_bar_height
	bottom_bar.offset_bottom = 0.0
	
	var top_overlay_height = max(top_bar.offset_bottom, p1_hp_display.offset_bottom, p2_hp_display.offset_bottom)
	var board_rect = _get_board_rect(safe_area_rect, top_overlay_height, bottom_bar_height)
	_update_board_scale(board_rect)
	
	board.refresh_layout()

func _on_viewport_resized():
	apply_responsive_layout(_get_spell_count_for_layout())
	update_units_visuals()

func update_all():
	apply_responsive_layout(_get_spell_count_for_layout())
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
	var p1_max_hp = Data.MELEE_HP if u1.get("character_class", "RANGER") == "MELEE" else Data.MAX_HP
	var p2_max_hp = Data.MELEE_HP if u2.get("character_class", "RANGER") == "MELEE" else Data.MAX_HP
	p1_hp_bar.max_value = p1_max_hp
	p1_hp_bar.value = u1.hp
	p1_hp_label.text = "%d / %d" % [u1.hp, p1_max_hp]
	p2_hp_bar.max_value = p2_max_hp
	p2_hp_bar.value = u2.hp
	p2_hp_label.text = "%d / %d" % [u2.hp, p2_max_hp]
	
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
	var unit = game_state.units[pid]
	var char_id = unit.get("character_class", "RANGER")
	
	# Get spells dynamically from character class
	var spell_list = Data.get_character_spells(char_id)
	var button_size = _get_spell_button_size(spell_container.columns)
	var cost_font_size = int(BASE_SPELL_LABEL_FONT_SIZE * ui_text_scale)
	var label_spacing = int(4 * ui_metrics_scale)
	
	for spell_id in spell_list:
		var spell = Data.get_spell(spell_id)
		if spell.is_empty(): continue
		var cd = unit.cooldowns.get(spell_id, 0)
		
		# Main cell container
		var cell = VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 6)
		
		# Square button area
		var frame = PanelContainer.new()
		frame.custom_minimum_size = button_size
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		# 1. SETUP STYLING
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.12, 0.12, 0.18, 1.0)
		normal_style.set_border_width_all(2)
		normal_style.border_color = Color(0.4, 0.4, 0.5, 0.6)
		normal_style.set_corner_radius_all(12)
		frame.add_theme_stylebox_override("panel", normal_style)
		cell.add_child(frame)
		
		# 2. THE ICON
		var icon_rect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.anchor_left = 0.0
		icon_rect.anchor_top = 0.0
		icon_rect.anchor_right = 1.0
		icon_rect.anchor_bottom = 1.0
		icon_rect.offset_left = 8
		icon_rect.offset_top = 8
		icon_rect.offset_right = -8
		icon_rect.offset_bottom = -8
		
		if spell.has("icon_atlas"):
			var path = spell.icon_atlas.strip_edges()
			var tex = null
			
			# Multi-Format Hyper-Diagnostic Load
			var fa = FileAccess.open(path, FileAccess.READ)
			if fa:
				var flen = fa.get_length()
				var buffer = fa.get_buffer(flen)
				var img = Image.new()
				
				# Detect format via magic bytes
				var magic = buffer.slice(0, 4).hex_encode()
				var err = OK
				
				if magic == "89504e47": # PNG
					err = img.load_png_from_buffer(buffer)
					print("[UI] Decoding PNG: ", path)
				elif magic.begins_with("ffd8ff"): # JPEG
					err = img.load_jpg_from_buffer(buffer)
					print("[UI] Decoding JPEG (despite .png ext): ", path)
				else:
					# Try generic load as last resort
					err = img.load_from_buffer(buffer)
					print("[UI] Unknown format magic ", magic, ", trying generic load")
					
				if err == OK:
					tex = ImageTexture.create_from_image(img)
					print("[UI] SUCCESS: Manual Decode OK")
				else:
					printerr("[UI] FAIL: Decode Error ", err, " for magic ", magic)
			else:
				# Fallback to standard for robustness
				tex = load(path)
			
			if tex:
				var atlas = AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = spell.get("icon_region", Rect2(0,0,341,341))
				icon_rect.texture = atlas
			else:
				icon_rect.texture = load("res://icon.svg")
				icon_rect.modulate = Color(1.0, 0.4, 0.4, 0.5) 
		
		frame.add_child(icon_rect)

		# 3. INTERACTION & STATUS (Added AFTER Icon to be on top)
		var btn = Button.new()
		btn.custom_minimum_size = button_size
		btn.flat = true
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		frame.add_child(btn)
		
		if selected_spell_id == spell_id:
			var sel_style = normal_style.duplicate()
			sel_style.border_color = Color(1.0, 0.9, 0.0, 1.0)
			sel_style.set_border_width_all(4)
			frame.add_theme_stylebox_override("panel", sel_style)

		var is_btn_disabled = cd > 0 or (multiplayer_mode and game_state.turn.currentPlayerId != my_player_id) or game_state.winner
		var ap_count = game_state.turn.get("apRemaining", Data.MAX_AP)
		var ap_cost = spell.get("ap_cost", 0)
		
		if ap_count < ap_cost:
			is_btn_disabled = true
			icon_rect.modulate = Color(1.0, 0.4, 0.4, 0.8)
			
		btn.disabled = is_btn_disabled
		if cd > 0: icon_rect.modulate = Color(0.4, 0.4, 0.4, 0.8)

		btn.pressed.connect(_on_spell_clicked.bind(spell_id))
		btn.mouse_entered.connect(show_spell_tooltip.bind(btn, spell.label + "\n\n" + spell.desc))
		btn.mouse_exited.connect(hide_spell_tooltip)

		
		# 5. OVERLAY (AP COST)
		var overlay = Label.new()
		overlay.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		overlay.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		overlay.add_theme_color_override("font_outline_color", Color.BLACK)
		overlay.add_theme_constant_override("outline_size", 4)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		if cd > 0:
			overlay.text = str(cd)
			overlay.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			overlay.add_theme_font_size_override("font_size", int(cost_font_size * 1.6))
		else:
			overlay.text = str(ap_cost)
			overlay.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
			overlay.add_theme_font_size_override("font_size", int(cost_font_size * 1.1))
		
		frame.add_child(overlay)
		
		# Spell Name Label (below frame)
		var name_label = Label.new()
		name_label.text = spell.label
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", int(BASE_SPELL_LABEL_FONT_SIZE * ui_text_scale))
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 2)
		cell.add_child(name_label)
		
		spell_container.add_child(cell)



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
			u_node.scale = Vector2.ONE * Iso.get_tile_scale()
			unit_nodes[pid] = u_node
		else:
			# Animate existing unit to new position
			var u_node = unit_nodes[pid]
			u_node.unit_data = unit_data
			u_node.scale = Vector2.ONE * Iso.get_tile_scale()
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
	# Store old status effects to detect new effects on targets
	var old_p1_status = game_state.units.P1.status.duplicate(true)
	var old_p2_status = game_state.units.P2.status.duplicate(true)
	
	# Store path for move actions before applying (so we know the path to animate)
	if action.type == "MOVE":
		var pid = action.playerId
		var me = game_state.units[pid]
		var path = Rules.find_movement_path(game_state, me.x, me.y, action.to.x, action.to.y)
		if path.size() > 0:
			pending_move_paths[pid] = path
	
	# Trigger spell visual effects BEFORE applying action
	if action.type == "CAST":
		play_spell_effect(action)
	
	game_state = Rules.apply_action(game_state, action)
	
	# Check for HP changes and status effects applied to targets
	var new_p1_hp = game_state.units.P1.hp
	var new_p2_hp = game_state.units.P2.hp
	
	var p1_hp_change = old_p1_hp - new_p1_hp
	var p2_hp_change = old_p2_hp - new_p2_hp
	
	# Detect newly applied status effects on each player
	var p1_effects = _detect_new_effects(old_p1_status, game_state.units.P1.status)
	var p2_effects = _detect_new_effects(old_p2_status, game_state.units.P2.status)
	
	# Spawn popups for targets with changes
	if p1_hp_change != 0 or p1_effects.size() > 0:
		spawn_stat_popup("P1", p1_hp_change, p1_effects)
	if p2_hp_change != 0 or p2_effects.size() > 0:
		spawn_stat_popup("P2", p2_hp_change, p2_effects)
	
	# Reset timer if turn changed
	if game_state.turn.currentPlayerId != old_player:
		turn_time_remaining = TURN_DURATION
		selected_spell_id = null
	
	update_all()

# Detect newly applied status effects by comparing old and new status dictionaries
func _detect_new_effects(old_status: Dictionary, new_status: Dictionary) -> Array:
	var effects = []
	
	# Check for MP reduction (from Immobilizing Arrow, Magnetic Pull)
	if new_status.get("mp_reduction") and not old_status.get("mp_reduction"):
		var amount = new_status.mp_reduction.get("amount", 0)
		if amount > 0:
			effects.append({"type": "mp", "amount": -amount})
	
	# Check for damage boost applied to enemy (from Thief Arrow)
	if new_status.get("damage_boost") and not old_status.get("damage_boost"):
		var percent = new_status.damage_boost.get("percent", 0)
		if percent > 0:
			effects.append({"type": "buff", "text": "+%d%% DMG" % int(percent * 100)})
	
	# Check for gravity lock (from Gravity Lock spell)
	if new_status.get("gravity_lock") and not old_status.get("gravity_lock"):
		effects.append({"type": "debuff", "text": "LOCKED"})
	
	# Check for was_displaced (from push/pull effects)
	if new_status.get("was_displaced") and not old_status.get("was_displaced"):
		effects.append({"type": "debuff", "text": "PUSHED"})
	
	return effects

# Spawn stat change popups for HP damage and status effects applied to targets
func spawn_stat_popup(pid: String, hp_change: int, effects: Array):
	var unit_data = game_state.units[pid]
	var screen_pos = Iso.grid_to_screen(unit_data.x, unit_data.y)
	var base_pos = screen_pos - Vector2(20, 60)
	
	# Track horizontal offset for multiple labels
	var x_offset = 0
	
	# HP change (red for damage, green for healing)
	if hp_change != 0:
		var hp_label = Label.new()
		if hp_change > 0:
			hp_label.text = "-%d" % hp_change
			hp_label.add_theme_color_override("font_color", Color.RED)
		else:
			hp_label.text = "+%d" % (-hp_change)  # Healing
			hp_label.add_theme_color_override("font_color", Color("#22c55e"))  # Green for heal
		hp_label.add_theme_font_size_override("font_size", 28)
		hp_label.position = base_pos + Vector2(x_offset, 0)
		hp_label.z_index = 100
		damage_popups.add_child(hp_label)
		_animate_popup(hp_label)
		x_offset += 65
	
	# Status effects applied to target
	for effect in effects:
		var label = Label.new()
		
		if effect.type == "mp":
			# MP reduction (green, negative)
			label.text = "%d MP" % effect.amount
			label.add_theme_color_override("font_color", Color("#22c55e"))  # Green
		elif effect.type == "ap":
			# AP change (blue)
			var sign_str = "+" if effect.amount > 0 else ""
			label.text = "%s%d AP" % [sign_str, effect.amount]
			label.add_theme_color_override("font_color", Color("#3b82f6"))  # Blue
		elif effect.type == "buff":
			# Buffs (yellow/gold)
			label.text = effect.text
			label.add_theme_color_override("font_color", Color.GOLD)
		elif effect.type == "debuff":
			# Debuffs (purple)
			label.text = effect.text
			label.add_theme_color_override("font_color", Color("#a855f7"))  # Purple
		else:
			continue
		
		label.add_theme_font_size_override("font_size", 20)
		label.position = base_pos + Vector2(x_offset, 0)
		label.z_index = 100
		damage_popups.add_child(label)
		_animate_popup(label)
		x_offset += 70

func _animate_popup(label: Label):
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

# =============================================================================
# SPELL VISUAL EFFECTS
# =============================================================================

func play_spell_effect(action: Dictionary) -> void:
	var spell_id = action.spellId
	var target = action.target
	var pid = action.playerId
	var caster = game_state.units[pid]
	
	var caster_pos = Iso.grid_to_screen(caster.x, caster.y)
	var target_pos = Iso.grid_to_screen(target.x, target.y)
	
	# Get spell color based on type
	var spell_color = get_spell_color(spell_id)
	
	# Trigger character attack animation
	if unit_nodes.has(pid):
		var unit_node = unit_nodes[pid]
		if unit_node.has_method("play_attack_animation"):
			unit_node.play_attack_animation(target_pos)
	
	match spell_id:
		# === RANGER SPELLS (bow animation + delayed projectile) ===
		"KNOCKBACK_ARROW", "PIERCING_ARROW", "EXPONENTIAL_ARROW", "IMMOBILIZING_ARROW", "THIEF_ARROW":
			# Wait for bow draw animation before spawning arrow
			await get_tree().create_timer(0.2).timeout
			spawn_arrow_effect(caster_pos, target_pos, spell_color)
		
		"DISPLACEMENT_ARROW":
			await get_tree().create_timer(0.2).timeout
			spawn_arrow_effect(caster_pos, target_pos, Color.PURPLE)
			# Delayed cross effect
			await get_tree().create_timer(0.25).timeout
			spawn_aoe_cross(target_pos, Color.PURPLE)
		
		# === MELEE SPELLS (sword animation synced with effect) ===
		"CRUSHING_STRIKE":
			await get_tree().create_timer(0.15).timeout
			spawn_slash_effect(target_pos, Color.ORANGE)
		
		"MAGNETIC_PULL":
			spawn_pull_effect(target_pos, caster_pos, Color.MAGENTA)
		
		"GRAVITY_LOCK":
			spawn_lock_effect(target_pos, Color.DARK_VIOLET)
		
		"KINETIC_DASH":
			spawn_dash_effect(caster_pos, target_pos, Color.CYAN)
		
		"SHOCKWAVE_SLAM":
			await get_tree().create_timer(0.2).timeout
			spawn_shockwave_effect(caster_pos, Color.ORANGE)
		
		"ADRENALINE_SURGE":
			spawn_buff_effect(caster_pos, Color.GREEN)

func get_spell_color(spell_id: String) -> Color:
	match spell_id:
		"KNOCKBACK_ARROW": return Color.CYAN
		"PIERCING_ARROW": return Color.RED
		"EXPONENTIAL_ARROW": return Color.GOLD
		"IMMOBILIZING_ARROW": return Color.DARK_BLUE
		"THIEF_ARROW": return Color.PURPLE
		"DISPLACEMENT_ARROW": return Color.MAGENTA
		_: return Color.WHITE

func spawn_arrow_effect(from: Vector2, to: Vector2, color: Color) -> void:
	var arrow = Node2D.new()
	arrow.position = from
	arrow.z_index = 100
	add_child(arrow)
	
	var trail_points = []
	var spark_particles = []
	var rotation_angle = 0.0
	
	arrow.set_meta("trail", trail_points)
	arrow.set_meta("sparks", spark_particles)
	arrow.set_meta("color", color)
	arrow.set_meta("rot", rotation_angle)
	arrow.set_meta("time", 0.0)
	
	arrow.draw.connect(func():
		var t = arrow.get_meta("trail") as Array
		var c = arrow.get_meta("color") as Color
		var rot = arrow.get_meta("rot") as float
		var time = arrow.get_meta("time") as float
		var sparks = arrow.get_meta("sparks") as Array
		
		# Draw gradient trail with glow
		if t.size() > 1:
			for i in range(t.size() - 1):
				var alpha = float(i) / t.size()
				var local_from = t[i] - arrow.position
				var local_to = t[i + 1] - arrow.position
				# Outer glow
				var glow_color = c
				glow_color.a = alpha * 0.3
				arrow.draw_line(local_from, local_to, glow_color, 12.0 * alpha)
				# Core trail
				var trail_color = c.lightened(0.2)
				trail_color.a = alpha * 0.9
				arrow.draw_line(local_from, local_to, trail_color, 5.0 * alpha)
				# Bright center
				var center_color = Color.WHITE
				center_color.a = alpha * 0.7
				arrow.draw_line(local_from, local_to, center_color, 2.0 * alpha)
		
		# Draw spark particles
		for spark in sparks:
			var spark_color = c.lightened(0.5)
			spark_color.a = spark.a
			arrow.draw_circle(spark.pos - arrow.position, spark.size, spark_color)
		
		# Outer glow pulse
		var pulse = 0.8 + sin(time * 20) * 0.2
		var glow_size = 18 * pulse
		arrow.draw_circle(Vector2.ZERO, glow_size, Color(c.r, c.g, c.b, 0.2))
		arrow.draw_circle(Vector2.ZERO, glow_size * 0.7, Color(c.r, c.g, c.b, 0.3))
		
		# Rotating energy ring
		for i in range(4):
			var angle = rot + (TAU / 4) * i
			var ring_pos = Vector2(cos(angle), sin(angle)) * 10
			arrow.draw_circle(ring_pos, 3, c.lightened(0.3))
		
		# Core with gradient
		arrow.draw_circle(Vector2.ZERO, 10, c)
		arrow.draw_circle(Vector2.ZERO, 7, c.lightened(0.4))
		arrow.draw_circle(Vector2.ZERO, 4, Color.WHITE)
	)
	
	var duration = from.distance_to(to) / 1200.0
	duration = clamp(duration, 0.12, 0.35)
	
	var tween = create_tween()
	tween.tween_method(func(t: float):
		var new_pos = from.lerp(to, t)
		trail_points.append(arrow.position)
		if trail_points.size() > 20:
			trail_points.pop_front()
		
		# Spawn sparks along trail
		if randf() < 0.4:
			var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
			spark_particles.append({"pos": arrow.position + offset, "a": 1.0, "size": randf_range(2, 4)})
		
		# Update sparks
		for spark in spark_particles:
			spark.a -= 0.08
		spark_particles = spark_particles.filter(func(s): return s.a > 0)
		
		rotation_angle += 0.4
		arrow.set_meta("trail", trail_points)
		arrow.set_meta("sparks", spark_particles)
		arrow.set_meta("rot", rotation_angle)
		arrow.set_meta("time", t)
		arrow.position = new_pos
		arrow.queue_redraw()
	, 0.0, 1.0, duration).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(func():
		spawn_impact_effect(to, color)
		spawn_screen_flash(color, 0.15)
		arrow.queue_free()
	)

func spawn_impact_effect(pos: Vector2, color: Color) -> void:
	var impact = Node2D.new()
	impact.position = pos
	impact.z_index = 100
	add_child(impact)
	
	var rings = []
	var particles = []
	var debris = []
	
	# Create multiple ring layers
	for i in range(4):
		rings.append({"r": 5.0, "a": 1.0, "width": 5.0 - i, "delay": i * 0.05})
	
	# Burst particles
	for i in range(16):
		var angle = randf() * TAU
		var speed = randf_range(100, 220)
		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"a": 1.0,
			"size": randf_range(3, 7),
			"decay": randf_range(1.5, 2.5)
		})
	
	# Debris sparks
	for i in range(12):
		var angle = randf() * TAU
		var speed = randf_range(40, 80)
		debris.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"a": 1.0,
			"size": randf_range(1.5, 3)
		})
	
	impact.set_meta("rings", rings)
	impact.set_meta("particles", particles)
	impact.set_meta("debris", debris)
	impact.set_meta("color", color)
	impact.set_meta("flash", 1.0)
	
	impact.draw.connect(func():
		var r_arr = impact.get_meta("rings") as Array
		var p_arr = impact.get_meta("particles") as Array
		var d_arr = impact.get_meta("debris") as Array
		var c = impact.get_meta("color") as Color
		var flash = impact.get_meta("flash") as float
		
		# Center flash burst
		if flash > 0:
			var flash_color = Color.WHITE
			flash_color.a = flash
			impact.draw_circle(Vector2.ZERO, 25 * flash, flash_color)
			var inner_flash = c.lightened(0.6)
			inner_flash.a = flash * 0.8
			impact.draw_circle(Vector2.ZERO, 15 * flash, inner_flash)
		
		# Draw rings with gradient
		for ring in r_arr:
			if ring.a > 0:
				# Outer glow
				var glow_c = c
				glow_c.a = ring.a * 0.3
				impact.draw_arc(Vector2.ZERO, ring.r + 5, 0, TAU, 48, glow_c, ring.width + 4)
				# Main ring
				var ring_c = c.lightened(0.2)
				ring_c.a = ring.a
				impact.draw_arc(Vector2.ZERO, ring.r, 0, TAU, 48, ring_c, ring.width)
				# Inner bright edge
				var inner_c = Color.WHITE
				inner_c.a = ring.a * 0.6
				impact.draw_arc(Vector2.ZERO, ring.r - 2, 0, TAU, 48, inner_c, 1.5)
		
		# Draw burst particles
		for p in p_arr:
			if p.a > 0:
				var p_c = c.lightened(0.4)
				p_c.a = p.a
				impact.draw_circle(p.pos, p.size, p_c)
				# Particle glow
				var glow = c
				glow.a = p.a * 0.4
				impact.draw_circle(p.pos, p.size * 1.8, glow)
		
		# Draw debris
		for d in d_arr:
			if d.a > 0:
				var d_c = Color.WHITE
				d_c.a = d.a
				impact.draw_circle(d.pos, d.size, d_c)
	)
	
	var tween = create_tween()
	tween.tween_method(func(t: float):
		# Update flash
		impact.set_meta("flash", max(0, 1.0 - t * 4))
		
		# Update rings
		for i in range(rings.size()):
			var progress = max(0, t - rings[i].delay)
			rings[i].r = 5 + progress * 120 * (1.0 - i * 0.15)
			rings[i].a = max(0, 1.0 - progress * 1.8)
		
		# Update particles
		for p in particles:
			p.pos += p.vel * 0.016
			p.vel *= 0.94
			p.a = max(0, p.a - 0.016 * p.decay)
		
		# Update debris
		for d in debris:
			d.pos += d.vel * 0.016
			d.vel *= 0.92
			d.a = max(0, d.a - 0.025)
		
		impact.set_meta("rings", rings)
		impact.set_meta("particles", particles)
		impact.set_meta("debris", debris)
		impact.queue_redraw()
	, 0.0, 1.0, 0.5)
	tween.tween_callback(func(): impact.queue_free())

func spawn_screen_flash(color: Color, duration: float = 0.15) -> void:
	var flash = ColorRect.new()
	flash.color = Color(color.r, color.g, color.b, 0.25)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, duration)
	tween.tween_callback(func(): flash.queue_free())

func spawn_slash_effect(pos: Vector2, color: Color) -> void:
	var slash = Node2D.new()
	slash.position = pos + Vector2(0, -30)
	slash.z_index = 100
	add_child(slash)
	
	var sparks = []
	for i in range(8):
		var angle = randf_range(-PI/4, PI/4)
		sparks.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(60, 120),
			"a": 1.0,
			"size": randf_range(2, 5)
		})
	
	slash.set_meta("angle", -PI/2.5)
	slash.set_meta("length", 0.0)
	slash.set_meta("color", color)
	slash.set_meta("sparks", sparks)
	slash.set_meta("time", 0.0)
	slash.set_meta("trails", [])
	
	slash.draw.connect(func():
		var a = slash.get_meta("angle") as float
		var l = slash.get_meta("length") as float
		var c = slash.get_meta("color") as Color
		var sp = slash.get_meta("sparks") as Array
		var time = slash.get_meta("time") as float
		var trails = slash.get_meta("trails") as Array
		
		# Draw trail afterimages
		for i in range(trails.size()):
			var trail = trails[i]
			var trail_alpha = float(i) / trails.size() * 0.4
			var trail_start = Vector2(cos(trail.a), sin(trail.a)) * -trail.l * 0.5
			var trail_end = Vector2(cos(trail.a), sin(trail.a)) * trail.l * 0.5
			var trail_c = c
			trail_c.a = trail_alpha
			slash.draw_line(trail_start, trail_end, trail_c, 6)
		
		if l > 0:
			var start = Vector2(cos(a), sin(a)) * -l * 0.5
			var end = Vector2(cos(a), sin(a)) * l * 0.5
			
			# Outer glow
			var glow_c = c
			glow_c.a = 0.3
			slash.draw_line(start * 1.1, end * 1.1, glow_c, 16)
			
			# Main blade
			slash.draw_line(start, end, c, 10)
			slash.draw_line(start, end, c.lightened(0.4), 6)
			
			# Bright core
			slash.draw_line(start * 0.8, end * 0.8, Color.WHITE, 3)
			
			# Arc sweep effect
			var arc_c = c.lightened(0.2)
			arc_c.a = 0.6
			slash.draw_arc(Vector2.ZERO, l * 0.4, a - PI/6, a + PI/6, 12, arc_c, 3)
		
		# Draw sparks
		for s in sp:
			if s.a > 0:
				var s_c = Color.WHITE
				s_c.a = s.a
				slash.draw_circle(s.pos, s.size, s_c)
				var glow = c
				glow.a = s.a * 0.5
				slash.draw_circle(s.pos, s.size * 2, glow)
	)
	
	spawn_screen_flash(color, 0.1)
	
	var tween = create_tween()
	tween.tween_method(func(t: float):
		var new_angle = -PI/2.5 + t * PI/1.2
		var new_length = sin(t * PI) * 100
		
		# Store trail
		var trails = slash.get_meta("trails") as Array
		if new_length > 10:
			trails.append({"a": slash.get_meta("angle"), "l": slash.get_meta("length")})
			if trails.size() > 6:
				trails.pop_front()
		slash.set_meta("trails", trails)
		
		slash.set_meta("angle", new_angle)
		slash.set_meta("length", new_length)
		slash.set_meta("time", t)
		
		# Update sparks
		var sp = slash.get_meta("sparks") as Array
		for s in sp:
			s.pos += s.vel * 0.016
			s.a -= 0.04
		slash.set_meta("sparks", sp)
		
		slash.queue_redraw()
	, 0.0, 1.0, 0.25)
	tween.tween_callback(func(): slash.queue_free())

func spawn_pull_effect(from: Vector2, to: Vector2, color: Color) -> void:
	# Energy beam connecting target to caster
	var beam = Node2D.new()
	beam.z_index = 99
	add_child(beam)
	
	beam.set_meta("from", from)
	beam.set_meta("to", to)
	beam.set_meta("color", color)
	beam.set_meta("time", 0.0)
	beam.set_meta("alpha", 1.0)
	
	beam.draw.connect(func():
		var f = beam.get_meta("from") as Vector2
		var t = beam.get_meta("to") as Vector2
		var c = beam.get_meta("color") as Color
		var time = beam.get_meta("time") as float
		var alpha = beam.get_meta("alpha") as float
		
		# Outer glow
		var glow = c
		glow.a = alpha * 0.3
		beam.draw_line(f, t, glow, 12)
		
		# Main beam with pulse
		var pulse = 0.7 + sin(time * 30) * 0.3
		var main_c = c
		main_c.a = alpha * pulse
		beam.draw_line(f, t, main_c, 5)
		
		# Core
		var core = Color.WHITE
		core.a = alpha * 0.8
		beam.draw_line(f, t, core, 2)
	)
	
	var beam_tween = create_tween()
	beam_tween.tween_method(func(t: float):
		beam.set_meta("time", t)
		beam.set_meta("alpha", 1.0 - t)
		beam.queue_redraw()
	, 0.0, 1.0, 0.35)
	beam_tween.tween_callback(func(): beam.queue_free())
	
	# Swirling particles being pulled
	for i in range(12):
		var particle = Node2D.new()
		var offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		particle.position = from + offset
		particle.z_index = 100
		add_child(particle)
		
		var p_size = randf_range(4, 8)
		particle.set_meta("size", p_size)
		particle.set_meta("color", color)
		particle.set_meta("orbit", randf() * TAU)
		
		particle.draw.connect(func():
			var sz = particle.get_meta("size") as float
			var c = particle.get_meta("color") as Color
			# Glow
			var glow = c
			glow.a = 0.4
			particle.draw_circle(Vector2.ZERO, sz * 1.8, glow)
			# Core
			particle.draw_circle(Vector2.ZERO, sz, c.lightened(0.3))
			particle.draw_circle(Vector2.ZERO, sz * 0.5, Color.WHITE)
		)
		particle.queue_redraw()
		
		var tween = create_tween()
		# Spiral toward caster
		tween.tween_method(func(t: float):
			var orbit = particle.get_meta("orbit") as float
			var spiral_offset = Vector2(cos(orbit + t * 6), sin(orbit + t * 6)) * (1.0 - t) * 20
			particle.position = from.lerp(to, t) + spiral_offset
			particle.modulate.a = 1.0 - t * 0.7
			particle.set_meta("size", p_size * (1.0 - t * 0.5))
			particle.queue_redraw()
		, 0.0, 1.0, 0.35).set_delay(i * 0.02).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): particle.queue_free())

func spawn_lock_effect(pos: Vector2, color: Color) -> void:
	var lock = Node2D.new()
	lock.position = pos + Vector2(0, -35)
	lock.z_index = 100
	add_child(lock)
	
	lock.set_meta("color", color)
	lock.set_meta("size", 0.0)
	lock.set_meta("rotation", 0.0)
	lock.set_meta("pulse", 0.0)
	
	lock.draw.connect(func():
		var c = lock.get_meta("color") as Color
		var s = lock.get_meta("size") as float
		var rot = lock.get_meta("rotation") as float
		var pulse = lock.get_meta("pulse") as float
		
		if s > 0:
			# Gravity well effect (concentric circles)
			for i in range(4):
				var ring_r = 45 * s - i * 8 * s
				if ring_r > 0:
					var ring_c = c
					ring_c.a = 0.15 + i * 0.05
					lock.draw_arc(Vector2.ZERO, ring_r, 0, TAU, 32, ring_c, 2)
			
			# Rotating chain links with glow
			for i in range(10):
				var angle = rot + (TAU / 10) * i
				var r = 35 * s
				var chain_pos = Vector2(cos(angle), sin(angle)) * r
				# Glow
				var glow = c
				glow.a = 0.4
				lock.draw_circle(chain_pos, 9 * s, glow)
				# Chain link
				lock.draw_circle(chain_pos, 5 * s, c.lightened(0.2))
				lock.draw_circle(chain_pos, 3 * s, Color.WHITE)
			
			# Center lock body with pulse
			var pulse_scale = 1.0 + sin(pulse) * 0.1
			var body_s = s * pulse_scale
			
			# Lock body glow
			var body_glow = c
			body_glow.a = 0.3
			lock.draw_rect(Rect2(-14 * body_s, -6 * body_s, 28 * body_s, 20 * body_s), body_glow, true)
			
			# Lock body
			lock.draw_rect(Rect2(-12 * body_s, -5 * body_s, 24 * body_s, 18 * body_s), c, true)
			lock.draw_rect(Rect2(-10 * body_s, -3 * body_s, 20 * body_s, 14 * body_s), c.lightened(0.3), true)
			
			# Lock shackle (arc)
			lock.draw_arc(Vector2(0, -5 * body_s), 10 * body_s, PI, TAU, 16, c, 5 * body_s)
			lock.draw_arc(Vector2(0, -5 * body_s), 8 * body_s, PI, TAU, 16, c.lightened(0.4), 3 * body_s)
			
			# Keyhole
			lock.draw_circle(Vector2(0, 4 * body_s), 3 * body_s, c.darkened(0.5))
	)
	
	spawn_screen_flash(color, 0.12)
	
	var tween = create_tween()
	tween.tween_method(func(t: float):
		lock.set_meta("size", t)
		lock.set_meta("rotation", t * TAU * 0.5)
		lock.set_meta("pulse", t * 20)
		lock.queue_redraw()
	, 0.0, 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.25)
	tween.tween_property(lock, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): lock.queue_free())

func spawn_dash_effect(from: Vector2, to: Vector2, color: Color) -> void:
	var dir = (to - from).normalized()
	var dist = from.distance_to(to)
	
	# Afterimage trail
	for i in range(5):
		var ghost = Node2D.new()
		ghost.position = from.lerp(to, float(i) / 5.0)
		ghost.z_index = 99
		ghost.modulate = color
		ghost.modulate.a = 0.6 - i * 0.1
		add_child(ghost)
		
		ghost.set_meta("size", 20.0)
		ghost.draw.connect(func():
			var sz = ghost.get_meta("size") as float
			ghost.draw_circle(Vector2.ZERO, sz, Color(1, 1, 1, 0.3))
		)
		ghost.queue_redraw()
		
		var ghost_tween = create_tween()
		ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.3).set_delay(i * 0.03)
		ghost_tween.tween_callback(func(): ghost.queue_free())
	
	# Main dash streak
	var dash = Node2D.new()
	dash.position = from
	dash.z_index = 100
	dash.rotation = dir.angle()
	add_child(dash)
	
	dash.set_meta("color", color)
	dash.set_meta("length", 0.0)
	dash.set_meta("width", 1.0)
	
	dash.draw.connect(func():
		var c = dash.get_meta("color") as Color
		var l = dash.get_meta("length") as float
		var w = dash.get_meta("width") as float
		
		if l > 0:
			# Outer glow
			var glow = c
			glow.a = 0.3
			dash.draw_line(Vector2.ZERO, Vector2(l, 0), glow, 16 * w)
			
			# Speed lines
			for i in range(3):
				var offset = (i - 1) * 8 * w
				var line_c = c.lightened(0.2)
				line_c.a = 0.7
				dash.draw_line(Vector2(0, offset), Vector2(l * 0.8, offset), line_c, 2)
			
			# Main trail
			dash.draw_line(Vector2.ZERO, Vector2(l, 0), c, 8 * w)
			dash.draw_line(Vector2.ZERO, Vector2(l, 0), c.lightened(0.5), 4 * w)
			
			# Bright core
			dash.draw_line(Vector2(l * 0.2, 0), Vector2(l, 0), Color.WHITE, 2 * w)
	)
	
	var tween = create_tween()
	tween.tween_method(func(t: float):
		dash.set_meta("length", dist * min(t * 1.5, 1.0))
		dash.set_meta("width", 1.0 - t * 0.5)
		dash.position = from.lerp(to, t * 0.6)
		dash.modulate.a = 1.0 - t * 0.6
		dash.queue_redraw()
	, 0.0, 1.0, 0.18)
	tween.tween_property(dash, "modulate:a", 0.0, 0.08)
	tween.tween_callback(func(): dash.queue_free())
	
	# Impact burst at destination
	await get_tree().create_timer(0.12).timeout
	spawn_impact_effect(to, color)

func spawn_shockwave_effect(pos: Vector2, color: Color) -> void:
	spawn_screen_flash(color, 0.12)
	
	# Ground impact marker
	var ground = Node2D.new()
	ground.position = pos
	ground.z_index = 98
	add_child(ground)
	
	ground.set_meta("size", 0.0)
	ground.set_meta("color", color)
	
	ground.draw.connect(func():
		var s = ground.get_meta("size") as float
		var c = ground.get_meta("color") as Color
		# Crater effect
		var crater_c = c.darkened(0.3)
		crater_c.a = 0.5 * (1.0 - s)
		ground.draw_circle(Vector2.ZERO, 40 * s, crater_c)
	)
	
	var ground_tween = create_tween()
	ground_tween.tween_method(func(t: float):
		ground.set_meta("size", t)
		ground.queue_redraw()
	, 0.0, 1.0, 0.4)
	ground_tween.tween_callback(func(): ground.queue_free())
	
	# Multiple expanding waves
	for w in range(3):
		var wave = Node2D.new()
		wave.position = pos + Vector2(0, -15)
		wave.z_index = 100 + w
		add_child(wave)
		
		wave.set_meta("color", color)
		wave.set_meta("radius", 0.0)
		wave.set_meta("alpha", 1.0)
		
		wave.draw.connect(func():
			var c = wave.get_meta("color") as Color
			var r = wave.get_meta("radius") as float
			var a = wave.get_meta("alpha") as float
			
			if r > 0:
				# Outer glow
				var glow = c
				glow.a = a * 0.25
				wave.draw_arc(Vector2.ZERO, r + 8, 0, TAU, 48, glow, 12)
				
				# Main wave
				var main_c = c.lightened(0.2)
				main_c.a = a * 0.9
				wave.draw_arc(Vector2.ZERO, r, 0, TAU, 48, main_c, 7 - w * 2)
				
				# Inner bright edge
				var inner = Color.WHITE
				inner.a = a * 0.6
				wave.draw_arc(Vector2.ZERO, r * 0.95, 0, TAU, 48, inner, 2)
		)
		
		var wave_tween = create_tween()
		wave_tween.tween_method(func(t: float):
			wave.set_meta("radius", t * (100 + w * 20))
			wave.set_meta("alpha", 1.0 - t)
			wave.queue_redraw()
		, 0.0, 1.0, 0.35).set_delay(w * 0.05).set_ease(Tween.EASE_OUT)
		wave_tween.tween_callback(func(): wave.queue_free())
	
	# Debris particles
	for i in range(16):
		var debris = Node2D.new()
		debris.position = pos
		debris.z_index = 101
		add_child(debris)
		
		var angle = randf() * TAU
		var speed = randf_range(80, 180)
		var d_size = randf_range(3, 7)
		
		debris.set_meta("vel", Vector2(cos(angle), sin(angle)) * speed)
		debris.set_meta("size", d_size)
		debris.set_meta("color", color)
		
		debris.draw.connect(func():
			var sz = debris.get_meta("size") as float
			var c = debris.get_meta("color") as Color
			debris.draw_circle(Vector2.ZERO, sz, c.lightened(0.3))
			debris.draw_circle(Vector2.ZERO, sz * 0.5, Color.WHITE)
		)
		debris.queue_redraw()
		
		var debris_tween = create_tween()
		debris_tween.tween_method(func(t: float):
			var vel = debris.get_meta("vel") as Vector2
			debris.position += vel * 0.016
			debris.set_meta("vel", vel * 0.94)
			debris.modulate.a = 1.0 - t
			debris.set_meta("size", d_size * (1.0 - t * 0.5))
			debris.queue_redraw()
		, 0.0, 1.0, 0.45).set_delay(randf() * 0.05)
		debris_tween.tween_callback(func(): debris.queue_free())

func spawn_buff_effect(pos: Vector2, color: Color) -> void:
	spawn_screen_flash(color, 0.1)
	
	# Aura ring expanding
	var aura = Node2D.new()
	aura.position = pos + Vector2(0, -30)
	aura.z_index = 99
	add_child(aura)
	
	aura.set_meta("size", 0.0)
	aura.set_meta("color", color)
	
	aura.draw.connect(func():
		var s = aura.get_meta("size") as float
		var c = aura.get_meta("color") as Color
		if s > 0:
			# Outer glow
			var glow = c
			glow.a = 0.2 * (1.0 - s * 0.5)
			aura.draw_arc(Vector2.ZERO, 50 * s, 0, TAU, 48, glow, 15)
			# Main ring
			var ring = c.lightened(0.3)
			ring.a = 0.6 * (1.0 - s * 0.5)
			aura.draw_arc(Vector2.ZERO, 40 * s, 0, TAU, 48, ring, 4)
	)
	
	var aura_tween = create_tween()
	aura_tween.tween_method(func(t: float):
		aura.set_meta("size", t)
		aura.queue_redraw()
	, 0.0, 1.0, 0.5)
	aura_tween.tween_callback(func(): aura.queue_free())
	
	# Rising spiral particles
	for i in range(16):
		var particle = Node2D.new()
		var angle = (TAU / 16) * i
		particle.position = pos + Vector2(cos(angle), sin(angle)) * 35
		particle.z_index = 100
		add_child(particle)
		
		var p_size = randf_range(4, 8)
		particle.set_meta("size", p_size)
		particle.set_meta("color", color)
		particle.set_meta("angle", angle)
		
		particle.draw.connect(func():
			var sz = particle.get_meta("size") as float
			var c = particle.get_meta("color") as Color
			# Glow
			var glow = c
			glow.a = 0.4
			particle.draw_circle(Vector2.ZERO, sz * 2, glow)
			# Core
			particle.draw_circle(Vector2.ZERO, sz, c.lightened(0.4))
			particle.draw_circle(Vector2.ZERO, sz * 0.4, Color.WHITE)
		)
		particle.queue_redraw()
		
		var tween = create_tween()
		tween.tween_method(func(t: float):
			var a = particle.get_meta("angle") as float
			# Spiral upward motion
			var spiral_r = 35 * (1.0 - t * 0.8)
			var spiral_a = a + t * TAU * 1.5
			var base_pos = pos + Vector2(0, -80 * t)
			particle.position = base_pos + Vector2(cos(spiral_a), sin(spiral_a)) * spiral_r
			particle.modulate.a = 1.0 - t
			particle.set_meta("size", p_size * (1.0 - t * 0.6))
			particle.queue_redraw()
		, 0.0, 1.0, 0.6).set_delay(i * 0.025).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func(): particle.queue_free())

func spawn_aoe_cross(pos: Vector2, color: Color) -> void:
	spawn_screen_flash(color, 0.1)
	
	var cross = Node2D.new()
	cross.position = pos
	cross.z_index = 100
	add_child(cross)
	
	cross.set_meta("color", color)
	cross.set_meta("length", 0.0)
	cross.set_meta("pulse", 0.0)
	
	cross.draw.connect(func():
		var c = cross.get_meta("color") as Color
		var l = cross.get_meta("length") as float
		var pulse = cross.get_meta("pulse") as float
		
		if l > 0:
			var pulse_width = 1.0 + sin(pulse * 15) * 0.2
			var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
			
			for dir in directions:
				# Outer glow
				var glow = c
				glow.a = 0.25
				cross.draw_line(Vector2.ZERO, dir * l * 1.1, glow, 16 * pulse_width)
				
				# Main beam
				cross.draw_line(Vector2.ZERO, dir * l, c, 8 * pulse_width)
				cross.draw_line(Vector2.ZERO, dir * l, c.lightened(0.4), 4 * pulse_width)
				
				# Core
				cross.draw_line(Vector2.ZERO, dir * l * 0.9, Color.WHITE, 2)
				
				# Endpoint glow
				var end_glow = c.lightened(0.3)
				end_glow.a = 0.6
				cross.draw_circle(dir * l, 12 * pulse_width, end_glow)
				cross.draw_circle(dir * l, 6 * pulse_width, Color.WHITE)
			
			# Center burst
			var center_c = Color.WHITE
			center_c.a = 0.8 * (1.0 - l / 120.0)
			cross.draw_circle(Vector2.ZERO, 15 * pulse_width, center_c)
	)
	
	var tween = create_tween()
	tween.tween_method(func(t: float):
		cross.set_meta("length", t * 110)
		cross.set_meta("pulse", t)
		cross.modulate.a = 1.0 - t * 0.4
		cross.queue_redraw()
	, 0.0, 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(cross, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): cross.queue_free())
	
	# Endpoint impacts (delayed)
	await get_tree().create_timer(0.15).timeout
	var tile_size = 64  # Approximate tile spacing
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var impact_pos = pos + dir * tile_size
		spawn_small_impact(impact_pos, color)

func spawn_small_impact(pos: Vector2, color: Color) -> void:
	var impact = Node2D.new()
	impact.position = pos
	impact.z_index = 99
	add_child(impact)
	
	impact.set_meta("size", 0.0)
	impact.set_meta("color", color)
	
	impact.draw.connect(func():
		var s = impact.get_meta("size") as float
		var c = impact.get_meta("color") as Color
		if s > 0:
			var ring_c = c
			ring_c.a = 1.0 - s
			impact.draw_arc(Vector2.ZERO, 25 * s, 0, TAU, 24, ring_c, 3)
			var center = Color.WHITE
			center.a = (1.0 - s) * 0.6
			impact.draw_circle(Vector2.ZERO, 10 * (1.0 - s * 0.5), center)
	)
	
	var tween = create_tween()
	tween.tween_method(func(t: float):
		impact.set_meta("size", t)
		impact.queue_redraw()
	, 0.0, 1.0, 0.25)
	tween.tween_callback(func(): impact.queue_free())

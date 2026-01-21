extends Node2D

var grass_texture = preload("res://assets/grass_texture.tres")

# State from Main
var game_state: Dictionary
var legal_moves: Array = []
var valid_targets: Array = []
var selected_spell_id = null
var range_zone_tiles: Array = []
var blocked_tiles: Array = []  # Tiles in range but blocked by LOS
var hovered_tile = null

func _ready():
	# Initial draw
	queue_redraw()

func update_visuals(state: Dictionary, moves: Array, targets: Array, spell_id, zone: Array, hover, blocked: Array = []) -> void:
	game_state = state
	legal_moves = moves
	valid_targets = targets
	selected_spell_id = spell_id
	range_zone_tiles = zone
	hovered_tile = hover
	blocked_tiles = blocked
	queue_redraw()

func _draw():
	if not game_state: return
	
	for row in range(Data.BOARD.rows):
		for col in range(Data.BOARD.cols):
			var fill_color = Color("#87CEEB")  # Sky blue base tiles
			var stroke_color = Color("#555555")
			var line_width = 1.0
			
			var is_move = false
			for m in legal_moves: if m.to.x == col and m.to.y == row: is_move = true
			
			var is_target = false
			for t in valid_targets: if t.x == col and t.y == row: is_target = true
			
			var is_blocked = false
			for t in blocked_tiles: if t.x == col and t.y == row: is_blocked = true
			
			if Data.is_obstacle(col, row):
				draw_obstacle(col, row)
				continue
			
			if game_state.winner == null:
				if selected_spell_id:
					if is_target: fill_color = Color("#c0c0c0")  # Light gray for clickable tiles (has LOS)
					elif is_blocked: fill_color = Color("#505050")  # Dark gray for blocked tiles (no LOS)
				else:
					if is_move: fill_color = Color("#1f4e1f")
			
			draw_tile(col, row, fill_color, stroke_color, line_width)
			
			# Overlays (Stroke/Highlight)
			if game_state.winner == null:
				if selected_spell_id:
					# No yellow border for targets - just keep the fill colors
					if is_blocked:
						# Dark overlay for blocked cells
						draw_tile(col, row, Color(0, 0, 0, 0.2), null)
				else:
					if is_move: draw_tile(col, row, null, Color("#22c55e"), 2.0)

	# Hover effect
	if hovered_tile and game_state.winner == null:
		var x = hovered_tile.x
		var y = hovered_tile.y
		var is_valid = false
		
		if selected_spell_id:
			for t in valid_targets: if t.x == x and t.y == y: is_valid = true
		else:
			for m in legal_moves: if m.to.x == x and m.to.y == y: is_valid = true
			
		if is_valid:
			draw_tile(x, y, null, Color.WHITE, 2.0)
			draw_tile(x, y, Color(1, 1, 1, 0.2), null)
		else:
			draw_tile(x, y, null, Color("#ef4444"), 2.0)

func draw_obstacle(col, row):
	# Draw a "block" - just a raised tile looking thing or dark color
	var poly = Iso.get_tile_polygon(col, row)
	# Simple extrude visual: draw a darker face slightly higher?
	# For simplicity, just draw a dark gray block
	draw_colored_polygon(poly, Color("#444444"))
	draw_polyline(poly, Color("#000000"), 2.0)

func draw_tile(col, row, fill_color, stroke_color, width=1.0, texture=null):
	var poly = Iso.get_tile_polygon(col, row)
	if fill_color:
		if texture:
			var uvs = PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)])
			draw_polygon(poly, PackedColorArray([fill_color]), uvs, texture)
		else:
			draw_colored_polygon(poly, fill_color)
	if stroke_color:
		# Godot 4 draw_polyline needs closed loop
		var pts = Array(poly)
		pts.append(poly[0])
		draw_polyline(PackedVector2Array(pts), stroke_color, width)

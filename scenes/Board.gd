extends Node2D

# State from Main
var game_state: Dictionary
var legal_moves: Array = []
var valid_targets: Array = []
var selected_spell_id = null
var range_zone_tiles: Array = []
var blocked_tiles: Array = []
var aoe_preview_tiles: Array = []
var path_preview_tiles: Array = []
var hovered_tile = null

# Animation timing
var animation_time: float = 0.0

# Premium color palette
const GRASS_LIGHT = Color(0.28, 0.52, 0.32, 1.0)
const GRASS_DARK = Color(0.22, 0.42, 0.25, 1.0)
const GRASS_EDGE = Color(0.18, 0.35, 0.20, 1.0)
const OBSTACLE_LIGHT = Color(0.40, 0.38, 0.45, 1.0)
const OBSTACLE_DARK = Color(0.32, 0.30, 0.38, 1.0)
const OBSTACLE_EDGE = Color(0.25, 0.24, 0.30, 1.0)

# State colors
const MOVE_COLOR = Color(0.2, 0.6, 1.0, 0.5)
const MOVE_EDGE = Color(0.3, 0.7, 1.0, 0.9)
const SPELL_COLOR = Color(1.0, 0.85, 0.3, 0.45)
const SPELL_EDGE = Color(1.0, 0.9, 0.4, 0.9)
const BLOCKED_TINT = Color(0.15, 0.15, 0.18, 0.7)
const AOE_COLOR = Color(1.0, 0.45, 0.15, 0.5)
const AOE_EDGE = Color(1.0, 0.5, 0.1, 0.9)
const PATH_COLOR = Color(0.25, 1.0, 0.65, 0.55)
const PATH_EDGE = Color(0.3, 1.0, 0.7, 1.0)
const HOVER_EDGE = Color(1.0, 1.0, 1.0, 1.0)

func _ready():
	queue_redraw()

func _process(delta):
	animation_time += delta
	queue_redraw()

func update_visuals(state: Dictionary, moves: Array, targets: Array, spell_id, zone: Array, hover, blocked: Array = [], aoe_preview: Array = [], path_preview: Array = []) -> void:
	game_state = state
	legal_moves = moves
	valid_targets = targets
	selected_spell_id = spell_id
	range_zone_tiles = zone
	hovered_tile = hover
	blocked_tiles = blocked
	aoe_preview_tiles = aoe_preview
	path_preview_tiles = path_preview
	queue_redraw()

func refresh_layout():
	queue_redraw()

func _draw():
	if not game_state:
		return
	
	var t = animation_time
	
	for row in range(Data.BOARD.rows):
		for col in range(Data.BOARD.cols):
			var is_obstacle = Data.is_obstacle(col, row)
			var is_alt = (col + row) % 2 == 1
			
			# Determine tile states
			var is_move = _is_in_moves(col, row)
			var is_target = _is_in_targets(col, row)
			var is_blocked = _is_in_blocked(col, row)
			var is_hover = hovered_tile and hovered_tile.x == col and hovered_tile.y == row
			var is_aoe = _is_in_aoe(col, row)
			var is_path = _is_in_path(col, row)
			
			# Draw the tile
			if is_obstacle:
				_draw_obstacle_tile(col, row, is_alt, t)
			else:
				_draw_grass_tile(col, row, is_alt, t)
			
			# Apply state overlays
			if game_state.winner == null:
				if is_blocked:
					_draw_blocked_overlay(col, row, t)
				elif selected_spell_id:
					if is_target:
						_draw_spell_range_overlay(col, row, t)
				else:
					if is_move:
						_draw_move_range_overlay(col, row, t)
				
				# AOE preview (on top of range)
				if is_aoe and not is_obstacle:
					_draw_aoe_overlay(col, row, t)
				
				# Path preview
				if is_path and not is_obstacle:
					_draw_path_overlay(col, row, t)
				
				# Hover effect (on top of everything)
				if is_hover:
					var is_valid = (selected_spell_id and is_target) or (not selected_spell_id and is_move)
					_draw_hover_overlay(col, row, t, is_valid)

func _draw_grass_tile(col: int, row: int, is_alt: bool, t: float):
	var poly = Iso.get_tile_polygon(col, row)
	var center = Iso.grid_to_screen(col, row)
	
	# Animated wave for grass variation
	var wave = sin(col * 0.8 + row * 0.6 + t * 1.5) * 0.5 + 0.5
	
	# Base color with wave-based variation
	var base_color = GRASS_LIGHT if is_alt else GRASS_DARK
	var varied_color = base_color.lerp(GRASS_LIGHT if not is_alt else GRASS_DARK, wave * 0.3)
	
	# Add subtle brightness animation
	var brightness = sin(col * 1.2 + row * 0.9 + t * 2.0) * 0.03 + 1.0
	varied_color = varied_color * brightness
	
	# Draw filled tile
	draw_colored_polygon(poly, varied_color)
	
	# Draw premium edge (darker stroke for depth)
	var stroke_color = GRASS_EDGE.lerp(base_color, 0.3)
	var stroke_width = max(1.5 * Iso.get_tile_scale(), 1.0)
	_draw_tile_stroke(poly, stroke_color, stroke_width)

func _draw_obstacle_tile(col: int, row: int, is_alt: bool, t: float):
	var poly = Iso.get_tile_polygon(col, row)
	
	# Subtle shimmer animation
	var shimmer = sin(col * 2.0 + row * 1.5 + t * 0.8) * 0.03 + 1.0
	
	var base_color = OBSTACLE_LIGHT if is_alt else OBSTACLE_DARK
	var shimmer_color = base_color * shimmer
	
	draw_colored_polygon(poly, shimmer_color)
	
	# Draw beveled look with inner highlight
	_draw_obstacle_relief(col, row, shimmer_color)
	
	# Edge stroke
	var stroke_width = max(1.5 * Iso.get_tile_scale(), 1.0)
	_draw_tile_stroke(poly, OBSTACLE_EDGE, stroke_width)

func _draw_obstacle_relief(col: int, row: int, base_color: Color):
	var poly = Iso.get_tile_polygon(col, row)
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	for p in poly:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
	
	var width = max_x - min_x
	var height = max_y - min_y
	if width <= 0.0 or height <= 0.0:
		return
	
	var scale = max(Iso.get_tile_scale(), 0.75)
	var inset = 4.0 * scale
	var max_inset = min(width, height) * 0.35
	inset = clamp(inset, 2.0, max_inset)
	
	var inner = PackedVector2Array([
		Vector2(min_x + inset, min_y + inset),
		Vector2(max_x - inset, min_y + inset),
		Vector2(max_x - inset, max_y - inset),
		Vector2(min_x + inset, max_y - inset)
	])
	
	var top_face = base_color.lightened(0.12)
	var highlight = base_color.lightened(0.25)
	var shadow = base_color.darkened(0.25)
	var edge_width = 2.0 * scale
	
	draw_colored_polygon(inner, top_face)
	draw_line(Vector2(min_x, min_y), Vector2(max_x, min_y), highlight, edge_width)
	draw_line(Vector2(min_x, min_y), Vector2(min_x, max_y), highlight, edge_width)
	draw_line(Vector2(min_x, max_y), Vector2(max_x, max_y), shadow, edge_width)
	draw_line(Vector2(max_x, min_y), Vector2(max_x, max_y), shadow, edge_width)

func _draw_move_range_overlay(col: int, row: int, t: float):
	var poly = Iso.get_tile_polygon(col, row)
	
	# Animated pulse
	var pulse = sin(t * 2.5) * 0.15 + 0.85
	var animated_color = MOVE_COLOR
	animated_color.a *= pulse
	
	draw_colored_polygon(poly, animated_color)
	
	# Glowing edge
	var stroke_width = max(2.5 * Iso.get_tile_scale(), 2.0)
	var edge_color = MOVE_EDGE
	edge_color.a *= pulse
	_draw_tile_stroke(poly, edge_color, stroke_width)

func _draw_spell_range_overlay(col: int, row: int, t: float):
	var poly = Iso.get_tile_polygon(col, row)
	
	# Animated pulse (slightly different timing)
	var pulse = sin(t * 3.0) * 0.12 + 0.88
	var animated_color = SPELL_COLOR
	animated_color.a *= pulse
	
	draw_colored_polygon(poly, animated_color)
	
	# Golden glowing edge
	var stroke_width = max(2.5 * Iso.get_tile_scale(), 2.0)
	var edge_color = SPELL_EDGE
	edge_color.a *= pulse
	_draw_tile_stroke(poly, edge_color, stroke_width)

func _draw_blocked_overlay(col: int, row: int, t: float):
	var poly = Iso.get_tile_polygon(col, row)
	
	# Dark pulsing overlay
	var pulse = sin(t * 2.0) * 0.08 + 0.92
	var block_color = BLOCKED_TINT
	block_color.a *= pulse
	
	draw_colored_polygon(poly, block_color)

func _draw_aoe_overlay(col: int, row: int, t: float):
	var poly = Iso.get_tile_polygon(col, row)
	
	# Fiery pulse
	var pulse = sin(t * 4.0) * 0.2 + 0.8
	var animated_color = AOE_COLOR
	animated_color.a *= pulse
	
	draw_colored_polygon(poly, animated_color)
	
	# Hot edge
	var stroke_width = max(2.5 * Iso.get_tile_scale(), 2.0)
	var edge_color = AOE_EDGE
	edge_color.a *= pulse
	_draw_tile_stroke(poly, edge_color, stroke_width)

func _draw_path_overlay(col: int, row: int, t: float):
	var poly = Iso.get_tile_polygon(col, row)
	
	# Flowing animation
	var flow = sin(col * 2.0 + row * 2.0 - t * 4.0) * 0.2 + 0.8
	var animated_color = PATH_COLOR
	animated_color.a *= flow
	
	draw_colored_polygon(poly, animated_color)
	
	var stroke_width = max(3.0 * Iso.get_tile_scale(), 2.0)
	var edge_color = PATH_EDGE
	edge_color.a *= flow
	_draw_tile_stroke(poly, edge_color, stroke_width)

func _draw_hover_overlay(col: int, row: int, t: float, is_valid: bool):
	var poly = Iso.get_tile_polygon(col, row)
	
	var pulse = sin(t * 4.0) * 0.15 + 0.85
	var stroke_width = max(3.0 * Iso.get_tile_scale(), 2.0)
	
	if is_valid:
		# White glowing edge for valid target
		var hover_color = HOVER_EDGE
		hover_color.a *= pulse
		_draw_tile_stroke(poly, hover_color, stroke_width)
		
		# Subtle inner brightening
		var fill = Color(1.0, 1.0, 1.0, 0.15 * pulse)
		draw_colored_polygon(poly, fill)
	else:
		# Red edge for invalid
		var invalid_color = Color(1.0, 0.3, 0.3, 0.8 * pulse)
		_draw_tile_stroke(poly, invalid_color, stroke_width)

func _draw_tile_stroke(poly: PackedVector2Array, color: Color, width: float):
	var pts = Array(poly)
	pts.append(poly[0])
	draw_polyline(PackedVector2Array(pts), color, width)

# Helper functions
func _is_in_moves(col: int, row: int) -> bool:
	for m in legal_moves:
		if m.to.x == col and m.to.y == row:
			return true
	return false

func _is_in_targets(col: int, row: int) -> bool:
	for t in valid_targets:
		if t.x == col and t.y == row:
			return true
	return false

func _is_in_blocked(col: int, row: int) -> bool:
	for t in blocked_tiles:
		if t.x == col and t.y == row:
			return true
	return false

func _is_in_aoe(col: int, row: int) -> bool:
	for t in aoe_preview_tiles:
		if t.x == col and t.y == row:
			return true
	return false

func _is_in_path(col: int, row: int) -> bool:
	for t in path_preview_tiles:
		if t.x == col and t.y == row:
			return true
	return false

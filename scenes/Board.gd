extends Node2D

var grass_texture = preload("res://assets/tile_grass.png")
var stone_texture = preload("res://assets/tile_stone.png")

# State from Main
var game_state: Dictionary
var legal_moves: Array = []
var valid_targets: Array = []
var selected_spell_id = null
var range_zone_tiles: Array = []
var blocked_tiles: Array = []  # Tiles in range but blocked by LOS
var aoe_preview_tiles: Array = []  # Tiles that will be affected by spell
var path_preview_tiles: Array = []  # Tiles showing movement path
var hovered_tile = null

func _ready():
	# Initial draw
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

func _draw():
	if not game_state: return
	
	for row in range(Data.BOARD.rows):
		for col in range(Data.BOARD.cols):
			var is_move = false
			for m in legal_moves: if m.to.x == col and m.to.y == row: is_move = true
			
			var is_target = false
			for t in valid_targets: if t.x == col and t.y == row: is_target = true
			
			var is_blocked = false
			for t in blocked_tiles: if t.x == col and t.y == row: is_blocked = true
			
			# Draw Base
			if Data.is_obstacle(col, row):
				draw_tile(col, row, Color(0.3, 0.3, 0.35, 1.0), Color(0.2, 0.2, 0.25, 1.0), 1.0)
				continue
			else:
				draw_tile(col, row, Color(0.5, 0.5, 0.55, 1.0), Color(0.3, 0.3, 0.35, 1.0), 1.0)
			
			# Overlays
			if game_state.winner == null:
				if selected_spell_id:
					if is_target:
						# Targetable: Light overlay
						draw_tile(col, row, Color(1, 1, 1, 0.4), null)
					elif is_blocked:
						# Blocked: Dark overlay
						draw_tile(col, row, Color(0, 0, 0, 0.5), null)
					elif is_in_zone(col, row):
						# In zone but not valid target: Subtle hint?
						pass
				else:
					if is_move:
						# Move: Blue overlay (high visibility against green grass)
						draw_tile(col, row, Color(0.3, 0.7, 1.0, 0.4), Color(0.3, 0.7, 1.0, 0.9), 2.0)

	# Hover effect
	if hovered_tile and game_state.winner == null:
		var x = hovered_tile.x
		var y = hovered_tile.y
		var is_valid = false
		
		# Only draw hover if in bounds
		if Rules.in_bounds(x, y):
			if selected_spell_id:
				for t in valid_targets: if t.x == x and t.y == y: is_valid = true
			else:
				for m in legal_moves: if m.to.x == x and m.to.y == y: is_valid = true
			
			if is_valid:
				draw_tile(x, y, Color(1, 1, 1, 0.2), Color.WHITE, 2.0)
			else:
				draw_tile(x, y, null, Color(1, 0, 0, 0.5), 2.0)
	
	# AOE Preview overlay - show affected tiles with orange highlight
	if aoe_preview_tiles.size() > 0 and game_state.winner == null:
		for tile in aoe_preview_tiles:
			if Rules.in_bounds(tile.x, tile.y) and not Data.is_obstacle(tile.x, tile.y):
				# Orange semi-transparent fill for affected area
				draw_tile(tile.x, tile.y, Color(1.0, 0.6, 0.1, 0.4), Color(1.0, 0.5, 0.0, 0.9), 2.0)
	
	# Movement path preview - show path tiles with green/cyan highlight
	if path_preview_tiles.size() > 0 and game_state.winner == null:
		for tile in path_preview_tiles:
			if Rules.in_bounds(tile.x, tile.y) and not Data.is_obstacle(tile.x, tile.y):
				# Bright cyan/green line for path
				draw_tile(tile.x, tile.y, Color(0.2, 1.0, 0.6, 0.5), Color(0.2, 1.0, 0.6, 1.0), 3.0)

func is_in_zone(col, row):
	for z in range_zone_tiles:
		if z.x == col and z.y == row: return true
	return false

func draw_iso_sprite(col, row, texture: Texture2D):
	if not texture: return
	
	var center = Iso.grid_to_screen(col, row)
	
	# The grid_to_screen gives the CENTER of the top diamond.
	# The sprite has a top face and a side face.
	# We want the center of the top face in the sprite to align with 'center'.
	# Since these generated assets are roughly isometric cubes, the 'center' of the top face
	# is usually about 1/4th down the image height (or half the top diamond height).
	# However, simpler alignment: align the horizontal center, and offset Y slightly up.
	
	# Simple centering (Naive):
	# var pos = center - texture.get_size() / 2
	
	# Adjusted for "Floor":
	# We want the tile to "sit" on the grid.
	# If the image is 96px wide, and the grid cell is 96px wide.
	# The texture should be drawn centered horizontally.
	# Vertically: The 'center' is the middle of the flat tile.
	# The image includes the thickness going DOWN.
	# So we roughly want to align the top part of the image with the center.
	# Let's try centering it at (center.x, center.y + offset).
	
	# A standard iso tile 96x48 (diamond) plus thickness of say 32px. Total H = 80.
	# The center of the diamond is at y=24 (relative to top of image).
	# grid_to_screen returns that point.
	# So we draw the image at:
	# x = center.x - (texture.width / 2)
	# y = center.y - (texture.height / 2) ... wait.
	# If relative y=24 is the center.
	# draw_pos.y = center.y - 24.
	
	# Let's assume the "optical center" of the top surface is roughly 25-30% from the top.
	# For now, let's center it and shift up by 1/4 height to account for thickness below.
	
	var tex_w = texture.get_width()
	var tex_h = texture.get_height()
	
	var offset_y = -tex_h * 0.3 # Shift up to align 3D block's top face with the grid center
	
	var pos = center - Vector2(tex_w/2.0, tex_h/2.0)
	pos.y += offset_y
	
	draw_texture(texture, pos)

func draw_tile(col, row, fill_color, stroke_color, width=1.0):
	var poly = Iso.get_tile_polygon(col, row)
	var stroke_width = width * max(Iso.get_tile_scale(), 0.75)
	
	if fill_color:
		draw_colored_polygon(poly, fill_color)
		
	if stroke_color:
		# Godot 4 draw_polyline needs closed loop
		var pts = Array(poly)
		pts.append(poly[0])
		draw_polyline(PackedVector2Array(pts), stroke_color, stroke_width)


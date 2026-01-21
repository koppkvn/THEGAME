class_name Iso

const TILE_W = 96
const TILE_H = 48
const HALF_W = TILE_W / 2
const HALF_H = TILE_H / 2


# Origin will be set by the main controller based on screen size
static var origin_x = 0
static var origin_y = 0

static func compute_origin(canvas_w: float, canvas_h: float, rows: int, cols: int) -> void:
	# Calculate bounding box of the grid
	var corners = [
		Vector2(0, 0),
		Vector2(cols - 1, 0),
		Vector2(0, rows - 1),
		Vector2(cols - 1, rows - 1)
	]
	
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	
	for p in corners:
		var rx = (p.x - p.y) * HALF_W
		var ry = (p.x + p.y) * HALF_H
		if rx < min_x: min_x = rx
		if rx > max_x: max_x = rx
		if ry < min_y: min_y = ry
		if ry > max_y: max_y = ry
	
	var box_w = max_x - min_x
	var box_h = max_y - min_y
	
	var center_rel_x = (min_x + max_x) / 2
	var center_rel_y = (min_y + max_y) / 2
	
	origin_x = canvas_w * 0.5 - center_rel_x
	origin_y = canvas_h * 0.35 - center_rel_y

static func grid_to_screen(col: int, row: int) -> Vector2:
	var x = origin_x + (col - row) * HALF_W
	var y = origin_y + (col + row) * HALF_H
	return Vector2(x, y)

static func get_tile_polygon(col: int, row: int) -> PackedVector2Array:
	var c = grid_to_screen(col, row)
	return PackedVector2Array([
		Vector2(c.x, c.y - HALF_H), # Top
		Vector2(c.x + HALF_W, c.y), # Right
		Vector2(c.x, c.y + HALF_H), # Bottom
		Vector2(c.x - HALF_W, c.y)  # Left
	])

static func pixel_to_grid(px: float, py: float) -> Vector2i:
	# Reverse projection
	# x_screen = origin_x + (col - row) * half_w
	# y_screen = origin_y + (col + row) * half_h
	# let dx = (px - origin_x) / half_w = col - row
	# let dy = (py - origin_y) / half_h = col + row
	# col = (dx + dy) / 2
	# row = (dy - dx) / 2
	
	var dx = (px - origin_x) / HALF_W
	var dy = (py - origin_y) / HALF_H
	
	var col = round((dx + dy) / 2.0)
	var row = round((dy - dx) / 2.0)
	
	return Vector2i(int(col), int(row))

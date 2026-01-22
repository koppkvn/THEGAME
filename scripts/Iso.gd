class_name Iso

const BASE_TILE_W = 96.0
const BASE_TILE_H = 48.0

static var tile_scale: float = 1.0
static var tile_w: float = BASE_TILE_W
static var tile_h: float = BASE_TILE_H
static var half_w: float = BASE_TILE_W / 2.0
static var half_h: float = BASE_TILE_H / 2.0


# Origin will be set by the main controller based on screen size
static var origin_x = 0
static var origin_y = 0

static func set_tile_scale(scale: float) -> void:
	tile_scale = clamp(scale, 0.6, 2.5)
	tile_w = BASE_TILE_W * tile_scale
	tile_h = BASE_TILE_H * tile_scale
	half_w = tile_w / 2.0
	half_h = tile_h / 2.0

static func get_tile_scale() -> float:
	return tile_scale

static func get_board_size(rows: int, cols: int, tile_width: float, tile_height: float) -> Vector2:
	var half_width = tile_width / 2.0
	var half_height = tile_height / 2.0
	var span = (rows + cols - 2)
	return Vector2(span * half_width + tile_width, span * half_height + tile_height)

static func compute_origin(canvas_w: float, canvas_h: float, rows: int, cols: int) -> void:
	compute_origin_in_rect(Rect2(Vector2.ZERO, Vector2(canvas_w, canvas_h)), rows, cols)

static func compute_origin_in_rect(bounds: Rect2, rows: int, cols: int) -> void:
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
		var rx = (p.x - p.y) * half_w
		var ry = (p.x + p.y) * half_h
		if rx < min_x: min_x = rx
		if rx > max_x: max_x = rx
		if ry < min_y: min_y = ry
		if ry > max_y: max_y = ry
	
	var box_w = max_x - min_x
	var box_h = max_y - min_y
	
	var center_rel_x = (min_x + max_x) / 2
	var center_rel_y = (min_y + max_y) / 2
	
	var center = bounds.position + bounds.size * 0.5
	origin_x = center.x - center_rel_x
	origin_y = center.y - center_rel_y

static func grid_to_screen(col: int, row: int) -> Vector2:
	var x = origin_x + (col - row) * half_w
	var y = origin_y + (col + row) * half_h
	return Vector2(x, y)

static func get_tile_polygon(col: int, row: int) -> PackedVector2Array:
	var c = grid_to_screen(col, row)
	return PackedVector2Array([
		Vector2(c.x, c.y - half_h), # Top
		Vector2(c.x + half_w, c.y), # Right
		Vector2(c.x, c.y + half_h), # Bottom
		Vector2(c.x - half_w, c.y)  # Left
	])

static func pixel_to_grid(px: float, py: float) -> Vector2i:
	# Reverse projection
	# x_screen = origin_x + (col - row) * half_w
	# y_screen = origin_y + (col + row) * half_h
	# let dx = (px - origin_x) / half_w = col - row
	# let dy = (py - origin_y) / half_h = col + row
	# col = (dx + dy) / 2
	# row = (dy - dx) / 2
	
	var dx = (px - origin_x) / half_w
	var dy = (py - origin_y) / half_h
	
	var col = round((dx + dy) / 2.0)
	var row = round((dy - dx) / 2.0)
	
	return Vector2i(int(col), int(row))

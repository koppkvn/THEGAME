class_name Iso

const BASE_TILE_W = 96.0
const BASE_TILE_H = 96.0

static var tile_scale: float = 1.0
static var tilt_y_scale: float = 0.85
static var tile_w: float = BASE_TILE_W
static var tile_h: float = BASE_TILE_H * tilt_y_scale
static var half_w: float = BASE_TILE_W / 2.0
static var half_h: float = (BASE_TILE_H * tilt_y_scale) / 2.0


# Origin will be set by the main controller based on screen size
static var origin_x = 0
static var origin_y = 0

static func _recompute_metrics() -> void:
	tile_w = BASE_TILE_W * tile_scale
	tile_h = BASE_TILE_H * tile_scale * tilt_y_scale
	half_w = tile_w / 2.0
	half_h = tile_h / 2.0

static func set_tile_scale(scale: float) -> void:
	tile_scale = clamp(scale, 0.6, 2.5)
	_recompute_metrics()

static func set_tilt_y_scale(scale: float) -> void:
	tilt_y_scale = clamp(scale, 0.6, 1.0)
	_recompute_metrics()

static func get_tile_scale() -> float:
	return tile_scale

static func get_tilt_y_scale() -> float:
	return tilt_y_scale

static func get_board_size(rows: int, cols: int, tile_width: float, tile_height: float) -> Vector2:
	return Vector2(cols * tile_width, rows * tile_height)

static func get_base_board_size(rows: int, cols: int) -> Vector2:
	return get_board_size(rows, cols, BASE_TILE_W, BASE_TILE_H * tilt_y_scale)

static func compute_origin(canvas_w: float, canvas_h: float, rows: int, cols: int) -> void:
	compute_origin_in_rect(Rect2(Vector2.ZERO, Vector2(canvas_w, canvas_h)), rows, cols)

static func compute_origin_in_rect(bounds: Rect2, rows: int, cols: int) -> void:
	var board_size = get_board_size(rows, cols, tile_w, tile_h)
	var center = bounds.position + bounds.size * 0.5
	origin_x = center.x - (board_size.x * 0.5)
	origin_y = center.y - (board_size.y * 0.5)

static func grid_to_screen(col: int, row: int) -> Vector2:
	var x = origin_x + col * tile_w + half_w
	var y = origin_y + row * tile_h + half_h
	return Vector2(x, y)

static func get_tile_polygon(col: int, row: int) -> PackedVector2Array:
	var c = grid_to_screen(col, row)
	return PackedVector2Array([
		Vector2(c.x - half_w, c.y - half_h),
		Vector2(c.x + half_w, c.y - half_h),
		Vector2(c.x + half_w, c.y + half_h),
		Vector2(c.x - half_w, c.y + half_h)
	])

static func pixel_to_grid(px: float, py: float) -> Vector2i:
	var local_x = (px - origin_x) / tile_w
	var local_y = (py - origin_y) / tile_h
	var col = floor(local_x)
	var row = floor(local_y)
	return Vector2i(int(col), int(row))

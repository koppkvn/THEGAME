extends Node2D
@export var cols: int = 9
@export var rows: int = 9

@export var tile_w: float = 96.0
@export var tile_h: float = 48.0

var origin := Vector2.ZERO
var picked := Vector2i(-1, -1)
var click_pos := Vector2.INF

func _ready() -> void:
	_update_origin()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		return


func _update_origin() -> void:
	# Center board inside BoardContainer.
	var container := get_parent() as Control
	if container == null:
		return
	var size := container.size

	# Board extents in screen space for iso grid:
	# Width ≈ (cols + rows) * tile_w/2
	# Height ≈ (cols + rows) * tile_h/2
	var board_w := (cols + rows) * (tile_w * 0.5)
	var board_h := (cols + rows) * (tile_h * 0.5)

	origin = Vector2(
		size.x * 0.5,
		size.y * 0.5 - board_h * 0.15
	)

func grid_to_screen(x: int, y: int) -> Vector2:
	# Standard diamond iso
	return origin + Vector2(
		(x - y) * (tile_w * 0.5),
		(x + y) * (tile_h * 0.5)
	)

func get_tile_poly(x: int, y: int) -> PackedVector2Array:
	var c := grid_to_screen(x, y)
	return PackedVector2Array([
		Vector2(c.x, c.y - tile_h * 0.5),
		Vector2(c.x + tile_w * 0.5, c.y),
		Vector2(c.x, c.y + tile_h * 0.5),
		Vector2(c.x - tile_w * 0.5, c.y)
	])

func point_in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
	# Ray casting (works for convex quads)
	var inside := false
	var j := poly.size() - 1
	for i in range(poly.size()):
		var pi := poly[i]
		var pj := poly[j]
		var intersect := ((pi.y > p.y) != (pj.y > p.y)) and \
			(p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y + 0.0000001) + pi.x)
		if intersect:
			inside = !inside
		j = i
	return inside

func pick_tile(p: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1e18

	for y in range(rows):
		for x in range(cols):
			var poly := get_tile_poly(x, y)
			if point_in_poly(p, poly):
				var c := grid_to_screen(x, y)
				var d := c.distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = Vector2i(x, y)

	return best

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var container := get_parent() as Control
		var local_p := container.get_local_mouse_position()
		click_pos = local_p
		picked = pick_tile(local_p)
		queue_redraw()

	if event is InputEventScreenTouch and event.pressed:
		var container := get_parent() as Control
		var local_p := container.get_local_mouse_position()
		click_pos = local_p
		picked = pick_tile(local_p)
		queue_redraw()

func _draw() -> void:
	# Draw tiles
	for y in range(rows):
		for x in range(cols):
			var poly := get_tile_poly(x, y)
			draw_colored_polygon(poly, Color(0.17, 0.17, 0.17, 1.0))
			draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.25, 0.25, 0.25, 1.0), 2.0)

	# Debug: picked tile outline + label
	if picked.x >= 0:
		var ppoly := get_tile_poly(picked.x, picked.y)
		draw_polyline(ppoly + PackedVector2Array([ppoly[0]]), Color(0.2, 0.8, 1.0, 1.0), 3.0)
		draw_string(get_theme_default_font(), grid_to_screen(picked.x, picked.y) + Vector2(0, -20),
			"(%d,%d)" % [picked.x, picked.y], HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.WHITE)

	# Debug: click dot
	if click_pos != Vector2.INF:
		draw_circle(click_pos, 5.0, Color.WHITE)

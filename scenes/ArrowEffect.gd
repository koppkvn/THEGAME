extends Node2D

var target_pos: Vector2
var color: Color
var callback: Callable
var trail_points: Array = []
var speed: float = 800.0

func init(to: Vector2, c: Color, on_complete: Callable = Callable()):
	target_pos = to
	color = c
	callback = on_complete

func _ready():
	# Start moving toward target
	var dir = (target_pos - position).normalized()
	var distance = position.distance_to(target_pos)
	var duration = distance / speed
	
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_hit)

func _process(_delta):
	# Add current position to trail
	trail_points.append(position)
	if trail_points.size() > 10:
		trail_points.pop_front()
	queue_redraw()

func _draw():
	# Draw trail
	if trail_points.size() > 1:
		for i in range(trail_points.size() - 1):
			var alpha = float(i) / trail_points.size()
			var local_from = trail_points[i] - position
			var local_to = trail_points[i + 1] - position
			var trail_color = color
			trail_color.a = alpha * 0.6
			draw_line(local_from, local_to, trail_color, 3.0 * alpha)
	
	# Draw arrow head
	var dir = Vector2.RIGHT
	if trail_points.size() > 1:
		dir = (position - trail_points[-2]).normalized()
	
	# Arrow body (line)
	draw_line(Vector2.ZERO, -dir * 20, color, 3.0)
	
	# Arrow head (triangle)
	var perp = dir.rotated(PI/2)
	var head_points = PackedVector2Array([
		Vector2.ZERO,
		-dir * 8 + perp * 5,
		-dir * 8 - perp * 5
	])
	draw_colored_polygon(head_points, color.lightened(0.3))
	
	# Glow
	draw_circle(Vector2.ZERO, 6, Color(color.r, color.g, color.b, 0.3))

func _on_hit():
	# Create impact effect
	var impact = Node2D.new()
	impact.position = position
	get_parent().add_child(impact)
	impact.set_script(load("res://scenes/ImpactEffect.gd"))
	impact.init(color)
	
	if callback.is_valid():
		callback.call()
	
	queue_free()

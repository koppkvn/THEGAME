extends Node2D

var unit_data: Dictionary

func set_unit(data: Dictionary):
	unit_data = data
	# Position update
	var screen_pos = Iso.grid_to_screen(data.x, data.y)
	position = screen_pos
	queue_redraw()

func _draw():
	if not unit_data: return
	
	var radius = 14.0
	var height = 36.0
	
	# Shadow
	draw_circle(Vector2(0, 0), radius, Color(0, 0, 0, 0.4))
	
	# Body Color
	var color = Color("#3b82f6") if unit_data.id == "P1" else Color("#ef4444")
	var lighter = color.lightened(0.2)
	
	# Cylinder body (Rectangle)
	var rect = Rect2(-radius, -height, radius * 2, height)
	draw_rect(rect, color, true)
	
	# Top Cap
	draw_set_transform(Vector2(0, -height), 0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, radius, lighter)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color, 1.0) # Stroke
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1)) # Reset
	
	# Bottom arc stroke
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
	draw_arc(Vector2.ZERO, radius, 0, PI, 16, color, 1.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
	
	# Text Label
	var font = SystemFont.new()
	var font_size = 13
	draw_string(font, Vector2(-radius, -height - 6), unit_data.id, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size)
	
	# Guard Icon
	if unit_data.status.get("guard"):
		draw_string(font, Vector2(10, -height/2), "🛡️", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GOLD)

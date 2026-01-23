extends Node2D

var unit_data: Dictionary

func set_unit(data: Dictionary):
	unit_data = data
	position = Iso.grid_to_screen(data.x, data.y)
	queue_redraw()

func _draw():
	if not unit_data:
		return
	
	var char_class = unit_data.get("character_class", "RANGER")
	var is_p1 = unit_data.id == "P1"
	
	# Color schemes
	var primary: Color
	var secondary: Color
	var dark: Color
	var skin = Color("#e0ac69")
	
	if char_class == "MELEE":
		if is_p1:
			primary = Color("#1e40af")    # Deep blue
			secondary = Color("#3b82f6")  # Light blue
			dark = Color("#1e3a5f")
		else:
			primary = Color("#7c3aed")    # Purple
			secondary = Color("#a78bfa")
			dark = Color("#4c1d95")
	else:
		if is_p1:
			primary = Color("#b91c1c")    # Deep red
			secondary = Color("#ef4444")
			dark = Color("#7f1d1d")
		else:
			primary = Color("#c2410c")    # Orange
			secondary = Color("#f97316")
			dark = Color("#7c2d12")
	
	# === SHADOW ===
	draw_set_transform(Vector2(0, 3), 0, Vector2(1.2, 0.4))
	draw_circle(Vector2.ZERO, 18, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# === LEGS ===
	draw_rect(Rect2(-9, -12, 6, 14), dark, true)
	draw_rect(Rect2(3, -12, 6, 14), dark, true)
	# Boots
	draw_rect(Rect2(-10, -4, 8, 6), Color("#1f2937"), true)
	draw_rect(Rect2(2, -4, 8, 6), Color("#1f2937"), true)
	
	# === BODY/TORSO ===
	# Main body shape (trapezoid-ish)
	var body_points = PackedVector2Array([
		Vector2(-14, -14), Vector2(14, -14),
		Vector2(16, -45), Vector2(-16, -45)
	])
	draw_colored_polygon(body_points, primary)
	
	# Chest plate / armor detail
	var chest_points = PackedVector2Array([
		Vector2(-10, -18), Vector2(10, -18),
		Vector2(8, -40), Vector2(-8, -40)
	])
	draw_colored_polygon(chest_points, secondary)
	
	# Belt
	draw_rect(Rect2(-15, -18, 30, 5), dark, true)
	draw_rect(Rect2(-3, -19, 6, 7), Color("#fbbf24"), true)  # Belt buckle
	
	# === ARMS ===
	# Left arm
	draw_rect(Rect2(-22, -44, 8, 26), primary, true)
	draw_rect(Rect2(-23, -20, 10, 8), skin, true)  # Hand
	# Right arm
	draw_rect(Rect2(14, -44, 8, 26), primary, true)
	draw_rect(Rect2(13, -20, 10, 8), skin, true)  # Hand
	
	# === CLASS SPECIFIC ===
	if char_class == "MELEE":
		# Shoulder pads (larger)
		draw_circle(Vector2(-18, -42), 10, secondary)
		draw_circle(Vector2(18, -42), 10, secondary)
		draw_arc(Vector2(-18, -42), 10, 0, TAU, 16, dark, 2)
		draw_arc(Vector2(18, -42), 10, 0, TAU, 16, dark, 2)
		
		# Sword on side
		draw_rect(Rect2(20, -50, 4, 35), Color("#6b7280"), true)
		draw_rect(Rect2(18, -52, 8, 5), Color("#78716c"), true)  # Hilt
		draw_rect(Rect2(20, -50, 4, 35), Color("#9ca3af"), false, 1)
	else:
		# Cape
		var cape = PackedVector2Array([
			Vector2(-12, -44), Vector2(12, -44),
			Vector2(18, -8), Vector2(-18, -8)
		])
		draw_colored_polygon(cape, dark)
		
		# Bow on back
		draw_arc(Vector2(-8, -35), 20, PI*0.3, PI*0.7, 12, Color("#92400e"), 4)
		draw_line(Vector2(-8, -55), Vector2(-8, -15), Color("#fef3c7"), 1)
		
		# Quiver
		draw_rect(Rect2(14, -48, 8, 28), Color("#78350f"), true)
	
	# === HEAD ===
	var head_y = -58.0
	# Face
	draw_circle(Vector2(0, head_y), 13, skin)
	
	if char_class == "MELEE":
		# Helmet
		draw_arc(Vector2(0, head_y), 14, PI, TAU, 16, secondary, 8)
		draw_arc(Vector2(0, head_y + 2), 12, 0, PI, 16, dark, 4)  # Visor
		# Helmet crest
		var crest = PackedVector2Array([
			Vector2(-4, head_y - 12), Vector2(4, head_y - 12),
			Vector2(2, head_y - 24), Vector2(-2, head_y - 24)
		])
		draw_colored_polygon(crest, secondary)
	else:
		# Hood
		draw_arc(Vector2(0, head_y), 16, PI*0.65, PI*2.35, 20, primary, 8)
		# Hair visible under hood
		draw_arc(Vector2(0, head_y - 5), 10, PI*0.8, PI*2.2, 12, Color("#78350f"), 4)
	
	# Eyes
	draw_circle(Vector2(-4, head_y - 2), 2.5, Color.WHITE)
	draw_circle(Vector2(4, head_y - 2), 2.5, Color.WHITE)
	draw_circle(Vector2(-4, head_y - 2), 1.2, Color("#1f2937"))
	draw_circle(Vector2(4, head_y - 2), 1.2, Color("#1f2937"))
	
	# === LABEL ===
	var font = ThemeDB.fallback_font
	var text = unit_data.id
	var text_color = Color("#60a5fa") if is_p1 else Color("#a78bfa")
	draw_string_outline(font, Vector2(-12, head_y - 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	draw_string(font, Vector2(-12, head_y - 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)
	
	# Status icons
	var icons = ""
	if unit_data.status.get("damage_reduction"): icons += "🛡"
	if unit_data.status.get("gravity_lock"): icons += "⚓"
	if unit_data.status.get("was_displaced"): icons += "💨"
	if icons != "":
		draw_string(font, Vector2(-15, head_y - 44), icons, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

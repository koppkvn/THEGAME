extends Node2D

var unit_data: Dictionary

# Animation state
var attack_anim_progress: float = 0.0
var is_attacking: bool = false
var attack_target_dir: Vector2 = Vector2.RIGHT

func _ready():
	# For characters with continuous animations (like Mage floating)
	set_process(true)

func _process(_delta):
	# Persistent animations
	if unit_data and unit_data.get("character_class") == "MAGE":
		queue_redraw()

func set_unit(data: Dictionary):
	unit_data = data
	position = Iso.grid_to_screen(data.x, data.y)
	queue_redraw()

func play_attack_animation(target_pos: Vector2) -> void:
	attack_target_dir = (target_pos - position).normalized()
	is_attacking = true
	attack_anim_progress = 0.0
	
	var tween = create_tween()
	tween.tween_method(func(t: float):
		attack_anim_progress = t
		queue_redraw()
	, 0.0, 1.0, 0.35)
	tween.tween_callback(func():
		is_attacking = false
		attack_anim_progress = 0.0
		queue_redraw()
	)

func _draw():
	if not unit_data:
		return
	
	var char_class = unit_data.get("character_class", "RANGER")
	var is_p1 = unit_data.id == "P1"
	
	if char_class == "MELEE":
		_draw_melee_character(is_p1)
	elif char_class == "MAGE":
		_draw_mage_character(is_p1)
	else:
		_draw_ranger_character(is_p1)
	
	# === PLAYER LABEL ===
	var font = ThemeDB.fallback_font
	var text = unit_data.id
	var text_color = Color("#60a5fa") if is_p1 else Color("#f472b6")
	draw_string_outline(font, Vector2(-12, -88), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	draw_string(font, Vector2(-12, -88), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)
	
	# Status icons
	var icons = ""
	if unit_data.status.get("damage_reduction"): icons += "🛡"
	if unit_data.status.get("gravity_lock"): icons += "⚓"
	if unit_data.status.get("was_displaced"): icons += "💨"
	if unit_data.status.get("damage_boost"): icons += "⚔"
	if icons != "":
		draw_string(font, Vector2(-15, -100), icons, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

# Animation helper - bow draw curve (0 to 1, peaks at 0.3, holds, then releases)
func _get_bow_draw_amount() -> float:
	if not is_attacking:
		return 0.0
	if attack_anim_progress < 0.3:
		return attack_anim_progress / 0.3  # Draw bow
	elif attack_anim_progress < 0.5:
		return 1.0  # Hold
	else:
		return max(0.0, 1.0 - (attack_anim_progress - 0.5) / 0.2)  # Release

# Animation helper - sword swing (0 to 1)
func _get_sword_swing_angle() -> float:
	if not is_attacking:
		return 0.0
	# Windup then swing
	if attack_anim_progress < 0.25:
		return -attack_anim_progress / 0.25 * 0.4  # Windup back
	elif attack_anim_progress < 0.5:
		var t = (attack_anim_progress - 0.25) / 0.25
		return -0.4 + t * 1.8  # Swing forward
	else:
		var t = (attack_anim_progress - 0.5) / 0.5
		return 1.4 - t * 1.4  # Return to rest

# =============================================================================
# RANGER CHARACTER - Hooded archer with bow and quiver
# =============================================================================
func _draw_ranger_character(is_p1: bool):
	# Color palette
	var cloak_primary = Color("#1e3a5f") if is_p1 else Color("#4a1942")
	var cloak_secondary = Color("#2563eb") if is_p1 else Color("#7c3aed")
	var leather = Color("#78350f")
	var leather_light = Color("#a16207")
	var metal = Color("#6b7280")
	var metal_shine = Color("#9ca3af")
	var skin = Color("#e0ac69")
	var skin_shadow = Color("#c68642")
	var hair = Color("#451a03")
	var cloth = Color("#374151")
	
	# Animation values
	var bow_draw = _get_bow_draw_amount()
	var facing_right = attack_target_dir.x >= 0 if is_attacking else true
	var arm_pull_offset = bow_draw * 12  # How far back the arm pulls
	
	# === SHADOW ===
	draw_set_transform(Vector2(0, 5), 0, Vector2(1.3, 0.35))
	draw_circle(Vector2.ZERO, 22, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# === CAPE/CLOAK (behind) ===
	var cape_points = PackedVector2Array([
		Vector2(-16, -48), Vector2(16, -48),
		Vector2(22, -6), Vector2(14, 0), Vector2(-14, 0), Vector2(-22, -6)
	])
	draw_colored_polygon(cape_points, cloak_primary)
	var cape_fold = PackedVector2Array([
		Vector2(-10, -45), Vector2(10, -45),
		Vector2(14, -10), Vector2(-14, -10)
	])
	draw_colored_polygon(cape_fold, cloak_primary.darkened(0.2))
	
	# === QUIVER (on back) ===
	draw_rect(Rect2(10, -55, 10, 35), leather, true)
	draw_rect(Rect2(10, -55, 10, 35), leather.darkened(0.3), false, 2)
	draw_line(Vector2(15, -55), Vector2(-8, -35), leather_light, 3)
	for i in range(4):
		var ax = 12 + i * 2
		draw_line(Vector2(ax, -58), Vector2(ax, -48), Color("#4b5563"), 2)
		draw_line(Vector2(ax - 1, -57), Vector2(ax, -54), cloak_secondary, 1)
		draw_line(Vector2(ax + 1, -57), Vector2(ax, -54), cloak_secondary, 1)
	
	# === LEGS ===
	draw_rect(Rect2(-10, -18, 8, 20), cloth, true)
	draw_rect(Rect2(-10, -18, 8, 20), cloth.darkened(0.2), false, 1)
	draw_rect(Rect2(2, -18, 8, 20), cloth, true)
	draw_rect(Rect2(2, -18, 8, 20), cloth.darkened(0.2), false, 1)
	
	# === BOOTS ===
	var boot_l = PackedVector2Array([
		Vector2(-12, -2), Vector2(-2, -2), Vector2(-1, 4), Vector2(-14, 4), Vector2(-14, 0)
	])
	draw_colored_polygon(boot_l, leather)
	draw_polyline(boot_l, leather.darkened(0.3), 2)
	draw_rect(Rect2(-10, -1, 6, 3), metal, true)
	
	var boot_r = PackedVector2Array([
		Vector2(2, -2), Vector2(12, -2), Vector2(14, 0), Vector2(14, 4), Vector2(1, 4)
	])
	draw_colored_polygon(boot_r, leather)
	draw_polyline(boot_r, leather.darkened(0.3), 2)
	draw_rect(Rect2(4, -1, 6, 3), metal, true)
	
	# === TORSO ===
	var torso = PackedVector2Array([
		Vector2(-14, -20), Vector2(14, -20),
		Vector2(16, -50), Vector2(-16, -50)
	])
	draw_colored_polygon(torso, cloak_secondary)
	
	var vest = PackedVector2Array([
		Vector2(-11, -22), Vector2(11, -22),
		Vector2(10, -48), Vector2(-10, -48)
	])
	draw_colored_polygon(vest, leather)
	for i in range(5):
		var y = -26 - i * 5
		draw_line(Vector2(-2, y), Vector2(2, y), leather_light, 1)
	
	draw_rect(Rect2(-15, -23, 30, 5), leather.darkened(0.2), true)
	draw_rect(Rect2(-4, -24, 8, 7), metal, true)
	draw_rect(Rect2(-3, -23, 6, 5), metal_shine, true)
	
	# === BOW ARM (Left - holds bow forward) ===
	var bow_arm_rotation = 0.0
	var bow_arm_x = -22
	if is_attacking:
		bow_arm_rotation = -0.3 - bow_draw * 0.2  # Tilt forward when drawing
		bow_arm_x = -24 - bow_draw * 4  # Extend forward
	
	# Left arm
	draw_set_transform(Vector2(bow_arm_x + 8, -44), bow_arm_rotation, Vector2.ONE)
	draw_rect(Rect2(-4, 0, 9, 28), cloak_secondary, true)
	draw_rect(Rect2(-4, 0, 9, 28), cloak_primary, false, 1)
	draw_rect(Rect2(-5, 14, 11, 10), leather, true)
	draw_rect(Rect2(-5, 16, 11, 2), metal, true)
	draw_circle(Vector2(1, 26), 5, skin)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# === DRAWING ARM (Right - pulls string) ===
	var draw_arm_x = 13 + arm_pull_offset
	var draw_arm_rotation = bow_draw * 0.4  # Elbow bends back
	
	draw_set_transform(Vector2(draw_arm_x, -44), draw_arm_rotation, Vector2.ONE)
	draw_rect(Rect2(0, 0, 9, 28), cloak_secondary, true)
	draw_rect(Rect2(0, 0, 9, 28), cloak_primary, false, 1)
	draw_rect(Rect2(-1, 14, 11, 10), leather, true)
	draw_rect(Rect2(-1, 16, 11, 2), metal, true)
	draw_circle(Vector2(4, 26), 5, skin)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# === BOW ===
	var bow_center_x = bow_arm_x - 8
	var bow_y = -35
	var bow_bend = 22 - bow_draw * 6  # Bow bends more when drawn
	
	# Bow limbs
	draw_arc(Vector2(bow_center_x, bow_y), bow_bend, PI * 0.35, PI * 0.65, 16, leather, 4)
	draw_arc(Vector2(bow_center_x, bow_y), bow_bend - 2, PI * 0.37, PI * 0.63, 14, leather_light, 2)
	
	# Bowstring - curves back when drawn
	var string_pull = bow_draw * 15
	var string_top = Vector2(bow_center_x, bow_y - bow_bend + 2)
	var string_bottom = Vector2(bow_center_x, bow_y + bow_bend - 2)
	var string_mid = Vector2(bow_center_x + string_pull, bow_y)
	
	# Draw string as two lines meeting at pulled point
	draw_line(string_top, string_mid, Color("#fef3c7"), 1)
	draw_line(string_mid, string_bottom, Color("#fef3c7"), 1)
	
	# Arrow (visible when drawing)
	if bow_draw > 0.1:
		var arrow_x = bow_center_x + string_pull - 5
		draw_line(Vector2(arrow_x, bow_y), Vector2(arrow_x - 35, bow_y), Color("#4b5563"), 2)
		# Arrowhead
		draw_line(Vector2(arrow_x - 35, bow_y), Vector2(arrow_x - 32, bow_y - 3), metal, 2)
		draw_line(Vector2(arrow_x - 35, bow_y), Vector2(arrow_x - 32, bow_y + 3), metal, 2)
		# Fletching
		draw_line(Vector2(arrow_x - 2, bow_y - 3), Vector2(arrow_x, bow_y), cloak_secondary, 1)
		draw_line(Vector2(arrow_x - 2, bow_y + 3), Vector2(arrow_x, bow_y), cloak_secondary, 1)
	
	# Grip
	draw_rect(Rect2(bow_center_x - 2, bow_y - 4, 5, 8), leather.darkened(0.2), true)
	
	# === HEAD ===
	var head_y = -62.0
	var head_tilt = bow_draw * 0.15  # Slight head tilt when aiming
	
	draw_rect(Rect2(-4, -52, 8, 6), skin, true)
	
	draw_set_transform(Vector2(0, head_y), -head_tilt, Vector2.ONE)
	draw_circle(Vector2.ZERO, 12, skin)
	
	# Hood
	var hood_outer = PackedVector2Array([
		Vector2(-16, 5), Vector2(16, 5),
		Vector2(18, -8), Vector2(12, -18),
		Vector2(0, -22), Vector2(-12, -18), Vector2(-18, -8)
	])
	draw_colored_polygon(hood_outer, cloak_primary)
	draw_arc(Vector2.ZERO, 14, PI * 0.7, PI * 2.3, 20, cloak_primary.darkened(0.3), 6)
	draw_arc(Vector2(0, -4), 9, PI * 0.85, PI * 2.15, 12, hair, 3)
	
	# Eyes - squinting when aiming
	var eye_squint = bow_draw * 0.5
	draw_circle(Vector2(-4, -1), 3 - eye_squint, Color.WHITE)
	draw_circle(Vector2(4, -1), 3 - eye_squint, Color.WHITE)
	draw_circle(Vector2(-4, -1), 1.5, Color("#1e3a5f"))
	draw_circle(Vector2(4, -1), 1.5, Color("#1e3a5f"))
	draw_circle(Vector2(-3, -2), 0.8, Color.WHITE)
	draw_circle(Vector2(5, -2), 0.8, Color.WHITE)
	
	draw_line(Vector2(-7, -5 - eye_squint), Vector2(-2, -4), hair, 2)
	draw_line(Vector2(7, -5 - eye_squint), Vector2(2, -4), hair, 2)
	draw_line(Vector2(0, 0), Vector2(0, 3), skin_shadow, 1)
	draw_arc(Vector2(0, 6), 3, 0, PI, 6, skin_shadow, 1)
	
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# =============================================================================
# MELEE CHARACTER - Armored warrior with sword and shield
# =============================================================================
func _draw_melee_character(is_p1: bool):
	var armor_primary = Color("#1e40af") if is_p1 else Color("#7c3aed")
	var armor_secondary = Color("#3b82f6") if is_p1 else Color("#a78bfa")
	var armor_dark = Color("#1e3a5f") if is_p1 else Color("#4c1d95")
	var metal = Color("#6b7280")
	var metal_shine = Color("#d1d5db")
	var gold = Color("#fbbf24")
	var gold_dark = Color("#b45309")
	var skin = Color("#e0ac69")
	var cloth = Color("#1f2937")
	var red_accent = Color("#dc2626")
	var leather = Color("#78350f")
	
	# Animation
	var swing_angle = _get_sword_swing_angle()
	var body_lean = swing_angle * 0.15  # Body leans with swing
	
	# === SHADOW ===
	draw_set_transform(Vector2(0, 5), 0, Vector2(1.4, 0.38))
	draw_circle(Vector2.ZERO, 24, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# === CAPE (behind) ===
	# Cape sways with movement
	var cape_sway = swing_angle * 8
	var cape = PackedVector2Array([
		Vector2(-14, -50), Vector2(14, -50),
		Vector2(18 - cape_sway, -8), Vector2(10 - cape_sway, 2), 
		Vector2(-10 - cape_sway, 2), Vector2(-18 - cape_sway, -8)
	])
	draw_colored_polygon(cape, red_accent.darkened(0.3))
	var cape_fold = PackedVector2Array([
		Vector2(-8, -48), Vector2(8, -48),
		Vector2(12 - cape_sway * 0.5, -12), Vector2(-12 - cape_sway * 0.5, -12)
	])
	draw_colored_polygon(cape_fold, red_accent.darkened(0.5))
	
	# === LEGS ===
	draw_rect(Rect2(-11, -18, 9, 22), armor_dark, true)
	draw_rect(Rect2(2, -18, 9, 22), armor_dark, true)
	draw_circle(Vector2(-6, -12), 6, armor_secondary)
	draw_circle(Vector2(7, -12), 6, armor_secondary)
	draw_arc(Vector2(-6, -12), 6, 0, TAU, 12, armor_dark, 1)
	draw_arc(Vector2(7, -12), 6, 0, TAU, 12, armor_dark, 1)
	
	# === BOOTS ===
	var boot_l = PackedVector2Array([
		Vector2(-13, 0), Vector2(-1, 0), Vector2(0, 5), Vector2(-15, 5), Vector2(-15, 2)
	])
	draw_colored_polygon(boot_l, metal)
	draw_polyline(boot_l, armor_dark, 2)
	draw_line(Vector2(-12, 1), Vector2(-3, 1), metal_shine, 2)
	
	var boot_r = PackedVector2Array([
		Vector2(1, 0), Vector2(13, 0), Vector2(15, 2), Vector2(15, 5), Vector2(0, 5)
	])
	draw_colored_polygon(boot_r, metal)
	draw_polyline(boot_r, armor_dark, 2)
	draw_line(Vector2(3, 1), Vector2(12, 1), metal_shine, 2)
	
	# === TORSO (leans with swing) ===
	draw_set_transform(Vector2(0, -35), body_lean, Vector2.ONE)
	
	var torso = PackedVector2Array([
		Vector2(-16, 15), Vector2(16, 15),
		Vector2(18, -17), Vector2(-18, -17)
	])
	draw_colored_polygon(torso, armor_primary)
	
	var chest = PackedVector2Array([
		Vector2(-12, 11), Vector2(12, 11),
		Vector2(14, -13), Vector2(0, -17), Vector2(-14, -13)
	])
	draw_colored_polygon(chest, armor_secondary)
	draw_polyline(chest, armor_dark, 2)
	
	draw_circle(Vector2(0, -3), 8, gold)
	draw_circle(Vector2(0, -3), 6, gold_dark)
	draw_circle(Vector2(0, -3), 4, gold)
	draw_line(Vector2(-5, -3), Vector2(5, -3), gold_dark, 2)
	draw_line(Vector2(0, -8), Vector2(0, 2), gold_dark, 2)
	
	draw_rect(Rect2(-17, 11, 34, 6), armor_dark, true)
	draw_rect(Rect2(-17, 11, 34, 6), metal, false, 2)
	draw_rect(Rect2(-5, 10, 10, 8), gold, true)
	
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# === SHOULDER PAULDRONS ===
	var pauldron_l = PackedVector2Array([
		Vector2(-28, -48), Vector2(-14, -52),
		Vector2(-12, -40), Vector2(-26, -36)
	])
	draw_colored_polygon(pauldron_l, armor_secondary)
	draw_polyline(pauldron_l, armor_dark, 2)
	draw_line(Vector2(-24, -46), Vector2(-16, -48), metal_shine, 2)
	draw_circle(Vector2(-20, -44), 4, gold)
	
	var pauldron_r = PackedVector2Array([
		Vector2(28, -48), Vector2(14, -52),
		Vector2(12, -40), Vector2(26, -36)
	])
	draw_colored_polygon(pauldron_r, armor_secondary)
	draw_polyline(pauldron_r, armor_dark, 2)
	draw_line(Vector2(24, -46), Vector2(16, -48), metal_shine, 2)
	draw_circle(Vector2(20, -44), 4, gold)
	
	# === SHIELD ARM (Left) ===
	var shield_raise = abs(swing_angle) * 5  # Raises shield when attacking
	
	draw_rect(Rect2(-26, -46 - shield_raise, 10, 26), armor_primary, true)
	draw_rect(Rect2(-26, -46 - shield_raise, 10, 26), armor_dark, false, 1)
	draw_rect(Rect2(-27, -24 - shield_raise, 12, 10), metal, true)
	draw_rect(Rect2(-27, -22 - shield_raise, 12, 3), metal_shine, true)
	draw_circle(Vector2(-21, -12 - shield_raise), 6, metal)
	
	# Shield
	var shield_center = Vector2(-32, -30 - shield_raise)
	var shield = PackedVector2Array([
		shield_center + Vector2(0, -18),
		shield_center + Vector2(14, -10),
		shield_center + Vector2(14, 10),
		shield_center + Vector2(0, 22),
		shield_center + Vector2(-14, 10),
		shield_center + Vector2(-14, -10)
	])
	draw_colored_polygon(shield, armor_secondary)
	draw_polyline(shield, armor_dark, 3)
	draw_polyline(shield, gold, 2)
	draw_circle(shield_center, 8, gold)
	draw_circle(shield_center, 5, armor_primary)
	
	# === SWORD ARM (Right - animated) ===
	var sword_pivot = Vector2(21, -46)
	var sword_rot = swing_angle * 1.5  # Sword rotates more than arm
	
	# Arm
	draw_set_transform(Vector2(16, -46), swing_angle * 0.5, Vector2.ONE)
	draw_rect(Rect2(0, 0, 10, 26), armor_primary, true)
	draw_rect(Rect2(0, 0, 10, 26), armor_dark, false, 1)
	draw_rect(Rect2(-1, 18, 12, 10), metal, true)
	draw_rect(Rect2(-1, 20, 12, 3), metal_shine, true)
	draw_circle(Vector2(5, 30), 6, metal)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# === SWORD (animated swing) ===
	draw_set_transform(sword_pivot, sword_rot, Vector2.ONE)
	
	# Blade
	var blade = PackedVector2Array([
		Vector2(9, -9), Vector2(13, -9),
		Vector2(14, 35), Vector2(11, 42), Vector2(8, 35)
	])
	draw_colored_polygon(blade, metal_shine)
	draw_polyline(blade, metal, 2)
	draw_line(Vector2(11, -6), Vector2(12, 32), Color.WHITE, 1)
	
	# Crossguard
	draw_rect(Rect2(5, -14, 12, 5), gold, true)
	draw_rect(Rect2(5, -14, 12, 5), gold_dark, false, 1)
	
	# Handle
	draw_rect(Rect2(8, -26, 6, 14), leather, true)
	draw_line(Vector2(9, -24), Vector2(9, -14), leather.darkened(0.3), 1)
	draw_line(Vector2(13, -24), Vector2(13, -14), leather.darkened(0.3), 1)
	
	# Pommel
	draw_circle(Vector2(11, -28), 4, gold)
	
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# === HEAD ===
	var head_y = -64.0
	var head_turn = swing_angle * 0.2
	
	draw_rect(Rect2(-5, -54, 10, 5), cloth, true)
	
	draw_set_transform(Vector2(0, head_y), head_turn, Vector2.ONE)
	draw_circle(Vector2.ZERO, 11, skin)
	
	# Helmet
	var helmet = PackedVector2Array([
		Vector2(-14, 6), Vector2(14, 6),
		Vector2(16, -6), Vector2(12, -18),
		Vector2(0, -22), Vector2(-12, -18), Vector2(-16, -6)
	])
	draw_colored_polygon(helmet, armor_secondary)
	draw_polyline(helmet, armor_dark, 2)
	draw_arc(Vector2(-4, -10), 8, PI * 0.6, PI * 1.4, 10, metal_shine, 2)
	
	# Visor
	draw_rect(Rect2(-12, -4, 24, 10), armor_dark, true)
	draw_line(Vector2(-10, 0), Vector2(-3, 0), Color.BLACK, 2)
	draw_line(Vector2(3, 0), Vector2(10, 0), Color.BLACK, 2)
	draw_circle(Vector2(-5, 0), 2, Color(armor_secondary.r, armor_secondary.g, armor_secondary.b, 0.6))
	draw_circle(Vector2(5, 0), 2, Color(armor_secondary.r, armor_secondary.g, armor_secondary.b, 0.6))
	
	# Crest
	var crest = PackedVector2Array([
		Vector2(-3, -20), Vector2(3, -20),
		Vector2(4, -38), Vector2(0, -42), Vector2(-4, -38)
	])
	draw_colored_polygon(crest, red_accent)
	draw_polyline(crest, red_accent.darkened(0.3), 2)
	draw_line(Vector2(0, -22), Vector2(0, -40), red_accent.lightened(0.2), 2)
	
	# Nose guard
	draw_rect(Rect2(-2, -6, 4, 14), metal, true)
	draw_line(Vector2(0, -5), Vector2(0, 6), metal_shine, 2)
	
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
# =============================================================================
# MAGE CHARACTER - Mystic robe and staff
# =============================================================================
func _draw_mage_character(is_p1: bool):
	var robe_primary = Color("#4c1d95") if is_p1 else Color("#831843")
	var robe_secondary = Color("#7c3aed") if is_p1 else Color("#db2777")
	var gold = Color("#f59e0b")
	var staff_wood = Color("#451a03")
	var crystal = Color("#22d3ee") if is_p1 else Color("#fb7185")
	var skin = Color("#e0ac69")
	
	# Floating animation
	var float_y = sin(Time.get_ticks_msec() * 0.005) * 5.0
	var base_pos = Vector2(0, float_y)
	
	# 1. Staff (Behind)
	draw_line(base_pos + Vector2(25, -20), base_pos + Vector2(35, -90), staff_wood, 4)
	draw_circle(base_pos + Vector2(35, -95), 8, crystal)
	draw_circle(base_pos + Vector2(35, -95), 12, Color(crystal.r, crystal.g, crystal.b, 0.3))
	
	# 2. Robe Bottom
	var robe_pts = PackedVector2Array([
		base_pos + Vector2(-25, 0),
		base_pos + Vector2(25, 0),
		base_pos + Vector2(15, -60),
		base_pos + Vector2(-15, -60)
	])
	draw_colored_polygon(robe_pts, robe_primary)
	draw_polyline(robe_pts, robe_secondary, 2)
	
	# 3. Arms
	draw_line(base_pos + Vector2(-15, -45), base_pos + Vector2(-28, -25), robe_primary, 8)
	draw_line(base_pos + Vector2(15, -45), base_pos + Vector2(28, -25), robe_primary, 8)
	
	# 4. Head
	draw_circle(base_pos + Vector2(0, -70), 12, skin)
	
	# 5. Hat
	var hat_pts = PackedVector2Array([
		base_pos + Vector2(-22, -75),
		base_pos + Vector2(22, -75),
		base_pos + Vector2(0, -110)
	])
	draw_colored_polygon(hat_pts, robe_primary)
	draw_line(base_pos + Vector2(-22, -75), base_pos + Vector2(22, -75), gold, 3)
	
	# 6. Belt/Trim
	draw_line(base_pos + Vector2(-16, -40), base_pos + Vector2(16, -40), gold, 2)

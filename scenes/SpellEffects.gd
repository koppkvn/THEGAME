extends Node2D
class_name SpellEffects

# Singleton for spell visual effects
static var instance: SpellEffects

func _ready():
	instance = self

# === PROJECTILE EFFECTS ===

static func arrow_projectile(parent: Node, from: Vector2, to: Vector2, color: Color = Color.CYAN, on_complete: Callable = Callable()) -> void:
	var arrow = Node2D.new()
	arrow.position = from
	arrow.set_script(load("res://scenes/ArrowEffect.gd"))
	arrow.init(to, color, on_complete)
	parent.add_child(arrow)

static func create_projectile(parent: Node, from: Vector2, to: Vector2, color: Color, size: float = 8.0) -> void:
	var projectile = Node2D.new()
	projectile.position = from
	parent.add_child(projectile)
	
	# Draw circle
	var draw_script = GDScript.new()
	draw_script.source_code = """
extends Node2D
var color: Color
var size: float
func _draw():
	draw_circle(Vector2.ZERO, size, color)
	draw_circle(Vector2.ZERO, size * 0.6, color.lightened(0.4))
"""
	draw_script.reload()
	projectile.set_script(draw_script)
	projectile.color = color
	projectile.size = size
	projectile.queue_redraw()
	
	# Animate
	var tween = parent.create_tween()
	tween.tween_property(projectile, "position", to, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): 
		create_impact(parent, to, color)
		projectile.queue_free()
	)

# === IMPACT EFFECTS ===

static func create_impact(parent: Node, pos: Vector2, color: Color, radius: float = 30.0) -> void:
	var impact = Node2D.new()
	impact.position = pos
	parent.add_child(impact)
	
	var rings = []
	for i in range(3):
		var ring = Node2D.new()
		ring.position = Vector2.ZERO
		impact.add_child(ring)
		rings.append(ring)
	
	# Animate rings expanding
	var tween = parent.create_tween()
	for i in range(rings.size()):
		var ring = rings[i]
		ring.modulate = color
		ring.modulate.a = 1.0
		tween.parallel().tween_property(ring, "scale", Vector2(2 + i, 2 + i), 0.4).from(Vector2(0.1, 0.1)).set_delay(i * 0.1)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.4).set_delay(i * 0.1)
	
	tween.tween_callback(func(): impact.queue_free())

# === SLASH EFFECT ===

static func create_slash(parent: Node, pos: Vector2, color: Color = Color.WHITE) -> void:
	var slash = Node2D.new()
	slash.position = pos
	parent.add_child(slash)
	
	var tween = parent.create_tween()
	slash.rotation = -PI/4
	slash.scale = Vector2(0.1, 0.1)
	slash.modulate = color
	
	tween.tween_property(slash, "scale", Vector2(1.5, 1.5), 0.15).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash, "rotation", PI/4, 0.15)
	tween.tween_property(slash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): slash.queue_free())

# === PUSH EFFECT ===

static func create_push_lines(parent: Node, from: Vector2, to: Vector2, color: Color = Color.YELLOW) -> void:
	for i in range(5):
		var line = Node2D.new()
		var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		line.position = from + offset
		parent.add_child(line)
		line.modulate = color
		line.modulate.a = 0.8
		
		var tween = parent.create_tween()
		tween.tween_property(line, "position", to + offset, 0.25).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(line, "modulate:a", 0.0, 0.25)
		tween.tween_callback(func(): line.queue_free())

# === HEAL EFFECT ===

static func create_heal(parent: Node, pos: Vector2) -> void:
	for i in range(8):
		var particle = Node2D.new()
		var angle = (TAU / 8) * i
		particle.position = pos + Vector2(cos(angle), sin(angle)) * 30
		parent.add_child(particle)
		particle.modulate = Color.GREEN
		
		var tween = parent.create_tween()
		tween.tween_property(particle, "position", pos + Vector2(0, -20), 0.5).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): particle.queue_free())

# === AOE EFFECT ===

static func create_aoe_blast(parent: Node, center: Vector2, radius: float, color: Color) -> void:
	var blast = Node2D.new()
	blast.position = center
	parent.add_child(blast)
	
	blast.scale = Vector2(0.1, 0.1)
	blast.modulate = color
	
	var tween = parent.create_tween()
	tween.tween_property(blast, "scale", Vector2(radius / 20, radius / 20), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(blast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): blast.queue_free())

# === BUFF EFFECT ===

static func create_buff(parent: Node, pos: Vector2, color: Color) -> void:
	var buff = Node2D.new()
	buff.position = pos
	parent.add_child(buff)
	
	# Spiral particles going up
	for i in range(12):
		var particle = Node2D.new()
		var angle = (TAU / 12) * i
		particle.position = Vector2(cos(angle) * 15, sin(angle) * 15)
		buff.add_child(particle)
		particle.modulate = color
		
		var tween = parent.create_tween()
		var target = Vector2(cos(angle + PI) * 5, -50 - i * 3)
		tween.tween_property(particle, "position", target, 0.6).set_delay(i * 0.03).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.6).set_delay(i * 0.03)
	
	var cleanup_tween = parent.create_tween()
	cleanup_tween.tween_interval(1.0)
	cleanup_tween.tween_callback(func(): buff.queue_free())

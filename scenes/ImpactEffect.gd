extends Node2D

var color: Color
var rings: Array = []
var particles: Array = []

func init(c: Color):
	color = c

func _ready():
	# Create expanding rings
	for i in range(3):
		var ring_data = {"radius": 5.0, "alpha": 1.0, "width": 4.0 - i}
		rings.append(ring_data)
	
	# Create particle bursts
	for i in range(12):
		var angle = (TAU / 12) * i + randf_range(-0.2, 0.2)
		var speed = randf_range(60, 120)
		var particle = {
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"alpha": 1.0,
			"size": randf_range(3, 6)
		}
		particles.append(particle)
	
	# Self-destruct after animation
	var tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(queue_free)

func _process(delta):
	# Update rings
	for ring in rings:
		ring.radius += delta * 150
		ring.alpha -= delta * 2.5
		ring.alpha = max(0, ring.alpha)
	
	# Update particles
	for p in particles:
		p.pos += p.vel * delta
		p.vel *= 0.95  # Slow down
		p.alpha -= delta * 2.0
		p.alpha = max(0, p.alpha)
	
	queue_redraw()

func _draw():
	# Draw rings
	for ring in rings:
		if ring.alpha > 0:
			var ring_color = color
			ring_color.a = ring.alpha
			draw_arc(Vector2.ZERO, ring.radius, 0, TAU, 32, ring_color, ring.width)
	
	# Draw particles
	for p in particles:
		if p.alpha > 0:
			var p_color = color.lightened(0.3)
			p_color.a = p.alpha
			draw_circle(p.pos, p.size, p_color)
	
	# Center flash
	var center_alpha = 1.0 - (rings[0].radius / 50.0)
	if center_alpha > 0:
		draw_circle(Vector2.ZERO, 15 * center_alpha, Color(1, 1, 1, center_alpha))

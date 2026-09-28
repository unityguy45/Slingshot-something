class_name Planet
extends Node2D

var radius := 60.0
var mu := 0.0
var field := 0.0
var color := Color(0.4, 0.7, 1.0)
var vel := Vector2.ZERO
var has_ring := false
var ring_tilt := 0.0
var t := randf() * 10.0


func setup(r: float) -> void:
	radius = r
	mu = 5.0 * r * r * r
	field = r * 5.5
	color = Color.from_hsv(randf(), randf_range(0.35, 0.6), randf_range(0.75, 0.95))
	has_ring = randf() < 0.35
	ring_tilt = randf_range(-0.6, 0.6)


func gravity_at(p: Vector2) -> Vector2:
	var d := position - p
	var dist := d.length()
	if dist > field or dist < 1.0:
		return Vector2.ZERO
	var fade := clampf((field - dist) / (field * 0.25), 0.0, 1.0)
	return d / dist * mu / maxf(dist * dist, radius * radius) * fade


func _process(delta: float) -> void:
	t += delta
	position += vel * delta
	queue_redraw()


func _draw() -> void:
	for i in 3:
		var rr := field * (0.4 + 0.3 * i)
		var al := 0.3 - i * 0.08
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 96, Color(color.r, color.g, color.b, al), 3.0, true)
	draw_circle(Vector2.ZERO, field, Color(color.r, color.g, color.b, 0.04))
	draw_circle(Vector2.ZERO, radius * 1.12, Color(color.r, color.g, color.b, 0.18))
	if has_ring:
		_ring(true)
	draw_circle(Vector2.ZERO, radius, color.darkened(0.45))
	draw_circle(Vector2(-radius * 0.12, -radius * 0.12), radius * 0.86, color.darkened(0.15))
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.5, color)
	if has_ring:
		_ring(false)


func _ring(back: bool) -> void:
	draw_set_transform(Vector2.ZERO, ring_tilt, Vector2(1.0, 0.28))
	var from := PI if back else 0.0
	draw_arc(Vector2.ZERO, radius * 1.7, from, from + PI, 48, Color(color.r, color.g, color.b, 0.55).lightened(0.3), radius * 0.18)
	draw_arc(Vector2.ZERO, radius * 2.0, from, from + PI, 48, Color(color.r, color.g, color.b, 0.35).lightened(0.3), radius * 0.1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

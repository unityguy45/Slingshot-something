class_name Drone
extends Node2D

signal landed(planet: Planet)

var vel := Vector2.ZERO
var bodies: Array = []
var life := 18.0
var t := 0.0


func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var a := Vector2.ZERO
	for b: Planet in bodies:
		a += b.gravity_at(position)
	vel += a * delta
	var best: Planet = null
	var bd := 2500.0
	for b: Planet in bodies:
		if b.drone_active:
			var dd := position.distance_to(b.position)
			if dd < bd:
				bd = dd
				best = b
	if best != null:
		var want := (best.position - position).normalized() * 700.0 + best.vel
		vel = vel.lerp(want, 1.5 * delta)
	position += vel * delta
	rotation = vel.angle()
	for b: Planet in bodies:
		if position.distance_to(b.position) < b.kill_radius():
			landed.emit(b)
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.2, 2.2))
	draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(-5, -5), Vector2(-3, 0), Vector2(-5, 5)]), Color(0.8, 0.82, 0.9))
	draw_circle(Vector2(0, 0), 2.0, Color(0.3, 1.8, 1.0) if int(t * 6.0) % 2 == 0 else Color(0.1, 0.4, 0.3))

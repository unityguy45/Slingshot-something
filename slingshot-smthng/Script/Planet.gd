class_name Planet
extends Node2D

var radius := 36.0
var orbit_r := 90.0
var is_sun := false
var color := Color(0.4, 0.8, 1.0)
var visited := false
var move_amp := 0.0
var move_speed := 1.0
var base_x := 0.0
var fuse := 0.0
var t := randf() * 10.0


func _ready() -> void:
	base_x = position.x


func _process(delta: float) -> void:
	t += delta
	if move_amp > 0.0:
		position.x = base_x + sin(t * move_speed) * move_amp
	queue_redraw()


func _draw() -> void:
	if is_sun:
		var pulse := 1.0 + sin(t * 4.0) * 0.08
		draw_circle(Vector2.ZERO, radius * 1.6 * pulse, Color(1.0, 0.35, 0.1, 0.15))
		draw_circle(Vector2.ZERO, radius * 1.25 * pulse, Color(1.0, 0.45, 0.1, 0.3))
		draw_circle(Vector2.ZERO, radius, Color(2.4, 1.1, 0.3))
		return
	var ring_col := color * Color(1, 1, 1, 0.35) if not visited else Color(1, 1, 1, 0.12)
	var dots := 40
	for i in dots:
		var a := TAU * i / dots + t * 0.2
		draw_circle(Vector2.from_angle(a) * orbit_r, 2.0, ring_col)
	if fuse > 0.0:
		var c := Color(2.0, 2.0, 2.0) if fuse > 0.35 else Color(2.5, 0.5, 0.4)
		draw_arc(Vector2.ZERO, orbit_r + 10.0, -PI / 2.0, -PI / 2.0 + TAU * fuse, 64, c, 4.0, true)
	draw_circle(Vector2.ZERO, radius + 4.0, color * Color(1, 1, 1, 0.25))
	draw_circle(Vector2.ZERO, radius, color.darkened(0.35))
	draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.6, color)

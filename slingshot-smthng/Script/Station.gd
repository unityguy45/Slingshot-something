class_name Station
extends Node2D

var used := false
var t := 0.0
const DOCK_R := 46.0


func _process(delta: float) -> void:
	t += delta
	rotation += delta * 0.4
	queue_redraw()


func _draw() -> void:
	var c := Color(0.35, 1.0, 0.6) if not used else Color(0.4, 0.4, 0.45)
	if not used:
		var p := 0.5 + 0.5 * sin(t * 3.0)
		draw_arc(Vector2.ZERO, DOCK_R + 10.0 + p * 8.0, 0, TAU, 48, Color(c.r, c.g, c.b, 0.35 * (1.0 - p)), 3.0)
	for i in 4:
		var d := Vector2.from_angle(i * PI / 2.0)
		draw_line(d * 14.0, d * 34.0, Color(0.7, 0.72, 0.78), 5.0)
		var side := d.orthogonal()
		draw_colored_polygon(PackedVector2Array([d * 26 + side * 12, d * 40 + side * 12, d * 40 - side * 12, d * 26 - side * 12]), Color(0.2, 0.35, 0.8))
	draw_arc(Vector2.ZERO, 16.0, 0, TAU, 32, Color(0.85, 0.87, 0.92), 7.0)
	draw_circle(Vector2.ZERO, 8.0, c)

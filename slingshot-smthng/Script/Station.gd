class_name Station
extends Node2D

var used := false
var mothership := false
var t := 0.0
var dock_r := 80.0
var sname := ""
var parent: Planet
var orbit_r := 0.0
var orbit_a0 := 0.0
var omega := 0.0
var vel := Vector2.ZERO


func set_orbit(p: Planet, r: float, a0: float) -> void:
	parent = p
	orbit_r = r
	orbit_a0 = a0
	omega = sqrt(p.mu / pow(r, 3.0))


func pos_at(tt: float) -> Vector2:
	return parent.pos_at(tt) + Vector2.from_angle(orbit_a0 + omega * tt) * orbit_r


func update_motion() -> void:
	position = pos_at(Planet.time)
	vel = (pos_at(Planet.time + 0.05) - position) / 0.05


func _ready() -> void:
	if mothership:
		dock_r = 130.0
		sname = "MOTHERSHIP"
	else:
		sname = "Station %s-%d" % [["Aurora", "Beacon", "Haven", "Relay", "Outpost"].pick_random(), randi_range(1, 99)]


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var s := 2.4 if mothership else 1.6
	var live := true
	var c := Color(0.35, 1.0, 0.6) if live else Color(0.4, 0.4, 0.45)
	if live:
		var p := fmod(t * 0.6, 1.0)
		draw_arc(Vector2.ZERO, dock_r * (0.8 + p * 0.6), 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.45 * (1.0 - p)), 4.0, true)
	draw_set_transform(Vector2.ZERO, t * (0.15 if mothership else 0.35), Vector2(s, s))
	for i in 4:
		var d := Vector2.from_angle(i * PI / 2.0)
		var side := d.orthogonal()
		draw_line(d * 14.0, d * 38.0, Color(0.55, 0.58, 0.65), 5.0)
		draw_colored_polygon(PackedVector2Array([d * 24 + side * 13, d * 44 + side * 13, d * 44 - side * 13, d * 24 - side * 13]), Color(0.15, 0.25, 0.6))
		for k in 3:
			draw_line(d * (27 + k * 6) + side * 12, d * (27 + k * 6) - side * 12, Color(0.35, 0.55, 1.0), 1.0)
		draw_circle(d * 44, 2.5, Color(2.0, 0.4, 0.4) if int(t * 2.0) % 2 == 0 else Color(0.4, 0.1, 0.1))
	draw_arc(Vector2.ZERO, 22.0, 0, TAU, 40, Color(0.75, 0.78, 0.85), 8.0)
	draw_arc(Vector2.ZERO, 22.0, 0, TAU, 40, Color(0.3, 0.32, 0.4), 1.5)
	for i in 8:
		draw_circle(Vector2.from_angle(i * TAU / 8.0) * 22.0, 1.6, Color(1.8, 1.6, 0.8))
	draw_circle(Vector2.ZERO, 11.0, Color(0.2, 0.22, 0.3))
	draw_circle(Vector2.ZERO, 7.0, c * (1.6 if live else 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

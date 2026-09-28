class_name Player
extends Node2D

signal died(reason: String)
signal docked(station: Station)

const THRUST := 170.0
const TURN := 6.0
const MAX_SPEED := 900.0
const FUEL_MAX := 100.0
const BURN := 32.0

var vel := Vector2(260, 0)
var fuel := FUEL_MAX
var thrusting := false
var launch_lock := true
var state := "fly"
var station: Station
var planets: Array = []
var stations: Array = []
var trail: Line2D


func _ready() -> void:
	trail = Line2D.new()
	trail.top_level = true
	trail.width = 5.0
	trail.default_color = Color(1.4, 0.7, 0.3)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0.8))
	trail.gradient = g
	add_child(trail)


func gravity_at(p: Vector2) -> Vector2:
	var a := Vector2.ZERO
	for pl: Planet in planets:
		a += pl.gravity_at(p)
	return a


func _physics_process(delta: float) -> void:
	if state == "dead":
		return
	var aim := get_global_mouse_position() - global_position
	rotation = rotate_toward(rotation, aim.angle(), TURN * delta)
	var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE)
	if not held:
		launch_lock = false
	thrusting = held and not launch_lock
	if state == "docked":
		position = station.position
		vel = Vector2.ZERO
		fuel = minf(FUEL_MAX, fuel + FUEL_MAX * 0.8 * delta)
		if thrusting and fuel >= FUEL_MAX * 0.99:
			state = "fly"
			vel = Vector2.from_angle(rotation) * 230.0
			position += vel.normalized() * (Station.DOCK_R + 10.0)
		queue_redraw()
		return
	if thrusting and fuel > 0.0:
		vel += Vector2.from_angle(rotation) * THRUST * delta
		fuel = maxf(0.0, fuel - BURN * delta)
	else:
		thrusting = false
	vel += gravity_at(position) * delta
	vel = vel.limit_length(MAX_SPEED)
	position += vel * delta
	for pl: Planet in planets:
		if position.distance_to(pl.position) < pl.radius + 6.0:
			died.emit("Crashed into a planet")
			state = "dead"
			return
	for st: Station in stations:
		if not st.used and position.distance_to(st.position) < Station.DOCK_R:
			if vel.length() < 260.0:
				state = "docked"
				station = st
				st.used = true
				docked.emit(st)
				return
	trail.add_point(global_position - Vector2.from_angle(rotation) * 26.0)
	while trail.get_point_count() > 40:
		trail.remove_point(0)
	queue_redraw()


func predict(steps: int, dt: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p := position
	var v := vel
	for i in steps:
		var a := Vector2.ZERO
		for pl: Planet in planets:
			var fut: Planet = pl
			a += fut.gravity_at(p - fut.vel * dt * i)
		v += a * dt
		p += v * dt
		pts.append(p)
		for pl: Planet in planets:
			if p.distance_to(pl.position + pl.vel * dt * i) < pl.radius:
				return pts
	return pts


func _draw() -> void:
	if state == "dead":
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.2, 2.2))
	if thrusting:
		var f := randf_range(0.8, 1.2) * 18.0
		draw_colored_polygon(PackedVector2Array([Vector2(-11, -4), Vector2(-11 - f, 0), Vector2(-11, 4)]), Color(1.6, 0.6, 0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(-11, -2), Vector2(-11 - f * 0.5, 0), Vector2(-11, 2)]), Color(1.0, 0.9, 0.5))
	var wing := Color(0.85, 0.2, 0.25)
	draw_colored_polygon(PackedVector2Array([Vector2(4, -5), Vector2(-12, -15), Vector2(-9, -5)]), wing)
	draw_colored_polygon(PackedVector2Array([Vector2(4, 5), Vector2(-12, 15), Vector2(-9, 5)]), wing)
	var body := PackedVector2Array([Vector2(20, 0), Vector2(8, -6), Vector2(-11, -6), Vector2(-11, 6), Vector2(8, 6)])
	draw_colored_polygon(body, Color(0.88, 0.9, 0.95))
	draw_colored_polygon(PackedVector2Array([Vector2(20, 0), Vector2(8, -6), Vector2(8, 6)]), wing)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(0.1, 0.1, 0.15), 1.2, true)
	draw_circle(Vector2(2, 0), 3.2, Color(0.25, 0.75, 1.0))

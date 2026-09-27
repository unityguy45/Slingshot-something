class_name Player
extends Node2D

signal captured(planet: Planet)
signal died

const FLY_SPEED := 620.0
const GRAVITY := 900000.0

var state := "orbit"
var planet: Planet
var angle := 0.0
var dir := 1.0
var ang_speed := 3.2
var vel := Vector2.ZERO
var left_planet: Planet
var grace := 0.0
var orbit_time := 0.0
var fuse_len := 4.0
var trail: Line2D
var planets: Array = []


func _ready() -> void:
	trail = Line2D.new()
	trail.top_level = true
	trail.width = 6.0
	trail.default_color = Color(0.6, 1.8, 2.2)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	trail.gradient = g
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)


func attach(p: Planet, at_angle: float, direction: float) -> void:
	planet = p
	angle = at_angle
	dir = direction
	state = "orbit"
	orbit_time = 0.0
	ang_speed = clampf(300.0 / p.orbit_r, 2.2, 4.5)
	captured.emit(p)


func release() -> void:
	if state != "orbit":
		return
	var tangent := Vector2.from_angle(angle + dir * PI / 2.0)
	vel = tangent * FLY_SPEED
	left_planet = planet
	planet.fuse = 0.0
	planet = null
	grace = 0.25
	state = "fly"


func _physics_process(delta: float) -> void:
	match state:
		"orbit":
			angle += dir * ang_speed * delta
			position = planet.position + Vector2.from_angle(angle) * planet.orbit_r
			orbit_time += delta
			planet.fuse = 1.0 - orbit_time / fuse_len
			if orbit_time >= fuse_len:
				release()
		"fly":
			grace -= delta
			for p: Planet in planets:
				var d: Vector2 = p.position - position
				var dist := d.length()
				if dist < p.radius + 6.0:
					_die()
					return
				if p.is_sun and dist < p.radius * 1.25:
					_die()
					return
				if dist < p.orbit_r * 2.2:
					vel += d / dist * GRAVITY / (dist * dist) * delta * (1.6 if p.is_sun else 1.0)
				if not p.is_sun and dist < p.orbit_r and not (p == left_planet and grace > 0.0):
					var rel := position - p.position
					var cross := rel.x * vel.y - rel.y * vel.x
					attach(p, rel.angle(), signf(cross) if cross != 0.0 else 1.0)
					return
			vel = vel.limit_length(FLY_SPEED * 1.4)
			position += vel * delta
	trail.add_point(global_position)
	while trail.get_point_count() > 24:
		trail.remove_point(0)
	queue_redraw()


func _die() -> void:
	if state == "dead":
		return
	state = "dead"
	died.emit()


func _draw() -> void:
	if state == "dead":
		return
	draw_circle(Vector2.ZERO, 16.0, Color(0.5, 1.5, 2.0, 0.25))
	draw_circle(Vector2.ZERO, 9.0, Color(2.0, 2.6, 3.0))

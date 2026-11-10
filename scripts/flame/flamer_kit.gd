class_name FlamerKit
extends RefCounted
## The flamethrower kit (Question Chat, flamethrower round, 2026-11-10), in the faceted low-poly style of the trains
## and guns (TrainGeo, vertex colours, TrainParts.material()).
##   back_tanks   the man-pack: two fuel bottles and a pressure ball on a frame, worn on the back
##   lance        the gun: rear pistol grip at the origin, pointing -Z, front grip, igniter and nozzle
##   spare_can    the assistant's spare fuel bottle (on his back)
##   heavy_tank / heavy_stand / heavy_gun / heavy_pump   the heavy trench flamer, four loads for a crew of four
##   tank_projector / tank_fuel   the flame tank's gun (replaces the light tank's gun) and its armoured fuel drums
##   wagon(car)   the flame wagon for the armoured trains (a TrainCar like the gun flat)

const OLIVE := Color(0.36, 0.40, 0.24)
const OLIVE_DARK := Color(0.28, 0.32, 0.19)
const BLACK := Color(0.09, 0.09, 0.10)
const STEEL := Color(0.40, 0.40, 0.42)
const BRASS := Color(0.66, 0.52, 0.28)
const LEATHER := Color(0.32, 0.22, 0.13)
const RUBBER := Color(0.12, 0.11, 0.10)
const RED := Color(0.55, 0.14, 0.10)
const WOOD := Color(0.47, 0.31, 0.18)
const SANDBAG := Color(0.62, 0.56, 0.40)

const LANCE_LEN := 1.12
const LANCE_FRONT := Vector3(0, -0.07, -0.46)  # front grip (left hand)
const LANCE_REAR := Vector3(0, -0.075, 0.02)   # pistol grip (right hand)
const LANCE_NOZZLE := Vector3(0, 0, -1.16)
const TANKS_HOSE := Vector3(0.12, -0.36, 0.06)  # the hose leaves the tanks here (tank frame)
const HEAVY_NOZZLE := Vector3(0, 0, -1.75)     # heavy gun frame
const HEAVY_PIVOT_H := 0.95                    # the stand's pivot height
const TANK_NOZZLE := Vector3(0, 0, -1.25)      # flame tank projector frame (on the tank's gun pivot)
const WAGON_NOZZLE := Vector3(0, 0, -2.0)      # flame wagon projector frame (on its cradle)


static func mesh(g: TrainGeo) -> Mesh:
	return g.to_mesh(TrainParts.material())


## Origin between the shoulder blades on the wearer's back, +Z away from the back.
static func back_tanks() -> TrainGeo:
	var g := TrainGeo.new()
	for s: float in [-1.0, 1.0]:
		var x := s * 0.105
		g.cyl(Vector3(x, -0.4, 0.1), Vector3(x, 0.12, 0.1), 0.095, 10, OLIVE)
		g.lump(Vector3(x, 0.13, 0.1), 0.095, OLIVE, Vector3(1, 0.55, 1))
		g.lump(Vector3(x, -0.41, 0.1), 0.095, OLIVE_DARK, Vector3(1, 0.45, 1))
		g.cyl(Vector3(x, 0.17, 0.1), Vector3(x, 0.23, 0.1), 0.022, 6, BRASS)          # valve
		g.box(Vector3(x, -0.05, 0.005), Vector3(0.03, 0.3, 0.012), LEATHER)              # straps
		g.box(Vector3(x * 0.9, 0.05, -0.12), Vector3(0.022, 0.14, 0.012), LEATHER, Basis(Vector3.RIGHT, 0.5))
	g.lump(Vector3(0, -0.12, 0.2), 0.075, STEEL)                                          # pressure ball
	g.cyl(Vector3(0, -0.06, 0.2), Vector3(0, 0.05, 0.13), 0.012, 5, BRASS)
	g.box(Vector3(0, -0.12, 0.04), Vector3(0.2, 0.035, 0.02), STEEL)                     # frame bars
	g.box(Vector3(0, -0.36, 0.04), Vector3(0.2, 0.035, 0.02), STEEL)
	g.cyl(Vector3(0.105, -0.42, 0.1), TANKS_HOSE, 0.02, 6, RUBBER)
	# Danger band.
	for s: float in [-1.0, 1.0]:
		g.cyl(Vector3(s * 0.105, -0.02, 0.1), Vector3(s * 0.105, 0.02, 0.1), 0.097, 10, RED)
	return g


static func lance() -> TrainGeo:
	var g := TrainGeo.new()
	g.cyl(Vector3(0, 0, 0.12), Vector3(0, 0, -0.98), 0.024, 7, OLIVE_DARK)
	g.cyl(Vector3(0, 0, -0.98), LANCE_NOZZLE, 0.032, 8, BLACK, 0.022)
	g.cyl(Vector3(0, 0, 0.1), Vector3(0, 0, -0.18), 0.036, 7, OLIVE)                    # valve body
	g.box(LANCE_REAR + Vector3(0, -0.02, 0), Vector3(0.018, 0.07, 0.026), LEATHER, Basis(Vector3.RIGHT, 0.25))
	g.box(Vector3(0, -0.04, -0.03), Vector3(0.006, 0.03, 0.03), STEEL)                  # trigger guard
	g.box(LANCE_FRONT + Vector3(0, 0.0, 0), Vector3(0.018, 0.065, 0.024), LEATHER)
	g.box(Vector3(0, 0.035, -1.0), Vector3(0.035, 0.03, 0.06), STEEL)                    # igniter
	g.cyl(Vector3(0.04, 0.0, -0.95), Vector3(0.04, 0.0, -1.1), 0.01, 5, BRASS)
	g.cyl(Vector3(0, -0.03, 0.12), Vector3(0, -0.08, 0.2), 0.02, 6, RUBBER)
	return g


## The assistant's spare bottle: origin on his back like back_tanks.
static func spare_can() -> TrainGeo:
	var g := TrainGeo.new()
	g.cyl(Vector3(0, -0.36, 0.11), Vector3(0, 0.1, 0.11), 0.11, 10, OLIVE)
	g.lump(Vector3(0, 0.11, 0.11), 0.11, OLIVE, Vector3(1, 0.5, 1))
	g.lump(Vector3(0, -0.37, 0.11), 0.11, OLIVE_DARK, Vector3(1, 0.4, 1))
	g.cyl(Vector3(0, -0.03, 0.11), Vector3(0, 0.01, 0.11), 0.112, 10, RED)
	g.cyl(Vector3(0, 0.15, 0.11), Vector3(0, 0.2, 0.11), 0.022, 6, BRASS)
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(s * 0.09, -0.1, 0.0), Vector3(0.025, 0.28, 0.012), LEATHER)
	return g


# ---------------------------------------------------------------- the heavy trench flamer

## The fuel cylinder on carrying poles (origin on the ground under its middle, length along X).
static func heavy_tank() -> TrainGeo:
	var g := TrainGeo.new()
	g.cyl(Vector3(-0.55, 0.42, 0), Vector3(0.55, 0.42, 0), 0.3, 12, OLIVE)
	for s: float in [-1.0, 1.0]:
		g.lump(Vector3(s * 0.56, 0.42, 0), 0.3, OLIVE_DARK, Vector3(0.3, 1, 1))
		g.box(Vector3(s * 0.38, 0.06, 0), Vector3(0.04, 0.06, 0.32), STEEL)              # skid feet
		g.box(Vector3(s * 0.38, 0.22, 0), Vector3(0.03, 0.18, 0.03), STEEL)
		g.cyl(Vector3(s * 0.3, 0.42, 0), Vector3(s * 0.34, 0.42, 0), 0.305, 12, RED)
	for s: float in [-1.0, 1.0]:
		g.cyl(Vector3(-1.05, 0.5, s * 0.36), Vector3(1.05, 0.5, s * 0.36), 0.025, 6, WOOD) # poles
		g.box(Vector3(0, 0.5, s * 0.33), Vector3(0.5, 0.02, 0.03), STEEL)
	g.cyl(Vector3(0.1, 0.72, 0), Vector3(0.1, 0.84, 0), 0.05, 8, BRASS)                 # filler
	g.lump(Vector3(-0.25, 0.8, 0.05), 0.1, STEEL)                                        # pressure bottle
	g.cyl(Vector3(-0.25, 0.86, 0.05), Vector3(-0.25, 0.95, 0.05), 0.015, 5, BRASS)
	g.box(Vector3(-0.25, 0.97, 0.05), Vector3(0.05, 0.02, 0.05), BLACK)                  # gauge
	g.cyl(Vector3(0.55, 0.3, 0.1), Vector3(0.7, 0.2, 0.25), 0.035, 6, RUBBER)           # hose outlet
	return g


## The stand the projector swings on: three legs, a pivot head at HEAVY_PIVOT_H (origin on the ground).
static func heavy_stand(open := 1.0) -> TrainGeo:
	var g := TrainGeo.new()
	var top := Vector3(0, HEAVY_PIVOT_H - 0.08, 0)
	for k in 3:
		var a := TAU * k / 3.0 + PI
		var spread := lerpf(0.06, 0.55, open)
		var foot := Vector3(sin(a) * spread, 0.02, cos(a) * spread) + Vector3(0, (1.0 - open) * 0.05, 0)
		g.cyl(foot, top, 0.025, 6, OLIVE_DARK)
		g.box(foot, Vector3(0.05, 0.02, 0.05), STEEL)
	g.cyl(top, Vector3(0, HEAVY_PIVOT_H, 0), 0.07, 8, STEEL)
	return g


## The projector: a long heavy pipe on a yoke, nozzle at HEAVY_NOZZLE, hand spades at the back.
static func heavy_gun() -> TrainGeo:
	var g := TrainGeo.new()
	g.cyl(Vector3(0, 0, 0.55), Vector3(0, 0, -1.6), 0.045, 8, OLIVE_DARK)
	g.cyl(Vector3(0, 0, -1.6), HEAVY_NOZZLE, 0.06, 8, BLACK, 0.04)
	g.cyl(Vector3(0, 0, 0.1), Vector3(0, 0, -0.3), 0.07, 8, OLIVE)                       # valve body
	g.box(Vector3(0, -0.06, 0), Vector3(0.09, 0.05, 0.06), STEEL)                        # yoke
	for s: float in [-1.0, 1.0]:
		g.cyl(Vector3(s * 0.05, 0, 0.55), Vector3(s * 0.28, -0.05, 0.75), 0.02, 5, STEEL)  # spade handles
		g.box(Vector3(s * 0.3, -0.06, 0.77), Vector3(0.025, 0.06, 0.025), LEATHER)
	g.box(Vector3(0, 0.07, -1.62), Vector3(0.05, 0.04, 0.08), STEEL)                    # igniter
	g.box(Vector3(0, 0.12, -0.4), Vector3(0.22, 0.16, 0.012), OLIVE, Basis(Vector3.RIGHT, -0.15))  # small shield
	g.cyl(Vector3(0, -0.05, 0.5), Vector3(0, -0.2, 0.62), 0.035, 6, RUBBER)
	return g


## The hand pump (keeps the pressure up), origin on the ground.
static func heavy_pump() -> TrainGeo:
	var g := TrainGeo.new()
	g.box(Vector3(0, 0.04, 0), Vector3(0.2, 0.04, 0.14), WOOD)
	g.cyl(Vector3(0, 0.08, 0), Vector3(0, 0.6, 0), 0.06, 8, OLIVE_DARK)
	g.lump(Vector3(0.12, 0.25, 0.0), 0.07, STEEL)
	return g


## The pump handle (pivot at the pump top, handle along +X).
static func pump_handle() -> TrainGeo:
	var g := TrainGeo.new()
	g.cyl(Vector3(-0.1, 0, 0), Vector3(0.55, 0, 0), 0.016, 5, STEEL)
	g.box(Vector3(0.55, 0, 0), Vector3(0.025, 0.025, 0.12), WOOD)
	return g


# ---------------------------------------------------------------- the flame tank

## The projector in the light tank's mantlet (origin on the gun's elevation pivot, pointing -Z).
static func tank_projector() -> TrainGeo:
	var g := TrainGeo.new()
	g.cyl(Vector3(0, 0, -0.2), Vector3(0, 0, -1.05), 0.075, 8, OLIVE_DARK)
	g.cyl(Vector3(0, 0, -1.05), TANK_NOZZLE, 0.09, 8, BLACK, 0.06)
	g.cyl(Vector3(0, 0, -0.55), Vector3(0, 0, -0.7), 0.09, 8, OLIVE)                    # collar
	g.box(Vector3(0, 0.1, -1.08), Vector3(0.05, 0.04, 0.08), STEEL)                     # igniter
	g.cyl(Vector3(0.06, 0.1, -1.02), Vector3(0.06, 0.1, -1.18), 0.012, 5, BRASS)
	return g


## Two armoured fuel drums and a pipe, on the rear deck (tank body frame).
static func tank_fuel() -> TrainGeo:
	var g := TrainGeo.new()
	for s: float in [-1.0, 1.0]:
		var x := s * 0.42
		g.cyl(Vector3(x, 1.38, 1.05), Vector3(x, 1.38, 1.95), 0.24, 10, OLIVE)
		g.lump(Vector3(x, 1.38, 1.96), 0.24, OLIVE_DARK, Vector3(1, 1, 0.3))
		g.lump(Vector3(x, 1.38, 1.04), 0.24, OLIVE_DARK, Vector3(1, 1, 0.3))
		for z: float in [1.2, 1.8]:
			g.cyl(Vector3(x, 1.38, z - 0.02), Vector3(x, 1.38, z + 0.02), 0.25, 10, STEEL)  # bands
		g.cyl(Vector3(x, 1.38, 1.5), Vector3(x * 0.4, 1.62, 1.0), 0.03, 6, RUBBER)
		g.box(Vector3(x, 1.18, 1.5), Vector3(0.2, 0.05, 0.5), STEEL)
	g.cyl(Vector3(-0.17, 1.62, 1.0), Vector3(0.17, 1.62, 1.0), 0.03, 6, STEEL)
	g.box(Vector3(0, 1.5, 0.85), Vector3(0.2, 0.08, 0.1), OLIVE_DARK)                   # pipe through the deck
	return g


# ---------------------------------------------------------------- the flame wagon

## A flame wagon for the armoured trains: an armoured flat car carrying two big fuel tanks, a pump house and a
## projector turret that swings round. Built like TrainParts' gun flat (same frame, buffers, wheels and far look).
static func wagon() -> TrainCar:
	var car := TrainCar.new()
	car.kind = "flamewagon"
	car.name = "FlameWagon"
	car.body = Node3D.new()
	car.body.name = "Body"
	car.add_child(car.body)
	car.front_z = -4.05
	car.rear_z = 4.05
	car.pivot_f = -2.3
	car.pivot_r = 2.3
	car.mass = 26000.0
	car.col_box = AABB(Vector3(-1.4, 0.0, -4.05), Vector3(2.8, 2.9, 8.1))
	car.com_y = 1.3
	for z: float in [-2.3, 2.3]:
		TrainParts._wheelset(car, z, 0.48, false)
	var m := TrainParts.material()
	var g := TrainGeo.new()
	TrainParts._wagon_frame(car, g, 3.6, [-2.3, 2.3], 1.06)
	TrainParts._buffers(car, g, -3.67, 3.67)
	for k in 9:
		var z := -3.4 + float(k) * 0.85
		g.box(Vector3(0, 1.13, z), Vector3(1.34, 0.07, 0.41), TrainParts.WOOD if k % 2 == 0 else TrainParts.WOOD_LIGHT)
	g.make(car.body, "Frame", m)

	var a := TrainGeo.new()
	# Armour skirts and the end plates.
	for s: float in [-1.0, 1.0]:
		a.box(Vector3(s * 1.31, 1.55, 0), Vector3(0.035, 0.36, 3.5), OLIVE, Basis(Vector3(0, 0, 1), s * 0.1))
	for e: float in [-1.0, 1.0]:
		a.box(Vector3(0, 1.52, e * 3.48), Vector3(1.3, 0.33, 0.035), OLIVE)
	# Two fuel tanks lying lengthways at the rear, banded, with the danger band.
	for s: float in [-1.0, 1.0]:
		var x := s * 0.62
		a.cyl(Vector3(x, 1.72, 0.55), Vector3(x, 1.72, 3.2), 0.5, 12, OLIVE_DARK)
		a.lump(Vector3(x, 1.72, 3.2), 0.5, OLIVE_DARK, Vector3(1, 1, 0.25))
		a.lump(Vector3(x, 1.72, 0.55), 0.5, OLIVE_DARK, Vector3(1, 1, 0.25))
		for z: float in [1.0, 2.0, 2.8]:
			a.cyl(Vector3(x, 1.72, z - 0.03), Vector3(x, 1.72, z + 0.03), 0.51, 12, STEEL)
		a.cyl(Vector3(x, 1.72, 1.45), Vector3(x, 1.72, 1.6), 0.51, 12, RED)
		a.box(Vector3(x, 1.22, 1.9), Vector3(0.12, 0.08, 1.2), STEEL)                 # cradles
		a.cyl(Vector3(x, 2.22, 2.4), Vector3(x, 2.34, 2.4), 0.05, 8, BRASS)          # fillers
	# The pump house between the tanks and the turret.
	a.box(Vector3(0, 1.6, -0.15), Vector3(0.9, 0.42, 0.45), OLIVE)
	a.box(Vector3(0, 2.05, -0.15), Vector3(0.95, 0.04, 0.5), OLIVE_DARK)
	a.cyl(Vector3(0.5, 2.09, -0.1), Vector3(0.5, 2.5, -0.1), 0.06, 8, BLACK)          # pump exhaust
	a.box(Vector3(-0.92, 1.6, -0.15), Vector3(0.02, 0.2, 0.18), BLACK)                # door
	a.cyl(Vector3(0, 1.75, 0.3), Vector3(0, 1.4, -1.5), 0.05, 6, RUBBER)              # feed pipe to the turret
	for p: Array in [[-0.95, -3.0], [0.95, -3.0], [0.0, -3.1]]:
		a.lump(Vector3(p[0], 1.42, p[1]), 0.3, SANDBAG, Vector3(1.0, 0.55, 0.8))
	a.make(car.body, "Armour", m)

	# The turret: a round armoured drum that swings, the projector on a cradle.
	var mount := Node3D.new()
	mount.name = "GunMount"
	mount.position = Vector3(0, 1.2, -1.85)
	car.add_child(mount)
	var mg := TrainGeo.new()
	mg.cyl(Vector3(0, 0, 0), Vector3(0, 0.1, 0), 0.95, 12, BLACK)
	mg.cyl(Vector3(0, 0.1, 0), Vector3(0, 1.05, 0), 0.82, 10, OLIVE, 0.74)
	mg.cyl(Vector3(0, 1.05, 0), Vector3(0, 1.14, 0), 0.74, 10, OLIVE_DARK, 0.5)
	mg.box(Vector3(0, 1.2, 0.2), Vector3(0.22, 0.08, 0.22), OLIVE_DARK)               # hatch
	mg.box(Vector3(0, 0.75, -0.78), Vector3(0.12, 0.03, 0.02), BLACK)                 # vision slit
	for s: float in [-1.0, 1.0]:
		mg.box(Vector3(s * 0.35, 0.62, -0.79), Vector3(0.05, 0.03, 0.02), BLACK)
	mg.make(mount, "Mesh", m)
	var cradle := Node3D.new()
	cradle.name = "Cradle"
	cradle.position = Vector3(0, 0.55, -0.7)
	mount.add_child(cradle)
	var cg := TrainGeo.new()
	cg.lump(Vector3(0, 0, -0.05), 0.2, OLIVE_DARK, Vector3(1.1, 1.0, 0.7))            # ball mount
	cg.make(cradle, "Mesh", m)
	var barrel := Node3D.new()
	barrel.name = "Barrel"
	cradle.add_child(barrel)
	var bg := TrainGeo.new()
	bg.cyl(Vector3(0, 0, 0.1), Vector3(0, 0, -1.7), 0.08, 8, OLIVE_DARK)
	bg.cyl(Vector3(0, 0, -1.7), WAGON_NOZZLE, 0.1, 8, BLACK, 0.07)
	bg.cyl(Vector3(0, 0, -0.9), Vector3(0, 0, -1.05), 0.1, 8, OLIVE)
	bg.box(Vector3(0, 0.12, -1.75), Vector3(0.06, 0.05, 0.1), STEEL)
	bg.make(barrel, "Mesh", m)
	car.gun_mount = mount
	car.gun_cradle = cradle
	car.gun_barrel = barrel
	car.marks["muzzle"] = mount.position + cradle.position + WAGON_NOZZLE
	car.marks["fire"] = Vector3(0, 1.8, 1.8)

	var fg := TrainGeo.new()
	fg.box(Vector3(0, 0.75, 0), Vector3(1.0, 0.6, 3.6), BLACK)
	fg.box(Vector3(0, 1.55, 0), Vector3(1.34, 0.36, 3.5), OLIVE)
	fg.box(Vector3(0, 1.85, 1.9), Vector3(1.1, 0.45, 1.3), OLIVE_DARK)
	fg.box(Vector3(0, 2.0, -1.85), Vector3(0.75, 0.45, 0.75), OLIVE)
	fg.box(Vector3(0, 1.75, -3.2), Vector3(0.08, 0.08, 0.9), OLIVE_DARK)
	car.far = fg.make(car, "Far", m)
	car.finish_lod()
	return car

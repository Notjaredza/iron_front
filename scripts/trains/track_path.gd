class_name TrackPath
extends RefCounted
## Iron Front: a track centre line as a polyline (metres, flat). Distance runs in the direction of travel.
## frame(d) gives a Transform3D on the line at rail-top height whose -Z points along the travel direction,
## the same as a car's forward.

var pts := PackedVector3Array()
var dist := PackedFloat32Array()


static func line(from: Vector3, to: Vector3) -> TrackPath:
	var p := TrackPath.new()
	p.pts = PackedVector3Array([from, to])
	p._measure()
	return p


## A straight run of length a from start along dir, then a curve of radius r turning by angle (radians, + = left),
## then a straight of length b.
static func straight_curve(start: Vector3, dir: Vector3, a: float, r: float, angle: float, b: float) -> TrackPath:
	var p := TrackPath.new()
	var d := dir.normalized()
	var at := start
	p.pts.append(at)
	at += d * a
	p.pts.append(at)
	var side := Vector3.UP.cross(d) * (1.0 if angle > 0.0 else -1.0)   # towards the curve's centre
	var centre := at + side * r
	var steps := maxi(4, int(absf(angle) * r / 2.0))
	var from_c := at - centre
	for i in range(1, steps + 1):
		var t := angle * float(i) / float(steps)
		var q := from_c.rotated(Vector3.UP, t)
		p.pts.append(centre + q)
	var last := p.pts[p.pts.size() - 1]
	var td := (last - p.pts[p.pts.size() - 2]).normalized()
	p.pts.append(last + td * b)
	p._measure()
	return p


func _measure() -> void:
	dist.resize(pts.size())
	dist[0] = 0.0
	for i in range(1, pts.size()):
		dist[i] = dist[i - 1] + pts[i].distance_to(pts[i - 1])


func length() -> float:
	return dist[dist.size() - 1]


func point(d: float) -> Vector3:
	var n := pts.size()
	if d <= 0.0:
		return pts[0] + (pts[1] - pts[0]).normalized() * d
	if d >= dist[n - 1]:
		return pts[n - 1] + (pts[n - 1] - pts[n - 2]).normalized() * (d - dist[n - 1])
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if dist[mid] <= d:
			lo = mid
		else:
			hi = mid
	var t := (d - dist[lo]) / maxf(dist[hi] - dist[lo], 1e-6)
	return pts[lo].lerp(pts[hi], t)


func frame(d: float) -> Transform3D:
	var a := point(d - 0.5)
	var b := point(d + 0.5)
	var fwd := (b - a).normalized()
	var z := -fwd
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), point(d))


## Where a car sits when its centre is d along the path: the line between its two support points.
func car_frame(d: float, car: TrainCar) -> Transform3D:
	var pf := point(d - car.pivot_f)
	var pr := point(d - car.pivot_r)
	var fwd := (pf - pr).normalized()
	var z := -fwd
	var x := Vector3.UP.cross(z).normalized()
	var mid := (pf + pr) * 0.5
	var off := (car.pivot_f + car.pivot_r) * 0.5
	return Transform3D(Basis(x, Vector3.UP, z), mid + fwd * off)

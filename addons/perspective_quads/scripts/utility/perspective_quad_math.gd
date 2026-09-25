## Static helpers for the four-point perspective (homography) behind
## [PerspectiveQuadShape]. This class helps bake a matrix from corners,
## invert it, and projects points back through it.
@tool
class_name PerspectiveQuadMath

## A Basis that is never a valid homography. Returned by [method compute_matrix]
## when the corner configuration is degenerate (e.g. opposing axes collapsed) so
## callers can tell "no valid transform" apart from a real (if odd) matrix.
const INVALID_MATRIX := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

## True when [param mat] is a usable homography. The zero [member INVALID_MATRIX]
## (and any matrix with a zero determinant) is not.
static func is_matrix_valid(mat: Basis) -> bool:
	return mat != INVALID_MATRIX and not is_zero_approx(mat.determinant())

## Bounding box of the polygon [param poly].
static func get_bounds(poly: PackedVector2Array) -> Rect2:
	var min_pt := poly[0]
	var max_pt := poly[0]
	for i: int in range(1, poly.size()):
		min_pt = min_pt.min(poly[i])
		max_pt = max_pt.max(poly[i])
	return Rect2(min_pt, max_pt - min_pt)

## How far [param bounds] reaches on the negative side of the plane. Never positive.
static func compute_frame_offset(bounds: Rect2) -> Vector2:
	return Vector2(minf(bounds.position.x, 0.0),
				   minf(bounds.position.y, 0.0))

## Size holding [param bounds] from [param offset], at least one unit per axis
## so degenerate quads stay renderable.
static func compute_frame_size(offset: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(maxf(bounds.position.x + bounds.size.x, 1.0) - offset.x,
				   maxf(bounds.position.y + bounds.size.y, 1.0) - offset.y)

## Homography mapping the unit square's (0, 0), (1, 0), (1, 1) and (0, 1)
## corners onto [param t_l], [param t_r], [param b_r] and [param b_l]. Returns
## [constant INVALID_MATRIX] when the corners are degenerate.
static func compute_matrix(t_l: Vector2, t_r: Vector2,
						   b_r: Vector2, b_l: Vector2) -> Basis:
	var dx1 := t_r.x - b_r.x
	var dx2 := b_l.x - b_r.x
	var dx3 := t_l.x - t_r.x + b_r.x - b_l.x
	var dy1 := t_r.y - b_r.y
	var dy2 := b_l.y - b_r.y
	var dy3 := t_l.y - t_r.y + b_r.y - b_l.y
	
	var denom := dx1 * dy2 - dy1 * dx2
	if is_zero_approx(denom): return INVALID_MATRIX
	
	var a13 := (dx3 * dy2 - dy3 * dx2) / denom
	var a23 := (dx1 * dy3 - dy1 * dx3) / denom
	var a11 := t_r.x - t_l.x + a13 * t_r.x
	var a21 := b_l.x - t_l.x + a23 * b_l.x
	var a31 := t_l.x
	var a12 := t_r.y - t_l.y + a13 * t_r.y
	var a22 := b_l.y - t_l.y + a23 * b_l.y
	var a32 := t_l.y
	
	var transform_mat := Basis(Vector3(a11, a12, a13),
							   Vector3(a21, a22, a23),
							   Vector3(a31, a32, 1.0))
	return transform_mat

## Inverse of [method compute_matrix], or [constant INVALID_MATRIX] when
## the corners are degenerate.
static func compute_matrix_inv(t_l: Vector2, t_r: Vector2,
							   b_r: Vector2, b_l: Vector2) -> Basis:
	var mat := compute_matrix(t_l, t_r, b_r, b_l)
	if not is_matrix_valid(mat): return INVALID_MATRIX
	return mat.inverse()

## Maps [param point] through [param mat_inv] as a UV coordinate, or
## ([code]NAN[/code], [code]NAN[/code]) when the matrix is invalid.
static func project_inv(mat_inv: Basis, point: Vector2) -> Vector2:
	if not is_matrix_valid(mat_inv): return Vector2(NAN, NAN)
	var result: Vector3 = mat_inv * Vector3(point.x, point.y, 1.0)
	if is_zero_approx(result.z): return Vector2(NAN, NAN)
	return Vector2(result.x / result.z, result.y / result.z)

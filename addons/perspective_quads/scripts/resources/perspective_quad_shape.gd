## One perspective-warped quad: four corner positions in frame space plus the
## homography baked from them.
## [br][br]
## Corner coordinates can extend outside 0..1. Writing any corner marks the shape
## dirty, so [member perspective_matrix], [member perspective_matrix_inv],
## [member frame_size] and [member frame_offset] are recomputed on the next read.
@tool
@icon("uid://dimwtf66honrx")
class_name PerspectiveQuadShape
extends Resource

@export_storage var _modulate := Color.WHITE
## The color that this shape's pixels are multipled by.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR)
var modulate := Color.WHITE: get = get_modulate, set = set_modulate

@export_group("Corners")
@export_storage var _corners: PackedVector2Array = [Vector2.ZERO, Vector2.RIGHT,
													Vector2.ONE, Vector2.DOWN]
## Position of the top-left corner.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR)
var top_left := Vector2.ZERO:    get = get_top_left,     set = set_top_left

## Position of the top-right corner.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR)
var top_right := Vector2.RIGHT:  get = get_top_right,    set = set_top_right

## Position of the bottom-right corner.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR)
var bottom_right := Vector2.ONE: get = get_bottom_right, set = set_bottom_right

## Position of the bottom-left corner.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR)
var bottom_left := Vector2.DOWN: get = get_bottom_left,  set = set_bottom_left

@export_group("Baked Values")
@export_storage var _perspective_matrix := Basis.IDENTITY
## Homography mapping the unit square onto this shape's corners.
## Read-only value.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var perspective_matrix: Basis: get = get_perspective_matrix, set = _set_nothing

@export_storage var _perspective_matrix_inv := Basis.IDENTITY
## Inverse of [member perspective_matrix], taking plane points back to UVs.
## Read-only value.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var perspective_matrix_inv: Basis: get = get_perspective_matrix_inv, set = _set_nothing

@export_storage var _frame_size := Vector2.ONE
## Size of the warped quad's bounding box in frame space.
## Read-only value.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var frame_size: Vector2: get = get_frame_size, set = _set_nothing

@export_storage var _frame_offset := Vector2.ZERO
## Offset of the warped quad's bounding box.
## Read-only value.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var frame_offset: Vector2: get = get_frame_offset, set = _set_nothing

@export_storage var _dirty := true

#region Property accessors

func get_modulate() -> Color: return _modulate

func set_modulate(value: Color) -> void: _modulate = value; emit_changed()

func _get_corners() -> PackedVector2Array:  return _corners
## Every corner as a copy, in [member top_left], [member top_right],
## [member bottom_right], [member bottom_left] order.
func get_corners() -> PackedVector2Array:   return _corners.duplicate()
## The corner at [param corner].
func get_corner(corner: Corner) -> Vector2: return _corners[corner]

## Writes up to four corners from [param corners], in the order [method get_corners] returns.
func set_corners(corners: PackedVector2Array) -> void:
	_own_corners_if_editor()
	for i: int in mini(corners.size(), 4):
		_corners[i] = corners[i]
	_mark_dirty()

## Writes all four corners at once.
func set_each_corner(t_l: Vector2, t_r: Vector2, b_r: Vector2, b_l: Vector2) -> void:
	_own_corners_if_editor()
	_corners[Corner.CORNER_TOP_LEFT]     = t_l
	_corners[Corner.CORNER_TOP_RIGHT]    = t_r
	_corners[Corner.CORNER_BOTTOM_RIGHT] = b_r
	_corners[Corner.CORNER_BOTTOM_LEFT]  = b_l
	_mark_dirty()

## Writes the corner at [param corner].
func set_corner(corner: Corner, value: Vector2) -> void:
	_own_corners_if_editor()
	_corners[corner] = value
	_mark_dirty()

func get_top_left()     -> Vector2: return get_corner(Corner.CORNER_TOP_LEFT)
func get_top_right()    -> Vector2: return get_corner(Corner.CORNER_TOP_RIGHT)
func get_bottom_right() -> Vector2: return get_corner(Corner.CORNER_BOTTOM_RIGHT)
func get_bottom_left()  -> Vector2: return get_corner(Corner.CORNER_BOTTOM_LEFT)

func set_top_left(value: Vector2) -> void:     set_corner(Corner.CORNER_TOP_LEFT, value)
func set_top_right(value: Vector2) -> void:    set_corner(Corner.CORNER_TOP_RIGHT, value)
func set_bottom_right(value: Vector2) -> void: set_corner(Corner.CORNER_BOTTOM_RIGHT, value)
func set_bottom_left(value: Vector2) -> void:  set_corner(Corner.CORNER_BOTTOM_LEFT, value)

func get_perspective_matrix()     -> Basis: _bake(); return _perspective_matrix
func get_perspective_matrix_inv() -> Basis: _bake(); return _perspective_matrix_inv
func get_frame_size()   -> Vector2: _bake(); return _frame_size
func get_frame_offset() -> Vector2: _bake(); return _frame_offset

func _set_nothing(_value): pass

#endregion

#region Corner ownership

# Due to how the Godot editor's Resource duplication currently uses
# shallow duplication, this needs to be worked around with the _corners
# array manually duplicating itself prior to it being written to.
# ---
# More details on this specific oversight here:
# https://github.com/godotengine/godot/issues/123646
# ---
# As a side note, if you want to safely duplicate a PerspectiveQuadShape
# during runtime, use duplicate_deep(Resource.DEEP_DUPLICATE_NONE) to
# make sure the _corners array is properly duplicated. This also goes
# with any other resource that stores arrays or dictionaries.
func _own_corners_if_editor() -> void:
	if Engine.is_editor_hint(): _own_corners()

func _own_corners() -> void:
	_corners = _corners.duplicate()

#endregion

#region Baking

func _mark_dirty() -> void:
	_dirty = true
	emit_changed()

# Recomputes trans/trans_inv/frame_size/frame_offset from the current corners.
func _bake(force: bool = false) -> void:
	if not (_dirty or force): return
	var bounds := PerspectiveQuadMath.get_bounds(_corners)
	_frame_offset = PerspectiveQuadMath.compute_frame_offset(bounds)
	_frame_size   = PerspectiveQuadMath.compute_frame_size(_frame_offset, bounds)
	_perspective_matrix = PerspectiveQuadMath.compute_matrix(top_left, top_right,
															 bottom_right, bottom_left)
	if PerspectiveQuadMath.is_matrix_valid(_perspective_matrix):
		_perspective_matrix_inv = _perspective_matrix.inverse()
	else:
		_perspective_matrix_inv = PerspectiveQuadMath.INVALID_MATRIX
	_dirty = false

#endregion

## Tracks a [Carousel2D]'s view position and moves itself by
## interpolating keyframe transforms stored in internal parallel arrays.
@tool
@icon("uid://dn173nt05sarw")
class_name CarouselAnchor2D
extends Node2D

## Emitted when the shape of the keyframe list changes.
## This happens when a keyframe is added, removed, reordered, or when
## [method set_keyframe_snapshot] replaces the whole list.
signal keyframes_changed

enum _Field { POSITION, ROTATION, SKEW, SCALE, MODULATE }

const _KEYFRAME_PREFIX: String = "keyframe/"
const _KEYFRAME_FIELDS: PackedStringArray = [
	"position", "rotation",
	"skew", "scale", "modulate"
]
const _KEYFRAME_TYPES: PackedByteArray = [
	TYPE_VECTOR2, TYPE_FLOAT,
	TYPE_FLOAT, TYPE_VECTOR2, TYPE_COLOR
]
const _KEYFRAME_HINTS: PackedByteArray = [
	PROPERTY_HINT_NONE, PROPERTY_HINT_RANGE,
	PROPERTY_HINT_RANGE, PROPERTY_HINT_LINK, PROPERTY_HINT_NONE
]
const _KEYFRAME_HINT_STRINGS: PackedStringArray = [
	"suffix:px", "-360,360,0.1,radians_as_degrees,or_greater,or_less",
	"-89.9,89.9,0.1,radians_as_degrees", "", ""
]

const _FIELD_BITS: int = 3
const _FIELD_MASK: int = (1 << _FIELD_BITS) - 1
const _NOT_A_KEYFRAME: int = -1

const _REVERT_PROPERTIES: Array = [Vector2.ZERO, 0.0, 0.0, Vector2.ONE, Color.WHITE]

#region Keyframe storage

# Per-keyframe local position offsets.
@export_storage var _positions: PackedVector2Array
# Per-keyframe rotations in radians.
@export_storage var _rotations: PackedFloat32Array
# Per-keyframe skew angles in radians (-89.9..89.9).
@export_storage var _skews: PackedFloat32Array
# Per-keyframe scale factors.
@export_storage var _scales: PackedVector2Array
# Per-keyframe modulate colors.
@export_storage var _modulates: PackedColorArray

#endregion

#region Public properties

## The driving carousel.
## If empty, the closest ancestor [Carousel2D] is used.
@export var carousel: Carousel2D:
	get = get_carousel, set = set_carousel

## If true, rotation interpolates along the shortest angular path.
@export var use_shortest_rotation: bool = true:
	get = get_use_shortest_rotation, set = set_use_shortest_rotation

@export_group("Keyframes", "keyframe_")
## Number of keyframes.
@export var keyframe_count: int = 0:
	get = get_keyframe_count, set = set_keyframe_count

#endregion

#region Property accessors

func get_carousel() -> Carousel2D: return carousel

func set_carousel(value: Carousel2D) -> void:
	if carousel == value: return
	if is_inside_tree():
		_unsubscribe(_get_carousel())
	carousel = value
	if is_inside_tree():
		_subscribe(_get_carousel())
	refresh()

func get_use_shortest_rotation() -> bool: return use_shortest_rotation

func set_use_shortest_rotation(value: bool) -> void:
	use_shortest_rotation = value
	_mark_data_changed()
	refresh()

func get_keyframe_count() -> int: return keyframe_count

func set_keyframe_count(value: int) -> void:
	value = maxi(value, 0)
	if value == keyframe_count: return
	_resize_arrays(value)
	keyframe_count = value
	notify_property_list_changed()
	_mark_data_changed()
	refresh()

#endregion

#region Internal state

var _data_version: int = 0

var _cache_valid: bool = false
var _last_t: float = 0.0
var _last_version: int = -1
var _last_transform := Transform2D()
var _last_modulate := Color.WHITE

var _nil_range_dirty: bool = true
var _first_non_nil: int = -1
var _last_non_nil:  int = -1

#endregion


#region Public API

## Local position offset of keyframe [param idx], or [constant Vector2.ZERO]
## when [param idx] is out of range.
## [br][br]
## If negative, [param idx] is considered relative to the last keyframe.
func get_keyframe_position(idx: int) -> Vector2:
	return _positions[idx] if absi(idx) < _positions.size() else Vector2.ZERO

## Sets [method get_keyframe_position].
## Writes to an out-of-range [param idx] are ignored.
## [br][br]
## If negative, [param idx] is considered relative to the last keyframe.
func set_keyframe_position(idx: int, value: Vector2) -> void:
	if absi(idx) < _positions.size(): _positions[idx] = value
	_mark_data_changed()
	refresh()

## Rotation of keyframe [param idx] in radians, or 0.0 when out of range.
## [br][br]
## If negative, [param idx] is considered relative to the last keyframe.
func get_keyframe_rotation(idx: int) -> float:
	return _rotations[idx] if absi(idx) < _rotations.size() else 0.0

## Sets [method get_keyframe_rotation].
## Writes to an out-of-range [param idx] are ignored.
## [br][br]
## If negative, [param idx] is considered relative to the last keyframe.
func set_keyframe_rotation(idx: int, value: float) -> void:
	if absi(idx) < _rotations.size(): _rotations[idx] = value
	_mark_data_changed()
	refresh()

## Degrees-facing view of [method get_keyframe_rotation], matching the
## radian-formatted rotation controls in the inspector.
func get_keyframe_rotation_deg(idx: int) -> float:
	return rad_to_deg(get_keyframe_rotation(idx))

## Sets [method get_keyframe_rotation] from a value in degrees.
func set_keyframe_rotation_deg(idx: int, value: float) -> void:
	set_keyframe_rotation(idx, deg_to_rad(value))

## Skew angle of keyframe [param idx] in radians (-89.9..89.9), or 0.0 when
## out of range.
## [br][br]
## If negative, [param idx] is considered relative to the last keyframe.
func get_keyframe_skew(idx: int) -> float:
	return _skews[idx] if absi(idx) < _skews.size() else 0.0

## Sets [method get_keyframe_skew].
## Writes to an out-of-range [param idx] are ignored.
## [br][br]
## If negative, [param idx] is considered relative to the last keyframe.
func set_keyframe_skew(idx: int, value: float) -> void:
	if absi(idx) < _skews.size(): _skews[idx] = value
	_mark_data_changed()
	refresh()

## Degrees-facing view of [method get_keyframe_skew].
func get_keyframe_skew_deg(idx: int) -> float:
	return rad_to_deg(get_keyframe_skew(idx))

## Sets [method get_keyframe_skew] from a value in degrees.
func set_keyframe_skew_deg(idx: int, value: float) -> void:
	set_keyframe_skew(idx, deg_to_rad(value))

## Scale factor of keyframe [param idx], or [constant Vector2.ONE] when out
## of range.
func get_keyframe_scale(idx: int) -> Vector2:
	return _scales[idx] if absi(idx) < _scales.size() else Vector2.ONE

## Sets [method get_keyframe_scale]. Writing [constant Vector2.ZERO] marks the
## keyframe as unset, and writes to an out-of-range [param idx] are ignored.
## [br][br]
## If negative, [param idx] is considered relative to the last keyframe.
func set_keyframe_scale(idx: int, value: Vector2) -> void:
	if absi(idx) < _scales.size(): _scales[idx] = value
	_mark_data_changed()
	_nil_range_dirty = true # scale doubles as the "keyframe is unset" sentinel
	refresh()

## Modulate color of keyframe [param idx], or [constant Color.WHITE] when out
## of range.
## [br][br]
## If negative, [param idx] is considered relative to the last keyframe.
func get_keyframe_modulate(idx: int) -> Color:
	return _modulates[idx] if absi(idx) < _modulates.size() else Color.WHITE

## Sets [method get_keyframe_modulate].
## Writes to an out-of-range [param idx] are ignored.
## [br][br]
## If negative, [param idx] is considered relative to the last keyframe.
func set_keyframe_modulate(idx: int, value: Color) -> void:
	if absi(idx) < _modulates.size(): _modulates[idx] = value
	_mark_data_changed()
	refresh()

## Inserts a new keyframe at [param at_index] with default values.
## Pass -1 to append.
func add_keyframe(at_index: int = -1) -> void:
	var insert_at := keyframe_count if at_index < 0 else at_index
	insert_keyframe(insert_at, Vector2.ZERO, 0.0, Vector2.ONE, 0.0, Color.WHITE)

## Inserts a keyframe at [param at_index] with explicit values, shifting
## later keyframes right. [param at_index] must be in [0, keyframe_count].
func insert_keyframe(at_index: int, position: Vector2, rotation: float,
					 scale: Vector2, skew: float, modulate: Color) -> void:
	if at_index < 0 or at_index > keyframe_count: return
	var new_count := keyframe_count + 1
	_resize_arrays(new_count)
	if at_index < new_count - 1:
		for i: int in range(new_count - 2, at_index - 1, -1):
			_positions[i + 1] = _positions[i]
			_rotations[i + 1] = _rotations[i]
			_skews[i + 1]     = _skews[i]
			_scales[i + 1]    = _scales[i]
			_modulates[i + 1] = _modulates[i]
	_positions[at_index] = position
	_rotations[at_index] = rotation
	_skews[at_index]     = skew
	_scales[at_index]    = scale
	_modulates[at_index] = modulate
	keyframe_count = new_count
	_mark_data_changed()
	_nil_range_dirty = true
	keyframes_changed.emit()

## Removes the keyframe at [param at_index].
func remove_keyframe(at_index: int) -> void:
	if at_index < 0 or at_index >= keyframe_count: return
	var new_count := keyframe_count - 1
	for i: int in range(at_index, new_count):
		_positions[i] = _positions[i + 1]
		_rotations[i] = _rotations[i + 1]
		_skews[i]     = _skews[i + 1]
		_scales[i]    = _scales[i + 1]
		_modulates[i] = _modulates[i + 1]
	_resize_arrays(new_count)
	keyframe_count = new_count
	_mark_data_changed()
	_nil_range_dirty = true
	keyframes_changed.emit()

## Moves keyframe [param from_index] to [param to_index], shifting others.
func move_keyframe(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= keyframe_count: return
	if to_index < 0 or to_index >= keyframe_count: return
	if from_index == to_index: return
	
	var tmp_pos   := _positions[from_index]
	var tmp_rot   := _rotations[from_index]
	var tmp_skew  := _skews[from_index]
	var tmp_scale := _scales[from_index]
	var tmp_mod   := _modulates[from_index]
	
	if from_index < to_index:
		for i: int in range(from_index, to_index):
			_positions[i] = _positions[i + 1]
			_rotations[i] = _rotations[i + 1]
			_skews[i]     = _skews[i + 1]
			_scales[i]    = _scales[i + 1]
			_modulates[i] = _modulates[i + 1]
	else:
		for i: int in range(from_index, to_index, -1):
			_positions[i] = _positions[i - 1]
			_rotations[i] = _rotations[i - 1]
			_skews[i]     = _skews[i - 1]
			_scales[i]    = _scales[i - 1]
			_modulates[i] = _modulates[i - 1]
	
	_positions[to_index] = tmp_pos
	_rotations[to_index] = tmp_rot
	_skews[to_index]     = tmp_skew
	_scales[to_index]    = tmp_scale
	_modulates[to_index] = tmp_mod
	_mark_data_changed()
	_nil_range_dirty = true
	refresh()
	keyframes_changed.emit()

## Returns a self-contained copy of every stored keyframe value, resized to
## [param count] (or the current [member keyframe_count] when negative).
func get_keyframe_snapshot(count: int = -1) -> Array:
	var target: int = maxi(keyframe_count if count < 0 else count, 0)
	return [
		target,
		_resized_vec2(_positions,  target, Vector2.ZERO),
		_resized_float(_rotations, target, 0.0),
		_resized_float(_skews,     target, 0.0),
		_resized_vec2(_scales,     target, Vector2.ONE),
		_resized_color(_modulates, target, Color.WHITE),
	]

## Restores a snapshot handed out by [method get_keyframe_snapshot], count
## included. The one way back for keyframes a shrink dropped.
func set_keyframe_snapshot(snapshot: Array) -> void:
	if snapshot.size() != 6: return
	var positions: PackedVector2Array = snapshot[1]
	var rotations: PackedFloat32Array = snapshot[2]
	var skews: PackedFloat32Array     = snapshot[3]
	var scales: PackedVector2Array    = snapshot[4]
	var modulates: PackedColorArray   = snapshot[5]
	var target: int = maxi(int(snapshot[0]), 0)
	var count_changed := target != keyframe_count
	
	_positions = positions
	_rotations = rotations
	_skews     = skews
	_scales    = scales
	_modulates = modulates
	keyframe_count = target
	
	_mark_data_changed()
	_nil_range_dirty = true
	
	if not count_changed: notify_property_list_changed()
	refresh()
	keyframes_changed.emit()

#endregion

#region Resize helpers

func _mark_data_changed() -> void: _data_version += 1

static func _resized_vec2(arr: PackedVector2Array, size: int, fill: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(size)
	var keep := mini(arr.size(), size)
	for i: int in keep: out[i] = arr[i]
	for i: int in range(keep, size): out[i] = fill
	return out

static func _resized_float(arr: PackedFloat32Array, size: int, fill: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(size)
	var keep := mini(arr.size(), size)
	for i: int in keep: out[i] = arr[i]
	for i: int in range(keep, size): out[i] = fill
	return out

static func _resized_color(arr: PackedColorArray, size: int, fill: Color) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(size)
	var keep := mini(arr.size(), size)
	for i: int in keep: out[i] = arr[i]
	for i: int in range(keep, size): out[i] = fill
	return out

func _resize_arrays(new_size: int) -> void:
	var positions_need_resize := new_size != _positions.size()
	var rotations_need_resize := new_size != _rotations.size()
	var skews_need_resize     := new_size != _skews.size()
	var scales_need_resize    := new_size != _scales.size()
	var modulates_need_resize := new_size != _modulates.size()
	
	if (not positions_need_resize) and \
	   (not rotations_need_resize) and \
	   (not skews_need_resize)     and \
	   (not scales_need_resize)    and \
	   (not modulates_need_resize): return
	
	if positions_need_resize:
		_positions = _resized_vec2(_positions, new_size, Vector2.ZERO)
	if rotations_need_resize:
		_rotations = _resized_float(_rotations, new_size, 0.0)
	if skews_need_resize:
		_skews     = _resized_float(_skews, new_size, 0.0)
	if scales_need_resize:
		_scales    = _resized_vec2(_scales, new_size, Vector2.ONE)
	if modulates_need_resize:
		_modulates = _resized_color(_modulates, new_size, Color.WHITE)
	
	_mark_data_changed()
	_nil_range_dirty = true

#endregion

#region Property list

static var _name_rows: Array[PackedStringArray] = []
static var _parse_cache: Dictionary[StringName, int] = {}

var _property_list: Array[Dictionary] = []
var _property_list_count: int = -1

static func _pack_keyframe_property(index: int, field: int) -> int:
	if index < 0 or field < 0 or field > _FIELD_MASK: return _NOT_A_KEYFRAME
	return (index << _FIELD_BITS) | field

static func _keyframe_property_index(kf: int) -> int:
	if kf < 0: return -1
	return kf >> _FIELD_BITS

static func _keyframe_property_field(kf: int) -> int:
	if kf < 0: return -1
	return kf & _FIELD_MASK

static func _keyframe_name_row(idx: int) -> PackedStringArray:
	if idx < 0: return PackedStringArray()
	
	var current_size := _name_rows.size()
	if current_size > idx: return _name_rows[idx]
	
	var new_size := idx + 1
	_name_rows.resize(new_size)
	for i: int in range(current_size, new_size):
		var prefix := "%s%d_" % [_KEYFRAME_PREFIX, i]
		var row := PackedStringArray()
		row.resize(_KEYFRAME_FIELDS.size() + 1)
		row[0] = prefix
		
		for k: int in _KEYFRAME_FIELDS.size():
			var kf_name := prefix + _KEYFRAME_FIELDS[k]
			row[k + 1] = kf_name
			_parse_cache[StringName(kf_name)] = _pack_keyframe_property(i, k)
		
		_name_rows[i] = row
	
	return _name_rows[idx]

func _get_property_list() -> Array[Dictionary]:
	if _property_list_count != keyframe_count:
		_property_list = _build_property_list()
		_property_list_count = keyframe_count
	var copy: Array[Dictionary] = []
	copy.assign(_property_list)
	return copy

func _build_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var field_count := _KEYFRAME_FIELDS.size()
	list.resize(keyframe_count * (field_count + 1))
	
	var n := 0
	for i: int in keyframe_count:
		var row := _keyframe_name_row(i)
		list[n] = _keyframe_group(row[0])
		n += 1
		for k: int in field_count:
			list[n] = _keyframe_property(row[k + 1], k)
			n += 1
	return list

static func _keyframe_group(prefix: String) -> Dictionary:
	return {
		"name": "Keyframes",
		"type": TYPE_NIL,
		"hint_string": prefix,
		"usage": PROPERTY_USAGE_GROUP,
	}

static func _keyframe_property(prop_name: String, k: int) -> Dictionary:
	return {
		"name": prop_name,
		"type": _KEYFRAME_TYPES[k],
		"hint": _KEYFRAME_HINTS[k],
		"hint_string": _KEYFRAME_HINT_STRINGS[k],
		"usage": PROPERTY_USAGE_EDITOR,
	}

func _get(property: StringName) -> Variant:
	var kf := _resolve_keyframe_property(property)
	if kf < 0: return null
	var idx := _keyframe_property_index(kf)
	match _keyframe_property_field(kf):
		_Field.POSITION: return get_keyframe_position(idx)
		_Field.ROTATION: return get_keyframe_rotation(idx)
		_Field.SKEW:     return get_keyframe_skew(idx)
		_Field.SCALE:    return get_keyframe_scale(idx)
		_Field.MODULATE: return get_keyframe_modulate(idx)
	return null

func _set(property: StringName, value: Variant) -> bool:
	var kf := _resolve_keyframe_property(property)
	if kf < 0: return false
	var idx := _keyframe_property_index(kf)
	match _keyframe_property_field(kf):
		_Field.POSITION: set_keyframe_position(idx, value)
		_Field.ROTATION: set_keyframe_rotation(idx, value)
		_Field.SKEW:     set_keyframe_skew(idx, value)
		_Field.SCALE:    set_keyframe_scale(idx, value)
		_Field.MODULATE: set_keyframe_modulate(idx, value)
		_: return false
	return true

func _property_can_revert(property: StringName) -> bool:
	return _resolve_keyframe_property(property) >= 0

func _property_get_revert(property: StringName) -> Variant:
	var kf := _resolve_keyframe_property(property)
	if kf < 0: return null
	
	var field := _keyframe_property_field(kf)
	return _REVERT_PROPERTIES[field]

static func _parse_keyframe_property(prop_name: StringName) -> int:
	var cached: Variant = _parse_cache.get(prop_name)
	if cached != null: return cached
	
	var prop_name_str := String(prop_name)
	if prop_name_str.begins_with(_KEYFRAME_PREFIX):
		var rest := prop_name_str.substr(_KEYFRAME_PREFIX.length())
		var sep := rest.find("_")
		if sep > 0:
			var idx_str := rest.substr(0, sep)
			var field := _KEYFRAME_FIELDS.find(rest.substr(sep + 1))
			if idx_str.is_valid_int() and field >= 0:
				var parsed := _pack_keyframe_property(idx_str.to_int(), field)
				_parse_cache[prop_name] = parsed
				return parsed
	
	_parse_cache[prop_name] = _NOT_A_KEYFRAME
	return _NOT_A_KEYFRAME

func _resolve_keyframe_property(property: StringName) -> int:
	var kf := _parse_keyframe_property(property)
	if kf < 0 or _keyframe_property_index(kf) >= keyframe_count:
		return _NOT_A_KEYFRAME
	return kf

#endregion

#region Tree lifecycle

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE: _subscribe(_get_carousel())
		NOTIFICATION_EXIT_TREE:  _unsubscribe(_get_carousel())

func _subscribe(car: Carousel2D) -> void:
	if not car: return
	if not car.view_position_changed.is_connected(_on_view_position_changed):
		car.view_position_changed.connect(_on_view_position_changed)
	_on_view_position_changed(car.get_resolved_view_position())

func _unsubscribe(car: Carousel2D) -> void:
	if not car: return
	if car.view_position_changed.is_connected(_on_view_position_changed):
		car.view_position_changed.disconnect(_on_view_position_changed)

func _on_view_position_changed(t: float) -> void:
	_interpolate(t)

func _ready() -> void:
	if _positions.size() != keyframe_count:
		_resize_arrays(keyframe_count)
	refresh()

#endregion

#region Carousel resolution

## Pulls the position from the carousel and updates this node's transform.
## [br][br]
## [b]Note:[/b] This method is executed automatically.
func refresh() -> void:
	if not is_inside_tree(): return
	var car := _get_carousel()
	if not car: return
	_interpolate(car.get_resolved_view_position())

func _get_carousel() -> Carousel2D:
	if carousel: return carousel
	return _find_ancestor_carousel()

func _find_ancestor_carousel() -> Carousel2D:
	var parent := get_parent()
	while parent:
		if parent is Carousel2D:
			return parent
		parent = parent.get_parent()
	return null

#endregion

#region Interpolation

func _interpolate(t: float) -> void:
	if _cache_hit(t): return
	_last_t = t
	_last_version = _data_version
	_recompute(t)
	_cache_valid = true
	_last_transform = transform
	_last_modulate = modulate

func _cache_hit(t: float) -> bool:
	return _cache_valid and _data_version == _last_version and \
		   is_equal_approx(t, _last_t) and transform == _last_transform and \
		   modulate == _last_modulate

func _refresh_nil_range() -> void:
	if not _nil_range_dirty: return
	_nil_range_dirty = false
	_first_non_nil = -1
	_last_non_nil = -1
	for i: int in keyframe_count:
		if not _is_keyframe_nil(i):
			if _first_non_nil < 0: _first_non_nil = i
			_last_non_nil = i

func _recompute(t: float) -> void:
	var last := keyframe_count - 1
	if last < 0: return
	
	_refresh_nil_range()
	if _first_non_nil < 0: return
	if _last_non_nil == _first_non_nil:
		_apply_keyframe(_first_non_nil)
		return
	
	var pos := clampf(t, 0.0, 1.0) * last
	var lo  := clampi(floori(pos), _first_non_nil, _last_non_nil)
	var hi  := clampi(lo + 1, _first_non_nil, _last_non_nil)
	
	var scan := 0
	while _is_keyframe_nil(lo) or _is_keyframe_nil(hi):
		scan += 1
		if scan > _last_non_nil - _first_non_nil: return
		if _is_keyframe_nil(lo):
			lo = clampi(lo - 1, _first_non_nil, _last_non_nil)
		if _is_keyframe_nil(hi):
			hi = clampi(hi + 1, _first_non_nil, _last_non_nil)
	
	var span := hi - lo
	var local := clampf((pos - lo) / span, 0.0, 1.0) if span > 0 else 0.0
	
	var rot_a := _rotations[lo]
	var rot_b := _rotations[hi]
	if use_shortest_rotation:
		rot_b = rot_a + angle_difference(rot_a, rot_b)
	
	transform = Transform2D(
		lerp_angle(rot_a, rot_b, local),
		_scales[lo].lerp(_scales[hi], local),
		lerpf(_skews[lo], _skews[hi], local),
		_positions[lo].lerp(_positions[hi], local)
	)
	modulate = _modulates[lo].lerp(_modulates[hi], local)

func _is_keyframe_nil(idx: int) -> bool:
	# A keyframe is "nil" when its scale is Vector2.ZERO.
	return idx < 0 or idx >= _scales.size() or _scales[idx] == Vector2.ZERO

func _apply_keyframe(idx: int) -> void:
	if idx < 0 or idx >= keyframe_count: return
	transform = Transform2D(_rotations[idx], _scales[idx], _skews[idx], _positions[idx])
	modulate = _modulates[idx]

#endregion

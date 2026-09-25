## Draws a [Texture2D] through a four-point perspective warp, mapping the
## undistorted plane onto four arbitrary corner positions.
## [br][br]
## Corners come either from the [code]corner_*[/code] properties or from a grid
## of [PerspectiveQuadShape] resources (see [member use_shape_resources]).
## Optionally, a [Carousel2D] can drive the blend between the grid's cells.
@tool
@icon("uid://bpsy4f6nwkuwp")
class_name PerspectiveQuad2D
extends Node2D

const PERSPECTIVE_SHADER: Shader = preload("uid://brrbyu0etk8g0")

## [Texture2D] object to draw.
@export var texture: Texture2D:
	get = get_texture, set = set_texture

## Pixel size of the undistorted plane.
## Leave at [constant Vector2.ZERO] to use the texture's own size.
@export var plane_size_override: Vector2 = Vector2.ZERO:
	get = get_plane_size_override, set = set_plane_size_override

## If true, texture edges are anti-aliased.
@export var antialiased: bool = false:
	get = get_antialiased, set = set_antialiased

@export_group("Offset")
## If true, the texture's offset is centered.
@export var centered: bool = true:
	get = get_centered, set = set_centered

## The plane's drawing offset.
@export var offset: Vector2 = Vector2.ZERO:
	get = get_offset, set = set_offset

## Mirrors the drawn texture horizontally.
@export var flip_h: bool = false:
	get = get_flip_h, set = set_flip_h

## Mirrors the drawn texture vertically.
@export var flip_v: bool = false:
	get = get_flip_v, set = set_flip_v

@export_group("Material")
## Custom [ShaderMaterial] to render with instead of this node's
## auto-generated one. Must implement the perspective shader's uniform
## interface ([code]matrix_inv[/code], [code]frame_size[/code],
## [code]frame_offset[/code], [code]plane_size[/code], [code]origin_offset[/code],
## [code]flip_vector[/code], [code]antialiased[/code]), as these are written
## to whichever material is active on every update.
## [br][br]
## Leave [code]null[/code] to use an auto-generated, scene-local
## [ShaderMaterial] created in [method _ready].
## [br][br]
## [b]Note:[/b] This node cannot share a custom material between different nodes.
## Ensure that each material is unique, and that [member Resource.resource_local_to_scene]
## is enabled on each material to prevent unwanted visual mutations.
@export var material_override: ShaderMaterial:
	get = get_material_override, set = set_material_override

@export_group("Corners", "corner_")
## Position of the top-left corner.
## Unused when [member use_shape_resources] is true.
@export var corner_top_left := Vector2(0, 0):
	get = get_corner_top_left, set = set_corner_top_left

## Position of the top-right corner.
## Unused when [member use_shape_resources] is true.
@export var corner_top_right := Vector2(1, 0):
	get = get_corner_top_right, set = set_corner_top_right

## Position of the bottom-right corner.
## Unused when [member use_shape_resources] is true.
@export var corner_bottom_right := Vector2(1, 1):
	get = get_corner_bottom_right, set = set_corner_bottom_right

## Position of the bottom-left corner.
## Unused when [member use_shape_resources] is true.
@export var corner_bottom_left := Vector2(0, 1):
	get = get_corner_bottom_left, set = set_corner_bottom_left

@export_group("Shapes")
## When true, shapes are stored as [PerspectiveQuadShape]s in
## [member grid_size]/[member shapes]/[member active_shape] for the
## blend-shape workflow. When false, a single quad defined by the
## [code]corner_*[/code] properties is used instead.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "checkbox_only")
var use_shape_resources: bool = false:
	get = get_use_shape_resources, set = set_use_shape_resources

## Shape grid dimensions in cells (X = columns, Y = rows). [member shapes]
## is a flat, row-major array: [code]index = y * grid_size.x + x[/code].
@export var grid_size: Vector2i = Vector2i.ONE:
	get = get_grid_size, set = set_grid_size

## Flat, row-major array of [PerspectiveQuadShape] cells, laid out per [member grid_size].
@export var shapes: Array[PerspectiveQuadShape] = []:
	get = get_shapes, set = set_shapes

## Grid cell (X, Y) currently selected for editing/display. Ignored when
## [member use_blend_shapes] is on, or locked while [member use_shape_resources] is off.
@export var active_shape: Vector2i = Vector2i.ZERO:
	get = get_active_shape, set = set_active_shape

@export_subgroup("Blend Shapes")
## When true, [member active_shape] is ignored and the displayed transform
## is bilinearly interpolated across the shape grid using [member blend_position].
## Locked while [member use_shape_resources] is off.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "")
var use_blend_shapes: bool = false:
	get = get_use_blend_shapes, set = set_use_blend_shapes

## Bilinear blend coordinate across the grid, 0..1 in X and Y.
@export_custom(PROPERTY_HINT_RANGE, "0.0,1.0")
var blend_position: Vector2 = Vector2.ZERO:
	get = get_blend_position, set = set_blend_position

@export_group("Carousel")
## When true, a [Carousel2D] drives the [member carousel_axis] of
## [member blend_position], so the quad turns with the room instead of being
## blended by hand.
## [br][br]
## The first position that comes in also switches [member use_blend_shapes] on
## (needs [member use_shape_resources] and a multi-cell [member grid_size]).
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "")
var use_carousel: bool = false:
	get = get_use_carousel, set = set_use_carousel

## The carousel driving [member carousel_axis].
## Leave empty to use the closest ancestor [Carousel2D] instead.
@export var carousel: Carousel2D:
	get = get_carousel, set = set_carousel

## Which axis of [member blend_position] the [Carousel2D] writes to.
## The other axis is left alone unless a [member secondary_carousel] is set up.
@export var carousel_axis: Vector2.Axis = Vector2.AXIS_X:
	get = get_carousel_axis, set = set_carousel_axis

@export_subgroup("Secondary Carousel")
## When set to true, [member secondary_carousel] drives the axis [member carousel]
## doesn't (see [method get_secondary_carousel_axis]), so a room can pan and
## tilt at once.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "")
var use_secondary_carousel: bool = false:
	get = get_use_secondary_carousel, set = set_use_secondary_carousel

## Second carousel, driving the axis [member carousel] leaves alone. Unlike
## [member carousel] there is no ancestor fallback. Leave it empty to keep that
## axis under manual [member blend_position] control.
@export var secondary_carousel: Carousel2D:
	get = get_secondary_carousel, set = set_secondary_carousel

#region Property accessors

func get_texture() -> Texture2D: return texture

func set_texture(value: Texture2D) -> void:
	if texture: texture.changed.disconnect(_on_texture_changed)
	texture = value
	if texture: texture.changed.connect(_on_texture_changed)
	_atlas_uniforms_dirty = true
	_request_update()

func get_plane_size_override() -> Vector2: return plane_size_override

func set_plane_size_override(value: Vector2) -> void:
	plane_size_override = value
	_request_update()

func get_antialiased() -> bool: return antialiased

func set_antialiased(value: bool) -> void:
	antialiased = value
	_request_update()

func get_centered() -> bool: return centered

func set_centered(value: bool) -> void:
	centered = value
	_request_update()

func get_offset() -> Vector2: return offset

func set_offset(value: Vector2) -> void:
	offset = value
	_request_update()

func get_flip_h() -> bool: return flip_h

func set_flip_h(value: bool) -> void:
	flip_h = value
	_request_update()

func get_flip_v() -> bool: return flip_v

func set_flip_v(value: bool) -> void:
	flip_v = value
	_request_update()

func get_material_override() -> ShaderMaterial: return material_override

func set_material_override(value: ShaderMaterial) -> void:
	material_override = value
	_update_material()

func get_corner_top_left() -> Vector2: return corner_top_left

func set_corner_top_left(value: Vector2) -> void:
	if corner_top_left == value: return
	corner_top_left = value
	_simple_shape_dirty = true
	_request_update()

func get_corner_top_right() -> Vector2: return corner_top_right

func set_corner_top_right(value: Vector2) -> void:
	if corner_top_right == value: return
	corner_top_right = value
	_simple_shape_dirty = true
	_request_update()

func get_corner_bottom_right() -> Vector2: return corner_bottom_right

func set_corner_bottom_right(value: Vector2) -> void:
	if corner_bottom_right == value: return
	corner_bottom_right = value
	_simple_shape_dirty = true
	_request_update()

func get_corner_bottom_left() -> Vector2: return corner_bottom_left

func set_corner_bottom_left(value: Vector2) -> void:
	if corner_bottom_left == value: return
	corner_bottom_left = value
	_simple_shape_dirty = true
	_request_update()

func get_use_shape_resources() -> bool: return use_shape_resources

func set_use_shape_resources(value: bool) -> void:
	if use_shape_resources == value: return
	use_shape_resources = value
	_shapes_version += 1
	notify_property_list_changed()
	if value:
		if grid_size.x > 0 and grid_size.y > 0:
			_ensure_shapes()
			_connect_shape_signals()
	else:
		_disconnect_shape_signals()
	update_configuration_warnings()
	_request_update()

func get_grid_size() -> Vector2i: return grid_size

func set_grid_size(value: Vector2i) -> void:
	var new_grid_size := value.maxi(0)
	if grid_size == new_grid_size: return
	grid_size = new_grid_size
	_shapes_version += 1
	notify_property_list_changed()
	if use_shape_resources and grid_size.x > 0 and grid_size.y > 0:
		_ensure_shapes()
		_connect_shape_signals()
	update_configuration_warnings()
	_request_update()

func get_shapes() -> Array[PerspectiveQuadShape]: return shapes

func set_shapes(value: Array[PerspectiveQuadShape]) -> void:
	_disconnect_shape_signals()
	var needed := grid_size.x * grid_size.y if use_shape_resources else 0
	shapes = _sanitize_shape_array(value, needed)
	_shapes_version += 1
	if use_shape_resources:
		if shapes.size() != value.size():
			notify_property_list_changed()
		_ensure_shapes()
		_connect_shape_signals()
	update_configuration_warnings()
	_request_update()

func get_active_shape() -> Vector2i: return active_shape

func set_active_shape(value: Vector2i) -> void:
	active_shape = value
	_request_update()

func get_use_blend_shapes() -> bool: return use_blend_shapes

func set_use_blend_shapes(value: bool) -> void:
	use_blend_shapes = value
	_request_update()

func get_blend_position() -> Vector2: return blend_position

func set_blend_position(value: Vector2) -> void:
	blend_position = value.clampf(0.0, 1.0)
	_request_update()

func get_use_carousel() -> bool: return use_carousel

func set_use_carousel(value: bool) -> void:
	if use_carousel == value: return
	use_carousel = value
	_rebind_carousels()
	update_configuration_warnings()

func get_carousel() -> Carousel2D: return carousel

func set_carousel(value: Carousel2D) -> void:
	if carousel == value: return
	carousel = value
	_rebind_carousels()
	update_configuration_warnings()

func get_carousel_axis() -> int: return carousel_axis

func set_carousel_axis(value: int) -> void:
	if carousel_axis == value: return
	carousel_axis = value
	_rebind_carousels()

func get_use_secondary_carousel() -> bool: return use_secondary_carousel

func set_use_secondary_carousel(value: bool) -> void:
	if use_secondary_carousel == value: return
	use_secondary_carousel = value
	_rebind_carousels()
	update_configuration_warnings()

func get_secondary_carousel() -> Carousel2D: return secondary_carousel

func set_secondary_carousel(value: Carousel2D) -> void:
	if secondary_carousel == value: return
	secondary_carousel = value
	_rebind_carousels()
	update_configuration_warnings()

#endregion

#region Property list

func _validate_property(property: Dictionary) -> void:
	var prop_name: StringName = property.name
	
	match prop_name:
		&"material", &"use_parent_material":
			property.usage |= PROPERTY_USAGE_READ_ONLY
		&"use_blend_shapes", &"blend_position", &"active_shape":
			if not use_shape_resources:
				property.usage |= PROPERTY_USAGE_READ_ONLY
		&"corner_top_left", &"corner_top_right", \
		&"corner_bottom_right", &"corner_bottom_left":
			if use_shape_resources:
				property.usage |= PROPERTY_USAGE_READ_ONLY

#endregion

#region Internal state

var _blend_result: PerspectiveQuadShape

var _shapes_version: int = 0
var _blend_key := Vector3.INF

var _simple_shape: PerspectiveQuadShape
var _simple_shape_dirty := true

var _visual: _Visual

var _generated_material: ShaderMaterial

var _atlas_uniforms_dirty := true
var _atlas_uniforms_material: ShaderMaterial

var _update_pending := false

var _bound_carousel: Carousel2D
var _bound_secondary_carousel: Carousel2D
var _is_parented := false

var _last_custom_rect: Rect2
var _last_custom_rect_valid := false

#endregion

#region Internal visual node

## Private child that owns the live [ShaderMaterial] and performs the
## actual textured draw call on this node's behalf.
class _Visual extends Node2D:
	var draw_texture: Texture2D
	var draw_when_empty: bool = false
	var _rect: Rect2
	
	func set_draw_data(texture: Texture2D, rect: Rect2,
					   mod: Color, force_draw: bool = false) -> void:
		draw_texture = texture
		_rect = rect
		draw_when_empty = force_draw
		modulate = mod
		queue_redraw()
	
	func _draw() -> void:
		if draw_texture:
			draw_texture_rect(draw_texture, _rect, false)
		elif draw_when_empty:
			draw_rect(_rect, Color.WHITE)

#endregion

#region Self-modulate propagation

## Sets [member self_modulate] and immediately mirrors it onto the internal
## [PerspectiveQuad2D._Visual] node, which is what's actually drawn on screen.
## Prefer this over assigning [member self_modulate] directly from code.
func set_self_modulate_and_update(value: Color) -> void:
	self_modulate = value
	if _visual: _visual.self_modulate = value

func _set(property: StringName, value: Variant) -> bool:
	if property == &"self_modulate" and _visual:
		_visual.self_modulate = value
	return false

#endregion

#region Lifecycle

func _ready() -> void:
	if not _visual:
		_visual = _Visual.new()
		add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
		_visual.self_modulate = self_modulate
	_update_material()
	if use_shape_resources:
		_ensure_shapes()
		_connect_shape_signals()
	_update()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_last_custom_rect_valid = false
		NOTIFICATION_PARENTED:
			_is_parented = true
			_rebind_carousels()
		NOTIFICATION_UNPARENTED:
			_is_parented = false
			_release_carousels()

#endregion

#region Configuration warnings

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if use_shape_resources:
		if grid_size.x <= 0 or grid_size.y <= 0:
			warnings.append("Grid size must be at least 1x1 when shape resources are enabled.")
		elif shapes.is_empty():
			warnings.append("Shapes array is empty. Add at least one shape, or adjust grid_size to match.")
	if use_carousel:
		var primary := _get_carousel()
		if primary == null:
			warnings.append("Carousel is enabled but no Carousel2D is assigned and none was found in the node's ancestors.")
		elif not use_shape_resources:
			warnings.append("Carousel is enabled but shape resources are off. The carousel drives blend_position, which needs shapes to blend between.")
		if use_secondary_carousel:
			var secondary := _get_secondary_carousel()
			if secondary == null:
				warnings.append("Secondary carousel is enabled but no Carousel2D is assigned.")
			elif secondary == primary:
				warnings.append("Secondary carousel is the same Carousel2D as the primary carousel.")
	return warnings

#endregion

#region Carousel integration

func _get_carousel() -> Carousel2D:
	if not use_carousel: return null
	if carousel: return carousel
	return _find_ancestor_carousel()

func _get_secondary_carousel() -> Carousel2D:
	if not use_carousel or not use_secondary_carousel: return null
	if secondary_carousel: return secondary_carousel
	return null

## The [member blend_position] axis a second carousel drives, being whichever one
## [member carousel_axis] does not.
func get_secondary_carousel_axis() -> Vector2.Axis:
	return Vector2.AXIS_Y if carousel_axis == Vector2.AXIS_X else Vector2.AXIS_X

func _find_ancestor_carousel() -> Carousel2D:
	var parent := get_parent()
	while parent:
		if parent is Carousel2D:
			return parent
		parent = parent.get_parent()
	return null

func _rebind_carousels() -> void:
	_release_carousels()
	if not _is_parented: return
	_bound_carousel = _get_carousel()
	_bound_secondary_carousel = _get_secondary_carousel()
	if _bound_carousel:
		_bound_carousel.view_position_changed.connect(_on_carousel_view_position_changed)
	if _bound_secondary_carousel:
		_bound_secondary_carousel.view_position_changed.connect(_on_secondary_carousel_view_position_changed)
	if _bound_carousel:
		_on_carousel_view_position_changed(_bound_carousel.get_resolved_view_position())
	if _bound_secondary_carousel:
		_on_secondary_carousel_view_position_changed(_bound_secondary_carousel.get_resolved_view_position())
	if use_carousel:
		update_configuration_warnings()

func _release_carousels() -> void:
	_unbind_carousel(_bound_carousel, _on_carousel_view_position_changed)
	_unbind_carousel(_bound_secondary_carousel, _on_secondary_carousel_view_position_changed)
	_bound_carousel = null
	_bound_secondary_carousel = null

func _unbind_carousel(target: Carousel2D, handler: Callable) -> void:
	if not target: return
	if target.view_position_changed.is_connected(handler):
		target.view_position_changed.disconnect(handler)

func _on_carousel_view_position_changed(t: float) -> void:
	_write_carousel_position(carousel_axis, t)

func _on_secondary_carousel_view_position_changed(t: float) -> void:
	_write_carousel_position(get_secondary_carousel_axis(), t)

func _write_carousel_position(axis: Vector2.Axis, t: float) -> void:
	if use_shape_resources and not use_blend_shapes:
		use_blend_shapes = true
	var bp := blend_position
	if is_equal_approx(bp[axis], t): return
	bp[axis] = t
	blend_position = bp

#endregion

#region Plane geometry

## The undistorted plane's size in pixels. Returns [member plane_size_override]
## when set, otherwise the texture's own size. If there's no valid texture
## either, returns 64x64.
func get_plane_size() -> Vector2:
	if plane_size_override != Vector2.ZERO: return plane_size_override
	if texture: return texture.get_size()
	return Vector2(64, 64)

## Local-space position of the plane's top-left corner, before the perspective warp.
func get_origin_offset(plane_size := get_plane_size()) -> Vector2:
	return offset - (plane_size / 2.0) if centered else offset

## Size of the warped quad's bounding box, in plane units.
func get_frame_size() -> Vector2:
	return get_display_shape().frame_size

## Offset of the warped quad's bounding box, in plane units.
func get_frame_offset() -> Vector2:
	return get_display_shape().frame_offset

## Local-space bounding rect of the warped quad, for culling.
func get_effective_local_rect() -> Rect2:
	return _local_rect(get_plane_size(), get_display_shape())

func _local_rect(plane_size: Vector2, shape: PerspectiveQuadShape) -> Rect2:
	var origin := get_origin_offset(plane_size)
	return Rect2(origin + plane_size * shape.frame_offset, plane_size * shape.frame_size)

#endregion

#region Editing shape

## The shape resource actively being edited. The currently selected grid
## cell ([member active_shape]) when [member use_shape_resources] is on, or
## the runtime-only quad built from the [code]corner_*[/code] properties
## when it's off. This is what the editor's on-canvas drag handles read
## from and write to.
## [br][br]
## This always ignores [member use_blend_shapes]. For the shape that's
## actually being rendered right now (which may be a computed blend
## instead), use [method get_display_shape].
## [br][br]
## Returns [code]null[/code] when there is no shape to edit, which is the case
## for a shape grid with a zero axis.
func get_editing_shape() -> PerspectiveQuadShape:
	if not use_shape_resources: return _get_simple_shape()
	_ensure_shapes()
	return shape_at()

## True when there is a shape that the editor can read and write to.
func has_editable_shape() -> bool:
	return is_instance_valid(get_editing_shape())

func _get_editing_corners() -> PackedVector2Array:
	var shape := get_editing_shape()
	if not shape: return PackedVector2Array()
	return shape._get_corners()

## Corners of [method get_editing_shape], the unblended shape being edited.
## Used by the editor to implement its on-canvas drag-handles. See
## [method get_display_corners] for the (possibly blended) corners actually
## being rendered.
## [br][br]
## Returns empty array while [method has_editable_shape] is false.
func get_editing_corners() -> PackedVector2Array:
	var corners := _get_editing_corners()
	return corners.duplicate() if corners else corners

## Writes to the corner matching [param corner] of [method get_editing_shape].
## When [member use_blend_shapes] is active, [method get_display_shape] is a
## computed blend and isn't affected directly, so editing a corner here only
## changes one of its inputs.
## [br][br]
## Does nothing while [method has_editable_shape] is false.
func set_corner(corner: Corner, value: Vector2) -> void:
	if not use_shape_resources:
		match corner:
			Corner.CORNER_TOP_LEFT:     corner_top_left = value
			Corner.CORNER_TOP_RIGHT:    corner_top_right = value
			Corner.CORNER_BOTTOM_RIGHT: corner_bottom_right = value
			Corner.CORNER_BOTTOM_LEFT:  corner_bottom_left = value
		return
	var shape := get_editing_shape()
	if not shape: return
	shape.set_corner(corner, value)

func _get_simple_shape() -> PerspectiveQuadShape:
	if not _simple_shape:
		_simple_shape = PerspectiveQuadShape.new()
	if _simple_shape_dirty:
		_simple_shape.set_each_corner(corner_top_left, corner_top_right,
									  corner_bottom_right, corner_bottom_left)
		_simple_shape_dirty = false
	return _simple_shape

#endregion

#region Blend-shape workflow

## Returns the shape at grid cell [param cell] (clamped), or [code]null[/code]
## when the grid has no cell to hand back.
## [br][br]
## There is no accessible grid at all when an axis of [member grid_size] is zero.
## Callers that need a shape unconditionally should check [method has_editable_shape] first.
func shape_at(cell: Vector2i = active_shape) -> PerspectiveQuadShape:
	_ensure_shapes()
	if grid_size.x <= 0 or grid_size.y <= 0 or shapes.is_empty(): return null
	var x := clampi(cell.x, 0, grid_size.x - 1)
	var y := clampi(cell.y, 0, grid_size.y - 1)
	return shapes[y * grid_size.x + x]

## The shape actually driving the current render. Returns the bilinearly-blended
## result across the grid when [member use_blend_shapes] is on. Otherwise, returns
## the exact same shape as [method get_editing_shape].
## [br][br]
## [b]Note:[/b] While blending, this returns an internal scratch
## [PerspectiveQuadShape] that gets overwritten the next time the blend is
## recomputed. Make sure to read what you need immediately, or call
## [method get_display_corners] for a standalone copy of just its corners.
func get_display_shape() -> PerspectiveQuadShape:
	if not use_shape_resources:
		return _get_simple_shape()
	if use_blend_shapes and shapes.size() > 1:
		return _blend_shapes()
	var shape := get_editing_shape()
	if not shape: return _get_simple_shape()
	return shape

## Corners of [method get_display_shape], the active shape's corners
## normally, or the live-interpolated corners of the current blend when
## [member use_blend_shapes] is active.
func get_display_corners() -> PackedVector2Array:
	return get_display_shape().get_corners()

func _ensure_shapes() -> void:
	if not use_shape_resources: return
	var needed := grid_size.x * grid_size.y
	if needed <= 0: return
	if _shapes_need_sanitize(shapes) or shapes.size() < needed:
		shapes = _sanitize_shape_array(shapes, needed)

static func _shapes_need_sanitize(arr: Array[PerspectiveQuadShape]) -> bool:
	if arr.is_read_only(): return true
	for shape in arr:
		if not shape: return true
	return false

func _sanitize_shape_array(arr: Array[PerspectiveQuadShape], min_size: int = 0) -> Array[PerspectiveQuadShape]:
	var result: Array[PerspectiveQuadShape] = arr.duplicate()
	while result.size() < min_size:
		result.append(_make_default_shape())
	for i: int in result.size():
		if not result[i]:
			result[i] = _make_default_shape()
	return result

func _make_default_shape() -> PerspectiveQuadShape:
	var shape := PerspectiveQuadShape.new()
	shape.resource_local_to_scene = true
	if not shape.changed.is_connected(_on_shape_changed):
		shape.changed.connect(_on_shape_changed)
	return shape

func _connect_shape_signals() -> void:
	for shape in shapes:
		if shape and not shape.changed.is_connected(_on_shape_changed):
			shape.changed.connect(_on_shape_changed)

func _disconnect_shape_signals() -> void:
	for shape in shapes:
		if shape and shape.changed.is_connected(_on_shape_changed):
			shape.changed.disconnect(_on_shape_changed)

func _on_shape_changed() -> void:
	_shapes_version += 1
	_request_update()

func _blend_shapes() -> PerspectiveQuadShape:
	_ensure_shapes()
	
	if not _blend_result:
		_blend_result = PerspectiveQuadShape.new()
	
	var key := Vector3(blend_position.x, blend_position.y, float(_shapes_version))
	if _blend_key == key:
		return _blend_result
	_blend_key = key
	
	var cols := grid_size.x
	var rows := grid_size.y
	
	if cols == 1 or rows == 1:
		var count := maxi(cols, rows)
		var pos := blend_position.x if rows == 1 else blend_position.y
		var p := clampf(pos, 0.0, 1.0) * (count - 1)
		var lo := clampi(floori(p), 0, count - 1)
		var hi := clampi(lo + 1, 0, count - 1)
		var t := p - lo
		
		var a := shapes[lo]
		var b := shapes[hi]
		
		_blend_from_pair(a, b, t, _blend_result)
		return _blend_result
	
	var x_pos := clampf(blend_position.x, 0.0, 1.0) * (cols - 1)
	var x_lo := clampi(floori(x_pos), 0, cols - 1)
	var x_hi := clampi(x_lo + 1, 0, cols - 1)
	var tx := x_pos - x_lo
	
	var y_pos := clampf(blend_position.y, 0.0, 1.0) * (rows - 1)
	var y_lo := clampi(floori(y_pos), 0, rows - 1)
	var y_hi := clampi(y_lo + 1, 0, rows - 1)
	var ty := y_pos - y_lo
	
	var t_l := shapes[y_lo * cols + x_lo]
	var t_r := shapes[y_lo * cols + x_hi]
	var b_l := shapes[y_hi * cols + x_lo]
	var b_r := shapes[y_hi * cols + x_hi]
	
	_blend_bilinear(t_l, t_r, b_l, b_r, tx, ty, _blend_result)
	return _blend_result

static func _blend_from_pair(a: PerspectiveQuadShape, b: PerspectiveQuadShape,
							 t: float, out_shape: PerspectiveQuadShape) -> void:
	out_shape.set_each_corner(
		a.top_left.lerp(b.top_left, t),
		a.top_right.lerp(b.top_right, t),
		a.bottom_right.lerp(b.bottom_right, t),
		a.bottom_left.lerp(b.bottom_left, t)
	)
	out_shape._modulate = a._modulate.lerp(b._modulate, t)

static func _blend_bilinear(t_l: PerspectiveQuadShape, t_r: PerspectiveQuadShape,
							b_l: PerspectiveQuadShape, b_r: PerspectiveQuadShape,
							t_x: float, t_y: float, out_shape: PerspectiveQuadShape) -> void:
	out_shape.set_each_corner(
		t_l.top_left.lerp(t_r.top_left, t_x).lerp(
			b_l.top_left.lerp(b_r.top_left, t_x), t_y
		),
		t_l.top_right.lerp(t_r.top_right, t_x).lerp(
			b_l.top_right.lerp(b_r.top_right, t_x), t_y
		),
		t_l.bottom_right.lerp(t_r.bottom_right, t_x).lerp(
			b_l.bottom_right.lerp(b_r.bottom_right, t_x), t_y
		),
		t_l.bottom_left.lerp(t_r.bottom_left, t_x).lerp(
			b_l.bottom_left.lerp(b_r.bottom_left, t_x), t_y
		)
	)
	
	var mod_top    := t_l._modulate.lerp(t_r._modulate, t_x)
	var mod_bottom := b_l._modulate.lerp(b_r._modulate, t_x)
	out_shape._modulate = mod_top.lerp(mod_bottom, t_y)

#endregion

#region Plane projection

## Maps a point in local space to the plane's texture-space UV, accounting
## for the active/blended shape's warp and flip flags. Returns a UV outside
## [0, 1] if the point falls outside the warped quad, and returns
## [[code]NAN[/code], [code]NAN[/code]] when the shape's matrix is invalid or
## when the plane's size is degenerate.
func local_to_plane_uv(local_pos: Vector2) -> Vector2:
	var plane_size := get_plane_size()
	if plane_size.x <= 0.0 or plane_size.y <= 0.0: return Vector2(NAN, NAN)
	
	var shape := get_display_shape()
	var inner := (local_pos - get_origin_offset(plane_size)) / plane_size
	var uv := PerspectiveQuadMath.project_inv(shape.perspective_matrix_inv, inner)
	if is_nan(uv.x): return Vector2(NAN, NAN)
	
	if flip_h: uv.x = 1.0 - uv.x
	if flip_v: uv.y = 1.0 - uv.y
	return uv

#endregion

#region Update

# Queues a single _update call before the next frame is drawn.
func _request_update() -> void:
	if _update_pending: return
	_update_pending = true
	RenderingServer.frame_pre_draw.connect(_flush_update, CONNECT_ONE_SHOT)

func _flush_update() -> void:
	_update_pending = false
	_update()

func _update() -> void:
	if not _visual: return
	var plane_size := get_plane_size()
	var shape := get_display_shape()
	
	if not PerspectiveQuadMath.is_matrix_valid(shape.perspective_matrix_inv):
		_visual.visible = false
		return
	_visual.visible = true
	
	var mat := _visual.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter(&"matrix_inv",    shape.perspective_matrix_inv)
		mat.set_shader_parameter(&"frame_size",    shape.frame_size)
		mat.set_shader_parameter(&"frame_offset",  shape.frame_offset)
		mat.set_shader_parameter(&"plane_size",    plane_size)
		mat.set_shader_parameter(&"origin_offset", get_origin_offset(plane_size))
		mat.set_shader_parameter(&"flip_vector",   Vector2(float(flip_h), float(flip_v)))
		mat.set_shader_parameter(&"antialiased",   antialiased)
		if _atlas_uniforms_dirty or mat != _atlas_uniforms_material:
			_update_atlas_uniforms(mat)
			_atlas_uniforms_dirty = false
			_atlas_uniforms_material = mat
	
	var atlas_tex := texture as AtlasTexture
	var draw_texture: Texture2D = atlas_tex.atlas if (atlas_tex and atlas_tex.atlas) else texture
	_visual.set_draw_data(draw_texture, Rect2(Vector2.ZERO, plane_size),
						  shape.modulate, material_override != null)
	
	if is_inside_tree():
		var rect := _local_rect(plane_size, shape)
		if not (_last_custom_rect_valid and rect == _last_custom_rect):
			RenderingServer.canvas_item_set_custom_rect(_visual.get_canvas_item(), true, rect)
			_last_custom_rect = rect
			_last_custom_rect_valid = true

func _on_texture_changed() -> void:
	_atlas_uniforms_dirty = true
	_request_update()

func _update_atlas_uniforms(mat: ShaderMaterial) -> void:
	var atlas_tex: AtlasTexture = texture if texture is AtlasTexture else null
	var source: Texture2D = atlas_tex.atlas if atlas_tex else null
	var source_size := Vector2(source.get_size()) if source else Vector2.ZERO
	
	if not (atlas_tex and source_size.x > 0.0 and source_size.y > 0.0):
		mat.set_shader_parameter(&"atlas_region",      Vector4(0.0, 0.0, 1.0, 1.0))
		mat.set_shader_parameter(&"atlas_texel_size",  Vector2.ZERO)
		mat.set_shader_parameter(&"atlas_margin_rect", Vector4(0.0, 0.0, 1.0, 1.0))
		return
	
	var region_size := atlas_tex.region.size
	if region_size.x == 0.0: region_size.x = source_size.x
	if region_size.y == 0.0: region_size.y = source_size.y
	
	mat.set_shader_parameter(&"atlas_region", Rect2(atlas_tex.region.position / source_size,
													region_size / source_size))
	mat.set_shader_parameter(&"atlas_texel_size", Vector2.ONE / source_size)
	
	var full_size := Vector2(atlas_tex.get_size())
	if full_size.x > 0.0 and full_size.y > 0.0:
		var margin := atlas_tex.margin
		mat.set_shader_parameter(&"atlas_margin_rect", Rect2(margin.position / full_size,
															 region_size / full_size))
	else:
		mat.set_shader_parameter(&"atlas_margin_rect", Vector4(0.0, 0.0, 1.0, 1.0))

#endregion

#region Material management

## The material currently in use. Returns [member material_override] if set.
## Otherwise, returns the internal material the node generated for itself.
func get_active_material() -> ShaderMaterial:
	if _visual: return _visual.material
	if material_override != null: return material_override
	return null

func _update_material() -> void:
	if not _visual: return
	_visual.material = material_override if material_override else _get_generated_material()
	_atlas_uniforms_dirty = true
	_request_update()

func _get_generated_material() -> ShaderMaterial:
	if not _generated_material:
		_generated_material = ShaderMaterial.new()
		_generated_material.resource_local_to_scene = true
		_generated_material.shader = PERSPECTIVE_SHADER
	return _generated_material

#endregion

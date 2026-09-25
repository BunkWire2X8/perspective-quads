## On-canvas corner-handle editor for [PerspectiveQuad2D].
## This editor draws grab handles around the quad being edited in the 2D
## viewport and turns mouse drags into corner writes.
@tool
extends RefCounted

const HANDLE_RADIUS := 6.0
const HANDLE_COLOR := Color(1.0, 1.0, 1.0)
const HANDLE_COLOR_ACTIVE := Color(0.4, 1.0, 1.0, 1.0)
const LINE_COLOR := Color(1.0, 0.3, 0.1, 0.8)
const PROPERTY_NAMES: Array[StringName] = [&"top_left", &"top_right",
										   &"bottom_right", &"bottom_left"]
const NODE_PROPERTY_NAMES: Array[StringName] = [&"corner_top_left", &"corner_top_right",
												&"corner_bottom_right", &"corner_bottom_left"]

#region Editor state

var _plugin: EditorPlugin
var _handle_tex: Texture2D
var _handle_tex_size_half := Vector2.ZERO

var _current: PerspectiveQuad2D = null
var _dragging_index: int = -1
var _hover_index: int = -1
var _drag_start_value: Vector2 = Vector2.ZERO
var _drag_target: Object = null
var _drag_property: StringName = &""

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_handle_tex = EditorInterface.get_base_control().get_theme_icon("EditorPathSharpHandle", "EditorIcons")
	_handle_tex_size_half = _handle_tex.get_size() / 2.0

#endregion

#region Entry points (called by plugin.gd)

## Handles every [PerspectiveQuad2D], the only node this editor draws handles for.
func handles(object: Object) -> bool:
	return object is PerspectiveQuad2D

## Switches the edited quad and redraws the overlay.
func edit(object: Object) -> void:
	_current = object as PerspectiveQuad2D
	_dragging_index = -1
	_hover_index = -1
	_plugin.update_overlays()

## Draws the outline joining the quad's corners plus a grab handle on each one.
func draw_over_viewport(overlay: Control) -> void:
	if not _current_valid(): return
	var screen_corners := _get_screen_corners()
	
	for i: int in screen_corners.size():
		var next_corner: Vector2 = screen_corners[(i + 1) % screen_corners.size()]
		overlay.draw_line(screen_corners[i], next_corner, LINE_COLOR, 2.0, false)
	for i: int in screen_corners.size():
		var active := i == _dragging_index or i == _hover_index
		overlay.draw_texture(_handle_tex, screen_corners[i] - _handle_tex_size_half,
							 HANDLE_COLOR_ACTIVE if active else HANDLE_COLOR)

## Starts a drag when a handle is grabbed, moves the dragged corner, and records
## the move as one undoable action when the button is released.
func gui_input(event: InputEvent) -> bool:
	if _current_valid():
		if event is InputEventMouseMotion:
			if _dragging_index != -1:
				_current.set_corner(_dragging_index, _screen_to_normalized(event.position))
				_plugin.update_overlays()
				return true
			var new_hover := _find_handle_at(event.position)
			if new_hover != _hover_index:
				_hover_index = new_hover
				_plugin.update_overlays()
			return _hover_index != -1
		
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var idx := _find_handle_at(event.position)
				if idx != -1:
					_dragging_index = idx
					if _current.use_shape_resources:
						_drag_target = _current.get_editing_shape()
						_drag_property = PROPERTY_NAMES[idx]
					else:
						_drag_target = _current
						_drag_property = NODE_PROPERTY_NAMES[idx]
					_drag_start_value = _current._get_editing_corners()[idx]
					return true
			elif _dragging_index != -1:
				_commit_drag()
				_dragging_index = -1
				_drag_target = null
				_drag_property = &""
				_plugin.update_overlays()
				return true
	
	return false

#endregion

#region Handle helpers

# To alter a shape, there needs to be both a valid and visible one to write to.
# It doesn't make sense to show off the handles when there's a shape blend
# driving the current render instead of the actual stored shapes.
func _current_valid() -> bool:
	return _current and _current.is_inside_tree() \
		   and _current.has_editable_shape() \
		   and not (_current.use_blend_shapes and _current.use_shape_resources)

func _find_handle_at(screen_pos: Vector2) -> int:
	var screen_corners := _get_screen_corners()
	for i: int in screen_corners.size():
		if screen_corners[i].distance_to(screen_pos) <= HANDLE_RADIUS + 4.0:
			return i
	return -1

func _get_screen_corners() -> PackedVector2Array:
	var transform := _world_to_screen_transform() * _current.get_global_transform()
	var plane_size := _current.get_plane_size()
	var origin := _current.get_origin_offset(plane_size)
	var points := _current._get_editing_corners()
	
	var result := PackedVector2Array()
	result.resize(points.size())
	
	for i: int in points.size():
		result[i] = transform * (points[i] * plane_size + origin)
	
	return result

func _screen_to_normalized(screen_pos: Vector2) -> Vector2:
	var world_pos: Vector2 = _world_to_screen_transform().affine_inverse() * screen_pos
	var local_pos: Vector2 = _current.get_global_transform().affine_inverse() * world_pos
	var plane_size := _current.get_plane_size()
	var origin := _current.get_origin_offset(plane_size)
	return (local_pos - origin) / plane_size

func _world_to_screen_transform() -> Transform2D:
	return EditorInterface.get_editor_viewport_2d().global_canvas_transform

#endregion

#region Undo

func _commit_drag() -> void:
	if not _drag_target: return
	var corners := _current._get_editing_corners()
	if _dragging_index < 0 or _dragging_index >= corners.size(): return
	var new_value: Vector2 = corners[_dragging_index]
	if new_value == _drag_start_value: return
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Move PerspectiveQuad2D corner")
	undo.add_do_property(_drag_target, _drag_property, new_value)
	undo.add_undo_property(_drag_target, _drag_property, _drag_start_value)
	undo.commit_action()

#endregion

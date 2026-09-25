## Displays a child [SubViewport]'s texture through the perspective warp, and
## forwards input through the inverse warp into the viewport's local coordinate
## space. The [PerspectiveQuad2D] equivalent of [SubViewportContainer].
@tool
@icon("uid://n8khikvcc2np")
class_name PerspectiveViewportContainer2D
extends PerspectiveQuad2D

## Scales the child [SubViewport]'s render resolution relative to the displayed
## size. [code]0.5[/code] renders at double resolution, and [code]2.0[/code] at half.
## [br][br]
## [b]Note:[/b] Only takes effect once [member PerspectiveQuad2D.plane_size_override]
## is set. Make sure to set the override to the SubViewport's initial [member SubViewport.size],
## due to how [member PerspectiveQuad2D.plane_size_override] effectively overrides that property.
@export_range(0.1, 8.0, 0.05) var stretch_shrink: float = 1.0:
	get = get_stretch_shrink, set = set_stretch_shrink

## If true, a pointer event that lands inside the warped quad is consumed after
## being forwarded, so it doesn't also reach the rest of the scene's unhandled input.
@export var stop_input_propagation: bool = true:
	get = get_stop_input_propagation, set = set_stop_input_propagation

## If true, a press that lands outside the warped quad naturally closes a popup that's
## open inside the child [SubViewport]. This includes [OptionButton] & [MenuButton]
## dropdowns, [ColorPickerButton]'s picker, and so on.
## [br][br]
## [b]Note:[/b] Only meaningful while the child [SubViewport]'s
## [member SubViewport.gui_embed_subwindows] is on. 
@export var dismiss_popups_outside_quad: bool = true:
	get = get_dismiss_popups_outside_quad, set = set_dismiss_popups_outside_quad

#region Property accessors

func get_stop_input_propagation() -> bool: return stop_input_propagation

func set_stop_input_propagation(value: bool) -> void: stop_input_propagation = value

func get_stretch_shrink() -> float: return stretch_shrink

func set_stretch_shrink(value: float) -> void:
	stretch_shrink = maxf(value, 0.1)
	_sync_viewport_sizes()

func get_dismiss_popups_outside_quad() -> bool: return dismiss_popups_outside_quad

func set_dismiss_popups_outside_quad(value: bool) -> void: dismiss_popups_outside_quad = value

# Overridden so changing plane_size_override also resizes the child
# SubViewport's render resolutions.
func set_plane_size_override(value: Vector2) -> void:
	plane_size_override = value
	_sync_viewport_sizes()
	_request_update()

#endregion

#region Property list

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: StringName = property.name
	
	match prop_name:
		# The texture no longer has any real need to be editable in the inspector.
		# It also doesn't need to be saved into the scene data anymore, due to its
		# texture now being auto-assigned during _ready().
		&"texture": property.usage &= ~PROPERTY_USAGE_DEFAULT

#endregion

#region Internal state

var _viewport: SubViewport

var _pointer_inside: Dictionary[int, bool] = {}
var _last_target_pos: Dictionary[int, Vector2] = {}
var _pointer_captured: Dictionary[int, bool] = {}

var _viewport_mouse_in: SubViewport

var _cursor_override_active := false

var _window_input_connected := false

var _guarded_popup_ids: PackedInt64Array

#endregion

#region Lifecycle

func _ready() -> void:
	_find_viewport()
	super._ready()
	if not child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.connect(_on_child_entered_tree)
	if not child_exiting_tree.is_connected(_on_child_exiting_tree):
		child_exiting_tree.connect(_on_child_exiting_tree)
	set_process_input(not Engine.is_editor_hint())
	set_process_unhandled_input(not Engine.is_editor_hint())
	set_process(not Engine.is_editor_hint())
	_sync_viewport_sizes()
	_connect_window_input()
	_watch_popup_menus()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_find_viewport()
			_sync_viewport_sizes()
			_apply_viewport_update_modes()
			_connect_window_input()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_release_mouse_over()
			_apply_viewport_update_modes()

func _exit_tree() -> void:
	_release_mouse_over()
	_reset_cursor_override()
	_disconnect_window_input()
	_unwatch_popup_menus()

#endregion

#region Configuration warnings

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	if _find_viewport_child() == null:
		warnings.append("This node has no SubViewport child, meaning it has nothing to display or forward input to. Add a SubViewport as a direct child.")
	return warnings

#endregion

#region Viewport wiring

## The [SubViewport] whose texture is displayed, if any.
func get_sub_viewport() -> SubViewport: return _viewport

func _on_child_entered_tree(_child: Node) -> void:
	_find_viewport()
	_sync_viewport_sizes()
	_apply_viewport_update_modes()

func _on_child_exiting_tree(child: Node) -> void:
	if child == _viewport:
		_viewport = null
		_release_mouse_over()
		_forget_viewport_mouse_in()
		_find_viewport.call_deferred()

func _find_viewport_child() -> SubViewport:
	for child in get_children():
		if child is SubViewport:
			return child
	return null

func _find_viewport() -> void:
	var found := _find_viewport_child()
	if (found == _viewport) and (found != null): return
	_release_mouse_over()
	_forget_viewport_mouse_in()
	_viewport = found
	_reset_cursor_override()
	texture = _viewport.get_texture() if _viewport else null
	_sync_viewport_sizes()
	update_configuration_warnings()

func _sync_viewport_sizes() -> void:
	if not _viewport or plane_size_override == Vector2.ZERO: return
	
	var logical_size := Vector2i(plane_size_override.round().max(Vector2.ONE))
	var render_size  := Vector2i((plane_size_override / stretch_shrink).round().max(Vector2.ONE))
	
	_viewport.size_2d_override_stretch = true
	_viewport.size_2d_override = logical_size
	_viewport.size = render_size

func _apply_viewport_update_modes() -> void:
	if Engine.is_editor_hint(): return
	if not _viewport: return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS \
										  if is_visible_in_tree() else \
										  SubViewport.UPDATE_DISABLED

func _viewport_logical_size() -> Vector2:
	if not _viewport: return get_plane_size()
	if _viewport.size_2d_override_stretch and _viewport.size_2d_override != Vector2i.ZERO:
		return Vector2(_viewport.size_2d_override)
	return Vector2(_viewport.size)

#endregion

#region Mouse-over forwarding

func _set_mouse_over(value: bool) -> void:
	if value:
		if _viewport == null or _viewport_mouse_in != null: return
		if _viewport.is_input_disabled(): return
		_viewport_mouse_in = _viewport
		_viewport.notify_mouse_entered()
		return
	
	if _viewport_mouse_in == null: return
	var target := _viewport_mouse_in
	if not target:
		_forget_viewport_mouse_in()
		return
	if not target.is_inside_tree(): return
	if target.is_input_disabled():
		_forget_viewport_mouse_in()
		return
	_forget_viewport_mouse_in()
	target.notify_mouse_exited()

func _sync_mouse_over() -> void:
	var any_inside := false
	for pointer_id in _pointer_inside:
		if _pointer_inside[pointer_id]: any_inside = true
	_set_mouse_over(any_inside)

func _release_mouse_over() -> void:
	_pointer_inside.clear()
	_last_target_pos.clear()
	_pointer_captured.clear()
	_set_mouse_over(false)

func _forget_viewport_mouse_in() -> void: _viewport_mouse_in = null

#endregion

#region Input pass-through

func _unhandled_input(event: InputEvent) -> void:
	if not _viewport: return
	if _viewport.gui_disable_input:
		_forget_viewport_mouse_in()
		return
	if not is_visible_in_tree(): return
	
	if _is_positional_event(event):
		_forward_pointer_event(event)
	else:
		_forward_nonpositional_event(event)

func _is_positional_event(event: InputEvent) -> bool:
	return event is InputEventMouse or event is InputEventScreenTouch \
		or event is InputEventScreenDrag or event is InputEventGesture

func _local_position_of(event: InputEvent) -> Vector2:
	var origin_viewport := get_viewport()
	if not origin_viewport: return Vector2.ZERO
	var canvas_pos := origin_viewport.canvas_transform.affine_inverse()\
					  * (event.position as Vector2)
	return to_local(canvas_pos)

func _uv_is_inside(uv: Vector2) -> bool:
	if is_nan(uv.x) or is_nan(uv.y): return false
	return uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0

func _forward_nonpositional_event(event: InputEvent) -> void:
	if _viewport.is_input_disabled(): return
	_viewport.push_input(event.duplicate(), true)

func _forward_pointer_event(event: InputEvent) -> void:
	var origin_viewport := get_viewport()
	if not origin_viewport: return
	
	var local_pos := _local_position_of(event)
	var uv := local_to_plane_uv(local_pos)
	var inside := _uv_is_inside(uv)
	
	var pointer_id := _pointer_id_for(event)
	var was_inside: bool = _pointer_inside.get(pointer_id, false)
	var captured: bool = _pointer_captured.get(pointer_id, false)
	if not inside and not was_inside and not captured: return
	
	var released := (event is InputEventScreenTouch) and \
					(not (event as InputEventScreenTouch).pressed)
	_pointer_inside[pointer_id] = inside
	_sync_mouse_over()
	
	var target_pos := uv * _viewport_logical_size()
	if (inside or captured) and not (is_nan(target_pos.x) or is_nan(target_pos.y)):
		var prev_target_pos: Vector2 = _last_target_pos.get(pointer_id, target_pos)
		var forwarded: InputEvent = event.duplicate()
		
		if forwarded is InputEventMouseMotion:
			var mm := forwarded as InputEventMouseMotion
			mm.position = target_pos
			mm.global_position = target_pos
			mm.relative = target_pos - prev_target_pos
		elif forwarded is InputEventMouseButton:
			var mb := forwarded as InputEventMouseButton
			mb.position = target_pos
			mb.global_position = target_pos
		elif forwarded is InputEventScreenTouch:
			(forwarded as InputEventScreenTouch).position = target_pos
		elif forwarded is InputEventScreenDrag:
			var sd := forwarded as InputEventScreenDrag
			sd.position = target_pos
			sd.relative = target_pos - prev_target_pos
		elif forwarded is InputEventGesture:
			(forwarded as InputEventGesture).position = target_pos
		
		var open_popups := _open_embedded_popups()
		var over_popup := _is_over_embedded_subwindow(target_pos)
		
		if _is_pointer_press(event):
			captured = over_popup
			if captured:
				_pointer_captured[pointer_id] = true
			else:
				_pointer_captured.erase(pointer_id)
		
		var blocked_by_exclusive := _has_exclusive_embedded_subwindow() \
									and not over_popup and not captured \
									and not _is_hover_tracking(event)
		
		if _is_pointer_press(event) and not over_popup:
			_dismiss_embedded_popups(open_popups)
		
		if not _viewport.is_input_disabled() and not blocked_by_exclusive:
			_viewport.push_input(forwarded, true)
		
		_last_target_pos[pointer_id] = target_pos
	
	if _is_pointer_release(event):
		_pointer_captured.erase(pointer_id)
	
	if released:
		_pointer_inside.erase(pointer_id)
		_last_target_pos.erase(pointer_id)
		_sync_mouse_over()
	
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_update_cursor_shape(inside, target_pos, event.position as Vector2)
	
	if inside and stop_input_propagation:
		origin_viewport.set_input_as_handled()

#endregion

#region Embedded subwindow dismissal

func _input(event: InputEvent) -> void:
	if not dismiss_popups_outside_quad: return
	if not _viewport: return
	if _viewport.gui_disable_input:
		_forget_viewport_mouse_in()
		return
	if not is_visible_in_tree(): return
	if not _is_pointer_press(event): return
	if _uv_is_inside(local_to_plane_uv(_local_position_of(event))): return
	_dismiss_embedded_popups(_open_embedded_popups())

func _is_pointer_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		return button.pressed and button.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

func _is_pointer_release(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		return not button.pressed and button.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	return false

func _is_hover_tracking(event: InputEvent) -> bool:
	return event is InputEventMouseMotion

func _embedded_subwindow_rect(subwindow: Window) -> Rect2:
	var rect := _embedded_subwindow_core_rect(subwindow)
	if not subwindow.get_flag(Window.FLAG_RESIZE_DISABLED):
		rect = rect.grow(subwindow.get_theme_constant(&"resize_margin", &"Window"))
	return rect

func _embedded_subwindow_core_rect(subwindow: Window) -> Rect2:
	var rect := Rect2(Vector2(subwindow.position), Vector2(subwindow.size))
	if subwindow.get_flag(Window.FLAG_BORDERLESS):
		return rect
	var title_height := subwindow.get_theme_constant(&"title_height", &"Window")
	rect.position.y -= title_height
	rect.size.y += title_height
	return rect

func _is_over_embedded_subwindow(point: Vector2, grow := 0.0) -> bool:
	for subwindow in _viewport.get_embedded_subwindows():
		if not subwindow.visible: continue
		if _embedded_subwindow_rect(subwindow).grow(grow).has_point(point):
			return true
	return false

func _open_embedded_popups() -> Array[Window]:
	var popups: Array[Window] = []
	for subwindow in _viewport.get_embedded_subwindows():
		if not subwindow.visible: continue
		if not subwindow.get_flag(Window.FLAG_POPUP): continue
		popups.append(subwindow)
	return popups

func _dismiss_embedded_popups(popups: Array[Window]) -> void:
	_guard_popup_menus_in_viewport()
	var ordered := popups.duplicate()
	ordered.reverse()
	for subwindow: Window in ordered:
		if not (subwindow and subwindow.visible): continue
		subwindow.hide()

func _watch_popup_menus() -> void:
	var tree := get_tree()
	if tree and not tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.connect(_on_tree_node_added)
	_guard_popup_menus_in_viewport()

func _unwatch_popup_menus() -> void:
	var tree := get_tree()
	if tree and tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.disconnect(_on_tree_node_added)
	_guarded_popup_ids.clear()

func _on_tree_node_added(node: Node) -> void:
	if _viewport == null or not (node is PopupMenu): return
	if not _viewport.is_ancestor_of(node): return
	_guard_popup_menu(node as PopupMenu)

func _guard_popup_menus_in_viewport() -> void:
	if _viewport == null: return
	var pending: Array[Node] = [_viewport]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is PopupMenu:
			_guard_popup_menu(node as PopupMenu)
		pending.append_array(node.get_children(true))

func _guard_popup_menu(popup: PopupMenu) -> void:
	var id := popup.get_instance_id()
	if _guarded_popup_ids.has(id): return
	_guarded_popup_ids.append(id)
	popup.about_to_popup.connect(_on_embedded_popup_about_to_popup.bind(popup as Window))

func _park_parent_before_engine_close(parent_popup: PopupMenu, submenu: Window) -> void:
	const ENGINE_SUBMENU_HANDLER := "::_submenu_hidden"
	if submenu.has_meta(&"pq_engine_close"): return
	
	var submenu_hide: Signal = submenu.popup_hide
	var engine_callable := Callable()
	for connection in submenu_hide.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == parent_popup and \
		   callable.get_method().ends_with(ENGINE_SUBMENU_HANDLER):
			engine_callable = callable
	if not engine_callable.is_valid(): return
	
	submenu.set_meta(&"pq_engine_close", engine_callable)
	submenu_hide.disconnect(engine_callable)
	submenu_hide.connect(_on_parked_submenu_hidden.bind(parent_popup, submenu))

func _on_parked_submenu_hidden(parent_popup: PopupMenu, submenu: Window) -> void:
	if parent_popup and parent_popup.visible:
		_park_popup_pointer(parent_popup)
	var engine_callable: Callable = submenu.get_meta(&"pq_engine_close", Callable())
	if engine_callable.is_valid():
		engine_callable.call()

func _on_embedded_popup_about_to_popup(subwindow: Window) -> void:
	var parent_popup := subwindow.get_parent() as PopupMenu
	if parent_popup == null:
		_release_embedded_mouse_focus.call_deferred()
		return
	if parent_popup.visible:
		_park_popup_pointer(parent_popup)
		_park_parent_before_engine_close(parent_popup, subwindow)
		return
	
	subwindow.hide.call_deferred()

func _release_embedded_mouse_focus() -> void:
	if _viewport == null or _viewport.is_input_disabled(): return
	_viewport.set_disable_input(true)
	_viewport.set_disable_input(false)
	_forget_viewport_mouse_in()

func _park_popup_pointer(popup: Window) -> bool:
	var size := Vector2(popup.size)
	const INSET := 1.0
	var inset_x := size.x - INSET
	var inset_y := size.y - INSET
	var candidates: PackedVector2Array = [
		Vector2(INSET, INSET),   Vector2(inset_x, INSET),
		Vector2(INSET, inset_y), Vector2(inset_x, inset_y),
	]
	for candidate in candidates:
		if candidate.x < 0.0 or candidate.y < 0.0: continue
		var local: Vector2 = Vector2(popup.position) + candidate
		if _is_over_other_embedded_subwindow(local, popup): continue
		var motion := InputEventMouseMotion.new()
		motion.position = local
		motion.global_position = local
		motion.relative = Vector2(0.0, -1.0)
		motion.velocity = Vector2(0.0, -60.0)
		_viewport.push_input(motion, true)
		return true
	return false

func _is_over_other_embedded_subwindow(point: Vector2, skip: Window) -> bool:
	for subwindow in _viewport.get_embedded_subwindows():
		if subwindow == skip: continue
		if not subwindow.visible: continue
		if _embedded_subwindow_core_rect(subwindow).has_point(point): return true
	return false

#endregion

#region Cursor shape

func _update_cursor_shape(inside: bool, target_pos: Vector2, origin_pos: Vector2) -> void:
	if not inside: _reset_cursor_override(); return
	_cursor_override_active = true
	
	var origin_viewport := get_viewport()
	var subwindow: Window = null
	var point := target_pos
	
	if origin_viewport != null and origin_viewport != _viewport:
		subwindow = _embedded_subwindow_in(origin_viewport, origin_pos)
		if subwindow != null: point = origin_pos
	if not subwindow:
		subwindow = _embedded_subwindow_at(target_pos)
		point = target_pos
	if not subwindow:
		if _has_exclusive_subwindow():
			_apply_cursor_shape(Control.CURSOR_ARROW)
		else:
			_apply_cursor_shape(_cursor_shape_at(target_pos))
	elif not _engine_owns_subwindow_cursor(subwindow, point):
		_apply_cursor_shape(_cursor_shape_in_subwindow(subwindow, point))

func _has_exclusive_subwindow() -> bool:
	if _has_exclusive_subwindow_in(_viewport): return true
	var origin_viewport := get_viewport()
	return origin_viewport != _viewport and _has_exclusive_subwindow_in(origin_viewport)

func _has_exclusive_subwindow_in(host: Viewport) -> bool:
	if not host: return false
	for subwindow in host.get_embedded_subwindows():
		if not subwindow.visible: continue
		if not subwindow.exclusive: continue
		if subwindow is Popup: continue
		return true
	return false

func _cursor_shape_at(target_pos: Vector2) -> int:
	var hovered := get_sub_viewport().gui_get_hovered_control()
	if not hovered: return Control.CURSOR_ARROW
	return hovered.get_cursor_shape(target_pos - hovered.global_position)

func _embedded_subwindow_at(point: Vector2) -> Window:
	return _embedded_subwindow_in(_viewport, point)

func _embedded_subwindow_in(host: Viewport, point: Vector2) -> Window:
	if not host: return null
	var subwindows := host.get_embedded_subwindows()
	for i: int in range(subwindows.size() - 1, -1, -1):
		var subwindow := subwindows[i]
		if not subwindow.visible: continue
		if _embedded_subwindow_rect(subwindow).grow(1.0).has_point(point):
			return subwindow
	return null

func _engine_owns_subwindow_cursor(subwindow: Window, point: Vector2) -> bool:
	for pointer_id in _pointer_captured:
		if _pointer_captured[pointer_id]: return true
	
	if subwindow.get_flag(Window.FLAG_BORDERLESS) or \
	   subwindow.get_flag(Window.FLAG_RESIZE_DISABLED): return false
	var core := _embedded_subwindow_core_rect(subwindow)
	if core.has_point(point): return false
	var margin := subwindow.get_theme_constant(&"resize_margin", &"Window") + 1.0
	return core.grow(margin).has_point(point)

func _cursor_shape_in_subwindow(subwindow: Window, point: Vector2) -> int:
	if _is_in_subwindow_titlebar(subwindow, point): return Control.CURSOR_ARROW
	var hovered := subwindow.gui_get_hovered_control()
	if not hovered: return Control.CURSOR_ARROW
	return hovered.get_cursor_shape(point - Vector2(subwindow.position) - hovered.global_position)

func _is_in_subwindow_titlebar(subwindow: Window, point: Vector2) -> bool:
	if subwindow.get_flag(Window.FLAG_BORDERLESS): return false
	var title_height := subwindow.get_theme_constant(&"title_height", &"Window")
	if title_height <= 0: return false
	var content := Rect2(Vector2(subwindow.position), Vector2(subwindow.size))
	var title := Rect2(Vector2(content.position.x, content.position.y - title_height),
					   Vector2(content.size.x, title_height))
	return title.has_point(point)

func _apply_cursor_shape(shape: int) -> void:
	Input.set_default_cursor_shape(shape as Input.CursorShape)

func _reset_cursor_override() -> void:
	if not _cursor_override_active: return
	_cursor_override_active = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _pointer_id_for(event: InputEvent) -> int:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).index
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).index
	return -1

#endregion

#region Exclusive subwindow bypass

func _connect_window_input() -> void:
	if Engine.is_editor_hint(): return
	if _window_input_connected: return
	var win := _get_root_window()
	if not win: return
	if not win.window_input.is_connected(_on_window_input):
		win.window_input.connect(_on_window_input)
	_window_input_connected = true

func _disconnect_window_input() -> void:
	if not _window_input_connected: return
	var win := _get_root_window()
	if win != null and win.window_input.is_connected(_on_window_input):
		win.window_input.disconnect(_on_window_input)
	_window_input_connected = false

func _get_root_window() -> Window:
	if not is_inside_tree(): return null
	return get_viewport().get_window() if get_viewport() else null

func _has_exclusive_embedded_subwindow() -> bool:
	if not _viewport: return false
	for subwindow in _viewport.get_embedded_subwindows():
		if not subwindow.visible: continue
		if subwindow.exclusive: return true
	return false

func _on_window_input(event: InputEvent) -> void:
	if not _viewport: return
	if not is_visible_in_tree(): return
	if not _has_exclusive_embedded_subwindow(): return
	
	if _is_positional_event(event):
		_forward_pointer_event(event)
	else:
		_forward_nonpositional_event(event)

#endregion

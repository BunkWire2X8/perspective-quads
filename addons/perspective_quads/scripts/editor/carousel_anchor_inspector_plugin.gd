## Turns [CarouselAnchor2D]'s dynamic "keyframe/<index>_<field>" properties
## into labelled rows with drag-to-reorder and delete, and replaces the plain
## [member CarouselAnchor2D.keyframe_count] spin box with an undoable
## [KeyframeCountEditor].
@tool
extends EditorInspectorPlugin

#region Plugin state

var _drag_state: DragState

#endregion

#region Drag-reorder state

## Drag-reorder state shared by every [Header] belonging to the same
## anchor within one inspector refresh pass.
class DragState:
	var headers: Array[Header] = []
	var dragging: int = -1
	var drag_to:  int = -1
	
	var line: ColorRect    = null
	var add_button: Button = null
	
	const LINE_HEIGHT := 2.0
	const LINE_NODE_NAME := &"CarouselKeyframeDropLine"
	const LINE_NODE_PATH := NodePath(LINE_NODE_NAME)
	
	var _root: Control = null
	var _style_plain: StyleBoxFlat = null
	var _style_highlight: StyleBoxFlat = null
	
	func get_root() -> Control:
		if not _root:
			_root = EditorInterface.get_base_control()
		return _root
	
	func header_style(highlighted: bool) -> StyleBoxFlat:
		if highlighted:
			if not _style_highlight:
				_style_highlight = _build_header_style(true)
			return _style_highlight
		if not _style_plain:
			_style_plain = _build_header_style(false)
		return _style_plain
	
	func _build_header_style(highlighted: bool) -> StyleBoxFlat:
		var base := get_root()
		var sb := StyleBoxFlat.new()
		if highlighted:
			sb.bg_color = base.get_theme_color(&"highlight_color", &"Editor")
			sb.border_color = base.get_theme_color(&"accent_color", &"Editor")
			sb.border_width_top   = 2
			sb.border_width_left  = 2
			sb.border_width_right = 2
		else:
			sb.bg_color = base.get_theme_color(&"dark_color_1", &"Editor")
		sb.corner_radius_top_left  = 6
		sb.corner_radius_top_right = 6
		sb.content_margin_left  = 4.0
		sb.content_margin_right = 4.0
		sb.content_margin_top    = 2.0
		sb.content_margin_bottom = 2.0
		return sb
	
	func ensure_line() -> ColorRect:
		if line and line.is_inside_tree(): return line
		
		var base := get_root()
		var existing := base.get_node_or_null(LINE_NODE_PATH)
		if existing is ColorRect:
			line = existing
			return line
		
		var ln_color := base.get_theme_color(&"selection_color", &"Editor")
		ln_color.a = 0.85
		
		const LN_SIZE := Vector2(0, LINE_HEIGHT)
		
		line = ColorRect.new()
		line.name = LINE_NODE_NAME
		line.color = ln_color
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.top_level = true
		line.z_index = 128
		line.custom_minimum_size = LN_SIZE
		line.size = LN_SIZE
		line.hide()
		base.add_child(line)
		return line

#endregion

#region Keyframe header row

## Slim header row (drag handle, index, delete) placed above each
## keyframe's property rows.
class Header extends PanelContainer:
	var anchor: CarouselAnchor2D
	var index: int
	var drag_state: DragState
	var _handle: Button
	
	func _init(anchor_: CarouselAnchor2D, index_: int, drag_state_: DragState) -> void:
		anchor = anchor_
		index = index_
		drag_state = drag_state_
		drag_state.headers.append(self)
		
		var root = drag_state.get_root()
		var hb := HBoxContainer.new()
		
		_handle = Button.new()
		_handle.icon = root.get_theme_icon(&"TripleBar", &"EditorIcons")
		_handle.flat = true
		_handle.focus_mode = Control.FOCUS_NONE
		_handle.modulate = Color(1, 1, 1, 0.4)
		_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
		_handle.tooltip_text = "Drag to reorder"
		_handle.button_down.connect(_begin_drag)
		hb.add_child(_handle)
		
		var lbl := Label.new()
		lbl.text = "Keyframe %d" % index
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lbl)
		
		var del := Button.new()
		del.icon = root.get_theme_icon(&"Remove", &"EditorIcons")
		del.flat = true
		del.tooltip_text = "Remove this keyframe"
		del.pressed.connect(_on_delete)
		hb.add_child(del)
		
		add_child(hb)
		add_theme_stylebox_override(&"panel", _style())
		set_process(false)
	
	func _style() -> StyleBoxFlat:
		return drag_state.header_style(index == drag_state.dragging)
	
	func _refresh_all_styles() -> void:
		for h in drag_state.headers:
			if h: h.add_theme_stylebox_override(&"panel", h._style())
	
	func _begin_drag() -> void:
		drag_state.dragging = index
		drag_state.drag_to = index
		_ensure_line()
		set_process(true)
		_refresh_all_styles()
		_update_line()
	
	func _process(_delta: float) -> void:
		if drag_state.dragging != index:
			set_process(false)
			return
		
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_finish_drag()
			return
		
		var to := _drop_index_at_mouse()
		if to != drag_state.drag_to:
			drag_state.drag_to = to
			_refresh_all_styles()
		
		_update_line()
	
	func _drop_index_at_mouse() -> int:
		var mpos := get_global_mouse_position()
		for k in drag_state.headers.size():
			var h = drag_state.headers[k]
			if h and mpos.y < h.get_global_rect().get_center().y:
				return k
		return drag_state.headers.size()
	
	func _ensure_line() -> void:
		drag_state.ensure_line().show()
	
	func _update_line() -> void:
		var ln := drag_state.line
		if not ln: return
		
		var count := drag_state.headers.size()
		if count == 0: return
		
		var from := drag_state.dragging
		var to := drag_state.drag_to
		var target := to if to <= from else to - 1
		if target == from:
			ln.hide()
			return
		
		var ref: Control = drag_state.headers[0]
		if not ref: return
		
		ln.show()
		var row_rect := ref.get_global_rect()
		var y := 0.0
		if to >= count:
			var btn := drag_state.add_button
			if btn:
				y = btn.get_global_rect().position.y - DragState.LINE_HEIGHT - 1.0
			else:
				var last: Control = drag_state.headers[count - 1]
				y = last.get_global_rect().end.y + 2.0
		else:
			var h: Control = drag_state.headers[to]
			if h: y = h.get_global_rect().position.y - 1.0
		
		ln.position = Vector2(row_rect.position.x, y)
		ln.size = Vector2(row_rect.size.x, DragState.LINE_HEIGHT)
	
	func _finish_drag() -> void:
		var from := drag_state.dragging
		var to   := drag_state.drag_to
		drag_state.dragging = -1
		drag_state.drag_to  = -1
		set_process(false)
		
		if drag_state.line: drag_state.line.hide()
		
		_refresh_all_styles()
		if from < 0 or to < 0 or not anchor: return
		var target := to if to <= from else to - 1
		if target != from and target >= 0 and target < anchor.keyframe_count:
			var ur = EditorInterface.get_editor_undo_redo()
			ur.create_action("Move Keyframe")
			ur.add_do_method(anchor, &"move_keyframe", from, target)
			ur.add_undo_method(anchor, &"move_keyframe", target, from)
			ur.commit_action()
	
	func _on_delete() -> void:
		if not anchor: return
		var i := index
		
		var saved_pos   := anchor.get_keyframe_position(i)
		var saved_rot   := anchor.get_keyframe_rotation(i)
		var saved_scale := anchor.get_keyframe_scale(i)
		var saved_skew  := anchor.get_keyframe_skew(i)
		var saved_mod   := anchor.get_keyframe_modulate(i)
		
		var ur = EditorInterface.get_editor_undo_redo()
		ur.create_action("Remove Keyframe")
		ur.add_do_method(anchor, &"remove_keyframe", i)
		ur.add_undo_method(anchor, &"insert_keyframe", i,
						   saved_pos, saved_rot, saved_scale, saved_skew, saved_mod)
		ur.commit_action()

#endregion

#region Keyframe count editor

## Editor for [member CarouselAnchor2D.keyframe_count], mainly existing to
## add better undo/redo support.
class KeyframeCountEditor extends EditorProperty:
	const ACTION_NAME: String = "Set Keyframe Count"
	
	var _spin: EditorSpinSlider
	var _syncing: bool = false
	
	func _init() -> void:
		_spin = EditorSpinSlider.new()
		_spin.set_flat(true)
		_spin.set_editing_integer(true)
		_spin.set_control_state(EditorSpinSlider.CONTROL_STATE_DEFAULT)
		_spin.min_value = 0
		_spin.step = 1
		_spin.allow_greater = true
		_spin.value_changed.connect(_on_value_changed)
		add_child(_spin)
		add_focusable(_spin)
	
	func _set_read_only(read_only: bool) -> void:
		_spin.set_read_only(read_only)
	
	func _update_property() -> void:
		var anchor := get_edited_object() as CarouselAnchor2D
		if not anchor: return
		var count := anchor.keyframe_count
		
		if int(_spin.get_value()) == count: return
		_syncing = true
		_spin.set_value_no_signal(count)
		_syncing = false
	
	func _on_value_changed(value: float) -> void:
		if _syncing: return
		var anchor := get_edited_object() as CarouselAnchor2D
		if not anchor: return
		
		var count := maxi(int(value), 0)
		if count == anchor.keyframe_count: return
		
		var before := anchor.get_keyframe_snapshot()
		var after := anchor.get_keyframe_snapshot(count)
		
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action(ACTION_NAME, UndoRedo.MERGE_DISABLE)
		ur.add_do_method(anchor, &"set_keyframe_snapshot", after)
		ur.add_undo_method(anchor, &"set_keyframe_snapshot", before)
		ur.commit_action()

#endregion

#region Inspector plugin entry points

func _can_handle(object: Object) -> bool:
	return object is CarouselAnchor2D

func _parse_begin(object: Object) -> void:
	_drag_state = DragState.new()

func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint,
					 _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	var anchor := object as CarouselAnchor2D
	if not anchor: return false
	
	var kf_count: int = anchor.keyframe_count
	if name == "keyframe_count":
		add_property_editor(name, KeyframeCountEditor.new())
		if kf_count == 0:
			add_property_editor(name, _make_add_button(anchor), true)
		return true
	
	var kf: int = CarouselAnchor2D._parse_keyframe_property(name)
	if kf < 0: return false
	
	var index: int = CarouselAnchor2D._keyframe_property_index(kf)
	var field: int = CarouselAnchor2D._keyframe_property_field(kf)
	if index == kf_count - 1 and field == CarouselAnchor2D._Field.MODULATE:
		add_property_editor(name, _make_add_button(anchor), true)
	elif field == CarouselAnchor2D._Field.POSITION:
		add_custom_control(Header.new(anchor, index, _drag_state))
	
	return false

func _make_add_button(anchor: CarouselAnchor2D) -> Button:
	if _drag_state.add_button: return _drag_state.add_button
	
	var root := _drag_state.get_root()
	var btn := Button.new()
	btn.text = "Add Keyframe"
	btn.icon = root.get_theme_icon(&"Add", &"EditorIcons")
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		var ur = EditorInterface.get_editor_undo_redo()
		ur.create_action("Add Keyframe")
		ur.add_do_method(anchor, &"add_keyframe")
		ur.add_undo_method(anchor, &"remove_keyframe", anchor.keyframe_count)
		ur.commit_action()
	)
	
	# Bottom anchor for the end-of-list drop target.
	_drag_state.add_button = btn
	return btn

#endregion

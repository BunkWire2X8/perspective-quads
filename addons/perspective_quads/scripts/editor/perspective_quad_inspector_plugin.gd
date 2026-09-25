## Replaces [PerspectiveQuad2D]'s [member PerspectiveQuad2D.active_shape] row
## with a pair of integer spin boxes, one per axis, each clamped by means of
## its own axis of [member PerspectiveQuad2D.grid_size].
@tool
extends EditorInspectorPlugin

#region Active shape cell editor

## Editor for [member PerspectiveQuad2D.active_shape].
class ActiveShapeEditor extends EditorProperty:
	const PROPERTY_NAME_STR: String = "active_shape"
	const PROPERTY_NAME := StringName(PROPERTY_NAME_STR)
	const ACTION_NAME: String = "Set " + PROPERTY_NAME_STR
	
	var _x_spin: EditorSpinSlider
	var _y_spin: EditorSpinSlider
	
	func _init() -> void:
		var row := VBoxContainer.new()
		var root := EditorInterface.get_base_control()
		
		var x_color := root.get_theme_color(&"property_color_x", &"Editor")
		_x_spin = _make_axis_spin(_on_x_changed, "x", x_color)
		row.add_child(_x_spin)
		
		var y_color := root.get_theme_color(&"property_color_y", &"Editor")
		_y_spin = _make_axis_spin(_on_y_changed, "y", y_color)
		row.add_child(_y_spin)
		
		add_child(row)
		add_focusable(_x_spin)
		add_focusable(_y_spin)
	
	func _make_axis_spin(handler: Callable, label: String, label_color: Color) -> EditorSpinSlider:
		var spin := EditorSpinSlider.new()
		spin.set_flat(true)
		spin.set_editing_integer(true)
		spin.set_control_state(EditorSpinSlider.CONTROL_STATE_PREFER_SLIDER)
		spin.label = label
		spin.min_value = 0
		spin.step = 1
		spin.allow_greater = false
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(handler)
		spin.add_theme_color_override(&"label_color", label_color)
		return spin
	
	func _set_read_only(read_only: bool) -> void:
		if read_only:
			_set_x_read_only(true)
			_set_y_read_only(true)
		else:
			var quad := get_edited_object() as PerspectiveQuad2D
			if not quad: return
			
			var grid_max := (quad.grid_size - Vector2i.ONE).maxi(0)
			
			_set_x_read_only(grid_max.x == 0)
			_set_y_read_only(grid_max.y == 0)
	
	func _update_property() -> void:
		var quad := get_edited_object() as PerspectiveQuad2D
		if not quad: return
		
		var grid_max := (quad.grid_size - Vector2i.ONE).maxi(0)
		
		_x_spin.max_value = grid_max.x
		_y_spin.max_value = grid_max.y
		
		var clamped := quad.active_shape.clamp(Vector2i.ZERO, grid_max)
		_x_spin.set_value_no_signal(clamped.x)
		_y_spin.set_value_no_signal(clamped.y)
		
		if not quad.use_shape_resources:
			_set_x_read_only(true)
			_set_y_read_only(true)
		else:
			_set_x_read_only(grid_max.x == 0)
			_set_y_read_only(grid_max.y == 0)
	
	func _set_x_read_only(read_only: bool) -> void:
		_set_spin_read_only(_x_spin, read_only)
	
	func _set_y_read_only(read_only: bool) -> void:
		_set_spin_read_only(_y_spin, read_only)
	
	func _set_spin_read_only(spin: EditorSpinSlider, read_only: bool) -> void:
		spin.read_only = read_only
		spin.control_state = (EditorSpinSlider.CONTROL_STATE_HIDE
							  if read_only else
							  EditorSpinSlider.CONTROL_STATE_PREFER_SLIDER)
	
	func _on_x_changed(value: float) -> void:
		_commit(Vector2i(int(value), int(_y_spin.value)))
	
	func _on_y_changed(value: float) -> void:
		_commit(Vector2i(int(_x_spin.value), int(value)))
	
	func _commit(cell: Vector2i) -> void:
		var quad := get_edited_object() as PerspectiveQuad2D
		if not quad: return
		var before: Vector2i = quad.active_shape
		if before == cell: return
		
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action(ACTION_NAME, UndoRedo.MERGE_ENDS)
		ur.add_do_property(quad, PROPERTY_NAME, cell)
		ur.add_undo_property(quad, PROPERTY_NAME, before)
		ur.commit_action()

#endregion

#region Inspector plugin entry points

func _can_handle(object: Object) -> bool:
	return object is PerspectiveQuad2D

func _parse_property(object: Object, _type: Variant.Type, name: String,
					_hint_type: PropertyHint, _hint_string: String, _usage_flags: int,
					_wide: bool) -> bool:
	if not (object is PerspectiveQuad2D): return false
	if name == ActiveShapeEditor.PROPERTY_NAME_STR: 
		add_property_editor(name, ActiveShapeEditor.new())
		return true
	return false

#endregion

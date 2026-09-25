## Registers the addon's editor extensions.
@tool
extends EditorPlugin

const PerspectiveQuadCornerEditor    := preload("uid://ddf8oydqlw0qt")
const CarouselAnchorInspectorPlugin  := preload("uid://bf0xjskm2qu6a")
const PerspectiveQuadInspectorPlugin := preload("uid://ccrswdmcwjxie")

var _corner_editor: PerspectiveQuadCornerEditor
var _carousel_anchor_inspector: CarouselAnchorInspectorPlugin
var _quad_inspector: PerspectiveQuadInspectorPlugin

func _enter_tree() -> void:
	_corner_editor = PerspectiveQuadCornerEditor.new(self)
	_carousel_anchor_inspector = CarouselAnchorInspectorPlugin.new()
	add_inspector_plugin(_carousel_anchor_inspector)
	_quad_inspector = PerspectiveQuadInspectorPlugin.new()
	add_inspector_plugin(_quad_inspector)

func _exit_tree() -> void:
	if _carousel_anchor_inspector:
		remove_inspector_plugin(_carousel_anchor_inspector)
		_carousel_anchor_inspector = null
	if _quad_inspector:
		remove_inspector_plugin(_quad_inspector)
		_quad_inspector = null
	_corner_editor = null

func _get_plugin_name() -> String:
	return "PerspectiveQuad2D"

func _handles(object: Object) -> bool:
	return _corner_editor.handles(object)

func _edit(object: Object) -> void:
	_corner_editor.edit(object)

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	_corner_editor.draw_over_viewport(overlay)

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	return _corner_editor.gui_input(event)

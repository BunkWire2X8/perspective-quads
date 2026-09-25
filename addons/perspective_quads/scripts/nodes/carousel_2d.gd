## Stationary point-and-click room rotator.
## [br][br]
## Exposes a single [member view_position] and broadcasts it through
## [signal view_position_changed] to every subscriber, so a whole scene
## can rotate together as if the viewer were turning their head.
## [br][br]
## Subscribers are every descendant [PerspectiveQuad2D] that has
## [member PerspectiveQuad2D.use_carousel] enabled, and every [CarouselAnchor2D].
@tool
@icon("uid://uwgne0bx5jmx")
class_name Carousel2D
extends Node2D

## Emits with the value returned by [method get_resolved_view_position] whenever
## [member view_position], [member loop], [member snap_to_step] or [member step]
## changes.
signal view_position_changed(t: float)

## The current view position in 0..1 range, driving shape blending and anchor placement.
## 0 = looking full left, 0.5 = center, 1 = full right.
@export_range(0.0, 1.0, 0.001) var view_position: float = 0.5:
	get = get_view_position, set = set_view_position

## When true, [member view_position] wraps with [method @GlobalScope.fposmod]
## so values outside 0..1 are valid (1.0 lands back at 0.0).
## Only use during setups where the scene loops back around to reveal a full 360 degrees.
@export var loop: bool = false:
	get = get_loop, set = set_loop

@export_group("Snap to Step")
## Snaps the view position to the nearest discrete step instead of smooth values.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "")
var snap_to_step: bool = false:
	get = get_snap_to_step, set = set_snap_to_step

## Spacing between discrete view steps, as a fraction of the 0..1 range.
## Only used when [member snap_to_step] is enabled.
@export_range(0.001, 1.0, 0.001) var step: float = 0.1:
	get = get_step, set = set_step

#region Property accessors

func get_view_position() -> float: return view_position

func set_view_position(value: float) -> void:
	view_position = value
	_emit_view_position()

func get_loop() -> bool: return loop

func set_loop(value: bool) -> void:
	loop = value
	notify_property_list_changed()
	_emit_view_position()

func get_snap_to_step() -> bool: return snap_to_step

func set_snap_to_step(value: bool) -> void:
	snap_to_step = value
	_emit_view_position()

func get_step() -> float: return step

func set_step(value: float) -> void:
	step = maxf(value, 0.0001)
	_emit_view_position()

#endregion

#region Property list

func _validate_property(property: Dictionary) -> void:
	var prop_name: StringName = property.name
	match prop_name:
		&"view_position":
			if loop:
				property.hint_string = "0.0,1.0,0.001,or_greater,or_less"

#endregion

#region View position

## [member view_position] after optional snap-to-step, clamped to 0..1
## (or wrapped when [member loop] is enabled). This is the value every
## subscriber is handed, and the value a freshly connected child pulls.
func get_resolved_view_position() -> float:
	var pos := view_position
	if snap_to_step:
		pos = roundf(view_position / step) * step
	if loop:
		return fposmod(pos, 1.0)
	return clampf(pos, 0.0, 1.0)

func _emit_view_position() -> void:
	view_position_changed.emit(get_resolved_view_position())

#endregion

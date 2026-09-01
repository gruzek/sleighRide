# instrument_carousel.gd (v2 bell selection screen) - swipe between the bells.
#
# The carousel is one number. `_offset` is its continuous position: a whole number
# means an instrument is centred, and every value between is a valid intermediate
# state. Every visible property of every instrument is a function of that
# instrument's signed cyclic distance from `_offset`, so there is no separate
# resting arrangement to keep in step with an animation. That is what makes a drag
# reversible mid-gesture and a settle catchable: both are just the number moving.
#
# Opacity is full out to `full_opacity_distance` and reaches nothing at
# `invisible_distance`. With three instruments the far side of the cycle falls at
# exactly 1.5, so a bell travelling from one side slot around to the other crosses
# over at zero opacity and the wrap is never seen. Moving `invisible_distance` off
# 1.5 looks perfectly correct standing still and shows the bell popping during a
# slow drag, which is why it is the value to suspect first.
#
# This extends sprite_position.gd rather than replacing it because the bell
# selection screen places this scene through that script's exported properties,
# and a node holds only one script.
@tool
class_name InstrumentCarousel
extends "res://app/sprite_position.gd"

# Emitted when the centred instrument is tapped. The screen hosting the carousel connects
# this and performs the navigation: the carousel has never known that screens exist. The
# choice is already published by the time this fires, so the signal carries no payload.
signal centre_tapped

# Velocity is measured across the last few drag samples rather than the last one,
# so a single stuttering frame at release cannot read as a flick.
const SAMPLE_COUNT: int = 6
const MIN_SAMPLE_SECONDS: float = 0.004
# A flick contributes at most this much, so one gesture can never skip a bell.
const MAX_FLICK_CONTRIBUTION: float = 0.9

@export var instruments: Array[InstrumentDefinition] = []:
	set(value):
		instruments = value
		_rebuild_slots()

@export_group("Slot geometry")
# Design pixels from the centre slot to a side slot.
@export var side_slot_distance: float = 170.0:
	set(value):
		side_slot_distance = value
		_render()

# Scale at a cyclic distance of one. At 0.5 the centre bell is exactly twice the
# size of each neighbour, which is the feature's sizing rule.
@export var side_slot_scale: float = 0.5:
	set(value):
		side_slot_scale = value
		_render()

@export_group("Opacity ramp")
# Cyclic distance out to which nothing is dimmed: the centre and both side slots.
@export var full_opacity_distance: float = 1.0:
	set(value):
		full_opacity_distance = value
		_render()

# Cyclic distance at which an instrument is fully invisible.
@export var invisible_distance: float = 1.5:
	set(value):
		invisible_distance = value
		_render()

@export_group("Drag feel")
# Design pixels of finger travel that equal one position.
@export var drag_distance_per_position: float = 420.0
# Fraction of a position a drag must pass to commit to the next instrument.
@export var commit_threshold: float = 0.5
# How much release speed contributes to the committed target.
@export var flick_sensitivity: float = 0.22
# Seconds the settle animation takes.
@export var settle_duration: float = 0.32

@export_group("Tap")
# Design pixels of finger travel below which a released gesture is a tap rather than a drag.
# Travel is measured in two dimensions and as the furthest point reached, so neither a
# vertical drag - which moves the carousel not at all - nor a finger that travels out and
# comes back can read as a tap.
@export var tap_travel_limit: float = 24.0
# Half-width of the tap rectangle around a centred instrument, in design pixels. Bounded by
# the slot geometry rather than by the artwork: at or above side_slot_distance divided by
# (1 + side_slot_scale) the centre rectangle reaches over the side ones and shadows them.
@export var tap_half_width: float = 110.0
# Half-height of the tap rectangle around a centred instrument, in design pixels.
# Deliberately generous, because no artwork is symmetric about its origin: the paddle bells
# reach 389 design pixels below theirs and only 291 above.
@export var tap_half_height: float = 400.0

@export_group("Drag band")
# Design pixels below the top of the viewport where the drag band starts, which
# places it under the Richmond Symphony logo.
@export var drag_band_top_inset: float = 300.0
# Design pixels above the bottom of the viewport where the band ends, which places
# it above the Jingle Cam button.
@export var drag_band_bottom_inset: float = 230.0

var _slots: Array[Node2D] = []
var _active: Array[InstrumentDefinition] = []
var _offset: float = 0.0
var _dragging: bool = false
var _drag_start_x: float = 0.0
var _drag_start_offset: float = 0.0
var _samples: Array[Vector2] = []
var _settle: Tween = null
var _press_at: Vector2 = Vector2.ZERO
var _max_travel: float = 0.0

func _ready() -> void:
	super()
	if not _tap_values_valid():
		return
	_rebuild_slots()

# Validated before any slot is built, so a mis-tuned target leaves an obviously empty screen
# rather than a carousel whose bells cannot be tapped for no visible reason.
func _tap_values_valid() -> bool:
	if tap_travel_limit <= 0.0:
		push_error("instrument_carousel: `tap_travel_limit` is %f. It is design pixels of finger travel and must be greater than 0. The correct default is 24.0." % tap_travel_limit)
		return false
	if tap_half_height <= 0.0:
		push_error("instrument_carousel: `tap_half_height` is %f. It is design pixels and must be greater than 0. The correct default is 400.0." % tap_half_height)
		return false
	var scale_sum := 1.0 + side_slot_scale
	if scale_sum <= 0.0:
		push_error("instrument_carousel: `side_slot_scale` is %f. It must be greater than -1 for the tap-width bound to be computable, and in practice belongs between 0 and 1. The correct default is 0.5." % side_slot_scale)
		return false
	var width_bound := side_slot_distance / scale_sum
	if tap_half_width <= 0.0 or tap_half_width >= width_bound:
		push_error("instrument_carousel: `tap_half_width` is %f. It must be greater than 0 and less than %f, which is `side_slot_distance` divided by (1 + `side_slot_scale`); at or above that the centre slot's tap rectangle reaches over the side slots and shadows them. The correct default is 110.0." % [tap_half_width, width_bound])
		return false
	return true

# Slots are added without an owner. An un-owned child is not serialized, which is
# what keeps this scene file holding nothing but its root even though a @tool
# script builds three instrument instances into it every time it is opened.
func _rebuild_slots() -> void:
	if not is_inside_tree():
		return
	for slot in _slots:
		remove_child(slot)
		slot.queue_free()
	_slots.clear()
	_active.clear()

	if instruments.size() < 3:
		push_error("instrument_carousel: a carousel of %d instrument(s) is not supported; use three or more. Below two there is nothing to swipe, and the carousel is the only control that advances the bell selection screen, so the screen would have no way forward. At exactly two the far side of the cycle falls at a cyclic distance of 1.0, where the opacity ramp has no room to hide the wrap." % instruments.size())
		return

	for index in instruments.size():
		var instrument: InstrumentDefinition = instruments[index]
		if instrument == null:
			push_error("instrument_carousel: entry %d of `instruments` is empty. Assign an InstrumentDefinition resource to it." % index)
			continue
		if instrument.artwork == null:
			push_error("instrument_carousel: entry %d of `instruments` has no artwork scene assigned." % index)
			continue
		var slot := Node2D.new()
		slot.name = "Slot%d" % index
		slot.add_child(instrument.artwork.instantiate())
		add_child(slot)
		_slots.append(slot)
		_active.append(instrument)

	_open_on_chosen()
	_render()
	_publish_selection()

# The carousel opens on the bell already chosen, so returning from the play screen shows what the
# audience member picked rather than resetting them to the first bell. This must run before
# _publish_selection, or the carousel overwrites the choice in the instant between being built and
# being positioned, which is the exact failure it exists to prevent. On the first entry to the
# flow nothing has been chosen and the offset stays at zero.
func _open_on_chosen() -> void:
	if Engine.is_editor_hint():
		return
	var index := _active.find(InstrumentSelection.chosen)
	if index < 0:
		return
	_offset = float(index)

func _render() -> void:
	var count := _slots.size()
	if count == 0:
		return
	for index in count:
		var slot := _slots[index]
		var distance := cyclic_distance(float(index) - _offset, count)
		var spread := absf(distance)
		var alpha := opacity_at(spread, full_opacity_distance, invisible_distance)
		slot.position = Vector2(side_slot_distance * distance, 0.0)
		slot.scale = Vector2.ONE * pow(side_slot_scale, spread)
		slot.modulate = Color(1.0, 1.0, 1.0, alpha)
		slot.visible = alpha > 0.0
		# Nearer the centre draws in front, so the side bells sit behind the chosen one.
		slot.z_index = int(roundf(clampf(100.0 - spread * 10.0, -100.0, 100.0)))

# Signed distance around the cycle, measured the short way, so the instrument
# before the first one is the last one.
static func cyclic_distance(raw: float, count: int) -> float:
	var distance := fposmod(raw, float(count))
	if distance > float(count) * 0.5:
		distance -= float(count)
	return distance

static func opacity_at(spread: float, full_to: float, invisible_at: float) -> float:
	if spread <= full_to:
		return 1.0
	if spread >= invisible_at:
		return 0.0
	# Both bounds equal is the degenerate ramp of zero width; the branches above
	# have already answered every case it could be asked about.
	if invisible_at <= full_to:
		return 0.0
	return 1.0 - smoothstep(0.0, 1.0, (spread - full_to) / (invisible_at - full_to))

# The drag band is derived from the viewport rather than from the design canvas,
# so it tracks the logo above it and the button below it as the screen grows.
#
# It is measured against the safe area rather than the physical screen edges,
# because both of the things it is bounded by are: the logo respects the safe area
# and the button is held above the home indicator by safe_area_margin.gd. Measured
# from the physical bottom instead, the band would reach over the top of the button
# on a phone with a home indicator.
func drag_band_rect() -> Rect2:
	var viewport_rect := get_viewport_rect()
	var reference := safe_area_rect(viewport_rect)
	# A display server with no window reports a zero-sized one, which makes the
	# safe-area fractions a division by zero. A display that does not exist has no
	# notch to stay clear of, so the viewport is the reference in that case.
	if not (is_finite(reference.position.y) and is_finite(reference.size.y)):
		reference = viewport_rect
	var top := reference.position.y + drag_band_top_inset
	var bottom := reference.position.y + reference.size.y - drag_band_bottom_inset
	return Rect2(viewport_rect.position.x, top, viewport_rect.size.x, maxf(0.0, bottom - top))

# Touch and mouse are both handled, because neither can be assumed. iOS reports no
# mouse at all, so relying on Godot's touch-to-mouse emulation leaves the phone -
# the only platform that matters here - dead. The desktop and the editor have no
# touch, so both families are needed.
#
# Where a platform delivers both for one finger, the duplicate is harmless: a
# press arriving while a drag is already running is dropped, and a move recomputes
# the offset from an absolute pointer position rather than accumulating a delta,
# so handling it twice lands on the same number.
#
# A press inside the Jingle Cam button is marked handled during interface input,
# which runs before this, so the button keeps its own rectangle without any check
# here. The band is also measured so that it ends above the button, which is what
# keeps that true on a platform that routes touch differently.
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _slots.size() < 2:
		return
	if event is InputEventScreenTouch:
		_pointer_button(event.pressed, event.position)
	elif event is InputEventScreenDrag:
		_pointer_moved(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_button(event.pressed, event.position)
	elif event is InputEventMouseMotion:
		_pointer_moved(event.position)

# The event is marked handled before the gesture is dispatched, never after. A release can end
# in a tap on the centred bell, which emits centre_tapped, and a listener is free to change the
# scene in response. Touching this node's viewport after that has run reaches into a scene the
# engine is already replacing, which crashes rather than failing.
func _pointer_button(pressed: bool, at: Vector2) -> void:
	if pressed:
		if _dragging or not drag_band_rect().has_point(at):
			return
		_press_at = at
		_max_travel = 0.0
		get_viewport().set_input_as_handled()
		_begin_drag(at.x)
	elif _dragging:
		get_viewport().set_input_as_handled()
		_end_drag(at)

func _pointer_moved(at: Vector2) -> void:
	if not _dragging:
		return
	_max_travel = maxf(_max_travel, _press_at.distance_to(at))
	_continue_drag(at.x)
	get_viewport().set_input_as_handled()

# A press arriving mid-settle kills the tween and picks the carousel up wherever
# it currently sits, so the bells are caught rather than restarted.
func _begin_drag(pointer_x: float) -> void:
	_stop_settle()
	_dragging = true
	_drag_start_x = pointer_x
	_drag_start_offset = _offset
	_samples = [Vector2(_seconds(), _offset)]

func _continue_drag(pointer_x: float) -> void:
	# Moving the finger left raises the offset, which advances the carousel.
	_offset = _drag_start_offset - (pointer_x - _drag_start_x) / drag_distance_per_position
	_samples.append(Vector2(_seconds(), _offset))
	if _samples.size() > SAMPLE_COUNT:
		_samples.remove_at(0)
	_render()
	_publish_selection()

func _end_drag(at: Vector2) -> void:
	_dragging = false
	if _max_travel <= tap_travel_limit:
		_handle_tap(at)
		return
	var predicted := _offset + clampf(
		_release_speed() * flick_sensitivity, -MAX_FLICK_CONTRIBUTION, MAX_FLICK_CONTRIBUTION)
	var lower := floorf(predicted)
	var target := lower + 1.0 if predicted - lower >= commit_threshold else lower
	_settle_to(target)

# Offset positions per second across the retained samples.
func _release_speed() -> float:
	if _samples.size() < 2:
		return 0.0
	var first := _samples[0]
	var last := _samples[_samples.size() - 1]
	var elapsed := last.x - first.x
	if elapsed <= MIN_SAMPLE_SECONDS:
		return 0.0
	return (last.y - first.y) / elapsed

# A tap that hit no instrument still settles, and that is not a contradiction of "a tap on
# nothing does nothing". The press that began this gesture killed any running settle, so
# returning here would leave the carousel stranded between two bells. Settling to the
# nearest whole position finishes the animation the press interrupted: it changes no
# selection, emits nothing, and _settle_to returns at once when the carousel was at rest.
func _handle_tap(at: Vector2) -> void:
	var count := _slots.size()
	var index := _slot_at(at)
	if index < 0:
		_settle_to(roundf(_offset))
		return
	# The same expression _publish_selection uses, so the bell that advances the screen
	# and the bell that has been published can never disagree.
	if index == int(fposmod(roundf(_offset), float(count))):
		centre_tapped.emit()
		return
	_settle_to(_offset + cyclic_distance(float(index) - _offset, count))

# The index of the slot whose tap rectangle contains a point, or -1 for none.
#
# The rectangle is the authored half-extents scaled by the slot's own scale, which _render
# has already set, so the target matches what is drawn at every point of a drag rather than
# only at rest. Invisible slots are skipped, so the slot sitting at the wrap point behind the
# others is never tapped. Overlapping rectangles resolve to the smallest cyclic distance,
# which is the ordering _render uses to set z_index, so the slot that takes the tap is the
# one drawn in front of the others.
#
# slot.global_position is a canvas coordinate and `at` is a viewport coordinate. They
# coincide because these screens carry no camera and no canvas transform, which is the same
# assumption drag_band_rect makes when its viewport-derived rectangle is tested against an
# event position.
func _slot_at(at: Vector2) -> int:
	var count := _slots.size()
	var best := -1
	var best_spread := INF
	for index in count:
		var slot := _slots[index]
		if not slot.visible:
			continue
		var half := Vector2(tap_half_width, tap_half_height) * slot.scale
		if not Rect2(slot.global_position - half, half * 2.0).has_point(at):
			continue
		var spread := absf(cyclic_distance(float(index) - _offset, count))
		if spread < best_spread:
			best_spread = spread
			best = index
	return best

func _settle_to(target: float) -> void:
	_stop_settle()
	if is_equal_approx(_offset, target):
		_set_offset(target)
		return
	_settle = create_tween()
	_settle.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_settle.tween_method(_set_offset, _offset, target, settle_duration)

func _stop_settle() -> void:
	if _settle != null and _settle.is_valid():
		_settle.kill()
	_settle = null

func _set_offset(value: float) -> void:
	_offset = value
	_render()
	_publish_selection()

# The chosen instrument is the one nearest the centre, kept current as the
# carousel moves, so the choice is already correct the moment the centred bell is
# tapped. That is what lets `centre_tapped` carry no payload.
func _publish_selection() -> void:
	if Engine.is_editor_hint():
		return
	var count := _active.size()
	if count == 0:
		return
	var index := int(fposmod(roundf(_offset), float(count)))
	if InstrumentSelection.chosen != _active[index]:
		InstrumentSelection.chosen = _active[index]

func _seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

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
extends "res://app/sprite_position.gd"

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

@export_group("Drag band")
# Design pixels below the top of the viewport where the drag band starts, which
# places it under the Richmond Symphony logo.
@export var drag_band_top_inset: float = 300.0
# Design pixels above the bottom of the viewport where the band ends, which places
# it above the continue button.
@export var drag_band_bottom_inset: float = 230.0

var _slots: Array[Node2D] = []
var _active: Array[InstrumentDefinition] = []
var _offset: float = 0.0
var _dragging: bool = false
var _drag_start_x: float = 0.0
var _drag_start_offset: float = 0.0
var _samples: Array[Vector2] = []
var _settle: Tween = null

func _ready() -> void:
	super()
	_rebuild_slots()

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

	if instruments.size() == 2:
		push_error("instrument_carousel: a carousel of exactly two instruments is not supported. Use one instrument, or three or more.")
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
# A press inside the continue button is marked handled during interface input,
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

func _pointer_button(pressed: bool, at: Vector2) -> void:
	if pressed:
		if _dragging or not drag_band_rect().has_point(at):
			return
		_begin_drag(at.x)
	elif _dragging:
		_end_drag()
	else:
		return
	get_viewport().set_input_as_handled()

func _pointer_moved(at: Vector2) -> void:
	if not _dragging:
		return
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

func _end_drag() -> void:
	_dragging = false
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
# carousel moves, so the selection screen's continue button needs no code of its
# own and the choice is already correct the moment it is pressed.
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

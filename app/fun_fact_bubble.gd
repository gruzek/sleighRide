# fun_fact_bubble.gd (C1_17 fun facts) - Winnie's speech bubble, and the fact inside it.
#
# One fact is drawn when the screen is entered and held until the screen is left. Facts come
# from a shuffle bag rather than a random pick, because the play screen's Back button rebuilds
# this screen from nothing and somebody trying all three bells passes through it three times in
# under a minute. Independent draws from a small pool repeat inside that, and a repeat reads as
# the application having very little to say rather than as chance.
#
# The bag is a static variable. It survives the scene change that destroys this node, for as
# long as the application is running, and it is written nowhere. An autoload would do the same
# job and is deliberately not used: there are two in this application and each is needed by
# more than one screen, which a bag belonging to one node on one screen is not.
#
# The entrance scales this node and carries the text with it; the pulse scales the bubble
# sprite alone. There is nothing to read while the bubble is arriving, but once the fact is
# legible a five percent wobble resamples the glyphs on the one thing on this screen anybody is
# actually reading.
#
# The pop grows from the tip of the tail rather than from the middle of the shape, which is set
# in the scene by the sprite's centered and offset properties and carries no value here. That is
# the same arrangement the red tree's pivot uses, and for the same reason: where the artwork
# meets Winnie's mouth is positioned by eye in the editor.
#
# This extends sprite_position.gd rather than replacing it because the bell selection screen
# places this scene through that script's exported properties, and a node holds only one script.
# The title animation and the bell carousel both met the same collision and resolved it the
# same way.
@tool
extends "res://app/sprite_position.gd"

# The three children this scene is built from. Named here rather than inferred so that a rename
# stops the bubble with a message, instead of bringing it in silently without its text.
const BUBBLE_NAME: String = "Bubble"
const HEADER_NAME: String = "Header"
const FACT_NAME: String = "Fact"

# Unticked, the bubble sits at its authored size showing whatever the scene holds, and nothing
# moves. That is the scene exactly as it renders in the editor.
@export var animate: bool = true

# The pool. Any length; adding a fact is adding an entry. An empty pool hides the bubble at
# runtime, because a heading over an empty white shape is worse than no bubble at all.
@export var facts: Array[String] = []

@export_group("Text")
@export var header_text: String = "DID YOU KNOW?"
# The one place the typeface is set. Both labels take it from here, so the brand face arriving
# later is this one property. Left unset, nothing is applied and the engine's default face is
# used, which is the state the feature specification describes rather than a fallback.
@export var typeface: Font = null
@export var header_font_size: int = 44
# The fact starts at this size and is stepped down until it fits the label's box.
@export var fact_font_size: int = 40
# and never below this, because text too small to read in a darkened hall has failed its only job.
@export var minimum_fact_font_size: int = 26

@export_group("Rhythm")
# Stillness after the screen appears, so the bubble does not arrive on top of the carousel
# building itself. One beat.
@export var initial_delay_seconds: float = 0.75
# One quarter note, from the title animation. 0.75 seconds is 80 beats per minute.
@export var beat_seconds: float = 0.75
# The repeating unit, in beats: two bars of 4/4, matching the title.
@export var loop_beats: int = 8

@export_group("Entrance")
# How far past its resting size the bubble carries before coming back, as a multiple of it.
@export var entrance_overshoot: float = 1.12
@export var entrance_grow_seconds: float = 0.12
@export var entrance_settle_seconds: float = 0.18

@export_group("Pulse")
# The peak, not a value passed through: the pulse has no overshoot to correct.
@export var pulse_peak: float = 1.05
@export var pulse_grow_seconds: float = 0.12
@export var pulse_return_seconds: float = 0.20

# Shuffled facts not yet shown, the next draw taken from the end. Static, so it outlives this
# node and every scene change, and is refilled from the pool when it empties.
static var _bag: Array[String] = []

var _bubble: Sprite2D = null
var _header: Label = null
var _fact: Label = null
var _resting_scale: Vector2 = Vector2.ONE
var _bubble_resting_scale: Vector2 = Vector2.ONE

# super() first, so the placement script positions the root in the editor as well as at runtime.
# The editor stops there: the bubble must stay visible at its authored size while a screen is
# being composed, so no fact is drawn, the pool is not consulted, and an empty pool does not
# hide the artwork somebody is trying to lay out.
func _ready() -> void:
	super()
	if Engine.is_editor_hint() or not animate:
		return
	if not _collect_nodes():
		return
	if not _validate_exports():
		return
	# Captured before anything is scaled. Both resting scales are authored in the scene and exist
	# nowhere else once the entrance has zeroed the root.
	_resting_scale = scale
	_bubble_resting_scale = _bubble.scale
	_apply_typeface()
	_header.text = header_text
	_header.add_theme_font_size_override("font_size", header_font_size)
	if facts.is_empty():
		visible = false
		return
	_fact.text = _draw_fact_from(facts)
	_fit_fact()
	# Before the first frame is drawn, not when the delay expires. A bubble left at its authored
	# scale for even one frame is a flash of the finished thing before the entrance collapses it.
	scale = Vector2.ZERO
	_conduct()

func _collect_nodes() -> bool:
	_bubble = get_node_or_null(NodePath(BUBBLE_NAME)) as Sprite2D
	if _bubble == null:
		push_error("fun_fact_bubble: no Sprite2D child named `%s`. The bubble needs children named %s, %s, and %s." % [BUBBLE_NAME, BUBBLE_NAME, HEADER_NAME, FACT_NAME])
		return false
	_header = get_node_or_null(NodePath(HEADER_NAME)) as Label
	if _header == null:
		push_error("fun_fact_bubble: no Label child named `%s`. The bubble needs children named %s, %s, and %s." % [HEADER_NAME, BUBBLE_NAME, HEADER_NAME, FACT_NAME])
		return false
	_fact = get_node_or_null(NodePath(FACT_NAME)) as Label
	if _fact == null:
		push_error("fun_fact_bubble: no Label child named `%s`. The bubble needs children named %s, %s, and %s." % [FACT_NAME, BUBBLE_NAME, HEADER_NAME, FACT_NAME])
		return false
	return true

# The values used as a divisor, a bound, or a loop count. Each is easy to mistype in the
# inspector while adjusting something else, and each produces a silent wrong result rather than
# an obvious one, so a bad value stops the bubble with a message rather than being corrected.
func _validate_exports() -> bool:
	if beat_seconds <= 0.0:
		push_error("fun_fact_bubble: `beat_seconds` is %.3f. It must be greater than 0, and the default is 0.75, which is 80 beats per minute." % beat_seconds)
		return false
	if loop_beats < 1:
		push_error("fun_fact_bubble: `loop_beats` is %d. It must be at least 1, and the default is 8, which is two bars of 4/4." % loop_beats)
		return false
	if minimum_fact_font_size < 1:
		push_error("fun_fact_bubble: `minimum_fact_font_size` is %d. It must be at least 1, and the default is 26." % minimum_fact_font_size)
		return false
	if fact_font_size < minimum_fact_font_size:
		push_error("fun_fact_bubble: `fact_font_size` is %d and `minimum_fact_font_size` is %d. The starting size must not be below the floor, and the defaults are 40 and 26." % [fact_font_size, minimum_fact_font_size])
		return false
	if header_font_size < 1:
		push_error("fun_fact_bubble: `header_font_size` is %d. It must be at least 1, and the default is 44." % header_font_size)
		return false
	# The loop has to be longer than the gesture it carries, or the rest between gestures is a
	# negative interval and the pulse runs continuously instead of on the beat.
	var loop := _loop_seconds()
	var entrance := entrance_grow_seconds + entrance_settle_seconds
	if loop <= entrance:
		push_error("fun_fact_bubble: the loop is %.3f seconds and the entrance takes %.3f. `beat_seconds` times `loop_beats` must exceed it, and the defaults of 0.75 and 8 give 6.0 seconds." % [loop, entrance])
		return false
	var pulse := pulse_grow_seconds + pulse_return_seconds
	if loop <= pulse:
		push_error("fun_fact_bubble: the loop is %.3f seconds and the pulse takes %.3f. `beat_seconds` times `loop_beats` must exceed it, and the defaults of 0.75 and 8 give 6.0 seconds." % [loop, pulse])
		return false
	return true

# Both labels take the typeface from the one exported property, so the brand face arriving later
# is a single change. Unset is the specified state today rather than a missing value: the engine's
# default face is what the feature was built to show until a font is licensed.
func _apply_typeface() -> void:
	if typeface == null:
		return
	_header.add_theme_font_override("font", typeface)
	_fact.add_theme_font_override("font", typeface)

# Refilled and reshuffled when it empties, so every fact is shown once before any is repeated.
# It refills from the pool as it stands at that moment, so a fact added between visits is picked
# up at the next refill rather than being missing from a shuffle taken earlier.
static func _draw_fact_from(pool: Array[String]) -> String:
	if _bag.is_empty():
		_bag = pool.duplicate()
		_bag.shuffle()
	return _bag.pop_back()

# Label has no fit-to-box mode, so the size is found by measuring. The label's box is authored in
# the scene, which is what keeps moving the text around a scene edit rather than a code change.
func _fit_fact() -> void:
	var font := _fact.get_theme_font("font")
	var box := _fact.size
	for size in range(fact_font_size, minimum_fact_font_size - 1, -1):
		var needed := font.get_multiline_string_size(_fact.text, HORIZONTAL_ALIGNMENT_CENTER, box.x, size)
		if needed.y <= box.y:
			_fact.add_theme_font_size_override("font_size", size)
			return
	_fact.add_theme_font_size_override("font_size", minimum_fact_font_size)
	push_error("fun_fact_bubble: a fact does not fit the bubble at the %d-pixel floor and is clipped. Shorten it, or raise `minimum_fact_font_size` knowing it becomes harder to read at arm's length. The fact is: %s" % [minimum_fact_font_size, _fact.text])

# Two tweens carry the pattern and neither animates anything itself beyond its own gesture. The
# opening is played once - the delay, the entrance, and the rest of that first loop - and hands
# over to the pulse, which repeats for as long as the screen is up. Both are bound to this node
# and are killed with it, so a scene change needs no cleanup of its own.
func _conduct() -> void:
	var opening := create_tween()
	opening.tween_interval(initial_delay_seconds)
	# Off the mark fast and decelerating into the peak, then eased at both ends coming off it, so
	# the two motions read as a hit followed by a settle rather than as two hits.
	opening.tween_property(self, "scale", _resting_scale * entrance_overshoot, entrance_grow_seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	opening.tween_property(self, "scale", _resting_scale, entrance_settle_seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	opening.tween_interval(_loop_seconds() - entrance_grow_seconds - entrance_settle_seconds)
	opening.tween_callback(_start_pulsing)

# The shape alone. The sprite's origin is the tail tip, the same point the root scales about, so
# the pulse and the entrance grow from the same place and the labels are left where they are.
func _start_pulsing() -> void:
	var pulsing := create_tween().set_loops()
	pulsing.tween_property(_bubble, "scale", _bubble_resting_scale * pulse_peak, pulse_grow_seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pulsing.tween_property(_bubble, "scale", _bubble_resting_scale, pulse_return_seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	pulsing.tween_interval(_loop_seconds() - pulse_grow_seconds - pulse_return_seconds)

func _loop_seconds() -> float:
	return beat_seconds * float(loop_beats)

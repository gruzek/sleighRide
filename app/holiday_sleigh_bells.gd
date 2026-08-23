# holiday_sleigh_bells.gd (C1_14 title animation) - the three words arrive on the beat, then breathe on it.
#
# The gesture is written as a rhythm rather than as a list of durations: one beat is a quarter
# note, a loop is eight of them, and the three words fire on the first three beats of every
# loop. The first loop is the entrance, where a word grows from nothing past its resting size
# and settles back onto it; every loop after it is the pulse, the same phrase spoken quietly.
#
# Every size here is a multiplier on the scale each word is saved at, captured once in _ready.
# The three words are hand-sized differently and will be sized again, so an animation naming
# those numbers would quietly undo the next composition change made in the editor.
#
# This extends sprite_position.gd rather than replacing it because the title screen places this
# scene through that script's exported properties, and a node holds only one script. The
# Instrument Carousel feature (C1_08) met the same collision and resolved it the same way.
@tool
extends "res://app/sprite_position.gd"

# The words, in reading order, which is also their order in the scene. The names are written
# here rather than inferred from the children so that a missing or renamed word stops the
# animation with a message, instead of bringing the title in as two words and saying nothing.
const WORD_NAMES: Array[String] = ["Holiday", "Sleigh", "Bells"]

# Each beat of the opening loop, counted from 1, as it is reached. It exists so that something
# else on the screen can arrive in time with the phrase without holding a second copy of the
# tempo: this scene stays the only place the beat is defined, and changing `beat_seconds` still
# moves everything together. Only the opening announces; once the pulse takes over the phrase has
# been spoken and there is nothing left to arrive on.
signal entrance_beat_reached(beat_index: int)

# Unticked, the three words sit at their authored scales and nothing moves, which is the scene
# exactly as it rendered before this feature.
@export var animate: bool = true

@export_group("Rhythm")
# Stillness after the screen appears, before the first word arrives.
@export var initial_delay_seconds: float = 1.0
# One quarter note. 0.75 seconds is 80 beats per minute, and a bar is 3.0 seconds.
@export var beat_seconds: float = 0.75
# The repeating unit, in beats: two bars of 4/4, being three words and then five beats of rest.
# In beats rather than seconds so that changing the tempo moves the whole pattern together and
# the loop cannot be set to a length that is not in time with the beat.
@export var loop_beats: int = 8

@export_group("Entrance")
# How far past its resting size a word carries before coming back, as a multiple of it.
@export var entrance_overshoot: float = 1.12
@export var entrance_grow_seconds: float = 0.12
@export var entrance_settle_seconds: float = 0.18

@export_group("Pulse")
# The peak, not a value passed through: the pulse has no overshoot to correct.
@export var pulse_peak: float = 1.05
@export var pulse_grow_seconds: float = 0.12
@export var pulse_return_seconds: float = 0.20

var _words: Array[Sprite2D] = []
var _resting_scales: Array[Vector2] = []

# super() first, so the placement script positions the root in the editor as well as at
# runtime. The editor stops there: scaling the words to zero while the scene is open would
# take the artwork off the 2D editor and make the composition impossible to author.
func _ready() -> void:
	super()
	if Engine.is_editor_hint() or not animate:
		return
	if not _collect_words():
		return
	if loop_beats < WORD_NAMES.size():
		push_error("holiday_sleigh_bells: `loop_beats` is %d. It must be at least %d, one beat for each word, and the default is 8." % [loop_beats, WORD_NAMES.size()])
		return
	# Before the first frame is drawn, not when the delay expires. A word left at its authored
	# scale for even one frame is a flash of the finished title before the entrance collapses it.
	for word in _words:
		word.scale = Vector2.ZERO
	_conduct()

# The resting scales are captured before anything is scaled, because a resting scale is
# authored in the scene and exists nowhere else once the words have been zeroed.
func _collect_words() -> bool:
	_words.clear()
	_resting_scales.clear()
	for word_name in WORD_NAMES:
		var word := get_node_or_null(NodePath(word_name)) as Sprite2D
		if word == null:
			push_error("holiday_sleigh_bells: no Sprite2D child named `%s`. The title animation needs all three of %s, in that order." % [word_name, ", ".join(PackedStringArray(WORD_NAMES))])
			return false
		_words.append(word)
		_resting_scales.append(word.scale)
	return true

# Three tweens carry the pattern and none animates anything itself; all three only schedule. The
# opening is played once - the delay, the entrance, and the rest of that first loop - and hands
# over to the pulse, which repeats for as long as the screen is up. The clock runs alongside the
# opening and announces its beats. All are bound to this node and are killed with it, so a scene
# change needs no cleanup of its own.
func _conduct() -> void:
	var opening := create_tween()
	opening.tween_interval(initial_delay_seconds)
	opening.tween_callback(_play_set.bind(true))
	opening.tween_interval(_loop_seconds())
	opening.tween_callback(_start_pulsing)

	# The clock is a separate tween rather than callbacks threaded into the opening, because the
	# opening schedules the phrase in two hops and a beat has to be announced on every one of the
	# loop's beats, including the five that carry no word.
	var clock := create_tween()
	clock.tween_interval(initial_delay_seconds)
	for index in loop_beats:
		clock.tween_callback(entrance_beat_reached.emit.bind(index + 1))
		clock.tween_interval(beat_seconds)

func _start_pulsing() -> void:
	var pulsing := create_tween().set_loops()
	pulsing.tween_callback(_play_set.bind(false))
	pulsing.tween_interval(_loop_seconds())

# One set of three: the same gesture on each word, one beat apart, in reading order. The
# stagger is the point of the feature - three words together is a title appearing, three words
# a beat apart is a title being spoken.
func _play_set(entrance: bool) -> void:
	for index in _words.size():
		var word := _words[index]
		var resting := _resting_scales[index]
		var peak := resting * (entrance_overshoot if entrance else pulse_peak)
		var grow_seconds := entrance_grow_seconds if entrance else pulse_grow_seconds
		var return_seconds := entrance_settle_seconds if entrance else pulse_return_seconds
		var word_tween := create_tween()
		if index > 0:
			word_tween.tween_interval(beat_seconds * float(index))
		# Off the mark fast and decelerating into the peak, then eased at both ends coming off
		# it, so the two motions read as a hit followed by a settle rather than as two hits.
		word_tween.tween_property(word, "scale", peak, grow_seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		word_tween.tween_property(word, "scale", resting, return_seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _loop_seconds() -> float:
	return beat_seconds * float(loop_beats)

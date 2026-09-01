# jingle_response.gd (C1_02 shake instrument) - sounds a bell on every detected stop.
#
# Which recording sounds is chosen by how hard the stop was, and how loudly it sounds is scaled
# by the same stop on a continuous scale. Both act at once and they are doing different jobs: the
# bank choice gives the change of character between a soft strike and a hard one, which volume
# cannot produce, and the ramp gives the continuous response inside each band, so a shake at the
# bottom of the piano range is still softer than one at the top of it.
#
# The recordings come from one of two places, chosen by use_chosen_bell. On the play screen they
# come from the bell the audience member picked, which this node reads for itself rather than
# having the screen assign it: both this node and its parent run _ready, and the order between
# them is fixed in the direction that would make an assignment from the screen arrive too late.
# Everywhere else the recording is the exported stream, which is how the capture harness uses it.
#
# The exported stream resolves into a one-entry piano bank with an empty forte bank, so there is
# one code path below _resolve_banks rather than a bank-driven shape and a single-stream shape
# with a branch between them at every step. The harness sounds exactly as it did before.
extends Node

# When true the recordings are the chosen bell's, read from the InstrumentSelection autoload.
# When false they are the exported stream below. False is the default so a node that predates
# this option keeps behaving as it did.
@export var use_chosen_bell: bool = false

@export var stream: AudioStream

# The highest level that draws from the piano bank; every level above it draws from the forte
# bank. The detector quantises a stop into five levels, so this is the boundary between "a light
# shake" and "a hard one" and it is the one number to move when that boundary is wrong.
@export var piano_top_level: int = 2

# Intensity 0 sounds at the quietest, intensity 1 at the loudest.
@export var quietest_db: float = -24.0
@export var loudest_db: float = 0.0

# Voices are sized from the longest recording the bell carries against the highest sustained
# event rate the C1_09 measurements found, 6.77 stops per second, rounded up to eight for margin.
# The longest is the right measure because the pool exists to stop a recording being cut short by
# reuse of its voice, and the longest is the one most at risk of it. The tightest measured gap
# between two stops is 50 milliseconds, but that is a transient between one pair of stops rather
# than a rate anything sustains. The trade is stated plainly: a burst faster than the pool holds
# reuses its oldest voice and cuts a recording short.
const EVENTS_PER_SECOND: float = 8.0
const MINIMUM_VOICES: int = 4

var _piano: Array[AudioStream] = []
var _forte: Array[AudioStream] = []
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

# The recording that sounded last, excluded from the next draw. Held across bank changes, so a
# stop crossing from piano to forte is not treated as a fresh start.
var _last_played: AudioStream = null

func _ready() -> void:
	if piano_top_level < 1 or piano_top_level > 4:
		push_error("jingle_response piano_top_level is %d and must be between 1 and 4, so that at least one level draws from each bank. The default is 2." % piano_top_level)
		return
	if not _resolve_banks():
		return
	for index in _voice_count():
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)
	ShakeEvents.jingled.connect(_on_jingled)

# Returns false after reporting why, in which case this node connects to nothing and is inert.
# Nothing is substituted: a silent bell is a fault to be fixed, not a case to be handled.
func _resolve_banks() -> bool:
	if not use_chosen_bell:
		if stream == null:
			push_error("jingle_response has no stream assigned, so it is inert. Set its Stream property to a recording in res://sounds/v2/, or tick Use Chosen Bell to sound the bell the audience member picked.")
			return false
		_piano = [stream]
		_forte = []
		return true
	var chosen: InstrumentDefinition = InstrumentSelection.chosen
	if chosen == null:
		push_error("jingle_response is set to sound the chosen bell, but no bell has been chosen, so it is inert. Reach this screen through the flow, which starts at res://app/main.tscn.")
		return false
	if chosen.piano_samples.is_empty():
		push_error("jingle_response is set to sound the chosen bell, but that bell's Piano Samples bank is empty, so it is inert. Every bell sounds its piano bank at some level. Assign recordings to the InstrumentDefinition in res://app/instruments/.")
		return false
	if not _bank_is_complete(chosen.piano_samples, "Piano Samples"):
		return false
	if not _bank_is_complete(chosen.forte_samples, "Forte Samples"):
		return false
	_piano = chosen.piano_samples
	_forte = chosen.forte_samples
	return true

# An empty entry in an exported array is one click to make and invisible to read past in a list
# of twenty-five, so it is caught here by name rather than as a null at the moment of playing.
func _bank_is_complete(bank: Array[AudioStream], bank_name: String) -> bool:
	for index in bank.size():
		if bank[index] == null:
			push_error("jingle_response: entry %d of the chosen bell's %s bank is empty, so it is inert. Assign a recording to it in res://app/instruments/." % [index, bank_name])
			return false
	return true

func _voice_count() -> int:
	var longest: float = 0.0
	for sample in _piano:
		longest = maxf(longest, sample.get_length())
	for sample in _forte:
		longest = maxf(longest, sample.get_length())
	return maxi(int(ceilf(longest * EVENTS_PER_SECOND)), MINIMUM_VOICES)

func _on_jingled(event: ShakeEvent) -> void:
	var sample: AudioStream = _draw_from(_bank_for(event.level))
	_last_played = sample
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = sample
	voice.volume_db = lerpf(quietest_db, loudest_db, event.intensity)
	voice.play()

# An empty forte bank is a bell with no dynamic layers, which sounds its piano bank at every
# level. That is not a fallback: the bell has one bank because one bank was recorded, and it
# still answers how hard it was shaken through the loudness ramp.
func _bank_for(level: int) -> Array[AudioStream]:
	if _forte.is_empty() or level <= piano_top_level:
		return _piano
	return _forte

# Random within the bank, excluding whatever sounded last. Excluding by index in one pass rather
# than drawing and retrying: a retry loop never exits on a bank holding the same recording twice,
# which is an easy assignment to make by hand and an invisible one to read, and it would hang the
# application on the first shake with nothing on screen to say why.
#
# A bank of one repeats, because there is no alternative to draw. A last-played recording that is
# not in this bank gives find a result of -1 and a free draw, which is the crossing from one bank
# to the other: a recording that is not in the bank cannot be repeated by it.
func _draw_from(bank: Array[AudioStream]) -> AudioStream:
	var last_index: int = bank.find(_last_played)
	if bank.size() == 1 or last_index < 0:
		return bank[randi() % bank.size()]
	var pick: int = randi() % (bank.size() - 1)
	if pick >= last_index:
		pick += 1
	return bank[pick]

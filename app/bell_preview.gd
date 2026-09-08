# bell_preview.gd (bell selection screen) - sounds a bell as it arrives at the centre.
#
# The selection screen asks the audience member to choose between three bells and, until now, gave
# them nothing to choose on but the artwork. This node answers a change of selection with a single
# jingle from the bell that just arrived, so the choice is made by ear as well as by eye.
#
# It does not know how the carousel works and the carousel does not know this exists. The screen
# connects the two, which is the same arrangement the tap-to-play signal uses: the carousel emits
# that the centred bell changed, and app/instrument_select.gd decides what that means.
#
# This is a preview rather than an instrument. It answers a selection, not a shake, so it does not
# connect to the ShakeEvents bus, carries no notion of how hard anything was struck, and sounds at
# one exported level and one exported loudness every time.
extends Node

# Which of the detector's five levels this preview sounds at. It picks the bank the same way
# shake/responses/jingle_response.gd does, so a bell with a forte bank previews with the same
# change of character a real shake at this level would have. Three is the middle of the five and
# is above the responder's default piano_top_level of 2, so a bell carrying both banks previews
# from its forte recordings.
@export var preview_level: int = 3

# Where the preview sits on the responder's loudness ramp, 0 quietest and 1 loudest. Half is a
# jingle that carries across a noisy lobby without being the loudest thing the bell can do.
@export var preview_intensity: float = 0.5

@export var quietest_db: float = -24.0
@export var loudest_db: float = 0.0

# The boundary between the two banks, matching the responder's own default so a preview and a
# shake at the same level draw from the same place.
@export var piano_top_level: int = 2

# Enough voices that swiping quickly through the bells overlaps rather than cuts. A preview is one
# short jingle and a person cannot swipe faster than a few a second, so this is small on purpose.
const VOICE_COUNT: int = 3

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played: AudioStream = null

func _ready() -> void:
	if preview_level < 1 or preview_level > 5:
		push_error("bell_preview: `preview_level` is %d. It must be between 1 and 5, matching the five levels the shake detector quantises a stop into, and the default is 3." % preview_level)
		return
	if preview_intensity < 0.0 or preview_intensity > 1.0:
		push_error("bell_preview: `preview_intensity` is %f. It must be between 0.0 and 1.0, and the default is 0.5." % preview_intensity)
		return
	if piano_top_level < 1 or piano_top_level > 4:
		push_error("bell_preview: `piano_top_level` is %d. It must be between 1 and 4, so that at least one level draws from each bank, and the default is 2." % piano_top_level)
		return
	for index in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)

# Sounds the bell that has just arrived at the centre. The screen calls this; nothing here watches
# the carousel.
func play(bell: InstrumentDefinition) -> void:
	if _voices.is_empty():
		return
	if bell == null:
		push_error("bell_preview: asked to preview a bell that is null. The carousel publishes the centred bell before it reports the change, so this means the change was reported by something else.")
		return
	var bank := BellSampler.bank_for(bell, preview_level, piano_top_level)
	if bank.is_empty():
		push_error("bell_preview: the bell arriving at the centre has no recordings to preview. Assign recordings to its InstrumentDefinition in res://app/instruments/.")
		return
	var sample := BellSampler.draw_from(bank, _last_played)
	if sample == null:
		push_error("bell_preview: the bell arriving at the centre has an empty entry in the bank this preview draws from. Assign a recording to it in res://app/instruments/.")
		return
	_last_played = sample
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = sample
	voice.volume_db = lerpf(quietest_db, loudest_db, preview_intensity)
	voice.play()

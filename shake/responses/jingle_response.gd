# jingle_response.gd (C1_02 shake instrument) - sounds a bell on every detected stop.
#
# The recording comes from one of two places, chosen by use_chosen_bell. On the play screen it
# comes from the bell the audience member picked, which this node reads for itself rather than
# having the screen assign it: both this node and its parent run _ready, and the order between
# them is fixed in the direction that would make an assignment from the screen arrive too late.
# Reading the selection here removes the ordering question and keeps the play screen from
# knowing anything about how sound is produced. Everywhere else the recording is the exported
# stream, which is how the capture harness uses it.
#
# Sounding a different recording per intensity level later replaces the single recording with an
# array indexed by ShakeEvent.level, and changes nothing outside this file.
extends Node

# When true the recording is the chosen bell's, read from the InstrumentSelection autoload.
# When false it is the exported stream below. False is the default so a node that predates this
# option keeps behaving as it did.
@export var use_chosen_bell: bool = false

@export var stream: AudioStream

# Intensity 0 sounds at the quietest, intensity 1 at the loudest.
@export var quietest_db: float = -24.0
@export var loudest_db: float = 0.0

# Voices are sized from the recording's own length against the highest sustained event rate the
# C1_09 measurements found, 6.77 stops per second, rounded up to eight for margin. The tightest
# measured gap between two stops is 50 milliseconds, but that is a transient between one pair of
# stops rather than a rate anything sustains, and provisioning for it as though it were sustained
# would build audio players that can never all be needed at once. The trade is stated plainly: a
# burst faster than the pool holds reuses its oldest voice and cuts a recording short.
const EVENTS_PER_SECOND: float = 8.0
const MINIMUM_VOICES: int = 4

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

func _ready() -> void:
	var recording: AudioStream = _recording()
	if recording == null:
		return
	for index in _voice_count(recording):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = recording
		add_child(player)
		_voices.append(player)
	ShakeEvents.jingled.connect(_on_jingled)

# Returns null after reporting why, in which case this node connects to nothing and is inert.
# Nothing is substituted: a silent bell is a fault to be fixed, not a case to be handled.
func _recording() -> AudioStream:
	if not use_chosen_bell:
		if stream == null:
			push_error("jingle_response has no stream assigned, so it is inert. Set its Stream property to a sound in res://sounds/, or tick Use Chosen Bell to sound the bell the audience member picked.")
			return null
		return stream
	var chosen: InstrumentDefinition = InstrumentSelection.chosen
	if chosen == null:
		push_error("jingle_response is set to sound the chosen bell, but no bell has been chosen, so it is inert. Reach this screen through the flow, which starts at res://app/main.tscn.")
		return null
	if chosen.sound == null:
		push_error("jingle_response is set to sound the chosen bell, but that bell carries no recording, so it is inert. Assign a sound to the InstrumentDefinition in res://app/instruments/.")
		return null
	return chosen.sound

func _voice_count(recording: AudioStream) -> int:
	return maxi(int(ceilf(recording.get_length() * EVENTS_PER_SECOND)), MINIMUM_VOICES)

func _on_jingled(event: ShakeEvent) -> void:
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.volume_db = lerpf(quietest_db, loudest_db, event.intensity)
	voice.play()

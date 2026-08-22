# jingle_response.gd (C1_02 shake instrument) - sounds a bell on every detected stop.
#
# Eight voices because the sound is 0.46 seconds long and the tightest measured gap between two
# real stops is 58 milliseconds. A single player would cut off almost every jingle; eight lets
# them overlap the way loose bells in a shell actually do. Voices are taken in turn, so the one
# reused is always the oldest.
#
# Swapping the sound is swapping the exported stream. Sounding a different recording per
# intensity level later replaces that one field with an array indexed by ShakeEvent.level, and
# changes nothing else in this file or anywhere else.
extends Node

@export var stream: AudioStream

@export var voice_count: int = 8

# Intensity 0 sounds at the quietest, intensity 1 at the loudest.
@export var quietest_db: float = -24.0
@export var loudest_db: float = 0.0

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

func _ready() -> void:
	if stream == null:
		push_error("jingle_response has no stream assigned, so it is inert. Set its Stream property to a sound in res://sounds/.")
		return
	if voice_count < 1:
		push_error("jingle_response needs at least one voice and voice_count is %d, so it is inert. Set voice_count to 8." % voice_count)
		return
	for index in voice_count:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = stream
		add_child(player)
		_voices.append(player)
	ShakeEvents.jingled.connect(_on_jingled)

func _on_jingled(event: ShakeEvent) -> void:
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.volume_db = lerpf(quietest_db, loudest_db, event.intensity)
	voice.play()

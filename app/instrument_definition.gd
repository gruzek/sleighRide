# instrument_definition.gd (v2) - one bell the audience can choose.
#
# An instrument is the artwork scene that draws it and the recording it sounds. How
# large the artwork is and where it sits relative to its own origin are authored in
# that scene, so the carousel scales and places a slot rather than correcting the
# artwork.
#
# The recording lives on the bell rather than on the play screen because the bell is
# already the thing that travels between screens: the selection screen publishes it,
# an autoload carries it across the scene change, and the play screen reads it. A
# recording attached here therefore arrives where it is needed without any screen
# having to know which bell was picked.
@tool
class_name InstrumentDefinition
extends Resource

@export var artwork: PackedScene

# The bell this instrument sounds, played once per detected stop. One recording per
# bell for now; sounding a different take per intensity level later replaces this
# with an array indexed by ShakeEvent.level.
@export var sound: AudioStream

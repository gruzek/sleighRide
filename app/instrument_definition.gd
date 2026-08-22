# instrument_definition.gd (v2) - one bell the audience can choose.
#
# An instrument is the artwork scene that draws it, and nothing else. How large it
# is and where it sits relative to its own origin are authored in that scene, so
# the carousel scales and places a slot rather than correcting the artwork. Each
# bell's set of recordings is added here when that feature is built.
@tool
class_name InstrumentDefinition
extends Resource

@export var artwork: PackedScene

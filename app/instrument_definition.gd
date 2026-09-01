# instrument_definition.gd (v2) - one bell the audience can choose.
#
# An instrument is the artwork scene that draws it and the recordings it sounds. How large the
# artwork is and where it sits relative to its own origin are authored in that scene, so the
# carousel scales and places a slot rather than correcting the artwork.
#
# The recordings live on the bell rather than on the play screen because the bell is already the
# thing that travels between screens: the selection screen publishes it, an autoload carries it
# across the scene change, and the play screen reads it.
#
# Two banks rather than one list indexed by level. The delivered recordings are split by how hard
# the instrument was struck, not by five gradations of it, and a struck bell changes timbre with
# force rather than only amplitude - which is the whole reason the choice is a recording and not
# a volume. Which levels take which bank is the responder's business, not the bell's.
@tool
class_name InstrumentDefinition
extends Resource

@export var artwork: PackedScene

# Softly struck recordings. A bell sounds these at every level when it has no forte bank, so this
# is the bank a bell cannot be without.
@export var piano_samples: Array[AudioStream] = []

# Hard struck recordings. Left empty for a bell whose recordings carry no dynamic layers, which
# is the strap bells: twenty-five takes were delivered for it, none of them split by dynamic.
@export var forte_samples: Array[AudioStream] = []

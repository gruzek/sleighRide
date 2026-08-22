# shake_event_bus.gd (C1_02 shake instrument) - autoloaded as ShakeEvents.
#
# The whole of the coupling between the thing that detects a stop and the things that respond to
# one. A responder connects to this signal in its own _ready and never refers to the detector; a
# detector emits and never refers to a responder. Adding, removing, or replacing an effect is
# therefore adding or deleting a node, with no wiring to change.
#
# This is global because it is stateless and costs nothing when nothing is shaking. The detector
# is deliberately not global: it belongs to the screen that wants an instrument, not to the
# title and instructions screens.
extends Node

signal jingled(event: ShakeEvent)

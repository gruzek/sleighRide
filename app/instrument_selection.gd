# instrument_selection.gd (v2) - carries the chosen bell across a scene change.
#
# The bell selection screen advances with change_scene_to_file, which frees the
# scene tree and everything held in it, so the choice cannot live on a node. This
# is an autoload, which is instanced once at startup and survives that call.
#
# Nothing is written to disk. The choice lasts for the session, which is all the
# flow needs. The play screen can return to the selection screen, so the choice is
# read as well as written after the flow has moved past it: the carousel opens on
# whatever is held here rather than resetting to the first bell.
extends Node

var chosen: InstrumentDefinition = null

# bell_sampler.gd - which of a bell's recordings to sound, and which one to draw next.
#
# Two decisions that anything sounding a bell has to make, written once so a second thing that
# sounds one does not arrive at them again by hand. shake/responses/jingle_response.gd made both
# for the play screen; app/bell_preview.gd needs the same two on the selection screen and takes
# them from here.
#
# It holds no state. The caller keeps its own last-played recording and hands it in, because a
# preview and an instrument are two independent runs of "not the same one twice" that should not
# be able to interfere with each other.
class_name BellSampler
extends Object

# The bank a level draws from.
#
# An empty forte bank is a bell with no dynamic layers, which sounds its piano bank at every level.
# That is not a fallback: the bell has one bank because one bank was recorded, and the strap bells
# are the case - twenty-five takes delivered with no dynamic split.
static func bank_for(bell: InstrumentDefinition, level: int, piano_top_level: int) -> Array[AudioStream]:
	if bell == null:
		return []
	if bell.forte_samples.is_empty() or level <= piano_top_level:
		return bell.piano_samples
	return bell.forte_samples

# Random within the bank, excluding whatever sounded last.
#
# The exclusion is by index in one pass rather than a draw-and-retry loop. A retry loop never
# terminates on a bank holding the same recording in two entries, which is one mis-click to create
# in a list of twenty-five near-identical filenames and would hang the application on the first
# jingle with nothing on screen to say why.
#
# A bank of one repeats, because there is nothing else to draw. A last-played recording that is not
# in this bank gives a find of -1 and a free draw, which is the crossing from one bank to the
# other: a recording that is not in the bank cannot be repeated by it.
static func draw_from(bank: Array[AudioStream], last_played: AudioStream) -> AudioStream:
	if bank.is_empty():
		return null
	var last_index: int = bank.find(last_played)
	if bank.size() == 1 or last_index < 0:
		return bank[randi() % bank.size()]
	var pick: int = randi() % (bank.size() - 1)
	if pick >= last_index:
		pick += 1
	return bank[pick]

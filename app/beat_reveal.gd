# beat_reveal.gd (title screen) - fades a control in on a beat of the title phrase.
#
# The start button is not on screen while the title is still being spoken. It arrives on the beat
# after the last word, so the phrase finishes and then the invitation appears, rather than the
# two competing for the same moment.
#
# The beat is not counted here. app/holiday_sleigh_bells.gd announces each beat of its opening
# loop and this listens, so the tempo lives in exactly one place and changing `beat_seconds`
# there still moves everything together. A second copy of the delay and the beat would be in
# time on the day it was written and silently out of time after the first adjustment.
#
# It fades rather than popping. The three words growing is the gesture that carries the title,
# and a fourth thing popping alongside them reads as a fourth word.
#
# This extends safe_area_margin.gd rather than replacing it because the button is bottom-anchored
# and needs holding clear of the home indicator, and a node holds only one script. The bell
# carousel and the title animation both met the same collision and resolved it the same way.
@tool
extends "res://app/safe_area_margin.gd"

# Unticked, the control is simply present from the first frame, which is the screen exactly as it
# rendered before this behaviour.
@export var animate: bool = true

# The scene announcing the beats. Reached by path and validated when ready, so a rename or a
# reparent surfaces at load rather than as a button that never appears.
@export var title_animation: NodePath

# Counted from 1, so the three words land on 1, 2, and 3 and the default of 4 is the beat after
# the phrase. It is validated against the announcing scene's own loop length, because a beat past
# the end of the loop is never announced and the control would stay hidden with nothing said.
@export var reveal_on_beat: int = 4

@export var fade_seconds: float = 0.4

func _ready() -> void:
	super()
	if Engine.is_editor_hint() or not animate:
		return
	var announcer := get_node_or_null(title_animation)
	if announcer == null:
		push_error("beat_reveal: `title_animation` does not name a node. Point it at the scene that announces the beats, which on the title screen is the Holiday Sleigh Bells artwork.")
		return
	if not announcer.has_signal("entrance_beat_reached"):
		push_error("beat_reveal: `%s` does not announce beats. `title_animation` must name a node carrying app/holiday_sleigh_bells.gd." % announcer.name)
		return
	if reveal_on_beat < 1 or reveal_on_beat > announcer.loop_beats:
		push_error("beat_reveal: `reveal_on_beat` is %d and the phrase is %d beats long. It must be between 1 and %d, and the default is 4, the beat after the last word." % [reveal_on_beat, announcer.loop_beats, announcer.loop_beats])
		return
	if fade_seconds <= 0.0:
		push_error("beat_reveal: `fade_seconds` is %.3f. It must be greater than 0, and the default is 0.4." % fade_seconds)
		return
	# Hidden rather than transparent, so the control cannot be pressed before it is offered. A
	# fully faded button still takes a touch, and the one on this screen leaves the title screen.
	visible = false
	modulate.a = 0.0
	announcer.entrance_beat_reached.connect(_on_beat_reached)

func _on_beat_reached(beat_index: int) -> void:
	if beat_index != reveal_on_beat:
		return
	visible = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, fade_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# flash_response.gd (C1_02 shake instrument) - flashes the screen on every detected stop.
#
# A worked example of a swappable effect as much as an effect in its own right. It reads only
# ShakeEvent.intensity, so the instrument animation that eventually replaces it connects to the
# same signal and needs to know nothing about how a stop is detected.
#
# The flash takes the brighter of the current level and the new one rather than replacing it, so
# a hard stop landing during the fade of a soft one is not dimmed by it.
extends ColorRect

@export var max_alpha: float = 0.85
@export var fade_seconds: float = 0.25

var _alpha: float = 0.0

# Processing is switched off while the flash is dark and on again when one arrives. This node
# shares a screen with the capture harness, whose sample clock is the frame clock, so a per-frame
# callback that exists only to return immediately is cost the measurement would pay for.
func _ready() -> void:
	color = Color(1.0, 1.0, 1.0, 0.0)
	set_process(false)
	ShakeEvents.jingled.connect(_on_jingled)

func _process(delta: float) -> void:
	_alpha = maxf(_alpha - delta / fade_seconds, 0.0)
	color = Color(1.0, 1.0, 1.0, _alpha)
	if _alpha <= 0.0:
		set_process(false)

func _on_jingled(event: ShakeEvent) -> void:
	_alpha = maxf(_alpha, event.intensity * max_alpha)
	color = Color(1.0, 1.0, 1.0, _alpha)
	set_process(true)

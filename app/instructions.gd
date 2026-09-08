# instructions.gd (v2 instructions screen)
extends Control

# Where the privacy policy lives. Both app stores require the policy to be reachable from inside
# the application and not only from the store listing, and this screen is where it is reachable
# from: it is in the ordinary path through the flow and it is not the screen anybody is playing on.
#
# The Richmond Symphony publishes the page; until they do, this address is the one thing to change
# here, and it is deliberately the only place the address appears.
const PRIVACY_POLICY_URL: String = "https://www.richmondsymphony.com/who-we-are/privacy-policy/"

@onready var continue_button: Button = $ContinueButton
# The link is a Button inside a Node2D rather than a Control on the screen root, because it sits
# in the middle of the screen rather than against an edge. app/sprite_position.gd places it by
# design_position the way every other piece of composition here is placed, and that script extends
# Node2D and cannot attach to a Control directly - the same shape app/fun_fact_bubble.tscn uses.
@onready var privacy_policy_button: Button = $PrivacyPolicyLink/Link

func _ready() -> void:
	if continue_button == null:
		push_error("instructions: no Button node named `ContinueButton`. The screen cannot advance to the bell selection without it.")
		return
	if privacy_policy_button == null:
		push_error("instructions: no Button node at `PrivacyPolicyLink/Link`. Both app stores require the privacy policy to be reachable from inside the application, so the screen cannot ship without it.")
		return
	continue_button.pressed.connect(_on_continue_pressed)
	privacy_policy_button.pressed.connect(_on_privacy_policy_pressed)

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://app/instrument_select.tscn")

# Hands the address to the phone, which opens it in whatever browser the person uses. The
# application has no browser of its own and wants none: a policy shown inside the application
# would be a second copy of a page the Symphony maintains, and the two would drift apart.
func _on_privacy_policy_pressed() -> void:
	var error: int = OS.shell_open(PRIVACY_POLICY_URL)
	if error != OK:
		push_error("instructions: the phone would not open `%s` (error %d). The privacy policy is unreachable from inside the application, which both app stores require it to be." % [PRIVACY_POLICY_URL, error])

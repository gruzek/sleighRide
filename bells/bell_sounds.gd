# BellHitSound.gd (Godot 4.4.x)
extends RigidBody2D

@export var hit_sounds: Array[AudioStream] = []

# Thresholds
@export var min_speed_wall: float = 180.0     # wall/anything non-bell
@export var min_speed_bell: float = 240.0     # bell vs bell (higher to avoid chatter)

# Loudness mapping
@export var max_speed: float = 1500.0         # speed that maps to max volume
@export var min_db: float = -22.0
@export var max_db: float = 0.0

# Trigger control
@export var min_time_between_triggers: float = 0.07  # debounce for spam contacts

# Upgrade logic (while playing)
@export var upgrade_ratio: float = 1.5        # new impact must be >= current*ratio to replace
@export var upgrade_min_db_delta: float = 5.0 # or at least this much louder to replace

@onready var player: AudioStreamPlayer2D = $HitSound

var _cooldown_left: float = 0.0
var _current_impact: float = 0.0   # proxy for "how strong is the currently playing jingle"
var _current_db: float = -80.0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)

func _physics_process(dt: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= dt

	# If the sound finished, clear intensity so next real hit can start fresh
	if not player.playing:
		_current_impact = 0.0
		_current_db = -80.0

func _on_body_entered(other: Node) -> void:
	# Compute an "impact speed" that suppresses resting contacts:
	# - bell vs bell: use relative velocity
	# - bell vs wall/other: use this bell's speed
	var impact_speed: float = _compute_impact_speed(other)

	# Choose threshold based on what we hit
	var threshold: float = min_speed_wall
	if other is RigidBody2D and other.is_in_group("bells"):
		threshold = min_speed_bell	
	
	if impact_speed < threshold:
		return

	# Map impact_speed -> target dB
	var target_db: float = _impact_to_db(impact_speed, threshold)

	# Decide whether to trigger / upgrade
	var is_playing: bool = player.playing

	# If already playing, ignore weaker taps (prevents warble)
	if is_playing:
		var upgrade_by_ratio := impact_speed >= _current_impact * upgrade_ratio
		var upgrade_by_db := (target_db - _current_db) >= upgrade_min_db_delta

		# Only allow replacing the sound if it's meaningfully stronger
		if not (upgrade_by_ratio or upgrade_by_db):
			return

		# If we are upgrading, allow it even if cooldown is active (optional).
		# Otherwise you'd sometimes "miss" a strong hit.
	else:
		# Not playing: debounce spam
		if _cooldown_left > 0.0:
			return

	_play_jingle(target_db, impact_speed, is_playing)

	# Apply cooldown only on "new start"; upgrades can be immediate
	if not is_playing:
		_cooldown_left = min_time_between_triggers

func _compute_impact_speed(other: Node) -> float:
	var my_v: Vector2 = linear_velocity

	# If other is another bell rigidbody, use relative speed
	if other is RigidBody2D and other.is_in_group("bells"):
		var other_rb := other as RigidBody2D
		return (my_v - other_rb.linear_velocity).length()

	# Otherwise use my speed
	return my_v.length()

func _impact_to_db(impact_speed: float, threshold: float) -> float:
	# Map [threshold .. max_speed] -> [min_db .. max_db]
	var denom: float = max(1.0, (max_speed - threshold))
	var t: float = clamp((impact_speed - threshold) / denom, 0.0, 1.0)
	return lerp(min_db, max_db, t)

func _play_jingle(target_db: float, impact_speed: float, allow_restart: bool) -> void:
	# Pick a sound (optional variety)
	if hit_sounds.size() > 0:
		player.stream = hit_sounds[randi() % hit_sounds.size()]

	player.volume_db = target_db
	player.pitch_scale = randf_range(0.95, 1.05)

	# If upgrading, restart to "replace" a weak sound with a strong one
	if allow_restart and player.playing:
		player.stop()

	player.play()

	_current_impact = impact_speed
	_current_db = target_db

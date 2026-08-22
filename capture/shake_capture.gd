# shake_capture.gd (C1_09 capture harness) - records raw motion samples, one file per run.
#
# Sampling happens in _process and never in _physics_process. The engine refreshes the motion
# values once per rendered frame, immediately before the main loop iterates, so _process maps
# one to one onto the data that exists. A physics callback runs on its own clock and would read
# the same value more than once or skip one entirely, manufacturing samples that correspond to
# nothing measured. bells/native_gravity_controller.gd samples in _physics_process and is the
# pattern this deliberately does not follow.
#
# The sample clock is the frame clock. Nothing on this screen animates, and nothing is written
# to disk while a run is active: a write inside the run would put file system latency into the
# very interval being measured. Samples are held in memory and the whole file is written in one
# operation when the run stops.
extends Control

const FORMAT_BANNER: String = "holiday_sleigh_bells_shake_capture v2"
const COLUMN_HEADER: String = "sample,t_ms,dt_ms,accel_x,accel_y,accel_z,grav_x,grav_y,grav_z,gyro_x,gyro_y,gyro_z,hit,hit_magnitude,hit_intensity,hit_level"
const CAPTURE_DIR: String = "user://"

# One sample is fifteen numbers held flat in a single buffer, so the per-frame cost is fifteen
# writes into memory that was reserved before the run began. The reserve is two minutes at 120
# samples per second, which is what an iPhone 13 Pro actually delivers; a longer run grows the
# buffer, and the frame that grows it shows the cost as a gap in t_ms rather than hiding it.
const FIELDS_PER_SAMPLE: int = 15
const RESERVE_SAMPLES: int = 14400

# The readout is refreshed ten times a second rather than every frame. It is a liveness check,
# and re-laying five labels on the same clock the run is measuring is a cost the measurement
# would otherwise pay for.
const READOUT_INTERVAL_S: float = 0.1

@onready var record_button: Button = $RecordButton
@onready var elapsed_label: Label = $Readout/ElapsedLabel
@onready var sample_count_label: Label = $Readout/SampleCountLabel
@onready var rate_label: Label = $Readout/RateLabel
@onready var magnitude_label: Label = $Readout/MagnitudeLabel
@onready var file_path_label: Label = $Readout/FilePathLabel
@onready var shake_detector: Node = $ShakeDetector

var _recording: bool = false
var _samples: PackedFloat64Array = PackedFloat64Array()
var _sample_count: int = 0
var _origin_usec: int = 0
var _latest_usec: int = 0
var _run_started_at: Dictionary = {}
var _readout_accumulator: float = 0.0

# The detection fired on the frame currently being recorded, or null. shake_detector runs at a
# lower process priority than this node, so a stop detected on a frame is latched here before
# that frame's row is written and lands on the row it actually belongs to.
var _pending_hit: ShakeEvent = null

# The detector is validated here rather than where its properties are read. Those reads happen
# only inside _write_run, which runs after a capture has already been performed, so a renamed or
# missing node would surface as a truncated file and a lost run rather than as a startup error.
func _ready() -> void:
	if shake_detector == null:
		push_error("shake_capture expects a child node named ShakeDetector. Add shake/shake_detector.tscn as a child with that name, or every recorded run will fail at the moment it is written.")
	_samples.resize(RESERVE_SAMPLES * FIELDS_PER_SAMPLE)
	record_button.pressed.connect(_on_record_pressed)
	ShakeEvents.jingled.connect(_on_jingled)
	_update_readout()

func _on_jingled(event: ShakeEvent) -> void:
	_pending_hit = event

func _process(delta: float) -> void:
	if _recording:
		_record_sample(delta)
	_readout_accumulator += delta
	if _readout_accumulator >= READOUT_INTERVAL_S:
		_readout_accumulator = 0.0
		_update_readout()

func _on_record_pressed() -> void:
	if _recording:
		_stop_run()
	else:
		_start_run()

func _start_run() -> void:
	_sample_count = 0
	_origin_usec = 0
	_latest_usec = 0
	_run_started_at = Time.get_datetime_dict_from_system()
	_recording = true
	record_button.text = "Stop"
	file_path_label.text = "recording"
	_update_readout()

func _stop_run() -> void:
	_recording = false
	record_button.text = "Start"
	_write_run()
	_update_readout()

# Nothing is filtered, clamped, smoothed, or skipped between the sensor and this buffer, and
# nothing derived is stored in place of a measured value. Linear acceleration, jerk, magnitude,
# and any projection onto a motion axis are all computable from these twelve columns during
# analysis; computing one here would embed the choice this feature exists to make.
func _record_sample(delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	var accel: Vector3 = Input.get_accelerometer()
	var gravity: Vector3 = Input.get_gravity()
	var gyro: Vector3 = Input.get_gyroscope()
	if _sample_count == 0:
		_origin_usec = now_usec
	_latest_usec = now_usec
	var index: int = _sample_count * FIELDS_PER_SAMPLE
	if index + FIELDS_PER_SAMPLE > _samples.size():
		_samples.resize(_samples.size() + RESERVE_SAMPLES * FIELDS_PER_SAMPLE)
	_samples[index] = float(now_usec - _origin_usec) / 1000.0
	_samples[index + 1] = delta * 1000.0
	_samples[index + 2] = accel.x
	_samples[index + 3] = accel.y
	_samples[index + 4] = accel.z
	_samples[index + 5] = gravity.x
	_samples[index + 6] = gravity.y
	_samples[index + 7] = gravity.z
	_samples[index + 8] = gyro.x
	_samples[index + 9] = gyro.y
	_samples[index + 10] = gyro.z
	if _pending_hit == null:
		_samples[index + 11] = 0.0
		_samples[index + 12] = 0.0
		_samples[index + 13] = 0.0
		_samples[index + 14] = 0.0
	else:
		_samples[index + 11] = 1.0
		_samples[index + 12] = _pending_hit.magnitude
		_samples[index + 13] = _pending_hit.intensity
		_samples[index + 14] = float(_pending_hit.level)
		_pending_hit = null
	_sample_count += 1

func _write_run() -> void:
	if _sample_count < 2 or _latest_usec <= _origin_usec:
		file_path_label.text = "not written: the run held %d sample(s). Press Start, hold the phone for a second, then press Stop." % _sample_count
		return
	var duration_s: float = float(_latest_usec - _origin_usec) / 1000000.0
	var achieved_rate_hz: float = float(_sample_count) / duration_s
	var path: String = CAPTURE_DIR + _run_file_name()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		file_path_label.text = "could not write %s (error %d). The run was not saved. Free space on the device and record it again." % [path, FileAccess.get_open_error()]
		return
	file.store_string(_header_text(duration_s, achieved_rate_hz))
	for index in _sample_count:
		file.store_string(_row_text(index))
	file.close()
	file_path_label.text = "wrote %s (%d samples)" % [path, _sample_count]

# The header records the engine's own settings rather than a constant, because a constant was
# wrong. This harness first claimed a target of 60 on the reasoning that the engine hard-codes
# preferredFrameRate to 60; the iPhone 13 Pro runs recorded on 2026-08-22 achieved 119.7 and
# 120.1 samples per second, so it does not. delta_smoothing is recorded because it decides
# whether dt_ms is a measurement or a snapped constant, and that cannot be told from the
# column alone without a run long enough to catch the engine passing a raw value through.
func _header_text(duration_s: float, achieved_rate_hz: float) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# " + FORMAT_BANNER)
	lines.append("# recorded_at=" + _run_timestamp_iso())
	lines.append("# device_model=" + OS.get_model_name())
	lines.append("# os_name=" + OS.get_name())
	lines.append("# os_version=" + OS.get_version())
	lines.append("# engine_version=" + str(Engine.get_version_info()["string"]))
	lines.append("# screen_refresh_hz=%.2f" % DisplayServer.screen_get_refresh_rate())
	lines.append("# engine_max_fps=%d" % Engine.max_fps)
	lines.append("# delta_smoothing=%s" % str(ProjectSettings.get_setting("application/run/delta_smoothing")))
	lines.append("# sample_count=%d" % _sample_count)
	lines.append("# duration_s=%.3f" % duration_s)
	lines.append("# achieved_rate_hz=%.2f" % achieved_rate_hz)
	lines.append("# longest_frame_ms=%.1f" % _longest_interval_ms())
	lines.append("# fire_threshold=%.3f" % shake_detector.fire_threshold)
	lines.append("# release_fraction=%.3f" % shake_detector.release_fraction)
	lines.append("# intensity_floor=%.3f" % shake_detector.intensity_floor)
	lines.append("# intensity_ceiling=%.3f" % shake_detector.intensity_ceiling)
	lines.append("# level_count=%d" % shake_detector.level_count)
	lines.append("# hit_count=%d" % _hit_count())
	lines.append(COLUMN_HEADER)
	lines.append("")
	return "\n".join(lines)

# The longest frame is measured from the monotonic timestamps rather than from the dt_ms the
# engine reported, because those are not the same quantity. dt_ms is the engine's belief about
# the interval, and the run recorded on 2026-08-22 showed that belief to be a constant 16.667
# across every frame while the real intervals ranged from 12.14 to 19.43 milliseconds. Godot's
# application/run/delta_smoothing snaps the reported delta to the refresh interval, and this
# project turns it off, but the header reports what the clock measured either way. A long frame
# during a shake is the one artefact that cannot be told apart from a slower shake afterwards,
# so the field that reports it is derived from the truth rather than from the report.
func _longest_interval_ms() -> float:
	var longest: float = 0.0
	for index in range(1, _sample_count):
		var interval: float = _sample_time_ms(index) - _sample_time_ms(index - 1)
		if interval > longest:
			longest = interval
	return longest

# The detector's calibration is written into every file because a hit column is only diagnosable
# against the constants that produced it. A run recorded under one threshold and read months
# later under another would otherwise look like the algorithm had changed its mind.
func _hit_count() -> int:
	var count: int = 0
	for index in _sample_count:
		if _samples[index * FIELDS_PER_SAMPLE + 11] > 0.0:
			count += 1
	return count

func _row_text(index: int) -> String:
	var base: int = index * FIELDS_PER_SAMPLE
	return "%d,%.3f,%.3f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%d,%.5f,%.5f,%d\n" % [
		index,
		_samples[base],
		_samples[base + 1],
		_samples[base + 2],
		_samples[base + 3],
		_samples[base + 4],
		_samples[base + 5],
		_samples[base + 6],
		_samples[base + 7],
		_samples[base + 8],
		_samples[base + 9],
		_samples[base + 10],
		int(_samples[base + 11]),
		_samples[base + 12],
		_samples[base + 13],
		int(_samples[base + 14]),
	]

# Hyphens rather than colons in the time portion, because a colon is not safe in a file name on
# every platform these files are later copied to. No label or description is collected on the
# device: a timestamp cannot be mislabelled during capture, and a picker can.
func _run_file_name() -> String:
	return "%04d-%02d-%02d_%02d-%02d-%02d.csv" % [
		_run_started_at["year"],
		_run_started_at["month"],
		_run_started_at["day"],
		_run_started_at["hour"],
		_run_started_at["minute"],
		_run_started_at["second"],
	]

func _run_timestamp_iso() -> String:
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		_run_started_at["year"],
		_run_started_at["month"],
		_run_started_at["day"],
		_run_started_at["hour"],
		_run_started_at["minute"],
		_run_started_at["second"],
	]

func _update_readout() -> void:
	elapsed_label.text = "elapsed  %.2f s" % _elapsed_s()
	sample_count_label.text = "samples  %d" % _sample_count
	rate_label.text = _rate_text()
	magnitude_label.text = "linear accel  %.2f m/s2" % _linear_acceleration().length()

func _elapsed_s() -> float:
	if _sample_count == 0:
		return 0.0
	return float(_latest_usec - _origin_usec) / 1000000.0

# The rate is measured over the last second rather than across the whole run, because a run-wide
# average hides exactly what this readout exists to catch: a rate that sags during a vigorous
# shake and recovers before the run ends.
func _rate_text() -> String:
	if _sample_count < 2:
		return "rate  --"
	var latest_ms: float = _sample_time_ms(_sample_count - 1)
	var oldest_index: int = _sample_count - 1
	while oldest_index > 0 and latest_ms - _sample_time_ms(oldest_index - 1) <= 1000.0:
		oldest_index -= 1
	var span_ms: float = latest_ms - _sample_time_ms(oldest_index)
	if span_ms <= 0.0:
		return "rate  --"
	return "rate  %.1f Hz" % (float(_sample_count - 1 - oldest_index) * 1000.0 / span_ms)

func _sample_time_ms(index: int) -> float:
	return _samples[index * FIELDS_PER_SAMPLE]

# Displayed only, never recorded. On a working handset this sits near zero at rest and rises
# visibly when the phone moves, which distinguishes a live sensor from a dead one at a glance.
# It is not a detector: no threshold is shown and no candidate technique runs here.
func _linear_acceleration() -> Vector3:
	return Input.get_accelerometer() - Input.get_gravity()

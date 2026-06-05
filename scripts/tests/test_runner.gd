extends SceneTree
## Headless test runner. Invoke with:
##   godot --headless -s scripts/tests/test_runner.gd
##
## Each test_*.gd file under scripts/tests/ should define a static method
## `static func run(tr) -> void` that calls `tr.assert_*` helpers.

var _failures: Array[String] = []
var _passes: int = 0

func _init() -> void:
	print("=== glitch-core test runner ===")
	_run_all()
	print("---")
	print("Passes: %d   Failures: %d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAIL: %s" % f)
	if _failures.size() > 0:
		quit(1)
	else:
		quit(0)

func _run_all() -> void:
	var test_scripts: Array[String] = [
		"res://scripts/tests/test_grid.gd",
		"res://scripts/tests/test_physics_push.gd",
		"res://scripts/tests/test_physics_relay.gd",
		"res://scripts/tests/test_physics_pull.gd",
		"res://scripts/tests/test_ai_carrion.gd",
		"res://scripts/tests/test_warden_attacks.gd",
		"res://scripts/tests/test_rift_spawn.gd",
		"res://scripts/tests/test_preview.gd",
		"res://scripts/tests/test_intent_actionable.gd",
		"res://scripts/tests/test_attack_adjacency.gd",
		"res://scripts/tests/test_spawn_move_events.gd",
		"res://scripts/tests/test_battle_flow_ui.gd",
		"res://scripts/tests/test_full_battle_trace.gd",
		"res://scripts/tests/test_friendly_fire.gd",
		"res://scripts/tests/test_plague_archer.gd",
		"res://scripts/tests/test_archer_round1.gd",
		"res://scripts/tests/test_round1_archer_moves.gd",
		"res://scripts/tests/test_defense_objectives.gd",
		"res://scripts/tests/test_boss_flow.gd",
		"res://scripts/tests/test_battle_config_catalog.gd",
		"res://scripts/tests/test_run_flow.gd",
		"res://scripts/tests/test_run_state_regression.gd",
	]
	for path in test_scripts:
		if not ResourceLoader.exists(path):
			continue
		var script: Script = load(path)
		if script == null:
			_failures.append("%s failed to load" % path.get_file())
			print("  X   %s failed to load" % path.get_file())
			continue
		print("\n[%s]" % path.get_file())
		# Each test file calls back into us via the global `Tester` instance.
		script.call(&"run", self)

# ---------- assertion helpers ----------

func assert_true(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  ok  %s" % name)
	else:
		_failures.append(name)
		print("  X   %s" % name)

func assert_eq(name: String, actual, expected) -> void:
	if actual == expected:
		_passes += 1
		print("  ok  %s" % name)
	else:
		_failures.append("%s (expected %s got %s)" % [name, expected, actual])
		print("  X   %s   expected=%s   got=%s" % [name, expected, actual])

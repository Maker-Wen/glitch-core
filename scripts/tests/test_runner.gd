extends SceneTree
## Headless test runner. Invoke with:
##   godot --headless -s scripts/tests/test_runner.gd
##
## Each test_*.gd file under scripts/tests/ should define a static method
## `static func run(tr) -> void` that calls `tr.assert_*` helpers.

var _failures: Array[String] = []
var _passes: int = 0
var _filter := ""

func _init() -> void:
	print("=== glitch-core test runner ===")
	_filter = _read_filter_arg()
	if not _filter.is_empty():
		print("Filter: %s" % _filter)
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
		"res://scripts/tests/test_same_faction_movement.gd",
		"res://scripts/tests/test_physics_push.gd",
		"res://scripts/tests/test_physics_relay.gd",
		"res://scripts/tests/test_physics_pull.gd",
		"res://scripts/tests/test_ai_carrion.gd",
		"res://scripts/tests/test_warden_attacks.gd",
		"res://scripts/tests/test_rift_spawn.gd",
		"res://scripts/tests/test_action_preview.gd",
		"res://scripts/tests/test_intent_actionable.gd",
		"res://scripts/tests/test_attack_adjacency.gd",
		"res://scripts/tests/test_spawn_move_events.gd",
		"res://scripts/tests/test_battle_flow_ui.gd",
		"res://scripts/tests/test_full_battle_trace.gd",
		"res://scripts/tests/test_friendly_fire.gd",
		"res://scripts/tests/test_plague_archer.gd",
		"res://scripts/tests/test_special_enemies.gd",
		"res://scripts/tests/test_archer_round1.gd",
		"res://scripts/tests/test_round1_archer_moves.gd",
		"res://scripts/tests/test_archer_los_blockers.gd",
		"res://scripts/tests/test_battle_atlases.gd",
		"res://scripts/tests/test_diamond_board_view.gd",
		"res://scripts/tests/test_defense_objectives.gd",
		"res://scripts/tests/test_boss_flow.gd",
		"res://scripts/tests/test_battle_config_catalog.gd",
		"res://scripts/tests/test_battle_pool_candidate_generator.gd",
		"res://scripts/tests/test_run_flow.gd",
		"res://scripts/tests/test_run_state_regression.gd",
		"res://scripts/tests/test_main_menu_hub_flow.gd",
	]
	for path in test_scripts:
		if not _filter.is_empty() and not path.get_file().contains(_filter) and not path.contains(_filter):
			continue
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

func _read_filter_arg() -> String:
	for args in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for i in range(args.size()):
			if String(args[i]) == "--filter" and i + 1 < args.size():
				return String(args[i + 1])
			if String(args[i]).begins_with("--filter="):
				return String(args[i]).trim_prefix("--filter=")
	return ""

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

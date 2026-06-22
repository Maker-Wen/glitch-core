extends SceneTree
## Prints a deterministic audit of expedition battle map pool assignments.
##
## Run with:
##   godot --headless --path . -s tools/audit_run_map_pool.gd
##   godot --headless --path . -s tools/audit_run_map_pool.gd -- --seeds=1,7 --expeditions=broken_wall

const RunMapPoolAuditorScript := preload("res://scripts/data/run_map_pool_auditor.gd")

func _init() -> void:
	var seeds := _read_csv_arg("--seeds")
	var expeditions := _read_csv_arg("--expeditions")
	var report := RunMapPoolAuditorScript.audit(expeditions, seeds)
	print(RunMapPoolAuditorScript.text_report(report))
	quit(0)

func _read_csv_arg(flag: String) -> Array:
	for args in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for i in range(args.size()):
			var arg := String(args[i])
			if arg == flag and i + 1 < args.size():
				return _split_csv(String(args[i + 1]))
			if arg.begins_with("%s=" % flag):
				return _split_csv(arg.trim_prefix("%s=" % flag))
	return []

func _split_csv(value: String) -> Array:
	var result: Array = []
	for part in value.split(",", false):
		var trimmed := String(part).strip_edges()
		if trimmed.is_empty():
			continue
		result.append(trimmed)
	return result

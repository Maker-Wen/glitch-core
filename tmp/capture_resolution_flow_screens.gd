extends SceneTree

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const RunStateScript := preload("res://scripts/run/run_state.gd")

const OUTPUT_DIR := "res://tmp/resolution_flow_screens"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_victory_debrief()
	await _capture_failure_debrief()
	await _capture_boss_retry_debrief()
	await _capture_reward_page()
	quit()

func _capture_victory_debrief() -> void:
	var manager := _make_manager()
	manager._run.current_node_id = "outer_wall_01"
	manager._on_battle_finished(_battle_summary(true, 0, 2))
	await _save_viewport("debrief_victory.png")
	manager.queue_free()
	await process_frame

func _capture_reward_page() -> void:
	var manager := _make_manager()
	manager._run.current_node_id = "outer_wall_01"
	manager._on_battle_finished(_battle_summary(true, 0, 2))
	manager._continue_from_debrief()
	await _save_viewport("reward_page.png")
	manager.queue_free()
	await process_frame

func _capture_failure_debrief() -> void:
	var manager := _make_manager()
	manager._run.current_node_id = "outer_wall_01"
	manager._on_battle_finished(_battle_summary(false, 2, 0))
	await _save_viewport("debrief_failure.png")
	manager.queue_free()
	await process_frame

func _capture_boss_retry_debrief() -> void:
	var manager := _make_manager()
	manager._run.current_node_id = "boss_outer_bell_01"
	manager._on_battle_finished(_battle_summary(false, 0, 0))
	await _save_viewport("debrief_boss_retry.png")
	manager.queue_free()
	await process_frame

func _make_manager() -> Node2D:
	var manager: Node2D = GameManagerScript.new()
	manager._run = RunStateScript.new()
	manager._run.setup_new_demo()
	root.add_child(manager)
	return manager

func _save_viewport(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save screenshot %s: %s" % [path, err])
	else:
		print("saved ", ProjectSettings.globalize_path(path))

func _battle_summary(victory: bool, destroyed: int, completed: int) -> Dictionary:
	return {
		"victory": victory,
		"line_breached": not victory,
		"destroyed_protected_count": destroyed,
		"protected_damage_taken": destroyed,
		"completed_reward_count": completed,
		"reward_tasks": [],
		"reward_completed": {},
		"reward_failed": {},
		"wardens": [
			{"def_id": "warden_bountyhunter", "name": "赏金猎人", "hp": 2, "hp_max": 2, "alive": true},
			{"def_id": "warden_graverobber", "name": "盗墓人", "hp": 2, "hp_max": 2, "alive": true},
			{"def_id": "warden_mage", "name": "大魔法师", "hp": 2, "hp_max": 2, "alive": true},
		],
		"round": 5,
		"max_rounds": 5,
	}

extends Node2D
## Game entry point. Currently jumps straight to the battle vertical slice.

const BATTLE_SCENE := preload("res://Scenes/battle/BattleScene.tscn")

func _ready() -> void:
	# Slice scope: skip menus, load battle directly.
	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)

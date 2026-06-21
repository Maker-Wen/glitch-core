extends SceneTree

const OUT_DIR := "/private/tmp/glitch_core_attack_fx_style_options"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await _render_case("style_a_ranged_push", "a", "action")
	await _render_case("style_a_impact", "a", "impact")
	await _render_case("style_b_ranged_push", "b", "action")
	await _render_case("style_b_impact", "b", "impact")
	quit(0)

func _render_case(case_name: String, style: String, moment: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var board := DiamondBoardView.new()
	viewport.add_child(board)
	board.bind_state(_make_state())
	board._pulse_t = 0.42
	board.set_attack_fx_suppresses_intents(true)

	var overlay := StyleOptionOverlay.new()
	overlay.board = board
	overlay.style = style
	overlay.moment = moment
	overlay.from_cell = Vector2i(2, 5)
	overlay.to_cell = Vector2i(5, 2)
	overlay.direction = Vector2i(1, -1)
	viewport.add_child(overlay)

	await process_frame
	await process_frame
	RenderingServer.force_sync()

	var image := viewport.get_texture().get_image()
	var output_path := "%s/%s.png" % [OUT_DIR, case_name]
	var result := image.save_png(output_path)
	if result != OK:
		push_error("Failed to save preview: %s" % output_path)
	viewport.queue_free()
	await process_frame

func _make_state() -> BattleState:
	var state := BattleState.new()
	state.grid = Grid.new()
	state.phase = BattleState.Phase.PLAYER_ACTION
	state.units.append(Unit.new(1, _make_def(&"bh", UnitDef.Faction.WARDEN, UnitDef.AttackKind.RANGED_PUSH), Vector2i(2, 5)))
	state.units.append(Unit.new(2, _make_def(&"carrion", UnitDef.Faction.ENEMY, UnitDef.AttackKind.MELEE_BUMP), Vector2i(5, 2)))
	state.units.append(Unit.new(3, _make_def(&"archer", UnitDef.Faction.ENEMY, UnitDef.AttackKind.RANGED_PUSH), Vector2i(3, 4)))
	return state

func _make_def(def_id: StringName, faction: int, attack_kind: int) -> UnitDef:
	var def := UnitDef.new()
	def.def_id = def_id
	def.display_name = String(def_id)
	def.faction = faction
	def.max_hp = 2
	def.attack_kind = attack_kind
	def.attack_range = 3
	def.attack_damage = 1
	def.attack_force = 1
	return def

class StyleOptionOverlay extends Node2D:
	var board: DiamondBoardView = null
	var style := "a"
	var moment := "action"
	var from_cell := Vector2i.ZERO
	var to_cell := Vector2i.ZERO
	var direction := Vector2i.ZERO

	const IRON := Color(0.035, 0.028, 0.024, 0.88)
	const IRON_SOFT := Color(0.055, 0.044, 0.038, 0.62)
	const AMBER := Color(0.86, 0.48, 0.16, 0.86)
	const AMBER_DIM := Color(0.52, 0.24, 0.08, 0.58)
	const BONE := Color(0.88, 0.78, 0.58, 0.74)
	const RED := Color(1.0, 0.22, 0.14, 0.82)
	const DUST := Color(0.34, 0.28, 0.21, 0.40)

	func _draw() -> void:
		if board == null:
			return
		if style == "a" and moment == "action":
			_draw_style_a_action()
		elif style == "a" and moment == "impact":
			_draw_style_a_impact()
		elif style == "b" and moment == "action":
			_draw_style_b_action()
		else:
			_draw_style_b_impact()

	func _draw_style_a_action() -> void:
		var from_px := board.cell_to_pixel(from_cell, DiamondBoardView.ATTACK_FX_MUZZLE_HEIGHT)
		var to_px := board.cell_to_pixel(to_cell, DiamondBoardView.ATTACK_FX_TARGET_HEIGHT)
		var dir := (to_px - from_px).normalized()
		var normal := dir.rotated(PI * 0.5)
		var start := from_px + dir * 21.0
		var head := start.lerp(to_px - dir * 18.0, 0.58)
		head.y -= 9.0
		var tail := head - dir * 38.0
		_draw_muzzle_tick(start, dir, 0.90)
		_draw_tactical_bolt(tail, head, normal)
		_draw_target_reticle(to_px, 0.38)

	func _draw_style_a_impact() -> void:
		var hit := board.cell_to_pixel(to_cell, DiamondBoardView.ATTACK_FX_TARGET_HEIGHT)
		_draw_target_reticle(hit, 0.62)
		for i in range(6):
			var angle := -0.82 * PI + float(i) * PI / 5.0
			var dir := Vector2(cos(angle), sin(angle))
			var inner := hit + dir * 7.0
			var outer := hit + dir * (21.0 + float(i % 2) * 7.0)
			draw_line(inner, outer, IRON, 5.0)
			draw_line(inner, outer, BONE if i % 2 == 0 else AMBER, 2.0)
		draw_circle(hit, 5.0, AMBER)
		draw_line(hit + Vector2(-20, 12), hit + Vector2(26, -8), Color(0, 0, 0, 0.34), 3.0)

	func _draw_style_b_action() -> void:
		var from_px := board.cell_to_pixel(from_cell, DiamondBoardView.ATTACK_FX_MUZZLE_HEIGHT)
		var to_px := board.cell_to_pixel(to_cell, DiamondBoardView.ATTACK_FX_TARGET_HEIGHT)
		var dir := (to_px - from_px).normalized()
		var normal := dir.rotated(PI * 0.5)
		var start := from_px + dir * 18.0
		var end_pt := to_px - dir * 18.0
		_draw_actor_flash(start, dir)
		for i in range(3):
			var offset := normal * (float(i) - 1.0) * 6.0 - dir * float(i) * 12.0
			var a := start.lerp(end_pt, 0.20 + float(i) * 0.14) + offset
			var b := start.lerp(end_pt, 0.50 + float(i) * 0.10) + offset
			draw_line(a, b, Color(0.02, 0.016, 0.012, 0.62), 4.0)
			draw_line(a + normal * 1.0, b + normal * 1.0, Color(0.74, 0.46, 0.22, 0.44), 1.5)
		var near_hit := start.lerp(end_pt, 0.70)
		draw_line(near_hit - normal * 12.0, near_hit + normal * 16.0, IRON_SOFT, 3.0)

	func _draw_style_b_impact() -> void:
		var hit := board.cell_to_pixel(to_cell, DiamondBoardView.ATTACK_FX_TARGET_HEIGHT)
		var from_px := board.cell_to_pixel(from_cell, DiamondBoardView.ATTACK_FX_MUZZLE_HEIGHT)
		var dir := (hit - from_px).normalized()
		var normal := dir.rotated(PI * 0.5)
		_draw_actor_flash(from_px + dir * 18.0, dir, 0.38)
		draw_line(hit - normal * 22.0 - dir * 4.0, hit + normal * 24.0 + dir * 4.0, IRON, 7.0)
		draw_line(hit - normal * 18.0, hit + normal * 20.0, AMBER, 2.8)
		draw_line(hit - dir * 20.0, hit + dir * 16.0, IRON_SOFT, 4.0)
		draw_line(hit - dir * 12.0, hit + dir * 10.0, BONE, 1.8)
		_draw_dust_puff(hit + Vector2(0, 6), 0.46)

	func _draw_tactical_bolt(tail: Vector2, head: Vector2, normal: Vector2) -> void:
		var dir := (head - tail).normalized()
		draw_line(tail, head, IRON, 5.0)
		draw_line(tail + normal * 1.3, head + normal * 1.3, AMBER, 1.8)
		var p1 := head - dir * 10.0 - normal * 5.0
		var p2 := head + dir * 10.0
		var p3 := head - dir * 9.0 + normal * 5.0
		draw_colored_polygon(PackedVector2Array([p1, p2, p3]), IRON)
		draw_colored_polygon(PackedVector2Array([p1.lerp(p2, 0.35), p2, p3.lerp(p2, 0.35)]), AMBER)

	func _draw_muzzle_tick(center: Vector2, dir: Vector2, alpha: float) -> void:
		var normal := dir.rotated(PI * 0.5)
		draw_line(center - dir * 8.0, center + dir * 16.0, IRON, 5.0)
		draw_line(center - dir * 3.0, center + dir * 12.0, Color(AMBER.r, AMBER.g, AMBER.b, AMBER.a * alpha), 2.0)
		draw_line(center - normal * 9.0, center + normal * 9.0, Color(BONE.r, BONE.g, BONE.b, 0.42 * alpha), 1.6)

	func _draw_actor_flash(center: Vector2, dir: Vector2, alpha: float = 0.72) -> void:
		var normal := dir.rotated(PI * 0.5)
		draw_line(center - normal * 13.0 - dir * 3.0, center + normal * 13.0 + dir * 3.0, IRON, 5.0)
		draw_line(center - normal * 9.0, center + normal * 9.0, Color(BONE.r, BONE.g, BONE.b, alpha), 2.0)
		draw_line(center - dir * 9.0, center + dir * 18.0, Color(AMBER.r, AMBER.g, AMBER.b, alpha * 0.80), 2.0)

	func _draw_target_reticle(center: Vector2, alpha: float) -> void:
		var w := 28.0
		var h := 12.0
		var color := Color(RED.r, RED.g, RED.b, alpha)
		draw_line(center + Vector2(-w, 0), center + Vector2(-12, 0), IRON, 4.0)
		draw_line(center + Vector2(12, 0), center + Vector2(w, 0), IRON, 4.0)
		draw_line(center + Vector2(0, -h), center + Vector2(0, -5), IRON, 4.0)
		draw_line(center + Vector2(0, 5), center + Vector2(0, h), IRON, 4.0)
		draw_line(center + Vector2(-w, 0), center + Vector2(-12, 0), color, 1.8)
		draw_line(center + Vector2(12, 0), center + Vector2(w, 0), color, 1.8)
		draw_line(center + Vector2(0, -h), center + Vector2(0, -5), color, 1.8)
		draw_line(center + Vector2(0, 5), center + Vector2(0, h), color, 1.8)

	func _draw_dust_puff(center: Vector2, alpha: float) -> void:
		draw_circle(center + Vector2(-12, 2), 9.0, Color(DUST.r, DUST.g, DUST.b, alpha * 0.30))
		draw_circle(center + Vector2(0, -2), 12.0, Color(DUST.r, DUST.g, DUST.b, alpha * 0.26))
		draw_circle(center + Vector2(12, 3), 8.0, Color(DUST.r, DUST.g, DUST.b, alpha * 0.22))
		draw_line(center + Vector2(-20, 9), center + Vector2(22, 5), Color(0.05, 0.04, 0.03, alpha * 0.42), 2.0)

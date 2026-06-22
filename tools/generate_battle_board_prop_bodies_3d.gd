extends SceneTree
## Renders rough body-only battle board prop blockouts from simple 3D models.
##
## This is a prototype scale/contact helper only. Production board prop art is
## generated or painted as polished dimetric body-only sprites, then placed
## through BattleBoardPropProfile. Do not write these low-poly blockouts over
## the production `art/tiles/board_*_body_v2.png` sources.
##
## Run with:
##   godot --path . --script tools/generate_battle_board_prop_bodies_3d.gd

const OUT_DIR := "res://tmp/generated_board_prop_blockouts"
const CANVAS := Vector2i(1024, 1024)

const MAT_TOP := Color(0.49, 0.52, 0.46, 1.0)
const MAT_MID := Color(0.35, 0.40, 0.37, 1.0)
const MAT_DARK := Color(0.23, 0.28, 0.28, 1.0)
const MAT_DEEP := Color(0.08, 0.11, 0.12, 1.0)
const MAT_MOSS := Color(0.25, 0.34, 0.23, 1.0)
const MAT_CORE := Color(0.08, 0.68, 0.72, 1.0)
const MAT_WARM_CORE := Color(1.0, 0.48, 0.14, 1.0)
const BUILDING_TOP := Color(0.54, 0.55, 0.50, 1.0)
const BUILDING_MID := Color(0.36, 0.39, 0.38, 1.0)
const BUILDING_DARK := Color(0.20, 0.24, 0.25, 1.0)
const BUILDING_CAP := Color(0.30, 0.29, 0.26, 1.0)

var _viewport: SubViewport
var _root_3d: Node3D
var _materials := {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_setup_viewport()
	await _render_prop("building", Callable(self, "_build_building"), "%s/board_building_body_blockout.png" % OUT_DIR)
	await _render_prop("pillar", Callable(self, "_build_pillar"), "%s/board_pillar_body_blockout.png" % OUT_DIR)
	await _render_prop("ruin", Callable(self, "_build_ruin"), "%s/board_ruin_body_blockout.png" % OUT_DIR)
	quit(0)

func _setup_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = CANVAS
	_viewport.transparent_bg = true
	_viewport.disable_3d = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	get_root().add_child(_viewport)

	var world := World3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.54, 0.49, 1.0)
	env.ambient_light_energy = 0.54
	world.environment = env
	_viewport.world_3d = world

	_root_3d = Node3D.new()
	_viewport.add_child(_root_3d)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.55
	camera.position = Vector3(4.8, 3.15, 4.8)
	_root_3d.add_child(camera)
	camera.look_at(Vector3(0, 0.82, 0), Vector3.UP)
	camera.current = true

	var key := DirectionalLight3D.new()
	key.light_color = Color(0.86, 0.94, 0.76, 1.0)
	key.light_energy = 2.35
	key.shadow_enabled = false
	key.position = Vector3(-3.0, 5.5, 2.4)
	_root_3d.add_child(key)
	key.look_at(Vector3.ZERO, Vector3.UP)

	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.35, 0.55, 0.58, 1.0)
	rim.light_energy = 0.55
	rim.shadow_enabled = false
	rim.position = Vector3(4.0, 2.5, -3.5)
	_root_3d.add_child(rim)
	rim.look_at(Vector3.ZERO, Vector3.UP)

func _render_prop(prop_name: String, builder: Callable, out_path: String) -> void:
	for child in _root_3d.get_children():
		if child is Camera3D or child is Light3D:
			continue
		child.queue_free()
	await process_frame
	builder.call()
	for i in range(10):
		await process_frame
	var image := _viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	_crop_render_alpha(image)
	_post_process_sprite(image)
	var absolute := ProjectSettings.globalize_path(out_path)
	var result := image.save_png(absolute)
	print("%s body render: %s result=%s" % [prop_name, absolute, str(result)])

func _crop_render_alpha(image: Image) -> void:
	var bbox := _alpha_bbox(image)
	if bbox.size.x <= 0 or bbox.size.y <= 0:
		return
	var margin := 96
	var crop := Rect2i(
		Vector2i(maxi(0, bbox.position.x - margin), maxi(0, bbox.position.y - margin)),
		Vector2i(
			mini(image.get_width(), bbox.position.x + bbox.size.x + margin) - maxi(0, bbox.position.x - margin),
			mini(image.get_height(), bbox.position.y + bbox.size.y + margin) - maxi(0, bbox.position.y - margin)
		)
	)
	var cropped := Image.create(crop.size.x, crop.size.y, false, Image.FORMAT_RGBA8)
	cropped.fill(Color(0, 0, 0, 0))
	cropped.blit_rect(image, crop, Vector2i.ZERO)
	image.fill(Color(0, 0, 0, 0))
	var dest := Vector2i((image.get_width() - cropped.get_width()) / 2, (image.get_height() - cropped.get_height()) / 2)
	image.blit_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), dest)

func _alpha_bbox(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _post_process_sprite(image: Image) -> void:
	var copy := image.duplicate()
	for y in range(1, image.get_height() - 1):
		for x in range(1, image.get_width() - 1):
			var color: Color = copy.get_pixel(x, y)
			if color.a > 0.02:
				var grain := _pixel_grain(x, y)
				color.r = clampf(color.r + grain, 0.0, 1.0)
				color.g = clampf(color.g + grain, 0.0, 1.0)
				color.b = clampf(color.b + grain, 0.0, 1.0)
				image.set_pixel(x, y, color)
				continue
			var neighbor_alpha := 0.0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					neighbor_alpha = maxf(neighbor_alpha, copy.get_pixel(x + ox, y + oy).a)
			if neighbor_alpha > 0.25:
				image.set_pixel(x, y, Color(0.025, 0.035, 0.034, minf(0.42, neighbor_alpha * 0.52)))

func _pixel_grain(x: int, y: int) -> float:
	var n := (x * 928371 + y * 689287 + (x ^ y) * 97) & 0xffff
	return (float(n % 1000) / 1000.0 - 0.5) * 0.045

func _build_building() -> void:
	_add_block(Vector3(0, 0.00, 0), Vector3(0.98, 0.92, 0.70), BUILDING_MID)
	_add_block(Vector3(-0.49, 0.02, 0.08), Vector3(0.18, 0.78, 0.38), BUILDING_DARK)
	_add_block(Vector3(0.49, 0.02, 0.08), Vector3(0.18, 0.78, 0.38), BUILDING_DARK)
	_add_block(Vector3(0, 0.88, 0), Vector3(0.74, 0.28, 0.52), BUILDING_TOP)
	_add_block(Vector3(0, 1.10, 0), Vector3(0.56, 0.24, 0.40), BUILDING_CAP)
	_add_pyramid(Vector3(0, 1.34, 0), Vector3(0.78, 0.40, 0.54), 0.34, BUILDING_TOP)
	for i in range(5):
		var offset := float(i - 2) * 0.22
		_add_block(Vector3(offset, 1.33 + 0.035 * float(i % 2), 0.35), Vector3(0.09, 0.18, 0.09), BUILDING_TOP)
	for i in range(5):
		_add_block(Vector3(-0.39 + float(i) * 0.20, 0.36, 0.38), Vector3(0.12, 0.065, 0.028), _building_stone_variant(i + 40))
		_add_block(Vector3(-0.38 + float(i) * 0.19, 0.62, 0.39), Vector3(0.11, 0.055, 0.028), _building_stone_variant(i + 70))
	_add_block(Vector3(0, 0.50, 0.38), Vector3(0.38, 0.46, 0.038), MAT_DEEP)
	_add_block(Vector3(0, 0.50, 0.42), Vector3(0.18, 0.26, 0.032), MAT_CORE, true)
	_add_block(Vector3(0, 0.83, 0.42), Vector3(0.52, 0.035, 0.032), BUILDING_CAP)
	_add_block(Vector3(-0.26, 0.77, 0.42), Vector3(0.08, 0.16, 0.030), BUILDING_CAP)
	_add_block(Vector3(0.26, 0.77, 0.42), Vector3(0.08, 0.16, 0.030), BUILDING_CAP)
	_add_crack(Vector3(-0.26, 0.74, 0.415), 0.30, 4)
	_add_crack(Vector3(0.31, 0.42, 0.415), 0.22, 5)
	_add_rubble(11, 0.60)
	_add_moss_strips()

func _build_pillar() -> void:
	_add_cylinder(Vector3(0, 0.00, 0), 0.42, 0.24, MAT_DARK, 12)
	_add_cylinder(Vector3(0, 0.24, 0), 0.32, 0.42, MAT_MID, 12)
	_add_cylinder(Vector3(0, 0.66, 0), 0.26, 0.50, MAT_TOP, 12)
	_add_cylinder(Vector3(0.08, 1.12, -0.04), 0.20, 0.30, MAT_MID, 10)
	_add_block(Vector3(-0.36, 0.20, 0.16), Vector3(0.28, 0.22, 0.21), MAT_MID)
	_add_block(Vector3(0.34, 0.16, 0.10), Vector3(0.30, 0.20, 0.22), MAT_DARK)
	_add_crack(Vector3(0.15, 0.92, 0.20), 0.28, 6)
	_add_rubble(10, 0.56)
	_add_moss_strips()

func _build_ruin() -> void:
	_add_block(Vector3(-0.54, 0.00, 0.02), Vector3(0.24, 0.82, 0.25), MAT_MID)
	_add_block(Vector3(-0.24, 0.00, 0.02), Vector3(0.25, 0.72, 0.25), MAT_MID)
	_add_block(Vector3(0.06, 0.00, 0.02), Vector3(0.27, 0.60, 0.25), MAT_MID)
	_add_block(Vector3(0.36, 0.00, 0.02), Vector3(0.25, 0.42, 0.25), MAT_MID)
	_add_block(Vector3(-0.40, 0.82, 0.02), Vector3(0.22, 0.24, 0.22), MAT_TOP)
	_add_block(Vector3(-0.08, 0.72, 0.02), Vector3(0.22, 0.20, 0.22), MAT_TOP)
	_add_block(Vector3(-0.28, 0.35, 0.31), Vector3(0.54, 0.38, 0.035), MAT_DEEP)
	for i in range(3):
		_add_block(Vector3(-0.46 + float(i) * 0.26, 0.52, 0.32), Vector3(0.13, 0.06, 0.028), _stone_variant(i + 110))
	_add_crack(Vector3(-0.52, 0.64, 0.24), 0.32, 9)
	_add_crack(Vector3(0.18, 0.48, 0.24), 0.24, 12)
	_add_rubble(14, 0.68)
	_add_moss_strips()

func _add_rubble(count: int, radius: float) -> void:
	for i in range(count):
		var angle := float(i) * 2.399
		var r := radius * (0.34 + 0.56 * _noise01(i, 17))
		var x := cos(angle) * r
		var z := sin(angle) * r * 0.68 + 0.10
		var sx := 0.10 + 0.09 * _noise01(i, 31)
		var sy := 0.06 + 0.12 * _noise01(i, 43)
		var sz := 0.09 + 0.08 * _noise01(i, 59)
		_add_block(Vector3(x, sy * 0.5, z), Vector3(sx, sy, sz), _stone_variant(i))

func _add_moss_strips() -> void:
	for i in range(6):
		var x := -0.46 + 0.92 * _noise01(i, 101)
		var z := -0.26 + 0.52 * _noise01(i, 113)
		var y := 0.12 + 0.30 * _noise01(i, 127)
		_add_block(Vector3(x, y, z), Vector3(0.09, 0.030, 0.11), MAT_MOSS)

func _add_crack(center: Vector3, height: float, salt: int) -> void:
	var segments := 4
	var previous := center
	for i in range(segments):
		var next := center + Vector3(
			(-0.06 + 0.12 * _noise01(i, salt + 3)) * float(i + 1),
			-height * float(i + 1) / float(segments),
			0.010
		)
		var mid := (previous + next) * 0.5
		var length := previous.distance_to(next)
		var crack := _add_block(mid, Vector3(0.030, length, 0.018), Color(0.02, 0.035, 0.035, 1.0))
		crack.rotation_degrees.z = -12.0 + 24.0 * _noise01(i, salt + 7)
		previous = next

func _add_block(center: Vector3, size: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(center.x, center.y + size.y * 0.5, center.z)
	node.rotation_degrees.y = 0.0
	node.material_override = _material(color, emissive)
	_root_3d.add_child(node)
	return node

func _add_cylinder(center: Vector3, radius: float, height: float, color: Color, sides: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.92
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(center.x, center.y + height * 0.5, center.z)
	node.rotation_degrees.y = 22.5
	node.material_override = _material(color)
	_root_3d.add_child(node)
	return node

func _add_pyramid(center: Vector3, base_size: Vector3, height: float, color: Color) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var half := Vector3(base_size.x * 0.5, 0.0, base_size.z * 0.5)
	var y := center.y
	var p0 := Vector3(center.x - half.x, y, center.z - half.z)
	var p1 := Vector3(center.x + half.x, y, center.z - half.z)
	var p2 := Vector3(center.x + half.x, y, center.z + half.z)
	var p3 := Vector3(center.x - half.x, y, center.z + half.z)
	var apex := Vector3(center.x, y + height, center.z)
	for tri in [[p0, p1, apex], [p1, p2, apex], [p2, p3, apex], [p3, p0, apex], [p0, p3, p2], [p0, p2, p1]]:
		for point in tri:
			vertices.append(point)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color)
	_root_3d.add_child(node)
	return node

func _stone_variant(i: int) -> Color:
	var t := 0.78 + 0.18 * _noise01(i, 211)
	return MAT_MID.lerp(MAT_TOP, t * 0.45).darkened(0.08 * _noise01(i, 223))

func _building_stone_variant(i: int) -> Color:
	var t := 0.64 + 0.24 * _noise01(i, 311)
	return BUILDING_MID.lerp(BUILDING_TOP, t * 0.38).darkened(0.06 * _noise01(i, 337))

func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var key := "%s_%s" % [str(color), str(emissive)]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	mat.metallic = 0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.6
	_materials[key] = mat
	return mat

func _noise01(a: int, b: int) -> float:
	var n := (a * 1103515245 + b * 12345) & 0x7fffffff
	return float(n % 1000) / 1000.0

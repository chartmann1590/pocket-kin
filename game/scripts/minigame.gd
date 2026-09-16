extends Control

signal finished(score: int)
signal cancelled

const Art = preload("res://scripts/art.gd")

var kind := "catch"
var score := 0
var remaining := 35.0
var elapsed := 0.0
var started := false
var ended := false
var combo := 0
var fever := 0.0
var is_fever := false
var fever_timer := 0.0

# Common UI nodes
var hud_score: Label
var hud_timer: Label
var hud_combo: Label
var fever_bar: ProgressBar
var instructions: Label
var start_button: Button
var back_button: Button
var sfx_players: Dictionary = {}

# 3D Viewport container for 3D games
var vp_container: SubViewportContainer
var vp: SubViewport
var camera: Camera3D

# --- GAME 1: Orchard Drop 3D (Pachinko / Pinball Fruit Drop) ---
var catcher_mesh: MeshInstance3D
var catcher_x := 0.0
var dropper_x := 0.0
var drop_cooldown := 0.0
var balls_3d: Array = [] # {mesh: MeshInstance3D, pos: Vector3, vel: Vector3, radius: float, is_fever: bool, is_clock: bool}
var pegs_3d: Array = []  # {mesh: MeshInstance3D, pos: Vector3, radius: float, mat: StandardMaterial3D, hit_anim: float}
var bumpers_3d: Array = [] # {mesh: MeshInstance3D, pos: Vector3, radius: float, mat: StandardMaterial3D, hit_anim: float}
var slots_3d: Array = [] # {x: float, width: float, pts: int, label: String}
var pet_cheer_sprite: TextureRect

# --- GAME 2: Kin Cloud Hop 3D (Vertical Platformer) ---
var hop_pet: MeshInstance3D
var hop_pet_sprite: Sprite3D
var hop_pos := Vector3(0, 1.5, 0)
var hop_vel := Vector3.ZERO
var hop_cam_y := 4.0
var hop_platforms: Array = [] # {mesh: Node3D, pos: Vector3, size: Vector3, type: String, broken: bool, dir: float}
var hop_stars: Array = []     # {mesh: MeshInstance3D, pos: Vector3, collected: bool}
var hop_touch_active := false
var hop_target_x := 0.0
var hop_highest_y := 0.0
var hop_fall_rescue := false
var hop_sky_mesh: MeshInstance3D
var hop_bg_clouds: Array = []
var hop_last_milestone := 0

# --- GAME 3: Treasure Match 3D (Tactile 3D Tilt Card Flip) ---
var cards: Array = [] # {btn: Button, face_tex: Texture2D, id: int, revealed: bool, matched: bool, flip_t: float, flipping: bool, target_rev: bool}
var match_revealed: Array = []
var match_pairs_left := 6
var match_lockout := 0.0
var match_grid: GridContainer
var match_level := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_init_sounds()
	var bg := ColorRect.new()
	bg.color = Color("f7f3ea")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if kind == "catch":
		_init_orchard_drop_3d()
	elif kind == "hop" or kind == "rhythm":
		kind = "hop"
		_init_cloud_hop_3d()
	elif kind == "match":
		_init_treasure_match()
	_build_ui()

func _init_sounds() -> void:
	for sound_name in ["bounce", "coin", "fever", "spring", "tap", "reward", "bubble"]:
		var path := "res://assets/%s.wav" % sound_name
		if ResourceLoader.exists(path):
			var p := AudioStreamPlayer.new()
			p.stream = load(path)
			add_child(p)
			sfx_players[sound_name] = p

func play_sfx(name: String, pitch := 1.0) -> void:
	if not World.data.settings.effects: return
	if sfx_players.has(name):
		var p: AudioStreamPlayer = sfx_players[name]
		p.pitch_scale = pitch
		p.play()

func _box_style(col: Color, rad := 16, border := Color.TRANSPARENT, border_w := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(rad)
	if border.a > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb

func spawn_sparkles(pos: Vector2, count := 6) -> void:
	for i in range(count):
		var star := Label.new()
		star.text = ["✨", "⭐", "🌸", "💎", "💫"][randi() % 5]
		star.position = pos + Vector2(randf_range(-35, 35), randf_range(-30, 30))
		star.add_theme_font_size_override("font_size", randi_range(22, 32))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)
		var tw := create_tween()
		var target := star.position + Vector2(randf_range(-50, 50), randf_range(-70, -130))
		tw.tween_property(star, "position", target, 0.75)
		tw.parallel().tween_property(star, "modulate:a", 0.0, 0.75)
		tw.tween_callback(star.queue_free)

func _build_ui() -> void:
	# Top Header Bar
	var top_bar := PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", _box_style(Color("faf7f0"), 20, Color("e5decb"), 2))
	top_bar.position = Vector2(24, 20)
	top_bar.size = Vector2(672, 90)
	add_child(top_bar)

	var bar_layout := HBoxContainer.new()
	bar_layout.add_theme_constant_override("separation", 16)
	top_bar.add_child(bar_layout)

	var title_lbl := Label.new()
	title_lbl.text = {"catch": "🌟 Orchard Drop 3D", "hop": "☁️ Kin Cloud Hop 3D", "match": "💎 Treasure Match 3D"}.get(kind, "Play")
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color("3d362d"))
	if ResourceLoader.exists("res://assets/Lora.ttf"):
		title_lbl.add_theme_font_override("font", load("res://assets/Lora.ttf"))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_layout.add_child(title_lbl)

	hud_score = Label.new()
	hud_score.text = "✦ 0"
	hud_score.add_theme_font_size_override("font_size", 28)
	hud_score.add_theme_color_override("font_color", Color("73856b"))
	bar_layout.add_child(hud_score)

	hud_timer = Label.new()
	hud_timer.text = "⏱ 35s"
	hud_timer.add_theme_font_size_override("font_size", 24)
	hud_timer.add_theme_color_override("font_color", Color("a36746"))
	bar_layout.add_child(hud_timer)

	# Combo banner
	hud_combo = Label.new()
	hud_combo.position = Vector2(24, 116)
	hud_combo.size = Vector2(672, 36)
	hud_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_combo.add_theme_font_size_override("font_size", 22)
	hud_combo.add_theme_color_override("font_color", Color("e06030"))
	hud_combo.text = ""
	add_child(hud_combo)

	# Instructions card
	instructions = Label.new()
	instructions.text = {
		"catch": "Slide to aim & tap to drop fruits! Catch them in the basket!",
		"hop": "Tap Left / Right to leap across floating 3D clouds & springs!",
		"match": "Tap cards to flip in 3D & find the matching pairs!"
	}.get(kind, "")
	instructions.position = Vector2(40, 150)
	instructions.size = Vector2(640, 50)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.add_theme_font_size_override("font_size", 21)
	instructions.add_theme_color_override("font_color", Color("766957"))
	add_child(instructions)

	# Ready / Start Overlay Button
	start_button = Button.new()
	start_button.text = "Ready? Tap to Play! 🚀"
	start_button.position = Vector2(160, 600)
	start_button.size = Vector2(400, 95)
	start_button.add_theme_stylebox_override("normal", _box_style(Color("73856b"), 28))
	start_button.add_theme_stylebox_override("hover", _box_style(Color("5f7057"), 28))
	start_button.add_theme_stylebox_override("pressed", _box_style(Color("4e5e47"), 28))
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.add_theme_font_size_override("font_size", 30)
	start_button.pressed.connect(func():
		started = true
		start_button.hide()
		instructions.text = "Go! Go! Go!"
		play_sfx("tap")
	)
	add_child(start_button)

	if kind == "hop":
		var left_btn := Button.new()
		left_btn.text = "◀ Hop Left"
		left_btn.position = Vector2(40, 1060)
		left_btn.size = Vector2(300, 95)
		left_btn.add_theme_stylebox_override("normal", _box_style(Color(1, 1, 1, 0.78), 24, Color("b0c4de"), 3))
		left_btn.add_theme_stylebox_override("pressed", _box_style(Color("dceefb"), 24, Color("4a90e2"), 3))
		left_btn.add_theme_font_size_override("font_size", 26)
		left_btn.add_theme_color_override("font_color", Color("2c3e50"))
		left_btn.pressed.connect(func():
			if not started or ended: return
			hop_target_x = clampf(hop_pos.x - 1.5, -2.8, 2.8)
			play_sfx("tap", 1.1)
		)
		add_child(left_btn)

		var right_btn := Button.new()
		right_btn.text = "Hop Right ▶"
		right_btn.position = Vector2(380, 1060)
		right_btn.size = Vector2(300, 95)
		right_btn.add_theme_stylebox_override("normal", _box_style(Color(1, 1, 1, 0.78), 24, Color("b0c4de"), 3))
		right_btn.add_theme_stylebox_override("pressed", _box_style(Color("dceefb"), 24, Color("4a90e2"), 3))
		right_btn.add_theme_font_size_override("font_size", 26)
		right_btn.add_theme_color_override("font_color", Color("2c3e50"))
		right_btn.pressed.connect(func():
			if not started or ended: return
			hop_target_x = clampf(hop_pos.x + 1.5, -2.8, 2.8)
			play_sfx("tap", 1.1)
		)
		add_child(right_btn)

	# Bottom Back Button
	back_button = Button.new()
	back_button.text = "← Back"
	back_button.position = Vector2(28, 1180)
	back_button.size = Vector2(140, 68)
	back_button.add_theme_stylebox_override("normal", _box_style(Color("eee7da"), 20, Color("dcd3c3"), 2))
	back_button.add_theme_color_override("font_color", Color("443e35"))
	back_button.add_theme_font_size_override("font_size", 22)
	back_button.pressed.connect(func(): cancelled.emit())
	add_child(back_button)

# -------------------------------------------------------------
# GAME 1: ORCHARD DROP 3D (PACHINKO PINBALL ARCADE)
# -------------------------------------------------------------
func _init_orchard_drop_3d() -> void:
	vp_container = SubViewportContainer.new()
	vp_container.position = Vector2(20, 200)
	vp_container.size = Vector2(680, 960)
	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vp_container)

	vp = SubViewport.new()
	vp.size = Vector2i(680, 960)
	vp.own_world_3d = true
	vp.world_3d = World3D.new()
	vp_container.add_child(vp)

	# 3D Camera
	camera = Camera3D.new()
	camera.position = Vector3(0, -0.2, 8.6)
	camera.current = true
	vp.add_child(camera)

	# Lighting
	var dir_light := DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-45, 25, 0)
	dir_light.light_energy = 0.95
	vp.add_child(dir_light)

	var omni_light := OmniLight3D.new()
	omni_light.position = Vector3(0, 2, 4)
	omni_light.light_energy = 1.2
	omni_light.omni_range = 15.0
	vp.add_child(omni_light)

	# Board backplate (Pastel wooden arcade look)
	var back_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8.0, 11.2, 0.4)
	back_mesh.mesh = box
	back_mesh.position = Vector3(0, 0, -0.3)
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color("f3ece1")
	back_mat.roughness = 0.7
	back_mesh.material_override = back_mat
	vp.add_child(back_mesh)

	# Side Wall Borders (rounded glossy rails)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.35, 11.2, 0.8)
		rail.mesh = rail_mesh
		rail.position = Vector3(side * 3.8, 0, 0)
		var rail_mat := StandardMaterial3D.new()
		rail_mat.albedo_color = Color("c7b89d")
		rail_mat.metallic = 0.2
		rail.material_override = rail_mat
		vp.add_child(rail)

	# 3D Pachinko Pegs Grid
	var peg_mesh_res := CylinderMesh.new()
	peg_mesh_res.top_radius = 0.11
	peg_mesh_res.bottom_radius = 0.11
	peg_mesh_res.height = 0.6

	var rows := 8
	for r in range(rows):
		var y := 3.6 - r * 0.95
		var cols := 6 if r % 2 == 0 else 5
		var start_x := -2.7 if r % 2 == 0 else -2.15
		for c in range(cols):
			var px := start_x + c * 1.08
			var peg := MeshInstance3D.new()
			peg.mesh = peg_mesh_res
			peg.rotation_degrees = Vector3(90, 0, 0)
			peg.position = Vector3(px, y, 0)

			var peg_mat := StandardMaterial3D.new()
			peg_mat.albedo_color = Color("ffd166") if (r + c) % 3 == 0 else Color("80b9ad")
			peg_mat.metallic = 0.7
			peg_mat.roughness = 0.2
			peg.material_override = peg_mat
			vp.add_child(peg)

			pegs_3d.append({
				"mesh": peg,
				"pos": Vector3(px, y, 0),
				"radius": 0.16,
				"mat": peg_mat,
				"hit_anim": 0.0
			})

	# 3D Rotating Bumpers
	var bumper_mesh_res := CylinderMesh.new()
	bumper_mesh_res.top_radius = 0.38
	bumper_mesh_res.bottom_radius = 0.38
	bumper_mesh_res.height = 0.5
	for bx in [-1.5, 1.5]:
		var b_inst := MeshInstance3D.new()
		b_inst.mesh = bumper_mesh_res
		b_inst.rotation_degrees = Vector3(90, 0, 0)
		b_inst.position = Vector3(bx, 0.0, 0)
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color("ef476f")
		b_mat.emission_enabled = true
		b_mat.emission = Color("ef476f") * 0.4
		b_mat.roughness = 0.2
		b_inst.material_override = b_mat
		vp.add_child(b_inst)
		bumpers_3d.append({
			"mesh": b_inst,
			"pos": Vector3(bx, 0.0, 0),
			"radius": 0.42,
			"mat": b_mat,
			"hit_anim": 0.0
		})

	# 3D Catcher Basket (Player controls horizontally)
	catcher_mesh = MeshInstance3D.new()
	var basket_box := BoxMesh.new()
	basket_box.size = Vector3(1.6, 0.5, 0.7)
	catcher_mesh.mesh = basket_box
	catcher_mesh.position = Vector3(0, -4.5, 0)
	var basket_mat := StandardMaterial3D.new()
	basket_mat.albedo_color = Color("43aa8b")
	basket_mat.metallic = 0.3
	basket_mat.roughness = 0.3
	catcher_mesh.material_override = basket_mat
	vp.add_child(catcher_mesh)

	# Cheering Pet Sprite overlay at bottom-right
	pet_cheer_sprite = Art.image(Art.pet(World.data.pet.get("species", 0), 4), Vector2(130, 130))
	pet_cheer_sprite.position = Vector2(530, 1020)
	pet_cheer_sprite.pivot_offset = Vector2(65, 65)
	add_child(pet_cheer_sprite)

func _drop_fruit(is_fever_drop := false) -> void:
	if not started or ended: return
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	var inst := MeshInstance3D.new()
	inst.mesh = sphere

	var mat := StandardMaterial3D.new()
	if is_fever_drop:
		mat.albedo_color = Color("ffd700") # Golden star fruit
		mat.emission_enabled = true
		mat.emission = Color("ffd700") * 0.7
		mat.metallic = 0.8
	else:
		mat.albedo_color = Color("f38c6c") if randf() > 0.3 else Color("f06292") # Juicy Peach or Berry
		mat.roughness = 0.3
	inst.material_override = mat

	var spawn_pos := Vector3(dropper_x + randf_range(-0.2, 0.2), 4.8, 0)
	inst.position = spawn_pos
	vp.add_child(inst)

	balls_3d.append({
		"mesh": inst,
		"pos": spawn_pos,
		"vel": Vector3(randf_range(-0.6, 0.6), randf_range(-0.5, -1.0), 0),
		"radius": 0.25,
		"is_fever": is_fever_drop,
		"is_clock": (not is_fever_drop and randf() < 0.08)
	})
	play_sfx("tap", randf_range(1.1, 1.4))

func _update_orchard_drop_3d(delta: float) -> void:
	if not started or ended: return

	# Auto dropper / reload
	drop_cooldown -= delta
	if is_fever:
		fever_timer -= delta
		if fever_timer <= 0:
			is_fever = false
			hud_combo.text = "Fever ended!"
		elif drop_cooldown <= 0:
			drop_cooldown = 0.16
			dropper_x = randf_range(-2.5, 2.5)
			_drop_fruit(true)
	elif drop_cooldown <= 0:
		drop_cooldown = 0.75
		_drop_fruit(false)

	# Update Catcher position
	catcher_mesh.position.x = lerpf(catcher_mesh.position.x, catcher_x, delta * 18.0)
	catcher_mesh.position.x = clampf(catcher_mesh.position.x, -2.8, 2.8)

	# Pet cheer idle bounce
	if is_instance_valid(pet_cheer_sprite):
		pet_cheer_sprite.scale = Vector2(1.0 + sin(elapsed * 6.0) * 0.08, 1.0 - sin(elapsed * 6.0) * 0.08)

	# Update Bumper animations
	for b in bumpers_3d:
		if b.hit_anim > 0:
			b.hit_anim -= delta * 4.0
			b.mesh.rotation_degrees.z += delta * 720.0
			b.mat.emission_energy_multiplier = 1.0 + b.hit_anim * 3.0
		else:
			b.mat.emission_energy_multiplier = 1.0

	# Update Peg animations
	for p in pegs_3d:
		if p.hit_anim > 0:
			p.hit_anim -= delta * 4.0
			p.mesh.scale = Vector3.ONE * (1.0 + p.hit_anim * 0.4)
		else:
			p.mesh.scale = Vector3.ONE

	# Physics simulation for bouncing fruits
	var gravity := Vector3(0, -9.8, 0)
	for i in range(balls_3d.size() - 1, -1, -1):
		var b = balls_3d[i]
		b.vel += gravity * delta
		b.pos += b.vel * delta

		# Wall collisions
		if b.pos.x < -3.4:
			b.pos.x = -3.4
			b.vel.x = absf(b.vel.x) * 0.8
			play_sfx("bounce", 0.9)
		elif b.pos.x > 3.4:
			b.pos.x = 3.4
			b.vel.x = -absf(b.vel.x) * 0.8
			play_sfx("bounce", 0.9)

		# Peg collisions
		for p in pegs_3d:
			var diff: Vector3 = b.pos - p.pos
			diff.z = 0
			var dist := diff.length()
			var min_dist: float = b.radius + p.radius
			if dist < min_dist and dist > 0.001:
				var normal: Vector3 = diff.normalized()
				b.pos = p.pos + normal * min_dist
				b.vel = b.vel.bounce(normal) * 0.82 + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 0.8), 0)
				p.hit_anim = 1.0
				play_sfx("bounce", randf_range(1.0, 1.5))
				if World.data.settings.haptics: Input.vibrate_handheld(15)
				score += 2
				fever += 3.0
				_check_fever()

		# Bumper collisions
		for bm in bumpers_3d:
			var diff: Vector3 = b.pos - bm.pos
			diff.z = 0
			var dist := diff.length()
			var min_dist: float = b.radius + bm.radius
			if dist < min_dist and dist > 0.001:
				var normal: Vector3 = diff.normalized()
				b.pos = bm.pos + normal * min_dist
				b.vel = normal * 6.5
				bm.hit_anim = 1.0
				play_sfx("spring", 1.2)
				score += 15
				fever += 8.0
				hud_combo.text = "💥 BUMPER BLAST! +15"
				_check_fever()

		# Catcher Basket Catch check
		if b.pos.y <= -4.2 and b.pos.y >= -4.7:
			if absf(b.pos.x - catcher_mesh.position.x) < 0.9:
				combo += 1
				var pts := 20 * combo if b.is_fever else 10 * combo
				score += pts
				fever += 12.0
				play_sfx("coin", 1.0 + combo * 0.08)
				if World.data.settings.haptics: Input.vibrate_handheld(30)
				hud_combo.text = "✨ CATCH x%d! +%d" % [combo, pts]
				if b.is_clock:
					remaining += 4.0
					hud_combo.text = "⏱ +4 SECONDS BONUS!"
				_check_fever()
				# Remove ball
				b.mesh.queue_free()
				balls_3d.remove_at(i)
				continue

		# Bottom slot fall
		if b.pos.y < -5.4:
			combo = 0
			b.mesh.queue_free()
			balls_3d.remove_at(i)
			continue

		b.mesh.position = b.pos

func _check_fever() -> void:
	if not is_fever and fever >= 100.0:
		fever = 0.0
		is_fever = true
		fever_timer = 8.0
		play_sfx("fever")
		hud_combo.text = "🌟 RAINBOW FEVER ACTIVATED! 🌟"
		if World.data.settings.haptics: Input.vibrate_handheld(50)

# -------------------------------------------------------------
# GAME 2: KIN CLOUD HOP 3D (VERTICAL PLATFORMER)
# -------------------------------------------------------------
func _init_cloud_hop_3d() -> void:
	vp_container = SubViewportContainer.new()
	vp_container.position = Vector2(20, 200)
	vp_container.size = Vector2(680, 960)
	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vp_container)

	vp = SubViewport.new()
	vp.size = Vector2i(680, 960)
	vp.own_world_3d = true
	vp.world_3d = World3D.new()
	vp_container.add_child(vp)

	camera = Camera3D.new()
	camera.position = Vector3(0, 4.5, 9.5)
	camera.rotation_degrees = Vector3(-12, 0, 0)
	camera.current = true
	vp.add_child(camera)

	var dir_light := DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-55, 30, 0)
	dir_light.light_energy = 1.15
	vp.add_child(dir_light)

	var ambient_light := OmniLight3D.new()
	ambient_light.position = Vector3(0, 6.0, 5.0)
	ambient_light.light_energy = 0.8
	ambient_light.omni_range = 30.0
	vp.add_child(ambient_light)

	# 3D Sky Backdrop Plane
	hop_sky_mesh = MeshInstance3D.new()
	var sky_box := BoxMesh.new()
	sky_box.size = Vector3(22.0, 45.0, 0.2)
	hop_sky_mesh.mesh = sky_box
	hop_sky_mesh.position = Vector3(0, 5.0, -5.0)
	var sky_mat := StandardMaterial3D.new()
	sky_mat.albedo_color = Color("cdebf8")
	sky_mat.roughness = 1.0
	hop_sky_mesh.material_override = sky_mat
	vp.add_child(hop_sky_mesh)

	# Drifting 3D Decorative Background Clouds at depth z = -2.8
	for ci in range(14):
		var bg_cloud := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = randf_range(0.7, 1.4)
		s.height = s.radius * 1.1
		bg_cloud.mesh = s
		bg_cloud.position = Vector3(randf_range(-6.0, 6.0), randf_range(0.0, 35.0), -2.8)
		var c_mat := StandardMaterial3D.new()
		c_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.65)
		c_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		c_mat.roughness = 0.9
		bg_cloud.material_override = c_mat
		vp.add_child(bg_cloud)
		hop_bg_clouds.append({
			"mesh": bg_cloud,
			"speed": randf_range(0.3, 0.7),
			"dir": 1.0 if randf() > 0.5 else -1.0
		})

	# 3D Pet Avatar representation
	hop_pet = MeshInstance3D.new()
	var pet_sphere := SphereMesh.new()
	pet_sphere.radius = 0.45
	pet_sphere.height = 0.85
	hop_pet.mesh = pet_sphere
	var pet_mat := StandardMaterial3D.new()
	pet_mat.albedo_color = Color("fff5eb")
	pet_mat.roughness = 0.4
	hop_pet.material_override = pet_mat
	vp.add_child(hop_pet)

	# Billboard face sprite inside 3D pet
	hop_pet_sprite = Sprite3D.new()
	hop_pet_sprite.texture = Art.pet(World.data.pet.get("species", 0), 4)
	hop_pet_sprite.pixel_size = 0.0055
	hop_pet_sprite.position = Vector3(0, 0, 0.48)
	hop_pet.add_child(hop_pet_sprite)

	# Generate Initial Platform Column
	_spawn_hop_platforms(0.0, 35.0)

func _spawn_hop_platforms(from_y: float, to_y: float) -> void:
	var cur_y := from_y
	while cur_y < to_y:
		cur_y += randf_range(1.6, 2.3)
		var p_x := randf_range(-2.4, 2.4)
		var p_type := "normal"
		var r := randf()
		if r < 0.18: p_type = "spring" # Super jump spring
		elif r < 0.35: p_type = "crumbly" # Crumbles fast
		elif r < 0.50: p_type = "moving" # Moves left and right

		var plat_root := Node3D.new()
		plat_root.position = Vector3(p_x, cur_y, 0)
		vp.add_child(plat_root)

		var plat_mesh := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(1.5, 0.3, 0.8)
		plat_mesh.mesh = p_box

		var p_mat := StandardMaterial3D.new()
		if p_type == "spring":
			p_mat.albedo_color = Color("ff70a6")
			p_mat.emission_enabled = true
			p_mat.emission = Color("ff70a6") * 0.5
		elif p_type == "crumbly":
			p_mat.albedo_color = Color("ffb703")
		elif p_type == "moving":
			p_mat.albedo_color = Color("70d6ff")
		else:
			p_mat.albedo_color = Color("f0f8ff")
			p_mat.roughness = 0.5
		plat_mesh.material_override = p_mat
		plat_root.add_child(plat_mesh)

		# Fluffy rounded cloud end-puffs
		for side in [-0.75, 0.75]:
			var puff := MeshInstance3D.new()
			var puff_sphere := SphereMesh.new()
			puff_sphere.radius = 0.26
			puff_sphere.height = 0.45
			puff.mesh = puff_sphere
			puff.position = Vector3(side, 0, 0)
			puff.material_override = p_mat
			plat_root.add_child(puff)

		# Spring mushroom cap
		if p_type == "spring":
			var cap := MeshInstance3D.new()
			var cap_sphere := SphereMesh.new()
			cap_sphere.radius = 0.3
			cap_sphere.height = 0.3
			cap.mesh = cap_sphere
			cap.position = Vector3(0, 0.2, 0)
			var cap_mat := StandardMaterial3D.new()
			cap_mat.albedo_color = Color("ff3377")
			cap_mat.emission_enabled = true
			cap_mat.emission = Color("ff3377") * 0.7
			cap.material_override = cap_mat
			plat_root.add_child(cap)

		hop_platforms.append({
			"mesh": plat_root,
			"pos": Vector3(p_x, cur_y, 0),
			"size": Vector3(1.6, 0.3, 0.8),
			"type": p_type,
			"broken": false,
			"dir": 1.0 if randf() > 0.5 else -1.0
		})

		# Golden Star above platform
		if randf() < 0.35:
			var star := MeshInstance3D.new()
			var star_mesh := TorusMesh.new()
			star_mesh.inner_radius = 0.14
			star_mesh.outer_radius = 0.28
			star.mesh = star_mesh
			star.rotation_degrees = Vector3(90, 0, 0)
			star.position = Vector3(p_x, cur_y + 0.85, 0)
			var s_mat := StandardMaterial3D.new()
			s_mat.albedo_color = Color("ffd166")
			s_mat.emission_enabled = true
			s_mat.emission = Color("ffd166") * 0.6
			star.material_override = s_mat
			vp.add_child(star)
			hop_stars.append({
				"mesh": star,
				"pos": star.position,
				"collected": false
			})

func _update_cloud_hop_3d(delta: float) -> void:
	if not started or ended: return

	# Physics
	var gravity := Vector3(0, -18.0, 0)
	hop_vel += gravity * delta
	hop_pos += hop_vel * delta

	# Horizontal steering toward target
	hop_pos.x = lerpf(hop_pos.x, hop_target_x, delta * 10.0)
	hop_pos.x = clampf(hop_pos.x, -3.2, 3.2)

	# Squish & Stretch jump animation
	if hop_vel.y > 0:
		hop_pet.scale = Vector3(0.85, 1.2, 0.85)
	else:
		hop_pet.scale = Vector3(1.1, 0.9, 1.1)

	# Platform landing check (only when falling)
	if hop_vel.y < 0:
		for p in hop_platforms:
			if p.broken: continue
			var dx: float = absf(hop_pos.x - p.pos.x)
			var dy: float = hop_pos.y - p.pos.y
			if dx < p.size.x * 0.58 and dy >= -0.2 and dy <= 0.45:
				if p.type == "spring":
					hop_vel.y = 18.0 # Super Jump!
					play_sfx("spring", 1.3)
					hud_combo.text = "🚀 SUPER SPRING JUMP! +50"
					score += 50
					combo += 1
				else:
					hop_vel.y = 11.8 # Standard bounce
					play_sfx("bounce", randf_range(1.1, 1.3))
					score += 15
					combo += 1
					hud_combo.text = "☁️ Hop streak x%d!" % combo

				if p.type == "crumbly":
					p.broken = true
					p.mesh.queue_free()

				if World.data.settings.haptics: Input.vibrate_handheld(20)
				break

	# Collect star coins with 3D spin
	for s in hop_stars:
		if is_instance_valid(s.mesh) and not s.collected:
			s.mesh.rotation_degrees.y += delta * 150.0
			s.mesh.position.y = s.pos.y + sin(elapsed * 4.0 + s.pos.x) * 0.1
			if hop_pos.distance_to(s.mesh.position) < 0.75:
				s.collected = true
				s.mesh.queue_free()
				score += 30
				play_sfx("coin", 1.4)
				hud_combo.text = "⭐ Star Jewel! +30"
				if World.data.settings.haptics: Input.vibrate_handheld(25)

	# Update Moving platforms
	for p in hop_platforms:
		if p.type == "moving" and not p.broken and is_instance_valid(p.mesh):
			p.pos.x += p.dir * delta * 2.2
			if p.pos.x > 2.4: p.dir = -1.0
			elif p.pos.x < -2.4: p.dir = 1.0
			p.mesh.position = p.pos

	# Camera follow
	if hop_pos.y > hop_highest_y:
		hop_highest_y = hop_pos.y
		instructions.text = "Altitude: %dm" % int(hop_highest_y * 10)

		# Altitude milestones
		var current_tier: int = int(hop_highest_y / 15.0)
		if current_tier > hop_last_milestone:
			hop_last_milestone = current_tier
			var alt_m: int = current_tier * 150
			score += 50
			hud_combo.text = "🌤 ALTITUDE %dm REACHED! +50 PTS" % alt_m
			play_sfx("fever", 1.2)
			if World.data.settings.haptics: Input.vibrate_handheld(40)

	var target_cam_y: float = maxf(4.0, hop_pos.y + 1.5)
	camera.position.y = lerpf(camera.position.y, target_cam_y, delta * 8.0)

	# Backdrop sky gradient progression
	if is_instance_valid(hop_sky_mesh):
		hop_sky_mesh.position.y = camera.position.y
		var alt_factor: float = clampf(hop_highest_y / 80.0, 0.0, 1.0)
		var sky_mat: StandardMaterial3D = hop_sky_mesh.material_override
		if alt_factor < 0.5:
			sky_mat.albedo_color = Color("cdebf8").lerp(Color("8ecae6"), alt_factor * 2.0)
		else:
			sky_mat.albedo_color = Color("8ecae6").lerp(Color("283044"), (alt_factor - 0.5) * 2.0)

	# Drifting background clouds with parallax and vertical wrap
	for c in hop_bg_clouds:
		if is_instance_valid(c.mesh):
			c.mesh.position.x += c.dir * c.speed * delta
			if c.mesh.position.x > 7.0: c.mesh.position.x = -7.0
			elif c.mesh.position.x < -7.0: c.mesh.position.x = 7.0
			if c.mesh.position.y < camera.position.y - 14.0:
				c.mesh.position.y = camera.position.y + randf_range(12.0, 24.0)
				c.mesh.position.x = randf_range(-6.0, 6.0)

	# Spawn more platforms dynamically as player ascends
	if hop_platforms.size() > 0 and camera.position.y + 20.0 > hop_platforms.back().pos.y:
		_spawn_hop_platforms(hop_platforms.back().pos.y, camera.position.y + 35.0)

	hop_pet.position = hop_pos

	# Fall rescue / Game over
	if hop_pos.y < camera.position.y - 7.0:
		finish()

# -------------------------------------------------------------
# GAME 3: TREASURE MATCH 3D (TACTILE 3D CARD FLIP)
# -------------------------------------------------------------
func _init_treasure_match() -> void:
	remaining = 45.0
	match_grid = GridContainer.new()
	match_grid.columns = 3
	match_grid.position = Vector2(40, 230)
	match_grid.add_theme_constant_override("h_separation", 18)
	match_grid.add_theme_constant_override("v_separation", 18)
	add_child(match_grid)

	# Cheering pet mascot at bottom-right
	pet_cheer_sprite = Art.image(Art.pet(World.data.pet.get("species", 0), 4), Vector2(130, 130))
	pet_cheer_sprite.position = Vector2(540, 1020)
	pet_cheer_sprite.pivot_offset = Vector2(65, 65)
	add_child(pet_cheer_sprite)

	_setup_match_board()

func _setup_match_board() -> void:
	cards.clear()
	match_revealed.clear()
	match_pairs_left = 6

	for c in match_grid.get_children():
		c.queue_free()

	var pair_ids := [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
	pair_ids.shuffle()

	var icons := [
		Art.atlas("res://assets/objects-final.png", 6, 4, 0),  # Peach
		Art.atlas("res://assets/objects-final.png", 6, 4, 1),  # Berry
		Art.atlas("res://assets/objects-final.png", 6, 4, 6),  # Daisy
		Art.atlas("res://assets/objects-final.png", 6, 4, 7),  # Shell
		Art.atlas("res://assets/objects-final.png", 6, 4, 10), # Leaf
		Art.atlas("res://assets/objects-final.png", 6, 4, 12), # Moon
	]

	for i in range(12):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 205)
		btn.text = "🌸\n✦"
		btn.add_theme_font_size_override("font_size", 34)
		btn.add_theme_color_override("font_color", Color("b89758"))
		btn.add_theme_stylebox_override("normal", _box_style(Color("faf6ed"), 24, Color("dfd4bf"), 3))
		btn.add_theme_stylebox_override("hover", _box_style(Color("f4ede0"), 24, Color("cebe9f"), 3))
		btn.add_theme_stylebox_override("pressed", _box_style(Color("eae0cf"), 24, Color("bfae99"), 3))
		btn.pivot_offset = Vector2(100, 102)

		var card_data := {
			"btn": btn,
			"face_tex": icons[pair_ids[i]],
			"id": pair_ids[i],
			"revealed": false,
			"matched": false,
			"flip_t": 0.0,
			"flipping": false,
			"target_rev": false
		}
		btn.pressed.connect(func(): _flip_card(i))
		match_grid.add_child(btn)
		cards.append(card_data)

func _flip_card(index: int) -> void:
	if not started or ended or match_lockout > 0: return
	var c = cards[index]
	if c.revealed or c.matched or match_revealed.size() >= 2: return

	c.revealed = true
	c.flipping = true
	c.flip_t = 0.0
	c.target_rev = true
	match_revealed.append(index)
	play_sfx("tap", 1.2)

	if match_revealed.size() == 2:
		var c1 = cards[match_revealed[0]]
		var c2 = cards[match_revealed[1]]
		if c1.id == c2.id:
			# Match!
			c1.matched = true
			c2.matched = true
			match_pairs_left -= 1
			combo += 1
			remaining += 3.0 # Time bonus!
			var pts := 25 * combo
			score += pts
			hud_combo.text = "💎 MATCH x%d! +%d PTS & +3s!" % [combo, pts]
			play_sfx("coin", 1.1 + combo * 0.1)
			if World.data.settings.haptics: Input.vibrate_handheld(35)
			spawn_sparkles(c1.btn.global_position + Vector2(100, 100))
			spawn_sparkles(c2.btn.global_position + Vector2(100, 100))

			# Mascot reaction
			if is_instance_valid(pet_cheer_sprite):
				var tw := create_tween()
				tw.tween_property(pet_cheer_sprite, "scale", Vector2(1.25, 0.8), 0.1)
				tw.tween_property(pet_cheer_sprite, "scale", Vector2(0.9, 1.25), 0.15)
				tw.tween_property(pet_cheer_sprite, "scale", Vector2.ONE, 0.15)

			match_revealed.clear()
			if match_pairs_left <= 0:
				play_sfx("fever")
				var clear_pts := 150 * match_level
				score += clear_pts
				remaining += 12.0
				match_level += 1
				hud_combo.text = "🎉 MEADOW CLEARED! +%d & +12s!" % clear_pts
				await get_tree().create_timer(1.0).timeout
				if not ended:
					_setup_match_board()
					instructions.text = "Meadow %d: Keep the streak alive!" % match_level
		else:
			# Mismatch
			combo = 0
			match_lockout = 0.8

func _update_treasure_match(delta: float) -> void:
	if not started or ended: return

	# Mascot idle bobbing
	if is_instance_valid(pet_cheer_sprite):
		pet_cheer_sprite.position.y = 1020 + sin(elapsed * 5.0) * 6.0

	# Handle 3D card flipping rotation
	for c in cards:
		if c.flipping:
			c.flip_t += delta * 6.0
			var scale_x := cos(c.flip_t * PI)
			c.btn.scale.x = absf(scale_x)
			if c.flip_t >= 0.5 and not c.btn.icon:
				c.btn.icon = c.face_tex
				c.btn.text = ""
				c.btn.expand_icon = true
				c.btn.add_theme_constant_override("icon_max_width", 110)
				c.btn.add_theme_stylebox_override("normal", _box_style(Color("ffffff"), 24, Color("73856b"), 3))
			if c.flip_t >= 1.0:
				c.flipping = false
				c.btn.scale.x = 1.0

	if match_lockout > 0:
		match_lockout -= delta
		if match_lockout <= 0:
			for idx in match_revealed:
				var c = cards[idx]
				c.revealed = false
				c.btn.icon = null
				c.btn.text = "🌸\n✦"
				c.btn.add_theme_stylebox_override("normal", _box_style(Color("faf6ed"), 24, Color("dfd4bf"), 3))
			match_revealed.clear()

# -------------------------------------------------------------
# INPUT HANDLING & GAME LOOP
# -------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if not started or ended: return

	if kind == "catch":
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			if event.pressed:
				# Drop fruit where tapped at the top
				var touch_x: float = (event.position.x / 720.0 - 0.5) * 6.8
				dropper_x = clampf(touch_x, -3.0, 3.0)
				_drop_fruit(is_fever)
		elif event is InputEventScreenDrag or event is InputEventMouseMotion:
			var touch_x: float = (event.position.x / 720.0 - 0.5) * 6.8
			catcher_x = clampf(touch_x, -3.0, 3.0)

	elif kind == "hop":
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			if event.pressed:
				hop_touch_active = true
				if event.position.x < 360:
					hop_target_x = clampf(hop_pos.x - 1.4, -2.8, 2.8)
				else:
					hop_target_x = clampf(hop_pos.x + 1.4, -2.8, 2.8)
		elif event is InputEventScreenDrag or event is InputEventMouseMotion:
			var touch_x: float = (event.position.x / 720.0 - 0.5) * 6.0
			hop_target_x = clampf(touch_x, -2.8, 2.8)

func _process(delta: float) -> void:
	if not started or ended: return

	elapsed += delta
	remaining -= delta
	hud_score.text = "✦ %d" % score
	hud_timer.text = "⏱ %ds" % ceili(maxf(0.0, remaining))

	if kind == "catch":
		_update_orchard_drop_3d(delta)
	elif kind == "hop":
		_update_cloud_hop_3d(delta)
	elif kind == "match":
		_update_treasure_match(delta)

	if remaining <= 0.0:
		finish()

func finish() -> void:
	if ended: return
	ended = true
	play_sfx("reward")
	instructions.text = "🎉 Awesome! Final Score: %d" % score
	hud_combo.text = "Petals Earned: +%d 🌸" % World.game_reward(kind, score)
	await get_tree().create_timer(1.4).timeout
	finished.emit(score)

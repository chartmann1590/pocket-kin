extends Control

const Art = preload("res://scripts/art.gd")
const MiniGame = preload("res://scripts/minigame.gd")

const INK = Color("3a332a")
const SAGE = Color("627c59")
const SAGE_DARK = Color("4b6144")
const MUTED = Color("7a6d5c")
const CREAM = Color("fbf8f1")
const WARM_BORDER = Color("e5decb")

var page := "Home"
var body: VBoxContainer
var shell: VBoxContainer
var overlay: Control
var toast_label: Label
var pet_image: TextureRect
var thought_box: PanelContainer
var needs: Dictionary = {}
var need_labels: Dictionary = {}
var coin_label: Label
var pet_title: Label
var mood_label: Label
var time := 0.0
var selected_egg := 0
var music: AudioStreamPlayer
var effects: AudioStreamPlayer
var last_explore := 0.0
var cloud_conflict: Dictionary = {}
var root_margin: MarginContainer
var safe_top := 38
var safe_bottom := 22

# --- 3D Toy Ball in Room ---
var toy_active := false
var toy_vp_container: SubViewportContainer
var toy_vp: SubViewport
var toy_ball: MeshInstance3D
var toy_pos := Vector3(0, 0, 0)
var toy_vel := Vector3(2.5, 3.5, 0)
var toy_touch_down := false
var toy_touch_start := Vector2.ZERO

func _ready() -> void:
	var theme := Theme.new()
	if ResourceLoader.exists("res://assets/Nunito.ttf"):
		var font := FontVariation.new()
		font.base_font = load("res://assets/Nunito.ttf")
		font.variation_opentype = {"wght": 600}
		font.variation_embolden = 0.35
		theme.default_font = font
	theme.default_font_size = 23
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_stylebox("normal", "Button", box(Color("f2ece0"), 20, WARM_BORDER, 2, 4))
	theme.set_stylebox("hover", "Button", box(Color("e8e0d0"), 20, Color("d5cbba"), 2, 4))
	theme.set_stylebox("pressed", "Button", box(Color("dfd6c4"), 20, Color("c9beab"), 2, 1))
	theme.set_stylebox("focus", "Button", box(Color(0,0,0,0), 20, SAGE, 2))
	theme.set_stylebox("disabled", "Button", box(Color("ebe6dc"), 20))
	theme.set_color("font_disabled_color", "Button", Color("9d9587"))
	theme.set_stylebox("normal", "LineEdit", box(Color("fffdf8"), 16, Color("c7cdbb"), 2))
	theme.set_stylebox("focus", "LineEdit", box(Color("fffdf8"), 16, SAGE, 2))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("caret_color", "LineEdit", SAGE)
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		theme.set_color(state, "CheckButton", INK)
	self.theme = theme

	World.changed.connect(refresh)
	World.notice.connect(toast)
	Platform.result.connect(platform_result)

	music = AudioStreamPlayer.new()
	effects = AudioStreamPlayer.new()
	add_child(music)
	add_child(effects)

	if ResourceLoader.exists("res://assets/ambient.wav"):
		music.stream = load("res://assets/ambient.wav")
		music.volume_db = -21
		music.finished.connect(func(): music.play() if World.data.settings.music else music.stop())
		if World.data.settings.music: music.play()

	show_page("Home")

	if Platform.native:
		Platform.call_service("fullscreen", {"enabled": World.data.settings.get("fullscreen", false)})
		Platform.call_deferred("_publish")

func box(color: Color, radius := 24, border := Color.TRANSPARENT, border_width := 2, bottom_shadow := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(18)
	if border.a > 0:
		style.border_color = border
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width + bottom_shadow
	elif bottom_shadow > 0:
		style.border_color = color.darkened(0.12)
		style.border_width_bottom = bottom_shadow
	return style

func label(text: String, font_size := 24, color := INK, serif := false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if serif and ResourceLoader.exists("res://assets/Lora.ttf"):
		node.add_theme_font_override("font", load("res://assets/Lora.ttf"))
	return node

func paragraph(text: String, parent: Node, font_size := 23) -> Label:
	var node := label(text, font_size, MUTED)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func button(text: String, callback: Callable, parent: Node, accent := false) -> Button:
	var node := Button.new()
	node.text = text
	var icon_map := {"Feed":0,"Cuddle":1,"Wash":2,"Sleep":3,"Home":4,"Play":8,"Explore":4,"Walk":4,"Room":7,"Memory album":9,"Sanctuary":4}
	if icon_map.has(text):
		node.icon = Art.atlas("res://assets/ui-icons-final.png", 6, 2, icon_map[text])
		node.expand_icon = true
		node.add_theme_constant_override("icon_max_width", 28)
	node.custom_minimum_size.y = 66
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(func(): sound(); callback.call())
	if accent:
		node.add_theme_stylebox_override("normal", box(SAGE, 20, SAGE_DARK, 1, 4))
		node.add_theme_stylebox_override("hover", box(SAGE.lightened(0.1), 20, SAGE_DARK, 1, 4))
		node.add_theme_stylebox_override("pressed", box(SAGE_DARK, 20, SAGE_DARK, 1, 1))
		node.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(node)
	return node

func row(parent: Node, separation := 12) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	parent.add_child(node)
	return node

func card(parent: Node, color := Color.WHITE) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(color, 24, WARM_BORDER, 2, 3))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	return content

func show_page(next: String) -> void:
	page = next
	pet_image = null
	thought_box = null
	needs.clear()
	need_labels.clear()
	pet_title = null
	mood_label = null
	toy_active = false
	toy_vp_container = null
	toy_ball = null

	for child in get_children():
		if child != music and child != effects:
			remove_child(child)
			child.queue_free()

	# Main background
	var background := ColorRect.new()
	background.color = CREAM
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	root_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	margin.add_theme_constant_override("margin_top", safe_top)
	margin.add_theme_constant_override("margin_bottom", safe_bottom)
	add_child(margin)

	shell = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 16)
	margin.add_child(shell)

	# --- Sleek Modern Header Bar ---
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", box(Color("faf6ed"), 22, WARM_BORDER, 2, 2))
	shell.add_child(header)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	header.add_child(header_row)

	var pet_name: String = World.data.pet.get("name", "Pocket Kin")
	var stage_name: String = str(World.data.pet.get("stage", "friend")).capitalize()
	var brand := label("🐾 %s · %s" % [pet_name, stage_name], 23, INK, true)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(brand)

	# Golden Petals Pill Badge
	var petal_badge := PanelContainer.new()
	petal_badge.add_theme_stylebox_override("panel", box(Color("fdf7ea"), 16, Color("eeddb6"), 1))
	header_row.add_child(petal_badge)
	var petal_box := HBoxContainer.new()
	petal_box.add_theme_constant_override("separation", 6)
	petal_badge.add_child(petal_box)
	coin_label = label("🌸 ✦ %d" % World.data.coins, 21, Color("8f6534"))
	petal_box.add_child(coin_label)

	# Settings Button
	var menu := Button.new()
	menu.text = "⚙️"
	menu.custom_minimum_size = Vector2(58, 52)
	menu.add_theme_font_size_override("font_size", 22)
	menu.add_theme_stylebox_override("normal", box(Color("f3ebe0"), 16, WARM_BORDER, 1, 2))
	menu.pressed.connect(func(): sound(); show_page("Settings"))
	header_row.add_child(menu)

	# Scroll Container for Content
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)

	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	scroll.add_child(body)

	if World.data.pet.is_empty() and next != "Settings":
		adoption()
	else:
		match next:
			"Home": home()
			"Play": play_page()
			"Explore": explore_page()
			"Walk": walk_page()
			"Room": room_page()
			"Album": album_page()
			"Sanctuary": sanctuary_page()
			"Settings": settings_page()

	# --- Floating Modern Bottom Navigation Dock ---
	var nav_panel := PanelContainer.new()
	nav_panel.add_theme_stylebox_override("panel", box(Color("faf7f0"), 28, WARM_BORDER, 2, 4))
	shell.add_child(nav_panel)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 6)
	nav_panel.add_child(nav_row)

	var nav_items := [
		["Home", "🏠 Home"],
		["Play", "🎮 Play"],
		["Explore", "🌿 Explore"],
		["Walk", "👟 Walk"],
		["Room", "🪑 Room"]
	]
	for item in nav_items:
		var item_name: String = item[0]
		var item_text: String = item[1]
		var b := Button.new()
		b.text = item_text
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 68
		b.add_theme_font_size_override("font_size", 19)
		if item_name == page:
			b.add_theme_stylebox_override("normal", box(SAGE, 20, SAGE_DARK, 1, 3))
			b.add_theme_stylebox_override("hover", box(SAGE, 20, SAGE_DARK, 1, 3))
			b.add_theme_color_override("font_color", Color.WHITE)
		else:
			b.add_theme_stylebox_override("normal", box(Color(0,0,0,0), 20))
			b.add_theme_stylebox_override("hover", box(Color("ede6d8"), 20))
			b.add_theme_color_override("font_color", INK)
		b.pressed.connect(func(): sound(); show_page(item_name))
		nav_row.add_child(b)

	# Toast Overlay
	toast_label = label("", 22, Color.WHITE)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", box(INK, 18))
	toast_label.position = Vector2(38, 1070)
	toast_label.size = Vector2(644, 85)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.hide()
	add_child(toast_label)

	refresh()

	if Platform.native:
		Platform.call_service("screen", {"page": page})
		Platform.call_service("insets")

func section(kicker: String, title: String, description := "") -> void:
	body.add_child(label(kicker.to_upper(), 17, SAGE))
	body.add_child(label(title, 37, INK, true))
	if not description.is_empty(): paragraph(description, body)

func adoption() -> void:
	section("A little beginning", "Someone is waiting for you.", "Choose a tiny egg. Grow a very big friendship.")
	var hero := card(body, Color("f1ebdf"))
	var preview := Art.image(Art.pet(selected_egg, 0), Vector2(0, 250))
	hero.add_child(preview)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	hero.add_child(grid)

	for i in range(6):
		var species: Dictionary = World.SPECIES[i]
		var unlocked: bool = World.data.lifetime_bond >= species.unlock
		var text: String = species.name if unlocked else "%d bond" % species.unlock
		var b := button(text, func(): selected_egg = i; show_page("Home"), grid, selected_egg == i)
		b.disabled = not unlocked

	paragraph(World.SPECIES[selected_egg].kind + " · Loves " + World.SPECIES[selected_egg].favorite.to_lower(), hero)
	var input := LineEdit.new()
	input.placeholder_text = "Your pet's name"
	input.text = World.SPECIES[selected_egg].name
	input.max_length = 20
	input.custom_minimum_size.y = 68
	hero.add_child(input)

	button("Meet my little friend", func(): hatch(selected_egg, input.text), hero, true)
	paragraph("A gentle home. Free food and care. A friend for every kind of day.", body, 21)

func spawn_heart(parent: Node, pos: Vector2) -> void:
	var heart := Label.new()
	heart.text = ["💕", "💖", "✨", "🌸", "⭐"][randi() % 5]
	heart.position = pos - Vector2(16, 16)
	heart.add_theme_font_size_override("font_size", 26)
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(heart)
	var tween := create_tween()
	tween.tween_property(heart, "position", pos - Vector2(randf_range(-20, 20), 65), 0.7)
	tween.parallel().tween_property(heart, "modulate:a", 0.0, 0.7)
	tween.tween_callback(heart.queue_free)

func bubble_bath_modal() -> void:
	show_page("Home")
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

	button("← Back to Room", func(): show_page("Home"), body)
	section("Bubble Bath Time", "Splish Splash! 🫧", "Tap the iridescent warm bubbles to give %s a joyful, sparkling bath." % World.data.pet.name)
	var stage := card(body, Color(0.91, 0.96, 0.95, 1.0))
	var center_pet := Art.image(Art.pet(World.data.pet.species, 4), Vector2(0, 240))
	stage.add_child(center_pet)

	var bubble_grid := GridContainer.new()
	bubble_grid.columns = 4
	bubble_grid.add_theme_constant_override("h_separation", 12)
	bubble_grid.add_theme_constant_override("v_separation", 12)
	stage.add_child(bubble_grid)

	var popped := [0]
	for i in range(12):
		var b := Button.new()
		b.text = "🫧"
		b.add_theme_font_size_override("font_size", 42)
		b.custom_minimum_size = Vector2(120, 72)
		b.add_theme_stylebox_override("normal", box(Color("e0f2f1"), 18, Color("80cbc4"), 2, 3))
		bubble_grid.add_child(b)
		b.pressed.connect(func():
			play_sound("bubble")
			if World.data.settings.haptics: Input.vibrate_handheld(25)
			World.pop_bath_bubble()
			b.disabled = true
			b.text = "✨"
			spawn_heart(stage, b.position + Vector2(60, 36))
			popped[0] += 1
		)

	button("All Squeaky Clean & Sparkling! 🧼✨", func():
		play_sound("care")
		show_page("Home")
		toast("Fluffy, fresh, and sparkling clean!")
	, body, true)

func _setup_3d_toy(stage: Control) -> void:
	toy_vp_container = SubViewportContainer.new()
	toy_vp_container.position = Vector2.ZERO
	toy_vp_container.size = Vector2(668, 395)
	toy_vp_container.stretch = true
	toy_vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(toy_vp_container)

	toy_vp = SubViewport.new()
	toy_vp.size = Vector2i(668, 395)
	toy_vp.own_world_3d = true
	toy_vp.world_3d = World3D.new()
	toy_vp.transparent_bg = true
	toy_vp_container.add_child(toy_vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 5.8)
	cam.current = true
	toy_vp.add_child(cam)

	var dir_light := DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-45, 30, 0)
	dir_light.light_energy = 1.2
	toy_vp.add_child(dir_light)

	var omni := OmniLight3D.new()
	omni.position = Vector3(0, 1.0, 2.5)
	omni.light_energy = 1.4
	toy_vp.add_child(omni)

	toy_ball = MeshInstance3D.new()
	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.35
	s_mesh.height = 0.7
	toy_ball.mesh = s_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff6b6b") # vibrant bouncy rubber ball
	mat.roughness = 0.2
	mat.metallic = 0.1
	toy_ball.material_override = mat
	toy_vp.add_child(toy_ball)

	toy_pos = Vector3(0, 0.5, 0)
	toy_vel = Vector3(randf_range(-2.5, 2.5), 3.5, 0)

func home() -> void:
	var pet: Dictionary = World.data.pet

	# Greeting & mood header
	var greeting := row(body)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	greeting.add_child(title_box)
	title_box.add_child(label("YOUR COZY COMPANION", 17, SAGE))
	pet_title = label(pet.name + "'s happy sanctuary", 36, INK, true)
	title_box.add_child(pet_title)
	mood_label = label("", 21, MUTED)
	title_box.add_child(mood_label)

	# --- Pet Living Stage ---
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 395)
	stage.clip_contents = true
	body.add_child(stage)

	var bg := Art.image(load("res://assets/home.png"), Vector2.ZERO)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)

	# Ambient lighting tint matching time of day
	var hour: int = Time.get_time_dict_from_system().hour
	var tint_color := Color("ffffff")
	if hour >= 20 or hour < 6:
		tint_color = Color("b0bede") # starry twilight glow
	elif hour >= 17:
		tint_color = Color("fec8b0") # golden sunset glow
	elif hour < 11:
		tint_color = Color("fef3d5") # warm morning sunrise
	var light_overlay := ColorRect.new()
	light_overlay.color = Color(tint_color.r, tint_color.g, tint_color.b, 0.18)
	light_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	light_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(light_overlay)

	# Furnishings
	var slots := {"cushion":Vector2(55,260),"plant":Vector2(495,195),"lamp":Vector2(465,100),"rug":Vector2(235,295),"bunting":Vector2(250,8),"picture":Vector2(50,60)}
	for item in World.catalog():
		if World.data.room.get(item.slot, "") == item.id:
			var deco := Art.image(Art.atlas("res://assets/decor-final.png", 6, 5, int(item.id.trim_prefix("decor_"))), Vector2.ZERO)
			deco.position = slots[item.slot]
			deco.size = Vector2(130, 100)
			stage.add_child(deco)

	# Floating Mood Thought Bubble
	thought_box = PanelContainer.new()
	thought_box.add_theme_stylebox_override("panel", box(Color("fffef9"), 16, Color("dcd5c7"), 2, 2))
	thought_box.position = Vector2(170, 44)
	thought_box.custom_minimum_size = Vector2(320, 42)
	var thought_text := Label.new()
	var thought_msg := "Feeling super snuggly! 💕"
	if pet.get("sleeping", false): thought_msg = "Dreaming of sweet peaches 🍑"
	elif pet.get("ill", false): thought_msg = "Needs a gentle cuddle 🩹"
	elif pet.get("hunger", 80) < 40: thought_msg = "Tummy is rumbling! 🍎"
	elif pet.get("cleanliness", 80) < 40: thought_msg = "Ready for bubble bath! 🫧"
	elif pet.get("happiness", 80) > 85: thought_msg = "Bouncing with pure joy! ✨"
	thought_text.text = thought_msg
	thought_text.add_theme_font_size_override("font_size", 19)
	thought_text.add_theme_color_override("font_color", INK)
	thought_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought_box.add_child(thought_text)
	stage.add_child(thought_box)

	# Pet Character Image with Shadow
	pet_image = Art.image(Art.pet(pet.species, pose()), Vector2.ZERO)
	pet_image.position = Vector2(191, 100)
	pet_image.size = Vector2(282, 282)
	pet_image.pivot_offset = Vector2(141, 141)
	stage.add_child(pet_image)

	# Interactive Touch / Petting Area
	var pet_touch := Control.new()
	pet_touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stroke_dist := [0.0]
	pet_touch.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenDrag or event is InputEventMouseMotion:
			spawn_heart(stage, event.position)
			stroke_dist[0] += 12.0
			if stroke_dist[0] >= 110.0:
				stroke_dist[0] = 0.0
				World.pet_stroke()
				play_sound("purr")
				if World.data.settings.haptics: Input.vibrate_handheld(25)
				if is_instance_valid(pet_image) and not World.data.pet.get("sleeping", false):
					pet_image.texture = Art.pet(World.data.pet.species, 4)
					get_tree().create_timer(1.2).timeout.connect(refresh)
			# Flick 3D toy if active
			if toy_active and is_instance_valid(toy_ball):
				toy_vel = Vector3(randf_range(-4.0, 4.0), randf_range(3.5, 6.0), 0)
				play_sound("bounce")
		elif (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and not event.pressed):
			if toy_active:
				toy_vel = Vector3(randf_range(-3.5, 3.5), randf_range(3.0, 5.5), 0)
				play_sound("bounce")
			else:
				do_care("love")
	)
	stage.add_child(pet_touch)

	# 3D Toy Toggle Button on Stage
	var toy_btn := Button.new()
	toy_btn.text = "🎾 3D Toy"
	toy_btn.position = Vector2(20, 18)
	toy_btn.custom_minimum_size = Vector2(130, 48)
	toy_btn.add_theme_font_size_override("font_size", 18)
	toy_btn.add_theme_stylebox_override("normal", box(Color("fff9ee"), 16, Color("e5d2b0"), 2, 2))
	toy_btn.pressed.connect(func():
		toy_active = not toy_active
		if toy_active:
			_setup_3d_toy(stage)
			toast("🎾 3D Toy Ball dropped in the room! Flick it to bounce!")
			play_sound("bounce")
		else:
			if is_instance_valid(toy_vp_container):
				toy_vp_container.queue_free()
			toy_vp_container = null
			toy_ball = null
			toast("Toy put away.")
	)
	stage.add_child(toy_btn)

	# Accessories & Premiums
	if not World.data.accessory.is_empty():
		var accessory := Art.image(Art.atlas("res://assets/accessories-final.png", 4, 3, int(World.data.accessory.trim_prefix("accessory_"))), Vector2.ZERO)
		accessory.position = Vector2(290, 160)
		accessory.size = Vector2(85, 65)
		stage.add_child(accessory)

	var equipped: String = World.data.get("premium_equipped", "")
	var packs := ["kin_cottage", "kin_moonlight", "kin_blossom"]
	if equipped in World.data.get("entitlements", []) and equipped in packs:
		var extras := Art.image(Art.atlas("res://assets/premium-final.png", 3, 1, packs.find(equipped)), Vector2.ZERO)
		extras.position = Vector2(450, 230)
		extras.size = Vector2(180, 145)
		stage.add_child(extras)

	# --- Vibrant Needs Dashboard (4 colorful pill cards) ---
	var meters := row(body, 8)
	var meter_info := {
		"hunger": {"name": "🍗 Fed", "color": Color("ff7043"), "bg": Color("fff3e0")},
		"happiness": {"name": "💖 Joy", "color": Color("ec407a"), "bg": Color("fce4ec")},
		"cleanliness": {"name": "🫧 Clean", "color": Color("26a69a"), "bg": Color("e0f2f1")},
		"energy": {"name": "⚡ Rest", "color": Color("ffa726"), "bg": Color("fff8e1")}
	}
	for key in ["hunger", "happiness", "cleanliness", "energy"]:
		var info = meter_info[key]
		var panel := card(meters, info.bg)
		panel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val: int = clampi(int(World.data.pet.get(key, 80)), 0, 100)
		var stat_lbl := label("%s %d%%" % [info.name, val], 18, INK)
		panel.add_child(stat_lbl)
		need_labels[key] = stat_lbl

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(90, 14)
		bar.show_percentage = false
		bar.max_value = 100
		bar.value = val
		bar.add_theme_stylebox_override("background", box(Color("e5ded2"), 7))
		bar.add_theme_stylebox_override("fill", box(info.color, 7))
		panel.add_child(bar)
		needs[key] = bar

	# --- Chunky Tactile Action Buttons ---
	var actions := row(body, 8)
	var action_configs := [
		["Feed", "🍎 Feed", Color("fdf0ed"), Color("ff7043"), func(): feed_menu()],
		["Cuddle", "💖 Cuddle", Color("fdf0f4"), Color("ec407a"), func(): do_care("love")],
		["Bath", "🫧 Bath", Color("edf7f6"), Color("26a69a"), func(): bubble_bath_modal()],
		["Sleep", "💤 Sleep", Color("f3f0fd"), Color("7e57c2"), func(): do_care("sleep")]
	]
	for act in action_configs:
		var act_btn := Button.new()
		act_btn.text = act[1]
		act_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act_btn.custom_minimum_size.y = 74
		act_btn.add_theme_font_size_override("font_size", 22)
		act_btn.add_theme_stylebox_override("normal", box(act[2], 20, act[3].lightened(0.4), 2, 4))
		act_btn.add_theme_stylebox_override("hover", box(act[2].lightened(0.1), 20, act[3], 2, 4))
		act_btn.add_theme_stylebox_override("pressed", box(act[2].darkened(0.05), 20, act[3], 2, 1))
		act_btn.add_theme_color_override("font_color", INK)
		var cb: Callable = act[4]
		act_btn.pressed.connect(func(): sound(); cb.call())
		actions.add_child(act_btn)

	if pet.ill:
		button("Feeling poorly · give free treatment 🩹", func(): do_care("treat"), body, true)

	var note := card(body, Color("edf2e8"))
	note.add_child(label("Little things, together", 27, INK, true))
	paragraph("%s loves %s. %s and always happy to be with you." % [pet.name, World.favorite_food().to_lower(), World.personality()], note, 22)
	if pet.bond >= 30:
		button("Show me a little trick 🌟", perform_trick, note)
	button("Today's little wishes   →", func(): tasks_page(), note)

	var links := row(body)
	button("Memory album", func(): show_page("Album"), links)
	button("Sanctuary", func(): show_page("Sanctuary"), links)

func pose() -> int:
	var p: Dictionary = World.data.pet
	if p.get("sleeping", false): return 5
	if p.get("ill", false): return 7
	if p.get("cleanliness", 100) < 25: return 6
	return {"baby":1, "juvenile":2, "adult":3}.get(p.get("stage", "baby"), 1)

func hatch(species: int, pet_name: String) -> void:
	var veil := ColorRect.new()
	veil.color = CREAM
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var egg := Art.image(Art.pet(species, 0), Vector2.ZERO)
	egg.size = Vector2(330, 400)
	egg.position = Vector2(195, 330)
	egg.pivot_offset = egg.size / 2
	veil.add_child(egg)

	var text := label("A tiny crack. A little wiggle…", 29, INK, true)
	text.position = Vector2(110, 790)
	veil.add_child(text)

	if not World.data.settings.reduced_motion:
		var tween := create_tween()
		for i in range(6):
			tween.tween_property(egg, "rotation", 0.08 if i % 2 == 0 else -0.08, 0.18)
		await tween.finished
	else:
		await get_tree().create_timer(1).timeout

	World.adopt(species, pet_name)
	egg.rotation = 0
	egg.texture = Art.pet(species, 1)
	text.text = "Hello, " + World.data.pet.name + "."
	play_sound("hatch")
	await get_tree().create_timer(1.5).timeout
	show_page("Home")
	toast("Your story together starts here.")

func feed_menu() -> void:
	show_page("Home")
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

	button("← Back to Room", func(): show_page("Home"), body)
	section("Something tasty", "A little picnic 🍎", "Fresh fruit, always free. Discover what your companion loves.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)

	for i in range(6):
		var content := card(grid, Color("fbf8f0"))
		content.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(Art.image(Art.atlas("res://assets/objects-final.png", 6, 4, i), Vector2(220, 130)))
		var fruit_name: String = ["Peaches", "Berries", "Pears", "Apples", "Melon", "Plums"][i]
		var btn_row := row(content, 6)
		button("Eat " + fruit_name, func():
			if World.feed_food(i):
				show_page("Home")
				play_sound("munch")
				toast("Munch munch! %s loved the %s!" % [World.data.pet.name, fruit_name.to_lower()])
			else: toast("Let's finish this bite first.")
		, btn_row, true)
		button("Toss 🎯", func():
			if World.toss_fruit(i):
				show_page("Home")
				play_sound("munch")
				if World.data.settings.haptics: Input.vibrate_handheld(30)
				toast("Chomp! %s leaped and caught the %s! 🌟" % [World.data.pet.name, fruit_name.to_lower()])
			else: toast("Let's finish this bite first.")
		, btn_row, false)

	button("← Back to Room", func(): show_page("Home"), body)

func perform_trick() -> void:
	if not is_instance_valid(pet_image): return
	pet_image.texture = Art.pet(World.data.pet.species, 4)
	pet_image.pivot_offset = pet_image.size / 2
	if not World.data.settings.reduced_motion:
		var tween := create_tween()
		var angle := TAU if World.data.pet.bond >= 75 else 0.15
		tween.tween_property(pet_image, "rotation", angle, 0.8)
		tween.tween_property(pet_image, "rotation", 0.0, 0.3)
		await tween.finished
	var trick: String = "A happy spin" if World.data.pet.bond >= 75 else "A little wave"
	if not World.data.pet.get("trick_memory", false):
		World.memory("Our first little trick", World.data.pet.name + " learned to wave just for you.")
		World.data.pet.trick_memory = true
		World.save()
	toast(trick + ", just for you.")

func do_care(action: String) -> void:
	if World.care(action):
		play_sound("sleep" if action == "sleep" else "care")
		if is_instance_valid(pet_image) and not World.data.pet.sleeping:
			pet_image.texture = Art.pet(World.data.pet.species, 4)
			get_tree().create_timer(2).timeout.connect(refresh)
		toast({
			"feed": "A full tummy and a happy little heart.",
			"love": "Your favorite place is together.",
			"clean": "Fresh, fluffy, and ready for the day.",
			"sleep": "A little rest works wonders.",
			"treat": "Feeling better. Thank you for looking after me."
		}[action])
		if action == "treat": show_page("Home")
		if World.data.settings.haptics: Input.vibrate_handheld(35)
		if World.task_progress("care") == 1: Platform.call_service("care_complete", World.data.settings)

func refresh() -> void:
	if is_instance_valid(coin_label):
		coin_label.text = "🌸 ✦ %d" % World.data.coins
	if World.data.pet.is_empty(): return
	for key in needs:
		if is_instance_valid(needs[key]):
			var val: int = clampi(int(World.data.pet[key]), 0, 100)
			needs[key].value = val
			if need_labels.has(key) and is_instance_valid(need_labels[key]):
				var icon_name: String = str({"hunger":"🍗 Fed","happiness":"💖 Joy","cleanliness":"🫧 Clean","energy":"⚡ Rest"}.get(key, ""))
				need_labels[key].text = "%s %d%%" % [icon_name, val]
	if is_instance_valid(pet_image):
		pet_image.texture = Art.pet(World.data.pet.species, pose())
	if is_instance_valid(mood_label):
		mood_label.text = "%s  ·  Friendship %d  ·  %s" % [
			str(World.data.pet.stage).capitalize(),
			World.data.pet.bond,
			"Dreaming 💤" if World.data.pet.sleeping else ("Needs a little care 🩹" if World.data.pet.ill else "Happy to see you ✨")
		]

func tasks_page() -> void:
	show_page("Album")
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

	section("A little every day", "Today's little wishes", "Small moments make the best memories. Each wish earns 25 petals.")
	for task in [["care", 3, "Share three moments of care"], ["play", 1, "Play a game together"], ["explore", 1, "Discover something outside"]]:
		var content := card(body)
		content.add_child(label(task[2], 26))
		paragraph("%d / %d complete" % [mini(World.task_progress(task[0]), task[1]), task[1]], content)
		var claimed: bool = "task:" + World.day_key() + ":" + task[0] in World.data.claims
		var b := button("Collected" if claimed else "Collect 25 petals", func():
			if World.claim_task(task[0], task[1]): tasks_page()
		, content, true)
		b.disabled = claimed or World.task_progress(task[0]) < task[1]

# --- REVAMPED PLAY PAGE SHOWCASING 3D ARCADE MINIGAMES ---
func play_page() -> void:
	section("Arcade & Adventures", "Play, laugh, repeat.", "Addictive 3D arcade games! Happy hearts and bonus petals.")
	var games_meta := [
		["catch", "🌟 Orchard Drop 3D", "3D PACHINKO ARCADE", "Aim, drop & bounce fruits through 3D pegs, bumpers, and catch combos into the moving basket! Trigger Rainbow Fever for jackpot cascades!", Color("fdf4e7"), Color("e28743")],
		["hop", "☁️ Kin Sky Hop 3D", "3D CLOUD HOPPER", "Bounce your companion across floating 3D clouds, super mushroom springboards, and soaring star platforms! How high can you climb?", Color("edf7fd"), Color("3a86c8")],
		["match", "💎 Treasure Match 3D", "3D CARD FLIP", "Tactile 3D perspective card flip! Match pairs of glistening woodland treasures, build combo streaks, and clear the meadow before time runs out!", Color("f7edf9"), Color("8e44ad")]
	]
	for g in games_meta:
		var content := card(body, g[4])
		var badge_row := row(content)
		var badge := label(g[2], 16, g[5])
		badge_row.add_child(badge)
		var best_score: int = int(World.data.bests.get(g[0], 0))
		var best_lbl := label("🏆 Best: %d" % best_score, 18, SAGE)
		badge_row.add_child(best_lbl)

		content.add_child(label(g[1], 29, INK, true))
		paragraph(g[3], content, 21)
		var btn := button("Play %s   🚀" % g[1], func(): start_game(g[0]), content, true)
		btn.custom_minimum_size.y = 70

func start_game(kind: String) -> void:
	var game_layer := ColorRect.new()
	game_layer.color = CREAM
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_layer)

	var game := MiniGame.new()
	game.kind = kind
	game.size = Vector2(720, 1280)
	game_layer.add_child(game)

	var fit_game := func():
		var available := get_viewport_rect().size - Vector2(0, safe_top + safe_bottom)
		var factor := minf(available.x / 720.0, available.y / 1280.0)
		game.scale = Vector2.ONE * factor
		game.position = Vector2((available.x - 720 * factor) / 2, safe_top + (available.y - 1280 * factor) / 2)
	fit_game.call()
	game_layer.resized.connect(fit_game)

	game.finished.connect(func(score: int):
		game_layer.queue_free()
		var reward := World.game_reward(kind, score)
		show_page("Play")
		play_sound("reward")
		toast("Awesome game! Score %d · +%d petals 🌸" % [score, reward])
		if World.data.ad.games % 3 == 0 and Time.get_unix_time_from_system() - World.data.ad.last >= 600:
			Platform.call_service("interstitial")
	)
	game.cancelled.connect(func(): game_layer.queue_free())

func explore_page() -> void:
	section("A world of little wonders", "Let's wander.", "Follow your curiosity. Bring a little treasure home.")
	var names := ["Daisy meadow", "Whispering woods", "Moonlit pond"]
	var files := ["meadow", "woodland", "pond"]
	for i in range(3):
		var content := card(body)
		if ResourceLoader.exists("res://assets/" + files[i] + ".png"):
			content.add_child(Art.image(load("res://assets/" + files[i] + ".png"), Vector2(0, 160)))
		content.add_child(label(names[i], 28, INK, true))
		var locked: bool = World.data.lifetime_bond < [0, 20, 60][i]
		var b := button("Unlocks at %d friendship" % [0, 20, 60][i] if locked else "Take a little trip   →", func(): outing(i), content, true)
		b.disabled = locked

func outing(destination: int) -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	section("Follow a little feeling", "Where shall we look?", "Choose a place to explore together.")
	var file: String = ["meadow", "woodland", "pond"][destination]
	if ResourceLoader.exists("res://assets/" + file + ".png"):
		body.add_child(Art.image(load("res://assets/" + file + ".png"), Vector2(0, 350)))
	for i in range(3):
		button(["Among the flowers", "Beside the path", "Under a little leaf"][i], func():
			if Time.get_unix_time_from_system() - last_explore < 15:
				toast("Let's enjoy this little moment first.")
				return
			last_explore = Time.get_unix_time_from_system()
			var found := World.explore(destination, i)
			show_page("Explore")
			toast("Found a %s! +8 petals" % found.to_lower())
		, body, true)

func walk_page() -> void:
	section("Every step, together", "Walk & Health Expedition", "Your steps and watch health give your pet energy and unlock joyful parcels.")
	var content := card(body, Color("edf2e8"))
	content.add_child(Art.image(Art.pet(World.data.pet.species, 4), Vector2(0, 190)))

	var total_steps: int = int(World.data.walking.get("steps", 0))
	content.add_child(label("%d steps today" % total_steps, 43, INK, true))

	var watch_info: Dictionary = World.data.walking.get("watch", {})
	if not watch_info.is_empty():
		var sync_row := row(content, 8)
		var sync_badge := label("🟢 Wear Companion Synced", 19, Color("2e7d32"))
		sync_row.add_child(sync_badge)

		var hr: int = int(watch_info.get("heart_rate", 74))
		var hr_text := "❤️ %d BPM · %s" % [hr, "Serene Harmony (+Friendship)" if hr in range(60, 83) else "Lively Pulse"]
		paragraph(hr_text, content, 21)

		var hydration: int = int(watch_info.get("hydration", 0))
		var hydro_text := "💧 Hydration: %d / 8 cups water logged" % hydration
		paragraph(hydro_text, content, 20)

		var cals: int = int(watch_info.get("calories", 0))
		var mins: int = int(watch_info.get("active_minutes", 0))
		paragraph("🔥 Active energy: %d kcal · %d active min" % [cals, mins], content, 19)
	else:
		paragraph(World.data.walking.status, content)

	var progress := ProgressBar.new()
	progress.max_value = 3000
	progress.value = total_steps
	progress.show_percentage = false
	progress.custom_minimum_size.y = 22
	progress.add_theme_stylebox_override("background", box(Color("d6dec9"), 10))
	progress.add_theme_stylebox_override("fill", box(Color("627c59"), 10))
	content.add_child(progress)

	var milestone_card := card(body, Color("f5f0e6"))
	milestone_card.add_child(label("Daily Expedition Parcels", 26, INK, true))
	for m in [[500, "Dewdrop Pouch", "15 petals"], [1500, "Sunbeam Parcel", "15 petals"], [3000, "Golden Star Chest", "20 petals"]]:
		var m_row := row(milestone_card, 10)
		var claimed: bool = "walk:" + World.day_key() + ":" + str(m[0]) in World.data.claims
		var reached: bool = total_steps >= m[0]
		var status_str := "Claimed ✦" if claimed else ("Ready to open! 🎁" if reached else "%d steps needed" % (m[0] - total_steps))
		var item_label := label("%s (%s): %s" % [m[1], m[2], status_str], 20, Color("4a7043") if reached else MUTED)
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_row.add_child(item_label)

	button("Sync watch & health now", func():
		Platform.call_service("get_watch_health")
		Platform.call_service("steps", {"activated": World.data.walking.activated})
		toast("Syncing with your Wear companion…")
	, body, true)

	button("Start phone walking session", func(): Platform.call_service("start_walk", {"activated": World.data.walking.activated}), body)
	button("Stop phone walking session", func(): Platform.call_service("stop_walk"), body)
	paragraph("Watch step counting and health sync over Bluetooth or Internet fallback. Steps, heart rhythm, and hydration boost your pet's happiness and health safely on-device.", body, 20)

func room_page() -> void:
	section("Make yourself at home", "A room full of you.", "Earn petals through play, then find something lovely.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)

	for item in World.catalog():
		var content := card(grid)
		content.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accessory: bool = item.slot == "accessory"
		var index := int(item.id.get_slice("_", 1))
		content.add_child(Art.image(Art.atlas("res://assets/accessories-final.png" if accessory else "res://assets/decor-final.png", 4 if accessory else 6, 3 if accessory else 5, index), Vector2(230, 105)))
		content.add_child(label(item.name, 21))
		var owned: bool = item.id in World.data.inventory
		button("Place / wear" if owned else "✦ %d petals" % item.cost, func():
			if World.buy_equip(item):
				show_page("Room")
				toast("A lovely little choice. See it at home!")
			else: toast("Earn a few more petals through play.")
		, content, owned)

	var premium := card(body, Color("f0eaf3"))
	premium.add_child(label("A little extra magic", 29, INK, true))
	paragraph("Optional permanent cosmetic collections. All pet care is always free.", premium)
	for pack in [["kin_cottage", "Cottage mornings"], ["kin_moonlight", "Moonlight dreams"], ["kin_blossom", "Blossom picnic"]]:
		premium.add_child(Art.image(Art.atlas("res://assets/premium-final.png", 3, 1, ["kin_cottage", "kin_moonlight", "kin_blossom"].find(pack[0])), Vector2(0, 150)))
		var owned: bool = pack[0] in World.data.get("entitlements", [])
		button("Decorate with " + pack[1] if owned else pack[1], func():
			if owned:
				World.data.premium_equipped = pack[0]
				World.save()
				show_page("Home")
			else: parent_gate(func(): Platform.call_service("purchase", {"product": pack[0]}))
		, premium)
	button("Optional video · 20 bonus petals", func(): Platform.call_service("rewarded"), body)

func album_page() -> void:
	section("The story of us", "Little moments, forever.", "A growing collection of the days you shared.")
	if World.data.memories.is_empty():
		paragraph("Your first memory is just around the corner.", body)
	for memory in World.data.memories:
		var content := card(body)
		content.add_child(label(memory.date, 18, SAGE))
		content.add_child(label(memory.title, 27, INK, true))
		paragraph(memory.body, content)
	if not World.data.discoveries.is_empty():
		paragraph("Your discoveries: " + ", ".join(World.data.discoveries), body)

func sanctuary_page() -> void:
	section("Always part of the family", "A softer place to stay.", "Grown friends can settle here whenever you're ready. There is no rush.")
	if ResourceLoader.exists("res://assets/sanctuary.png"):
		body.add_child(Art.image(load("res://assets/sanctuary.png"), Vector2(0, 250)))
	for pet in World.data.sanctuary:
		var content := card(body)
		content.add_child(Art.image(Art.pet(pet.species, 3), Vector2(0, 130)))
		content.add_child(label(pet.name + " · always loved", 27, INK, true))
	if World.data.sanctuary.is_empty():
		paragraph("A peaceful garden for your future grown friends.", body)
	var b := button("Settle my grown pet here", func():
		var dialog := ConfirmationDialog.new()
		dialog.dialog_text = "Your grown friend stays in the sanctuary, and you can adopt a new egg. Move them now?"
		dialog.confirmed.connect(func(): World.retire(); show_page("Home"))
		add_child(dialog)
		dialog.popup_centered(Vector2i(580, 220))
	, body)
	b.disabled = World.data.pet.stage != "adult"

func settings_page() -> void:
	section("Just your kind of cozy", "Make it yours.")
	var content := card(body)
	for pair in [["music", "Ambient music"], ["effects", "Little sound effects"], ["haptics", "Gentle haptics"], ["reduced_motion", "Reduce motion"], ["fullscreen", "Full-screen mode"], ["reminders", "Friendly care reminders"]]:
		var toggle := CheckButton.new()
		toggle.text = pair[1]
		toggle.custom_minimum_size.y = 64
		toggle.button_pressed = World.data.settings.get(pair[0], false)
		toggle.toggled.connect(func(enabled):
			World.data.settings[pair[0]] = enabled
			World.save()
			if pair[0] == "music": music.play() if enabled else music.stop()
			if pair[0] == "fullscreen": Platform.call_service("fullscreen", {"enabled": enabled})
			if pair[0] == "reminders": Platform.call_service("reminders", World.data.settings)
		)
		content.add_child(toggle)
	for pair in [["sleep_hour", "Bedtime hour"], ["wake_hour", "Wake-up hour"], ["quiet_start", "Quiet hours start"], ["quiet_end", "Quiet hours end"]]:
		var line := row(content)
		line.add_child(label(pair[1], 24))
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 23
		spin.value = World.data.settings[pair[0]]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(value): World.data.settings[pair[0]] = int(value); World.save())
		line.add_child(spin)

	paragraph(Platform.status, body)
	button("Connect cloud saves", func(): parent_gate(func(): Platform.call_service("sign_in")), body, true)
	button("Back up this pet", func(): Platform.call_service("cloud_save", {"save": World.cloud_snapshot(), "revision": World.data.cloud_revision}), body)
	button("Restore cloud save", func(): Platform.call_service("cloud_load"), body)
	if World.has_cloud_conflict():
		button("Review cloud save conflict", func(): cloud_conflict_dialog(), body, true)
	button("Restore cosmetic purchases", func(): parent_gate(func(): Platform.call_service("restore")), body)
	button("Privacy and ad choices", func(): Platform.call_service("privacy"), body)
	button("Connect a Wear OS watch", func(): Platform.call_service("watch_status"), body)
	button("Add home-screen widget", func(): Platform.call_service("pin_widget"), body)
	button("Delete cloud account", func(): parent_gate(func(): Platform.call_service("delete_account")), body)
	paragraph("Pocket Kin · Original art and a little everyday magic.\nCloud services and purchases need a configured release. Your local pet is saved automatically.", body, 20)

func cloud_conflict_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "The cloud has a different save that is not newer than yours. Use the cloud copy, or keep playing with this pet? Your choice is kept either way."
	dialog.ok_button_text = "Use cloud"
	dialog.cancel_button_text = "Keep mine"
	dialog.confirmed.connect(func():
		World.resolve_cloud_conflict(true)
		show_page("Home")
		toast("Cloud save applied.")
	)
	dialog.canceled.connect(func():
		World.resolve_cloud_conflict(false)
		show_page("Settings")
		toast("Kept your local pet.")
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(580, 260))

func parent_gate(action: Callable) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "For a grown-up"
	var layout := VBoxContainer.new()
	dialog.add_child(layout)
	layout.add_child(label("What is 7 × 8?", 27))
	var answer := LineEdit.new()
	answer.custom_minimum_size = Vector2(350, 60)
	layout.add_child(answer)
	dialog.confirmed.connect(func():
		if answer.text.strip_edges() == "56": action.call()
		else: toast("Please ask a grown-up to help.")
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(450, 220))

func platform_result(kind: String, payload: Dictionary) -> void:
	if kind == "widget_open":
		var p: String = str(payload.get("page", "Home"))
		if not World.data.pet.is_empty():
			if p == "Feed": feed_menu()
			elif p == "Walk": show_page("Walk")
			elif p == "Love": do_care("love")
			elif p == "Play": show_page("Play")
			else: show_page("Home")
		else: show_page("Home")
	if kind == "insets":
		var ratio := get_viewport_rect().size.x / maxf(1, DisplayServer.window_get_size().x)
		safe_top = maxi(38, ceili(float(payload.get("top", 0)) * ratio) + 12)
		safe_bottom = maxi(22, ceili(float(payload.get("bottom", 0)) * ratio) + 12)
		if is_instance_valid(root_margin):
			root_margin.add_theme_constant_override("margin_top", safe_top)
			root_margin.add_theme_constant_override("margin_bottom", safe_bottom)
	if kind == "steps" and payload.get("ok", false):
		if page == "Walk": show_page("Walk")
	elif kind == "interstitial" and payload.get("shown", false):
		World.data.ad.last = Time.get_unix_time_from_system()
		World.save()
	elif kind == "cloud_save" and payload.get("ok", false):
		World.data.cloud_revision = payload.get("revision", World.data.cloud_revision)
		World.data.sync_local_revision = World.data.revision
		World.save(false)
	elif kind == "cloud_save" and payload.get("conflict", false) and payload.get("save") is Dictionary:
		World.stash_cloud(payload.save)
		cloud_conflict_dialog()
	elif kind == "cloud_load" and payload.get("ok", false) and payload.has("save"):
		World.data.entitlements = payload.get("entitlements", [])
		var outcome := World.apply_cloud_snapshot(payload.save)
		if outcome == "applied":
			show_page("Home")
			toast("Cloud save restored. Welcome back!")
		elif outcome == "kept-local":
			cloud_conflict_dialog()
		else:
			toast("That cloud save could not be used. Your local pet is safe.")
	if payload.has("message"): toast(payload.message)

func toast(message: String) -> void:
	if not is_instance_valid(toast_label): return
	toast_label.position = Vector2(38, maxf(safe_top, get_viewport_rect().size.y - safe_bottom - 190))
	toast_label.size.x = get_viewport_rect().size.x - 76
	toast_label.text = message
	toast_label.show()
	var current := toast_label
	get_tree().create_timer(4).timeout.connect(func():
		if is_instance_valid(current): current.hide()
	)

func sound() -> void:
	play_sound("tap")

func play_sound(name: String) -> void:
	if World.data.settings.effects and ResourceLoader.exists("res://assets/" + name + ".wav"):
		effects.stream = load("res://assets/" + name + ".wav")
		effects.play()

func _process(delta: float) -> void:
	time += delta

	# Subtle pet idle breathing & life
	if is_instance_valid(pet_image) and not World.data.settings.reduced_motion:
		var breath := sin(time * 3.2) * 0.032
		pet_image.scale = Vector2(1.0 + breath, 1.0 - breath)
		pet_image.position.y = 100 + sin(time * 2.0) * 3.5

	# Gentle floating bob for mood thought bubble
	if is_instance_valid(thought_box) and not World.data.settings.reduced_motion:
		thought_box.position.y = 44 + sin(time * 2.2) * 3.0

	# 3D Toy Ball physics in the pet room
	if toy_active and is_instance_valid(toy_ball):
		toy_vel.y -= 12.0 * delta # gravity
		toy_pos += toy_vel * delta

		# Floor bounce
		if toy_pos.y <= -1.4:
			toy_pos.y = -1.4
			toy_vel.y = absf(toy_vel.y) * 0.82
			toy_vel.x *= 0.95
			play_sound("bounce")
			if is_instance_valid(pet_image):
				pet_image.scale = Vector2(1.15, 0.85)

		# Ceiling bounce
		if toy_pos.y >= 1.6:
			toy_pos.y = 1.6
			toy_vel.y = -absf(toy_vel.y) * 0.8

		# Wall bounds
		if toy_pos.x <= -2.4:
			toy_pos.x = -2.4
			toy_vel.x = absf(toy_vel.x) * 0.8
			play_sound("bounce")
		elif toy_pos.x >= 2.4:
			toy_pos.x = 2.4
			toy_vel.x = -absf(toy_vel.x) * 0.8
			play_sound("bounce")

		toy_ball.position = toy_pos
		toy_ball.rotation.z += toy_vel.x * delta * 3.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		World.reconcile()
		if page == "Walk" and World.data.walking.enabled:
			Platform.call_service("steps", {"activated": World.data.walking.activated})

extends Control
signal finished(score: int)
signal cancelled
const Art = preload("res://scripts/art.gd")
var kind := "catch"
var score := 0
var remaining := 25.0
var elapsed := 0.0
var spawn_at := 0.0
var fruit: Array = []
var basket := 360.0
var hud: Label
var instructions: Label
var started := false
var ended := false
var pairs: Array = []
var revealed: Array = []
var matched: Array = []
var reveal_timer := 0.0
var last_beat := -1
var card_buttons: Array = []
var start_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("f3f0e5")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var name_label := Label.new()
	name_label.text = {"catch":"Orchard catch","match":"Memory meadow","rhythm":"Raindrop rhythm"}[kind]
	name_label.position = Vector2(35,70)
	name_label.add_theme_font_size_override("font_size",40)
	add_child(name_label)
	hud = Label.new()
	hud.position = Vector2(35,135)
	hud.add_theme_font_size_override("font_size",26)
	add_child(hud)
	instructions = Label.new()
	instructions.text = {"catch":"Slide your finger to catch the peaches.","match":"Tap two cards to find matching treasures.","rhythm":"Tap when the ripple reaches the outer ring."}[kind]
	instructions.position = Vector2(35,185)
	instructions.add_theme_font_size_override("font_size",23)
	add_child(instructions)
	start_button = Button.new()
	start_button.text = "Ready, let's play"
	start_button.position = Vector2(190,1050)
	start_button.size = Vector2(340,85)
	start_button.pressed.connect(func(): started = true; start_button.hide())
	add_child(start_button)
	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(35,1160)
	back.size = Vector2(130,65)
	back.pressed.connect(func(): cancelled.emit())
	add_child(back)
	if kind == "match":
		remaining = 45
		pairs = [0,0,1,1,2,2,3,3,4,4,5,5]
		pairs.shuffle()
		for i in range(12):
			var card := Button.new()
			card.position = Vector2(65+(i%3)*205,300+(i/3)*165)
			card.size = Vector2(180,145)
			card.text = "✦"
			card.add_theme_font_size_override("font_size",40)
			card.pressed.connect(func(): flip(i))
			add_child(card)
			card_buttons.append(card)
	queue_redraw()

func flip(index: int) -> void:
	if not started or ended or index in revealed or index in matched or revealed.size() >= 2: return
	revealed.append(index)
	card_buttons[index].text = ["Peach","Leaf","Moon","Daisy","Berry","Shell"][pairs[index]]
	card_buttons[index].text = ""
	card_buttons[index].icon=Art.atlas("res://assets/objects-final.png",6,4,[0,10,12,6,1,7][pairs[index]])
	card_buttons[index].expand_icon=true
	card_buttons[index].add_theme_constant_override("icon_max_width",100)
	card_buttons[index].add_theme_font_size_override("font_size",23)
	if revealed.size() == 2:
		if pairs[revealed[0]] == pairs[revealed[1]]:
			matched.append_array(revealed)
			for id in revealed: card_buttons[id].modulate = Color("c0d1ab")
			revealed.clear()
			score += 10
			if matched.size() == 12: finish()
		else: reveal_timer = 0.8

func _gui_input(event: InputEvent) -> void:
	if not started or ended: return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		basket = clampf(event.position.x,70,650)
	elif event is InputEventMouseMotion:
		basket = clampf(event.position.x,70,650)
	if kind == "rhythm" and ((event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)):
		var beat := int(elapsed / 1.5)
		if beat != last_beat:
			last_beat = beat
			var phase := fposmod(elapsed,1.5)/1.5
			if phase > 0.76:
				score += 5 if phase > 0.88 else 3
				instructions.text = "Lovely timing!" if phase > 0.88 else "Almost perfect!"
			else: instructions.text = "Wait for the ripple to reach the ring."

func _process(delta: float) -> void:
	if not started or ended:
		hud.text = "A little game, just for you two."
		return
	elapsed += delta
	remaining -= delta
	hud.text = "Score %d     ·     %d seconds" % [score,ceili(remaining)]
	if kind == "catch":
		spawn_at -= delta
		if spawn_at <= 0:
			spawn_at = maxf(0.35,0.85-elapsed*0.015)
			fruit.append(Vector2(randf_range(70,650),260))
		for i in range(fruit.size()-1,-1,-1):
			fruit[i].y += (190+elapsed*5)*delta
			if fruit[i].y > 935:
				if absf(fruit[i].x-basket) < 78: score += 3
				fruit.remove_at(i)
	elif kind == "match" and reveal_timer > 0:
		reveal_timer -= delta
		if reveal_timer <= 0:
			for index in revealed:
				card_buttons[index].text = "✦"
				card_buttons[index].icon = null
				card_buttons[index].add_theme_font_size_override("font_size",40)
			revealed.clear()
	queue_redraw()
	if remaining <= 0: finish()

func finish() -> void:
	if ended: return
	ended = true
	finished.emit(score)

func _draw() -> void:
	if kind == "catch":
		var peach := Art.atlas("res://assets/objects-final.png",6,4,0)
		for position in fruit:
			if peach: draw_texture_rect(peach,Rect2(position-Vector2(34,34),Vector2(68,68)),false)
			else: draw_circle(position,28,Color("e8ac92"))
		var basket_art := Art.atlas("res://assets/objects-final.png",6,4,17)
		if basket_art: draw_texture_rect(basket_art,Rect2(basket-75,915,150,110),false)
	elif kind == "rhythm":
		var center := Vector2(360,650)
		draw_circle(center,190,Color("e3e9dc"))
		draw_arc(center,190,0,TAU,80,Color("73856b"),8,true)
		var radius := 30+fposmod(elapsed,1.5)/1.5*170
		draw_arc(center,radius,0,TAU,80,Color("b7c9a5"),12,true)
		var texture := Art.pet(World.data.pet.get("species",0),4)
		if texture: draw_texture_rect(texture,Rect2(280,570,160,160),false)

func _basket_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ae8260")
	style.set_corner_radius_all(15)
	return style

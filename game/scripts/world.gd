extends Node

signal changed
signal notice(message: String)
const Sim = preload("res://scripts/simulation.gd")
const SAVE = "user://pocket-kin.json"
const SPECIES = [
	{"name":"Mochi", "kind":"Meadow bun", "color":"fff0dc", "favorite":"Peaches", "unlock":0},
	{"name":"Fern", "kind":"Forest fox", "color":"c3d1a4", "favorite":"Berries", "unlock":0},
	{"name":"Pebble", "kind":"Cloud bear", "color":"c2d6e4", "favorite":"Pears", "unlock":0},
	{"name":"Clover", "kind":"Sprout deer", "color":"d8d5a0", "favorite":"Apples", "unlock":50},
	{"name":"Pippin", "kind":"Sun puff", "color":"f3c38e", "favorite":"Melon", "unlock":100},
	{"name":"Lumi", "kind":"Moon moth", "color":"d8c6e5", "favorite":"Plums", "unlock":150}
]
var data: Dictionary
var save_error := false

func watch_action(request: Dictionary) -> bool:
	var receipts: Dictionary = data.get("watch_receipts",{})
	var id: String = request.get("id","")
	if id.is_empty(): return false
	if receipts.has(id): return receipts[id]
	if data.pet.is_empty() or request.get("pet_id") != data.pet.id or int(request.get("revision",-1)) != int(data.revision): return false
	var ok := false
	var action: String = request.get("action","")
	if action == "watch_play":
		var now := Time.get_unix_time_from_system()
		if request.get("duration",0) < 20 or now-float(data.pet.last_actions.get("watch_play",0)) < 20: return false
		data.pet.last_actions.watch_play = now
		game_reward("watch_rhythm",clampi(int(request.get("hits",0)),0,14)*3)
		ok = true
	else:
		ok = care(action)
	receipts[id] = ok
	if receipts.size()>100: receipts.erase(receipts.keys()[0])
	data.watch_receipts = receipts
	save(true)
	return ok

func fresh() -> Dictionary:
	return {"schema":1, "revision":0, "pet":{}, "sanctuary":[], "coins":80, "inventory":[], "room":{}, "accessory":"", "discoveries":[], "memories":[], "bests":{}, "claims":[], "daily":{}, "lifetime_bond":0, "settings":{"music":true,"effects":true,"haptics":true,"reduced_motion":false,"reminders":false,"quiet_start":21,"quiet_end":8,"sleep_hour":22,"wake_hour":7,"utc_offset":Time.get_time_zone_from_system().bias * 60}, "walking":{"enabled":false,"activated":0,"steps":0,"status":"Connect your steps to begin","source":"","updated":0}, "ad":{"games":0,"last":0}, "cloud_revision":0}

func _ready() -> void:
	data = fresh()
	for path in [SAVE, SAVE + ".bak"]:
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if valid_save(parsed):
				data.merge(parsed, true)
				break
	# Forward-compatible settings: older saves keep working when new keys land.
	var defaults: Dictionary = fresh().settings
	for key in defaults:
		if not data.settings.has(key):
			data.settings[key] = defaults[key]
	# Godot unix<->date helpers speak UTC, so local-day math carries this bias
	# (see steps()/simulation.awake_seconds). Refresh it on every launch so
	# travel or DST changes cannot strand sleep windows or walking days.
	data.settings.utc_offset = Time.get_time_zone_from_system().bias * 60
	reconcile()
	var timer := Timer.new()
	timer.wait_time = 60
	timer.timeout.connect(reconcile)
	add_child(timer)
	timer.start()

func valid_save(value: Variant) -> bool:
	if not value is Dictionary or int(value.get("schema", 0)) != 1:
		return false
	for field in ["pet", "settings", "walking", "room", "daily", "ad", "bests"]:
		if not value.get(field) is Dictionary:
			return false
	for field in ["inventory", "sanctuary", "claims", "memories", "discoveries"]:
		if not value.get(field) is Array:
			return false
	if not value.pet.is_empty():
		for field in ["id", "name", "species", "hunger", "happiness", "cleanliness", "energy", "updated", "care_age"]:
			if not value.pet.has(field): return false
	return true

func reconcile() -> void:
	if not data.pet.is_empty():
		var old: String = data.pet.get("stage", "baby")
		Sim.reconcile(data.pet, Time.get_unix_time_from_system(), data.settings)
		if old != data.pet.stage:
			memory("Growing together", "%s became a %s." % [data.pet.name, data.pet.stage])
	save(false)
	changed.emit()

func save(increment := true) -> void:
	if increment: data.revision += 1
	var file := FileAccess.open(SAVE + ".tmp", FileAccess.WRITE)
	if not file:
		save_error = true
		notice.emit("Couldn't save. Please check your device storage.")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(SAVE, SAVE + ".bak")
	var error := DirAccess.rename_absolute(SAVE + ".tmp", SAVE)
	save_error = error != OK
	changed.emit()

func adopt(species: int, pet_name: String) -> void:
	if not data.pet.is_empty() or species < 0 or species >= SPECIES.size(): return
	if data.lifetime_bond < SPECIES[species].unlock: return
	var now := Time.get_unix_time_from_system()
	data.pet = {"id":str(now) + "-" + str(randi()), "name":pet_name.strip_edges().left(20) if not pet_name.strip_edges().is_empty() else SPECIES[species].name, "species":species,"stage":"baby","born":now,"updated":now,"care_age":0.0,"hunger":85.0,"happiness":90.0,"cleanliness":95.0,"energy":90.0,"bond":0,"sleeping":false,"ill":false,"last_actions":{},"activities":{}}
	memory("Hello, little one", "%s hatched. A friendship begins." % data.pet.name)
	save()

func care(action: String) -> bool:
	if data.pet.is_empty(): return false
	reconcile()
	if not Sim.care(data.pet, action, Time.get_unix_time_from_system()): return false
	data.lifetime_bond += 1
	data.pet.activities[action] = int(data.pet.activities.get(action,0))+1
	activity("care")
	if int(data.pet.bond) in [10, 30, 75, 150]:
		memory("Closer every day", "%s reached friendship %d." % [data.pet.name, data.pet.bond])
	save()
	return true

func feed_food(index: int) -> bool:
	if index<0 or index>5 or not care("feed"): return false
	var foods: Dictionary = data.pet.get("foods",{})
	foods[str(index)]=int(foods.get(str(index),0))+1
	data.pet.foods=foods
	if int(foods[str(index)])==3: memory("A new favorite",data.pet.name+" really loves "+favorite_food().to_lower()+".")
	save()
	return true

func favorite_food() -> String:
	if data.pet.is_empty(): return "Peaches"
	var foods: Dictionary=data.pet.get("foods",{})
	var favorite:=int(data.pet.species)%6
	var count:=2
	for key in foods:
		if int(foods[key])>count: favorite=int(key);count=int(foods[key])
	return ["Peaches","Berries","Pears","Apples","Melon","Plums"][favorite]

func personality() -> String:
	if data.pet.is_empty(): return "Curious"
	var activities: Dictionary=data.pet.get("activities",{})
	if int(activities.get("love",0))>=5:return "A snuggly soul"
	if int(activities.get("catch",0))+int(activities.get("rhythm",0))>=3:return "A playful little spirit"
	if int(activities.get("sleep",0))>=3:return "A dreamy little friend"
	return "Curious about everything"

func memory(title: String, description: String) -> void:
	data.memories.push_front({"title":title,"body":description,"date":Time.get_date_string_from_system()})
	if data.memories.size() > 250: data.memories.resize(250)

func day_key() -> String:
	return Time.get_date_string_from_system()

func activity(kind: String) -> void:
	var day := day_key()
	if not data.daily.has(day): data.daily[day] = {}
	data.daily[day][kind] = int(data.daily[day].get(kind, 0)) + 1
	# Keep bounded task history, while persistent reward claim IDs remain separate.
	if data.daily.size() > 10:
		var keys: Array = data.daily.keys()
		keys.sort()
		data.daily.erase(keys[0])

var last_game_reward := 0

func daily_chores() -> Array:
	return [
		{"id": "care", "title": "💖 Snuggle & Groom", "desc": "Snuggle, feed, or wash your pet 3 times", "req": 3, "reward": 15},
		{"id": "play", "title": "🎮 Mini-Game Master", "desc": "Play any 2 games with your companion", "req": 2, "reward": 20},
		{"id": "explore", "title": "🌿 Wandering Explorer", "desc": "Embark on 1 wild outing", "req": 1, "reward": 15},
		{"id": "tidy", "title": "🧹 Room Tidying & Care", "desc": "Sweep room dust or tend houseplant", "req": 1, "reward": 15},
		{"id": "walk", "title": "👟 Stride Champion", "desc": "Reach 500+ daily steps together", "req": 500, "reward": 25}
	]

func task_progress(kind: String) -> int:
	if kind == "walk":
		return int(data.walking.get("steps", 0))
	return int(data.daily.get(day_key(), {}).get(kind, 0))

func claim_task(kind: String, required: int, reward: int = 25) -> bool:
	var id := "task:" + day_key() + ":" + kind
	if id in data.claims or task_progress(kind) < required: return false
	data.claims.append(id)
	data.coins += reward
	save()
	return true

func game_reward(kind: String, score: int) -> int:
	if data.pet.is_empty(): return 0
	var reward := clampi(5 + score / 3, 5, 30)
	data.coins += reward
	last_game_reward = reward
	data.pet.happiness = minf(100, data.pet.happiness + 12)
	data.pet.bond += 2
	data.lifetime_bond += 2
	data.bests[kind] = maxi(score, int(data.bests.get(kind, 0)))
	data.pet.activities[kind] = int(data.pet.activities.get(kind, 0)) + 1
	data.ad.games += 1
	activity("play")
	save()
	return reward

func explore(destination: int, choice: int) -> String:
	if data.pet.is_empty() or destination < 0 or destination > 2 or data.lifetime_bond < [0, 20, 60][destination]: return "Grow your friendship to unlock this place."
	var names := [["Daisy crown", "Smooth pebble", "Four-leaf clover"], ["Amber acorn", "Fern print", "Robin feather"], ["Moon shell", "Star lily", "Silver reed"]]
	var item: String = names[destination][posmod(choice, 3)]
	if item not in data.discoveries:
		data.discoveries.append(item)
		memory("A little discovery", "%s found a %s." % [data.pet.name, item.to_lower()])
	data.coins += 8
	data.pet.happiness = minf(100, data.pet.happiness + 6)
	data.pet.bond += 1
	data.lifetime_bond += 1
	activity("explore")
	save()
	return item

func catalog() -> Array:
	var out := []
	var types := ["Cushion", "Plant", "Lamp", "Rug", "Bunting", "Picture"]
	var colors := ["Peach", "Sage", "Honey", "Lavender", "Cloud"]
	for i in range(30):
		out.append({"id":"decor_%d" % i,"name":colors[i / 6] + " " + types[i % 6],"slot":types[i % 6].to_lower(),"cost":30 + (i / 6) * 15,"color":["eab29b","9eae8b","e3c17f","bcaacb","b1c8d2"][i / 6]})
	var acc_names := [
		"Peach bow","Sage scarf","Sun crown","Moon ribbon","Berry bow","Cloud scarf",
		"Daisy crown","Leaf ribbon","Honey bow","Lilac scarf","Star crown","Sky ribbon",
		"Golden Tiara", "Wizard Star Hat", "Detective Cap", "Sakura Crown",
		"Dapper Bowtie", "Cosmic Halo", "Winter Beanie", "Velvet Cape"
	]
	for i in range(acc_names.size()):
		out.append({"id":"accessory_%d" % i,"name":acc_names[i],"slot":"accessory","cost":40+i*5,"color":["eab29b","9eae8b","e3c17f","bcaacb"][i%4]})
	return out

func treats_catalog() -> Array:
	return [
		{"id": "treat_honeycomb", "name": "Golden Honeycomb", "icon": "🍯", "cost": 25, "desc": "Sweet mountain honey. +25 Happiness, +20 Hunger."},
		{"id": "treat_starberry", "name": "Starberry Tart", "icon": "🥧", "cost": 35, "desc": "Baked with starlight. Restores Hunger to 100% and +2 Friendship!"},
		{"id": "treat_macaron", "name": "Sparkle Macaron Box", "icon": "🧁", "cost": 45, "desc": "Glittering pastries. +35 Happiness, +25 Cleanliness!"},
		{"id": "treat_cotton_candy", "name": "Sweet Cloud Sugar", "icon": "☁️", "cost": 30, "desc": "Light, fluffy sweetness. +40 Happiness and joyful dance!"},
		{"id": "treat_elixir", "name": "Herbal Vitality Elixir", "icon": "🧪", "cost": 40, "desc": "Soothes sniffles instantly, restores 100% Cleanliness & Energy!"},
		{"id": "treat_parfait", "name": "Rainbow Fruit Parfait", "icon": "🍨", "cost": 60, "desc": "Decadent feast. Restores Hunger, Happiness, and Energy to 100%!"}
	]

func toys_catalog() -> Array:
	return [
		{"id": "toy_mouse", "name": "Clockwork Mouse", "icon": "🐭", "cost": 55, "desc": "Scurrying wind-up toy for lively room play!"},
		{"id": "toy_bell", "name": "Golden Bell Rattle", "icon": "🔔", "cost": 45, "desc": "Playful jingling toy for smiles and bonding."},
		{"id": "toy_pipe", "name": "Enchanted Bubble Wand", "icon": "🫧", "cost": 65, "desc": "Blowing pastel floating bubbles around the room!"},
		{"id": "toy_musicbox", "name": "Campfire Music Box", "icon": "📻", "cost": 95, "desc": "Plays peaceful melodies to comfort your companion."},
		{"id": "toy_projector", "name": "Starry Nebula Projector", "icon": "🌌", "cost": 110, "desc": "Cosmic ceiling projection for enchanting cozy evenings."}
	]

func buy_treat(treat_id: String) -> bool:
	var treat: Dictionary = {}
	for t in treats_catalog():
		if t.id == treat_id:
			treat = t
			break
	if treat.is_empty() or data.coins < treat.cost or data.pet.is_empty():
		return false
	data.coins -= treat.cost
	match treat_id:
		"treat_honeycomb":
			data.pet.happiness = minf(100.0, data.pet.happiness + 25.0)
			data.pet.hunger = minf(100.0, data.pet.hunger + 20.0)
		"treat_starberry":
			data.pet.hunger = 100.0
			data.pet.bond += 2
			data.lifetime_bond += 2
		"treat_macaron":
			data.pet.happiness = minf(100.0, data.pet.happiness + 35.0)
			data.pet.cleanliness = minf(100.0, data.pet.cleanliness + 25.0)
		"treat_cotton_candy":
			data.pet.happiness = minf(100.0, data.pet.happiness + 40.0)
		"treat_elixir":
			data.pet.ill = false
			data.pet.cleanliness = 100.0
			data.pet.energy = 100.0
		"treat_parfait":
			data.pet.hunger = 100.0
			data.pet.happiness = 100.0
			data.pet.energy = 100.0
			data.pet.bond += 3
			data.lifetime_bond += 3
	activity("care")
	save()
	notice.emit("Delightful treat! %s loved the %s!" % [data.pet.name, treat.name])
	return true

func buy_toy(toy_id: String) -> bool:
	var toy: Dictionary = {}
	for t in toys_catalog():
		if t.id == toy_id:
			toy = t
			break
	if toy.is_empty(): return false
	var is_first_purchase: bool = toy_id not in data.inventory
	if is_first_purchase:
		if data.coins < toy.cost: return false
		data.coins -= toy.cost
		data.inventory.append(toy_id)
	data.room["toy"] = toy_id
	if is_first_purchase and not data.pet.is_empty():
		data.pet.happiness = minf(100.0, data.pet.happiness + 15.0)
		data.pet.bond += 2
		data.lifetime_bond += 2
		activity("play")
	save()
	if is_first_purchase:
		notice.emit("New toy placed in the room: %s!" % toy.name)
	else:
		notice.emit("Equipped %s in the room!" % toy.name)
	return true

func open_mystery_box(tier: String, is_free_ad := false) -> Dictionary:
	if not is_free_ad:
		var cost := 40 if tier == "lucky" else 140
		if data.coins < cost: return {"ok": false, "message": "Not enough petals."}
		data.coins -= cost
	var prize := {}
	if tier == "lucky":
		var roll := randi() % 100
		if roll < 40:
			var petals := randi_range(50, 90)
			data.coins += petals
			prize = {"type": "petals", "amount": petals, "text": "+%d Petals!" % petals, "icon": "🌸"}
		elif roll < 70:
			var treats := ["treat_honeycomb", "treat_starberry", "treat_cotton_candy"]
			var t_id: String = treats[randi() % treats.size()]
			for t in treats_catalog():
				if t.id == t_id:
					prize = {"type": "treat", "id": t_id, "text": "A fresh " + t.name + "!", "icon": t.icon}
					if not data.pet.is_empty(): data.pet.happiness = minf(100.0, data.pet.happiness + 20.0)
					break
		elif roll < 85:
			var petals := randi_range(100, 150)
			data.coins += petals
			prize = {"type": "petals", "amount": petals, "text": "🎉 JACKPOT! +%d Petals!" % petals, "icon": "✨"}
		else:
			var unowned := []
			for acc in catalog():
				if acc.id not in data.inventory: unowned.append(acc)
			if not unowned.is_empty():
				var won: Dictionary = unowned[randi() % unowned.size()]
				data.inventory.append(won.id)
				prize = {"type": "item", "id": won.id, "text": "Unlocked " + won.name + "!", "icon": "🎀"}
			else:
				data.coins += 100
				prize = {"type": "petals", "amount": 100, "text": "Bonus +100 Petals!", "icon": "🌸"}
	else:
		# Royal Golden Trunk
		var roll := randi() % 100
		if roll < 50:
			var petals := randi_range(200, 350)
			data.coins += petals
			prize = {"type": "petals", "amount": petals, "text": "Royal Treasury! +%d Petals!" % petals, "icon": "👑"}
		else:
			var unowned := []
			for item in catalog():
				if item.id not in data.inventory: unowned.append(item)
			if not unowned.is_empty():
				var won: Dictionary = unowned[randi() % unowned.size()]
				data.inventory.append(won.id)
				prize = {"type": "item", "id": won.id, "text": "Royal Treasure! Unlocked " + won.name + "!", "icon": "🎁"}
			else:
				data.coins += 300
				prize = {"type": "petals", "amount": 300, "text": "Royal Blessing! +300 Petals!", "icon": "👑"}
	save()
	return {"ok": true, "prize": prize}

func claim_rewarded_ad(reward_type: String) -> void:
	match reward_type:
		"mystery_box":
			var res := open_mystery_box("lucky", true)
			if res.get("ok", false):
				var p: Dictionary = res.get("prize", {})
				notice.emit("🎁 Lucky Mystery Box! " + p.get("text", "+35 Petals"))
		"double_game":
			if last_game_reward > 0:
				data.coins += last_game_reward
				notice.emit("🎬 Double Rewards! Added +%d extra petals!" % last_game_reward)
				last_game_reward = 0
			else:
				data.coins += 35
				notice.emit("🎬 Sponsor Bonus! +35 Petals added!")
		"spa":
			if not data.pet.is_empty():
				data.pet.hunger = 100.0
				data.pet.happiness = 100.0
				data.pet.cleanliness = 100.0
				data.pet.energy = 100.0
				data.pet.ill = false
				data.coins += 15
				notice.emit("🫧 Super Vitality Spa! %s is fully restored & joyful!" % data.pet.name)
		_:
			data.coins += 35
			notice.emit("🌸 Sponsor Bonus! +35 Petals added to your pouch!")
	save()

func buy_equip(item: Dictionary) -> bool:
	if item.id not in data.inventory:
		if data.coins < item.cost: return false
		data.coins -= item.cost
		data.inventory.append(item.id)
	if item.slot == "accessory": data.accessory = item.id
	else: data.room[item.slot] = item.id
	save()
	return true

func retire() -> bool:
	if data.pet.is_empty() or data.pet.stage != "adult": return false
	data.sanctuary.append(data.pet.duplicate(true))
	memory("A home in the sanctuary", "%s will always be part of your family." % data.pet.name)
	data.pet = {}
	save()
	return true

func is_cozy_pass_active() -> bool:
	return "kin_cozy_pass" in data.get("entitlements", [])

func grant_purchase(product_id: String, token: String = "") -> String:
	if not token.is_empty():
		var claim_id := "purchase:" + token
		var claims: Array = data.get("claims", [])
		if claim_id in claims:
			return "Already credited!"
		claims.append(claim_id)
		data.claims = claims

	match product_id:
		"kin_petals_small":
			data.coins += 250
			save(true)
			notice.emit("🌸 Handful of Petals! +250 Petals added.")
			return "Added 250 petals to your pouch!"
		"kin_petals_medium":
			data.coins += 750
			save(true)
			notice.emit("🧺 Basket of Petals! +750 Petals added.")
			return "Added 750 petals to your pouch!"
		"kin_petals_large":
			data.coins += 2000
			save(true)
			notice.emit("✨ Treasure Chest of Petals! +2,000 Petals added.")
			return "Added 2,000 petals to your treasure chest!"
		"kin_treat_basket":
			data.coins += 100
			if not data.pet.is_empty():
				data.pet.hunger = 100.0
				data.pet.energy = 100.0
				var foods: Dictionary = data.pet.get("foods", {})
				for fi in range(6):
					foods[str(fi)] = int(foods.get(str(fi), 0)) + 5
				data.pet.foods = foods
			save(true)
			notice.emit("🍓 Fruit Feast! Treats added & pet energized!")
			return "Fruit Feast delivered! +100 petals and 5 of each fruit!"
		"kin_cozy_pass":
			var entitlements: Array = data.get("entitlements", [])
			var is_new: bool = "kin_cozy_pass" not in entitlements
			if is_new:
				entitlements.append("kin_cozy_pass")
				data.entitlements = entitlements
				data.coins += 150
			save(true)
			notice.emit("👑 Cozy Caretaker Pass! Interstitial ads disabled & perks active!")
			return "Cozy Caretaker Pass active! Enjoy ad-free care and bonus rewards!"
		"kin_cottage", "kin_moonlight", "kin_blossom":
			var entitlements: Array = data.get("entitlements", [])
			if product_id not in entitlements:
				entitlements.append(product_id)
				data.entitlements = entitlements
			data.premium_equipped = product_id
			save(true)
			notice.emit("🏡 Storybook Collection unlocked! Decorated your sanctuary.")
			return "Collection unlocked and equipped!"
		_:
			var entitlements: Array = data.get("entitlements", [])
			if product_id not in entitlements:
				entitlements.append(product_id)
				data.entitlements = entitlements
			save(true)
			return "Item unlocked!"

func steps(total: int, date: String, source: String) -> void:
	if not data.walking.enabled or total < 0: return
	var now := Time.get_unix_time_from_system()
	var yesterday := Time.get_date_string_from_unix_time(int(now + data.settings.utc_offset - 86400))
	if date not in [day_key(), yesterday]: return
	if date == day_key():
		data.walking.steps = total
		data.walking.updated = now
		data.walking.source = source
		data.walking.status = "Steps connected"
	for threshold in [500, 1500, 3000]:
		var id := "walk:" + date + ":" + str(threshold)
		if total >= threshold and id not in data.claims:
			data.claims.append(id)
			var petal_reward := 25 if is_cozy_pass_active() else 15
			data.coins += petal_reward
			if not data.pet.is_empty():
				data.pet.happiness = minf(100, data.pet.happiness + 5)
				data.pet.bond += 2
				data.lifetime_bond += 2
			notice.emit("A walking parcel! +%d petals and a little more friendship." % petal_reward)
	save()

func watch_health(payload: Dictionary) -> void:
	if not payload is Dictionary: return
	var steps_val: int = int(payload.get("steps", 0))
	var hr: int = int(payload.get("heart_rate", 0))
	var hydration: int = int(payload.get("hydration", 0))
	var active_min: int = int(payload.get("active_minutes", 0))
	var cals: int = int(payload.get("calories", 0))

	if not data.walking.has("watch"): data.walking.watch = {}
	data.walking.watch = {
		"steps": steps_val,
		"heart_rate": hr,
		"hydration": hydration,
		"active_minutes": active_min,
		"calories": cals,
		"synced": Time.get_unix_time_from_system()
	}

	if steps_val > int(data.walking.get("steps", 0)):
		data.walking.enabled = true
		steps(steps_val, day_key(), "watch")

	if hr in range(60, 83) and not data.pet.is_empty():
		var claim_id := "hr_serene:" + day_key()
		if claim_id not in data.claims:
			data.claims.append(claim_id)
			data.pet.happiness = minf(100, data.pet.happiness + 10)
			data.pet.bond += 3
			data.lifetime_bond += 3
			data.coins += 10
			memory("Heartbeat Harmony", "%s felt your calm heartbeat and curled up beside you." % data.pet.name)
			notice.emit("Heartbeat Harmony! Your calm pulse gave %s peace (+10 petals)." % data.pet.name)

	if hydration >= 3 and not data.pet.is_empty():
		var claim_id := "hydration:" + day_key()
		if claim_id not in data.claims:
			data.claims.append(claim_id)
			data.pet.cleanliness = minf(100, data.pet.cleanliness + 15)
			data.pet.energy = minf(100, data.pet.energy + 10)
			memory("Fresh and hydrated", "%s enjoyed fresh water along with you." % data.pet.name)
			notice.emit("Hydration shared! %s feels refreshed and glowing." % data.pet.name)

	save(false)
	changed.emit()

func pet_stroke() -> void:
	if data.pet.is_empty(): return
	data.pet.happiness = minf(100, data.pet.happiness + 6)
	data.pet.bond += 1
	data.lifetime_bond += 1
	var count: int = int(data.pet.get("stroke_count", 0)) + 1
	data.pet.stroke_count = count
	if count == 15:
		memory("Sweet cuddles", "%s loves being gently stroked and purred softly." % data.pet.name)
		data.coins += 10
		notice.emit("Warm cuddles! +10 petals from %s." % data.pet.name)
	save(true)
	changed.emit()

func pop_bath_bubble() -> bool:
	if data.pet.is_empty(): return false
	data.pet.cleanliness = minf(100, data.pet.cleanliness + 6)
	data.pet.happiness = minf(100, data.pet.happiness + 2)
	if data.pet.cleanliness >= 100 and not data.pet.get("bath_memory", false):
		data.pet.bath_memory = true
		memory("Bubble bath fun", "%s splashed joyfully and is squeaky clean!" % data.pet.name)
		data.coins += 15
		notice.emit("Squeaky clean! +15 petals.")
	save(true)
	changed.emit()
	return true

func toss_fruit(index: int) -> bool:
	if index < 0 or index > 5 or not care("feed"): return false
	data.pet.happiness = minf(100, data.pet.happiness + 8)
	var foods: Dictionary = data.pet.get("foods", {})
	foods[str(index)] = int(foods.get(str(index), 0)) + 1
	data.pet.foods = foods
	save()
	return true

func cloud_snapshot() -> Dictionary:
	var snapshot := data.duplicate(true)
	snapshot.erase("walking")
	snapshot.erase("entitlements")
	snapshot.erase("watch_receipts")
	snapshot.settings.erase("utc_offset")
	return snapshot

const STASH = "user://pocket-kin.cloud.json"

## Applies a Firestore snapshot. Newer revisions replace local state (local
## walking + tz stay on-device); anything else is stashed for an explicit
## player choice - never silently merged, never auto-overwriting local play.
func normalize_cloud(incoming: Dictionary) -> Dictionary:
	# Cloud snapshots deliberately exclude local-only walking + tz offset
	# (privacy), so restore those slots before validation.
	var copy: Dictionary = incoming.duplicate(true)
	if not copy.get("walking") is Dictionary:
		copy.walking = fresh().walking
	if copy.get("settings") is Dictionary and not copy.settings.has("utc_offset"):
		copy.settings.utc_offset = int(data.settings.get("utc_offset", 0))
	return copy

func apply_cloud_snapshot(incoming: Dictionary) -> String:
	if not incoming is Dictionary:
		return "rejected"
	var candidate := normalize_cloud(incoming)
	if not valid_save(candidate):
		return "rejected"
	var incoming_rev := int(candidate.get("revision", 0))
	if incoming_rev > int(data.get("cloud_revision", 0)) and int(data.revision) <= int(data.get("sync_local_revision",0)):
		var walking: Dictionary = data.walking.duplicate(true)
		var entitlements: Array = data.get("entitlements",[])
		var offset: int = int(data.settings.get("utc_offset", 0))
		data = candidate
		data.walking = walking
		data.entitlements = entitlements
		data.sync_local_revision = data.revision
		data.settings.utc_offset = offset
		data.cloud_revision = incoming_rev
		if FileAccess.file_exists(STASH):
			DirAccess.remove_absolute(STASH)
		save(false)
		return "applied"
	stash_cloud(candidate)
	return "kept-local"

func stash_cloud(candidate: Dictionary) -> void:
	var file := FileAccess.open(STASH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(candidate))
		file.close()

func has_cloud_conflict() -> bool:
	return FileAccess.file_exists(STASH)

func resolve_cloud_conflict(use_cloud: bool) -> String:
	if not has_cloud_conflict():
		return "rejected"
	if not use_cloud:
		var remote = JSON.parse_string(FileAccess.get_file_as_string(STASH))
		if remote is Dictionary:
			data.cloud_revision = maxi(int(data.get("cloud_revision",0)),int(remote.get("revision",0)))
			save(false)
		DirAccess.remove_absolute(STASH)
		return "kept-local"
	var incoming = JSON.parse_string(FileAccess.get_file_as_string(STASH))
	if not incoming is Dictionary:
		return "rejected"
	var candidate := normalize_cloud(incoming)
	if not valid_save(candidate):
		return "rejected"
	var walking: Dictionary = data.walking.duplicate(true)
	var entitlements: Array = data.get("entitlements",[])
	var backup := FileAccess.open("user://pocket-kin.before-cloud.json",FileAccess.WRITE)
	if backup:
		backup.store_string(JSON.stringify(data))
		backup.close()
	var offset: int = int(data.settings.get("utc_offset", 0))
	data = candidate
	data.walking = walking
	data.entitlements = entitlements
	data.sync_local_revision = data.revision
	data.settings.utc_offset = offset
	data.cloud_revision = maxi(int(data.get("cloud_revision", 0)), int(candidate.get("revision", 0)))
	DirAccess.remove_absolute(STASH)
	save(false)
	return "applied"

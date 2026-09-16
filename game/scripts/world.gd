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

func task_progress(kind: String) -> int:
	return int(data.daily.get(day_key(), {}).get(kind, 0))

func claim_task(kind: String, required: int) -> bool:
	var id := "task:" + day_key() + ":" + kind
	if id in data.claims or task_progress(kind) < required: return false
	data.claims.append(id)
	data.coins += 25
	save()
	return true

func game_reward(kind: String, score: int) -> int:
	if data.pet.is_empty(): return 0
	var reward := clampi(5 + score / 3, 5, 30)
	data.coins += reward
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
	for i in range(12):
		out.append({"id":"accessory_%d" % i,"name":["Peach bow","Sage scarf","Sun crown","Moon ribbon","Berry bow","Cloud scarf","Daisy crown","Leaf ribbon","Honey bow","Lilac scarf","Star crown","Sky ribbon"][i],"slot":"accessory","cost":40+i*5,"color":["eab29b","9eae8b","e3c17f","bcaacb"][i%4]})
	return out

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
			data.coins += 15
			if not data.pet.is_empty():
				data.pet.happiness = minf(100, data.pet.happiness + 5)
				data.pet.bond += 2
				data.lifetime_bond += 2
			notice.emit("A walking parcel! +15 petals and a little more friendship.")
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

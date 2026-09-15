extends SceneTree
## World/persistence/economy regression tests (steps 03-06).
## Uses a detached World instance; the real user save file is backed up first.
const WorldScript = preload("res://scripts/world.gd")
const SimScript = preload("res://scripts/simulation.gd")
var failures := 0
var backup := ""

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("world_test: " + message)
		failures += 1

func _init() -> void:
	for path in ["user://pocket-kin.json", "user://pocket-kin.json.bak", "user://pocket-kin.json.tmp"]:
		if FileAccess.file_exists(path):
			backup += path + "|" + FileAccess.get_file_as_string(path) + "\n%%\n"
	var w = WorldScript.new()
	w.data = w.fresh()

	# Save validation.
	check(w.valid_save(w.data), "fresh data validates")
	check(not w.valid_save({"schema": 2}), "wrong schema rejected")
	check(not w.valid_save({"schema": 1}), "missing fields rejected")

	# Adoption rules.
	w.adopt(3, "Testy")
	check(w.data.pet.is_empty(), "locked species cannot be adopted early")
	w.adopt(0, "  Mochi Jr  ")
	check(w.data.pet.name == "Mochi Jr", "adoption trims name")
	w.adopt(1, "Second")
	check(w.data.pet.name == "Mochi Jr", "second adoption blocked while pet active")

	# Care + cooldown.
	var hunger_before: float = w.data.pet.hunger
	w.data.pet.hunger = 40.0
	check(w.care("feed"), "feeding works")
	check(w.data.pet.hunger > 40.0, "feeding raises hunger")
	check(not w.care("feed"), "instant repeat care blocked by cooldown")
	check(not w.care("dance"), "unknown action rejected")
	w.data.pet.hunger = hunger_before

	# Daily tasks pay exactly once.
	w.data.daily = {w.day_key(): {"care": 3}}
	check(w.claim_task("care", 3), "completed task can be claimed")
	var coins_after_task: int = w.data.coins
	check(not w.claim_task("care", 3), "task cannot be claimed twice")
	check(w.data.coins == coins_after_task, "no double pay on task reclaim")

	# Mini-game rewards are bounded and recorded.
	var c0: int = w.data.coins
	var r0: int = w.game_reward("catch", 0)
	check(r0 == 5, "minimum game reward is 5")
	check(w.game_reward("catch", 120) == 30, "game reward capped at 30")
	check(int(w.data.bests["catch"]) == 120, "personal best persists")
	check(w.data.coins == c0 + 5 + 30, "game rewards paid in coins")

	# Exploration: locks, discoveries persist without duplicates.
	check(w.explore(1, 0) == "Grow your friendship to unlock this place.", "woods locked at bond 0")
	check(w.explore(9, 0) == "Grow your friendship to unlock this place.", "invalid destination safely locked")
	w.data.lifetime_bond = 25
	var found: String = w.explore(1, 1)
	check(found == "Fern print", "exploration returns deterministic discovery")
	check(w.data.discoveries.count(found) == 1, "discovery recorded")
	w.explore(1, 1)
	check(w.data.discoveries.count(found) == 1, "repeat discovery not duplicated")

	# Shop: no negative coins, ownership persists, equip works.
	w.data.coins = 0
	var item: Dictionary = w.catalog()[0]
	check(not w.buy_equip(item), "purchase blocked without coins")
	check(w.data.coins == 0, "coins never go negative")
	w.data.coins = 500
	check(w.buy_equip(item), "purchase works with coins")
	check(item.id in w.data.inventory, "owned item persists in inventory")
	check(w.data.room[item.slot] == item.id, "decor equips into room slot")
	var accessory: Dictionary = w.catalog()[30]
	check(w.buy_equip(accessory), "accessory purchase works")
	check(w.data.accessory == accessory.id, "accessory equips on pet")

	# Sanctuary: adults only, identity retained.
	check(not w.retire(), "baby cannot be retired")
	w.data.pet.stage = "adult"
	check(w.retire(), "adult can settle in sanctuary")
	check(w.data.pet.is_empty() and w.data.sanctuary.size() == 1, "sanctuary holds retired pet")
	check(w.data.sanctuary[0].name == "Mochi Jr", "sanctuary retains identity")

	# Walking: opt-in, thresholds, no duplicate claims, bad input ignored.
	w.data.pet = {"id": "t", "name": "T", "species": 0, "hunger": 50.0, "happiness": 50.0, "cleanliness": 50.0, "energy": 50.0, "updated": Time.get_unix_time_from_system(), "care_age": 0.0, "bond": 0}
	w.steps(5000, w.day_key(), "test")
	check(w.data.walking.steps == 0, "steps ignored before opt-in")
	w.data.walking.enabled = true
	var cw: int = w.data.coins
	w.steps(600, w.day_key(), "health-connect")
	check(w.data.walking.steps == 600, "today steps recorded")
	check("walk:" + w.day_key() + ":500" in w.data.claims, "500 milestone claimed")
	check(w.data.coins == cw + 15, "milestone pays 15 once")
	w.steps(600, w.day_key(), "health-connect")
	check(w.data.coins == cw + 15, "same total never pays twice")
	w.steps(-40, w.day_key(), "health-connect")
	w.steps(5000, "2099-01-01", "health-connect")
	check(w.data.coins == cw + 15, "negative and far-future totals ignored")
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system() + w.data.settings.utc_offset - 86400))
	w.steps(1600, yesterday, "health-connect")
	check("walk:" + yesterday + ":500" in w.data.claims and "walk:" + yesterday + ":1500" in w.data.claims, "late yesterday sync claims both milestones")

	# Cloud snapshot keeps raw steps and tz offset local-only.
	var snap: Dictionary = w.cloud_snapshot()
	check(not snap.has("walking"), "raw steps excluded from cloud snapshot")
	check(not snap.settings.has("utc_offset"), "tz offset excluded from cloud snapshot")
	check(snap.revision == w.data.revision, "snapshot carries revision for CAS")

	# Growth: steady care crosses juvenile (~2d) and adult (~7d); absence alone cannot.
	var noon := 1725688800.0 # a fixed midday; Sim clock is fully injectable.
	var pup := {"hunger": 100.0, "happiness": 100.0, "cleanliness": 100.0, "energy": 100.0, "care_age": 1.9 * 86400.0, "updated": noon, "sleeping": false, "ill": false, "bond": 0, "stage": "baby"}
	SimScript.reconcile(pup, noon + 0.2 * 86400.0, {"sleep_hour": 22, "wake_hour": 7, "utc_offset": 0})
	check(pup.stage == "juvenile", "steady care reaches juvenile near day two")
	pup.care_age = 6.9 * 86400.0
	pup.hunger = 100.0
	pup.updated = noon
	pup.stage = "juvenile"
	SimScript.reconcile(pup, noon + 0.2 * 86400.0, {"sleep_hour": 22, "wake_hour": 7, "utc_offset": 0})
	check(pup.stage == "adult", "steady care reaches adult near day seven")
	var stray := {"hunger": 100.0, "happiness": 100.0, "cleanliness": 100.0, "energy": 100.0, "care_age": 0.0, "updated": noon, "sleeping": false, "ill": false, "bond": 0, "stage": "baby"}
	SimScript.reconcile(stray, noon + 2.2 * 86400.0, {"sleep_hour": 22, "wake_hour": 7, "utc_offset": 0})
	check(stray.stage == "baby", "one long absence without feeding cannot rush growth")

	# Cloud conflicts: newer applies (walking stays local), older stashes, garbage rejected.
	w.data.coins = 111
	w.data.cloud_revision = 5
	w.data.walking.enabled = true
	w.data.walking.steps = 4321
	var newer := w.cloud_snapshot()
	newer.revision = 9
	newer.coins = 777
	w.data.sync_local_revision = w.data.revision
	check(w.apply_cloud_snapshot(newer) == "applied", "newer cloud snapshot applies")
	check(w.data.coins == 777, "applied snapshot content wins")
	check(w.data.walking.steps == 4321, "local walking survives cloud apply")
	check(w.data.cloud_revision == 9, "cloud revision advances")
	var older := w.cloud_snapshot()
	older.revision = 4
	older.coins = 5
	check(w.apply_cloud_snapshot(older) == "kept-local", "older snapshot never overwrites")
	check(w.data.coins == 777, "local state untouched by older snapshot")
	check(w.has_cloud_conflict(), "divergent snapshot stashed for player choice")
	check(w.resolve_cloud_conflict(false) == "kept-local", "player can keep local pet")
	check(not w.has_cloud_conflict(), "dismissed conflict clears stash")
	check(w.apply_cloud_snapshot(older) == "kept-local", "conflict stashed again")
	check(w.resolve_cloud_conflict(true) == "applied", "player can choose cloud copy")
	check(w.data.coins == 5 and not w.has_cloud_conflict(), "chosen cloud copy takes effect")
	check(w.apply_cloud_snapshot({"nope": true}) == "rejected", "garbage snapshot rejected")
	# Local play cannot be overwritten merely because another device uploaded.
	w.data.revision += 2
	var divergent := w.cloud_snapshot()
	divergent.revision = w.data.cloud_revision + 10
	check(w.apply_cloud_snapshot(divergent) == "kept-local", "newer remote still prompts when local is dirty")
	w.resolve_cloud_conflict(false)

	# Save round-trips through disk.
	w.save()
	check(FileAccess.file_exists("user://pocket-kin.json"), "save file written")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://pocket-kin.json"))
	check(w.valid_save(parsed), "saved file validates on reload")

	w.free()
	# Restore any pre-existing user save.
	for path in ["user://pocket-kin.json", "user://pocket-kin.json.bak", "user://pocket-kin.json.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if not backup.is_empty():
		for chunk in backup.split("\n%%\n"):
			if chunk.is_empty():
				continue
			var split_at := chunk.find("|")
			var file := FileAccess.open(chunk.left(split_at), FileAccess.WRITE)
			file.store_string(chunk.substr(split_at + 1))
			file.close()
	print("World tests: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)

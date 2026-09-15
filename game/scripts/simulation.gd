class_name PetSimulation
extends RefCounted

const NEEDS = ["hunger", "happiness", "cleanliness", "energy"]
const DAY = 86400.0

static func awake_seconds(start: float, finish: float, sleep_hour: int, wake_hour: int, offset: int) -> float:
	if finish <= start:
		return 0.0
	var awake := 0.0
	var cursor := start
	# Integrate partial hours, then whole days, so long absences remain bounded.
	var duration := finish - start
	var full_days := int(duration / DAY)
	var sleep_hours := posmod(wake_hour - sleep_hour, 24)
	if full_days > 0:
		awake += full_days * (24 - sleep_hours) * 3600.0
		cursor += full_days * DAY
	while cursor < finish:
		var local := cursor + offset
		var hour := posmod(int(floor(local / 3600.0)), 24)
		var next := minf(finish, cursor + 3600.0 - fposmod(local, 3600.0))
		var asleep := false
		if sleep_hour > wake_hour:
			asleep = hour >= sleep_hour or hour < wake_hour
		elif sleep_hour < wake_hour:
			asleep = hour >= sleep_hour and hour < wake_hour
		if not asleep:
			awake += next - cursor
		cursor = next
	return awake

static func reconcile(pet: Dictionary, now: float, settings: Dictionary) -> void:
	var then := float(pet.get("updated", now))
	if now <= then:
		return
	var elapsed := now - then
	var hours := awake_seconds(then, now, int(settings.sleep_hour), int(settings.wake_hour), int(settings.get("utc_offset", 0))) / 3600.0
	var healthy_hours := maxf(0, minf(hours, (float(pet.hunger) - 20) / 8.0))
	var safe_hours := maxf(0,minf((float(pet.hunger)-10)/8.0,(float(pet.cleanliness)-10)/4.0))
	var neglected := maxf(0,hours-safe_hours)
	pet.neglect_hours = float(pet.get("neglect_hours",0)) + neglected if neglected>0 else 0.0
	pet.care_age = float(pet.get("care_age", 0)) + minf(elapsed, healthy_hours * 3600 + (elapsed - hours * 3600))
	pet.hunger = clampf(float(pet.hunger) - hours * 8.0, 0, 100)
	pet.happiness = clampf(float(pet.happiness) - hours * 5.0, 0, 100)
	pet.cleanliness = clampf(float(pet.cleanliness) - hours * 4.0, 0, 100)
	if pet.get("sleeping", false):
		pet.energy = clampf(float(pet.energy) + elapsed / 3600.0 * 18, 0, 100)
	else:
		pet.energy = clampf(float(pet.energy) - hours * 6 + (elapsed / 3600.0 - hours) * 15, 0, 100)
	if pet.neglect_hours >= 4:
		pet.ill = true
	pet.updated = now
	pet.stage = "adult" if pet.care_age >= 7 * DAY else ("juvenile" if pet.care_age >= 2 * DAY else "baby")

static func care(pet: Dictionary, action: String, now: float) -> bool:
	var last: Dictionary = pet.get("last_actions", {})
	if now - float(last.get(action, 0)) < 3:
		return false
	match action:
		"feed": pet.hunger = minf(100, pet.hunger + 28)
		"love": pet.happiness = minf(100, pet.happiness + 20)
		"clean": pet.cleanliness = minf(100, pet.cleanliness + 40)
		"sleep": pet.sleeping = not pet.get("sleeping", false)
		"treat":
			pet.ill = false
			pet.neglect_hours = 0.0
		_: return false
	pet.bond = int(pet.get("bond", 0)) + 1
	last[action] = now
	pet.last_actions = last
	return true

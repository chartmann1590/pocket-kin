extends Node
signal result(kind: String, payload: Dictionary)
var native: Object
var status := "Local save • cloud not connected"

func _ready() -> void:
	if Engine.has_singleton("PocketKin"):
		native = Engine.get_singleton("PocketKin")
		# Activity and Data Layer callbacks may arrive while rendering is paused.
		# Apply scene changes on Godot's next main-loop frame.
		native.connect("result", _result, CONNECT_DEFERRED)
	World.changed.connect(_publish)

func call_service(kind: String, payload: Dictionary = {}) -> void:
	if native:
		native.request(kind, JSON.stringify(payload))
	else:
		result.emit(kind, {"ok":false,"message":"Available in the Android app. Your local game is saved."})

func _publish() -> void:
	if native:
		native.request("snapshot", JSON.stringify({"revision":World.data.revision,"pet":World.data.pet,"walking":World.data.walking,"settings":World.data.settings,"save_path":ProjectSettings.globalize_path(World.SAVE)}))

func _result(kind: String, raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary: return
	if kind == "steps" and parsed.get("ok", false):
		World.steps(int(parsed.steps), parsed.date, parsed.source)
	elif kind == "steps" and parsed.get("permission_required",false):
		call_service("steps_permission",{"activated":World.data.walking.activated})
	elif kind == "external_save" and World.valid_save(parsed.get("save")):
		World.data = parsed.save
		World.reconcile()
	elif kind == "watch_action":
		var ok := World.watch_action(parsed)
		call_service("watch_ack", {"id":parsed.get("id", ""),"ok":ok,"revision":World.data.revision})
	elif kind == "watch_health":
		World.watch_health(parsed)
	elif kind == "rewarded" and parsed.get("earned", false):
		var id := "ad:" + str(parsed.get("id", ""))
		if id not in World.data.claims:
			World.data.claims.append(id)
			World.data.coins += 20
			World.data.ad.last = Time.get_unix_time_from_system()
			World.save()
	elif kind == "purchase":
		# Entitlements are server-owned: the client never unlocks bundles from
		# a store callback. Verified purchases arrive via the cloud snapshot.
		if parsed.get("verified", false):
			call_service("cloud_load")
			result.emit(kind, {"ok": true, "message": "Purchase verified. Syncing your collection."})
			return
		result.emit(kind, parsed)
		return
	elif kind == "restore":
		if parsed.get("verified", false):
			call_service("cloud_load")
			result.emit(kind, {"ok": true, "message": "Purchases restored. Syncing your collection."})
			return
		result.emit(kind, parsed)
		return
	result.emit(kind, parsed)

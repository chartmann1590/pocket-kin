extends Node
signal result(kind: String, payload: Dictionary)
var native: Object
var status := "Local save • cloud not connected"

var product_prices := {}

func _ready() -> void:
	if Engine.has_singleton("PocketKin"):
		native = Engine.get_singleton("PocketKin")
		# Activity and Data Layer callbacks may arrive while rendering is paused.
		# Apply scene changes on Godot's next main-loop frame.
		native.connect("result", _result, CONNECT_DEFERRED)
		call_service("query_products")
	World.changed.connect(_publish)

func call_service(kind: String, payload: Dictionary = {}) -> void:
	if native:
		native.request(kind, JSON.stringify(payload))
	else:
		if kind == "rewarded":
			var r_type: String = str(payload.get("reward_type", "general"))
			_result("rewarded", JSON.stringify({"earned": true, "id": "mock-" + str(randi()), "reward_type": r_type, "message": "Reward claimed!"}))
		elif kind == "interstitial":
			_result("interstitial", JSON.stringify({"shown": true}))
		result.emit(kind, {"ok":false,"message":"Available in the Android app. Your local game is saved."})

func _publish() -> void:
	if native:
		native.request("snapshot", JSON.stringify({
			"revision": World.data.revision,
			"pet": World.data.pet,
			"walking": World.data.walking,
			"settings": World.data.settings,
			"entitlements": World.data.get("entitlements", []),
			"coins": World.data.coins,
			"save_path": ProjectSettings.globalize_path(World.SAVE)
		}))

func _result(kind: String, raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary: return
	if kind == "products_details" and parsed.get("ok", false):
		product_prices = parsed.get("products", {})
		result.emit(kind, parsed)
	elif kind == "steps" and parsed.get("ok", false):
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
			var r_type: String = str(parsed.get("reward_type", "general"))
			World.claim_rewarded_ad(r_type)
			World.data.ad.last = Time.get_unix_time_from_system()
			World.save()
		result.emit(kind, parsed)
	elif kind == "purchase":
		if parsed.get("verified", false) or parsed.get("ok", false):
			var prod_id: String = str(parsed.get("product", ""))
			var token: String = str(parsed.get("purchase_token", ""))
			if not prod_id.is_empty():
				var grant_msg := World.grant_purchase(prod_id, token)
				_publish()
				if not token.is_empty():
					call_service("confirm_grant", {"purchase_token": token, "product": prod_id})
				result.emit(kind, {"ok": true, "product": prod_id, "message": grant_msg})
				return
		result.emit(kind, parsed)
		return
	elif kind == "restore":
		if parsed.get("verified", false) or parsed.get("ok", false):
			var prod_id: String = str(parsed.get("product", ""))
			var token: String = str(parsed.get("purchase_token", ""))
			if not prod_id.is_empty():
				World.grant_purchase(prod_id, token)
				_publish()
				if not token.is_empty():
					call_service("confirm_grant", {"purchase_token": token, "product": prod_id})
				result.emit(kind, {"ok": true, "product": prod_id, "message": "Restored collection!"})
				return
		result.emit(kind, parsed)
		return
	result.emit(kind, parsed)

extends Node
## App-wide on-device translation via Google ML Kit (see TranslationBridge.kt).
##
## Two lookup helpers:
##  - T(key, english): keyed UI strings ("nav.home"). Callers format the result
##    themselves ("... % args"), so cached templates stay placeholder-safe.
##  - t(text): one-off dynamic strings (platform messages, notices, saved text).
##
## ML Kit mangles printf specifiers ("%d" became "% D" on a real device), so
## templates are sent to ML Kit with "{1} {2}" ICU-style tokens instead and the
## originals are restored + validated before caching. Translations whose
## placeholders came back damaged are rejected and that string stays English
## (self-heals later; legacy mangled entries are dropped at read time too).
## Every string shown while a non-English language is active is collected once,
## batch-translated in the background, and cached in the save under data.i18n.
## English (the default) is always rendered verbatim and collects nothing.
##
## The native widget and care notifications read the same cache: platform.gd
## publishes the pairs in the snapshot, and KinServices stores them for
## KinWidget.tr().

signal strings_updated

## Every language ML Kit translation supports (BCP-47 code, native name).
## English first (default), then the most-requested languages, then the rest.
const LANGUAGES := [
	["en", "English"], ["es", "Español"], ["fr", "Français"], ["de", "Deutsch"],
	["pt", "Português"], ["it", "Italiano"], ["ja", "日本語"], ["ko", "한국어"],
	["zh", "中文"], ["ru", "Русский"], ["ar", "العربية"], ["hi", "हिन्दी"],
	["af", "Afrikaans"], ["be", "Беларуская"], ["bg", "Български"], ["bn", "বাংলা"],
	["ca", "Català"], ["cs", "Čeština"], ["cy", "Cymraeg"], ["da", "Dansk"],
	["el", "Ελληνικά"], ["eo", "Esperanto"], ["et", "Eesti"], ["fa", "فارسی"],
	["fi", "Suomi"], ["ga", "Gaeilge"], ["gl", "Galego"], ["gu", "ગુજરાતી"],
	["he", "עברית"], ["hr", "Hrvatski"], ["ht", "Kreyòl ayisyen"], ["hu", "Magyar"],
	["id", "Bahasa Indonesia"], ["is", "Íslenska"], ["ka", "ქართული"], ["kn", "ಕನ್ನಡ"],
	["lt", "Lietuvių"], ["lv", "Latviešu"], ["mk", "Македонски"], ["mr", "मराठी"],
	["ms", "Bahasa Melayu"], ["mt", "Malti"], ["nl", "Nederlands"], ["no", "Norsk"],
	["pl", "Polski"], ["ro", "Română"], ["sk", "Slovenčina"], ["sl", "Slovenščina"],
	["sq", "Shqip"], ["sv", "Svenska"], ["sw", "Kiswahili"], ["ta", "தமிழ்"],
	["te", "తెలుగు"], ["th", "ไทย"], ["tl", "Tagalog"], ["tr", "Türkçe"],
	["uk", "Українська"], ["ur", "اردو"], ["vi", "Tiếng Việt"]
]

const MAX_COLLECT := 240

var collect_pool: Dictionary = {}
var pending_tokens: Dictionary = {}  # tokenized -> original english
var failed: Dictionary = {}
var translating := false
var _platform_ref: Node = null
var _world_ref: Node = null

## Autoloads are resolved dynamically (not at compile time) so headless tests
## can instantiate this script without Platform/World being registered.
func _platform() -> Node:
	if _platform_ref == null or not is_instance_valid(_platform_ref):
		_platform_ref = get_node_or_null("/root/Platform")
	return _platform_ref

func _world() -> Node:
	if _world_ref == null or not is_instance_valid(_world_ref):
		_world_ref = get_node_or_null("/root/World")
	return _world_ref

func _ready() -> void:
	var flush_timer := Timer.new()
	flush_timer.wait_time = 3.0
	flush_timer.timeout.connect(_flush)
	add_child(flush_timer)
	flush_timer.start()
	var platform := _platform()
	if platform: platform.result.connect(_on_platform_result)

func lang() -> String:
	var world := _world()
	if world == null or world.data == null or world.data.is_empty(): return "en"
	return str(world.data.settings.get("lang", "en"))

func active() -> bool:
	return lang() != "en"

func language_name(code: String) -> String:
	for entry in LANGUAGES:
		if entry[0] == code: return str(entry[1])
	return code

func _spec_count(text: String) -> int:
	var re := RegEx.new()
	if re.compile("%[ds]") != OK: return 0
	return re.search_all(text).size()

## Replace printf specifiers with numbered "{n}" tokens ML Kit preserves.
func _tokenize(text: String) -> String:
	var re := RegEx.new()
	if re.compile("%([ds])") != OK: return text
	var matches := re.search_all(text)
	if matches.is_empty(): return text
	var out := ""
	var last := 0
	var index := 0
	for m in matches:
		index += 1
		out += text.substr(last, m.get_start() - last)
		out += "{%d}" % index
		last = m.get_end()
	out += text.substr(last)
	return out

## Restore "{n}" tokens to printf specifiers; reject badly damaged translations
## (missing, duplicated, or out-of-range placeholders). Bare "%" is escaped to
## "%%" so later "template % args" formatting stays safe.
func _restore(english: String, translated: String) -> String:
	var specs := RegEx.new()
	if specs.compile("%([ds])") != OK: return ""
	var found: Array = specs.search_all(english)
	var token_re := RegEx.new()
	if token_re.compile("\\{(\\d+)\\}") != OK: return ""
	var tmatches := token_re.search_all(translated)
	if tmatches.size() != found.size(): return ""
	var used := {}
	var out := ""
	var last := 0
	for m in tmatches:
		var n := int(m.get_string(1))
		if used.has(n) or n < 1 or n > found.size(): return ""
		used[n] = true
		out += translated.substr(last, m.get_start() - last)
		out += found[n - 1].get_string(0)
		last = m.get_end()
	out += translated.substr(last)
	var bare := RegEx.new()
	if bare.compile("%(?![ds%])") == OK:
		out = bare.sub(out, "%%", true)
	return out

## Keyed UI string lookup. Returns English until ML Kit delivers the cache.
func T(key: String, english: String) -> String:
	if not active(): return english
	var world := _world()
	if world == null or world.data == null: return english
	var cache: Dictionary = world.data.get("i18n", {})
	if cache.has(english):
		var translated := str(cache[english])
		# Self-heal legacy entries saved before placeholder protection.
		if _spec_count(english) > 0 and _spec_count(translated) != _spec_count(english):
			cache.erase(english)
			world.data.i18n = cache
		else:
			return translated
	if failed.has(english): return english
	if collect_pool.size() < MAX_COLLECT and not collect_pool.has(english) and english.length() >= 2:
		collect_pool[english] = key
	return english

## One-off string lookup (platform messages, notices, saved text).
func t(text: String) -> String:
	if not active() or text.length() < 2: return text
	return T("", text)

## True while a string is collected but not yet translated; UI can dim it so
## players can tell still-English strings from translated ones.
func is_pending(english: String) -> bool:
	return active() and collect_pool.has(english)

func _flush() -> void:
	var platform := _platform()
	if translating or collect_pool.is_empty() or not active() or platform == null:
		return
	translating = true
	var send: Array = []
	pending_tokens = {}
	for english in collect_pool.keys():
		var tokenized := _tokenize(english)
		pending_tokens[tokenized] = english
		send.append(tokenized)
	platform.call_service("translate_batch", {"lang": lang(), "strings": send})

## Merge a batch of {sent -> translated} into the save-file cache, keyed back
## to the original English strings.
func apply_translations(translations: Dictionary) -> void:
	if translations.is_empty(): return
	var world := _world()
	if world == null or world.data == null: return
	var cache: Dictionary = world.data.get("i18n", {})
	var stored := 0
	for sent in translations:
		var source := str(pending_tokens.get(str(sent), str(sent)))
		var translated := str(translations[sent])
		if _spec_count(source) > 0:
			translated = _restore(source, translated)
			if translated.is_empty():
				failed[source] = true  # damaged by MT; keep English, stop retrying
				continue
		cache[source] = translated
		collect_pool.erase(source)
		stored += 1
	pending_tokens.clear()
	world.data.i18n = cache
	if stored > 0: world.save(false)
	strings_updated.emit()

func reset_for_language(code: String) -> void:
	var world := _world()
	if world == null or world.data == null: return
	world.data.settings.lang = code
	world.data.i18n = {}
	world.data.i18n_lang = code
	collect_pool.clear()
	pending_tokens.clear()
	failed.clear()
	translating = false
	world.save(false)

func _on_platform_result(kind: String, payload: Dictionary) -> void:
	var world := _world()
	if world == null or world.data == null: return
	if kind == "translations":
		translating = false
		if payload.get("ok", false):
			var map: Dictionary = payload.get("map", {})
			if not map.is_empty(): apply_translations(map)
	elif kind == "language_ready":
		var code := str(payload.get("lang", ""))
		if payload.get("ok", false):
			if not world.data.pet.is_empty() or code != "en":
				world.notice.emit(language_name(code) + " " + T("lang.ready", "is ready."))
			call_deferred("_flush")
		else:
			world.notice.emit(str(payload.get("message", T("lang.failed", "Translation download failed. Check your connection and try again."))))

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var platform := _platform()
		if platform: platform.result.disconnect(_on_platform_result)

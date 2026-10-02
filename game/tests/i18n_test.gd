extends SceneTree
## Quick verification of i18n.gd placeholder tokenize/restore round-trips.
const I18nScript = preload("res://scripts/i18n.gd")
var failures := 0

func check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("i18n_test FAIL: " + msg)
		failures += 1

func _init() -> void:
	var i = I18nScript.new()
	# Tokenize wraps each specifier in a numbered token.
	check(i._tokenize("Claim +%d 🌸") == "Claim +{1} 🌸", "tokenize single %d")
	check(i._tokenize("%d steps today") == "{1} steps today", "tokenize leading %d")
	check(i._tokenize("%s (%s): %s") == "{1} ({2}): {3}", "tokenize multiple %s")
	check(i._tokenize("Plain sentence") == "Plain sentence", "tokenize leaves plain text")
	check(i._tokenize("50% off") == "50% off", "tokenize ignores bare percent")

	# Restore maps tokens back and keeps template formatting safe.
	check(i._restore("Claim +%d 🌸", "Reclamar +{1} 🌸") == "Reclamar +%d 🌸", "restore single token")
	check(i._restore("%s (%s): %s", "{1} ({2}): {3}") == "%s (%s): %s", "restore multi token")
	check(i._restore("%d steps today", "Hoy: {1} pasos") == "Hoy: %d pasos", "restore reordered token")
	check(i._restore("Claim +%d 🌸", "Reclamar +{ D 🌸").is_empty(), "restore rejects mangled token")
	check(i._restore("%d x %d", "solo {1}").is_empty(), "restore rejects missing token")
	check(i._restore("%d x %d", "{2} y {2}").is_empty(), "restore rejects duplicated token")
	check(i._restore("Claim +%d 🌸", "Reclamar +{5} 🌸").is_empty(), "restore rejects out-of-range token")
	# Bare percent in the translated body is escaped for later %-formatting.
	var esc: String = i._restore("%d petals", "50{1} de descuento")
	check(esc == "50%d de descuento" or esc == "50%%d de descuento", "restore escapes bare percent safely, got: " + esc)

	# Spec counting treats %% and bare % as literals, not format slots.
	check(i._spec_count("a %d b") == 1, "spec count %d")
	check(i._spec_count("a %% b") == 0, "spec count ignores %% literal")
	check(i._spec_count("100% happy") == 0, "bare % is not a format slot")
	check(i._spec_count("50%% + %d") == 1, "escaped literal plus real slot")

	if failures == 0:
		print("I18n tests: PASS (0 failures)")
	else:
		print("I18n tests: FAIL (", failures, " failures)")
	quit(1 if failures > 0 else 0)

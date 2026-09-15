class_name KinArt
extends RefCounted

static func atlas(path: String, cols: int, rows: int, index: int) -> Texture2D:
	if not ResourceLoader.exists(path): return null
	var source: Texture2D = load(path)
	var texture := AtlasTexture.new()
	texture.atlas = source
	var cell := source.get_size() / Vector2(cols, rows)
	texture.region = Rect2(Vector2(index % cols, index / cols) * cell, cell)
	if path.ends_with("decor-final.png"):
		texture.region = texture.region.grow_individual(-cell.x*0.1,-cell.y*0.035,-cell.x*0.1,-cell.y*0.035)
	return texture

static func pet(species: int, pose: int) -> Texture2D:
	var names := ["mochi","fern","pebble","clover","pippin","lumi"]
	var path := "res://assets/pet_%s.png" % names[clampi(species, 0, 5)]
	if ResourceLoader.exists(path): return atlas(path, 4, 2, pose)
	# mochi.png is a reference-only sheet (not evenly divisible), so fall
	# back to the verified Mochi lifecycle atlas instead of mis-slicing it.
	if path != "res://assets/pet_mochi.png":
		return atlas("res://assets/pet_mochi.png", 4, 2, clampi(pose, 0, 7))
	return null

static func image(texture: Texture2D, minimum: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.custom_minimum_size = minimum
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

extends SceneTree
var saved: Dictionary = {}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = root.get_node("World")
	for path in [world.SAVE,world.SAVE+".bak",world.SAVE+".tmp",world.STASH,"user://pocket-kin.before-cloud.json"]:
		if FileAccess.file_exists(path): saved[path]=FileAccess.get_file_as_string(path)
	var original: Dictionary=world.data.duplicate(true)
	world.data=world.fresh()
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/adoption.png")
	world.adopt(0,"Mochi")
	for page in ["Home","Play","Explore","Walk","Room","Album","Sanctuary","Settings"]:
		scene.show_page(page)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/"+page.to_lower()+".png")
		print("SCREEN OK: ",page)
	world.data=original
	for path in [world.SAVE,world.SAVE+".bak",world.SAVE+".tmp",world.STASH,"user://pocket-kin.before-cloud.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		if saved.has(path):
			var file=FileAccess.open(path,FileAccess.WRITE)
			file.store_string(saved[path])
			file.close()
	quit()

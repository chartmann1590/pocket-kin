extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition: push_error(message); failures += 1
func _init() -> void:
	var settings := {"sleep_hour":22,"wake_hour":7,"utc_offset":0}
	var midnight := 1725667200.0
	check(is_equal_approx(Sim.awake_seconds(midnight,midnight+86400,22,7,0),15*3600),"Daily waking window")
	check(Sim.awake_seconds(midnight,midnight+6*3600,22,7,0)==0,"Overnight sleep protected")
	check(Sim.awake_seconds(midnight+20*3600,midnight+30*3600,22,7,0)==2*3600,"Cross-midnight window")
	check(Sim.awake_seconds(midnight,midnight+365*86400,22,7,0)==365*15*3600,"Long absence bounded integration")
	var pet := {"hunger":85.0,"happiness":90.0,"cleanliness":95.0,"energy":80.0,"care_age":0.0,"updated":midnight+8*3600,"sleeping":false,"ill":false,"bond":0}
	Sim.reconcile(pet,midnight+12*3600,settings)
	check(is_equal_approx(pet.hunger,53),"Four-hour hunger decay")
	var snapshot := pet.duplicate(true)
	Sim.reconcile(pet,midnight,settings)
	check(pet==snapshot,"Clock rollback never grants progress")
	Sim.reconcile(pet,midnight+10*86400,settings)
	check(pet.ill and pet.hunger==0,"Neglect causes recoverable illness")
	check(Sim.care(pet,"treat",midnight+10*86400),"Free treatment succeeds")
	check(not pet.ill,"Treatment cures illness")
	check(not Sim.care(pet,"treat",midnight+10*86400+1),"Repeated action cooldown")
	print("Simulation tests: ", "PASS" if failures==0 else "FAIL", " (", failures, " failures)")
	quit(failures)

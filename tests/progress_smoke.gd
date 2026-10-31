extends SceneTree
func _initialize() -> void:
	var profile = load("res://scripts/progress.gd").new()
	var unlocks: Array[String] = []
	for i in 8:
		var result: Dictionary = profile.settle(true,1000)
		assert(result.delta==1000)
		if not result.unlocked.is_empty(): unlocks.append(result.unlocked)
	assert(unlocks.size()==4)
	assert(profile.equip_skin(4))
	assert(not profile.equip_skin(5))
	assert(profile.save_profile("user://qa_agent91_profile.cfg")==OK)
	var restored = load("res://scripts/progress.gd").new()
	restored.load_profile("user://qa_agent91_profile.cfg")
	assert(restored.credits==9000 and restored.wins==8 and restored.equipped_skin==4)
	for i in 40: restored.settle(false,1000)
	assert(restored.credits==0 and restored.wins==8 and restored.equipped_skin==4)
	assert(restored.equip_skin(4))
	var fresh = load("res://scripts/progress.gd").new()
	assert(not fresh.equip_skin(1))
	DirAccess.remove_absolute("user://qa_agent91_profile.cfg")
	print("PROGRESS_SMOKE_OK: win unlocks, loss floor, ownership, save/load")
	quit()

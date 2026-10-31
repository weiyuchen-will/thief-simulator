extends RefCounted
## Persistent cosmetic progress. Mission score is separate from account credits.
const PROFILE_PATH := "user://agent91.cfg"
const SKINS = [
	{"name":"原型·夜行","required":0,"color":Color("91a9ae"),"secondary":Color("25333a")},
	{"name":"极光·青锋","required":1,"color":Color("78ffe0"),"secondary":Color("203f49")},
	{"name":"赤焰·熔核","required":3,"color":Color("ff9856"),"secondary":Color("772e35")},
	{"name":"紫电·脉冲","required":5,"color":Color("b99aff"),"secondary":Color("4de9eb")},
	{"name":"黑金·特务91","required":8,"color":Color("efd083"),"secondary":Color("272527")}
]
var credits: int = 1000
var wins: int = 0
var equipped_skin: int = 0

func load_profile(path: String=PROFILE_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	credits = maxi(0,int(config.get_value("profile","credits",1000)))
	wins = maxi(0,int(config.get_value("profile","wins",0)))
	var selected := clampi(int(config.get_value("profile","skin",0)),0,SKINS.size()-1)
	equipped_skin = selected if wins>=int(SKINS[selected].required) else 0

func save_profile(path: String=PROFILE_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("profile","credits",credits)
	config.set_value("profile","wins",wins)
	config.set_value("profile","skin",equipped_skin)
	return config.save(path)

func settle(success: bool,reward: int) -> Dictionary:
	var before := credits
	var unlocked := ""
	if success:
		wins += 1
		credits += maxi(0,reward)
		for skin in SKINS:
			if int(skin.required)==wins: unlocked = str(skin.name)
	else:
		credits = maxi(0,credits-300)
	return {"delta":credits-before,"unlocked":unlocked}

func equip_skin(index: int) -> bool:
	if index<0 or index>=SKINS.size() or wins<int(SKINS[index].required): return false
	equipped_skin = index
	return true

func get_skins() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in SKINS.size():
		var entry: Dictionary = SKINS[i].duplicate()
		entry.index = i
		entry.unlocked = wins>=int(entry.required)
		result.append(entry)
	return result

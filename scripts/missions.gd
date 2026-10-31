extends RefCounted

const DEFINITIONS = {
	"bank": {
		"id":"bank", "name":"银行行动 · 夜幕金库", "location":"bank", "place":"曙光银行",
		"kind":"collect", "required":3, "item":"资产箱", "alarm_delay":35.0,
		"brief":"取回金库内的三个资产箱，全员撤离。",
		"arrival":"银行到了。跟紧队友，目标在后面的金库。",
		"inside":"警报响了！三个资产箱都在金库，拿齐后返回车辆。",
		"client":"联络人 · K", "reward":5000
	},
	"home": {
		"id":"home", "name":"住宅潜入 · 雨夜来客", "location":"home", "place":"松影宅邸",
		"kind":"collect", "required":2, "item":"情报箱", "alarm_delay":45.0,
		"brief":"潜入私人住宅，找到书房后的两份情报并带回。",
		"arrival":"松影宅邸到了。穿过客厅，资料在后面的书房。",
		"inside":"住宅的安保系统被触发了。找到两份情报，准备撤离。",
		"client":"情报员 · 岚", "reward":5500
	},
	"assassination": {
		"id":"assassination", "name":"特务委托 · 无声名单", "location":"office", "place":"黑曜会所",
		"kind":"eliminate", "required":1, "item":"目标", "alarm_delay":30.0,
		"brief":"寻找代号「灰狐」的敌方头目，完成暗杀并撤离。",
		"arrival":"黑曜会所到了。灰狐在后面的办公室，确认目标后行动。",
		"inside":"特务 91，灰狐就在后面。我们掩护你，完成委托后撤离。",
		"client":"特务联络人 · K", "reward":7000
	},
	"capture": {
		"id":"capture", "name":"特务委托 · 活口交易", "location":"office", "place":"黑曜会所",
		"kind":"capture", "required":1, "item":"目标", "alarm_delay":38.0,
		"brief":"找到代号「信使」的目标，控制并带上车辆。目标必须存活。",
		"arrival":"委托人要一个活口。接近信使，使用交互将他控制。",
		"inside":"信使在后面的办公室。别击杀他，控制后带回车上。",
		"client":"特务联络人 · K", "reward":8000
	}
}

static func get_mission(id: String) -> Dictionary:
	return DEFINITIONS.get(id,DEFINITIONS.bank).duplicate(true)

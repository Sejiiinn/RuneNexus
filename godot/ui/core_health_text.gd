extends RefCounted
const HudNumber = preload("res://ui/hud_number.gd")
## One compact number for the integrated bar; ordinary healing limits stay
## authoritative in combat, while this display cap tracks remaining extra HP.
static func additional_hp(defense) -> float:
	var value: Variant = defense.get("additional_hp")
	return maxf(0,float(value)) if value != null else 0.0
static func has_additional_hp(defense) -> bool:
	if additional_hp(defense)>0: return true
	var config: Variant = defense.get("config")
	return config is Dictionary and float(config.get("nexusAdditionalHpRate",0))>0
static func combined_numbers(defense) -> String:
	var bonus := additional_hp(defense)
	return "%s/%s" % [HudNumber.compact_integer(ceili(float(defense.hp)+bonus)),HudNumber.compact_integer(ceili(float(defense.max_hp)+bonus))]
static func tooltip(defense) -> String:
	var text := "체력 %d/%d" % [ceili(float(defense.hp)),ceili(float(defense.max_hp))]
	if has_additional_hp(defense): text += " · 추가 체력 %d (회복 불가)" % ceili(additional_hp(defense))
	return text
static func update_bar(bar,defense) -> void:
	bar.set_health(float(defense.hp),float(defense.max_hp),additional_hp(defense))

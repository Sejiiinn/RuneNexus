extends SceneTree
const Numbers=preload("res://ui/hud_number.gd")
func _initialize():
	var checks:=0; var failures:=[]
	for pair in [[0,"0"],[999,"999"],[1000,"1K"],[1250,"1.25K"],[9999,"10K"],[12500,"12.5K"],[99999,"100K"],[123456,"123K"],[999499,"999K"],[999500,"1M"],[999999,"1M"],[1000000,"1M"],[1250000,"1.25M"],[12500000,"12.5M"],[123456789,"123M"],[-999500,"-1M"]]:
		checks+=1
		if Numbers.compact_price(pair[0])!=pair[1]: failures.append(str(pair))
	var result={"checks":checks,"failures":failures}
	var f=FileAccess.open("/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-23/turret-stats-ux/incremental-update/independent-price-format-result.json",FileAccess.WRITE); f.store_string(JSON.stringify(result,"  ")); f.close()
	print("INDEPENDENT_PRICE_FORMAT ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)

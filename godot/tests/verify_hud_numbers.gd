extends SceneTree
const Numbers = preload("res://ui/hud_number.gd")
var checks := 0
var failures: Array[String] = []

func check(actual: String, expected: String, context: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [context,expected,actual])

func _initialize() -> void:
	var samples := [[0,"0"],[999,"999"],[1000,"1,000"],[1250,"1,250"],[9999,"9,999"],
		[10000,"10K"],[10049,"10K"],[10050,"10.1K"],[12500,"12.5K"],
		[999949,"999.9K"],[999950,"1M"],[999999,"1M"],[1000000,"1M"],
		[1049999,"1M"],[1050000,"1.1M"],[123456789,"123.5M"],
		[9223372036854775807,"9223372036854.8M"]]
	for sample in samples:
		for direction in [1,-1]:
			var value: int = sample[0] * direction
			var expected: String = ("-" if value < 0 else "") + sample[1]
			for output in [Numbers.format_number(value),Numbers.compact_integer(value),Numbers.compact_price(value)]:
				check(output,expected,"shared integer policy %d" % value)
			check(Numbers.compact(value,0),expected,"compact integer %d" % value)
	var minimum: int = -9223372036854775807 - 1
	check(Numbers.compact_price(minimum),"-9223372036854.8M","minimum price")
	check(Numbers.exact_integer(minimum),"-9,223,372,036,854,775,808","minimum exact")
	check(Numbers.exact_integer(9223372036854775807),"9,223,372,036,854,775,807","maximum exact")
	check(Numbers.format_number(9223372036854775807,{"decimals":6}),"9223372036854.775807M","exact six decimal maximum")
	check(Numbers.format_number(minimum,{"decimals":6}),"-9223372036854.775808M","exact six decimal minimum")
	for sample in [[0.0,"0.0"],[1.25,"1.3"],[1250.25,"1,250.3"],[-1250.25,"-1,250.3"],[9999.0,"9,999.0"],[10000.0,"10K"],[12345.6,"12.3K"],[999950.0,"1M"],[-999950.0,"-1M"]]:
		check(Numbers.compact(sample[0]),sample[1],"fractional combat %s" % sample[0])
	check(Numbers.compact(1.234,2),"1.23","fractional stat precision")
	check(Numbers.compact(1250.99,0),"1,250","integer truncation compatibility")
	check(Numbers.compact(-1250.99,0),"-1,250","negative truncation compatibility")
	check(Numbers.format_number(1250.0,{"small_decimals":2}),"1,250","trim small zeros")
	check(Numbers.format_number(1250.0,{"small_decimals":2,"small_trim_zeros":false}),"1,250.00","fixed small zeros")
	check(Numbers.format_number(1250.25,{"small_decimals":2,"group_small":false}),"1250.25","disable grouping")
	check(Numbers.format_number(10000,{"decimals":2,"trim_zeros":false}),"10.00K","fixed compact zeros")
	check(Numbers.format_number(999950,{"trim_zeros":false}),"1.0M","fixed promoted zeros")
	# An explicitly selected policy can reproduce the former combat threshold
	# and precision without restoring a second abbreviation implementation.
	var legacy := {"abbreviate_at":1000,"decimals":2,"group_small":false}
	for sample in [[999,"999"],[1000,"1K"],[1250,"1.25K"],[999990,"999.99K"],[999994,"999.99K"],[999995,"1M"],[-999995,"-1M"]]:
		check(Numbers.format_number(sample[0],legacy),sample[1],"configured legacy policy %s" % sample[0])
	for sample in [[999499,"999K"],[999500,"1M"],[-999500,"-1M"]]:
		check(Numbers.format_number(sample[0],{"decimals":0}),sample[1],"configured whole compact %s" % sample[0])
	check(Numbers.format_number(999999,{"abbreviate_at":1000000}),"999,999","explicit million threshold")
	check(Numbers.format_number(1000000,{"abbreviate_at":1000000}),"1M","explicit million threshold reached")
	check(Numbers.format_number(-0.0),"0","negative zero")
	check(Numbers.format_number(INF),"inf","positive infinity")
	check(Numbers.format_number(-INF),"-inf","negative infinity")
	check(Numbers.format_number(NAN),"nan","not a number")
	print("HUD_NUMBERS checks=%d failures=%d %s" % [checks,failures.size(),JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

extends RefCounted
## Display only. Domain values, prices and affordability remain unrounded.
static func compact(value: float, small_decimals: int = 1) -> String:
	if absf(value) < 1000.0:
		return str(int(value)) if small_decimals == 0 else ("%.*f" % [small_decimals,value])
	var scale := 1000000.0 if absf(value) >= 1000000.0 else 1000.0
	var rounded := snappedf(value / scale,0.01)
	if scale == 1000.0 and absf(rounded) >= 1000.0:
		scale = 1000000.0
		rounded = snappedf(value / scale,0.01)
	var text := "%.2f" % rounded
	while text.ends_with("0"): text = text.left(-1)
	if text.ends_with("."): text = text.left(-1)
	return text + ("M" if scale == 1000000.0 else "K")

## Price tokens stay readable in narrow buttons; their tooltips keep raw quotes.
static func compact_price(value: float) -> String:
	if absf(value) < 1000.0: return str(int(value))
	var scale := 1000000.0 if absf(value) >= 1000000.0 else 1000.0
	var amount := absf(value / scale)
	var decimals := 2 if amount < 10.0 else (1 if amount < 100.0 else 0)
	# Reuse unit promotion, so a rounded 1000K is displayed as 1M.
	return compact(signf(value)*snappedf(amount,pow(10.0,-decimals))*scale,0)

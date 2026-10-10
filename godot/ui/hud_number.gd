extends RefCounted
## Display only. Domain values, prices and affordability remain unrounded.
## K/M summaries share the 10,000 threshold and one trimmed decimal by default.
## Options: abbreviate_at (1,000..1,000,000), decimals (0..6), small_decimals
## (0..6), trim_zeros, small_trim_zeros and group_small. Zero small_decimals
## preserves the existing integer/truncation policy; fractional stats can opt in.
static func format_number(value: Variant, options: Dictionary = {}) -> String:
	assert(value is int or value is float, "Display value must be numeric")
	if value is float and not is_finite(value): return str(value)
	var threshold := clampi(int(options.get("abbreviate_at",10000)),1000,1000000)
	var small: bool = value > -threshold and value < threshold
	var decimals := clampi(int(options.get("small_decimals" if small else "decimals",0 if small else 1)),0,6)
	var scale := 1 if small else (1000000 if value <= -1000000 or value >= 1000000 else 1000)
	var text := _scaled(int(value) if small and decimals == 0 else value,scale,decimals)
	# Promote after rounding at the selected precision, never emit 1000K.
	if scale == 1000 and text.trim_prefix("-").get_slice(".",0) == "1000":
		scale = 1000000
		text = _scaled(value,scale,decimals)
	if bool(options.get("small_trim_zeros" if small else "trim_zeros",true)):
		text = _trim_zeros(text)
	if small:
		return _group_number(text) if bool(options.get("group_small",true)) else text
	return text + ("M" if scale == 1000000 else "K")

## Compatibility entry points keep caller precision without duplicating math.
## Small fractional combat stats retain their requested fixed decimal places.
static func compact(value: Variant, small_decimals: int = 1) -> String:
	return format_number(value,{"small_decimals":small_decimals,"small_trim_zeros":false})

## Price tooltips and command quotes keep exact amounts at their call sites.
static func compact_price(value: Variant) -> String:
	return format_number(value)

static func compact_integer(value: int) -> String:
	return format_number(value)

## Exact integer display, including the full signed 64-bit range.
static func exact_integer(value: int) -> String:
	return _group_number(str(value))

static func _scaled(value: Variant, scale: int, decimals: int) -> String:
	if value is float:
		var rounded := snappedf(absf(value / float(scale)),pow(10.0,-decimals))
		return ("-" if value < 0 and rounded != 0 else "") + ("%.*f" % [decimals,rounded])
	# Divide before multiplying: neither INT64_MIN's absolute value nor an
	# int64 amount times the decimal factor is safe. The remainder is bounded.
	var number: int = value
	var factor := int(pow(10,decimals))
	@warning_ignore("integer_division")
	var whole := number / scale
	@warning_ignore("integer_division")
	var fraction := (absi(number % scale) * factor + scale / 2) / scale
	if fraction == factor:
		whole += signi(number)
		fraction = 0
	var text := ("-" if number < 0 else "") + str(whole).trim_prefix("-")
	return text + (".%0*d" % [decimals,fraction] if decimals > 0 else "")

static func _trim_zeros(text: String) -> String:
	if not text.contains("."): return text
	while text.ends_with("0"): text = text.left(-1)
	return text.left(-1) if text.ends_with(".") else text

static func _group_number(text: String) -> String:
	var digits := text.trim_prefix("-").get_slice(".",0)
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(-3)
	var fraction := "." + text.get_slice(".",1) if text.contains(".") else ""
	return ("-" if text.begins_with("-") else "") + digits + grouped + fraction

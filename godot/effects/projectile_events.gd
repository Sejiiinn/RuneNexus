extends RefCounted

## Authoritative Flame launch/finish edges; no native collision or damage.
var generation := -1
var through := -1
var flights := {}
var latest_clock := 0.0

func clear() -> void:
	generation = -1
	through = -1
	flights.clear()
	latest_clock = 0.0

func sample(payload: Dictionary, visual_time: float) -> Array:
	var incoming := int(payload.get("generation", 0))
	if incoming < generation:
		incoming = generation
		payload = {"clock": latest_clock, "events": []}
	if incoming != generation:
		clear()
		generation = incoming
	var clock := maxf(latest_clock, float(payload.get("clock", 0.0)))
	latest_clock = clock
	for event: Dictionary in payload.get("events", []):
		var sequence := int(event.get("event", -1))
		if sequence <= through:
			continue
		through = sequence
		if event.has("remove"):
			flights.erase(int(event["remove"]))
			continue
		var data: Array = event.get("data", [])
		if data.size() < 14:
			continue
		flights[int(data[0])] = event
	var result: Array = []
	for id in flights.keys():
		var event: Dictionary = flights[id]
		var data: Array = event["data"].duplicate()
		if float(data[11]) >= 0.0:
			var age := fposmod(visual_time - float(data[11]), 1200.0)
			if age >= 0.14 or str(data[5]) not in ["arrow", "cannon", "magic"]:
				flights.erase(id)
				continue
		else:
			var distance := maxf(0.0, clock - float(event["clock"])) * maxf(0.0, float(event["speed"]))
			distance = minf(distance, float(event.get("remaining", INF)))
			data[1] = float(data[1]) + float(data[3]) * distance
			data[2] = float(data[2]) + float(data[4]) * distance
		result.append(data)
	return result

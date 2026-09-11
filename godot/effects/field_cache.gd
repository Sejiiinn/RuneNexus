extends RefCounted
class_name GodotFieldCache

## 기존 RGBA8 밀도장을 전장 전체가 공유하는 3D 텍스처로 한 번 업로드.
static var _shared: Dictionary = {}


static func load_shared(
	manifest_path: String = "res://assets/cannon_field.json",
	data_path: String = "res://assets/cannon_field.bin"
) -> Dictionary:
	var cache_key: String = manifest_path + "\n" + data_path
	if _shared.has(cache_key):
		return _shared[cache_key]
	if not FileAccess.file_exists(manifest_path) or not FileAccess.file_exists(data_path):
		push_error("포탄 체적 캐시 파일을 찾을 수 없습니다.")
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(manifest_path)) != OK:
		push_error("포탄 체적 캐시의 JSON을 읽을 수 없습니다.")
		return {}
	if not (parser.data is Dictionary):
		push_error("포탄 체적 캐시의 메타데이터 형식이 맞지 않습니다.")
		return {}
	var manifest: Dictionary = parser.data
	var grid: int = int(manifest.get("gridSize", 0))
	var bricks: Array = manifest.get("atlasBricks", [])
	var times: Array = manifest.get("times", [])
	if int(manifest.get("version", 0)) != 1 or grid < 2 or bricks.size() != 3:
		push_error("포탄 체적 캐시의 격자 형식이 맞지 않습니다.")
		return {}
	var width: int = grid * int(bricks[0])
	var height: int = grid * int(bricks[1])
	var depth: int = grid * int(bricks[2])
	if width < grid or height < grid or depth < grid or times.size() < 2:
		push_error("포탄 체적 캐시의 크기나 시간 표본이 맞지 않습니다.")
		return {}
	if times.size() != int(bricks[0]) * int(bricks[1]) * int(bricks[2]):
		push_error("포탄 체적 캐시의 시간 블록 수가 맞지 않습니다.")
		return {}
	if float(times[0]) != 0.0 or not is_equal_approx(float(times[-1]), 1.1):
		push_error("포탄 체적 캐시의 재생 시간이 맞지 않습니다.")
		return {}
	for index in range(times.size()):
		if not is_finite(float(times[index])):
			push_error("포탄 체적 캐시의 시간 값이 유효하지 않습니다.")
			return {}
		if index > 0 and float(times[index]) <= float(times[index - 1]):
			push_error("포탄 체적 캐시의 시간이 증가하지 않습니다.")
			return {}
	if manifest.get("boundsMin", []) != [-2.35, 0.0, -2.35] \
		or manifest.get("boundsMax", []) != [2.35, 2.9, 2.35]:
		push_error("포탄 체적 캐시의 공간 경계가 맞지 않습니다.")
		return {}
	for key in ["densityScale", "emissionScale"]:
		var value: float = float(manifest.get(key, 0.0))
		if not is_finite(value) or value <= 0.0:
			push_error("포탄 체적 캐시의 복원 배율이 맞지 않습니다.")
			return {}
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(data_path)
	var slice_bytes: int = width * height * 4
	var expected_bytes: int = slice_bytes * depth
	if bytes.size() != expected_bytes or int(manifest.get("byteLength", 0)) != expected_bytes:
		push_error("포탄 체적 캐시의 데이터 길이가 맞지 않습니다.")
		return {}
	var slices: Array[Image] = []
	# x → y → z 순서 보존. 알파는 투명도가 아닌 열도이며 색 공간 변환 없음.
	for z in range(depth):
		slices.append(Image.create_from_data(
			width, height, false, Image.FORMAT_RGBA8,
			bytes.slice(z * slice_bytes, (z + 1) * slice_bytes)
		))
	var texture := ImageTexture3D.new()
	var error: Error = texture.create(Image.FORMAT_RGBA8, width, height, depth, false, slices)
	if error != OK:
		push_error("포탄 체적 텍스처를 준비하지 못했습니다: %s" % error_string(error))
		return {}
	var result: Dictionary = {"texture": texture, "manifest": manifest}
	_shared[cache_key] = result
	return result

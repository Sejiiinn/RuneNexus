extends SceneTree

## --script res://verify_compressed_field.gd -- <원본 cannon_field.bin 절대경로>
## staging gzip을 원본 전체와 비교하고 공유 texture의 크기·형식·시간 표본을 확인한다.
const FieldCache = preload("res://effects/field_cache.gd")
var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not FileAccess.file_exists(args[0]):
		push_error("비교할 원본 cannon_field.bin 절대경로가 필요합니다.")
		quit(1)
		return
	var original := FileAccess.get_file_as_bytes(args[0])
	var compressed := FileAccess.get_file_as_bytes("res://assets/cannon_field.bin.gz")
	_check(compressed.size() < original.size(), "gzip이 원시 자산보다 작지 않음")
	var decoded := compressed.decompress(original.size(), FileAccess.COMPRESSION_GZIP)
	_check(decoded == original, "gzip 복원 byte가 제작 원본과 다름")
	var loaded := FieldCache.load_shared()
	_check(not loaded.is_empty(), "압축 볼륨 공유 캐시 로드 실패")
	if loaded.is_empty():
		quit(1)
		return
	var manifest: Dictionary = loaded["manifest"]
	_check(int(manifest["gridSize"]) == 48 and manifest["atlasBricks"] == [4.0, 4.0, 2.0], "격자·시간 brick 구성 변경")
	_check(manifest["times"].size() == 32 and manifest["times"][0] == 0.0 and manifest["times"][-1] == 1.1, "시간 표본·효과 수명 변경")
	_check(int(manifest["byteLength"]) == original.size(), "manifest 원본 byte 길이 변경")
	var texture: Texture3D = loaded["texture"]
	_check(texture.get_width() == 192 and texture.get_height() == 192 and texture.get_depth() == 96, "공유 3D texture 크기 변경")
	_check(texture.get_format() == Image.FORMAT_RGBA8 and not texture.has_mipmaps(), "RGBA8·샘플링 형식 변경")
	_check(FieldCache.load_shared()["texture"] == texture, "동일 cache 재호출이 texture를 새로 만듦")
	var raw := FieldCache.load_shared("res://assets/cannon_field.json", args[0])
	_check(not raw.is_empty(), "기존 raw 경로 호환성 파괴")
	if not raw.is_empty():
		_check(raw["texture"].get_width() == texture.get_width() and raw["texture"].get_depth() == texture.get_depth(), "raw/gzip texture 크기 불일치")
		_check(FieldCache.load_shared("res://assets/cannon_field.json", args[0])["texture"] == raw["texture"], "raw 경로의 cache 재사용 실패")
	print("Compressed field verification: %d failures; %d -> %d bytes, exact RGBA8/32 frames/1.1s, shared cache and raw compatibility" % [failures, original.size(), compressed.size()])
	quit(0 if failures == 0 else 1)

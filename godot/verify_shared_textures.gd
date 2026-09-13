extends SceneTree

## --path build/godot/project --script <이 파일 절대경로> -- <shared_texture_manifest.json 절대경로>
## import/export 없이 준비된 GLB/Texture2D를 읽는다. 제작 GLB BIN/JSON 동일성은 Python 검사 담당.
const Labels = preload("res://ui/battlefield_labels.gd")
var failures := 0
var texture_references := 0
var materials_checked := 0
var opaque_pixels_checked := 0
var alpha_texture_paths: Array[String] = []
var shared: Dictionary = {}

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _glbs(directory: String) -> Array[String]:
	var result: Array[String] = []
	for filename in DirAccess.get_files_at(directory):
		if filename.ends_with(".glb"):
			result.append(directory.path_join(filename))
	for subdirectory in DirAccess.get_directories_at(directory):
		result.append_array(_glbs(directory.path_join(subdirectory)))
	result.sort()
	return result

func _document(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 20 or bytes.decode_u32(0) != 0x46546c67 or bytes.decode_u32(16) != 0x4e4f534a:
		_check(false, "GLB JSON 헤더 오류: " + path)
		return {}
	var size := bytes.decode_u32(12)
	var parsed = JSON.parse_string(bytes.slice(20, 20 + size).get_string_from_utf8())
	if not parsed is Dictionary:
		_check(false, "GLB JSON 파싱 실패: " + path)
		return {}
	return parsed

func _texture_path(path: String, document: Dictionary, definition: Dictionary) -> String:
	var index := int(definition.get("index", -1))
	var textures: Array = document.get("textures", [])
	if index < 0 or index >= textures.size():
		_check(false, "glTF texture index 누락: " + path)
		return ""
	var image_index := int(textures[index].get("source", -1))
	var images: Array = document.get("images", [])
	if image_index < 0 or image_index >= images.size():
		_check(false, "glTF image source 누락: " + path)
		return ""
	var image: Dictionary = images[image_index]
	_check(image.has("uri") and not image.has("bufferView"), "embedded image 잔류: " + path)
	return path.get_base_dir().path_join(str(image.get("uri", ""))).simplify_path()

func _check_slot(path: String, document: Dictionary, definition: Dictionary, material: StandardMaterial3D, slot: int) -> void:
	var expected := _texture_path(path, document, definition)
	var texture := material.get_texture(slot)
	_check(texture != null, "material texture slot 누락: %s / %s / %d" % [path, material.resource_name, slot])
	if texture == null or expected.is_empty(): return
	texture_references += 1
	_check(expected.begins_with("res://assets/shared_textures/"), "공용 외부 texture URI가 아님: " + expected)
	_check(texture.resource_path == expected, "imported texture 경로 불일치: %s != %s" % [texture.resource_path, expected])
	if shared.has(expected):
		_check(texture == shared[expected], "동일 URI texture 객체가 중복됨: " + expected)
	else:
		shared[expected] = texture
	_check(load(expected) == texture, "직접 로드 texture와 GLB material 참조가 다름: " + expected)

func _check_material(path: String, document: Dictionary, material: StandardMaterial3D, definition: Dictionary) -> void:
	materials_checked += 1
	var pbr: Dictionary = definition.get("pbrMetallicRoughness", {})
	if pbr.has("baseColorTexture"):
		_check_slot(path, document, pbr["baseColorTexture"], material, BaseMaterial3D.TEXTURE_ALBEDO)
	if pbr.has("metallicRoughnessTexture"):
		_check_slot(path, document, pbr["metallicRoughnessTexture"], material, BaseMaterial3D.TEXTURE_ROUGHNESS)
		_check_slot(path, document, pbr["metallicRoughnessTexture"], material, BaseMaterial3D.TEXTURE_METALLIC)
	for key in {"normalTexture": BaseMaterial3D.TEXTURE_NORMAL, "occlusionTexture": BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION, "emissiveTexture": BaseMaterial3D.TEXTURE_EMISSION}:
		if definition.has(key):
			var slots := {"normalTexture": BaseMaterial3D.TEXTURE_NORMAL, "occlusionTexture": BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION, "emissiveTexture": BaseMaterial3D.TEXTURE_EMISSION}
			_check_slot(path, document, definition[key], material, slots[key])

func _verify_glb(path: String, document: Dictionary) -> void:
	var packed := load(path) as PackedScene
	_check(packed != null, "GLB PackedScene 로드 실패: " + path)
	if packed == null: return
	var scene := packed.instantiate()
	var definitions := {}
	for definition: Dictionary in document.get("materials", []):
		definitions[str(definition.get("name", ""))] = definition
	var seen := {}
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	if scene is MeshInstance3D: meshes.push_front(scene)
	_check(not meshes.is_empty(), "GLB mesh 누락: " + path)
	for mesh: MeshInstance3D in meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			_check(material != null, "GLB surface material 누락: " + path)
			if material == null or seen.has(material.get_instance_id()): continue
			seen[material.get_instance_id()] = true
			_check(definitions.has(material.resource_name), "glTF material 이름 대응 누락: %s/%s" % [path, material.resource_name])
			if definitions.has(material.resource_name):
				_check_material(path, document, material, definitions[material.resource_name])
	scene.free()

func _verify_pixels() -> void:
	for path: String in shared:
		var original := Image.new()
		_check(original.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK, "원본 PNG decode 실패: " + path)
		if original.is_empty(): continue
		var texture: Texture2D = shared[path]
		var imported := texture.get_image()
		_check(imported != null and not imported.is_empty(), "imported texture 이미지 누락: " + path)
		if imported == null or imported.is_empty(): continue
		_check(original.get_size() == imported.get_size(), "texture 원본 크기 변경: " + path)
		# importer의 투명 경계 RGB 보정은 합법적이므로 완전 불투명 PNG만 전체 byte 비교.
		if original.detect_alpha() != Image.ALPHA_NONE:
			alpha_texture_paths.append(path)
			continue
		original.convert(Image.FORMAT_RGBA8)
		imported.clear_mipmaps()
		imported.convert(Image.FORMAT_RGBA8)
		_check(original.get_data() == imported.get_data(), "불투명 texture base level byte 변경: " + path)
		opaque_pixels_checked += 1

func _verify() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("shared_texture_manifest.json 절대경로가 필요합니다.")
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not manifest is Dictionary:
		push_error("공용 texture manifest JSON 파싱 실패")
		quit(1)
		return
	var paths := _glbs("res://assets")
	_check(paths.size() == int(manifest["glb_count"]), "staging GLB 총수와 manifest 불일치")
	var documents := {}
	for path: String in paths:
		var document := _document(path)
		documents[path] = document
		_verify_glb(path, document)
	var manifest_textures := {}
	for record: Dictionary in manifest["images"]:
		var path: String = "res://assets/" + str(record["glb"])
		var images: Array = documents.get(path, {}).get("images", [])
		var index := int(record["image_index"])
		_check(index >= 0 and index < images.size(), "manifest image index 누락: " + path)
		if index >= 0 and index < images.size():
			_check(images[index].get("uri") == record["uri"], "manifest 외부 URI와 GLB 불일치: " + path)
		var texture_path: String = "res://assets/" + str(record["texture"])
		manifest_textures[texture_path] = true
		_check(shared.has(texture_path), "manifest texture의 실제 material 사용 누락: " + texture_path)
	_check(shared.size() == int(manifest["shared_texture_count"]), "실제 공유 texture 수 불일치")
	_verify_pixels()
	_check(opaque_pixels_checked > 0, "불투명 texture 픽셀 보존을 하나도 검사하지 못함")
	var labels := Labels.new()
	_check(labels.supported_groups().has("labels") and labels.textures.size() == 4, "UI labels 지원 그룹/4개 texture 누락")
	_check(labels.textures.get("diamond_currency") == load("res://assets/ui/diamond_currency.png"), "UI diamond 공용 texture 연결 실패")
	labels.free()
	print("Shared textures verification: %d failures; %d GLBs, %d materials, %d texture references -> %d shared objects, %d opaque PNGs byte-exact, %d alpha PNGs dimensions checked, labels supported" % [failures, paths.size(), materials_checked, texture_references, shared.size(), opaque_pixels_checked, alpha_texture_paths.size()])
	quit(0 if failures == 0 else 1)

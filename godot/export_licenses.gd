extends SceneTree

## 사용한 엔진 버전의 본문·외부 라이브러리 고지를 프로젝트 팩에 포함.
func _initialize() -> void:
	var file := FileAccess.open("res://engine_licenses.txt", FileAccess.WRITE)
	file.store_line(Engine.get_license_text())
	file.store_line(JSON.stringify(Engine.get_copyright_info(), "\t"))
	var licenses := Engine.get_license_info()
	for title in licenses:
		file.store_line("\n" + title + "\n" + licenses[title])
	file.close()
	quit()

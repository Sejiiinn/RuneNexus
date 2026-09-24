# Godot 네이티브 엔진의 이름 기반 JNI 호출 대상 보존.
# AAR에 consumer 규칙이 없어 R8이 파일 접근·기기 정보 메서드를 제거함.
-keep class org.godotengine.godot.** { *; }

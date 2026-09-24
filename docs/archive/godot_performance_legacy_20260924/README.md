# 2026-09-24 이전 Godot·Flutter 혼합 호스트 측정 도구

원본 위치: `tool/godot_performance/`. `build_validation.py`와 `run_baseline.py`는 제거된 Flutter SDK·`GodotBenchmarkActivity`·`validation_baseline.dart`를 필요로 한다. `run_native.py`도 옛 `.godotpreview` Activity를 대상으로 한다. `summarize_results.py`와 `analyze_validation.py`는 당시 로그 형식의 분석용이다. 함께 쓰인 `native/` 장면·fixture도 역사적 재현 자료로 보존했다. 현재 Android 빌드·검증 경로로 실행하지 않는다.

당시 Dart 원본은 [Flutter 보관 압축](../flutter_reference_20260924.tar.gz), 현재 절차는 [인앱 가이드](../../../.agents/in_app_test_guide.md)를 따른다. 이 보관은 과거 측정 결과를 현재 Godot 단일 앱 결과로 인정한다는 뜻이 아니다.

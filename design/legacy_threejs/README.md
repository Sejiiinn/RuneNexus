# 과거 ThreeJS 렌더러 보관

2026-09-13 ThreeJS·flutter_angle 실행 경로를 제품에서 제거했다. 이 폴더는 역사 기록이며 현행 구현이나 실행 대상이 아니다.

- `lib/`, `test/`: 이전 경로를 유지한 `.dart.txt` 소스와 전용 테스트. 분석·컴파일하지 않는다.
- `web_bindings/`: 과거 WebGL2 바인딩과 원본 라이선스. 웹 배포에 포함하지 않는다.
- 기존 `design/stage1_3d/mobile_profile/`와 대포 `barrage_runtime/`, `shell_runtime/`, `v2/comparison/`의 진입 코드는 각 폴더에서 `main.dart.txt`로 보존한다.
- Blender·GLB·이미지·효과 데이터는 기존 위치에 보존한다. Godot 입력 자산은 PCK로만 포함하고 Flutter의 중복 자산 등록을 제거했다.

현재 실행·검증은 [Godot 본게임 경로](../../docs/stage1_3d_preview.md)를 따른다. 과거 렌더러를 복구하려면 당시 의존성·빌드 설정도 함께 복구해야 한다.

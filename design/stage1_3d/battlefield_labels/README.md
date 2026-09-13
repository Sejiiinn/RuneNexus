# 전장 객체 부착 정보 이관

역할: 2026-09-13 Godot 객체 정보 이관의 원본·단독 확인 기록. Android 본게임 시각 채택·실기기 성능 확인을 대신하지 않는다.

## 원본

- 화상 불씨/빛/연기와 감속 십자: `lib/game/rendering/status_effect_sprite_cache.dart`의 기존 Flutter 생성 그림을 그대로 PNG로 내보냈다.
- 다이아: `assets/images/diamond_currency.png` 원본 복사.
- 출력: `assets/images/stage1_3d/ui/labels/`의 PNG 5개. Godot PCK에는 `assets/ui/labels/`로 복사한다. 런타임 픽셀 전송은 없다.
- 적 상태 위치·시간·크기·색·순서·내구도 바의 기준: `lib/game/rendering/enemy_renderer.dart`의 `showBody: false` 경로.
- 코어 바: `lib/game/rendering/core_skill_cooldown_renderer.dart` 기준. 기존 지면 기울기를 유지하고 진행도·활성·색은 Dart에서 전달한다.

재생성은 저장소 루트에서 `scripts/in_app_server_macos.sh flutter test tool/export_battlefield_label_sprites.dart`로 한다. 원본 이미지 수정 도구나 새 디자인 생성은 사용하지 않았다.

## 확인

- `test/battlefield_labels_test.dart`: 불변 목록, 표시 데이터 직렬화, 최대 내구도·시간·상태 의미, 코어 비표시 계약 검사.
- `godot/verify_battlefield_labels.gd`: 자산 준비 capability, 내구도 분할, 새 데이터 없이 카메라/월드 이동·확대, 동일 ID 재사용, 정지 시간 보존, 제거/리셋 검사.
- `native-labels-preview.png`: Godot 4.7.2 macOS OpenGL 단독 렌더. 왼쪽부터 체력, 체력+장갑, 보호막 포함, 모든 상태 표시를 확인했다. 아래는 코어 쿨다운이다. 배경·배치는 검사 전용이며 실제 본게임 캡처가 아니다.
- Android 본게임 두 시점·시점 전환, 실제 적 부착 위치, 작은 화면·다중 상태, 보상/복원/일시정지와 실기기 성능은 통합 검증에서 확인해야 한다.

# 챕터 1 적의 실제 3D 모델

2026-09-10. 기존 인게임 적의 형태·색을 보존한 6종 GLB. 현재 파일은 사용자 피드백에 따른 볼륨 개선 버전이다.

- 게임용: `assets/images/stage1_3d/enemies/{normal,armored,shielded,fast,tank,boss}.glb`.
- 현행 원본: `chapter-one-enemies-refined.blend`, 재생성: `refine_enemies.py`, 용량/삼각형: `manifest-refined.json`.
- 초기 원본 `chapter-one-enemies.blend`와 `build_enemies.py`는 제작 기록으로 보존한다.
- 근거: `lib/game/rendering/enemy_shape_renderer.dart`의 front/side/back 실루엣과 `_EnemyVisualPalette`, `lib/data/definitions/game_enemy_data.dart`의 핵 색.

## 현재 형태

동일한 전면을 뒤로 밀어 만든 평평한 측면을 없애고 전체 방향에서 이어지는 곡면형 다면체 껍질로 재구성했다. 일반/보호막의 3가시, 빠른 적의 날렵한 몸통·뒤로 뻗는 가시, 탱커의 금색 양옆 장갑, 장갑병의 은색 분할 장갑, 보스의 5가시·자주색 장갑을 따른다. 새 팔다리나 곤충 부품은 추가하지 않았다.

각 핵은 약간 위로 기울어진 recessed crystal이다. 흰 중앙 버튼과 평면 렌즈를 제거하고 핵 색의 여러 결정면으로 표현했다. 표면은 roughness 0.84와 미세 grain normal을 사용하며 512×512 공유 atlas를 각 GLB에 내장한다.

## 런타임 계약과 검증

- glTF +Y 위, +Z 정면. 바닥 기준 원점, 최대 가로폭 1.0, 최저점 +Y 0.045의 부유 여유.
- 정적 모델이며 이동·방향·부유 진동·후방 빛·보호막·상태 효과는 런타임 처리.
- `enemy-steep-refined.png`는 카메라 (5,-13,27)의 높은 전장 시점에서 검수한 Blender 렌더다. 실제 앱 캡처는 아니다.
- 단일 mesh/2 material primitives/하나의 texture atlas/COLOR_0 포함을 GLB 파싱으로 확인했다. 면별 미세 색 변화는 vertex color로 통합해 재질별 draw call을 줄였다. 실제 게임 크기 가시성·동작은 통합 검증 대상이다.

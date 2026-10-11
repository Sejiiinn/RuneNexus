# 기관총 명중 — 도탄 불티 A안

상태: 사용자 선택 A안을 Godot 본게임 전장에 적용. 2026-10-11. 현행 결정은 [전장 문서의 스테이지 1 행](../../../docs/design_decisions/battlefield.md#챕터-1-스테이지-15)이 기준이다.

## 선택과 이전 표현

- 시안: [`machinegun-hit-concepts.html`](machinegun-hit-concepts.html). 2D 캔버스 동작 시안이며 실제 게임 렌더가 아니다. A 도탄 불티 / B 석재 파편 / C 몸체 피격광 중 사용자가 A를 선택했다.
- 이전 표현: 네이티브 전투의 `impact`/`spark` 시각 항목을 `godot/ui/battlefield_effects.gd`가 3D 전장 위 2D 캔버스에 대칭 6갈래 선과 흰 원으로 0.28초 그렸다. 탄 방향·맞은 몸체와 무관한 평면 표시였다.

## 런타임 계약

- 전투: `native_combat_runtime.gd::_impact`가 기관총 탄환 명중에만 표시 필드 `turretType="arrow"`, `targetId`, `direction`(탄 진행 단위 벡터)을 추가한다. 피해·충돌·명중 좌표·저장은 바꾸지 않는다.
- 라우팅: `EffectFormat.is_spatial_ricochet`. 본게임 `main.gd`가 `spatial_ricochet`을 켜면 캔버스는 기관총 섬광만 건너뛴다. 저격 등 다른 `spark` 명중은 기존 2D 표시를 유지한다.
- 표시: `godot/effects/machinegun_ricochet.gd`, `machinegun_ricochet.gdshader`, `machinegun_ricochet_flare.gdshader`.
  - 위치: 논리 명중점 + 맞은 적의 차선 표시 오프셋, 높이 0.45(탄체·예광 비행 높이). 접점 섬광은 표면 바깥 0.05, 불티는 0.02 앞에 둔다.
  - 형태: 백열 핵(반지름 0.048)과 접선·수직 십자 갈래, 60ms. 불티 7개는 탄의 반대 방향 ±43~77°, 위로 −9~54°, 속도 2.2~4.4타일/초, 중력 4.5, 수명 90~170ms, 백색→앰버→주황. 표면광 80ms·최대 0.35·반경 0.28. 모두 입체 메시이며 카메라 정면 평면을 쓰지 않는다.
  - 성능: 명중 32발 고정 풀(불티·섬광 MultiMesh 각 1개, 살아 있는 명중이 없으면 숨김). 명중 시 자세·시작 시각·seed만 한 번 기록하고 운동·소멸은 공유 효과 시계로 정점 셰이더가 계산한다. 표면광은 전장 공용 2개. 스테이지 로딩의 `effect_preparation.gd`에서 셰이더를 미리 실행한다.
  - 시계: 효과 항목의 `age`와 프레임 `time`(effectTime)을 사용한다. 정지·배속을 따르고, 시계 되감기·새 전투·표시 비활성에서 슬롯을 비운다. 수명이 지난 뒤 처음 도착한 명중은 재생하지 않는다.

## 검증 (2026-10-11)

- 실제 화면: Godot 4.7.2 Metal Forward Mobile, 데스크톱 720×1472. 개발 fixture 전투(기관총·일반 적)를 고정 시계로 렌더 프레임당 1스텝 진행하고 표시 확인용으로 연사를 6발/초로 올렸다. 같은 명중의 연속 프레임을 비스듬한 시점 1×·드론 시점 1×·비스듬한 시점 4×에서 변경 전후로 촬영했다. 비교 페이지: [`compare/machinegun-hit-compare.html`](compare/machinegun-hit-compare.html). 프레임 이미지는 명중점 주변 180px의 3배 보간 확대이며 원래 크기 비교는 같은 페이지의 `native-*` 이미지다.
- 자동 검사: `godot/verify_machinegun_ricochet.gd`(실제 렌더러 필요) 30항목 통과. 26항목 시점에 변경 전 전투 런타임으로 바꾸면 4항목 실패를 확인했다. 기존 `verify_battlefield_effects`, `verify_effects_cache`, `verify_overlay_cache_integration`, `verify_blast_lifecycle`, `verify_effect_preparation`, `verify_machinegun`, `verify_projectiles` 통과. 네이티브 회귀 `verify_native_combat_runtime`, `verify_legacy_combat_regressions`, `verify_fixed_combat_clock`, `verify_damage_event_collection`, `verify_native_session`, `verify_diamond_event`, `verify_event_batch` 통과.
- 독립 검증: 요청 적합성·범위·계약 PASS. 600초 상대 시계 재기준 뒤 지난 슬롯 재생 결함을 재현해 수정하고 회귀 항목을 추가했다. 이웃 적에 번지던 표면광 반경을 0.4→0.28로 줄였다.
- 미검증: Android 실기기 화면·모바일 GPU 비용, 4배속 다중 포탑 명중의 실기기 프레임 시간, 콘텐츠 전투의 사냥개·탱커·보스 대상 화면.

## 파일

- `machinegun-hit-concepts.html`: 선택 단계 시안.
- `compare/`: 변경 전후 비교 페이지와 JPEG 대표 화면. `video/machinegun-hit-drone-1x.mp4`는 드론 시점 1배속 연속 4초(실제 속도)와 첫 1초의 1/4 속도 재생을 나란히 보여주는 대표 영상이다(같은 fixture·고정 시계, 360px 영역 1.33배).
- `runtime/`: 일회성 캡처 스크립트와 원본 PNG. 로컬 보관, Git 제외.

# 보호막 적 사망 모션

요청(2026-10-15): 스파크가 튀며 휘청이고, 동시에 룬 광원이 깜빡이며 어두워지다가 땅으로 추락한다. 채택한 [보호막 적 게임용 에셋](../shielded-ingame-v1/README.md)의 형상·재질·Idle은 그대로 두고 `Death` 클립과 게임 연출만 추가했다.

## 원본과 제작

- 입력: 채택 게임용 원본 `shielded-01-single-view-ingame-v1.blend`(SHA는 v1 계약과 대조). 이 파일은 덮어쓰지 않는다.
- `author_death.py`를 백그라운드 Blender에서 실행하면 새 원본 `shielded-01-single-view-ingame-death-v1.blend`(SSD)와 `assets/images/stage1_3d/enemies/shielded.glb`를 만든다. 경로·SHA·검사 결과는 `asset-contract.json`에 기록한다.
  ```sh
  /Applications/Blender.app/Contents/MacOS/Blender -b <ingame-v1.blend> --python design/enemy_concepts/2026-10-15/shielded-death-v1/author_death.py
  ```
- 클립(24fps, 1.958초): 프레임 1~17은 부유력이 끊기는 휘청임 키(덜컥이는 기울기·고리 흔들림·부유석 처짐)다. 프레임 17부터는 Blender 강체로 본체가 쓰러지고 고리·돌 4개가 떨어진다. 36프레임 충돌 직후 높은 감쇠로 재시뮬레이션한 정지 자세로 12프레임 동안 보간해 오래 흔들리지 않게 한다. 바닥은 게임의 `MODEL_LIFT`(경로 표면 = 모델 -0.61)다.
- 시작 자세는 Idle 1프레임과 게임의 직립 본체 보정이다. `BodyPivot`의 기본 회전은 원래대로 비워 두고 직립 회전은 `Death` 키에만 둔다.
- Idle은 같은 action을 NLA 트랙으로 다시 내보낸다. `compare_glb.py`로 이전 GLB와 대조해 메시 속성·인덱스·이미지·재질 바이트가 같고 Idle 키 차이가 최대 3.6e-7임을 확인했다. 파일 크기는 8,737,840 → 8,756,248 B(+18,408 B, Death 키)다.
- 제작 검사는 전 48프레임에서 부품 간 BVH 겹침 0, 바닥 아래 0(고리 메시 접촉 보정 최대 2.3mm)이다. 같은 입력으로 다시 실행하면 같은 GLB SHA가 나온다.

## 게임 연결

- `godot/effects/shielded_death.gd`: 처치 시점의 전투 시계로 Idle과 직립 보정을 샘플링해 실제 표시 자세에서 0.12초 동안 `Death`로 이어 붙인다. 이후 클립을 전투 시계로 seek하여 일시정지·배속·되감기를 따른다. 정지 자세를 0.25초 유지하고 0.35초 동안 디더로 사라진다(총 2.56초).
- 룬 출력은 1/30초 단위로 정한 깜빡임 패턴에 덜컥임 순간의 번쩍임을 더한다. 0.2~0.9초 사이에 꺼지며 발광·수정 밝기와 기존 전후 OmniLight 두 개에 같은 값을 쓴다. `shielded_death_body.gdshader`는 원래 albedo/normal/발광 맵을 그대로 쓰고, 꺼진 만큼 발광 마스크 부위 albedo를 최대 65% 낮춘다.
- 스파크는 덜컥임 4회와 착지 1회에 14개씩 튄다. 공유 MultiMesh 하나와 `shielded_death_sparks.gdshader`가 전투 시계만으로 위치를 계산하며, 버스트 시각은 스크립트와 셰이더에 같은 값으로 둔다.
- `guardian_preview.gd`의 기존 처치 전달 경로에 `shielded`를 추가했다. 로딩 예열(`effect_preparation.gd`)에서 사망 셰이더를 미리 그리고, 스테이지에 보호막 적이 없으면 캐시를 해제한다.

## 확인 범위

2026-10-15 Godot 4.7.2 / Apple M4 / Mobile(Metal), 440×900 데스크톱 앱.

- `verify_shielded_death.gd`(115개): 실제 표시 자세에서 시작, 클립 길이, 전 구간 바닥 위, 일시정지·되감기 재현, 깜빡임·소등, 스파크 표시 구간, 페이드, 캐시 공유·해제를 확인한다. `RUNE_SHIELDED_DEATH_CAPTURE_DIR`를 주고 렌더러로 실행하면 실제 Stage 10 앱에서 런타임 화상 피해로 처치하고 공식 세션을 진행하며 90프레임을 촬영한다.
- 관련 검사 `verify_death_presentation_delivery.gd`(보호막 포함 7종), `verify_shielded_presentation.gd`, `verify_effect_preparation.gd`, `verify_stage_effect_cache.gd`, `verify_target_geometry_preparation.gd`, `verify_effects_cache.gd`, `verify_skinned_enemy_presentation.gd`, `verify_boss_death.gd`, `verify_combat_presentation_determinism.gd`, `verify_enemy_burn.gd`, `verify_enemy_frost.gd`가 통과했다.
- 실제 화면 촬영과 영상은 로컬 `build/ignored/shielded-death/`(`game/`, `shielded-death-ingame*.mp4`)에 보관하며 새 체크아웃의 필수 입력이 아니다. Android/APK·모바일 GPU 성능은 실행하지 않았다.

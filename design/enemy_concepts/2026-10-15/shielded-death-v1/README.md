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
- 진행 방향 보정은 생존·사망 모델의 공통 부모에 약 +12.37°를 똑같이 적용한다. 본체·고리·네 돌의 상대배치·휘청임·낙하 궤적을 조립체 전체로 회전하므로 원래 간격과 구운 접지를 보존한다. 기존 0.12초 이어붙임이 처치 순간의 실제 생존 자세를 그대로 받으며, 정지·되감기에는 변하지 않는 클립 시작 자세를 복원하여 변환 분해의 미세한 scale 오차가 누적되지 않게 한다. GLB와 Blender 사망 원본은 변경하지 않는다.
- 룬 출력은 1/30초 단위로 정한 깜빡임 패턴에 덜컥임 순간의 번쩍임을 더한다. 0.2~0.9초 사이에 꺼지며 발광·수정 밝기와 기존 전후 OmniLight 두 개에 같은 값을 쓴다. `shielded_death_body.gdshader`는 원래 albedo/normal/발광 맵을 그대로 쓰고, 꺼진 만큼 발광 마스크 부위 albedo를 최대 65% 낮춘다.
- 후속 전기 표현 교정은 덜컥임 4회·착지 1회의 타이밍을 유지하고, 직선 상자 불티를 실제 3D 분기 전류와 접점 코로나로 교체한다. `lightning-A-approved.blend`에서 추출·구운 기존 `lightning_attack_meshes/beam04.res`와 `impact.res`를 그대로 재사용하며 라이트닝 공격 자체의 메시·셰이더·전투는 바꾸지 않는다. 청백색 가는 중심과 옅은 청록 외피를 한 표면에서 그려 31ms 이내의 첫 파열·44~82ms 재점화·106~132ms 잔방전으로 끊어지게 한다. 접점의 작은 가지 잔광도 180ms 안에 끝난다.
- 본체 룬의 발광 삼각형 중심과 고리·네 돌의 실제 메시 정점을 로딩 중 한 번 골라 공유한다. 재생 시에는 현재 구운 자세의 변환만 적용해 전류 양끝을 움직이는 표면에 붙이며, 마지막 접점은 모델 높이 0.61에 대응하는 실제 경로 표면을 따른다. 광원은 기존 룬 OmniLight 두 개만 짧은 접점 반응으로 재사용한다. 별도 광원·벽시계·누적 입자 시뮬레이션·매 프레임 곡선 생성은 없다.
- 전류 3개와 접점 2개를 각각 하나의 공유 MultiMesh로 묶는다. 이전 70개 상자/840삼각형·1배치에서 총 6,160삼각형·2배치로 기하 비용이 늘며, 이 수치를 성능 개선으로 해석하지 않는다. 두 메시·재질·접점 자료는 로딩 예열하고 보호막형이 없는 스테이지로 전환하면 해제한다. 보호막형만 등장하고 라이트닝 포탑이 없어도 두 리소스를 사전 로딩한다.
- `guardian_preview.gd`의 기존 처치 전달 경로에 `shielded`를 추가했다. 로딩 예열(`effect_preparation.gd`)에서 사망 셰이더를 미리 그리고, 스테이지에 보호막 적이 없으면 캐시를 해제한다.

## 확인 범위

2026-10-15 Godot 4.7.2 / Apple M4 / Mobile(Metal), 440×900 데스크톱 앱.

- `verify_shielded_death.gd`(434개): 실제 표시 자세에서 시작, 클립 길이, 접지 보존, 일시정지·되감기 재현, 깜빡임·소등, 전기 방전의 실제 표면 부착·별도 위상·2배치 기하 예산·보호막형 단독 사전 로딩, 페이드와 캐시 공유·해제를 확인한다. `RUNE_SHIELDED_DEATH_CAPTURE_DIR`를 주고 렌더러로 실행하면 실제 Stage 10 앱에서 런타임 화상 피해로 처치하고 공식 세션을 진행하며 90프레임을 촬영한다(총 529개 항목).
- 관련 검사 `verify_death_presentation_delivery.gd`(보호막 포함 7종), `verify_shielded_presentation.gd`, `verify_effect_preparation.gd`, `verify_stage_effect_cache.gd`, `verify_target_geometry_preparation.gd`, `verify_effects_cache.gd`, `verify_skinned_enemy_presentation.gd`, `verify_boss_death.gd`, `verify_combat_presentation_determinism.gd`, `verify_enemy_burn.gd`, `verify_enemy_frost.gd`가 통과했다.
- 실제 화면 촬영과 영상은 로컬 `build/ignored/shielded-death/`(`game/`, `shielded-death-ingame*.mp4`)에 보관하며 새 체크아웃의 필수 입력이 아니다. Android/APK·모바일 GPU 성능은 실행하지 않았다.

진행 방향 교정 최종 검증은 `build/ignored/shielded-facing-fix/final-death-checks.json`(자동 회귀)과 `final-death/`·`final-death.log`(실제 Stage 10 처치·90프레임, 총 477개 항목)다. 생존→사망의 방향·이어붙임·낙하·접지·퇴장을 실제 화면에서 확인했다. 독립 검증은 Death 308자세의 본체/다른 부품 교차 0, 여섯 부품의 원본 강체 곡선과 높이 보존을 확인했고, `.051/.119초` 이어붙임을 포함한 1,000회 정지 샘플링과 처치 시계 세 시각에서 다른 시간 방문 후 되감기에도 변환 오차 0을 확인했다(`independent/final-death-geometry-report.json`, `pause-final.log`). Android/APK는 이번 방향 교정에서도 실행하지 않았다.

전기 VFX 최종 근거는 `build/ignored/shielded-electric-vfx/`다. `checks.json`의 사망·사망 전달·효과 예열·스테이지 캐시 네 사례와 후속 `final-death-check.json`을 통과했고, 실제 Stage 10 기본(`wide/`)·드론 확대(`zoom/`)에서 가는 분기 전류·재점화·모델 가림 없는 짧은 섬광을 확인했다. 착지는 주변 살아 있는 적의 시각 root만 숨긴 같은 Stage 10 보조 촬영(`isolated/`, `impact-sheet.png`)으로 바닥 방전·접점 섬광을 추가 확인했다. 세 촬영은 각각 529개 항목을 통과했다. 독립 계약 214개에서 실제 접점 부착·정지·되감기·자원 공유·2배치·광원 두 개 유지가 통과했고, 직전 방향 교정본과 비교한 생존·사망 자세 차이는 0이다(`independent/contract.log`, `preservation.json`, `rune-contact.json`). 변형 정점도 460개 시각·재점화 회전 경계에서 모두 custom AABB 안에 있으며 최소 여유는 6.27cm다(`independent/bounds-report.json`). Android/APK·모바일 GPU 성능은 미검증이다.

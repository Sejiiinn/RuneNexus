# 일반 골렘 v2 게임 연결

범위: 사용자가 승인한 갈색 이끼 석재 일반 골렘을 기존 `normal` 적에 연결한다. 큰 머리·짧고 두꺼운 팔다리·보라색 이마 룬·붉은 눈과 핵·1K 기본색과 실제 tangent normal을 보존한다. 같은 승인 원본의 Death를 유지하며 붕괴 후 잔해가 자연스럽게 사라지는 표시 처리를 연결한다. 장갑·실드·빠름·탱커·보스와 전투·저장 계약은 변경하지 않는다.

## 원본과 출력

편집 원본과 승인 복합 GLB는 사용자 외장 SSD 보관 정책에 따라 아래에 유지한다. 저장소에 별도 `.blend` 백업을 만들거나 열린 Blender를 바꾸지 않는다. 기존 제작 버전도 유지한다.

- SSD 작업 폴더: `/Volumes/KIOXIA_MAC/AI-3D/projects/RuneNexus/normal-multiview-20261007-v3/animation-rig-v2`.
- 편집 원본: `blender/stonegolem-rig-walk-death-v2.blend`, SHA256 `8004975f8c635afa3638793e2eca1f73b371a28c5b8193bf050b06704cd8de73`.
- 승인 GLB: `exports/stonegolem-rig-walk-death-v2.glb`, SHA256 `bfbc450101e547ad162c58c62cc22bc429ac8be051eae0d4a40b06f6813b750b`.
- 8,923삼각형·14뼈, Walk 1.6초·Death 1.4초. 원본 팔꿈치 굽힘 25~35°와 팔 시차를 유지한다. GLB의 30Hz LINEAR/STEP 키는 수학적 C1 곡선으로 간주하지 않는다.
- 게임용 Walk SSD 폴더: `/Volumes/KIOXIA_MAC/AI-3D/projects/RuneNexus/normal-multiview-20261007-v3/animation-ingame-v1`. 편집 원본 `blender/stonegolem-ingame-walk-v1.blend`, SHA256 `b35fe572e2a0f7bb9446ebe154867dd58fd3c2b489b5f19e82308e3a17f912af`; GLB `exports/stonegolem-ingame-walk-v1.glb`, SHA256 `8bda2628b6800db14b9337eeaad23603f49504b45b16302e5ef1be401e9ec0ef`.
- 게임 출력: `assets/images/stage1_3d/enemies/normal.glb`와 `normal_death.glb`. [출력 계약](runtime-contract.json)에 SHA와 경로를 기록한다. 두 출력의 기본색·normal은 빌드 시 같은 콘텐츠 해시 경로로 공유된다.

[export_runtime.py](export_runtime.py)는 승인 GLB의 메시·스킨·재질·이미지·선택한 클립의 키 및 전체 BIN을 그대로 두고 Walk/Death를 분리한다. 공용 부모에 1.0940977489373418 균등 배율만 추가하여 이전 일반 적의 rest 높이 1.097729445를 유지한다. +Z 전방·Y-up은 동일하며 별도 색 보정이나 형상 변경은 없다. 콘텐츠 `.55`와 기존 표시 확대 `1.15`는 유지한다.

## 게임 동작과 상태 효과

`godot/presentation/guardian_preview.gd`가 normal Walk와 Death를 명시적으로 선택한다. Walk 위상은 native 이동 거리, 방향 보간·사망은 전투 시계를 사용한다. 일시정지·배속·감속·순간이동·역행의 기존 책임을 유지한다. 탱커의 Walk·보폭과 사망 재생은 [탱커 게임 연결](../../2026-10-09/tank-game-integration/README.md)의 별도 계약을 따른다. 일반 사체는 승인 Death를 1.4초 전부 재생하고 마지막 자세를 0.10초 유지한 뒤 0.35초 동안 부드럽게 사라진다. `normal_death.gd`는 붕괴 중 원래 PBR 재질을 유지하며, 퇴장 구간에서는 일반 전용 셰이더에 원래 기본색·tangent normal·roughness·발광 맵과 계수를 전달한다. 탱커·보스와 같은 화면 고정 coverage/discard로 표면을 점진적으로 지우며 불투명 깊이와 눈·핵의 가림을 유지한다. 1.85 전투초에 표시 사체만 정리하며 처치·보상·저장과 다른 적의 퇴장 시간은 변경하지 않는다.

기존 화상·성에 모양을 새 스킨에 `scripts/bake_skinned_enemy_status.gd -- normal`로 굽는다. `normal_status_burn.res`, `normal_status_frost_shards.res`, `normal_status_frost_grains.res`만 갱신한다. 상태 좌표 배율은 실제 Godot 가져오기에서 확인한 1.094098을 사용한다. 성에는 보라색 룬과 붉은 눈/핵을 기존 보호 옵션으로 보존하며 다른 종의 부착 자료는 유지한다.

## 검증 상태

2026-10-08 Godot 4.7.2 공식 Mobile/Metal·Apple M4에서 실제 스테이지 1 웨이브 3의 앱 HUD와 native 전투를 실행했다. 기존 검수 경로의 격리 checkpoint와 명시적 건설 예산 fixture를 사용하며 서비스 시작 UI만 생략한다. 포탑 공격·상태·이동·처치는 실제 게임 경로다. 모델의 게임 표시 크기와 갈색 이끼·룬·눈/핵, 기존 전장·HUD 연결, 화염/냉각 공격과 사체 해제를 확인했다.

관련 skinned enemy·화상 184개·성에 327개·효과 준비 검사와 native enemy state·wave/core·teleport·combat runtime 4회귀가 통과했다. 구체적인 실행 로그·영상·일회성 드라이버와 이전 파일은 로컬 `verification/`에 보관하고 Git 추적에서 제외한다.

원본의 짧은 접지 보폭에서 실제 전장 반복이 빨라 게임용 Walk의 발 IK를 조정했다. 형상·텍스처·뼈 길이·바인드·승인 팔꿈치 25~35°와 시차·Death는 동일하다. 게임용 native 보폭 `.44`, stance `.56`, 골반 추가 하강 `.034`이며 표시 배율 적용 보폭 `.3044874035`타일이다. 기존 normal 속도 `.65625`타일/초에서 한 주기는 `.4639808054`전투초다. 상태 부착 자료의 메시·스킨 입력은 동일하므로 재사용한다. 최종 실제 전장과 독립 확대 검수에서 보행·코너·4x 배속에 눈에 띄는 발 미끄러짐, 무릎 반전이나 튐이 없음을 확인했다. 1초 일시정지는 clock·position·rotation·phase가 정확히 멈추고 재개 및 4x 진행은 각각 1/30초·4/30초였다. 실제 게임 스킨의 49개 위상에서 최저 지면 여유는 `.0008788`타일로 관통이 없었으며, 화상·성에는 해당 메시의 스킨과 skeleton을 따른다. 부모도 최종 기본·상태·확대 실제 화면을 확인했고 데스크톱 판정은 통과했다.

퇴장 후처리의 관련 skinned 검사는 0건 실패로 통과했다. 최종 붕괴 자세 유지·원래 재질과 발광 맵/계수 보존·coverage 중간값·일시정지·4x 시간 간격·붕괴 구간 되감기·1.85초 제거와 하운드/탱커의 기존 수명을 확인했다. 일반 전용 셰이더가 탱커·보스와 정확히 같은 화면 고정 coverage/discard 수식을 사용하며 ALPHA 출력을 하지 않는 것도 확인했다. 같은 실제 전투의 최종 1x 영상에서 붕괴 뒤 잔해 표면이 점진적으로 사라지고 완전히 제거되는 구간을 확인했다. 독립 검증자는 최종 실제/보조 영상을 직접 재생해 석재 퇴장 일치·마지막 자세 유지·밝기 튐과 핵 잔상 없음을 확인했다. 기존 runtime 14개 검사와 동시 사체의 독립 fade 근거는 셰이더 연결 외 시간·동작 로직의 동일성을 대조하여 재사용했다. 탱커·보스 생산 셰이더와 사망 동작은 변경하지 않았다. 겹친 생존 적의 몸과 일부 표시층을 가린 보조 영상은 native 공격·생성·전투 시계와 앱 HUD를 유지하며, 실제 전투 영상과 구분해 로컬에 보관한다.

편집 프로젝트 helper는 기존 `build/godot/editor/project.godot`의 별도 변경을 보존하고 중단했으므로 MCP 편집 프로젝트 동기화는 미확인이다. 검증은 준비한 `build/godot/project` 직접 실행으로 수행했다. Android 실기기·APK·배포·성능 검증은 수행하지 않았다.

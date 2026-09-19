# 스테이지 1 Blender 작업 허브

현행 작업 진입점. 독립 식물·추가 환경 장식 원본의 맵 조립 경로 반영: 2026-09-12. `rune-nexus-stage1.blend`를 연다.

- **00 Start**: 내부 Text Editor의 시작 안내·원본 목록·수정 절차.
- **01 Models**: 상단 Scene 선택기로 지형, 현행 포탑, 적, 포구 프레임을 확인한다.
- Scene **01 Terrain**: [표면 질감 보강 원본](../surface_effects/README.md)의 `terrain-surface.blend`. 기존 형상·색·노멀을 유지하고 전체맵의 cavity와 돌·이끼 거칠기를 보강한 현행 출력 원본이다.
- Scene **09 Machine Gun Muzzle 3D**: Godot 기관총의 입체 포구 화염 원본. 체적 연기와 불티는 [게임 효과 소스](../machinegun_muzzle_3d/README.md)에서 제어한다.
- Scene **10 Environment Dressing**: 풀·고사리·넓은 잎·이끼돌·뿌리가 겹치는 비대칭 군락과 바람 미리보기. 기존 지형은 연결 참조이며, [환경 장식 제작·출력](../environment_dressing/README.md)과 내부 `05_환경장식_제작_절차`를 따른다. 게임은 두 병합 메시와 공유 정점 셰이더를 사용한다. [최근 Android 적용 화면·검증](../surface_effects/verification/common-shadow-implementation-20260913/README.md)은 Blender 제작 렌더와 구분한다.
- Scene **11 Grass Master ~ 14 Groundcover Master**: [독립 식물 4종](../environment_dressing/plant_library/README.md). 각 식물의 줄기·잎을 별도로 편집하며 내부 `06_식물_독립원본`을 따른다. 저장된 원본을 맵용으로 복사·배치한 결과가 Scene 10이며, 원본을 직접 바꾸지 않는다.
- Scene **15 Wildflower Master ~ 21 Exposed Root Master**: [꽃·돌·이끼·덩굴·뿌리 7종](../environment_dressing/companion_library/README.md). 내부 `07_추가환경_독립원본`과 정지 검수 이미지를 따른다. 맵 배치·병합 출력은 Scene 10에서 확인한다.
- Scene **22 Portal Master / 23 Core Master**: [A안 공용 포탈·코어](../portal_core_concepts/README.md). 바닥 없는 독립 원본이며 두 장면에서 각각 편집한다. 내부 `08_포탈코어_공용원본`에 내보내기·애니메이션 계약이 있다.
- Scene **24~27 Chapter 1 Stage 2~5 Dressing**: [2~5 환경 장식](../../chapter1_3d/environment/README.md). 기존 승인 군락을 각 실제 맵에 재배치한 편집 원본이며, 스테이지 1 원본과 독립적으로 보존한다.
- Scene **28 Cannonball**: [둥근 철구 포탄](../projectiles/README.md)의 `cannonball.blend`. 저장한 수동 편집은 `build_cannonball.py -- --export-only`로 내보낸다. 기본 재생성은 기존 원본을 덮어쓰므로 두 경로를 구분한다. 승인 철구 시안과 원본 검수 렌더는 해당 제작 안내에서 확인한다.
- Scene **29 Chapter 2 Tiles / 30 Rune Pillar / 31 Crystal Cluster / 32 Void Fissure**: [챕터 2 균열 유적](../../chapter2_3d/README.md)의 길·건설 타일과 독립 외곽 소품. 소품은 각 장면에서 한 종류씩 연결해 확인하며 실제 편집은 안내에 연결된 원본에서 수행한다.
- **02 Game Preview**: 게임에 적용된 v5 폭발의 실제 게임 캡처. 이미지 선택기로 승인 시안도 확인한다.
- **02 Game Preview**의 이미지 선택기에서 `MOVIE`를 선택하면 같은 게임 효과의 두 시점 영상을 확인할 수 있다. Movie Clip 데이터에도 영상을 등록했다.

모델은 원본 `.blend`에 연결된 읽기 전용 라이브러리다. 원본을 수정하고 저장한 뒤 허브를 다시 열면 기존 연결 데이터가 갱신된다. 실제 편집은 내부 `01_현행원본`에 적힌 원본 파일을 연다. 허브에서 Make Local로 복제하여 별도 원본을 만들지 않는다. 새 객체·원본 경로·게임 미리보기를 추가하거나 바꾸면 `catalog.json`을 수정하고 허브를 다시 생성한다.

## 룬 화염 포탑 원본

- [룬 화염 포탑](../../fire_tower_concepts/runic_3d/README.md): 사용자가 선택한 14번 시안의 독립 Blender 제작 원본. 길쭉한 팔각 몸체·주황 룬 홈·청동 음각 지지대·작은 상부 화염구를 따른다. 후속 이관 승인으로 `magic.glb`를 교체했다. **33 Runic Fire Turret**는 구운 기본 PBR 이관 원본이며 원형 편집은 링크의 승인 Blender 원본에서 한다. 효과는 Godot 기본 재질·GPU 파티클로 재생한다.

## 갱신

저장소 루트에서 별도 Blender 백그라운드 프로세스로 다음 스크립트를 실행해야 한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/stage1_3d/blender_workspace/sync_workspace.py
```

스크립트는 백그라운드 프로세스의 Scene을 초기화하며, 편집 중인 Blender UI에서의 실행은 차단한다. 재생성 전 허브의 `USER_` 메모를 저장하고, 재생성 후에는 새 허브를 다시 연다. 이전 허브가 열린 창에서 저장하면 새 결과를 덮어쓰므로 재생성 후 기존 창의 내용을 저장하지 않는다. 기존 허브는 `rune-nexus-stage1.previous.blend`로 백업하며 `USER_`로 시작하는 내부 Text 메모는 새 허브에도 보존한다. 원본 모델·게임 에셋을 변경하거나 내보내지 않는다. 전체 폴더 구조를 유지하여 상대 경로를 보존한다.

## 수정부터 게임 반영까지

반복 이관 경로는 `catalog.json`의 `workflows`에 원본·기존 스크립트의 진입 함수·최종 출력·관련 검사를 연결한다. 현재 룬 화염 포탑과 화상 효과를 등록했다. 저장소 루트에서 다음 명령으로 해당 경로와 출력 크기·해시를 확인한다.

```sh
python3 scripts/asset_workflow_report.py
python3 scripts/asset_workflow_report.py runic-fire --json-out build/reports/runic-fire.json
python3 scripts/asset_workflow_report.py enemy-burn --json-out build/reports/enemy-burn.json
```

요약은 읽기 전용이며 Blender 제작·패키징·검증을 실행하지 않는다. 기존 검사 기록도 현재 출력에 대한 성공 근거로 자동 승격하지 않는다. 제작 스크립트는 현재 checkout의 절대 `ROOT`와 승인 원본 장면을 전제로 하므로 다른 위치에서 재사용할 때 실제 경로를 확인한다. 등록 경로의 스크립트를 수정했으면 진입점도 함께 갱신한다. 이 메타데이터 변경만으로 Blender 허브를 재생성할 필요는 없다.

과거 `24 Fern Canopy Shadows`는 공통 그림자 전환으로 현행 목록에서 제외했다. 편집 원본은 제작 이력으로 보존하며, 실제 잎의 그림자·LOD 계약은 [환경 장식 안내](../environment_dressing/README.md)를 따른다.

1. 내부 원본 목록에서 해당 `.blend` 또는 효과 소스를 연다. 객체 계층·조준·반동·포구 노드 계약은 유지한다.
2. 각 제작 폴더 README에 따라 GLB 또는 프레임을 내보낸다. 2D 보정·알파·패킹은 GIMP에서 마무리한다. `build_turrets.py`는 여섯 포탑을 모두 다시 생성하므로 최신 기관총·냉각·대포 후속 보정도 필요하다. 수작업 Blender 편집을 이 생성기가 자동 반영하지 않는다.
3. 최종 에셋은 `assets/images/stage1_3d/`에 저장하고 실제 게임 크기·프레임 순서·반복·시점을 확인한다. 검증 기준은 저장소 `DESIGNS.md`와 `.agents/in_app_test_guide.md`를 따른다.
4. 변경된 원본 대응·절차·검수 자료를 갱신한다. 게임 적용 여부와 마지막 검증은 내부 `USER_작업메모`에 남기고 허브를 저장한 뒤 재생성한다. `04_확인기록`은 매번 재생성하는 기준 시점의 자동 요약이므로 직접 편집하지 않는다.

## 현재 폭발과 이전 작업 구분

현재 포탄 폭발은 Blender 시뮬레이션이 아닌 게임 3D 필드 캐시다. `cannon_impact/field_cache/bake_field.py`와 `noise32.bin`이 베이크 원본이며, `procedural_source.dart.txt`는 참고용 코드 스냅샷이다. 결과는 `assets/images/stage1_3d/effects/cannon_field.bin`과 `.json`, 런타임은 `lib/game/rendering/stage1_3d/cannon_impact_field.dart` 및 `battlefield_impact_effects.dart`다. 캐시 밀도·방사·열을 런타임에서 보간하고 짧은 섬광·파편 등을 함께 렌더한다. 상세는 `cannon_impact/field_cache/README.md`를 따른다.

`cannon_impact/v2/production/cannon_export.blend`와 이전 폭발 Scene들은 과거 화염구 작업이다. 최신 폭발 원본으로 사용하지 않는다. 허브의 게임 영상은 Blender 렌더가 아니며, Blender에서 현재 효과를 직접 편집·재생하는 시뮬레이션은 없다.

환경 상위 편집 원본은 `actor_refinement/stage1-actors-refined.blend`다. 이 파일의 포탑 배치는 과거 스냅샷이다. `append_source_environment.py`, `bake_authored_floor_atlas.py`의 절차는 `environment/README.md`를 따른다. Blender 조명 변경은 게임의 조명 코드에 자동 동기화되지 않는다.

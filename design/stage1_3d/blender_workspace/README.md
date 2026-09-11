# 스테이지 1 Blender 작업 허브

현행 작업 진입점. 확인: 2026-09-11. `rune-nexus-stage1.blend`를 연다.

- **00 Start**: 내부 Text Editor의 시작 안내·원본 목록·수정 절차.
- **01 Models**: 상단 Scene 선택기로 지형, 현행 포탑, 적, 포구 프레임을 확인한다.
- Scene **09 Machine Gun Muzzle 3D**: Godot 기관총의 입체 포구 화염 원본. 체적 연기와 불티는 [게임 효과 소스](../machinegun_muzzle_3d/README.md)에서 제어한다.
- **02 Game Preview**: 게임에 적용된 v5 폭발의 실제 게임 캡처. 이미지 선택기로 승인 시안도 확인한다.
- **02 Game Preview**의 이미지 선택기에서 `MOVIE`를 선택하면 같은 게임 효과의 두 시점 영상을 확인할 수 있다. Movie Clip 데이터에도 영상을 등록했다.

모델은 원본 `.blend`에 연결된 읽기 전용 라이브러리다. 원본을 수정하고 저장한 뒤 허브를 다시 열면 기존 연결 데이터가 갱신된다. 실제 편집은 내부 `01_현행원본`에 적힌 원본 파일을 연다. 허브에서 Make Local로 복제하여 별도 원본을 만들지 않는다. 새 객체·원본 경로·게임 미리보기를 추가하거나 바꾸면 `catalog.json`을 수정하고 허브를 다시 생성한다.

## 갱신

저장소 루트에서 별도 Blender 백그라운드 프로세스로 다음 스크립트를 실행해야 한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/stage1_3d/blender_workspace/sync_workspace.py
```

스크립트는 백그라운드 프로세스의 Scene을 초기화하며, 편집 중인 Blender UI에서의 실행은 차단한다. 재생성 전 허브의 `USER_` 메모를 저장하고, 재생성 후에는 새 허브를 다시 연다. 이전 허브가 열린 창에서 저장하면 새 결과를 덮어쓰므로 재생성 후 기존 창의 내용을 저장하지 않는다. 기존 허브는 `rune-nexus-stage1.previous.blend`로 백업하며 `USER_`로 시작하는 내부 Text 메모는 새 허브에도 보존한다. 원본 모델·게임 에셋을 변경하거나 내보내지 않는다. 전체 폴더 구조를 유지하여 상대 경로를 보존한다.

## 수정부터 게임 반영까지

1. 내부 원본 목록에서 해당 `.blend` 또는 효과 소스를 연다. 객체 계층·조준·반동·포구 노드 계약은 유지한다.
2. 각 제작 폴더 README에 따라 GLB 또는 프레임을 내보낸다. 2D 보정·알파·패킹은 GIMP에서 마무리한다. `build_turrets.py`는 여섯 포탑을 모두 다시 생성하므로 최신 기관총·냉각·대포 후속 보정도 필요하다. 수작업 Blender 편집을 이 생성기가 자동 반영하지 않는다.
3. 최종 에셋은 `assets/images/stage1_3d/`에 저장하고 실제 게임 크기·프레임 순서·반복·시점을 확인한다. 검증 기준은 저장소 `DESIGNS.md`와 `.agents/in_app_test_guide.md`를 따른다.
4. 변경된 원본 대응·절차·검수 자료를 갱신한다. 게임 적용 여부와 마지막 검증은 내부 `USER_작업메모`에 남기고 허브를 저장한 뒤 재생성한다. `04_확인기록`은 매번 재생성하는 기준 시점의 자동 요약이므로 직접 편집하지 않는다.

## 현재 폭발과 이전 작업 구분

현재 포탄 폭발은 Blender 시뮬레이션이 아닌 게임 3D 필드 캐시다. `cannon_impact/field_cache/bake_field.py`와 `noise32.bin`이 베이크 원본이며, `procedural_source.dart.txt`는 참고용 코드 스냅샷이다. 결과는 `assets/images/stage1_3d/effects/cannon_field.bin`과 `.json`, 런타임은 `lib/game/rendering/stage1_3d/cannon_impact_field.dart` 및 `battlefield_impact_effects.dart`다. 캐시 밀도·방사·열을 런타임에서 보간하고 짧은 섬광·파편 등을 함께 렌더한다. 상세는 `cannon_impact/field_cache/README.md`를 따른다.

`cannon_impact/v2/production/cannon_export.blend`와 이전 폭발 Scene들은 과거 화염구 작업이다. 최신 폭발 원본으로 사용하지 않는다. 허브의 게임 영상은 Blender 렌더가 아니며, Blender에서 현재 효과를 직접 편집·재생하는 시뮬레이션은 없다.

환경 상위 편집 원본은 `actor_refinement/stage1-actors-refined.blend`다. 이 파일의 포탑 배치는 과거 스냅샷이다. `append_source_environment.py`, `bake_authored_floor_atlas.py`의 절차는 `environment/README.md`를 따른다. Blender 조명 변경은 게임의 조명 코드에 자동 동기화되지 않는다.

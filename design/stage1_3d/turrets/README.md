# 스테이지 1 실제 3D 포탑

2026-09-11. 기존 전체 해금 계정도 스테이지 1에서 쓸 수 있도록 TurretType 6종을 제공한다. 전체 작업·게임 적용 상태는 [Blender 작업 허브](../blender_workspace/README.md)에서 확인한다.

- 게임 파일: `assets/images/stage1_3d/turrets/{arrow,cannon,magic,frost,sniper,lightning}.glb`.

| 게임 모델 | 현행 편집 원본 | 제작 경로 |
| --- | --- | --- |
| `arrow.glb` — 기관총 | `machine-gun-refined.blend` | `refine_machine_gun.py` |
| `cannon.glb` — 대포 | `cannon_tone_refinement/cannon-muted-orange.blend` | 최초 제작 `build_turrets.py`, 마지막 도장 보정 `cannon_tone_refinement/refine_tone.py` |
| `frost.glb` — 냉각 | `frost_refinement/frost.blend` | `frost_refinement/build_frost.py` |
| `magic.glb`, `sniper.glb`, `lightning.glb` | `chapter-one-turrets.blend` | `build_turrets.py` |

`build_turrets.py`는 **여섯 게임 GLB를 모두 덮어쓴다**. 단독 실행하면 최신 기관총·냉각 형태와 대포 도장 보정이 이전 상태로 돌아가므로 전체 재생성 뒤에는 위 세 후속 제작 경로를 적용해야 한다. 기존 Blender 편집 내용을 스크립트가 자동 반영하는 구조는 아니다.

`refine_tone.py`는 기존 `cannon.glb`의 재질 JSON만 보정하며 Blender 원본을 저장하지 않는다. `cannon-muted-orange.blend`는 보정 GLB를 별도로 import·저장한 편집본이다. 이 파일에서 새로 편집한 내용은 계약 노드를 보존한 별도 GLB 내보내기가 필요하며, 그 내보내기를 자동화하는 스크립트는 아직 없다.

## 기타 포탑 수작업 내보내기

`chapter-one-turrets.blend`에서 `magic`·`sniper`·`lightning`을 편집한 경우에 적용한다. 저장된 원본은 갤러리 배치이며, 게임 GLB를 내보낸 뒤 네 계약 노드에 종류 접두사를 붙이고 루트를 이동한 상태다. `build_turrets.py`를 다시 실행하면 수작업 편집이 재생성 결과로 대체된다.

1. 형태·재질 편집을 원본에 저장한다. 내보내기 전용 사본을 `design/stage1_3d/turrets/` 아래 별도 `.blend`로 저장하고 아래 조정은 사본에서만 수행한다.
2. 대상 종류의 루트와 모든 자손만 남긴다. 다른 포탑, 갤러리 바닥·카메라·광원을 제외한다.
3. 대상의 `<kind>_turret_root`, `<kind>_turret_head`, `<kind>_turret_barrel`, `<kind>_muzzle` 이름을 각각 `turret_root`, `turret_head`, `turret_barrel`, `muzzle`로 복원한다. 이름 뒤 `.001` 같은 중복 접미사가 없는지 확인한다.
4. `turret_root`의 Location을 `(0, 0, 0)`으로 복원하여 갤러리 이동을 제거한다. 자식의 로컬 변환·부모 관계는 유지하며 루트 이동을 메시나 자식에 적용하지 않는다.
5. 루트와 모든 자손을 선택하고 GLB로 내보낸다. 선택 객체만·현재 Scene만 포함하며, 애니메이션·카메라·광원은 제외하고 glTF의 +Y 위 축 변환을 유지한다. 출력은 해당 `assets/images/stage1_3d/turrets/<kind>.glb`다.
6. 내보낸 GLB의 단일 Scene, 원점의 루트, 네 계약 노드와 계층을 확인하고 게임에서 조준·반동·포구 위치를 검증한다. 내보내기용 이름·위치 조정은 원래 갤러리 편집 원본에 덮어쓰지 않는다.

## 최초 제작과 후속 개선

- 최초 기관총·저격·화염·냉기·번개는 `lib/game/rendering/turret_shape_renderer.dart`의 현행 실루엣·색·상부 구조를 실제 부피로 구현했다.
- 대포의 최초 형태는 `design/high_fidelity_battlefield/cannon_material_refinement/battlefield-cannon-matte.blend`의 Cannon_Root 하위 원본을 가져왔다. 장식 추가안이 아닌 원래 대포다. 이후 위 경로에서 주황 도장의 붉은 성분을 낮췄다. 도장은 roughness 0.89, 노멀/도장 색 변화는 512×512 두 장으로 구워 GLB에 내장했다.

## 좌표와 조작 연결

단위 1 = 타일 한 칸. glTF +Y 위, +Z 전방. 받침 최대 폭 약 0.76~0.83. 루트 바닥 기준, 상부 조준 회전 초기값 0. 모델 전체를 회전시키지 않고 `turret_head.rotation.y`를 사용한다.

```
turret_root
├─ 고정 받침 mesh
└─ turret_head (회전 상부; +Y 0.26~0.30)
   ├─ 상부 mesh
   └─ turret_barrel (반동; 초기 위치 0,0,0)
      ├─ 포신 mesh (냉기는 없음)
      └─ muzzle (발사 원점)
```

반동은 `turret_barrel.position.z` 음수 방향. 포구는 `muzzle.getWorldPosition` 사용. 냉기 포구는 결정 위쪽이다. `manifest.json`은 제작 원본 Blender 좌표(+Z 위/-Y 전방)를 기록하므로 glTF 해석 시 (x,z,-y)로 변환한다.

각 GLB의 4개 계약 노드 이름·초기 회전·포구 방향과 단일 scene을 파싱해 확인했다. `turret-library-preview.png`는 최초 라이브러리의 Blender 검수 렌더이며 최신 세 후속 개선이나 게임 화면을 나타내지 않는다. 게임 내 클릭·사거리·발사 동기화·가시성은 통합 런타임 검증 대상이다.

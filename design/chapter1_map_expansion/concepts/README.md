# 챕터 1 추가 맵 — 3D 배치 시안

[설계 맵 원본](../maps.json)의 1-6~1-10을 챕터 1 자산으로 표현한다. 2026-09-30에 **1-7과 1-10만 포탈과 끊어진 지형으로 갱신**했다. 본게임 스테이지 배치·번호·웨이브·저장은 변경하지 않았다.

- [현재 5개 비교](five-map-comparison.png), [포탈 적용 두 맵 비교](teleport-map-comparison.png)
- Blender 최종 렌더: [1-6](chapter-1-6.png), [1-7](chapter-1-7.png), [1-8](chapter-1-8.png), [1-9](chapter-1-9.png), [1-10](chapter-1-10.png)
- [포탈 반영 편집 원본](chapter1-teleport-map-concepts.blend): **최신 1-7·1-10 두 Scene**. 승인 포탈의 실제 곡면·재질·애니메이션을 포함한다.
- [보존한 5맵 편집 원본](chapter1-five-map-concepts.blend): **포탈 적용 전 원본**. 1-6·1-8·1-9의 현행 장면과 1-7·1-10의 이전 배치를 보존하며, 최신 두 맵을 만들 때 입력으로 재사용한다.

## 포탈과 지형

1-7은 청색 IN `[3,4]` → OUT `[8,4]` 사이의 `[4..7,4]` 4칸을 비웠다. 1-10은 청색 `[3,3]` → `[7,3]` 사이 3칸, 주황색 `[7,8]` → `[1,8]` 사이 5칸을 비웠다. 삭제한 12칸은 `tiles`에서 `blocked`이고 실제 `path` 배열에서도 제거했다. 각 IN 다음 경로점이 같은 색 OUT이며, 나머지 이동은 인접한 칸을 따른다.

기존 건설 좌표·스폰·코어와 1-6·1-8·1-9는 유지했다. 1-7은 보행 18칸·전송 1회·건설 17칸, 1-10은 보행 17칸·전송 2회·건설 18칸이다. 승인된 [텔레포트 제작 원본](../../teleport_device_concepts/2026-09-30/production/README.md)을 재사용하며, 본체·효과가 한 칸을 넘지 않는다. IN은 어두운 중심으로 수렴하고 OUT은 밝은 중심에서 외곽으로 확산한다.

## 실제 Godot 화면과 이동

[격리 미리보기](../../../godot/previews/chapter1_expansion/preview.gd)는 설계 JSON을 읽어 공용 전장 렌더러와 **NativeCombatRuntime·BattlefieldUnits**로 실행한다. 임의의 이동 애니메이션으로 순간이동을 흉내 내지 않는다. 식생은 보존한 Blender 배치에서 [1-7 GLB](chapter-1-7-dressing.glb), [1-10 GLB](chapter-1-10-dressing.glb)로 내보내고 기존 정점색 처리를 적용했다. 이 GLB는 설계 미리보기용이며 본게임 맵에 연결하지 않았다.

| 설계 맵 | 실제 화면 | 실제 출구 상태 | 동작 영상 |
| --- | --- | --- | --- |
| 1-7 | [전체](godot-1-7-overview.png) | [청색 OUT](godot-1-7-teleport-1.png) | [12초 영상](godot-1-7-teleport.mp4) |
| 1-10 | [전체](godot-1-10-overview.png) | [청색 OUT](godot-1-10-teleport-1.png), [주황색 OUT](godot-1-10-teleport-2.png) | [11.33초 영상](godot-1-10-teleport.mp4) |

Godot 4.7.2 / Mobile / Metal에서 24fps로 실제 이동을 기록했다. 두 맵 모두 코어에 도착했고 전송은 각각 1회/2회였다. 금지 칸 통과 0, 렌더 위치와 논리 위치 불일치 0을 확인했다. 영상은 288/272프레임 전체 디코드 오류가 없었다. 이후 조작 안내문 위치만 바로잡아 최종 전체 화면을 다시 캡처했다. 영상의 지형·재질·이동은 같은 최종 구현이다.

별도 Astra 독립 검증 **PASS**: 최종 JSON의 지정 12칸 제거·다른 세 맵/건설칸 보존, 실제 세 전송의 IN 직전→OUT 직후 프레임과 런타임 trace, 출구 저장 복원 후 재전송 없음, 지형 분리·한 칸 경계를 확인했다. 부모도 최종 Godot 전체·출구 화면을 직접 확인했다. Android 빌드·배포 검증은 수행하지 않았다.

## 원본 보존과 재생성

현재 두 맵은 아래 순서로 갱신한다. 기존 편집 원본을 덮어쓰지 않으며 열린 Blender의 미저장 작업과 독립된 background 프로세스를 사용한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/chapter1_map_expansion/concepts/update_teleport_concepts.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/chapter1_map_expansion/concepts/export_preview_dressing.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/chapter1_map_expansion/concepts/build_comparison.py
COMPARE_TELEPORT_ONLY=1 /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/chapter1_map_expansion/concepts/build_comparison.py
```

`update_teleport_concepts.py`는 보존한 5맵 원본을 읽고 1-7·1-10만 복제·수정하여 새 2맵 원본과 렌더를 저장한다. 기존 `build_concepts.py`는 **포탈 이전 기본 배치 생성기**이며 현재 포탈 맵 입력에서는 중단한다. 이를 단독 실행해 포탈 없는 일반 타일 렌더로 최신 결과를 덮어쓰지 않는다. 수동 편집을 유지한 재렌더는 최신 2맵 `.blend`의 해당 Scene을 직접 렌더한다.

공용 Godot 프로젝트를 준비한 뒤, 저장소 루트에서 다음과 같이 격리 미리보기를 실행할 수 있다.

```sh
RUNE_EXPANSION_DESIGN_ROOT="$PWD/design/chapter1_map_expansion" RUNE_EXPANSION_STAGE=1-7 build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --path build/godot/project --scene res://previews/chapter1_expansion/preview.tscn
```

Space 정지/재생, 1/4 배속, 7/0 맵 전환, R 다시 보기. `RUNE_EXPANSION_STAGE=1-10`으로 두 번째 맵을 연다. `RUNE_EXPANSION_CAPTURE`에 로컬 출력 폴더를 지정하고 `-- --capture`를 추가하면 전체 경로의 실제 프레임과 `runtime-report.json`을 저장한다. `-- --still`은 전체 화면 한 장만 저장한다.

원시 프레임·상세 trace·변환 보고·로그와 이전 비교 사본은 `build/chapter1-teleport-placement/`에 보관하며 Git 추적에서 제외한다. 확정 PNG·MP4·편집 원본·필요 제작 스크립트·미리보기 GLB는 재사용 자료로 남긴다.

## 기존 환경 표현

기존 `terrain-surface.blend`의 건설·경로 타일, `environment-dressing.blend`의 풀·고사리·바위 군락, `rune-landmarks.blend`의 스폰 포탈·코어를 재사용한다. 비플레이 칸은 같은 `combat_space_nebula.png` 배경으로 비워 둔다. 맵별로 식물 종류를 나누지 않고, 비대칭 군락과 작은 빈틈을 둔 원래 배치를 유지했다.

Blender 비교는 같은 수직축 기준 25도 시점·직교 배율 12.8·조명·1200×1320·Cycles 32샘플이다. 공용 스폰 포탈만 기존 `portal_preview.py`의 0초 정지 재질을 사용한다. 새 텔레포트는 승인된 실제 입체 원본의 frame 17이며, Godot에서는 공용 전투 시계로 애니메이션한다.

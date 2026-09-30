# 한 칸 텔레포트 — Blender 제작 원본

승인 원본은 [12번 IN/OUT 소용돌이](../12-in-out-vortex-single-tile.png)이다. 이 폴더는 모델·재질·루프 애니메이션 원본과 Godot용 변환 원본을 보관한다. 게임 기믹은 선택 필드로 연결하며 출시 맵에는 배치하지 않았다.

- [편집 원본](teleport-four-variants.blend): `Teleport • Four Variant Comparison` 장면. `BLUE IN`, `BLUE OUT`, `ORANGE IN`, `ORANGE OUT` 컬렉션을 각각 편집한다. 각 컬렉션의 같은 이름 루트 Empty를 이동하면 독립 배치할 수 있다.
- [네 변형 비교](four-variants.png): Blender Cycles 실제 렌더, 1600×1080, frame 17.
- [4초 비교 루프](four-variants-loop.mp4): 같은 원본의 frame 1–96, 24fps, 960×648. 마지막 프레임 다음에 첫 프레임을 재생한다.
- [제작 스크립트](build_teleport.py), [영상 인코더](encode_loop.py).

옆길과 포탈의 두꺼운 석재 측면은 현행 [terrain-surface.blend](../../../stage1_3d/surface_effects/terrain-surface.blend)의 `path_tile_natural_surface` 형상·재질·UV를 재사용했다. 한 칸은 1×1, 석재 바닥은 Z=-0.334, 길 상면은 Z=0이다. 좁은 사각 금속 프레임의 상단은 Z=0.013이며 모서리만 짧게 깎았다. 네 변형은 같은 측면 메시와 동일 금속 프레임 형상을 사용한다. 옆길·표제·카메라·조명은 비교용이며 포탈 컬렉션에 포함하지 않는다.

IN은 가장자리 Z=-0.005에서 중심 Z≈-0.097로 내려가는 실제 곡면이다. 넓은 흐름이 중심 쪽으로 가늘어지고 어두워지며, 이동광과 재질 맥동이 가장자리에서 중심으로 이동한다. OUT은 Z=0.002–0.027의 낮은 볼록 곡면과 밝은 중심을 사용하고, 흐름의 폭·밝기가 외곽으로 증가한다. 이동광과 맥동도 중심에서 바깥으로 나간다. 회전 방향만 뒤집은 구분이 아니다.

포탈 표면은 8,299개 정점의 편집 가능한 곡면과 절차적 재질이다. 승인 이미지를 평면에 붙이지 않았으며 포탈 효과 재질에 이미지 텍스처 노드가 없다. 석재 표면 텍스처 8개는 원본에 패킹되어 있다. 애니메이션은 프레임 키와 재질 드라이버로 저장되어 있고 자동 실행 Python 핸들러가 필요하지 않다.

## 다시 렌더하기

저장한 수동 편집을 보존하고 렌더하려면 저장소 루트에서 실행한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/teleport_device_concepts/2026-09-30/production/build_teleport.py -- --render-still
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/teleport_device_concepts/2026-09-30/production/build_teleport.py -- --render-loop
python3 design/teleport_device_concepts/2026-09-30/production/encode_loop.py --ffmpeg /absolute/path/to/ffmpeg
```

옵션 없는 제작 실행은 기존 원본이 있으면 중단한다. 재생성이 필요하면 수동 편집을 보관한 뒤 별도 사본에서 수행한다. 제작·렌더는 독립 Blender background 프로세스를 사용하여 기존 열린 편집 파일을 덮어쓰지 않는다.

## 검증과 범위

Blender 5.2.1 LTS / Cycles / AgX에서 비교 렌더했다. 네 변형의 1×1 규격·공유 석재 측면·UV 보존·얕은 곡면 깊이와 높이·IN/OUT 반대 방사 이동·frame 1=97의 이동광 위치와 크기 일치를 확인했다. 원본은 96프레임 주기이며 97번은 루프 닫힘 검사에만 사용한다. 최종 MP4는 FFmpeg 전체 디코드에서 96프레임·4.00초를 오류 없이 확인했다.

Blender 재질 드라이버·컴포지터를 그대로 내보내지 않는다. Godot에서는 실제 곡면을 유지하고 방사 흐름과 이동광을 전투 시계로 계산한다. Blender AgX와 Godot 공용 Filmic의 조명·톤 매핑 차이는 기기용 재질에서 다룬다.

초기 Blender 검수 당시 원본 SHA-256: `1292d7dc4e6d0d92bf5ef2af1f615752621f6f09cc6e9119568cce84bd8b5178`. 이동광 대표 반경은 frame 17→25에서 IN 0.34454→0.31244, OUT 0.08774→0.11984로 확인했다. 상세 일회성 검사와 중간 원본·로그·프레임은 로컬에 보관하며 `.gitignore`로 제외한다.

별도 Astra 독립 검증: **PASS**. 승인 12번과 최종 비교 렌더의 본체·한 칸 규격·색·IN 중심 수렴·OUT 외곽 확산 외형을 대조했다. 저장 원본을 독립 background 검사하고 실제 렌더 frame 1/9/17/25/33/49/73/96을 비교하여 IN 반경 감소·OUT 반경 증가·frame 1=97 오차 0을 확인했다. 실제 frame 96→1의 렌더 변화량도 일반 프레임 간 최대 변화보다 작아 루프 연결을 통과했다. 부모가 최종 비교 렌더와 검증 근거를 직접 검토했다. 아래 타일 경계 보정은 이후 게임 이식 중 적용했다. 비교 렌더·영상의 흐름과 형태 근거는 유지하며, 경계 보정과 게임 표현은 별도 확인한다.


## Godot 기믹 원본과 경계

[export_game.py](export_game.py)는 승인 원본의 평가된 메시를 내보내며, [teleport-game-export.blend](teleport-game-export.blend)를 편집 가능한 변환 원본으로 저장한다. 게임용 [teleport_device.glb](../../../../assets/images/stage1_3d/teleport/teleport_device.glb)는 프레임·IN 곡면·OUT 곡면·이동광·OUT 중심 메시를 포함한다. 석재는 포함하지 않고 배치된 챕터 타일의 측면과 바닥을 유지한다.

외곽 금속선 반경만 0.0023→0.0018로 줄여 곡선 평가 메시까지 X/Y ±0.5 안에 들어오게 했다. 갱신한 승인 원본 SHA-256은 `e6076ae4b179f3c28a0adf12f7679f63eb263034d2539581300a2b03ca60a95d`이다. 네 변형·프레임 1–97의 실제 평가 정점과 이동광을 검사했다. 기존 비교 렌더·영상은 이 미세 경계 보정 전 결과다.

[Godot device](../../../../godot/environment/teleport_device.gd)는 프레임과 3D 곡면을 재사용하고, 입구/출구와 색에 따라 재질을 선택한다. 양면 곡면·선형 색 전달을 명시해 Blender 원본의 흐름을 재현한다. 이동광은 실제 메시 15개를 MultiMesh로 표시한다. 시간은 `frame.time`만 사용하므로 정지·전투 배속과 함께 움직인다. 각 본체 및 전체 주기의 이동광 가로·세로 범위는 ±0.5다.

배치는 `map.teleportPairs` 선택 필드로만 요청한다. 필드가 없거나 빈 배열이면 새 노드·상면 절삭·GLB 로딩이 발생하지 않는다. 배치 시 기존 지형 공유 리소스를 변경하지 않고 해당 인스턴스의 중앙 상면만 복사 절삭한다. 챕터 2 공유 포장 MultiMesh는 해당 칸만 분리한다. 본체 밖 가장자리·측면·바닥과 기존 지형 재질·UV를 보존한다. 출현 포탈·코어와 겹치지 않도록 끝점은 일반 `path` 칸만 허용한다.

[격리 미리보기](../../../../godot/previews/teleport_device/preview.gd)는 실제 전장 렌더러로 네 변형과 인접 타일을 보여 준다. Space로 정지/재생, 1/4로 배속을 바꾼다. `RUNE_TELEPORT_STAGE=1|6|11` 환경 변수는 원본 JSON의 메모리 복사본에만 임시 배치해 각 챕터 지형을 확인한다. 실제 콘텐츠·사용자 저장은 변경하지 않는다. `-- --capture`와 `RUNE_TELEPORT_CAPTURE`로 대표 시간 프레임을 로컬 보관할 수 있다.

Godot 4.7.2 / Mobile / Metal 실제 화면으로 네 변형과 1·6·11번 맵의 메모리 복사본을 확인했다. 격리 미리보기에서 타일 범위·없는 필드와 빈 배열의 기존 노드 수 동일·공유 원본 메시 19/59/70개 불변을 검사했다. 실제 입력에서 1x 1.008초, 4x 4.05초 진행과 정지 후 시각 5.791667초 불변을 확인했다. 로컬 근거는 `build/teleport-gimmick-verification/`에 보관한다. 기기 빌드·설치·배포는 수행하지 않았다.

[최종 Godot 네 변형 화면](godot-four-variants.png)은 실제 전장 렌더러의 격리 미리보기 frame 17이다. 별도 Astra 독립 검증에서 최종 화면·GLB 경계·챕터별 타일 측면 보존, 1x/정지/4x 전투 시계와 전송 후 보행·출구 방향, 세션에서 렌더러까지의 선택 필드 전달을 확인해 **PASS** 판정했다. 전송 회귀 66항목과 관련 기존 전투·콘텐츠·저장 검사를 통과했다. 최종 GLB SHA-256은 `a15f61a6648716c45f61d6683362df73f854496a55601309d0c1292d824bfd41`이다. 게임 배치 계약과 상태의 원본은 [콘텐츠 계약](../../../../godot/content/README.md#선택적-전송-기믹)에 둔다.

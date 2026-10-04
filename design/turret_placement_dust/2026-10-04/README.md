# 포탑 설치 3D 먼지

역할: 편집 원본·게임용 기하·방사 확산 동작의 제작 계약. 2026-10-04.

포탑이 즉시 설치될 때 받침 주변에서 옅은 회갈색 먼지가 360도로 짧게 퍼지고 가라앉는다. 불꽃·발광·파편 없이 낮은 비대칭 구름을 사용한다. 포탑 낙하와 HUD 움직임은 포함하지 않는다.

`placement-dust.blend`의 독립 `PlacementDust3D` 장면에서 `PlacementDust_SourceGeometry`는 닫힌 단일 메시, `PlacementDust_BurstPreview`는 같은 기하를 공유하는 32개 입체 먼지의 위치·크기·회전 키프레임이다. 30fps의 1~20프레임(0.633초)에 방사 확산·낮은 상승·성장·소멸을 편집할 수 있다. 원본에는 다른 열린 Blender 장면을 포함하지 않는다.

burst의 `PlacementDust_True3DVolume`은 표면 쉘 없이 실제 3D 밀도를 적분하는 PrincipledVolume 재질이다. bounds로 정규화한 공간 좌표에 3D hash/value noise를 적용하고, 각 puff의 index와 수명에 따라 내부 밀도와 경계를 이동시킨다. 경계 warp는 최대 ±0.10, radial smoothstep은 .08~.49, 밀도 noise는 주파수 3.8·강도 .20+.80noise, 최종 밀도는 수명 곡선×2.8이다. 따뜻한 회색(.57,.53,.46)을 사용하며 발광과 표면 하이라이트는 없다. Blender의 world 길이 적분을 native의 normalized 길이 적분에 대응하는 metric 노드로 정규화한다. 정점 알파는 3D 밀도 보조 정보이며 카메라 명암을 베이크하지 않았다.

게임용 `assets/images/stage1_3d/effects/placement_dust.glb`는 `placement_dust_puff` 단일 메시·단일 primitive, 680정점·1,356삼각형, smooth normal과 `COLOR_0`을 담는다. 카메라를 향하는 평면·스프라이트·플립북·텍스처는 사용하지 않는다. 노드 transform은 identity, glTF +Y가 위이며 중심 원점이다. Godot bounds는 약 `(-0.509,-0.123,-0.372)`~`(0.504,0.125,0.369)`이다. 하나로 융합된 낮은 다중 lobe 기하는 밀도 영역의 proxy이며 최종 구름의 경계는 체적 밀도로 표현한다.

동작·재질 입력은 `burst_manifest.json` 한 곳에서 관리한다. `export.py`가 동일 입력을 게임용 `placement_dust.json`으로 복사한다. 수명·32개 입자의 각도와 반경·폭·높이·상승·회전 및 네 구간의 이동/크기/불투명도 곡선을 제공한다. 런타임은 원본 크기로 정규화한 native MultiMesh를 기단 주변에 배치하며 12회 체적 밀도 적분과 opaque depth clipping을 사용한다. `volume.color`는 Blender 체적 산란의 원본색이며, `native_tint`와 `native_tint_mix`는 Godot의 체적 적분 결과에 같은 색감을 유지하기 위한 엔진 색 대응값이다. 숨긴 master의 별도 rest PBR 재질은 GLB fallback이고 체적 재질을 glTF 표면으로 대체했다는 뜻은 아니다. 이벤트와 시간 기준은 기존 설치 cue 런타임이 담당한다.

Blender MCP에서 새 원본은 `build_source.py`로 제작한다. 기존 `PlacementDust3D`가 있으면 생성기는 덮어쓰지 않고 중단하므로 해당 원본을 편집한다. `animate_source.py`는 대표 burst, `build_volume.py`는 편집 가능한 3D density 재질 제작 단계이다. 편집 후에는 같은 장면에서 `export.py`를 실행한다. 살아 있는 다른 파일에 `open_mainfile`이나 `save_as_mainfile`을 사용하지 않는다. source 저장은 `bpy.data.libraries.write(..., {scene}, fake_user=True)`로 해당 새 장면만 분리한다.

기하 검사에서 닫힌 메시·smooth normal·유한 좌표·identity transform과 GLB의 POSITION/NORMAL/COLOR_0을 확인했다. Blender 원본의 두 시점은 제작 확인이며 최종 외형 판정은 실제 Godot 고정·드론 시점의 움직임과 포탑/타일 가림으로 수행한다. 로컬 렌더·검사 덤프는 ignored `build/godot/placement-impact-asset/`에 보관한다.

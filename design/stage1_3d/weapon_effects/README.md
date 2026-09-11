# 실제 3D 전투 발사 효과

2026-09-11. 기관총과 대포가 공유하는 투명 발사 섬광/연기 atlas.

대포 착탄은 별도의 [3D 필드 캐시](../cannon_impact/field_cache/README.md)와 런타임 입체 파편·불티를 사용한다. 최신 착탄에는 대응하는 Blender 원본이 없으며, Python 제작 원본과 실제 화면은 [착탄 검수](../cannon_impact/shell_runtime/README.md)를 따른다. 아래 8프레임 규격은 포구 효과에만 적용한다. 전체 원본 연결은 [Blender 작업 허브](../blender_workspace/README.md)에서 확인한다.

## 런타임 계약

| 파일 | 셀/프레임 | 방향·원점 |
| --- | --- | --- |
| `assets/images/stage1_3d/effects/muzzle_flash.png` | 1024×512 RGBA, 4열×2행, 256×256 8프레임 | 오른쪽 +X 측면 제트, 셀 원점 (0.28, 0.5) |
| `assets/images/stage1_3d/effects/gun_smoke.png` | 동일 | 중심 원점 (0.5, 0.5) |

프레임은 왼쪽→오른쪽, 위→아래 0~7. 섬광은 0에서 즉시 점화, 1~3에서 아이보리 핵과 얇은 앰버 갈래가 뻗으며 4~7에서 소멸한다. 연기는 회갈색 부피가 팽창하며 투명도가 감소한다. 지속시간과 스케일은 무기별 런타임에서 결정하며 끝에서 opacity 0으로 닫는다.

섬광 실제 내용 최대 폭 152px, 연기 160px이므로 투명 여백을 포함한 billboard 전체 스케일과 구분한다. 섬광 Sprite.center=(.28,.5), 연기=(.5,.5). 섬광 회전은 화면에 투영한 포신 전방을 따른다. 일반 straight alpha; 검은 테두리용 배경은 없다.

기관총은 기본 전장 크기에서 식별되도록 섬광 0.12초·연기 0.65초를 표시한다. 초기 연기 내용은 셀 폭의 약 15%이므로 셀 전체 크기만으로 크기를 정하지 않는다. 밝은 석재 길과 구분되는 회색 틴트와 아틀라스 자체 소멸 알파를 고려한 불투명도를 사용한다. 실제 게임 가독성 검수는 `../machinegun_visibility/`를 따른다.

## 제작·검증

- `build_effects.py` → Blender에서 실제 방향성 3D 제트와 Noise 밀도 볼륨 장면 생성·저장. 이 스크립트는 렌더와 atlas 내보내기까지 자동 실행하지 않는다.
- `weapon-effects.blend`의 WeaponMuzzleFrames/WeaponSmokeFrames에서 투명 RGBA 8프레임 렌더. 원본 프레임은 `frames/`.
- GIMP 3.2.4 MCP `export_sprite_sheet`는 `ImageBaseType.RGBA` enum 오류로 실패했다. 대신 OpenRaster의 레이어좌표로 4×2 배치한 `muzzle-atlas.ora`/`smoke-atlas.ora`를 GIMP에서 열어, 알파를 보존하는 PNG export로 패킹했다.
- `gun-smoke-atlas.xcf`는 레이어 원본. 프레임 데이터에 다른 이미지 생성/편집 도구를 사용하지 않았다.
- 최종 PNG의 RGBA/크기/프레임 순서/프레임별 alpha를 원본과 비교 확인했다. 셀 경계는 완전 투명이며 24px/64px 셀 크기로 GIMP 축소한 `*-qa.png`에서 실제 작은 크기를 확인했다.
- QA 이미지와 Blender 출력은 자산 검수용이며 실제 게임 녹화가 아니다.

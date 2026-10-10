# 챕터 3 타일 추가 감량본

역할: 승인된 외형을 보존한 현행 게임용 타일·패널과 재현 경로. 확인: 2026-10-10 KST. [승인 외형](../../../DESIGNS.md), [고해상도 제작·베이크 원본](../export/README.md), [첫 감량본과 당시 검증](../optimized-game-distance/README.md)은 보존한다.

게임의 [chapter3_tiles.glb](../../../assets/images/stage1_3d/environment/chapter3_tiles.glb)에 적용했다. [편집 원본](chapter3-tiles-optimized.blend)은 최종 메시와 PBR 이미지 4개를 패킹했고 저장 후 실제 재열기를 확인했다. 최종 해시·기법·보호 좌표·검증은 [manifest.json](manifest.json)을 기준으로 한다.

| 종류 | 첫 감량본 삼각형 | 현재 삼각형 |
| --- | ---: | ---: |
| 길 | 8,776 | 3,308 |
| 관통 격자 | 11,850 | 5,378 |
| 원형 건설칸 | 9,198 | 5,624 |
| 원 없는 건설칸 | 5,678 | 2,350 |
| 막힌 패널 | 1,252 | 872 |
| 환기 패널 | 1,908 | 910 |
| **고유 6종 합계** | **38,662** | **18,442** |

고유 삼각형은 첫 감량본보다 52.30%, GLB는 8,082,184→6,036,104바이트로 25.32% 추가 감소했다. 소품·포탈·코어를 포함한 실제 전장 기하량은 아래와 같다. UI·배경·적·포탑과 추가 렌더 패스는 제외하며 FPS와 구분한다.

| 기본 배율 전장 | 추가 감량 전 | 현재 삼각형 | 추가 감소 |
| --- | ---: | ---: | ---: |
| 3-1 / 스테이지 11 | 593,010 | 317,596 | 46.44% |
| 3-7 / 스테이지 27 | 649,980 | 359,536 | 44.69% |
| 3-10 / 스테이지 30 | 619,826 | 334,568 | 46.02% |

## 방법과 보존

`meshoptimizer`의 `meshopt_simplifyWithAttributes`, `options=0`을 사용했다. 첫 감량 메시를 반복 감량하지 않고 보존한 고해상도 원본에서 다시 생성했다. 원형 건설 타일은 상대 오차 `.001`, 나머지는 `.002`이며 법선 가중치 `.03`, UV 가중치 `1`이다. 정확히 같은 위치·UV만 임시 연결하고 출력에는 원본 POSITION·UV·NORMAL·TANGENT 코너 묶음을 복사한다. 위치 이동·새 UV·재베이크·재색칠은 하지 않았다.

[protected-regions.json](protected-regions.json)의 원본 6좌표 주변 반경 `.02`를 추가 잠금해 건설칸·격자 베벨의 국소 접점을 보존했다. 6루트 이름·변환·치수·경계·연결 요소 수와 현재 비다양체 수, PBR와 이미지 payload, 5개 길 돌기·25개 실제 격자 구멍·4면 패널 좌석·교체 패널 깊이·환기구 세로 열원 3개를 대조했다. 기존 이웃 패널 생략과 격자·텔레포트 주변 개방면, 소품·포탈·코어·맵·카메라·전투 계약은 유지한다. 런타임 코드·LOD·이웃 마스크는 변경하지 않았다.

처음 만든 일괄 `.002` 후보는 실제 게임에서 청동 링의 어두운 분절 경계가 강해져 미채택했다. 건설 타일의 감량 강도를 낮춘 최종 후보는 가는 청동 링 인상을 회복했다. 일부 베벨 음영의 미세한 차이는 있으며 픽셀 동일성을 주장하지 않는다.

## 검증

- Blender 5.2.2 LTS/Cycles 32의 같은 카메라·조명에서 [상판 전](review/before-hero.png)·[후](review/after-hero.png), [좌석·패널 전](review/before-seats.png)·[후](review/after-seats.png)를 비교했다. GLB 재임포트·4이미지 패킹·편집 원본 저장·실제 재열기는 통과했다.
- 별도 검증자가 원본 속성·이미지·기하 경계·연결 구조·격자·좌석·환기구 깊이를 직접 확인했다. 건설 타일의 918개 표면 ray에서 누락 변화는 없었다. 유한 표본은 전체 표면 오차 상한 측정이 아니며, 겹친 면·경계의 ray나 UV 보간 차이를 전체 텍스처 이동으로 해석하지 않는다.
- Godot 4.7.2 Mobile/Metal, Apple M4, 440×900의 실제 앱 준비 화면에서 스테이지 11·30·27의 고정/드론 시점과 기본/2.5배 확대, 총 12상태를 같은 맵·카메라·배율로 전후 비교했다. 부모·독립 시각 검수 PASS. [최종 실제 게임 화면](game-preview.png)은 검수 후보와 동일한 최종 GLB에 대응한다. 사용자 저장과 네트워크를 분리한 검수였다.
- 기존 타일·공유 재질·패널 배치·소품 접합·카메라 검사에서 텔레포트 없는 9개 맵과 스테이지 11 재진입이 통과했다. 기존 검사에서 타일로 세던 텔레포트 장치 루트를 제외하고, 현행 경로 점프·잘린 호스트 메시를 반영한 스테이지 27 검사와 재진입도 별도로 통과했다. 전체 게임 회귀가 아닌 이번 타일 계약의 검사다. 최종 Godot 가져오기도 통과했다.
- 원본 export-only 재생성과 최종 보호 설정의 재감량에서 최종 GLB SHA-256이 일치했다. 이미 감량한 입력과 원본 경로 덮어쓰기는 거부한다. 최종 게임·실제 앱 검수·Blender 재열기·독립 검증의 해시 대응을 확인했다.
- FPS·GPU 시간·Android 실기기·APK·배포는 미측정/미실행이다. 일회성 후보·캡처·표본·스크립트·자동 백업·로그는 로컬 `checks/`에 보관하고 Git 추적에서 제외한다.

## 재현

저장소 루트에서 실행한다. 기존 열린 Blender 문서를 보존하고 독립 background 실행을 사용한다. baseline이 이미 있으면 첫 명령은 덮어쓰지 않는다. 다른 위치는 `prepare_baseline.py -- --output <경로>`로 지정하고 감량 도구에 `--source <경로>`로 전달한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python design/chapter3_3d/optimized-game-distance-v2/scripts/prepare_baseline.py
/Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 design/chapter3_3d/optimized-game-distance-v2/scripts/optimize_tiles.py --error .002 --root-errors '{"build_tile":0.001}' --protect design/chapter3_3d/optimized-game-distance-v2/protected-regions.json --output design/chapter3_3d/optimized-game-distance-v2/checks/error002-hybrid.glb
/Applications/Blender.app/Contents/MacOS/Blender -b --python design/chapter3_3d/optimized-game-distance-v2/scripts/verify_render.py -- --candidate design/chapter3_3d/optimized-game-distance-v2/checks/error002-hybrid.glb --validate-only
```

감량 도구는 `--library`를 지원한다. 마지막 명령은 최종 packed 편집 원본을 저장·재열기한다. 전후 렌더까지 재생성하려면 첫 감량 `.blend`에서 export-only로 비교 GLB를 준비하고 `verify_render.py -- --before <비교 GLB> --candidate <최종 후보>`를 실행한다. 게임 파일 복사는 시각 검수 후 별도로 수행한다.

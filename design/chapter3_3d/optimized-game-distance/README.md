# 챕터 3 타일 첫 감량본

역할: 기존 상판 4종·교체 패널 2종의 첫 감량본과 당시 검증·재현 기록. 확인: 2026-10-10 KST. [승인 외형](../../../DESIGNS.md)과 [고해상도 베이크 원본](../export/README.md)을 유지한다. 현행 게임은 [추가 감량본](../optimized-game-distance-v2/README.md)을 사용하며 이 폴더의 메시·수치·검증은 첫 감량 당시 상태를 보존한다.

게임 파일은 기존 [chapter3_tiles.glb](../../../assets/images/stage1_3d/environment/chapter3_tiles.glb)를 교체했다. [편집 원본](chapter3-tiles-optimized.blend)은 텍스처를 패킹한 감량본이며 기존 제작·베이크 원본은 변경하지 않았다. 해시·기법·독립 기하 검증은 [manifest.json](manifest.json)을 기준으로 한다.

| 종류 | 감량 전 삼각형 | 감량 후 삼각형 |
| --- | ---: | ---: |
| 길 | 24,416 | 8,776 |
| 관통 격자 | 30,320 | 11,850 |
| 원형 건설칸 | 24,916 | 9,198 |
| 원 없는 건설칸 | 16,276 | 5,678 |
| 막힌 패널 | 2,660 | 1,252 |
| 환기 패널 | 4,048 | 1,908 |
| **고유 6종 합계** | **102,636** | **38,662** |

삼각형은 62.33%, GLB는 18,672,584→8,082,184바이트로 56.72% 줄었다. 고유 라이브러리 합계이며 맵 인스턴스 합계·FPS·APK 감소율과 구분한다. 실제 앱 전장의 소품·포탈·코어까지 포함한 기하량은 스테이지 11에서 1,479,300→593,010, 스테이지 30에서 1,520,840→619,826삼각형이었다.

## 감량과 보존

Blender에 포함된 `meshoptimizer`의 `meshopt_simplifyWithAttributes`, `options=0`, 상대 오차 상한 `.0005`를 사용했다. 위치·UV가 완전히 같은 분할 정점만 임시 연결하고 법선·UV를 감량 속성으로 전달한다. 출력에는 원본의 위치·UV·법선·탄젠트 코너 묶음을 사용한다. 정점 위치 이동·새 UV 전개·텍스처 재베이크·재색칠은 하지 않았다.

6루트 이름·변환·외곽 치수·상면과 하단·4면 패널 좌석·25관통구멍·세로 열원 슬롯 3개·실제 매립 깊이·공용 PBR와 4개 내장 PNG payload를 보존했다. 면이 바뀌어 베벨의 법선·탄젠트 보간에는 차이가 있으며, 원본 속성 보존을 픽셀 동일 주장으로 해석하지 않는다.

## 검증과 한계

- Blender 5.2.2 LTS/Cycles의 같은 카메라·조명에서 [상판 비교 전](review/before-hero.png)·[후](review/after-hero.png), [좌석·패널 비교 전](review/before-seats.png)·[후](review/after-seats.png)를 확인했다. 최종 GLB 재임포트와 packed `.blend` 저장·실제 재열기가 통과했다.
- 별도 검증자가 최종 GLB를 직접 해석하고 806개 표면 ray를 대조했다. 새 누락은 없으며 최대 위치 차이는 .000479타일, UV 차이는 2048px 기준 .0792px였다. 일부 베벨의 법선 차이는 최대 약30°지만 실제 게임에서 유의미한 외형·재질 손상이 보이지 않았다.
- Godot 4.7.2 Mobile/Metal, Apple M4, 440×900의 실제 앱 준비 화면에서 스테이지 11·30 고정/드론 시점과 스테이지 11의 2.5배 확대를 같은 맵·배율로 전후 비교했다. 부모·독립 검증 모두 PASS. [최종 실제 게임 화면](game-preview.png)은 검수 후보와 동일한 최종 GLB에 대응한다. 사용자 저장과 네트워크를 분리한 오프라인 검수였다.
- 기존 `verify_chapter_three_stage.gd`의 원래 실행은 감량 전후 모두 텔레포트 경로가 빠진 생성 입력과 마지막 조명 초기화 기대값에서 동일하게 실패했다. 이를 전체 회귀 PASS로 기록하지 않는다. 이번 변경의 타일·재질·패널·배치·카메라 검사는 텔레포트가 없는 9개 실제 맵을 대상으로 범위를 한정해 확인했다. 텔레포트 스테이지 27의 진입은 현행 앱 경로에서 별도 확인했다.
- FPS·실제 GPU 시간·Android 실기기·APK·배포는 미측정/미실행이다. 기하량 감소를 전체 프레임 성능 개선율로 해석하지 않는다. 일회성 검사·원시 수치·게임 캡처·비교 GLB·로그는 로컬 `checks/`에 보관하고 Git 추적에서 제외한다.

## 재현

저장소 루트에서 실행한다. 기존 열린 Blender 문서는 보존하며 독립 background 실행을 사용한다. 새 체크아웃에서는 먼저 원본 `.blend`의 기존 베이크 표면을 export-only로 내보낸다. baseline이 이미 있으면 덮어쓰지 않는다. 다른 위치는 `prepare_baseline.py -- --output <경로>`로 지정하고 다음 감량 도구에 `--source`로 전달한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python design/chapter3_3d/optimized-game-distance/scripts/prepare_baseline.py
/Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 design/chapter3_3d/optimized-game-distance/scripts/optimize_tiles.py --error .0005
/Applications/Blender.app/Contents/MacOS/Blender -b --python design/chapter3_3d/optimized-game-distance/scripts/verify_render.py
```

baseline 재생성 시험에서 기존 감량 전 GLB와 SHA-256이 일치했다. 감량 도구는 `--source`·`--output`·`--library`를 지원하고 원본 삼각형 수를 검사해 이미 감량한 게임 GLB를 다시 감량하는 일을 막는다. 감량 출력은 `checks/chapter3_tiles-candidate.glb`이며 게임 파일 교체는 검수 후 별도로 수행한다. `verify_render.py`는 감량 편집 원본을 저장·재열기하고 Blender 비교 이미지를 만든다.

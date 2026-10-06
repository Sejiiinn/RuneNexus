# 사거리 원 표시 조건

역할: 사거리 표시·좌표 캐시의 보존 계약과 2026-09-15 측정 역사. 아래 Flutter·Flame·APK 측정은 전환 전 당시 경로이며 현행 실행·성능 판정이 아니다. 원시 측정·캡처는 로컬 기록이며 새 체크아웃에서 제공되는 근거로 링크하지 않는다. 현행 실행·책임은 [Godot 전환 상태](../../../docs/godot_unified_app_roadmap.md)를 따른다.

## 두 변경을 함께 적용한 최종 1배속 측정

표시 제한과 좌표 캐시를 **모두 켠 production 동작**을 측정했다. 선택·설치 중이 아닌 평소 상태이며 selection 묶음을 강제로 숨기는 no_ranges 모드를 사용하지 않았다. 레벨·화염·그림자 등 나머지 옵션은 유지했다. 최신 비교 APK와 production selection 소스가 같은지 확인했으며 모드는 one_x, 캐시는 기본 true다.

| Godot 단독 검증 장면 | 변경 전 FPS | 두 변경 적용 후 FPS | 실제 SurfaceView FPS | 적용 후 p95 |
|---|---:|---:|---:|---:|
| 화염 6문 / 정지 적 3기, 60초 | 24.72 | 40.36 | 41.124 | 28.895ms |
| 대포만 6문 / 정지 적 3기, 60초 | 29.19 (이전 20초) | 46.89 | 47.979 | 26.771ms |
| 혼합 6문 / 이동 적 24기, 20초 | 21.78 | 27.65 | 27.755 | 53.099ms |
| 화염 6문 / 이동 적 24기, 20초 | 21.46 | 27.55 | 27.744 | 62.997ms |

1080×2424 Android 에뮬레이터, 각 12초 준비 후 측정. 변경 전은 기존 acceptance-* 1배속 기록이다. 별도 시점의 측정이므로 고정 개선율을 보장하지 않는다. 이 표는 동일 에셋을 쓰는 최소 Godot 전투의 결과이며 Flutter 전체 HUD와 완성 전투 규칙의 성능을 뜻하지 않는다. 두 변경을 함께 적용해도 60 FPS에는 미달했다. source: combined-final-*.json 및 대응 SurfaceFlinger 원본.

### 당시 Flutter HUD + Flame + Godot 구조 확인

화염 포탑 없는 추가 비교는 같은 최종 APK의 normal/one_x로 대포 6문과 정지 적 3기를 12초 준비 후 60초 측정했다. 원본은 `combined-no-fire-normal.json` 및 대응 SurfaceFlinger/log 파일. 선택·설치 없음, 두 사거리 최적화 모두 유지. Godot 단독 평균 46.89 FPS로 화염 40.36 FPS보다 높았지만 60 FPS는 미달했다. 아래 Flutter 대포 수치는 직전 측정값이며 이 추가 실행으로 재측정한 것은 아니다. 두 엔진 경로의 수치를 같은 FPS로 합치지 않는다.

같은 최신 APK의 실제 GameHud·Flame 전투를 쓰는 기준 장면도 실행했다. 원은 자연스럽게 숨겨지고, snapshot에서 모든 selected=false·tiles=[]를 확인했다. 각 20개 1초 표본을 수집했다.

| 1배속 장면 | Godot 보고 FPS 평균 | Flame 전투 update/s | Flutter raster 평균 |
|---|---:|---:|---:|
| 대포 6문 / 정지 적 3기 | 37.33 | 22.22 | 31.49ms |
| 화염 6문 / 정지 적 3기 | 38.57 | 7.15 | 121.02ms |

화염의 실제 SurfaceView 표시는 39.052 FPS, Flutter 앱 윈도 갱신은 6.480 FPS였다. 같은 전투 상태를 Godot가 여러 번 표시할 수 있어 39 FPS가 전투 갱신 속도를 뜻하지 않는다. 화염 update 간격 p95는 170.96ms다. 이번 Flutter 경로의 native viewport는 880×1976으로 보고됐으므로 1080×2424 단독 경로와 직접 개선율 비교를 하지 않는다. 이 경로는 일반 전투 규칙을 쓰는 고정 표적 fixture이며 모든 실전 상황을 검증한 것은 아니다.

판단: 사거리 표시 제한+좌표 캐시로 Godot 표시 성능은 개선됐으나, 당시 앱 구조의 전투 갱신/Flutter raster 병목은 남아 있다. GPU 시간과 실기기 성능은 미측정이다. 집계·APK 해시 (당시 로컬 기록 `docs/analysis/godot_validation_20260915/combined-measurement.json`), 현재 구조 원본 (당시 로컬 기록 `docs/analysis/godot_validation_20260915/combined-flutter-final.json`). 기존 측정 파일은 보존했으며 실제 본게임 앱을 다시 열어 두었다.

확인: 2026-09-15. 현행 기준은 [DESIGNS.md](../../../DESIGNS.md).

- 평소·선택 해제: 사거리 원 숨김.
- 기존 포탑 선택: 해당 포탑만 표시. 업그레이드 사거리 미리보기 유지.
- 빈 건설칸 선택부터 설치 패널이 열려 있는 동안: 기존 전체 포탑 표시. 종류를 고르면 설치 후보의 미리보기도 표시.
- 설치 완료: 새로 선택된 포탑만 표시. 설치 취소: 전체 표시 해제.
- 보상 대상 지정의 기존 표시 우선순위와 레벨·젬 장식은 유지.

당시 Godot는 selection.tiles의 build 상태를 사용하고, Flame은 같은 게임의 건설칸 선택 상태를 사용했다. 저장·전투 규칙·전달 형식 변경은 없다.

## 당시 Android 본게임 확인

일반 lib/main.dart release ARM64 APK, 에뮬레이터 1080×2424, 스테이지 1, 1배속 준비 상태에서 직접 조작했다. 로비에서 이어서 진행한 뒤 선택·설치·해제 화면을 확인했다. 공개 배포는 하지 않았다.

- 평소 숨김 (당시 로컬 기록 `design/stage1_3d/range_visibility/idle.png`)
- 포탑 하나 선택 (당시 로컬 기록 `design/stage1_3d/range_visibility/selected.png`)
- 설치 패널: 전체 표시 (당시 로컬 기록 `design/stage1_3d/range_visibility/placement.png`)
- 설치할 포탑 미리보기 (당시 로컬 기록 `design/stage1_3d/range_visibility/preview.png`)
- 설치 완료: 새 포탑만 표시 (당시 로컬 기록 `design/stage1_3d/range_visibility/installed.png`)
- 설치 취소·해제 후 숨김 (당시 로컬 기록 `design/stage1_3d/range_visibility/cancelled.png`)

Flutter analyze 통과. 선택·설치·재선택·해제 실제 입력 상태 전환 및 기존 렌더 관련 테스트 8개 통과. Godot 기존 선택/보상 실루엣·카메라·클리핑·생명주기 검사 0 failures. 2D는 코드·테스트로 확인했고 이 캡처는 Android 3D 화면이다. 변경 후 전투 FPS는 별도로 재측정하지 않았다.

## 사거리 좌표 계산 최적화

Godot 선택·설치·업그레이드 미리보기의 원 좌표를 위치와 반경별로 재사용한다. 원의 96개 구간·색·투명도·선 두께는 유지하고 채움/테두리는 같은 좌표를 공유한다. 단위원도 한 번만 계산한다. 움직이는 젬 호와 조준 장식에는 이 캐시를 적용하지 않는다. 2D의 기존 drawCircle에는 같은 3D 좌표 변환이 없어 별도 캐시를 추가하지 않았다.

카메라 실제 transform/projection, 카메라 viewport, 월드 transform(화면 흔들림 포함), 맵 크기가 달라지면 화면 좌표를 폐기한다. 위치나 반경 변경은 별도 키를 사용하며, 누적 좌표는 최대 256개로 제한하고 장면 초기화 때 비운다. 카메라 보정값까지 포함하는 API는 [Godot Camera3D 문서](https://docs.godotengine.org/en/stable/classes/class_camera3d.html#class-camera3d-method-get-camera-transform)를 기준으로 확인했다. 보상 마스크와 움직이는 장식의 redraw는 유지한다.

검사 `godot/verify_range_projection_cache.gd`: 기존 _path와 점 배열 완전 일치, 카메라 이동/회전/줌/투영/오프셋/화면 크기·월드 흔들림/회전/스케일·맵 변경, 캐시 유지·초기화·상한을 확인했다. 검사 원본 로그 (당시 로컬 기록 `design/stage1_3d/range_visibility/cache/verification.log`): 728 checks, 0 failures. 고정 카메라에서 600프레임×6원 비교 시 투영 호출 349,200→582회, 좌표 계산 총 CPU 시간 98.668→1.029ms(캐시 쪽 context 비교 포함). 호출 수 검사에 사용한 카운터도 포함된 데스크톱 헤드리스 측정이며, 전체 게임 FPS·GPU 비용 측정이 아니다. 반투명 면을 그리는 비용은 남는다.

일반 Android release APK를 다시 설치해 본게임의 선택·고정 시점 (당시 로컬 기록 `design/stage1_3d/range_visibility/cache/selected-fixed.png`), 드론 시점 전환 (당시 로컬 기록 `design/stage1_3d/range_visibility/cache/selected-drone.png`), 설치 시 전체 원 (당시 로컬 기록 `design/stage1_3d/range_visibility/cache/placement-drone.png`)을 확인했다. 기존 선택·보상 표시 검사도 통과했다. 공개 배포와 변경 후 전투 FPS 재측정은 하지 않았다.


## 좌표 캐시 전후 Android FPS 측정

같은 비교용 release APK에서 화염 포탑 6문·정지 적 3기·1배속·1080×2424·고정 시점, 원 표시 조건과 나머지 그래픽을 유지하고 좌표 캐시만 전환했다. 준비 12초 + 측정 20초, 각 조건 2회. 순서는 선택 끔→켬, 설치 켬→끔, 설치 끔→켬, 선택 켬→끔이다. 측정 중 녹화·빌드는 하지 않았다. Flutter가 실행되지 않는 기존 Godot 단독 검증 장면이며 본게임 전체 HUD·전투 이관 결과는 아니다.

| 표시 상태 | 캐시 없음 FPS (2회) | 캐시 적용 FPS (2회) | 실행별 FPS의 평균: 전→후 |
|---|---:|---:|---:|
| 선택한 포탑 1개 | 28.38 / 26.24 | 29.39 / 23.49 | 27.31→26.44 |
| 설치 중 전체 6개 | 25.25 / 25.63 | 28.60 / 26.28 | 25.44→27.44 |

SurfaceView 실제 표시 FPS의 실행별 평균도 선택 27.43→26.40, 전체 25.45→27.61이었다. 전체 원은 두 쌍 모두 개선됐으나 증가 폭은 +3.36 / +0.64 FPS로 달랐다. 선택 1개는 결과가 엇갈려 개선을 확인하지 못했다. 선택 캐시 적용 두 번째 실행에는 p99 177.36ms의 지연이 있었고, 제외하지 않고 결과에 포함했다. 그 지연을 캐시 자체나 셰이더 컴파일 때문이라고 확정하지 않는다.

전체 표시의 process p95는 전 46.95 / 45.93ms, 후 41.71 / 45.38ms였다. 선택 1개는 전 42.54 / 45.09ms, 후 40.86 / 52.34ms였다. 좌표 계산의 큰 감소가 전체 FPS의 같은 비율 개선을 뜻하지 않는다는 결과다. 설치 상태 평균은 약 2 FPS 좋아졌지만 일반적인 보장 수치로 쓰지 않으며 60 FPS 목표도 미달이다. GPU 시간·실기기 성능은 미측정이다.

전체 원본·APK 해시·집계 (당시 로컬 기록 `docs/analysis/godot_validation_20260915/cache-comparison.json`), 대응 cache-*-fire.log 및 *-surfaceflinger.txt를 보존했다. 비교는 tool/godot_performance/native/range_comparison.gd의 검증 전용 switch를 사용하며 production의 캐시·표시 동작을 변경하지 않았다. 공용 production PCK 복원과 본게임 재실행을 확인했다. 최신 build/godot/validation.apk는 이 비교 APK이며 이전 레벨 비교 APK 해시와 구분한다.

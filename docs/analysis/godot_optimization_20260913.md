# Godot 중복 작업 최적화 전후 비교 — 2026-09-13

에뮬레이터의 포탄 4배속 장면에서 Godot 렌더 FPS는 17.6→29.2로 높아졌지만, Flutter raster 평균은 49.5→70.9ms로 악화했고 최대 Godot 프레임 간격도 294ms가 관측됐다. 일부 네이티브 렌더 작업 감소는 확인했으나, 전체 앱이 66% 빨라졌거나 테스터의 끊김이 해결됐다고 판정할 수 없다.

## 변경 범위

시각 품질을 유지하면서 반복 데이터 처리와 전송 비용을 줄이는 변경을 비교한다. 본게임 Flutter 전송은 epoch를 JSON 외피로 분리한 `submitFrameV2`를 사용하며, Kotlin 최신 프레임 슬롯 교체 시 전체 JSON을 다시 파싱하지 않는다. 최신 presentation을 제출 응답에 포함해 별도 조회 왕복을 줄인다. 기존 문자열 전송 API는 검수 앱 호환을 위해 유지한다.

Godot에서는 카메라 평면 맞춤 계산을 캐시하고, overlay 갱신을 `frame_pre_draw`에서 프레임당 한 번으로 합쳤다. 6~10스테이지 포장 타일은 이웃 타일에 가려지는 면을 제외하는 28종 MultiMesh 변형을 사용한다. 원래 재질의 텍스처 참조를 공유한다. 프레임 sequence가 같아도 카메라 전환에 따른 투영 변화는 반영하며, 실제 적용 응답을 효과 ACK로 사용하는 계약을 유지한다.

기준 소스는 [Godot main](godot_optimization_20260913/baseline/main.gd), [effects](godot_optimization_20260913/baseline/ui/battlefield_effects.gd), [selection](godot_optimization_20260913/baseline/ui/battlefield_selection.gd), [Flutter view](godot_optimization_20260913/baseline/lib/ui/hud/godot_battlefield_view.dart.txt), [Android bridge](godot_optimization_20260913/baseline/android/app/src/main/kotlin/com/example/rune_nexus/GodotBridge.kt)에 보관했다. Flutter 사본은 분석 대상에 포함되지 않도록 `.dart.txt`로 저장했다.

## 측정 조건과 한계

- Android 에뮬레이터에서 **release 격리 패키지**를 실행한다. 실제 `GameHud`와 전투 코드를 사용하며 저장소는 `MemorySave`다.
- 호스트는 Apple M4 / RAM 16GiB, 에뮬레이터는 `sdk_gphone64_arm64`다. 물리 화면은 1080×2424, Godot 보고 viewport는 880×1976이다. 기본 MSAA 2×와 높은 그림자 설정을 유지했다.
- 기준본 실행 후 최종 개선본을 실행했다. 중간 개선본의 텍스처 중복 상태는 최종 비교에서 제외했다. APK 크기·SHA-256·ABI는 [packaging.json](godot_optimization_20260913/packaging.json)에 기록했다.
- `stage10_idle`은 12초, `stage10_cannon4x`는 15초 워밍업한다. 두 번째 장면은 같은 포탑 6개·고정 대상 3개 시나리오를 4배속으로 진행한다. 각 버전·장면에서 서로 다른 metrics 창 15개와 종료 시 Flutter/game 요약을 수집한다. [측정 진입점](../../tool/godot_performance/main.dart).
- 전후 [기준 이미지](godot_optimization_20260913/baseline.png)와 [개선 이미지](godot_optimization_20260913/optimized.png)를 직접 비교해 타일 색·형태가 같음을 확인했다. 전투 입자의 애니메이션 위상 차이는 있다. draw/primitives는 아래에서 따로 비교한다.
- 실기기 측정이 아니므로 테스터 기기의 FPS 개선을 단정하지 않는다. 에뮬레이터의 GPU 가상화·호스트 스케줄링과 격리 패키지의 서비스 부하 차이가 결과에 영향을 줄 수 있다.
- `render_gpu_ms=0`은 이 측정 환경의 **GPU timing 미지원**을 뜻한다. GPU 비용이 0이거나 GPU 병목이 없다는 의미가 아니다.
- 각 조건 한 실행의 비교이며 반복 실험의 분산·유의성을 검증하지 않는다. 프로파일링과 로그 수집 부하는 양쪽에 동일하게 적용한다.

## 집계 방법

[`compare_logs.py`](godot_optimization_20260913/compare_logs.py)는 `RN_AB_CHUNK START …`, `CONT …`, `RN_AB_END`로 분할된 JSON을 복원한다. 미완성 JSON, 중복 프로파일 창, 원시 간격 수 불일치, 누락된 15개 표본·종료 요약은 오류로 처리한다.

```sh
python3 docs/analysis/godot_optimization_20260913/compare_logs.py \
  docs/analysis/godot_optimization_20260913/baseline.log \
  docs/analysis/godot_optimization_20260913/optimized.log
```

원시 로그는 [기준](godot_optimization_20260913/baseline.log)·[최종 개선](godot_optimization_20260913/optimized.log), 전체 집계는 [comparison.json](godot_optimization_20260913/comparison.json)·[상세 표](godot_optimization_20260913/comparison.md)에 보관했다. 잘린 기존 `RN_AB` 로그는 사용하지 않는다. 전체 원시 `frame_intervals_ms`를 합쳐 nearest-rank p50/p95/p99를 계산하며, 창별 분위수를 평균하지 않는다. FPS는 `전체 간격 수 × 1000 / 전체 간격 합(ms)`으로 계산한 **Godot 렌더 프레임 기준**이며 Flutter 합성을 포함한 전체 앱 FPS가 아니다. apply/json/render 시간은 각 지표의 프로파일 표본 수로 가중 평균하고 draw/primitives/메모리는 창별 값의 산술 평균을 사용한다. Flutter/game 종료 요약은 별도 계측 범위이므로 Godot 간격과 더하거나 동일 표본으로 해석하지 않는다.

## 결과

| 지표 | idle 기준→개선 | cannon4x 기준→개선 |
| --- | ---: | ---: |
| Godot 렌더 FPS | 39.29→39.32 | 17.59→29.20 |
| Godot 간격 p50 / p95 / p99 (ms) | 24.86 / 32.12 / 37.57→25.02 / 31.49 / 38.76 | 55.10 / 85.49 / 115.97→28.29 / 54.12 / 80.37 |
| Godot 최대 간격 (ms) | 51.51→46.81 | 144.22→294.34 |
| apply 평균 (ms) | 1.643→0.821 | 4.534→4.408 |
| JSON parse / render CPU 평균 (ms) | 0.297 / 1.242→0.348 / 1.307 | 0.585 / 1.517→0.899 / 2.145 |
| draw calls 평균 | 192→130 | 259.3→196.0 |
| primitives 평균 | 1,019,108→393,027（−61.4%） | 1,056,789→430,630（−59.3%） |
| game update 평균 (ms) | 0.049→0.038 | 0.295→0.393 |
| Flutter build 평균 (ms) | 1.436→1.623 | 3.453→4.719 |
| Flutter raster 평균 (ms) | 30.562→33.435 | 49.541→70.853 |
| Flutter raster p95 / p99 (ms) | 40.25 / 56.69→43.60 / 47.40 | 113.20 / 133.74→133.54 / 166.44 |

Godot 원시 간격 표본은 idle 598→597개, cannon4x 275→451개다. 텍스처 메모리는 idle 305,446,528 bytes, cannon4x 317,732,224 bytes로 전후 동일하다. video memory는 idle 371,658,528→385,068,128 bytes（+12.79MiB）, cannon4x 평균 389,681,773→403,041,453 bytes（+12.74MiB）로 증가했다. 추가 메시 변형 비용과 함께 고려해야 한다. GPU timing은 양쪽 모두 미지원이다.

## APK 포함 항목

기준 APK는 284,806,109 bytes, 최종 APK는 284,809,981 bytes로 차이는 3,872 bytes다. 두 APK 모두 arm64-v8a만 포함하며, APK 내부에 원시 GLB나 `design/` 파일은 없다. PCK에는 최적화 에셋의 import 결과 17,101,604 bytes가 **양쪽 모두** 들어 있다. 따라서 APK B−A를 신규 에셋의 추가 용량으로 해석할 수 없다. 전체 내역과 해시는 [packaging.json](godot_optimization_20260913/packaging.json)에 있다. 이번 비교는 공개 배포가 아니며 이전 공개 APK와의 비교는 수행하지 않았다.

## 판정과 검증

idle의 전체 Godot 간격은 거의 같지만 apply 시간과 draw/primitives가 줄었다. 포탄 장면에서는 Godot FPS와 p95/p99가 개선됐다. 반면 Flutter raster 평균은 43.0% 증가했고, game update·Flutter build·Godot render CPU 평균도 늘었다. 최대 간격은 단일 294.34ms 이상치로 기준보다 커졌다. 이를 특정 변경의 인과 효과로 분리한 실험은 아니며, 긴 지연과 Flutter 합성 비용이 남아 있다. 반복 측정 분산도 확인하지 않았으므로 판정은 **일부 네이티브 렌더 작업 개선, 전체 체감 성능 해결은 미확인**이다.

전후 캡처에서 타일 색·형태 보존을 확인했고, [재질·텍스처 동일성 기록](godot_optimization_20260913/texture_identity.json)에서도 GLB PBR 정의와 내장 이미지 payload가 일치한다. 이는 GPU readback 검증을 뜻하지 않는다.

- Godot protocol·camera headless 검사: 실패 0건.
- 타일 포장 검사: 실제 Metal 렌더러에서 6~10 및 6 재진입, 실패 0건. headless dummy 렌더러는 이 검사의 MultiMesh 읽기 검증을 지원하지 않으므로 실제 렌더러 결과를 사용했다.
- `flutter analyze`: 문제 없음. 관련 Flutter 테스트: 14개 통과, 기존 웹 대상 테스트 1개 skip.
- 일반 `lib/main.dart` APK에서 메모리 저장 fixture로 10번 맵 [고정 시점](godot_optimization_20260913/main-angled.png)·[드론 시점](godot_optimization_20260913/main-drone.png)을 직접 확인했다. 실제 UI로 [대포 설치](godot_optimization_20260913/main-build.png) 후 90G 차감과 타일 중심·선택 표시를 확인했다. 검증 후 원래 저장을 사용하는 앱으로 복구했다. 디버거의 프레임 중간 상태 변경으로 생긴 초기 검증 오류는 다음 이벤트에서 전환하도록 절차를 고쳐 해결했으며 게임 코드를 바꾸지 않았다.

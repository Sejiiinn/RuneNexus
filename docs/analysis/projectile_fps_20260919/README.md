# 탄환 표시 최적화 후 기존 FPS 측정 재실행

2026-09-19. [9월 16일 통합 측정](../godot_validation_20260916/README.md)의 같은 실행 도구·조건을 재사용했다. 현재 결과는 대포 44.06, 화염 31.47 Flutter 갱신/초이며 모두 60에 미달한다. 과거 기록과의 비교이고 이번 탄환 변경만을 켰다 끈 A/B는 아니다.

## 조건

- Apple M4 호스트, Android API 37 `sdk_gphone64_arm64` 에뮬레이터. 화면 1080×2424, DPR 2.625, Godot viewport 880×1976, mobile renderer 4.7.2.
- ARM64 release 별도 검수 패키지 `com.example.rune_nexus.godotpreview`, 기존 `GameHud`·Flame 전투·Godot 연결. 메모리 저장소를 사용하며 본게임 계정·보상 선택을 변경하지 않았다.
- 스테이지 1, 포탑 6개·정지 불사 탱커 3개, 1배속, 대포→화염 순서. 화염 상태 적 2개. 기존 기본 그래픽과 전체 효과 유지.
- 각 조건 워밍업 8초+snapshot 기록 후 2초 대기, 1초 간격 60회 수집. 실제 측정 시간 대포 61.591초, 화염 62.254초. 녹화·화면 캡처·빌드와 겹치지 않았다.
- 양쪽 snapshot의 `projectileEvents` 존재를 확인했다. 현재 `projectiles: 0`, `effects: 0`은 반복 전송 배열이 비었다는 뜻이며 실제 탄환·효과가 없다는 뜻이 아니다.

## 이전 기록과 비교

| 항목 | 대포: 이전 → 현재 | 화염: 이전 → 현재 |
|---|---:|---:|
| Flutter 갱신/초 | 40.54 → **44.06** (+8.7%) | 25.05 → **31.47** (+25.6%) |
| 갱신 간격 p95 | 41.43 → 35.73ms | 57.29 → 44.58ms |
| 갱신 간격 p99 | 51.67 → 47.25ms | 68.59 → 55.07ms |
| 최대 갱신 간격 | 103.73 → 163.75ms | 119.10 → 80.48ms |
| 게임 update 평균 | 0.108 → 0.070ms | 0.686 → 0.438ms |
| Flutter build 평균 | 2.055 → 3.080ms | 7.302 → 6.843ms |
| Flutter raster 평균 | 13.564 → 11.415ms | 22.824 → 17.029ms |

Flutter 갱신/초는 전투 update 호출 수÷실제 측정 시간이다. 갱신 간격 분위수는 update 진입 간격이며 Android 최종 화면 표시 FPS나 GPU 실행 시간이 아니다. 평균이 높아졌지만 대포의 최대 지연은 악화했고, 화염의 갱신 간격 33.334ms 초과 비율은 37.39%다.

SurfaceFlinger도 별도로 수집했다. 검수 Activity의 SurfaceView는 대포 42.257 / 화염 40.131 FPS, VRI 레이어는 33.721 / 27.289 FPS다. 서로 다른 레이어의 표시 주기이며 이를 합산하거나 하나의 전체 앱 FPS로 바꾸지 않는다. 원시 레이어 이름·히스토그램은 아래 자료에 보존했다. GPU 시간은 미측정이다.

## 실행·근거

기존 `tool/godot_performance/build_validation.py`에 `RN_VALIDATION_SECONDS=60`을 전달했다. 기존 검수 APK를 데이터 삭제 없이 교체하기 위해 Flutter 빌드 인자에 `--build-number=6015`만 추가했다. 실행은 기존 `run_baseline.py`의 결과 디렉터리를 이 폴더로 지정하고 `RN_BASELINE_TAG=projectile`, `RN_BASELINE_STOP_AFTER=fire`로 두 조건까지만 수행했다. Godot 단독 모드는 Flame 잔상·전송 비용을 포함하지 않으므로 이번 통합 비교에 섞지 않았다.

- [원시 로그](projectile-final.log), [복원 JSON](projectile-final.json), [비교 JSON](comparison.json), [집계 스크립트](summarize.py)
- [대포 SurfaceFlinger](projectile-normal-surfaceflinger.txt), [화염 SurfaceFlinger](projectile-fire-surfaceflinger.txt)
- [빌드 로그](build.log), [실행 소스·APK 해시](inputs.json)

60개 표본씩, 6포탑·3표적 유지와 종료 요약을 확인했다. 원하는 두 조건 뒤 검수 프로세스를 종료했으므로 전체 4개 시나리오용 runner의 `complete` 레코드는 의도적으로 없다. 검수 후 일반 본게임을 다시 열었고 production Godot 팩은 빌드 도구가 복원했다.

같은 방법의 단회 과거/현재 비교다. 9월 16일 이후 다른 변경과 호스트 부하·실행 시점 차이가 포함되어 있어 증가율을 이번 탄환 최적화의 독립 효과로 확정할 수 없다. 실제 모바일 기기의 60 FPS·발열·지속 성능 통과를 뜻하지 않는다.

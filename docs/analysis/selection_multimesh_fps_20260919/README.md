# 선택 이관·화염 MultiMesh 후 FPS 재측정

2026-09-19. 기존 60초 통합 측정을 재실행했다. 대포 45.24, 화염 29.93 Flutter 갱신/초. 직전 대비 대포는 소폭 상승하고 화염은 하락하여 **이번 측정에서는 화염 전체 프레임 성능 개선을 확인하지 못했다.**

## 조건과 비교

[직전 탄환 개선 측정](../projectile_fps_20260919/README.md)과 같은 Apple M4 호스트·Android API 37 ARM64 에뮬레이터, 1080×2424, Godot 4.7.2 mobile renderer, ARM64 release 검수 패키지 `com.example.rune_nexus.godotpreview`다. 스테이지 1, 포탑 6개·정지 불사 탱커 3개, 1배속, 대포→화염 순서, 기본 그래픽·전체 효과 유지. 각 조건 8초 워밍업+snapshot 후 2초 대기, 1초 간격 60회 수집. 실제 측정 시간은 61.444초·62.244초. 측정 중 빌드·화면 녹화·캡처 없음.

| 항목 | 대포: 직전 → 현재 | 화염: 직전 → 현재 |
|---|---:|---:|
| Flutter 갱신/초 | 44.06 → **45.24 (+2.7%)** | 31.47 → **29.93 (-4.9%)** |
| 갱신 간격 p95 | 35.73 → 34.32ms | 44.58 → 48.25ms |
| 갱신 간격 p99 | 47.25 → 46.08ms | 55.07 → 57.86ms |
| 최대 갱신 간격 | 163.75 → 74.14ms | 80.48 → 76.06ms |
| 게임 update 평균 | 0.070 → 0.080ms | 0.438 → 0.471ms |
| Flutter build 평균 | 3.080 → 3.039ms | 6.843 → 7.286ms |
| Flutter raster 평균 | 11.415 → 11.231ms | 17.029 → 17.794ms |

SurfaceFlinger 별도 수집: SurfaceView 대포 44.565 / 화염 39.011 FPS, VRI 레이어 34.681 / 26.091 FPS. 레이어별 표시 주기이며 합산하거나 하나의 전체 앱 FPS로 해석하지 않는다. 위 표의 FPS는 Flame update 호출 수/실제 측정 시간이다. GPU 실행 시간은 미측정이다.

단회 과거/현재 비교이며 이번 변경을 켰다 끈 동일 시점 A/B가 아니다. 호스트 부하·실행 시점의 변동을 포함하므로 화염 하락의 원인을 MultiMesh로 확정할 수 없다. 두 조건 모두 60 FPS 미달이다. 실제 모바일 기기 지속 성능·발열은 미측정이다. 기존 barrage 하네스는 preparation 상태의 HUD publish 동작을 포함한다. 비교 조건을 유지하려고 이번에는 이를 변경하지 않았으며 실제 wave 성능과 동일하다고 가정하지 않는다.

## 재현과 자료

기존 `build_validation.py`에 `RN_VALIDATION_SECONDS=60`, Flutter 빌드 인자에 기존 검수 버전 유지용 `--build-number=6015`를 추가했다. 기존 runner `run_baseline.py`는 이 결과 디렉터리와 `RN_BASELINE_TAG=selection`, `RN_BASELINE_STOP_AFTER=fire`로 실행했다. 메모리 저장소의 별도 검수 앱이라 본게임 저장을 변경하지 않는다. production Godot 팩은 빌드 도구가 복원했고 측정 후 일반 본게임으로 복귀했다.

- [원시 로그](selection-final.log), [복원 JSON](selection-final.json), [비교 JSON](comparison.json), [집계 코드](summarize.py)
- [대포 SurfaceFlinger](selection-normal-surfaceflinger.txt), [화염 SurfaceFlinger](selection-fire-surfaceflinger.txt)
- [빌드](build.log), [설치](install.log), [실행 입력·APK 해시](inputs.json)

각 조건 60개 표본, 6포탑·3표적, 화염 조건의 화상 적 2개, 종료 요약과 탄환 이벤트 입력을 확인했다. snapshot은 stateless encoder로 만든 전체 선택 DTO이므로 실제 view의 ACK 이후 선택 전송량 측정으로 사용하지 않는다. 반복 배열의 projectiles/effects 0도 효과 부재를 뜻하지 않는다. 로그에 SCRIPT ERROR·Parse Error·FATAL EXCEPTION 없음. 두 조건 뒤 의도적으로 종료하여 전체 시나리오용 complete 레코드는 없다.

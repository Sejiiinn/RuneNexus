# 저장 검증과 복원 데이터 생성 분리

> 원시 로그·일회성 검사·측정 덤프는 로컬 기록으로 Git 추적에서 제외했다. 본문의 요약 결과와 유지되는 회귀 테스트는 보존하며, 아래 로컬 기록은 새 체크아웃에 포함되지 않는다.

2026-09-28. 기준 원본은 `717f881f`의 `content_run_save.gd`와 `content_catalog.gd`다. [현행 저장 계약](../../../godot/app/README.md)을 보존하면서 `capture()`가 복원 결과를 만들고 버리던 경로를 공통 검증으로 교체했다. 검증에 성공한 `prepare()`에서만 전투 초기 설정·포탑·적·남은 스폰 데이터를 만든다.

## 결과와 근거

- 관련 회귀 (`implementation-regressions.log`, 로컬 기록): 콘텐츠 저장·복원, 저장 어댑터, codec, 런 명령, 웨이브/코어 검사 통과. 저장 시 `bootstrap`·`enemy`·`random_spawn_values`·`turret` 생성 호출은 모두 0회이며 실제 복원에서는 계속 생성한다.
- [별도 Astra 독립 검증](independent-review.md): 30개 capture와 109개 prepare의 성공/거부·오류·입력 불변 및 성공 복원 결과와 후속 RNG 상태가 원본과 일치했다. 기존 젬 이관과 잘못된 타일·포탑·스폰·체력·라운드·배율을 포함한다. 원본 대조 로그 (`independent-run.log`, 로컬 기록).
- [실제 앱](app-result.json): Godot 4.7.2 macOS의 `main --app`, 스테이지 15에서 강화·런 구매, 진행 중 적과 남은 스폰 저장, 실제 체크포인트 복원 및 재저장의 25개 검사가 통과했다. 잘못된 레벨 저장 거부, 기존 디스크 파일 보존, 실패 시 정지와 정상 재시도도 확인했다. 이전 구현 (`baseline/app-result.json`, 로컬 기록)도 같은 검사에서 통과했다. 실행 코드 (`verify-app.gd`, 로컬 기록) · 소스 해시 (`app-inputs.json`, 로컬 기록) · 로그 (`app.log`, 로컬 기록).
- 추가 콘텐츠 검사 (`supplemental-catalog-check.log`, 로컬 기록): stage/wave/type/layout/config/enemyValues 거절 검사는 통과했다. 과거 Dart 콘텐츠 fixture 대조는 변경 전후 모두 52,373개 검사 중 같은 128개 실패와 동일 오류 목록을 반환했다. 이번 변경의 회귀가 아닌 기존 불일치이며, 전체 콘텐츠 fixture 검사를 통과로 처리하지 않았다. 원본 로그 (`supplemental-catalog-reference-baseline.log`, 로컬 기록) · 변경 후 로그 (`supplemental-catalog-reference-current.log`, 로컬 기록).

검사 프로젝트와 저장은 기존 `RuneNexus-HUD-Incremental-Review` 격리 환경을 재사용했다. 사용자 플레이 저장·운영 API는 사용하지 않았다. 파일 쓰기·백업 정책과 저장 스키마는 변경하지 않았다. 검증에서 거부한 복원은 난수를 미리 소비하지 않으며, 이는 실제 복원 결과가 없는 실패 경로의 의도된 차이다.

## CPU 측정

[측정 결과](benchmark-result.json): 데스크톱 headless에서 동일한 스테이지 15, 라운드 인덱스 36, 포탑 2개·살아 있는 적 12개·남은 스폰 29개의 입력을 사용했다. 이전/개선 구현 순서를 교대하며 7배치 × 각 40회 측정한 배치 평균의 중앙값은 capture당 **10.981ms → 7.249ms**, 약 **34.0% 감소**였다. 양쪽 v2 저장 결과는 완전히 같고 입력 상태도 변하지 않았다. 실행 코드 (`benchmark-capture.gd`, 로컬 기록) · 로그 (`benchmark-run.log`, 로컬 기록) · 원본 저장 코드 (`benchmark-old-save.gd`, 로컬 기록) · 원본 카탈로그 (`benchmark-old-catalog.gd`, 로컬 기록).

이 수치는 해당 입력의 저장 데이터 생성·검증 CPU 시간이며, 파일 직렬화·읽기·백업·쓰기, GPU와 전체 FPS는 포함하지 않는다. 측정 배치 간 편차가 있으므로 전체 저장이나 실기기 성능의 개선율로 해석하지 않는다.

Android/A34의 실제 프레임 지연과 전체 저장 시간은 미측정이다.

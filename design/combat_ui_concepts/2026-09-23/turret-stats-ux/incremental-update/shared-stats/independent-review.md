# 전투·HUD·선택 공유 스탯 독립 검증

판정: **PASS**. 2026-09-28, macOS Godot 4.7.2 headless. 저장소 구현 소스는 수정하지 않고 격리 임시 프로젝트의 `Stats.stats_at` 첫 줄에 독립 카운터를 삽입했다. 구현자의 shared_calculation_count를 자체 통과 근거로 재인용하지 않았다.

## 근거

- `independent-check.gd`: 별도 검증 시나리오. 282 기존 fixture × 거리 3종 × core 배율 2종 × cleanup 2종 = **3,384** 조합.
- `independent-oracle-stats.gd`, `independent-oracle-catalog.gd`, `independent-oracle-runtime.gd`: 공유구조 구현 전 직접 보존한 원본. 원본 계산과 모든 결과 dictionary를 정확히 비교했다. selection oracle은 직전 display-cache의 committed uncached 원본이다.
- `independent-run.log`: 3,384조합 + 23통합상태, `INDEPENDENT_SHARED_STATS failures=[]`, 실행 exit 0.
- `independent-save.log`: 기존 관련 저장·복원 회귀 `CONTENT_RUN_SAVE failures=0`, exit 0.
- `independent-source-hashes.json`: 실제 검증한 7개 소스의 SHA-256. 최종 반환 직전 현재 파일과 일치 확인.

## 관측 결과

6종 포탑 초기 전투 + HUD 생성 합계는 stats_at 6회였다. 이후 전투 명령→HUD→selection 전체 경로에서 unchanged 0회, 개별 level 1회, 새 preview 1회, preview 반복·해제 0회, 계산한 preview를 현재 레벨로 승격 0회였다. 공격 동기화 on/off 및 cleanup 변화는 추가 중립 계산 0회이며, native의 보정된 스탯과 수호광선 기초피해는 원본 runtime과 정확히 같았다. HUD 기본 전투력은 일시적 core 버프에 따라 바뀌지 않았다.

전역 런 강화·코어 rank·영구 성장·젬/종류 다양성·삭제/동일 ID 재생성·세션 교체·content catalog 내부 변경/객체 교체·성장 객체 교체 및 hotedit 후 명시 invalidate를 검증했다. HUD 전체 stats·성장 derived dictionary·전체 합산 DPS·selection 전체 dictionary(범위/preview/색/궤도 젬)와 native 실제 stats를 원본과 대조했다. native turret 저장 snapshot도 원본과 일치했다.

거리 1/48 및 다른 scale, core 피해/공속 배율, cleanup 후처리의 곱 순서를 원본과 정확히 비교했다. 반환 dictionary를 훼손한 후 재조회, 입력의 nested definition 변경, 동일 hash bucket에 다른 입력의 가짜 항목을 앞에 넣은 경우도 올바른 결과를 냈다. 300개 입력 이후 order와 bucket 총 보관 수는 각각 256이며, 퇴출된 입력의 재계산도 원본과 같았다.

## 실제 앱 근거와 한계

부모의 실제 main 앱 89개 검사와 440/320 화면 검수는 `app-result.json`, `app-inputs.json`, 앱 캡처 근거를 따른다. 부모 실측에서 preview 1회, 확정 추가 0회, 2포탑 전역 강화 2회가 확인됐다. 독립 담당은 headless 계약·수치·계산 횟수 검증을 수행했다.

미해결 결함 없음. 성장 카탈로그를 개발 도구가 in-place 변경할 때는 직전 합의대로 명시 invalidate()가 필요하다. 전체 FPS/CPU 시간, A34/Android GPU/발열은 측정하지 않았다. 남는 hash·입력 비교·복사 비용과 후처리가 있으므로 중복 stats_at 감소를 전체 프레임 개선율로 해석하지 않는다.

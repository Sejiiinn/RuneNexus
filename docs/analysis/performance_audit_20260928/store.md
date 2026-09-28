# 저장 경로 비용 점검

> 원시 로그·일회성 검사·측정 덤프는 로컬 기록으로 Git 추적에서 제외했다. 본문의 요약 결과와 유지되는 회귀 테스트는 보존하며, 아래 로컬 기록은 새 체크아웃에 포함되지 않는다.

2026-09-28. 실행 코드 변경 없이 Godot 4.7.2 데스크톱 headless 격리 프로젝트에서 측정했다. 기존 capture 검증/복원 분리 이후에도 남은 저장소 경로를 대상으로 한다.

`godot/app/app_lifecycle.gd:246`의 강화 등 런 명령은 성공 후 `persist_progression()`을 동기 호출한다. `godot/app/local_save_store.gd:62`는 새 저장 검증·직렬화 후 기존 저장을 다시 읽고, JSON 파싱·canonical 검증·decode를 수행한다(`:125–135`). 백업에는 decode한 객체가 아닌 기존 raw 문자열만 사용한다. 변경된 저장이면 백업과 본문 두 파일을 atomic write/flush한다.

15스테이지, 포탑 2, 생존 적 12, 대기 29, 저장 11,704자 fixture에서 savedAtMillis를 갱신하며 20회씩 5묶음 측정했다. 묶음별 평균의 중앙값은 저장소 전체 **10.346ms**, 기존 저장 읽기·파싱·검증·decode **7.748ms**, atomic write 합 **1.171ms**였다. 실제 쓰기는 매 저장 2회였다. 항목별 중앙값은 서로 다른 묶음에 해당할 수 있어 단순 합산하지 않는다.

capture·전투·UI·GPU는 제외했고 OS 파일 캐시를 포함한 wall time이다. A34 실측이나 전체 강화 지연 수치가 아니며 단일 짧은 실행으로 측정 분산이 있다. 원시 결과는 [store-result.json](store-result.json), 실행 코드는 verify-store-cost.gd (`verify-store-cost.gd`, 로컬 기록), 로그는 store-run.log (`store-run.log`, 로컬 기록).

개선 후보는 이미 검증한 저장 원문/상태의 재사용과 불필요한 decode 제거다. 백업 복구·외부 파일 변경·실패 처리·즉시 저장 계약을 보존해야 하며, 무조건 백업이나 flush를 없애는 개선을 뜻하지 않는다. 현재 관측에서는 파일 쓰기보다 기존 저장 재검증 경로의 비용이 크다.

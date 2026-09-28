# 저장 검증과 복원 생성 분리 — 독립 검증

판정: **PASS**. 2026-09-28. macOS / Godot 4.7.2 headless, 사용자 저장과 분리한 임시 프로젝트. 검증자는 구현 소스를 수정하지 않았다.

## 비교 방식과 근거

- 구현 전 `content_run_save.gd`를 `independent-oracle-content-save.gd`에 보존했다.
- 변경 전 커밋의 catalog는 `independent-oracle-catalog.gd`에 보존했다. 원본 adapter가 변경된 catalog를 사용해 결함을 가리지 않도록 독립 catalog 인스턴스로 실행했다.
- `independent-adapter.gd`는 현재/원본 양쪽을 같은 입력으로 실행하며 accept/reject, error 문자열, 전체 반환 dictionary, 성공 prepare의 seeded RNG 후속 상태를 비교한다. 입력 불변은 Variant 직렬화 byte 비교로 확인하여 NaN 비교 자체의 거짓 실패를 피했다.
- `independent-check.gd`는 기존 실제 콘텐츠 fixture·legacy migration 사례와 별도 변조 입력 matrix를 실행한다.
- `independent-run.log`: **capture 30회 / prepare 109회**, `parity_failures=[]`, `fixture_failures=0`, exit 0.
- `independent-source-hashes.json`: 실행한 소스 SHA-256. 최종 검토 시 현재 source와 동일함을 확인했다. 변경한 두 파일의 diff whitespace 검사도 통과했다.

## 확인 결과

모든 capture 30회에서 CounterCatalog가 계측한 `bootstrap`, `enemy`, `random_spawn_values`, `turret` 호출은 각각 **0회**였다. catalog의 공통 검증 경로를 호출하고 복원 결과 생성만 제거한 것을 소스로도 확인했다. prepare의 성공 결과는 state/bootstrap/session/envelope를 포함해 변경 전 결과와 정확히 같았다.

검증 범위에는 진행 중 적과 대기 스폰이 있는 구매 보상 상태, pause 복원, preparation/reward/success/failure, coreDestruction 정규화, 라운드 경계, 맵 signature, 포탑 종류/좌표/중복 타일/레벨/소켓/특성/젬, 코어 HP, 업그레이드 범위, 적 종류, 스폰 개수/순서/지연, origin/tile scale, enemyValues, 누락 snapshot 필드·중복 turret snapshot·미정산 event, 비정수/비유한 값이 포함된다. 6종 포탑 legacy lightWeapon 반환·재저장·재복원은 반환 중복 없이 원본과 같았다. capture/prepare 모두 원본 입력을 변경하지 않았다.

## 합의된 의도적 차이

실패 prepare #92 (`Invalid spawn delay`)는 변경 전 RNG를 소비한 뒤 실패했고, 변경 후 먼저 거절하여 RNG를 소비하지 않았다. 부모가 실패 prepare의 불필요 RNG 소비를 보존 대상에서 제외하도록 명시했으므로 허용한다. 같은 성공 입력과 seed에서는 전체 복원 결과 및 후속 RNG 상태가 같았다. 실패 여부/오류 문자열/입력 불변은 실패 사례에서도 동일했다.

## 저장 내구성과 실제 앱 근거

`app_lifecycle.gd`, `session_checkpoint.gd`, `local_save_store.gd`는 이번 변경에서 수정되지 않았다. 부모의 baseline/after 실제 stage15 앱 검증은 각각 25개 검사를 통과했고, 강화/구매 후 live enemy·pending queue가 있는 저장→load→재capture의 포탑·적·큐·골드·HP 동일성을 확인했다. 잘못된 레벨 저장 거부, 디스크의 기존 저장 보존, 실패 정지 및 정상 재시도 근거는 `app-result.json`, `app-inputs.json`, `app.log`, `baseline/`를 따른다. 독립 담당의 범위는 위 원본 대조와 생성 호출 계측이다.

미해결 결함 없음. 이 결과는 불필요 복원 생성 제거와 계약 동등성을 확인한 것이며, A34/Android 프레임·저장 wall time 또는 전체 FPS 개선율은 측정하지 않았다. 상태 복사·정규화·검증·직렬화·동기 디스크 쓰기는 여전히 남는다.

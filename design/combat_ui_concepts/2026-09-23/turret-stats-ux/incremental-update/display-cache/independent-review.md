# 표시 스탯 캐시 독립 검증

판정: PASS. 2026-09-28, macOS Godot 4.7.2 headless, 임시 프로젝트/저장 격리. 구현 소스는 검증자가 수정하지 않았다.

- `independent-check.gd`: 별도 CountingCatalog subclass가 실제 turret_stats 호출을 기록한다. 수치 oracle은 캐시를 거치지 않는 원본 catalog 계산이다.
- `independent-oracle-selection.gd`: 작업 전 HEAD의 selection 원본. 최종 selection 전체 dictionary를 비교했다(범위/preview/색/위치/궤도 젬 포함).
- `independent-final.log`: 19개 상태, failures=[], exit 0. HUD 전체 stats dictionary·derived configuration·전투력 합산과 selection 결과 일치.
- `independent-source-hashes.json`: 최종 실행 대상 4개 구현 파일 SHA-256.

6포탑 warm 이후 unchanged=0회, 개별 level=2회(대상 포탑 tileSize 1/48 각각 1회), preview 생성=2회, preview 반복/해제·wallet만 변경=0회. 전역 런강화, 코어 rank, 젬/종류 다양성, 삭제/동일 ID 재생성, 세션 교체, content catalog 내부 변경/객체 교체, 영구 physical 성장, 성장 객체 교체, 성장 hotedit 후 invalidate를 확인했다. 선택 HUD 꾸밈 뒤 cache dictionary에 dps/burnDuration이 남지 않는 것도 최종 raw dictionary 일치로 확인했다.

최초 검증에서 관찰한 성장 content in-place stale과 HUD 꾸밈의 cache dictionary 오염은 부모·구현자에게 반환했다. 최종 구현은 꾸밈 소비자의 shallow copy 및 명시 invalidate API/주석 계약을 추가했다. 정상 플레이의 progression/runUpgrade 변화는 자동 감지하며, 개발 도구가 growth.data를 직접 수정할 때는 invalidate()가 필요하다. 최종 로그가 과거 `independent-run.log`의 중간 진단보다 우선한다.

캐시 bind의 content turrets/units deep equality는 매 호출에 남는 검사 비용이다. 호출 수 감소를 전체 CPU·프레임 시간 감소로 해석하지 않았다. A34/Android GPU·전체 FPS·발열·wall time은 미측정. 실제 화면 검증은 부모의 별도 앱 근거를 따른다.

# 스테이지 결과창

2026-10-02 사용자 승인 기준은 [첫 번째 시안 01](01-reward-hierarchy.png)이다. 내장 ImageGen으로 제작했으며 수치는 예시다. 02는 탐색 기록이고 현행 구현 기준이 아니다.

## 승인된 외형과 동작

큰 중앙 청록 성공 크리스탈·주황 붕괴 크리스탈, 중앙 결과 제목·스테이지 부제, 각진 남청 금속·청동 외곽을 사용한다. 보상은 아이콘·종류·수량으로 구분해 조건부 열로 표시한다. 전투 기록은 라벨 왼쪽·값 오른쪽의 별도 프레임, 첫 클리어 해금은 별도 프레임으로 구성한다. 기존 ‘확인’의 로비 스테이지 화면 이동을 ‘스테이지 선택’으로 명시하고 ‘다시 시작’과 같은 줄에 둔다. 작은 화면에서는 내용 내부 스크롤로 정보와 행동에 접근한다.

룬·조건부 코어 포인트·티켓, 도달 라운드·기록·최고 피해 포탑/수치·현재 룬, 첫 클리어 해금을 실제 상태에서 읽는다. 사용자 후속 지시에 따라 정산 대기 문구는 고정하지 않는다. 종료 저장·보상 큐 영속 기록 직후 서버 정산을 요청하고 실제 요청 중·완료·통신 실패·오프라인·저장 실패를 구분한다. 실패 시 영속 재시도와 서버 권위를 보존한다. 정산·저장 계약은 [서버 경제 기준](../../../docs/server_authoritative_economy_design.md#65-로컬-플레이-보상)을 따른다.

정보·행동의 원본은 [결과창 presenter](../../../godot/ui/battle_rewards.gd), [진행/해금 정의](../../../godot/content/generated_progression.gd), [공통 디자인 기준](../../../DESIGNS.md)이다.

## 구현과 검증

승인 01의 중앙 상징·청동 외곽·청록 구획을 새 PNG 4개로 적용했다. [승리·첫 클리어 실제 화면](implementation/victory-first-clear-440x900.png) · [패배 실제 화면](implementation/failure-440x900.png). 편집 가능한 XCF와 생성 프롬프트는 `production/`에 보존하고, 게임에는 `assets/images/results/`의 최종 PNG만 연결했다.

Godot 4.7.2 / macOS Metal Forward Mobile / Apple M4의 격리 `--app` 실행에서 440×900·320×680을 확인했다. 제어된 런 종료와 격리 인증 HTTP fixture를 사용했고, 보상·해금은 실제 도메인 종료 계산에서 읽었다. 스테이지 1은 실제 2열 보상·해금, 스테이지 11은 모듈 티켓을 포함한 3열 보상으로 확인했다. 부모도 최종 승리·패배 캡처를 직접 검토했다.

별도 `gpt-6.1-sol / high` 독립 검증 **PASS**, 미해결 없음. 승인 01의 형태·색·재질·정보 위계, 작은 화면 내부 스크롤, 실제 포인터 재시작·스테이지 이동, 정산 중→완료 갱신과 저장 실패 이동 차단·복구를 확인했다. 즉시 인증 요청·영속 기록 순서·동일 요청 재시도·중복 억제·계정 교체 중 늦은 응답·오프라인 보존·서버 잔액 권위·영구 거절 구분도 자체 계약 검사와 관련 유지 회귀로 확인했다. 게스트 큐는 계정으로 자동 이관하지 않으며 화면에서도 게스트 서버 정산 제외를 명시한다.

상세 로컬 근거는 `build/godot/result-ui-review/implementation-summary.json`, `build/godot/result-independent-review/review-summary.json`, `build/godot/result-settlement-review/`에 보관한다. 유지 회귀는 `godot/verify_result_settlement.gd`와 기존 economy/run/reward 검사를 사용한다. 사용자 저장과 열린 에디터를 보존했다. Android APK·실계정 서버 보상 요청·배포는 수행하지 않았다.

## 시안 제작 기록

[승인 01](01-reward-hierarchy.png) · [미채택 탐색 02](02-compact-results.png) · [초기 프롬프트](prompt-01.txt) · [02 수정 프롬프트](prompt-02.txt)

01은 02 생성의 편집 입력이기도 하다. 실제 Godot `--app` 결과창을 격리 fixture로 캡처해 참조했고 로컬 원본은 `build/godot/fire-stat-area-review/current-victory-result-440x900.png`에 있다. [과거 결과창 탐색](../../combat_ui_concepts/2026-09-22/08-results.png)은 재질 참고로만 사용했다.

02 이미지 시안은 보상·정산 상태·4개 기록·조건부 해금·두 행동과 한글 가독성 검수를 통과했지만 사용자는 01을 선택했다. 당시 이미지 검수는 실제 게임 적용·반응형·조작 검증이 아니다.

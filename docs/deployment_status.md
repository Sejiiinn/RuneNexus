# 배포 상태와 세션 간 인계

배포 요청을 처리할 때 이 문서와 [운영 배포 절차](self_hosted_api_deployment.md)를 먼저 확인한다.
이 문서는 마지막으로 검증한 이력이며 실시간 운영 상태가 아니다. 배포 직전 실제 DB 버전,
실행 중인 API 이미지, 공개 웹 커밋, 최신 APK release를 다시 확인한다.

## 마지막 확인된 운영 상태

2026-09-08 배포 완료 기준:

- API와 웹: 커밋 `8ccb32b` (종료 정산 기반 리더보드와 메인 로비).
- 운영 DB: migration 009까지 적용. HTTPS health/live·health/ready 정상 확인.
- 웹 workflow: `34200652899` 성공. 공개 main.dart.js의 커밋과 리더보드 API 연결 확인.
- Android workflow: `34200655266` 성공. `apk-8`, versionCode 8, versionName 0.1.7.
- 배포 전 DB 백업을 생성하고 pg_restore 목록 검사를 완료했다. 백업과 비밀 설정은 Git에 넣지 않는다.

## 다음 배포에 필요한 변경 — 아직 미배포

메인 로비 스크롤 제거와 진행 중 클리어 기록의 리더보드 반영 코드가 대상이다.

1. 배포 대상 커밋을 확정하고 그 커밋의 서버 코드와 migration을 함께 준비한다.
   작업 트리에 섞인 미커밋 변경으로 운영 이미지를 만들지 않는다.
2. 운영 DB의 현재 migration 버전과 백업·복원 가능 여부를 확인한다.
3. [010_leaderboard_save_progress.sql](../server/db/migrations/010_leaderboard_save_progress.sql)을
   **새 API를 시작하기 전에** 적용한다. 더 이전 버전이라면 tern으로 누락된 순서를 모두 적용한다.
   새 SQL 쿼리가 source_save_revision을 참조하므로 009 DB에 새 API만 올리면 저장과 정산이 실패한다.
4. 동일 커밋으로 빌드한 API를 교체하고 DB 버전 10 및 health/live·health/ready를 확인한다.
5. 웹과 APK를 배포한다. 두 GitHub Actions는 workflow_dispatch 방식이며 git push만으로 실행되지 않는다.
   APK versionCode는 배포 시점의 최신 release보다 크게 정한다.
6. 인증된 계정의 진행 저장 후 리더보드를 확인한다. 3라운드 전투 중이면 완료한 2라운드까지 반영되고,
   동일·낮은 기록은 기존 최고와 최초 확인 시각을 유지해야 한다. 저장 실패 시 클라이언트는 갱신 실패를 표시한다.

010은 기존 기록을 보존하고 정산 명령 또는 저장 revision 중 하나를 출처로 남긴다.
저장 출처 기록이 생긴 뒤에는 010 down이 거부된다. 기록을 삭제해 down을 강제하지 않는다.
API 롤백과 DB down은 별도로 판단하고, 가능한 경우 확장된 스키마를 유지한다.
세부 집계 기준과 검증은 [리더보드 설계](leaderboard_design.md)의 진행 중 기록 반영 확장을 참조한다.

## 기록 유지 규칙

- 배포가 필요한 코드 변경에는 필요한 migration·환경 설정·선행 조건을 이 문서에 함께 기록한다.
- 배포 후 검증된 커밋, DB 버전, workflow/release, 검증 결과를 갱신하고 미배포 항목을 정리한다.
- 실패·부분 완료는 구성 요소별로 기록한다. 과거 대화나 로컬 작업 기록만으로 완료를 판단하지 않는다.
- 비밀번호, 토큰, 암호화 키, DB 백업 내용은 이 문서나 커밋에 넣지 않는다.

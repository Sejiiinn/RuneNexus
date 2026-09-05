# 기존 카카오 인앱 브라우저 진행 이전

> 임시 테스트 이행 기능이다. **정식 배포 전에 API, 클라이언트 UX, 설정, DB 보관소를 모두 제거한다.**

## 목적

카카오 인앱 브라우저의 origin 저장소는 Chrome·Safari·설치 앱에서 직접 읽을 수 없다.
기존 테스터가 해당 브라우저에 남아 있는 guest 진행을 잃지 않도록, 서버를 경유하는
15분짜리 일회용 이전 링크를 제공한다.

이 기능은 카카오 로그인을 추가하거나 카카오 계정을 인증 수단으로 사용하는 기능이
아니다. 카카오 브라우저에 남아 있는 로컬 진행을 Rune Nexus 내부 account에 귀속시키는
한시적 데이터 이행 수단이다.

## 동작 흐름

1. 기존 진행이 남은 카카오 브라우저의 `계정 및 저장`에서
   `카카오 브라우저 진행 옮기기`를 연다.
2. 현재 canonical v2 guest 저장을 `POST /v1/legacy-save-transfers`로 전송한다.
3. 서버는 저장 구조와 재화 상한을 검사하고 256-bit 일회용 토큰을 발급한다.
4. 클라이언트는 토큰을 URL fragment에만 넣은 이전 링크를 표시한다. fragment는
   HTTP 요청, reverse proxy access log, Referrer 헤더로 전송되지 않는다.
5. 사용자는 링크를 Chrome 또는 Safari에서 연다. 저장된 Google 세션이 있으면 복원하고,
   없으면 로그인한다. 이후 현재 내부 account ID와 기존 진행 교체 경고를 확인한다.
   **링크를 열거나 세션이 복원됐다는 이유만으로 consume하지 않는다.** 가져오지 않기를
   선택하면 현재 페이지의 이전 token/fragment만 지우고 해당 account 진행을 연다.
6. 사용자가 가져오기를 승인하면 인증된 `POST /v1/legacy-save-transfers/consume`가 대상 account의 현재 저장과
   구매 다이아 보유 여부를 확인한다.
7. 빈 account이면 revision 1로 반영한다. 기존 저장이 있고 구매 다이아가 0이면
   현재 snapshot을 영수증에 백업하고 writer generation을 올린 뒤 다음 revision으로
   카카오 진행을 교체한다. 이후 guest를 복사하지 않는 `sessionRestore` bootstrap으로
   해당 account 진행을 연다. 기존 Outbox 우선 복구 규칙은 유지한다.
8. 소비가 끝난 임시 저장 원문은 같은 DB 트랜잭션에서 즉시 삭제한다. 토큰 해시,
   payload 해시, 대상 account와 결과 revision을 영수증으로 남긴다. 기존 저장을
   교체했다면 복구용 이전 snapshot도 같은 영수증에 보존한다.

## 안전 경계

- 기존 account 저장을 교체할 때는 모든 JSONB 영역과 revision을 먼저 백업한다.
- 기존 writer generation을 같은 트랜잭션에서 올려 다른 브라우저의 오래된 PUT을 차단한다.
- 대상 account의 구매 다이아가 0임을 확인할 수 없으면 교체하지 않는다.
- 같은 토큰의 같은 account 재시도는 원래 결과를 반환한다.
- 같은 토큰을 다른 account에서 사용하면 거부한다.
- 생성과 소비 endpoint는 IP별로 분리된 token bucket 제한을 적용한다.
- 만료된 미사용 원문은 소비 시 삭제하고, 다음 생성 요청에서도 일괄 정리한다.
- 구매 다이아(`paidDiamonds`)가 0이 아닌 저장은 거부한다.
- 무료 다이아는 1,000,000, 룬은 2,000,000,000, 모듈권은 1,000,000,
  모듈 아이템은 10,000개를 임시 이전 상한으로 둔다.
- 클라이언트 build flag와 서버 feature flag가 모두 켜져야 전체 흐름을 사용할 수 있다.

## 남는 리스크

기존 guest 저장은 서버가 발급한 서명이 없으므로 위변조되지 않았음을 증명할 수 없다.
동일 저장을 조금 수정해 여러 신규 account로 옮기는 복제도 완전히 차단할 수 없다.
기존 account 교체는 현재 테스터가 Google 로그인을 먼저 완료해 생긴 진행을 구제하기
위한 한시적 예외다. 일반 저장 동기화에서는 원격 snapshot 덮어쓰기를 허용하지 않는다.
따라서 이 기능은 현재 소규모 테스터의 데이터 구제에만 사용하며 정식 서비스의
일반적인 import 기능으로 유지하지 않는다.

운영 중에는 생성·소비 건수, 거부 사유, account별 소비 영수증을 확인한다. 비정상적인
대량 이전이 보이면 먼저 서버의 `LEGACY_LOCAL_TRANSFER_ENABLED=false`로 생성을 포함한
전체 endpoint를 닫는다.

## 정식 배포 전 제거 체크리스트

1. `LEGACY_LOCAL_TRANSFER_ENABLED=false`로 서버 endpoint를 먼저 닫는다.
2. 마지막으로 안내한 링크 TTL 15분이 지난 뒤 미소비 transfer가 없는지 확인한다.
3. GitHub Pages의 `RUNE_NEXUS_LEGACY_TRANSFER_ENABLED` build define과 계정 화면의
   이전 카드·다이얼로그·fragment 자동 로그인 흐름을 제거한다.
4. `/v1/legacy-save-transfers`, `/v1/legacy-save-transfers/consume`, 관련 rate limit,
   Go service와 설정을 제거한다.
5. 적용된 `004_legacy_save_transfers.sql`과 `005_legacy_transfer_existing_save_backup.sql`을
   수정하지 않는다. 새 down 목적 migration으로
   `legacy_save_transfers`, `legacy_save_transfer_receipts`를 제거한다.
6. 교체 백업이 필요한 account가 없는지 확인하고 필요한 snapshot은 복구·내보내기를
   끝낸다. 영수증에는 카카오 원문은 없지만 교체 전 account snapshot이 남아 있다.
7. 전체 테스트와 공개 환경 Google 로그인·일반 account bootstrap을 다시 검증한다.

정식 배포 차단 조건은 이 문서의 제거 체크리스트가 완료되지 않은 상태다.

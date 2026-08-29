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
5. 사용자는 링크를 Chrome 또는 Safari에서 열고 Google 로그인을 완료한다.
6. 인증된 `POST /v1/legacy-save-transfers/consume`가 대상 account에 저장 header가
   없는지 확인한다.
7. 빈 account이면 저장 revision 1로 전체 진행을 원자적으로 반영하고 토큰을
   소비한다. 이후 일반 account bootstrap이 해당 원격 저장을 연다.
8. 소비가 끝난 임시 저장 원문은 같은 DB 트랜잭션에서 즉시 삭제한다. 토큰 해시,
   payload 해시, 대상 account, 결과 revision만 영수증으로 남긴다.

## 안전 경계

- 대상 account에 `save_headers`가 하나라도 있으면 병합하거나 덮어쓰지 않는다.
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
5. 적용된 `004_legacy_save_transfers.sql`을 수정하지 않는다. 새 down 목적 migration으로
   `legacy_save_transfers`, `legacy_save_transfer_receipts`를 제거한다.
6. 영수증 감사 자료가 필요하면 payload 해시·대상 account·소비 시각만 먼저 내보낸다.
   원문 저장 데이터는 영수증 테이블에 남아 있지 않다.
7. 전체 테스트와 공개 환경 Google 로그인·일반 account bootstrap을 다시 검증한다.

정식 배포 차단 조건은 이 문서의 제거 체크리스트가 완료되지 않은 상태다.

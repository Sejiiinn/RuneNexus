# 배포 상태와 세션 간 인계

배포 요청은 이 문서와 [파이프라인 지도](deployment_pipeline.md)에서 시작한다.
서버·DB·운영 설정 또는 그 계약이 바뀌는 경우 [API 운영 절차](self_hosted_api_deployment.md)를 함께 확인한다.
이 문서는 마지막 검증 이력이며 실시간 운영 상태가 아니다. 배포 대상의 실제 공개 버전·커밋과
서버 실행 이미지·DB 버전을 확인한다.


## 현재 미배포 변경

- 포탑 내부 ID를 표시명에 맞춰 `arrow`→`machinegun`(기관총), `magic`→`flame`(화염)으로 바꿨다. 클라이언트·서버 호환 세대 17, DB 마이그레이션 `023_turret_identity_rename.sql`(저장 JSON·모듈 행·bootstrap 백업의 포탑 ID 재작성, 모든 계정 writer 하한 17)이 함께 나간다.
  - 새 앱은 예전 ID 저장을 읽을 때 새 ID로 바꾸고, 서버는 모듈 뽑기 요청의 예전 ID를 받아 준다. 이전 앱(16 이하)은 새 ID를 버리므로 저장 쓰기가 막힌다.
  - 순서: 서버·DB23을 먼저 반영하고 바로 새 APK를 **필수 업데이트**로 공개한다. 운영 `MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION`도 17로 올려 신규 계정의 이전 앱 쓰기를 막는다.
- 대포 기본 피해 25→34, 폭발 반경 42→52, 화염 기본 피해 16→22 상향. 앱 콘텐츠만 바뀌며 서버·DB 변경은 없다.
- 포탑 정보 창 초당 피해·전투력에 저격 조준 시간을 반영했다(표시만 변경).
- 3-10 맵을 「나란한 두 차선」으로 개조했다(두 입구가 한 칸 간격 차선으로 내려와 코어 앞에서 합류, 경로 ID `outer`/`inner`). 앱 콘텐츠만 바뀐다. 옛 3-10 맵으로 진행 중이던 저장은 맵 서명이 달라 불러오지 못하지만, 그런 진행은 없다(사용자 확인).
- 런 기록 수집([설계](run_log_design.md)): 서버 `POST /v1/telemetry/run-logs`와 DB 마이그레이션 `024_run_logs.sql`(기록 테이블, 탈퇴 요청 시 삭제 트리거), 앱의 정산 후 1회 전송. 호환 세대·저장 형식 변경은 없다.
  - 앱 공개 전에 개인정보처리방침(수집 항목·목적·180일 보관)을 게시한다. 서버·DB24를 앱보다 먼저 반영한다(이전 서버는 404로 버림).
- 카카오 인앱 브라우저 진행 임시 이전 제거: 서버 `/v1/legacy-save-transfers` API·요청 제한·`LEGACY_*` 설정을 지우고, DB 마이그레이션 `025_drop_legacy_save_transfers.sql`로 `legacy_save_transfers`·`legacy_save_transfer_receipts`를 삭제한다(남은 이전 대상 없음, 사용자 확인). 앱 변경은 없다.
  - 영수증의 교체 전 계정 스냅숏도 함께 지워지며 down으로 되살릴 수 없다. 배포 동결 백업에는 남는다. 운영 `.env`의 `LEGACY_*` 값은 무시되므로 지워도 되고 남겨도 된다.

마지막 공개 앱은 6061 / 0.2.32(`a36ad158`, 필수 업데이트·최소 지원 코드 6061), 운영 서버는 `424dd591`·DB22다.

실제 Google 계정·운영 서버에 연결한 앱 젬 덱 플레이와 Android 본게임·실기기 지속 성능의 미검증 범위는 [체크리스트](implementation_checklist.md)에 유지한다.

## 2026-11-03 Android 0.2.32 / code 6061 — 공개 완료

- APK 대상 `a36ad15857ce20b2315b4dab940aebe4fe8fc2b8`, [build-only CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/41544138017), [공개 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/41546635296), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6061), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6061/rune-nexus.apk). 2026-11-02 23:36:12 UTC(2026-11-03 08:36:12 KST)에 공개·최신 지정했다. 클라이언트 호환 세대 16을 쓰므로 서버를 먼저 반영했고, 사용자 결정으로 **필수 업데이트**(최소 지원 코드 6061)다.
- 포함: 하드 난이도(입장·적 승급·룬 ×1.5·하드 기록)와 하드 보상(첫 클리어 코어 1P·모듈권 2장, 서버 추첨 반복 모듈권·전리품 모듈), 매직·희귀 적 다이아 운반 ×2/×4, 전체 포탑 모듈 일괄 분해, 스테이지 도전과제(판정·업적 팝업 받기·카드 조건 줄·코어 ⓘ), 스크롤 없는 결과창, 컬렉션 훈장과 업적 능력치, 누적 업적 5단계와 누적 훈장, 업적 팝업 받기 강조, 전투 도전 조건 시작 안내·실패 알림. 세부는 [난이도·도전과제 설계](stage_difficulty_design.md#구현-계약).
- 빌드 재시도: 첫 build-only는 전투 안내가 배치 전에 지워질 때 지연 호출이 해제된 인스턴스를 타입 지정 인자로 받아 회귀 3건이 오류로 실패했다(`546583b6`에서 수정). 두 번째는 계정 서비스 격리 검사가 하드 규칙 파일 `content/stage_difficulty.gd`를 복사하지 않아 실패했다(`c71fcfd0`). 세 번째는 결과창 배치 검사가 CI 병렬 부하에서 20초 제한을 넘었다(`a36ad158`에서 60초 직렬 차선으로 이동). 네 번째가 통과했다.
- 검사: build-only CI가 배포 검사 공용 액션(계약·네이티브 회귀·계정·앱 서비스·세션·수명주기)·서명 빌드·팩 감사·패치 디코더·차등 업데이트 준비를 통과했다. 로컬에서는 변경 책임별 회귀(도전과제·결과창·보상 입장·코어 화면 등)와 실제 앱 화면 캡처를 확인했다. 공개 실행은 검수한 build-only 후보를 다시 빌드하지 않고 승격했다(`same_as_build_only_candidate=true`).
- APK **361,567,717 bytes**, SHA-256 `feeb69e7…`(전체 값은 [update.json](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6061/update.json)). 6060 대비 **+889,024 bytes(+0.25%)**이며 PCK가 208,750,388 bytes·1473항목(+889,024 bytes, +36항목)으로 늘었다. 훈장 그림 11종·업적 화면 에셋과 새 스크립트가 늘어난 몫이다. 기존 22개 중복군 2,707,494 bytes는 같고 신규 중복은 없다. **6060/6059/6058→6061 패치는 6,278,632 / 8,784,091 / 10,924,627 bytes**다.
- 공개 tag 대상 커밋·성공 CI, latest/버전별 `update.json` 일치, 익명 공개 주소에서 받은 자산의 크기·SHA-256과 GitHub digest 일치를 확인했다(`public-verification.json`).
- 전투 도전 조건 안내는 Codex 독립 검증을 받아 결함 1건(보상·결과 화면에서 안내가 남음)을 고쳤고, 나머지 기능은 독립 검증을 하지 않았다. Android 전용 변경(저장 마이그레이션·업데이트 경로·네이티브 연동)이 없어 AVD·기기 확인은 하지 않았다. **필수 업데이트 안내의 실기기 동작, 앱 내 패치 업데이트, 실제 Google 로그인·운영 서버 연결에서의 하드 보상·도전과제·업적 받기, Android 실기기 표시는 미검증**이다.

## 2026-11-03 서버 — `424dd591` 반영 완료

- 하드 정산·하드 보상 추첨, 도전과제 받기 `POST /v1/economy/challenges/claim`, 누적 업적 받기 `POST /v1/economy/achievements/claim`, 클라이언트 호환 세대 16을 반영했다. 정확한 `424dd591f479b0feb8dc5625d83b349f97800436` 소스로 `rune-nexus-api:424dd591`(image `sha256:4d8e7618e69fb8e8f21882eccf82589af618a33ecf6092144f147119c7a48a7a`)을 빌드했다. DB 마이그레이션은 없다(보상 명령 종류는 기존 `reward_claim`).
- 검사: `prepare`의 Go test·vet·격리 DB 통합 검사·운영 DB 사본 마이그레이션 사전 검사(스키마 22→22, 33개 테이블)·격리 API 9조건, `rehearse-deploy`의 정지·동결 백업 복원·HTTP 9조건을 통과했다.
- 2026-11-03 07:48:03~07:48:15 KST(약 12초)에 API를 정지하고 동결 백업을 격리 복원해 확인한 뒤 반영했다. 스키마는 22 그대로다. 새 API는 loopback·공개 HTTPS 18조건을 통과했다. 환경·mount·port·network와 Caddy/DuckDNS 컨테이너를 보존했다. 운영 계정 로그인·명령은 하지 않았다.
- 동결 백업(`production-frozen-schema22.dump`, SHA-256 `e95b168efc9f148c055c2a6ffc4740a5cbb65ee7881156767d53932814914d7d`)과 반영 기록은 Git 밖 `~/Library/Application Support/RuneNexus/operations/server-424dd591-20261102T224457Z/`에 있다. 이전 작업 폴더 `server-f85a9037-…`는 외장 보관소로 옮겼다.
- 서버 변경은 독립 검증하지 않았다. **실제 Google 계정으로 하드 보상·도전과제·누적 업적을 받는 운영 E2E는 미검증**이다.

## 과거 배포 기록

이전 Godot 앱·서버 배포는 [배포 이력](archive/deployment_history_godot.md), 2026-09-12~20의 Flutter/Web 배포와 당시 복구 명령은 [전환 전 기록](archive/deployment_before_godot_20260924.md)에 보존한다. 현행 운영 절차나 다음 작업으로 사용하지 않는다.

## 기록 유지 규칙

- 이 문서에는 미배포 변경과 마지막 앱·서버 배포 기록만 둔다. 새 배포를 기록하면 같은 구성 요소의 직전 기록을 [배포 이력](archive/deployment_history_godot.md) 맨 위로 옮긴다.
- 배포가 필요한 코드 변경에는 필요한 migration·환경 설정·선행 조건을 함께 기록한다.
- 배포 후 구성 요소별 커밋, workflow/release, 검증 결과와 한계를 갱신하고 미배포 항목을 정리한다.
- 실패·부분 완료는 구성 요소별로 기록한다. 과거 대화나 로컬 작업 기록만으로 완료를 판단하지 않는다.
- 비밀번호, 토큰, 암호화 키, DB 백업 내용은 이 문서나 커밋에 넣지 않는다.
- 운영 작업 폴더(`~/Library/Application Support/RuneNexus/operations/`)에는 실행 중인 API의 compose가 있는 폴더와 다음 배포 준비 폴더만 둔다. 나머지는 외장 `/Volumes/KIOXIA_MAC/RuneNexus/operations-archive/`로 옮기며, 기록에 적힌 `operations/<폴더>` 경로는 그 아래에서 찾는다.

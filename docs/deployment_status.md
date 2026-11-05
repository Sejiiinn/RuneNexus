# 배포 상태와 세션 간 인계

배포 요청은 이 문서와 [파이프라인 지도](deployment_pipeline.md)에서 시작한다.
서버·DB·운영 설정 또는 그 계약이 바뀌는 경우 [API 운영 절차](self_hosted_api_deployment.md)를 함께 확인한다.
이 문서는 마지막 검증 이력이며 실시간 운영 상태가 아니다. 배포 대상의 실제 공개 버전·커밋과
서버 실행 이미지·DB 버전을 확인한다.


## 현재 미배포 변경

- **개인정보처리방침 게시가 남았다.** 사용자 결정으로 앱을 먼저 공개했으므로 6062부터 게시 전에도 런 기록이 고지 없이 수집된다. 수집 항목·목적·180일 보관을 적어 게시하며 작성·게시는 사용자 담당이다.

마지막 공개 앱은 6062 / 0.2.33(`faf2aa99`, 필수 업데이트·최소 지원 코드 6062), 운영 서버는 `f5b9cfc4`·DB25다.

실제 Google 계정·운영 서버에 연결한 앱 젬 덱 플레이와 Android 본게임·실기기 지속 성능의 미검증 범위는 [체크리스트](implementation_checklist.md)에 유지한다.

## 2026-11-05 Android 0.2.33 / code 6062 — 공개 완료

- APK 대상 `faf2aa99c6669e5a4d3d33fbcc5bca595cc9f979`, [build-only CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/41974248046), [공개 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/41976123006), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6062), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6062/rune-nexus.apk). 2026-11-05 05:47:09 UTC(14:47:09 KST)에 공개·최신 지정했다. 포탑 ID 변경으로 이전 앱은 저장이 막히므로 **필수 업데이트**(최소 지원 코드 6062)다.
- 포함: 포탑 내부 ID 변경(`arrow`→`machinegun`, `magic`→`flame`, 호환 세대 17), 대포 기본 피해 34·폭발 반경 52, 화염 기본 피해 22, 저격 초당 피해·전투력의 조준 시간 반영, 3-10 「나란한 두 차선」 맵, 정산 후 [런 기록](run_log_design.md) 1회 전송, 게스트 bootstrap 분기와 Android v1 임시 저장 가져오기 제거.
- 순서: 이전 앱이 서버 반영 순간부터 저장이 막히고 재빌드 위험이 있어 build-only 검수와 AVD 확인을 마친 뒤 서버를 반영하고 바로 공개했다. 서버 반영 완료부터 공개까지 약 1분이다.
- 빌드 재시도: 첫 build-only는 런 기록이 읽는 `max_hp`가 `verify_event_batch.gd`의 가짜 방어 상태에 없어 실패했다. 실제 방어 상태에는 있어 앱 결함이 아니며, 테스트만 고쳤다(`faf2aa99`). 이 회귀는 `ec37ff2b`부터 `main` 검사 CI에서 실패하고 있었다. 재시도 전 CI가 건너뛴 계정·앱 서비스 검사와 세션·수명주기 7건을 로컬에서 통과시켰고, 두 번째 build-only가 통과했다.
- 검사: build-only CI가 배포 검사 공용 액션·서명 빌드·팩 감사·패치 디코더·차등 업데이트 준비를 통과했다. 공개 실행은 검수한 후보를 다시 빌드하지 않고 승격했다(`same_as_build_only_candidate=true`). 같은 커밋의 [`main` 검사 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/41974244085)는 `verify_battle_result_entrance.gd`의 스프링 움직임 판정 1건으로 실패했다. build-only에서는 같은 사례가 통과했으므로 CI 부하 민감으로 보이지만 원인을 확정하지는 않았다.
- APK **361,572,981 bytes**, SHA-256 `3ae8e5f8…`(전체 값은 [update.json](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6062/update.json)). 6061 대비 **+5,264 bytes(+0.001%)**이며 PCK가 208,755,652 bytes·1477항목(+5,264 bytes, +4항목)이다. 기존 중복 2,707,494 bytes는 같다. **6061/6060/6059→6062 패치는 8,593,341 / 10,238,271 / 12,742,676 bytes**로, 포탑 ID 변경이 여러 스크립트와 콘텐츠를 건드려 직전 패치보다 크다.
- 공개 tag 대상 커밋·성공 CI, latest/버전별 `update.json` 일치, 익명 공개 주소에서 받은 자산의 크기·SHA-256과 GitHub digest 일치를 확인했다(`public-verification.json`).
- API37 arm64 읽기 전용 AVD에서 공개 6061 설치·실행 → build-only 6062 업데이트 설치 후 최초 설치 시각과 앱 데이터 44개 파일 해시가 같았고, 6062 실행 후 치명 오류·스크립트 오류 없이 로그인 안내를 표시했다. 로그인 전이라 포탑 ID가 든 저장은 없었으며, ID 변환은 Godot 회귀에서만 확인했다.
- 독립 검증은 수행하지 않았다. **실제 Google 로그인·운영 계정의 포탑 ID 변환 후 플레이와 런 기록 전송, 필수 업데이트 안내의 실기기 동작, 앱 내 패치 업데이트, Android 실기기 표시는 미검증**이다.

## 2026-11-05 서버 — `f5b9cfc4` 반영 완료

- 포탑 ID 재작성(DB23), 런 기록 `POST /v1/telemetry/run-logs`(DB24), 카카오 임시 이전 제거(DB25), 웹·구형 인증 경로와 CORS 제거를 반영했다. 정확한 `f5b9cfc4924e3601547685afc7f6538301d4494c` 소스로 `rune-nexus-api:f5b9cfc4`를 빌드했다. 앱 대상 `faf2aa99`는 테스트만 다르므로 서버를 다시 준비하지 않았다.
- 검사: `prepare`의 Go test·vet·격리 DB 통합 검사·운영 DB 사본 마이그레이션 사전 검사(스키마 22→25, 33개 테이블)·격리 API 9조건, `rehearse-deploy`의 정지·동결 백업 복원·HTTP 9조건을 통과했다. 행 대조 허용 테이블은 `save_progression`·`save_turret_modules`·`save_active_runs`·`economy_bootstrap_backups`·`legacy_save_transfers`·`legacy_save_transfer_receipts`·`player_modules`·`save_writer_states` 8개다. 첫 리허설은 `rehearse-deploy`가 `prepare`의 허용 목록을 물려받지 않아 인자 누락으로 멈췄고, 인자를 넣어 재실행했다.
- 2026-11-05 14:46:04~14:46:17 KST(약 13초)에 API를 정지하고 동결 백업을 격리 복원해 확인한 뒤 반영했다. 스키마는 22→25다. 새 API는 loopback·공개 HTTPS 18조건을 통과했다. 환경·mount·port·network와 Caddy/DuckDNS 컨테이너를 보존했다. 운영 계정 로그인·명령은 하지 않았다.
- 동결 백업(`production-frozen-schema22.dump`, SHA-256 `157422b8f6b39b345e34dbb2b31e2e9b0d2bace7cc8e9351ffdda829ce01903b`)과 반영 기록은 Git 밖 `~/Library/Application Support/RuneNexus/operations/server-f5b9cfc4-20261105T050955Z/`에 있다. DB25가 지운 임시 이전 영수증은 이 백업에만 남는다.
- 앱 공개 뒤 2026-11-05 15:23:31~15:23:38 KST(약 7초)에 실행 중인 compose의 `MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION`을 4→17로 올리고 API를 다시 만들었다. `deploy`가 환경값 보존을 검사하므로 별도 단계로 수행했다. 바뀐 환경값은 이 하나이며 이미지·mount·port·network는 같고, 공개 HTTPS live/ready 200을 확인했다. 변경 전 compose는 작업 폴더의 `api-release-min4.compose.private.json`이다. 저장소 밖 `.env.production`의 값은 실행에 쓰이지 않아 그대로 두었다.
- 서버 변경은 독립 검증하지 않았다. **실제 Google 계정으로 런 기록이 쌓이는지와 이전된 포탑 ID 계정의 운영 E2E는 미검증**이다.

## 과거 배포 기록

이전 Godot 앱·서버 배포는 [배포 이력](archive/deployment_history_godot.md), 2026-09-12~20의 Flutter/Web 배포와 당시 복구 명령은 [전환 전 기록](archive/deployment_before_godot_20260924.md)에 보존한다. 현행 운영 절차나 다음 작업으로 사용하지 않는다.

## 기록 유지 규칙

- 이 문서에는 미배포 변경과 마지막 앱·서버 배포 기록만 둔다. 새 배포를 기록하면 같은 구성 요소의 직전 기록을 [배포 이력](archive/deployment_history_godot.md) 맨 위로 옮긴다.
- 배포가 필요한 코드 변경에는 필요한 migration·환경 설정·선행 조건을 함께 기록한다.
- 배포 후 구성 요소별 커밋, workflow/release, 검증 결과와 한계를 갱신하고 미배포 항목을 정리한다.
- 실패·부분 완료는 구성 요소별로 기록한다. 과거 대화나 로컬 작업 기록만으로 완료를 판단하지 않는다.
- 비밀번호, 토큰, 암호화 키, DB 백업 내용은 이 문서나 커밋에 넣지 않는다.
- 운영 작업 폴더(`~/Library/Application Support/RuneNexus/operations/`)에는 실행 중인 API의 compose가 있는 폴더와 다음 배포 준비 폴더만 둔다. 나머지는 외장 `/Volumes/KIOXIA_MAC/RuneNexus/operations-archive/`로 옮기며, 기록에 적힌 `operations/<폴더>` 경로는 그 아래에서 찾는다.

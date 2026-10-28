# 배포 상태와 세션 간 인계

배포 요청은 이 문서와 [파이프라인 지도](deployment_pipeline.md)에서 시작한다.
서버·DB·운영 설정 또는 그 계약이 바뀌는 경우 [API 운영 절차](self_hosted_api_deployment.md)를 함께 확인한다.
이 문서는 마지막 검증 이력이며 실시간 운영 상태가 아니다. 배포 대상의 실제 공개 버전·커밋과
서버 실행 이미지·DB 버전을 확인한다.


## 현재 미배포 변경

없음. 마지막 공개 앱은 6059 / 0.2.30(`33d65199`, 선택 업데이트·최소 지원 코드6058), 운영 서버는 `f85a9037`·DB22다.

실제 Google 계정·운영 서버에 연결한 앱 젬 덱 플레이와 Android 본게임·실기기 지속 성능의 미검증 범위는 [체크리스트](implementation_checklist.md)에 유지한다.

## 2026-10-28 Android 0.2.30 / code 6059 — 공개 완료

- APK 대상 `33d6519983af37af0efab437903bf081a515e511`, [build-only CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40650174316), [공개 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40652276663), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6059), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6059/rune-nexus.apk). 2026-10-28 07:47:27 UTC(16:47:27 KST)에 공개·최신 지정했다. 저장·API 호환이 유지되어 **선택 업데이트**이며 최소 지원 코드는 6058 그대로다. 클라이언트 세대·저장·API·DB 변경이 없어 서버는 반영하지 않았다(운영 `f85a9037` 이후 `server/`·콘텐츠 원본·fixture 변경 없음).
- 포함: 영구 강화 탭을 청동 단련대 목록과 해금·잠김·완료 상태 탭으로 재설계하고 레벨업 성공 단련 연출 추가, 강화 탭 배경의 용광로 빛·불티, 연구 탭을 청록 설계도 카드·연구 전용 9-slice 에셋·작은 크기용 아이콘으로 재설계하고 배경 청록 조명·훑기 빛·입자 추가, 슬롯이 차 있어도 룬이 충분한 연구 카드는 어둡게 하지 않음([결정](design_decisions/lobby.md)), 스테이지 홈 설정을 하단 단축 줄 맨 왼쪽으로 이동, 선택 소켓 숫자 중심 보정과 획득한 해금 배지 체크 표시 유지. 쓰지 않는 옛 연구 슬롯 에셋 2개를 제거했다.
- 검사: 로컬에서 관련 Godot 회귀(강화·연구 화면, 연구 가능 상태·슬롯·중단·모달 갱신·확인창, 로비)를 통과했다. build-only CI가 배포 검사 공용 액션(계약·회귀·준비 프로젝트)·서명 빌드·팩 감사·패치 디코더·차등 업데이트 준비를 통과했고, 공개 실행은 검수한 build-only 후보를 다시 빌드하지 않고 승격했다(`same_as_build_only_candidate=true`).
- APK **359,493,129 bytes**, SHA-256 `fabce59d…`(전체 값은 [update.json](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6059/update.json)). 6058 대비 **+475,608 bytes**이며 PCK가 206,675,800 bytes·1439항목(+475,604 bytes, +50항목)으로 늘었다. 강화 13개·연구 14개 새 UI PNG를 더하고 옛 연구 슬롯 2개를 뺀 순증 25개 에셋의 가져오기 항목이다. 기존22개 중복군2,707,494 bytes는 같고 신규 중복은 없다. **6058/6057/6056→6059 패치는 6,591,008 / 6,944,820 / 7,389,661 bytes**다.
- 공개 tag 대상 커밋·성공 CI, latest/버전별 `update.json` 일치, 익명 공개 주소에서 받은 자산4개의 크기·SHA-256과 GitHub digest 일치를 확인했다(`apk_release.py publish`의 `public-verification.json`).
- Codex 독립 검증(gpt-6-astra, high): 강화 탭 재설계(조건 1·2·3·5·6·9 PASS, 미미 2건은 생략 제안, 1건은 기존부터 실패하던 `verify_menu_shell_parity.gd`)와 연구 탭 재설계(조건 10개 중 8개 PASS, 에셋 면 알파 252~254의 미미 1건은 사용자 합의로 생략, 훑기 빛 움직임은 미확인)를 각각 받았다. 강화 탭의 세부 디테일·단련 연출·배경은 그 검증 뒤에 바뀌어 독립 재검증하지 않았다.
- Android 전용 변경이 없어 AVD·기기 확인은 하지 않았다. **Android 실기기의 새 강화·연구 화면 표시와 터치, 모바일 GPU에서의 배경 셰이더·입자 부하, 앱 내 패치 업데이트, 실제 Google 로그인·운영 서버 연결 강화·연구 명령은 미검증**이다.

## 2026-10-27 서버 — `f85a9037` 반영 완료

- Go 툴체인·서버 의존성 보안 패치다. 정확한 `f85a90373e3a3669152f28dfadcbcdb906474c0f` 소스로 `rune-nexus-api:f85a9037`(image `sha256:f05182b060a4b14a1eb54140ee4aa5efdfaa22caa0b5f13fdc0daed44410d3b9`)을 빌드했다. 앱·저장·API 계약·DB 스키마 변경은 없다(`53fb799d` 이후 서버 쪽 다른 변경은 테스트 주석·fixture 설명의 검사 경로뿐).
- 포함: Go 1.26.5→1.26.10(`go.mod` toolchain·API/마이그레이션 Dockerfile·Makefile·compose 빌드 인자), `golang.org/x/net` 0.61.0·`x/text` 0.43.0·`x/crypto` 0.58.0·`google.golang.org/grpc` 1.84.0, `google.golang.org/api` 0.309.0, `pgx/v5` 5.11.0. 패치 전 `govulncheck`에서 서버 코드가 호출하는 경로의 취약점(표준 라이브러리 HTTP/2·`net/http`·TLS 인증서, x/net HTTP/2, grpc, x/text)이 15건 있었고 패치 후 0건이다. 남은 미호출 1건(GO-2026-5932, 유지보수 종료된 `x/crypto/openpgp`)은 수정 버전이 없고 서버가 그 패키지를 포함하지 않는다. `cloud.google.com/go/auth`는 `google.golang.org/api` 0.309.0이 요구하는 의사 버전 `v0.24.1-0.20261001053825-dbc26066f70a`다.
- 검사: `make -C server test`·`vet`(golang:1.26.10-alpine), 격리 DB 통합 검사79건(skip0), `prepare`의 Go test/vet·통합·운영 DB 사본 마이그레이션 사전 검사(스키마22→22, 33개 테이블)·격리 API9조건, `rehearse-deploy`의 정지·동결 백업 복원·HTTP9조건을 통과했다.
- 2026-10-27 17:18:51~17:19:02 KST(약 11초)에 API를 정지하고 동결 백업을 격리 복원해 확인한 뒤 반영했다. 스키마는 22 그대로다. 새 API는 healthy이며 loopback·공개 HTTPS 각 9조건(상태 200·보호 경로401)을 통과했다. 환경·mount·port·network·실행 설정과 PostgreSQL/Caddy/DuckDNS 컨테이너를 보존했다. 운영 계정 로그인·명령은 하지 않았다.
- 동결 백업(`production-frozen-schema22.dump`, SHA-256 `2b55ec83b70a9a55daf8d550296386c60034ae575f44b9f99989cebc1b383530`)과 반영 기록은 Git 밖 `~/Library/Application Support/RuneNexus/operations/server-f85a9037-20261027T081244Z/`에 있다. 이전 작업 폴더 `server-53fb799d-…`·`apk-6054-server-…`는 외장 보관소로 옮겼다.
- Codex 독립 검증(변경 커밋 대상): 버전 일관성·모듈 정합성(`go mod verify`·`tidy` 무변경)·호환성(build/test/vet, Google ID token 검증 코드 동일, pgxpool 사용 API 유지)·auth 의사 버전 근거·문서 정확성 PASS, 결함 0건. 호출 경로 취약점 0건과 Docker 빌드는 검증 샌드박스의 네트워크·Docker 차단으로 **미확인**이며, 이 두 항목은 Claude의 `govulncheck`와 `prepare` 빌드로만 확인했다. **실제 Google 계정 로그인·앱 연결 E2E는 미검증**이다.

## 과거 배포 기록

이전 Godot 앱·서버 배포는 [배포 이력](archive/deployment_history_godot.md), 2026-09-12~20의 Flutter/Web 배포와 당시 복구 명령은 [전환 전 기록](archive/deployment_before_godot_20260924.md)에 보존한다. 현행 운영 절차나 다음 작업으로 사용하지 않는다.

## 기록 유지 규칙

- 이 문서에는 미배포 변경과 마지막 앱·서버 배포 기록만 둔다. 새 배포를 기록하면 같은 구성 요소의 직전 기록을 [배포 이력](archive/deployment_history_godot.md) 맨 위로 옮긴다.
- 배포가 필요한 코드 변경에는 필요한 migration·환경 설정·선행 조건을 함께 기록한다.
- 배포 후 구성 요소별 커밋, workflow/release, 검증 결과와 한계를 갱신하고 미배포 항목을 정리한다.
- 실패·부분 완료는 구성 요소별로 기록한다. 과거 대화나 로컬 작업 기록만으로 완료를 판단하지 않는다.
- 비밀번호, 토큰, 암호화 키, DB 백업 내용은 이 문서나 커밋에 넣지 않는다.
- 운영 작업 폴더(`~/Library/Application Support/RuneNexus/operations/`)에는 실행 중인 API의 compose가 있는 폴더와 다음 배포 준비 폴더만 둔다. 나머지는 외장 `/Volumes/KIOXIA_MAC/RuneNexus/operations-archive/`로 옮기며, 기록에 적힌 `operations/<폴더>` 경로는 그 아래에서 찾는다.

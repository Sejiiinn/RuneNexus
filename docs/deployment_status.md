# 배포 상태와 세션 간 인계

배포 요청은 이 문서와 [파이프라인 지도](deployment_pipeline.md)에서 시작한다.
서버·DB·운영 설정 또는 그 계약이 바뀌는 경우 [API 운영 절차](self_hosted_api_deployment.md)를 함께 확인한다.
이 문서는 마지막 검증 이력이며 실시간 운영 상태가 아니다. 배포 대상의 실제 공개 버전·커밋과
서버 실행 이미지·DB 버전을 확인한다.


## 현재 미배포 변경

없음. 마지막 공개 앱은 6057 / 0.2.28(`cfc87f07`, 선택 업데이트·최소 지원 코드6055), 운영 서버는 `53fb799d`·DB22다.

실제 Google 계정·운영 서버에 연결한 앱 젬 덱 플레이와 Android 본게임·실기기 지속 성능의 미검증 범위는 [체크리스트](implementation_checklist.md)에 유지한다.

## 2026-10-27 Android 0.2.28 / code 6057 — 공개 완료

- APK 대상 `cfc87f0725cefe0f6006b1dcb1c3af22531602fd`, [build-only CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40452279229), [공개 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40454068459), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6057), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6057/rune-nexus.apk). 2026-10-27 05:26:22 UTC(14:26:22 KST)에 공개·최신 지정했다. **선택 업데이트·최소 지원 코드6055**이며 클라이언트 세대14·저장·API·DB 변경이 없어 서버는 반영하지 않았다(`53fb799d` 이후 서버 쪽 변경은 테스트 주석·검사 경로 문서뿐).
- 포함: 적 종류별 첫 처치 때 사망 연출 셰이더 준비 끊김(데스크톱 70~80ms)을 로딩 예열로 이동, 첫 탱크의 체력바 기준점 재계산(7~8ms) 제거, 웨이브 끝 하단 HUD 패널 재구성 비용 제거, 젬 보상 화면 첫 표시의 텍스처 로드 지연 제거, 전투 스텝·명중의 임시 할당 축소. 동작 변화 없는 전투 런타임·앱 수명주기·전장 장면·전장 환경·확장 코어 트리 계층 분할과 검사 스크립트의 `godot/tests/` 이동(내보내기 제외)도 포함한다.
- 두 CI 모두 배포 검사 공용 액션(계약·회귀·준비 프로젝트)·서명 빌드·팩 감사·Android 패치 디코더·검증된 차등 업데이트 준비를 통과했다. 공개 실행은 build-only와 별도로 다시 빌드했으므로 아래 크기는 공개본 기준이다.
- APK **362,033,713 bytes**, SHA-256 `413caeb5…`(전체 값은 [update.json](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6057/update.json)). 6056 대비 **+32,396 bytes**이며 전부 PCK 증가다(209,216,388 bytes·1441항목, +38항목). 증가 항목은 계층 분할로 생긴 새 스크립트 19개의 `.gdc`·`.remap`이고 `tests/`·`verify_*` 항목은 없다. 기존22개 중복군2,707,494 bytes는 같고 신규 중복은 없다. **6056/6055/6054→6057 패치는 4,618,321 / 7,641,275 / 7,774,906 bytes**다.
- 공개 tag 대상 커밋·성공 CI, 내장 `clientBuild=android:cfc87f07…`, latest/버전별 `update.json` 일치, 익명 공개 주소에서 받은 자산4개의 크기·SHA-256과 GitHub digest 일치를 확인했다(`apk_release.py publish`의 `public-verification.json`).
- Android에서만 드러나는 변경(저장 마이그레이션·업데이트/패치 경로·네이티브 연동·터치·수명주기)이 없어 AVD 업데이트 설치 확인은 하지 않았다. 끊김 개선 수치는 데스크톱 실제 앱 측정이며 **Android 실기기·모바일 GPU에서의 개선, 앱 내 패치 다운로드 업데이트, 실제 Google 로그인·계정 동기화·운영 서버 연결 플레이는 미검증**이다. 포함 변경 중 사망 연출 예열·탱크 기준점·HUD 비용·계층 분할 일부는 Codex 독립 검증을 거쳤고, 배포 절차 자체의 독립 검증은 요청이 없어 수행하지 않았다.

## 2026-10-26 서버·DB — `53fb799d` 반영 완료

- [반영 스크립트](../scripts/server_release.py)로 처음 반영했다. 정확한 `53fb799d19b77bb77749704096bbf6011bff8fe8` 소스로 `rune-nexus-api:53fb799d`(image `sha256:8cb973e8714f5566de51debd3c2007d47ea4962e1ee0cc1ae862c85e474eb0a1`, revision label 일치)를 빌드했다. `prepare`에서 Go test/vet·전체 pgx 통합, 운영 DB 사본의 migration021·022(스키마20→22) 뒤 기존 33개 테이블의 기존 열 값 보존, 새 이미지 격리 기동의 공개 계약9조건을 통과했다. `rehearse-deploy`로 운영 DB 사본·현 API 설정의 격리 스택에서 정지·동결 백업 복원·마이그레이션·기동·HTTP9조건까지 통과했다.
- 2026-10-26 13:23:39~13:23:52 KST에 API를 정지(DB 클라이언트0 확인)하고 동결 백업을 격리 복원해 행 지문이 같음을 확인한 뒤 운영 DB를 **스키마20→22**로 올렸다. 기존 열 값은 모두 보존됐다. 새 API는 healthy이며 loopback·공개 HTTPS의 상태 200·보호 경로401 18조건을 통과했다. 환경·mount·port·network·실행 설정과 PostgreSQL/Caddy/DuckDNS 컨테이너를 보존했다. 운영 계정 로그인·명령은 하지 않았다.
- 반영 내용: 젬·포탑 식별자 형식 검사(021), 계정별 클라이언트 세대 하한(022), 세대 14(지원 코어) 수용, 콘텐츠 레지스트리 기반 서버 검증.
- 세대 하한: DB migration022가 `save_writer_states.client_generation_floor`를 추가하고, 서버는 writer를 획득한 가장 높은 세대를 기록해 그보다 낮은 세대의 writer 획득·저장 PUT·writer를 확인하는 경제 명령·주간 보상을 업데이트 필요로 거부한다. 하한 검사는 잠금 후 영수증 재조회 뒤에 두어 하한 상승 자체가 이미 성공한 요청의 재시도를 막지 않게 한다([저장 스키마와 구버전 클라이언트](multi_device_save_sync_design.md#16-저장-스키마와-구버전-클라이언트)). 앱 변경은 없으며, 하한은 이번 반영 뒤 writer 획득부터 기록된다. 서버 Go test/vet, 격리 PostgreSQL18 전체 DB 통합 검사(전용 하한 사례와 잠금 대기 중 재시도 영수증 복구 경쟁 사례 포함)와 022 적용→롤백(21)→재적용을 통과했다. 021 롤백은 런 젬 행에 020 이후 콘텐츠가 있으면 거부되며, 이를 격리 DB에서 확인했다. Codex 독립 검증에서 지적된 claim 재조회 순서·배포 설명·021 롤백 결함을 반영했다. 같은 검증이 찾은 기존 결함(writer를 확인하는 경제 명령·주간 보상에서 writer 세대·세션 불일치 검사가 잠금 후 영수증 재조회보다 앞서, writer 교체 경쟁 중 재시도가 영수증 대신 409를 받을 수 있음)은 이번 변경 전부터 있었다. 서버 결과는 이미 반영되어 있고 writer를 잃은 기기는 재연결 때 서버 상태로 복구되며 동시 기기 경쟁에서만 발생해, 영향이 미미하다고 보고 사용자와 합의해 처리하지 않았다.
- 동결 백업(`production-frozen-schema20.dump`, SHA-256 `8b211431fa69ada9817655151d32c7470978acaeb9812c9890ac932a68a3f390`)과 반영 기록은 Git 밖 `~/Library/Application Support/RuneNexus/operations/server-53fb799d-20261026T032849Z/`에 있다. 새 쓰기 뒤 구API/DB 자동 복귀는 하지 않는다. 실제 Google 계정 앱 E2E·독립 검증은 수행하지 않았다.

## 과거 배포 기록

이전 Godot 앱·서버 배포는 [배포 이력](archive/deployment_history_godot.md), 2026-09-12~20의 Flutter/Web 배포와 당시 복구 명령은 [전환 전 기록](archive/deployment_before_godot_20260924.md)에 보존한다. 현행 운영 절차나 다음 작업으로 사용하지 않는다.

## 기록 유지 규칙

- 이 문서에는 미배포 변경과 마지막 앱·서버 배포 기록만 둔다. 새 배포를 기록하면 같은 구성 요소의 직전 기록을 [배포 이력](archive/deployment_history_godot.md) 맨 위로 옮긴다.
- 배포가 필요한 코드 변경에는 필요한 migration·환경 설정·선행 조건을 함께 기록한다.
- 배포 후 구성 요소별 커밋, workflow/release, 검증 결과와 한계를 갱신하고 미배포 항목을 정리한다.
- 실패·부분 완료는 구성 요소별로 기록한다. 과거 대화나 로컬 작업 기록만으로 완료를 판단하지 않는다.
- 비밀번호, 토큰, 암호화 키, DB 백업 내용은 이 문서나 커밋에 넣지 않는다.
- 운영 작업 폴더(`~/Library/Application Support/RuneNexus/operations/`)에는 실행 중인 API의 compose가 있는 폴더와 다음 배포 준비 폴더만 둔다. 나머지는 외장 `/Volumes/KIOXIA_MAC/RuneNexus/operations-archive/`로 옮기며, 기록에 적힌 `operations/<폴더>` 경로는 그 아래에서 찾는다.

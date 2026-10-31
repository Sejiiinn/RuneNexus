# Godot 단독 앱 배포 이력

역할: 2026-09-24 Godot 단독 앱 전환 이후 배포 기록의 보존본. 최신 앱·서버 배포와 미배포 변경은 [배포 상태](../deployment_status.md)에 있고, 새 배포를 기록할 때 직전 기록을 이 문서 맨 위로 옮긴다. 각 절의 “현재”·“이번”은 당시 기준이다. 전환 전 기록은 [전환 전 배포 기록](deployment_before_godot_20260924.md)에 있다. 본문의 `~/Library/Application Support/RuneNexus/operations/<폴더>` 근거는 2026-10-26부터 외장 `/Volumes/KIOXIA_MAC/RuneNexus/operations-archive/<폴더>`에 있다.

## 2026-10-28 Android 0.2.30 / code 6059 — 공개 완료

- APK 대상 `33d6519983af37af0efab437903bf081a515e511`, [build-only CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40650174316), [공개 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40652276663), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6059), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6059/rune-nexus.apk). 2026-10-28 07:47:27 UTC(16:47:27 KST)에 공개·최신 지정했다. 저장·API 호환이 유지되어 **선택 업데이트**이며 최소 지원 코드는 6058 그대로다. 클라이언트 세대·저장·API·DB 변경이 없어 서버는 반영하지 않았다(운영 `f85a9037` 이후 `server/`·콘텐츠 원본·fixture 변경 없음).
- 포함: 영구 강화 탭을 청동 단련대 목록과 해금·잠김·완료 상태 탭으로 재설계하고 레벨업 성공 단련 연출 추가, 강화 탭 배경의 용광로 빛·불티, 연구 탭을 청록 설계도 카드·연구 전용 9-slice 에셋·작은 크기용 아이콘으로 재설계하고 배경 청록 조명·훑기 빛·입자 추가, 슬롯이 차 있어도 룬이 충분한 연구 카드는 어둡게 하지 않음([결정](../design_decisions/lobby.md)), 스테이지 홈 설정을 하단 단축 줄 맨 왼쪽으로 이동, 선택 소켓 숫자 중심 보정과 획득한 해금 배지 체크 표시 유지. 쓰지 않는 옛 연구 슬롯 에셋 2개를 제거했다.
- 검사: 로컬에서 관련 Godot 회귀(강화·연구 화면, 연구 가능 상태·슬롯·중단·모달 갱신·확인창, 로비)를 통과했다. build-only CI가 배포 검사 공용 액션(계약·회귀·준비 프로젝트)·서명 빌드·팩 감사·패치 디코더·차등 업데이트 준비를 통과했고, 공개 실행은 검수한 build-only 후보를 다시 빌드하지 않고 승격했다(`same_as_build_only_candidate=true`).
- APK **359,493,129 bytes**, SHA-256 `fabce59d…`(전체 값은 [update.json](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6059/update.json)). 6058 대비 **+475,608 bytes**이며 PCK가 206,675,800 bytes·1439항목(+475,604 bytes, +50항목)으로 늘었다. 강화 13개·연구 14개 새 UI PNG를 더하고 옛 연구 슬롯 2개를 뺀 순증 25개 에셋의 가져오기 항목이다. 기존22개 중복군2,707,494 bytes는 같고 신규 중복은 없다. **6058/6057/6056→6059 패치는 6,591,008 / 6,944,820 / 7,389,661 bytes**다.
- 공개 tag 대상 커밋·성공 CI, latest/버전별 `update.json` 일치, 익명 공개 주소에서 받은 자산4개의 크기·SHA-256과 GitHub digest 일치를 확인했다(`apk_release.py publish`의 `public-verification.json`).
- Codex 독립 검증(gpt-6-astra, high): 강화 탭 재설계(조건 1·2·3·5·6·9 PASS, 미미 2건은 생략 제안, 1건은 기존부터 실패하던 `verify_menu_shell_parity.gd`)와 연구 탭 재설계(조건 10개 중 8개 PASS, 에셋 면 알파 252~254의 미미 1건은 사용자 합의로 생략, 훑기 빛 움직임은 미확인)를 각각 받았다. 강화 탭의 세부 디테일·단련 연출·배경은 그 검증 뒤에 바뀌어 독립 재검증하지 않았다.
- Android 전용 변경이 없어 AVD·기기 확인은 하지 않았다. **Android 실기기의 새 강화·연구 화면 표시와 터치, 모바일 GPU에서의 배경 셰이더·입자 부하, 앱 내 패치 업데이트, 실제 Google 로그인·운영 서버 연결 강화·연구 명령은 미검증**이다.

## 2026-10-28 Android 0.2.29 / code 6058 — 공개 완료

- APK 대상 `eca02b549a96bd62a8bb2e266340c34d1cb28e0d`, [build-only CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40530691263), [공개 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40533131959), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6058), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6058/rune-nexus.apk). 2026-10-27 15:39:51 UTC(2026-10-28 00:39:51 KST)에 공개·최신 지정했다. 사용자 요청으로 **필수 업데이트·최소 지원 코드6058**이다. 클라이언트 세대·저장·API·DB 변경이 없어 서버는 반영하지 않았다(운영 `f85a9037` 이후 `server/`·콘텐츠 원본·fixture 변경 없음).
- 포함: 별도 메인 로비를 없애고 스테이지 탭을 챕터 지도 홈으로 교체(지도·소켓·해금 배지·룬 보상·선택 경로·챕터별 배경 움직임, 하단 스테이지 카드와 해금 말풍선, 옛 목록·상세 모달 제거, [결정](../design_decisions/lobby.md)), 임무 보상 수령 중 회전 로딩과 획득 다이아 수치 연출(완료 문구 제거), 코어 트리의 영역 4개 제목·진행 배지·상세 영역 태그 제거. 독립 검증 후 수정 2건(수령 대기 중 임무창 재진입 때 로딩·획득 표시, 카드 안 탭으로 말풍선 닫기)을 함께 넣었다.
- 검사: 로컬에서 관련 Godot 회귀(로비·스테이지·숫자·임무 수령·모달·리더보드·레이아웃·챕터3 체크포인트·코어 트리)와 프로젝트 검사(로비 헤더·모달·앱 수명주기·챕터3 렌더·확장 코어 UI), `test_prepare_godot_project` 12건을 통과했다. build-only CI가 배포 검사 공용 액션(계약·회귀·준비 프로젝트)·서명 빌드·팩 감사·패치 디코더·차등 업데이트 준비를 통과했고, 공개 실행은 검수한 build-only 후보를 다시 빌드하지 않고 승격했다(`same_as_build_only_candidate=true`).
- APK **359,017,521 bytes**, SHA-256 `dc3e8719…`(전체 값은 [update.json](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6058/update.json)). 6057 대비 **−3,016,192 bytes**이며 PCK가 206,200,196 bytes·1389항목(−3,016,192 bytes, −52항목)으로 줄었다. 옛 로비 배경·받침대, 챕터 배너, 스테이지 목록·상세 모달 전용 UI 33개를 앱 에셋 목록에서 빼고, 챕터 지도 3장(손실 WebP·밉맵)과 소켓 2개를 더했다. 기존22개 중복군2,707,494 bytes는 같고 신규 중복은 없다. **6057/6056/6055→6058 패치는 6,564,151 / 6,882,774 / 9,747,791 bytes**다.
- 공개 tag 대상 커밋·성공 CI, 내장 `clientBuild=android:eca02b54…`, latest/버전별 `update.json` 일치, 익명 공개 주소에서 받은 자산의 크기·SHA-256과 GitHub digest 일치를 확인했다(`apk_release.py publish`의 `public-verification.json`).
- Codex 독립 검증(gpt-6-astra, high): 미배포 커밋 3건 대상 완료 조건 8개 중 6개 PASS, 2개 FAIL(중간 1건·미미 1건)을 받아 모두 수정하고 검증자 재현 스크립트로 재확인했다. 수정 뒤 전체 재검증은 하지 않았다.
- 지도 홈은 데스크톱 `--app`의 로그인 관문에 가려 실제 로비 코드에 시험 진행 데이터를 넣어 확인했다([캡처](../../design/stage_map_concepts/2026-10-27/README.md)). AVD 업데이트 설치 확인은 하지 않았다. **Android 실기기의 지도 홈 표시·터치·시스템 뒤로가기(지도에서 앱 종료), 모바일 GPU에서의 배경 효과 부하, 앱 내 필수 업데이트·패치 다운로드, 실제 Google 로그인·운영 서버 연결 보상 수령은 미검증**이다.

## 2026-10-27 Android 0.2.28 / code 6057 — 공개 완료

- APK 대상 `cfc87f0725cefe0f6006b1dcb1c3af22531602fd`, [build-only CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40452279229), [공개 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40454068459), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6057), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6057/rune-nexus.apk). 2026-10-27 05:26:22 UTC(14:26:22 KST)에 공개·최신 지정했다. **선택 업데이트·최소 지원 코드6055**이며 클라이언트 세대14·저장·API·DB 변경이 없어 서버는 반영하지 않았다(`53fb799d` 이후 서버 쪽 변경은 테스트 주석·검사 경로 문서뿐).
- 포함: 적 종류별 첫 처치 때 사망 연출 셰이더 준비 끊김(데스크톱 70~80ms)을 로딩 예열로 이동, 첫 탱크의 체력바 기준점 재계산(7~8ms) 제거, 웨이브 끝 하단 HUD 패널 재구성 비용 제거, 젬 보상 화면 첫 표시의 텍스처 로드 지연 제거, 전투 스텝·명중의 임시 할당 축소. 동작 변화 없는 전투 런타임·앱 수명주기·전장 장면·전장 환경·확장 코어 트리 계층 분할과 검사 스크립트의 `godot/tests/` 이동(내보내기 제외)도 포함한다.
- 두 CI 모두 배포 검사 공용 액션(계약·회귀·준비 프로젝트)·서명 빌드·팩 감사·Android 패치 디코더·검증된 차등 업데이트 준비를 통과했다. 공개 실행은 build-only와 별도로 다시 빌드했으므로 아래 크기는 공개본 기준이다.
- APK **362,033,713 bytes**, SHA-256 `413caeb5…`(전체 값은 [update.json](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6057/update.json)). 6056 대비 **+32,396 bytes**이며 전부 PCK 증가다(209,216,388 bytes·1441항목, +38항목). 증가 항목은 계층 분할로 생긴 새 스크립트 19개의 `.gdc`·`.remap`이고 `tests/`·`verify_*` 항목은 없다. 기존22개 중복군2,707,494 bytes는 같고 신규 중복은 없다. **6056/6055/6054→6057 패치는 4,618,321 / 7,641,275 / 7,774,906 bytes**다.
- 공개 tag 대상 커밋·성공 CI, 내장 `clientBuild=android:cfc87f07…`, latest/버전별 `update.json` 일치, 익명 공개 주소에서 받은 자산4개의 크기·SHA-256과 GitHub digest 일치를 확인했다(`apk_release.py publish`의 `public-verification.json`).
- Android에서만 드러나는 변경(저장 마이그레이션·업데이트/패치 경로·네이티브 연동·터치·수명주기)이 없어 AVD 업데이트 설치 확인은 하지 않았다. 끊김 개선 수치는 데스크톱 실제 앱 측정이며 **Android 실기기·모바일 GPU에서의 개선, 앱 내 패치 다운로드 업데이트, 실제 Google 로그인·계정 동기화·운영 서버 연결 플레이는 미검증**이다. 포함 변경 중 사망 연출 예열·탱크 기준점·HUD 비용·계층 분할 일부는 Codex 독립 검증을 거쳤고, 배포 절차 자체의 독립 검증은 요청이 없어 수행하지 않았다.

## 2026-10-26 서버·DB — `53fb799d` 반영 완료

- [반영 스크립트](../../scripts/server_release.py)로 처음 반영했다. 정확한 `53fb799d19b77bb77749704096bbf6011bff8fe8` 소스로 `rune-nexus-api:53fb799d`(image `sha256:8cb973e8714f5566de51debd3c2007d47ea4962e1ee0cc1ae862c85e474eb0a1`, revision label 일치)를 빌드했다. `prepare`에서 Go test/vet·전체 pgx 통합, 운영 DB 사본의 migration021·022(스키마20→22) 뒤 기존 33개 테이블의 기존 열 값 보존, 새 이미지 격리 기동의 공개 계약9조건을 통과했다. `rehearse-deploy`로 운영 DB 사본·현 API 설정의 격리 스택에서 정지·동결 백업 복원·마이그레이션·기동·HTTP9조건까지 통과했다.
- 2026-10-26 13:23:39~13:23:52 KST에 API를 정지(DB 클라이언트0 확인)하고 동결 백업을 격리 복원해 행 지문이 같음을 확인한 뒤 운영 DB를 **스키마20→22**로 올렸다. 기존 열 값은 모두 보존됐다. 새 API는 healthy이며 loopback·공개 HTTPS의 상태 200·보호 경로401 18조건을 통과했다. 환경·mount·port·network·실행 설정과 PostgreSQL/Caddy/DuckDNS 컨테이너를 보존했다. 운영 계정 로그인·명령은 하지 않았다.
- 반영 내용: 젬·포탑 식별자 형식 검사(021), 계정별 클라이언트 세대 하한(022), 세대 14(지원 코어) 수용, 콘텐츠 레지스트리 기반 서버 검증.
- 세대 하한: DB migration022가 `save_writer_states.client_generation_floor`를 추가하고, 서버는 writer를 획득한 가장 높은 세대를 기록해 그보다 낮은 세대의 writer 획득·저장 PUT·writer를 확인하는 경제 명령·주간 보상을 업데이트 필요로 거부한다. 하한 검사는 잠금 후 영수증 재조회 뒤에 두어 하한 상승 자체가 이미 성공한 요청의 재시도를 막지 않게 한다([저장 스키마와 구버전 클라이언트](../multi_device_save_sync_design.md#16-저장-스키마와-구버전-클라이언트)). 앱 변경은 없으며, 하한은 이번 반영 뒤 writer 획득부터 기록된다. 서버 Go test/vet, 격리 PostgreSQL18 전체 DB 통합 검사(전용 하한 사례와 잠금 대기 중 재시도 영수증 복구 경쟁 사례 포함)와 022 적용→롤백(21)→재적용을 통과했다. 021 롤백은 런 젬 행에 020 이후 콘텐츠가 있으면 거부되며, 이를 격리 DB에서 확인했다. Codex 독립 검증에서 지적된 claim 재조회 순서·배포 설명·021 롤백 결함을 반영했다. 같은 검증이 찾은 기존 결함(writer를 확인하는 경제 명령·주간 보상에서 writer 세대·세션 불일치 검사가 잠금 후 영수증 재조회보다 앞서, writer 교체 경쟁 중 재시도가 영수증 대신 409를 받을 수 있음)은 이번 변경 전부터 있었다. 서버 결과는 이미 반영되어 있고 writer를 잃은 기기는 재연결 때 서버 상태로 복구되며 동시 기기 경쟁에서만 발생해, 영향이 미미하다고 보고 사용자와 합의해 처리하지 않았다.
- 동결 백업(`production-frozen-schema20.dump`, SHA-256 `8b211431fa69ada9817655151d32c7470978acaeb9812c9890ac932a68a3f390`)과 반영 기록은 Git 밖 `~/Library/Application Support/RuneNexus/operations/server-53fb799d-20261026T032849Z/`에 있다. 새 쓰기 뒤 구API/DB 자동 복귀는 하지 않는다. 실제 Google 계정 앱 E2E·독립 검증은 수행하지 않았다.

## 2026-10-26 Android 0.2.27 / code 6056 — 공개 완료

- APK 대상 `82aae9da7a0cf69a6a13157a083d14b1298d9fc9`, [build-only CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40269450886), [공개 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40273588260), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6056), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6056/rune-nexus.apk). 2026-10-26 05:34:57 UTC(14:34:57 KST)에 공개·최신 지정했다. **선택 업데이트·최소 지원 코드6055**이며 서버 `53fb799d`·DB22를 먼저 반영했다.
- 포함: 지원 코어(3-2 해금, 첫 계열 피해 증가, 클라이언트 세대14), 앱 복귀 때 유효한 동일 계정의 재연결 화면·인증 복원 생략, 관통 젬 설명 간소화, 콘텐츠 레지스트리 기반 식별자와 코어 부품 피해 증가 범위 결함 수정, PCK 파일 단위 차등 패치 생성기, 공개 APK의 `x86_64` 제외.
- 두 CI 모두 배포 검사 공용 액션(Python·콘텐츠·Godot 네이티브 회귀·계정/AppServices·준비 프로젝트 session/lifecycle)·서명 빌드·팩 감사·Android 패치 디코더를 통과했고, 패치3개의 Python/Kotlin 차등 복원이 통과했다. 공개 실행은 build-only와 별도로 다시 빌드했으므로 아래 크기는 공개본 기준이다.
- APK **362,001,317 bytes**, SHA-256 `61bb8c93…`(전체 값은 [update.json](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6056/update.json)). 6055 대비 **−70,730,197 bytes(−16.3%)**로 `x86_64` 엔진·C++ 라이브러리(약75MB) 제거가 원인이며 PCK는 지원 코어 에셋만큼 +4,676,784 bytes(209,183,992 bytes·1403항목)다. 기존22개 중복군2,707,494 bytes는 같고 신규 중복은 없다. **6055/6054/6053→6056 패치는 7,214,232 / 7,348,587 / 11,025,106 bytes**로, 이전 고정 청크 생성기의 약146MB에서 줄었다.
- 공개 tag 대상 커밋·성공 CI, 내장 `clientBuild=android:82aae9da…`, latest/버전별 `update.json` 바이트 일치, 익명 공개 주소에서 받은 자산5개의 크기·SHA-256과 GitHub digest 일치를 확인했다(`release_report verify`, 공개 다운로드 관측 항목은 curl 익명 다운로드로 대조).
- build-only 후보로 API37 arm64 읽기 전용 AVD에서 공개 6055 설치·실행 → 6056 업데이트 설치 직후 primary/backup 저장 바이트·최초 설치 시각 동일, 6056 실행 후 런타임 오류 없이 로비·게스트 로그인 안내 표시를 확인했다. **앱 내 패치 다운로드 업데이트, 실제 Google 로그인·계정 동기화·운영 서버 연결 플레이, 실기기·모바일 GPU는 미검증**이다. 독립 검증은 요청 없어 수행하지 않았다.

## 2026-10-24 Android 0.2.26 / code 6055 — 모듈 분해 수정·필수 업데이트 공개 완료

- APK 대상 `34d05903e36249bf986478fce6201e0ae2dffc41`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40071018176), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6055), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6055/rune-nexus.apk). 검수한 build-only 산출물5개를 그대로 2026-10-24 07:02:17 UTC(16:02:17 KST)에 공개·최신 지정했다. **필수 업데이트·최소 지원 코드6055**이며 서버·DB 재배포는 하지 않았다.
- 분해 버튼이 존재하지 않는 `_service`를 확인해 연결 계정도 안내문으로 보내던 조건을 실제 진입점 `open_service`로 수정했다. 이 조건은 2026-09-22 `32cd0f52`부터 있었으며6054 배포 전 검사에서 실제 인벤토리 버튼 진입을 놓쳐 발견하지 못했다. 새 회귀 검사에서 수정 전 실패를 재현하고 수정 후 관련 네이티브3사례를 통과했다. 연결/미연결 서비스 대역으로 실제 버튼→확인창→요청, 단일/일괄 ID·환급 미리보기·장착 모듈 제외·확인 전 무변경·중복 요청 방지·미연결 차단을 확인했다.
- CI의 Python191개·Godot 네이티브91개·prepared session/lifecycle7개(NOT_RUN0), 계정/AppServices·서명 빌드·Android 패치 디코더·6052/6053/6054 서명 일치와 Python/Kotlin 차등 복원이 통과했다. 아티팩트12551438639의 실제 다운로드 ZIP SHA-256이 GitHub digest와 같았고, 패키지/바이너리 버전·기존 서명·운영 설정·내장 clientBuild를 대조했다. 실제 APK의 compiled PCK4사례(분해 확인·컬렉션·경제 서비스·compiled origin)와 Metal Mobile/Apple M4의320px 연결/미연결 확인창 검증을 통과했고 부모가 개별/일괄 분해 화면을 직접 확인했다. 제품 소스 override는 없으며 서비스 요청은 대역 검증이다.
- APK **432,731,514 bytes**, SHA-256 `fd2c631050b4ee73133e4bd4125d23ca3305cd8f19d9710fc683a1c18608eefb`. 6054 대비 **+48 bytes**로 PCK 증가와 같다. PCK204,507,208 bytes·1382항목, ABI3종/네이티브6개의 바이트와 기존22개 중복군2,707,494 bytes는 동일하다. 에셋 원본 변경·제작 원본 포함·신규 중복은 없다. 6052/6053/6054→6055 패치는 각각146,063,848 / 146,063,838 / 111,501,697 bytes다.
- 소유한 API37 arm64 read-only AVD의6054→6055 실제 업데이트 후 설치 직후 primary/backup 저장 바이트·최초 설치 시각, 뒤로가기/Home/재시작 후 진행 중 런·설정·모듈·v4 트리 투자/포인트 보존과 런타임 오류 없음 등10조건이 통과했다. 변경은 날짜 필드4개와 저장 시각뿐이다. 공개 후 같은 격리 환경의 실제6054 앱에서0.2.26 필수 업데이트 안내·업데이트 버튼만 표시·게임 시작 차단을 직접 확인했다. 소유 에뮬레이터를 종료했고 원본 AVD 디스크6개의 크기/mtime는 동일하다.
- 공개 tag 대상·성공 CI, latest/버전 manifest 바이트·최소 지원6055, 자산5개 크기·GitHub SHA-256이 검수본과 같고 익명 주소의 실제 APK·패치3개·manifest 다운로드도 통과했다. 상세 후보/공개 대조·실제 PCK·Android 저장/화면 근거는 Git 밖 `~/Library/Application Support/RuneNexus/operations/apk-6055-release-20261024T063841Z/`에 보관한다. **실제 Google 로그인·운영 계정 모듈 분해/환급·Android 본게임·실기기 조작/지속 성능은 미검증**이며 운영 계정 데이터는 변경하지 않았다. 독립 검증은 요청 없어 수행하지 않았다.

## 2026-10-24 서버·DB — 6054 선행 반영 완료

- 정확한 `e37d0b3846839133a803303c6f0b7972eec83003` 소스로 `rune-nexus-api:e37d0b38`을 빌드·반영했다. 실행 image ID는 `sha256:c9877cd7c032b3b2a6b9dc724eebb313ea6db8c2f5d59554a0c407de054e25f2`이며 revision label은 대상 소스 SHA와 일치한다. 뒤이은 앱 배포 준비 커밋은 검사 코드만 바꾸므로 운영 제품 코드와 같다.
- 2026-10-24 14:14:43~14:15:28 KST에 API 쓰기 정지·연결0을 확인하고 최신 DB18을 동결 백업했다. 백업을 격리 PostgreSQL18에 복원한 뒤 019(독 피해 젬)·020(독 모듈)을 적용해 **스키마18→20**, 기존33개 데이터 테이블의 모든 행·영수증 fingerprint 보존을 확인했다. 운영 migration 직후에도 복원 검증본과 동일했다. dump는 **2,364,590 bytes**, SHA-256 `f4217b73c2773c9f564be3bc9dabc8a657360dfd7b9ee33488c142fec5f5cb71`이며 복구 스크립트의 별도 재복원·DB20 이행도 통과했다.
- Go test/vet·전체 pgx 통합, 실제 새 이미지의 격리 HTTP32조건(독 훈련·모듈·세대13, 구12 차단, 과거 영수증 복구), 운영 loopback/공개 HTTPS18조건과 SQL4조건을 통과했다. API 교체 직후 공개503은 Caddy의 기존30초 health check 상태에서 발생했고 다음 검사에서 설정 변경·재시작 없이 회복했다. 최종 API는 healthy다.
- 전체 환경·인증 영수증키·mount/port/network·실행 옵션과 PostgreSQL/Caddy/DuckDNS 컨테이너를 보존했다. **최소 저장 호환세대4 유지**, 독 콘텐츠를 저장한 계정에는 선택적세대13 보호를 적용한다. 운영 계정 로그인·명령·지급·저장 조작은 하지 않았다. 새 쓰기 뒤 구API/DB 자동 복귀는 수행하지 않는다.
- 상세 소스·보호 백업·복원/compose·검사·동결/운영 대조는 Git 밖 `~/Library/Application Support/RuneNexus/operations/apk-6054-server-20261024T051316Z/`에 보관한다. 검수용 API·DB·네트워크와 임시 자격증명을 제거했고 운영4개 컨테이너·백업·복구 절차는 유지했다. 실제 Google 계정 앱 E2E는 미검증이며 독립 검증은 요청 없어 수행하지 않았다.

## 2026-10-24 Android 0.2.25 / code 6054 — 필수 업데이트 공개 완료

- APK 대상 `314673d6790345895ebcf6e3d307d95d63cc42ec`, [최종 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/40066395838), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6054), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6054/rune-nexus.apk). 검수한 build-only 산출물5개를 그대로 2026-10-24 05:58:20 UTC(14:58:20 KST)에 공개·최신 지정했다. **필수 업데이트·최소 지원 코드6054**이며 서버·DB는 아래 절과 같이 먼저 반영했다.
- 2-8 해금의 독 포탑·특성4종·독 화력 훈련·독 피해 증폭 젬·독 포탑 모듈/독 지속시간 옵션, 고정 라운드의 마법·희귀 몬스터와 옵션6종을 포함한다. 포탑별 화상·독 중첩, 독 외 지속피해의 방어구50% 적용, 보스 둔화 저항, 젬 구매 바로가기·모듈 화면의 번개 해금 판정도 반영했다. 부여 젬·포탑 컬렉션의 검토 중 아이디어는 포함하지 않았다.
- 최종 CI의 Python191개·Godot 네이티브91개·prepared session/lifecycle7개(NOT_RUN0), 계정/AppServices·서명 빌드·Android 패치 디코더·6051/6052/6053 서명 일치와 Python/Kotlin 차등 복원이 통과했다. 선행 CI의 두 codec timeout은 검사 임시프로젝트의 `enemy_rarity.gd` 누락이었고, 전역 콘텐츠 digest는 독 포탑 추가 전 기준이었다. `436bec82`에서 누락 의존성과 기대값만 고쳤으며 독 포탑 항목 제거 시 이전 전체 객체·digest가 정확히 일치하고 기존25개 stageDigests도 유지됨을 확인했다. 후속 CI의 다섯 번째 링크 검사는 신규 독 포탑 해금(ID23) 없이 전체 포탑 건설을 시도해 실패했다. `314673d6`에서 검사 조건과 실패 보고만 보완했고 제품 코드·데이터는 변경하지 않았다.
- CI 아티팩트12549907282의 다운로드 ZIP SHA-256이 GitHub digest와 일치했다. 부모가 실제 APK의 패키지/버전·기존 서명 인증서·운영 설정·내장 clientBuild·ABI3종/네이티브6개의 바이트 동일을 확인했다. 소스 override 없는 실제 compiled PCK7사례(독 포탑·희귀 몬스터·저장·성장·모듈·필수 업데이트 및 compiled origin)가 통과했다. 같은 PCK의 Metal Mobile/Apple M4 실제 렌더에서 승인 독 포탑 형태·재질·크기, 마법/희귀 표시와320px 독 모듈 옵션·440px 독 훈련 화면을 직접 확인했다. 이는 데스크톱 fixture 검증이며 Android 본게임 검증과 구분한다.
- 소유한 API37 arm64 read-only AVD에서6053→6054 실제 업데이트 후 설치 직후 primary/backup 저장 바이트와 최초 설치 시각이 동일했다. 뒤로가기·Home 복귀·강제 재시작 후 진행 중 런 전체·설정·모듈·v4 트리 투자/포인트 보존과 런타임 오류 없음 등10조건이 통과했다. 변경은 일/주 날짜 필드4개와 저장 시각뿐이다. 공개 후 같은 격리 환경의 실제6053 앱에서 **필수 업데이트·업데이트 버튼만 표시·게임 시작 차단**을 확인했다. 원본 AVD 디스크6개의 크기/mtime를 보존하고 소유 에뮬레이터를 정상 종료했다.
- APK **432,731,466 bytes**, SHA-256 `f5c00cfc59e930c757960d3399588712ad5f8663e52830998a8f71ebf505d69a`. 6053 대비 **+5,273,068 bytes(+1.234%)**로 PCK 증가분과 같다. PCK204,507,160 bytes·1382항목이며 새 독 포탑의 ASTC텍스처3개(각1,398,180 bytes)·씬542,920 bytes와 아이콘이 주요 증가 원인이다. 제작 원본은 포함하지 않았고 기존22개 중복군2,707,494 bytes는 hash·크기·경로까지 동일하여 신규 중복은 없다. 6051/6052/6053→6054 패치는 각각146,063,873 / 146,063,890 / 146,063,870 bytes다.
- 공개 tag의 대상 커밋·성공 CI, latest/버전별 manifest 바이트와 최소 지원6054, 자산5개의 크기·GitHub SHA-256이 검수본과 일치했다. 익명 공개 주소의 실제 APK·패치3개·manifest 다운로드 및 내장 clientBuild 대조도 통과했다. 상세 CI·후보/공개 대조·실제 PCK·Android 저장/화면 근거는 Git 밖 `~/Library/Application Support/RuneNexus/operations/apk-6054-release-20261024T051309Z/`에 보관한다. 중복 전송 아카이브·공개 다운로드 캐시는 정리하고 최종 후보와 근거는 유지했다.
- **실제 Google 로그인·계정 동기화·운영 서버 연결 앱 젬 덱 플레이·Android 본게임·실기기 터치/글자·모바일 GPU/지속 성능은 미검증**이다. 독립 검증은 요청 없어 수행하지 않았다.

## 2026-10-19 Android 0.2.24 / code 6053 — 공개 완료

- APK 대상 `fe4a9afc5f485785e556686b281dacaa6ad70ec4`, [최종 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/39144390106), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6053), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6053/rune-nexus.apk). 검수한 build-only 산출물 5개를 그대로 2026-10-18 16:46:48 UTC(10-19 01:46:48 KST)에 공개·최신 지정했다. **선택 업데이트·최소 지원 코드 6051**을 유지한다. 서버·DB는 아래 절과 같이 먼저 반영했다.
- 대형 표적 훈련·관통 젬, 3-6 해금의 피해 방식별 훈련 3종(최대80·레벨당0.5%·비용배율1.055), 긴급 매각·전술 명령 초기 연구를 포함한다. 젬 슬롯 확장 비용·장착 화면·포탈별 웨이브 안내, 챕터3 전장 소품·부유 잔해와 3-8 건설칸, 기기별 카메라 저장도 반영했다.
- 최종 CI의 Python190개·Godot 네이티브89개·prepared session/lifecycle7개(NOT_RUN0)·계정/AppServices·서명 빌드·Android 패치 디코더·6050/6051/6052 서명 일치와 Python/Kotlin 차등 복원이 통과했다. 선행 CI의 실패는 승인된 관통 젬/3-8 지형의 과거 기대값, 새 지속피해 계수 메타데이터의 과거 fixture 호환 검사 누락, 콘텐츠·비동기 저장 검사의 기존20초 실행 예산이었다. `28f4ed8d`·`21a01b3c`·`fe4a9afc`에서 검사만 수정하고 실제 대상3개를60초·직렬 실행으로 분류했다. 제품 코드·기존 엄격 대조·성공 표식은 유지했으며 별도 검증자가 수정 범위와 실행 결과를 확인했다.
- 별도 검증자가 최종 APK 신원·기존 인증서·운영 설정·정확 clientBuild·ABI/네이티브·패치51조건과 소스 override 없는 compiled PCK10사례를 통과했다. 변경된 imported 씬67개의 노드·메시·재질·애니메이션 의미값, 새 젬14개 텍스처와 승인 원본/엔진 알파 경계 보정도 대조했다. 최종 PCK의 Metal Mobile 실제 3-8/3-10 화면에서 잔해·벽 소품·경로 간격·부유와 정지 상태를 확인했고 부모도 직접 검토했다. 훈련80의320/440 화면과 보상/슬롯 모달의 기존 최종 근거는 관련 입력이 같아 재사용했다.
- API37 arm64 read-only AVD의 host GPU에서 6052→6053 업데이트·동일 appId/최초 설치 시각, 설치 직후 primary/backup 저장 바이트 동일을 확인했다. 실제 로그인 gate·뒤로가기·Home 복귀·강제 재시작 후 activeRun 전체·설정·모듈·v4 트리 투자/포인트가 보존됐고 변경은 날짜 필드3개와 저장 시각뿐이다. 부모10조건과 별도 검증자의 원자료19조건을 통과했다. 원본 AVD 디스크6개의 크기/mtime를 보존하고 소유 에뮬레이터를 정상 종료했다. **실제 Google 로그인·계정 동기화·운영 서버 연결 앱 젬 덱 플레이·Android 본게임·실기기 터치/글자·모바일 GPU/지속 성능은 미검증**이다.
- APK **427,458,398 bytes**, SHA-256 `0e7bae02fd628523f0eed1e81225269088119dc3f2ba2cf37dc06392051d6e95`. 6052 대비 **+2,095,232 bytes(+0.493%)**로 PCK 증가분과 같다. ABI3종·네이티브6개는 동일하고 제작 원본은 포함하지 않았다. 기존22개 중복군2,707,494 bytes는 hash·크기·경로까지 동일하여 신규 중복은 없다. 6050/6051/6052→6053 패치는 각각143,367,869 / 143,367,854 / 143,367,868 bytes다.
- 공개 tag의 대상 커밋·성공 CI와 latest/버전별 manifest 바이트, 자산5개의 크기·GitHub SHA-256이 검수본과 일치했다. 익명 공개 URL의 APK·패치3개·manifest 실제 다운로드와 내장 clientBuild 대조도 통과했다. 별도 검증자가 공개·최신·tag/CI·자산/manifest 결속27조건을 독립 확인했다. 상세 CI·팩 감사·후보/공개 대조·Android 저장/화면·독립 검증 근거는 로컬 `build/release-verification/apk-6053/`에 보관한다.

## 2026-10-19 서버·DB — 6053 대상 운영 반영 완료

- API 소스 `f1c201d97b39cd29fc78a6f5d3fe993364455d55`, 이미지 `rune-nexus-api:f1c201d9`, image ID `sha256:fc64dc70af7cc7153e8e3f0aeb7fa21807c613dc873d1e04a2d932cd3e54e527`, DB18이며 healthy다. 공개 앱 `fe4a9afc`와 서버·공용 콘텐츠·fixture 입력은 동일하며 이후 차이는 검사 하네스뿐이다.
- 관통 젬의 migration018과 세대 11·12 저장 보호, 대형 표적·피해 방식별 훈련 및 초기 연구 해금을 반영했다. 2026-10-19 01:19:01~01:19:14 KST에 API만 정지해 연결 0을 확인하고 최신 DB17 백업을 동결했다. 백업을 격리 PostgreSQL18에 정확 복원·018 적용한 뒤 기존 33테이블의 모든 행·영수증 fingerprint 보존을 확인했고, 운영 018 적용 직후 결과도 복원본과 동일했다. 동결 dump는 2,237,942 bytes, SHA-256 `8ff1eaa76918aedf70f14d953849daad5eb19001f13b749092cccc5b9fac4b09`다. 새 쓰기 후 구 API/DB 자동 복귀는 수행하지 않는다.
- 정확 서버 입력의 Go test/vet·전체 pgx 통합, 최종 이미지의 격리 HTTP 23조건과 운영 loopback/공개 HTTPS 18조건을 통과했다. 별도 검증자가 실제 이미지·DB18·SQL 함수·환경과 동결 dump/복원·운영 migration 직후 전체 행을 직접 대조해 51조건을 통과했다. 실제 운영 계정 명령·로그인·지급·저장 조작은 하지 않았다.
- 환경 전체·인증 영수증 키·mount·port·network·실행 옵션과 PostgreSQL/Caddy/DuckDNS 컨테이너를 보존했다. 최소 저장 호환 세대4를 유지하며 기존 세대10에는 관통 젬을 발급하지 않는다. 새 콘텐츠를 저장한 계정만 해당 세대 11/12 보호가 적용되고 정확한 기완료 구 영수증 복구는 유지한다.
- 상세 소스·보호 백업·복원 절차·compose·검사·동결/운영 대조는 Git 밖 `~/Library/Application Support/RuneNexus/operations/apk-6053-server-20261018T155324Z/`, 독립 검수는 로컬 `build/release-verification/apk-6053/independent/`에 보관한다. 검수용 API·DB·네트워크와 임시 비밀번호/환경 파일을 정리했으며 운영4개 컨테이너·보호 백업·소스·compose·로그는 보존했다. 실제 계정 앱 E2E는 이 서버 검증 범위에서 미검증이다.

## 2026-10-15 Android 0.2.23 / code 6052 — 공개 완료

- APK 대상 `764e0bfc80c3e3aa4c5a79b6da5da5ddcd11f547`, [최종 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38685335668), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6052), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6052/rune-nexus.apk). 검수한 build-only 산출물 5개를 그대로 2026-10-15 05:36:55 UTC(14:36:55 KST)에 공개·최신 지정했다. **선택 업데이트·최소 지원 코드 6051**을 유지한다.
- 스킬트리 적용 후 카메라 유지·연결 예정 노드 표시 제거, 할당 경로를 따라 퍼지는 빛과 흰빛 투자 계획 표시를 포함한다. 보호막형 적의 새 석재·금속 고리·부유석 모델과 보호막·부유·사망 모션, 실제 룬 면의 진행 방향 정렬, 부품 표면에 붙는 전기 아크·착지 방전도 반영했다. 서버·DB·운영 설정은 변경하지 않았다.
- 최초 [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38685000884)는 기존 준비 검사에서 보호막 텍스처의 채택된 1K import 제한을 기대 목록에 넣지 않아 Python 검사 1개가 실패했다. `764e0bfc`에서 검사 목록 한 줄만 수정했고 제품 코드·에셋·import 정책은 유지했다. 별도 검증자가 실제 정책·에셋 계약·반복 prepare 회귀를 직접 대조했다.
- 최종 CI의 Python180개·Godot 네이티브87개·prepared session/lifecycle7개(NOT_RUN0)·계정/AppServices·서명 빌드·Android 패치 디코더·6049/6050/6051 서명 일치와 Python/Kotlin 차등 복원이 통과했다. 별도 검증자는 실제 APK 신원·서명·설정·패치37조건과 소스 override 없는 compiled PCK5사례를 통과했다. 보호막 최종 실제 화면·모션·접점·정지/되감기·렌더 경계 근거는 최종 런타임 입력과 일치하며, 트리 후속 빛 전파·흰빛 계획·완료 금색·카메라 보존은 Metal Mobile 실제 화면26조건으로 추가 확인했다. 부모도 최종 대표 화면을 직접 확인했다.
- API37 arm64 read-only AVD의 host GPU에서 6051→6052 업데이트·동일 appId/최초 설치 시각, 설치 직후 primary/backup 저장 바이트 동일을 확인했다. 실제 로그인 gate·뒤로가기·Home 복귀·강제 재시작 뒤 진행 중 activeRun 전체·설정·모듈·트리 투자·포인트는 동일하며 변경은 날짜 필드3개와 저장 시각뿐이다. 부모10조건과 별도 검증자의 원자료19조건을 통과했다. 원본 AVD 디스크 크기/mtime는 동일하며 소유 검수 에뮬레이터를 정상 종료했다. **실제 Google 로그인·계정 동기화·운영 서버 연결 앱 젬 덱 플레이·Android 본게임·실기기 터치/글자·모바일 GPU/지속 성능은 미검증**이다.
- APK **425,363,166 bytes**, SHA-256 `b41866da01829994b27dc48428a2266ea822f5616574128877eb1af31c567a75`. 6051 대비 **+4,773,052 bytes(+1.13%)**로 PCK 증가분과 같다. PCK197,138,860 bytes·1312항목이며 신규 ASTC 텍스처3개(각1,398,180 bytes)와 보호막 imported scene545,765 bytes가 증가 대부분이다. ABI3종·네이티브6개 바이트는 동일하고 제작 원본은 포함하지 않았다. 기존22개 중복군2,707,494 bytes는 hash·크기·경로까지 동일하여 신규 중복은 없다. 6051→6052 패치는108,136,704 bytes다.
- 공개 tag의 대상 커밋, latest/버전별 manifest 바이트, 자산5개의 크기·GitHub SHA-256과 검수본 일치를 확인했다. 익명 공개 URL의 APK·패치 다운로드와 내장 clientBuild 대조도 통과했다. 상세 CI·팩 감사·후보/공개 대조·Android 저장/화면·독립 검증 근거는 로컬 `build/release-verification/apk-6052/`에 보관한다.

## 2026-10-14 Android 0.2.22 / code 6051 — 공개 완료

- APK 대상 `1bd39c2de857a0175d4846536a4f561d3481cc42`, [최종 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38431257495), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6051), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6051/rune-nexus.apk). 검수한 build-only 산출물 5개를 **필수 업데이트·최소 지원 코드 6051**로 2026-10-13 17:07:55 UTC(10-14 02:07:55 KST)에 공개·최신 지정했다. 아래 DB017→API 세대10 반영을 먼저 마쳤다.
- 60노드 코어 트리와 핵심 효과 8개, 추가 체력·비축 표시, 승인 시안의 포인트/투자 계획·노드/스킬 시트·확대/이동 조작, 원소 연소/확산 분류를 포함한다. 런 시작에 발급한 젬 덱으로 선택·재선택·구매 대기를 줄였고, 연구 완료·강화·전투 처리와 백그라운드 저장의 반복 비용·슬롯 거래 교착을 보완했다. 기존 진행 중 v4 런의 고정 트리·코어·모듈을 유지하며 실제 종료 후 계정 트리를 v5로 이관한다. 총 포인트와 최초 보상 기록은 보존한다.
- 최초 [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38428737471)는 기존 5링크 검사가 새 v5 런 고정을 생략해 실패했다. 전체 사전 대조에서 스테이지 검사의 성장 도메인 주입·런 고정과 과거 스탯 fixture의 새 중립 효과 필드도 보완했다. 원본 fixture·기존 엄격한 수치/키 대조를 유지하고 새 6필드의 중립값을 명시 검증한다. 유효하지 않은 코어 체크포인트는 스크립트 예외 대신 거절하도록 국소 수정했고 원본 불변 검사를 추가했다. 관련 변경은 `f33aa7e1`·`1bd39c2d`이며 별도 검증자가 재현과 수정 후 결과를 확인했다. 중간 CI는 사전 검사 중 발견한 누락 때문에 취소했으며 APK 공개에 쓰지 않았다.
- 최종 CI의 Python180개·Godot 네이티브87개·prepared session/lifecycle7개(NOT_RUN0)·계정/AppServices·서명 빌드·Android 패치 디코더·6048/6049/6050 서명 일치와 Python/Kotlin 차등 복원이 통과했다. 별도 검증자는 실제 APK 신원/서명/자원/패치35조건, 실제 앱과 같은 gd→gdc 경로의 compiled 출처·기능24조건을 확인했다. 새 이미지43개의 크기/엔진 기본 알파 경계 보정 후 픽셀, 기존 imported 씬63개의 노드·자원·메시·재질·애니메이션 의미값도 대조했다. 부모와 검증자가 최종 입력에 대응하는 Metal Mobile의 승인 트리·상세·스킬·추가 체력 HUD와 비축 표시를 직접 확인했다.
- API37 arm64 read-only AVD에서 6050→6051 업데이트·동일 서명·appId/최초 설치 시각을 확인했다. 설치 직후 primary/backup 저장 바이트는 동일하며, 실제 로그인 gate·뒤로가기·홈 복귀·강제 재시작 후 진행·설정·고정 코어/모듈과 activeRun 전체를 보존했다. 런에 생략됐던 `runCorePassiveTreeRevision=4`를 정상 고정한 1필드와 날짜 표시/저장 시각만 바뀌었다. 별도 검증자17조건이 통과했고 부모도 대표 최종 화면을 직접 확인했다. 초기 짧은 캡처는 로딩 중이어서 완료 근거로 쓰지 않고 실제 준비 완료 후 화면/복귀 근거로 확인했다. 원본 AVD 디스크 크기/mtime는 모두 동일하며 소유 검수 에뮬레이터를 정상 종료했다. **실제 Google 로그인·계정 동기화·운영 서버와 연결한 앱 젬 덱 플레이·Android 본게임·새 트리의 실기기 터치/글자·모바일 GPU/지속 성능은 미검증**이다.
- APK **420,590,114 bytes**, SHA-256 `efc6059d9f8e6fdbd3fe87582618d9f80979bd8e68d29370a8db9e307f78a864`. 6050 대비 **+9,802,400 bytes(+2.39%)**로 PCK 증가분과 같다. PCK192,365,808 bytes·1297항목이며 새 코어 트리 이미지/콘텐츠·compiled 코드가 원인이다. 제작 원본 미포함·ABI3종/네이티브6파일 동일을 확인했다. 완전 중복2,707,494 bytes 중 기존699,208 bytes는 유지되고 신규22그룹2,008,286 bytes는 새 트리와 기존 UI아이콘의 별칭 재사용이다. 해당 원본 픽셀이 모두 같음을 대조했으며 이번 배포에서 중복 경로를 정리하지 않았다. 6050→6051 패치는139,070,609 bytes다.
- 초안 검수 뒤 공개 태그 대상·latest/버전별 manifest 바이트 일치와 최소 지원6051, 공개5자산의 크기/GitHub SHA-256·익명 다운로드 바이트가 검수본과 동일함을 확인했다. 상세 CI·패키지·시각/Android·공개·독립 검수 근거는 Git 밖 `build/release-verification/apk-6051/`에 보관한다.

## 2026-10-14 서버·DB — 6051 대상 운영 반영 완료

- API 실제 소스 `b4e848a3f4ea5d9db669b6141eff89faa4592d80`, 이미지 `rune-nexus-api:b4e848a3`, image ID `sha256:65dc610e7506db23e012d0ba8bb0635da5f98eed4a3376ccb14f18497455e707`이며 healthy다. 최종 APK 대상 `1bd39c2de857a0175d4846536a4f561d3481cc42`와 서버·공용 콘텐츠·fixture 바이트가 동일하다. 2026-10-13 17:05:24 UTC(10-14 02:05:24 KST)에 API 쓰기를 정지하고 17:05:37 UTC에 최종 자체 검증을 마쳤다.
- 세대10 런 젬 덱 migration017과 60노드 코어 트리/저장 검증을 반영했다. DB를 **16→17**로 올렸으며 기존 경제 런은 `gem_deck=NULL`로 유지한다. API 정지·DB 연결0 뒤 보호된 동결 백업을 격리 PostgreSQL18에 복원해 migration017을 검증하고, 기존33개 데이터 테이블(스키마 버전 포함34개)의 전체 행·ID·updated_at 및 영수증이 그대로 보존됨을 확인했다. 실제 운영17의 새 API 시작 전 행 fingerprint도 검증된 동결 복원본과 동일하다.
- 기존 DB16 SQL 체크 함수는 내부 함수명을 비한정으로 호출해 빈 검색 경로의 기본 pg_restore에서 데이터 복원이 실패한다. 보호 백업에서 생성한 복원 SQL의 단일 `search_path` 설정만 `public, pg_catalog`로 지정해 정확 복원을 검증했다. 제품 소스·운영 함수·데이터는 이 우회 때문에 수정하지 않았다. 해당 보호된 복원 절차와 원본 dump를 함께 보존한다. migration017의 down은 덱을 삭제하지 않으며 새 쓰기 뒤 구 API/DB 자동 복귀는 수행하지 않는다.
- 정확 소스 Go test/vet, 전체 실제 pgx 통합102개(skip0)와 별도 CGO compiler를 갖춘 격리 DB race102개를 통과했다. 최초 Alpine 기본 runner의 race는 CGO 누락으로 실패했으며 대체 실행 결과를 별도로 보존한다. 실제 API 이미지의 격리 HTTP26개에서 세대10 writer/60노드 tree 이관·구9 저장 exact receipt·구9 신규 writer/save 거절·잘못된 allocation422, 런 덱 발급/7waves/runId·exact replay·snapshot 복구, 세대10 우편 및 구6 completed 우편 영수증 exact 복구·구6/7/8 신규 명령 거절과 wallet revision 불변을 확인했다.
- 운영 환경 전체·인증 영수증 키·mount·port·network 및 PostgreSQL/Caddy/DuckDNS 컨테이너를 보존한다. 환경 최소 저장 호환 세대4를 유지하며 콘텐츠 계약이 신규 이관 상태의 구세대 쓰기를 거절한다. loopback/공개 HTTPS live/ready200 4건과 무인증 보호401 14건을 확인했다. 운영 계정 명령·지급·로그인·저장 조작은 수행하지 않았으며 실제 계정 앱 E2E는 이 서버 검증 범위에서 미검증이다.
- 상세 소스·보호 백업/compose·Go/pgx/race·실제 이미지 HTTP·동결 복원과 운영 검증 근거는 Git 밖 `~/Library/Application Support/RuneNexus/operations/apk-6051-server-20261013T161316Z/`에 보존한다. 별도 검증자가 실제 운영 이미지·환경·DB17·보호 HTTP18건과 동결 복원본/운영 migration 직후 전체 행을 자체 대조해 통과했다. 검수용 API·DB·네트워크 및 임시 비밀번호/환경 파일을 정리했으며 운영4개 컨테이너와 보호 백업·소스·compose·로그는 보존한다.

## 2026-10-13 Android 0.2.21 / code 6050 — 공개 완료

- APK 대상 `9a51122a73f1d39da6a8be473f72c9bed98ec665`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38363973929), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6050), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6050/rune-nexus.apk). 검수한 build-only 산출물 5개를 **선택 업데이트·최소 지원 코드 6049**로 2026-10-13 08:10:11 UTC(17:10:11 KST)에 공개·최신 지정했다.
- 3링크의 포탑 레벨 조건을 Lv.3, 5링크를 Lv.7로 조정하고 기존 구매 슬롯·저장을 유지한다. 일반 체크포인트의 전용 스레드 처리·슬롯별 기록 순서·필수 동기 저장, 화면 갱신 통합·강화 견적 재사용, 첫 보스 표시 경계 재사용·웨이브 전환의 중복 저장 검증 감소, 모든 배속의 전투 스탯·적 상태 처리 비용 감소를 포함한다. 서버·DB·저장 형식·호환 세대·Android 호스트·엔진·서명 설정 변경은 없다.
- CI의 Python 174개·Godot 네이티브 82개·prepared session/lifecycle 7개(NOT_RUN 0)·계정/AppServices·서명 빌드·Android 패치 디코더·6047/6048/6049 서명 일치와 Python/Kotlin 차등 복원이 통과했다. 별도 검증자는 기존 최종 소스·Metal 화면·저장/전투 독립 근거의 유효 범위를 대조하고, 실제 APK의 compiled 저장·링크/견적·코어/적·화면 갱신·HUD/보상 계약 9개를 실행했다. CI preset 밖의 화면 갱신 통합도 실제 APK에서 71건 통과했다.
- 실제 APK 버전·package·운영 설정·정확 build·기존 서명과 ABI 3종·네이티브 6파일 SHA가 일치한다. 텍스처·기타 에셋 바이트는 6049와 동일하며 imported 씬 63개는 엔진에서 읽은 노드·자원·메시·재질·애니메이션 의미값이 모두 같다. 별도 검증자가 6049 패치의 정확 APK 복원을 독립 확인했다.
- API37 arm64 read-only AVD에서 6049→6050 업데이트·appId/최초 설치 시각·동일 서명을 확인했다. 설치 직후 primary/backup 저장 바이트가 동일하고, 뒤로가기·홈 복귀·강제 재시작 뒤 진행·코어/모듈 스냅샷·설정을 보존했다. 테스트 저장 복사본을 사용했고 원본 AVD와 사용자 저장은 보존했으며 검수 에뮬레이터를 종료했다. 부모도 대표 실제 로그인 제한 화면을 직접 확인했다. **실계정 인증·서버 동기화, Android 본게임 중 일반 비동기 저장, 실기기 본게임·모바일 GPU/지속 성능은 미검증**이다.
- APK **410,787,714 bytes**, SHA-256 `37c8df27d4ad34de6c1b9fb72b4eb9ee8f646fa52a9f68c54d41094bbeab8691`. 6049 대비 **+15,168 bytes(+0.00369%)**로 PCK 증가분과 같다. PCK 182,563,408 bytes·1198항목이며 주로 compiled 스크립트 증가다. 제작 원본 미포함·기존 중복 699,208 bytes 유지·새 중복 0·네이티브 변경 0. 6049→6050 패치는 129,370,343 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치와 최소 지원 6049, 공개 5자산의 크기/GitHub SHA-256·익명 다운로드 바이트가 검수본과 동일함을 확인했다. 상세 CI·패키지·독립 검사·Android 저장/화면·공개 검증 근거는 Git 밖 로컬 `build/release-verification/apk-6050/`에 보관한다.

## 2026-10-13 Android 0.2.20 / code 6049 — 공개 완료

- APK 대상 `a627c4ab9ac674fbfb0b48b415107219813763d0`, [최종 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38322470095), [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6049), [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6049/rune-nexus.apk). 검수한 build-only 산출물 5개를 **필수 업데이트·최소 지원 코드 6049**로 2026-10-13 00:08:44 UTC(09:08:44 KST)에 공개·최신 지정했다.
- [젬 서버 offer와 도전 소유권](../server_authoritative_economy_design.md#젬-보상과-도전-수명주기-호환-세대-9), 무료/리셋권 재선택·선택/10파편 보상과 필수 계정 인증/복구 gate를 호환 세대 9로 반영했다. 강화·연구의 진행 중 전투 반영, 스테이지 시작 코어/모듈 구성 고정, 저장 복원과 구세대 우편 exact 영수증 재시도 수정을 포함한다. 신재화는 초기 0이며 실계정 지급·상점·광고·다이아 대체 결제는 포함하지 않았다. 파편 획득·전투/클리어 보고의 기존 클라이언트 신뢰 경계는 유지한다.
- 최종 CI의 Python174개·Godot 네이티브81개·prepared session/lifecycle7개(NOT_RUN0)·계정/AppServices·서명 빌드·Android 패치 디코더·6046/6047/6048 서명 일치와 Python/Kotlin 차등 복원이 통과했다. 통합 중 구세대 우편 재시도를 저장된 영수증으로 먼저 복구하도록 서버 순서를 보정했다. legacy-transfer fixture와 Godot 검사3개는 실제 미이관/서버 보상 계약으로 보정했고 별도 검증자가 보상 누락·중복 연출·1px 오류 주입의 실패를 확인했다. 배포 확인 도구의 실제 PCK 경로 표기 보정은 `1429cf4c`에 별도로 반영했으며 APK/서버 바이트를 바꾸지 않았다. 관련34개 도구 검사와 입력 부정 조건을 독립 대조했다.
- 별도 검증자가 실제 APK 버전·package·운영 설정·정확 build·서명·ABI3종·네이티브6파일·PCK1192항목을 대조했다. 실제 compiled 계약13개·이전 저장87개와 최종 입력의 Metal UI144개·flip319개·Boot 동작7개, Back/닫기/ESC5개 경계가 통과했다. 기존 imported 씬63개의 엔진 의미값도 동일했다. 부모는 대표 화면을 직접 검토했다. fresh lobby 종료의 미부착 조명/ObjectDB 경고는 실제6048 PCK의 같은 조건에서도 재현한 기존 문제이며 이번 배포에서 수정하지 않았다.
- API37 read-only AVD에서 6048→6049 업데이트·서명/설치 식별자·primary/backup 진행 및 합성 코어/모듈 스냅샷 보존, 로그인 gate·BACK·HOME 복귀·강제 재시작을 확인했다. 저장 차이는 날짜 rollover와 저장 시각뿐이다. 초기 GUI 소실 판독은 PNG13개의 동일 SHA-256과 부모·별도 검증자의 Vision OCR로 오판임을 확인해 철회했다. 원본 AVD와 사용자 저장을 보존하고 검수 에뮬레이터·Godot 프로세스를 정상 종료했다. **실제 Google 로그인·계정 동기화·실기기 본게임·모바일 GPU/지속 성능은 미검증**이다.
- APK **410,772,546 bytes**, SHA-256 `d957cec168a30b12de60a2a6fec792784fe37e305d0b1a2a4f9f24d5da78226d`. 6048 대비 **+114,544 bytes(+0.02789%)**로 PCK 증가분과 같다. PCK182,548,240 bytes·1192항목이며 새 리셋권 아이콘과 compiled 코드/셰이더가 원인이다. 제작 원본 미포함·기존 중복699,208 bytes 유지·새 중복0·네이티브 변경0. 6048→6049 패치는129,359,866 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치와 최소 지원6049, 공개5자산의 크기/GitHub SHA-256·익명 다운로드 바이트가 검수본과 동일함을 확인했다. 상세 CI·패키지·서버·독립 검수·대표 화면은 Git 밖 `~/Library/Application Support/RuneNexus/operations/apk-6049-release-verification/`에 보관한다.

## 2026-10-13 서버·DB — 6049 대상 운영 반영 완료

- API 소스는 `008a9fee838e91da6b38f4396e95bf53bd027732`, 이미지 `rune-nexus-api:008a9fee`, image ID `sha256:08e1eea9eba532c6dc9bcc926098235b222beacdf4a5ef533d07f670a71f05c3`이며 healthy다. APK 대상과의 차이는 회귀 검사3개뿐이고 서버 소스·마이그레이션이 동일함을 독립 대조했다.
- 구 API 쓰기를 정지하고 연결0을 확인한 뒤 보호된 동결 백업을 격리 PostgreSQL18에 복원해 014–016 이관과 기존34개 데이터 테이블·canonical ID/updated_at 보존·신규 리셋권 초기0을 검증했다. 운영 DB를 **13→16**으로 올린 뒤 실제 운영34개 테이블을 검증한 복원본과 완전히 대조하고 새 API를 시작했다. 구·신 API 혼합 쓰기는 허용하지 않았다. 014–016은 forward-only이며 새 쓰기 뒤 구 API 자동 복귀/down을 수행하지 않는다.
- 정확 소스의 Go test/vet, 전체 PostgreSQL18 pgx 통합(skip0)·race와 격리 HTTP15개 계약을 확인했다. 세대9 신규 writer/save·exact replay, 구6/7/8 신규 명령 거절, 구6 completed 우편 영수증 exact 복구와 거절/재시도 시 wallet revision 불변을 확인했다. loopback·공개 HTTPS live/ready200과 무인증 보호14건도 확인했다. 운영 계정 명령·지급·로그인·저장 조작은 하지 않았다.
- 운영 인증키·환경 전체·마운트·포트·네트워크와 DB/Caddy/DuckDNS 컨테이너를 보존했다. **환경 최소 저장 호환 세대4**는 유지하며 서비스에서 신규 writer/save에 세대9를 요구한다. 환경값을9로 올려 기존 completed 영수증 복구를 막지 않았다. 별도 검증자의 실제 운영 image/DB/환경·34개 테이블/HTTP 대조를 마친 뒤 임시 API·DB·테스트 네트워크를 정리했다. 보호 백업·compose·로그는 보존한다.


## 2026-10-12 Android 0.2.19 / code 6048 — 공개 완료

- APK 대상 `a8de9e5733aec268fdcac5105642dce800bb3ff6`, [최종 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38147520470)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6048). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6048/rune-nexus.apk). 공개 시각은 2026-10-11 15:08:25 UTC(2026-10-12 00:08:25 KST). **선택 업데이트·최소 지원 코드 6039**로 검수한 build-only 산출물 5개를 초안에 올린 뒤 그대로 공개·최신 지정했다.
- 기관총 명중의 입체 도탄 불티, 3D 렌더 해상도 50·75·100%와 프레임 제한 30·60, 전투 스텝의 표적 후보 공유·범위 사전 판정·표시 크기 계산 축소와 밝기0 조명 숨김을 포함한다. 연구 선행 조건을 서버·Godot 공용 원본에서 생성하며 서버 판정 변경은 아래와 같이 먼저 반영했다. 폐기된 웹 저장소도 팩에서 제거했다.
- 최초 [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38146890649)는 메뉴 복귀 검사에서 20초 제한을 넘겨 실패했다. 같은 고정 카탈로그를 사례마다 다시 파싱하는 검사 비용을 줄였고 제품 코드는 보존했다. 로컬 본체 약9.5→1.76초, 기존52검사·분기·20초 제한을 유지했다. 별도 검증자가 사례별 App/Host/run/checkpoint·저장 경로 분리와 카탈로그 불변을 확인하고 저장 보존 실패 주입의 exit1을 확인했다. 최종 CI의 Python110개·콘텐츠·Godot 회귀73개·계정/AppServices·서명 빌드·Android 패치 디코더·6045/6046/6047 Python/Kotlin 차등 복원이 통과했다.
- 별도 검증자가 실제 APK의 버전·패키지·정확 build·운영 설정·서명·지원 ABI3종·네이티브6개 SHA·원본JSON·변경 compiled 스크립트·새 셰이더를 대조했다. 이전 에셋815개 중 imported 씬63개만 직렬화 바이트가 달라 실제 이전/최종 PCK를 Godot로 각각 로드해 노드·저장 속성·메시·재질·애니메이션 의미값이 모두 같음을 확인했다. 최종 compiled 연구/5슬롯 계약201검사, 실제 Metal Mobile 렌더러의 도탄30검사, 저장 복사본의 실제 Main/App/HUD 이어하기·전투·메뉴 복귀8검사가 통과했다. 부모도 최종 실제 설정·전투 대표 화면을 직접 검토했다.
- API37 read-only 격리 AVD에서 기존6047→6048 서명 업데이트·설치 식별자·원본 저장 인계, 기본100%/60 및50%/30 설정 저장·강제종료/재시작 유지를 확인했다. 스테이지1-1·웨이브23/40·골드2199·HP4/20·파편34·포탑8을 보존했고, 날짜 변경에 따른 달력 필드·저장시각과 float끝자리 반올림만 달라졌다. SwiftShader 소프트웨어 GPU의 본게임 진입은 기본 MSAA/그림자 및 낮은 설정 단회 시도 모두 `gfxstream vkWaitForFences/vkGetFenceStatus`에서 대기해 **Android 본게임·새 효과는 미확인**이다. 데스크톱 통과로 대체하지 않았다. 실기기 GPU/FPS/발열·터치/수명주기 전체 및 실제 Google 계정 E2E 공백은 [체크리스트](../implementation_checklist.md)에 유지한다.
- APK **410,658,002 bytes**, SHA-256 `d6a79940ea3f4cc8b598c3821283f2f9bde253abafd7699ea1fcf20644ef7fcf`. 6047 대비 **+11,632 bytes(+0.00283%)**로 모두 PCK 증가다. PCK182,433,696 bytes·1179항목이며 새 도탄 스크립트/셰이더와 변경 스크립트·웹 저장소 제거가 주된 변화다. 실제 팩 감사는 CI와 정확히 같고 제작 원본 미포함·기존 챕터2 노멀맵 동일 압축 중복699,208 bytes를 유지한다. 6047→6048 패치는129,242,236 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산5개의 크기/GitHub SHA-256과 검수본 일치, 익명 APK HTTP200을 확인했다. 상세 CI·패키지·서버·독립 검수·대표 캡처는 Git 밖 `~/Library/Application Support/RuneNexus/operations/apk-6048-release-verification/`에 보관한다. 검수 AVD와 데스크톱 실행은 정상 종료했고 원본 AVD와 사용자 저장은 보존했다.

## 2026-10-11 서버 — 6048 대상 운영 반영 완료

- 정확한 `6a2e8f59b3575b0fc6d2d93b57d7a2c0133b6206`의 `git archive` 소스로 `rune-nexus-api:6a2e8f59`를 빌드해 운영 API에 반영했다. 실제 image는 `sha256:8b752506b3ee249f7dd6fa3a450fa74fba6a5ea724ce3dd6ea20919ae890f530`, revision label과 대상 SHA가 일치하며 healthy다.
- 연구 선행 조건을 `progression.json`의 `researchPrerequisites`에서 공용 생성하고, 서버 링크 확장 II 즉시 완료·효과 ACK 판정을 Godot 해금 조건과 맞췄다. 링크 확장 I은 그 자체의 3-5 클리어·grandfather·미이관 저장의 레거시 해금 조건을 충족해야 선행 연구로 인정한다. DB 마이그레이션·저장 형식·호환 세대 변경은 없다.
- 정확 소스의 Go test/vet, 별도 PostgreSQL18 임시 DB의 유지 통합 검사 3개(skip0), 격리 HTTP15건과 공용 선행 조건 8사례의 완료·ACK·거부 시 상태 무변경 64검사가 통과했다. 별도 검증자가 공용 사례의 기대값과 실제 HTTP·거부 전후 상태를 대조했다.
- 기존 운영 환경값·영속 인증키·마운트·포트·네트워크를 보존하고 DB13·최소 저장 호환 세대4를 유지했다. 환경 배열 순서만 달라졌으며 키와 값은 완전히 같다. DB/Caddy/DuckDNS 컨테이너는 유지했고 운영 계정·저장 조작은 없다. 부모와 별도 검증자가 최종 image/revision·healthy, loopback·공개 HTTPS live/ready200 및 무인증 보호를 확인했다.
- 상세 근거는 Git 밖 `~/Library/Application Support/RuneNexus/operations/apk-6048-release-verification/server/`와 `independent/`에 보관한다. 보호된 정확 소스·release/rollback compose를 보존하고 이번 격리 컨테이너·임시 볼륨·네트워크는 제거했다. 실제 Google 로그인·운영 계정의 연구/저장 E2E는 기존 미검증 항목으로 유지한다.

## 2026-10-11 Android 0.2.18 / code 6047 — 공개 완료

- APK 대상 `4a94337cd0c366805a912d79efc295a15986d99d`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38068681133)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6047). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6047/rune-nexus.apk). 공개 시각은 2026-10-10 17:08:25 UTC이며 **선택 업데이트·최소 지원 코드 6039**를 유지했다. 검수한 build-only 산출물 5개를 그대로 공개했다.
- 챕터3 3-6~3-10·다중 경로/포탈과 저장, 3-10 성공 클리어 및 링크 확장 I 완료 후 해금되는 **링크 확장 II(기본 45,000룬·8시간)**를 포함한다. 기존 비용/시간 효율을 적용하고, 연구 완료 뒤 실제 다섯 번째 슬롯은 Lv.5·네 번째 기본 가격의 2배 골드로 구매한다. 서버·DB는 아래 절과 같이 먼저 반영했으며 APK 대상의 추가 커밋은 회귀 검사 한 파일만 바꿔 서버 실행 코드와 일치한다.
- 챕터2·3 타일과 냉각 포탑 메시 경량화, 젬14종 128px 이미지, 보상 숫자 축약/전투 UI, 시작 우편 조회·이벤트/우편 배지, 메뉴 복귀 일시정지와 보상 ACK 이후 적 사망 연출 전달 수정을 포함한다. 실제 게임의 승인 외형·조작 근거는 관련 입력 범위에서 활용했다.
- 최초 [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38068024942)는 연구 선택 검사에서 새 선행 연구 잠금 상태를 기대값에 포함하지 않아 실패했다. 제품 동작을 보존하고 실제 해금/선행 조건으로 검사를 보정했다. 별도 검증자가 단일 사례 통과 및 잘못된 선택 노출·차단 오류 주입의 실패를 확인했다. 최종 CI의 Python110개·Godot 회귀73개·계정/AppServices·서명 빌드·Android 패치 디코더·6044/6045/6046 Python/Kotlin 복원이 통과했다.
- 별도 검증자가 실제 APK의 패키지/버전·운영 설정·최종 build·원본 JSON·변경된 compiled 스크립트, ABI3종·네이티브6개 SHA와 기존 서명 인증서를 대조했다. 실제 PCK를 엔진에서 로드해 냉각 포탑 **11,760삼각형·1024px 압축 맵4개**, 챕터2·3 메시/맵, 젬14종 원본 픽셀 일치를 확인했다. APK에 포함된 compiled 코드의 45,000룬·8시간·ID30/I 선행 조건·세대6, 다섯 슬롯의 금액/Lv.5/서로 다른 젬 스탯·체크포인트 복원·불법 슬롯 거부·구4슬롯 보존193건이 통과했다.
- APK **410,646,370 bytes**, SHA-256 `e28851dab20b33cad0d9f04e7318ffbd51bddc3fa01355652ffcd70c9fc3c686`. 6046 대비 **12,137,476 bytes 감소(-2.8708%)**로 모두 PCK 감소다. PCK182,422,064 bytes·1177항목이며 scene -9,687,889/texture -3,733,698/content +1,253,980/script +32,159 bytes를 포함한다. 제작 원본은 포함하지 않았고 기존 챕터2 노멀맵3개의 동일 압축 결과699,208 bytes 중복만 남는다. 6046→6047 패치는129,235,621 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산5개의 크기/GitHub SHA-256과 검수본 일치, 익명 APK HTTP200을 확인했다. 외장 SSD의 일부 검증 경로 I/O 지연으로 최종 APK·패치·CI·독립 검수·추가 DB 근거는 내장 SSD의 Git 밖 `~/Library/Application Support/RuneNexus/operations/apk-6047-release-verification/`에 보관한다. API37 AVD의 기존 부팅 장애에 변화가 없고 API36 이미지·연결 기기가 없어 최종 Android 설치·본게임·로그인·저장 유지·터치/수명주기·모바일 GPU/지속 성능은 **미검증**이다. 정상 성장으로 챕터3 후반을 연속 플레이한 난이도와 실제 Google 계정 E2E도 [기존 확인 항목](../implementation_checklist.md)에 남는다.

## 2026-10-11 서버·DB — 6047 선행 반영 완료

- 서버 대상 `cfa9e6d82de422ab1e9deccadcdb3bb37df3cf9e`의 정확한 `git archive` 소스로 `rune-nexus-api:cfa9e6d8`를 빌드해 기존 운영 API에 반영했다. 실제 실행 image는 `sha256:0ec474c20437969ca2943236f48ea1d94cb2be6d88754040980fd933fac052a9`이며 revision label과 대상 SHA가 일치한다.
- 운영 DB를 **스키마 12→13**으로 올렸다. 기존 운영 tern 마이그레이터가 `013_chapter_three_routes.sql` 하나만 적용했으며 ID26–30 제약·진행 순위 함수·랭킹 인덱스를 실제 DB에서 확인했다. 기존 진행·계정 기록 삭제나 DB down은 수행하지 않았다. 적용 직전 보호된 custom-format 백업을 확보하고 별도 PostgreSQL18에 복원해 스키마12 복구 가능 여부를 확인했다.
- 기존 영속 인증키·전체 API 환경·secret mount를 보존하고 **최소 저장 호환 세대4**를 유지했다. ID26–30/경로 저장은 선택적으로 세대5, 링크 확장II 연구/5슬롯 저장은 선택적으로 세대6을 요구한다. 기존 6046의 25맵 저장 접근을 유지하며 전체 최소 호환 세대를 올리지 않았다. DB/Caddy/DuckDNS 컨테이너와 네트워크·공유기 설정은 유지했다.
- 같은 최종 image를 별도 복원 DB와 합성 검증 계정에 연결해 HTTP 계약15건을 통과했다. 기존 세대4 writer·저장 허용, ID30 저장의 세대4 차단, 링크II의 세대5 writer/PUT 426, 즉시 완료·멱등 재시도·효과 ACK, 연구 완료·5슬롯 저장/조회 왕복과 구버전 덮어쓰기 차단을 확인했다. 운영 사용자 계정·저장은 조작하지 않았다.
- 추가 P0 검증에서 확정 서버 소스의 유지 DB 통합 검사3개(skip0), 012→013 기존 기록/달성 시각 보존·26–30 랭킹·신규 기록이 있는 down의23514 거부·실패 후 스키마/함수/제약/인덱스/모든 기록 보존4건을 통과했다. 별도 검증자가 원본 Git 바이트와 전후 SQL/JSON·실제 실패 로그를 대조했다. Go1.26.5·PostgreSQL18.4의 별도 임시 DB를 사용한 뒤 삭제했으며 운영 DB·계정은 조작하지 않았다.
- 운영 API는 healthy이며 loopback·공개 HTTPS live/ready 200, 무인증 저장·writer·경제 카탈로그·링크II 완료·랭킹401을 확인했다. 상세 배포·백업 메타·복원·격리 HTTP·운영 DB/health 근거는 로컬 `build/release-verification/apk-6047/server/`에 보관한다. 백업과 영속 private compose는 Git 밖의 보호된 운영 폴더에 유지했고 검증 컨테이너·임시 볼륨·네트워크는 제거했다. 실제 Google 계정 로그인·운영 계정의 연구/저장 동기화는 미검증이다.

## 2026-10-09 Android 0.2.17 / code 6046 — 공개 완료

- APK 대상 `a63ce407374191b0e415b2d8c6e8d23c79899bd6`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37882057710)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6046). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6046/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지하며 검수한 build-only 산출물 5개를 그대로 공개했다.
- 승인 일반 골렘·최적화 탱커·UltraTex 보스 모델과 보행·사망 표시, 젬 장착 VFX, 이동 경로 선과 설치 충격 조정을 포함한다. 스테이지 자원 수명·로딩 안내·타깃 메시 준비·UI/환경 텍스처 메모리·별 배경 조회를 최적화하고, 저장 오류·타깃 처리·고정 전투 시간 간격·지속피해·앱 전환 시간 보정을 반영했다. 서버·API·DB·Android 호스트·운영 설정 변경이나 재배포는 없다.
- 독립 검토에서 최종 탱커 입력·상태 에셋과 실제 Mobile/Metal 게임의 이동·일시정지·12조각 사망·냉각 핵 보호 근거가 일치했고, 최신 전투 시계·지속피해 집중 회귀 2개를 격리 실행해 통과했다. 기존 일반·보스·기타 표현 근거는 관련 입력·공유 의존성 범위에서 활용했다. 부모도 대표 실제 게임 화면을 확인했다. 이는 데스크톱 및 헤드리스 결과이며 최종 Android 실행 검증과 구분한다.
- 최초 [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37881409226)는 젬 보상창 resize 검사에서 약 0.000015px 부동소수점 오차를 완전 일치로 비교해 실패했다. 런타임·기대 좌표는 보존하고 기존 중심 검사와 같은 근사 비교로 수정했다. 별도 검증자가 원본 실패와 수정 후 45개 통과, 중심/배치 각각 1px 오류 주입 시 실패를 확인했다. 최종 CI의 Python 83개·콘텐츠·Godot 회귀 62개·계정/AppServices·서명 빌드·Android 패치 디코더·6043/6044/6045 서명 일치와 Kotlin 차등 복원이 통과했다. 실제 APK의 패키지·버전·운영 설정·대상 build·콘텐츠 JSON·변경 컴파일 스크립트와 탱커 상태 자료 포함을 대조했다. 별도 검증자가 실제 APK의 PCK에서 normal/normal_death/tank/tank_death/boss 5씬을 직접 로드·생성해 삼각형·스킨·클립·공유 맵을 확인했다. 탱커 Walk 49키·Death 61키의 24Hz 원본 키 보존, 상태 자료 9개·관련 셰이더 3개의 원본 일치, 최종 compiled 고정 시계·보폭·사체 수명도 확인했다.
- APK **422,783,846 bytes**, SHA-256 `ff9fd36ae8b84d6fa18ef5c289123a22c6f78822691b54dd63e7f3e609a7bbf7`. 6045 대비 **22,408,364 bytes 감소(-5.0334%)**로 PCK 감소와 일치한다. 텍스처 payload -25,195,642 bytes가 주요 감소 원인이며 새 별 배경 자료 +2,596,638 bytes 등을 반영했다. PCK 194,559,540 bytes·1181항목, 제작 원본 포함 없음, 지원 ABI 3종과 네이티브 라이브러리 크기·CRC 유지. 챕터2 건설칸·측면·길 노멀맵 3개의 512 축소·ASTC 결과가 같아 699,208 bytes의 완전 중복이 남는다. 원본의 최대 1/255 소수 픽셀 차이가 축소 후 사라진 것으로 출처·로드 참조를 확인했으며 잘못된 맵 포함으로 보지 않는다. 6045→6046 패치는 139,948,602 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산 5개의 크기·GitHub SHA-256과 검수본 일치 및 익명 APK HTTP 200을 확인했다. 로컬 산출물과 상세 검증은 외장 SSD의 `build/release-verification/apk-6046/`에 보관한다. 새 격리 Android API37 AVD는 앱 실행 전 `super` 파티션 경로 오류로 커널 재부팅을 반복했고 구성/렌더러 대체에서도 복구되지 않았다. API36 대체 이미지·연결 실기기가 없어 최종 APK 설치·본게임·로그인·저장 유지·터치/수명주기·모바일 GPU/지속 성능은 **미검증**이다. 기존 사용자 저장·계정·AVD는 보존했다.

## 2026-10-07 Android 0.2.16 / code 6045 — 공개 완료

- APK 대상 `d859b80d944f6a9712bbf9c616ebc399381f78c5`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37565375644)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6045). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6045/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지하며 검수한 build-only 산출물 5개를 그대로 공개했다.
- 포탑 모듈 코어·포신·프레임의 등급별 아이콘 12종과 유니크 전용 배경 후광, 빈 모듈 인벤토리의 슬롯 한 줄, 라이트닝 포탑 표시 크기 10% 축소, 설치 시 0.22초·최대 2px 상하 충격을 포함한다. 화상·독 지속피해는 방어구 감쇄를 무시하되 보호막→방어구→체력 순서를 유지하며, 장갑병 처치 보상은 7→8골드다. 서버·DB·운영 설정 변경이나 재배포는 없다.
- 독립 검증자가 승인 원본과 최종 모듈 화면·관련 입력·공유 의존성을 대조하고, 기존 지속피해 독립 89건의 입력 유효성을 확인했다. 실제 App 격리 실행에서 장갑병 보상 6건, 라이트닝 미리보기·설치 90% 크기와 상하 충격·HUD 고정·일시정지/4배속 64건, 빈 인벤토리 320px 12건이 통과했다. 부모도 최종 모듈·빈 인벤토리·전장 화면과 설치 시간축을 직접 확인했다. 추가 실제 실행은 Godot 4.7.2·macOS Apple M4·Metal Forward Mobile의 데스크톱 결과다.
- CI Python 77개·콘텐츠·Godot 네이티브 회귀 57개·계정/AppServices 검사, 서명 빌드·Android 패치 디코더·6042/6043/6044 서명 일치와 Kotlin 차등 복원이 통과했다. 실제 APK의 버전·운영 설정·대상 build, 최종 콘텐츠 JSON과 장갑병 8골드, 모듈 텍스처 13개와 변경된 컴파일 스크립트의 포함도 확인했다.
- APK **445,192,210 bytes**, SHA-256 `6a013a85740b9c0a3f1ea4e0b99b1009d49a90b8d2ff9bc7028a4c04610e25a2`. 6044 대비 **+2,674,056 bytes(+0.6043%)**로 모두 PCK 증가이며 새 모듈 아이콘·후광이 주요 원인이다. PCK 216,967,904 bytes·1177항목·완전 중복 0, 제작 원본 포함 없음. ABI 3종과 네이티브 라이브러리 크기·CRC를 유지한다. 6044→6045 패치는 157,161,555 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산 5개의 크기·GitHub SHA-256과 검수본 일치 및 익명 APK HTTP 200을 확인했다. 다운로드 정체는 받은 바이트를 보존하고 이어받아 복구했으며 전체 아티팩트의 GitHub SHA-256을 대조했다. 로컬 산출물과 검증 자료는 외장 SSD의 `build/release-verification/apk-6045/`에 보관한다. 연결된 Android 기기가 없어 실기기 설치·로그인·저장 유지·터치/수명주기·모바일 GPU/지속 성능은 미검증이다.

## 2026-10-06 Android 0.2.15 / code 6044 — 공개 완료

- APK 대상 `d8f19196c5bd08fe1ef11926036c8e87840ba71d`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37468968196)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6044). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6044/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지하며 검증한 build-only 산출물 5개를 그대로 공개했다.
- 이전에 미배포였던 자동 저장 중복 처리 최적화, 젬 보상 카드·모달 등장 애니메이션, 3종 강화 상한 확장 연구의 비용 10배 조정, 처치 보너스 강화 비용 하향·레벨 구간별 효과 개선, 두 번째 연구 슬롯의 초기 안내, 연구 목록의 청록 테두리·전체 명암 구분을 모두 포함한다. 목록의 시작 가능 문구·체크·룬 부족 표시는 제거했다. 2-10 클리어 전 슬롯 구매 안내는 비활성화하며 기존 600다이아 구매 계약을 유지한다.
- 독립 검증자가 신규/2-10 전후/구매 후의 320px 실제 화면·포인터 구매·재진입을 확인했다. 440px 초기 안내, 카탈로그 320/440, 슬롯 A안, 젬 연출, 자동 저장, 처치 보너스는 현재 입력·소스와 유효성을 대조한 기존 독립 근거를 활용했다. CI 전체 검사·서명 빌드·Android 패치 디코더·6041/6042/6043 서명 일치와 Kotlin 차등 복원이 통과했다. 실제 APK 내부의 3종 연구 첫 비용 1500, 처치 보너스 첫 비용 10·효과 0.03, 젬 연출 컴파일 코드도 확인했다.
- APK **442,518,154 bytes**, SHA-256 `95723e6b65d296b5146be58eea5d7e4c1bfbce4a8b2196767c639517a484a92c`. 6043 대비 **+10,140 bytes(+0.00229%)**로 모두 PCK 증가이며 새 젬 연출 코드가 주요 원인이다. PCK 214,293,848 bytes·1151항목·완전 중복 0, 제작 원본 포함 없음. ABI 3종·네이티브 라이브러리 크기·CRC와 텍스처 용량을 유지한다. 6043→6044 패치는 168,769,507 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산 5개의 크기·GitHub SHA-256과 검수본 일치, 익명 APK HTTP 200을 확인했다. DuckDNS는 실행 중 컨테이너의 `0:0`·healthy·읽기 전용·권한 제한이 이미 반영돼 있어 재시작하지 않았다. API·DB 변경이나 재배포는 없다. 연결된 Android 기기가 없어 실기기 설치·로그인·저장 유지·지속 성능은 미검증이다. 근거는 로컬 `build/release-verification/apk-6044/`에 보관한다.

## 2026-10-06 Android 0.2.14 / code 6043 — 공개 완료

- APK 대상 `993de3fa34ecd86f6c6baff50709657fceac170a`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37448415598)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6043). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6043/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지하며 검증한 build-only 산출물 5개를 그대로 공개했다.
- 연구 중 슬롯에 승인된 A안의 남청 금속 카드·연구 아이콘·금색 진행바와 진행률·남은 시간·청동색 중단 버튼·청록색 즉시 완료와 다이아 비용을 적용했다. 재개한 연구의 경과 시간을 보존하고 초기 진행률을 바로 표시한다. 이전 공개본 이후 main의 골렘 보스 보행·사망, 웨이브 예고와 실제 적 구성 일치, 탱커 사망 계산 정리, 텍스처 압축도 포함한다. 미승인 로컬 변경·기존 미푸시 커밋은 제외했고 서버·DB 재배포는 없다.
- 별도 검증자가 배포 후보의 연구 슬롯·중단·상세·성장 규칙·저장 관련 회귀와 1/2슬롯 각각 320/440 실제 Godot 화면을 확인했다. CI 전체 검사·서명 빌드·Android 패치 디코더·6040/6041/6042 서명 일치와 Kotlin 차등 복원이 통과했다. 첫 CI의 기존 `×` 기대 문구를 승인된 `중단`으로 고친 뒤 해당 검사와 최종 CI를 통과했다.
- APK **442,508,014 bytes**, SHA-256 `e7288a84c4a1d0a5f7aebea0202add6b867649494be07096dd401f17b888816f`. 6042 대비 **+26,888,936 bytes(+6.47%)**이며 거의 전부 PCK 증가다. ASTC 텍스처 +57,324,908 bytes, 기존 기타 텍스처 -34,271,800 bytes, 가져온 장면 +3,259,588 bytes(주로 보스)가 주요 원인이다. PCK 214,283,708 bytes·1149항목·완전 중복 0, 제작 원본 포함 없음. ABI 3종과 네이티브 라이브러리 크기·CRC를 유지하며 6042→6043 패치는 152,849,661 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산 5개의 크기·GitHub SHA-256과 검수본 일치, 익명 APK HTTP 200을 확인했다. 연결된 Android 기기가 없어 실기기 설치·로그인·저장 유지·지속 성능은 미검증이다. 근거는 로컬 `build/release-verification/apk-6043/`에 보관한다.

## 2026-10-04 Android 0.2.13 / code 6042 — 공개 완료

- APK 대상 `74c7d33d37055dc37ff05d5eeec6e6d24227573e`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37169361846)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6042). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6042/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지하며 build-only 산출물 5개를 그대로 공개했다.
- 모듈 뽑기 확인창 공간, 전투 종료·계정 모달, 연구 상세 정보, 결과창 크리스탈 결집 연출, 포탑 설치 충격·3D 먼지·LOD, 설치 포탑·미리보기의 남서쪽 기본 방향, 라이트닝 포탑 모델·입체 연쇄 공격 효과를 포함한다. 미커밋 연구 카드 수정은 제외했다. 서버·DB·운영 설정 변경이나 재배포는 없다.
- 첫 CI는 Godot 준비 테스트의 임시 자산에 새 설치 먼지 파일이 없어 실패했다. 제품 동작은 유지하고 fixture에 GLB·JSON을 추가한 뒤 재실행했다. 최종 CI의 Python 71개·콘텐츠·Godot 네이티브 회귀 54개·계정/AppServices 검사, 서명 빌드·Android 패치 디코더·6039/6040/6041 서명 일치 및 차등 복원이 통과했다.
- APK **415,619,078 bytes**, SHA-256 `c004a09e7efce0c48153438fa58eb0bb02931c0ffa963d11de11be514a591748`. 이전 6041 대비 **+853,872 bytes(+0.2059%)**이며 증가 대부분은 PCK의 라이트닝 모델·공격 메시와 설치 먼지다. PCK 187,394,768 bytes·1129항목·완전 중복 0, 제작 원본 포함 없음. ABI 3종을 유지하며 네이티브 라이브러리의 크기·CRC는 이전 공개본과 같다. 6041→6042 패치는 180,404,610 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산 5개의 크기·GitHub SHA-256과 CI 산출물 일치, 익명 APK 접근 HTTP 200을 확인했다. 사용자 요청에 따라 추가 로컬 기능·화면 검증과 Android 설치·실행을 생략했다. 이번 APK의 실기기 로그인·저장 유지·지속 성능은 미검증이다. 로컬 근거는 `build/release-verification/apk-6042/`에 보관한다.

## 2026-10-02 Android 0.2.12 / code 6041 — 공개 완료

- APK 대상 `7a6065debda844fc1d0a425f87f59529cb85f57d`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36965869424)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6041). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6041/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지한다. build-only 검수본 5개를 그대로 공개했다.
- 냉각타워 감속 스탯 표시 순서, 스테이지 결과창·보상 즉시 정산, 포탑 모듈 화면·작업 버튼 배치, 일일·주간 임무 완료 집계의 출석 포함을 반영했다. 탱커의 승인 모델·걷기·사망·화상/냉각 효과·머리 위 체력바도 함께 커밋·배포했다. 제작 원본과 필요한 입력은 보존하고 중복 GLB export·임시 검증 산출물은 추적에서 제외했다.
- API는 정확한 서버 소스 `2923497c426087963ab2b20632c8833e1f8bd39b`의 `rune-nexus-api:2923497c` 이미지로 반영했다. APK 대상과 서버 소스는 동일하다. 운영 환경·secret·포트·DB/Caddy/DuckDNS를 보존하고 **DB 스키마 12·최소 저장 호환 세대 4**를 유지했다. Go 테스트 292개·vet·출석 집계의 격리 DB 13사례와 새 운영 백업의 격리 복원을 통과했다. 실제 이미지·설정 보존과 공개 live/ready 200·무인증 경제/우편함/랭킹 401을 별도 검증자가 확인했다. migration·운영 계정 조작은 없다.
- CI의 Python 71개·콘텐츠·Godot 네이티브 회귀·계정/AppServices 검사, 서명 빌드·Android 패치 디코더와 6038/6039/6040 차등 복원을 통과했다. 별도 검증자가 최종 입력에 대응하는 기존 실제 화면·독립 근거를 대조하고 결과 정산·임무·모듈 관련 회귀를 실행했다. 최종 APK의 버전·운영 설정·대상 빌드·기존 정식 인증서·필수 탱커 리소스·패치 무결성도 독립 확인했다.
- 격리 Android API 37 arm64 AVD의 host GPU에서 정식 6040→6041 덮어 설치·최초 설치 시각 유지·로비·이어하기·Home 복귀·일시정지 터치 맵 이동을 확인했다. 스테이지 1·웨이브 23/40·HP 4/20·골드 2199·젬 조각 34·포탑 8개와 런·모듈·설정·진행 필드가 유지됐다. 별도 저장 복사본의 본게임에서 탱커 기본/화상/냉각 보행·체력바·포탑 피격·코어 빔과 사망 직후 HP/상태 제거·정지/재개·붕괴·잔해 소멸을 확인했다. 부모도 최종 실제 화면·시간축을 직접 대조했다. 초기화 중 입력이 무시된 로비 녹화와 일시정지 구간은 붕괴 완료 근거에서 제외하고 실제 재개 영상을 확인했다. AVD 원본은 보존했다.
- APK **414,765,206 bytes**, SHA-256 `8e47d060f265d193bff6dbf6eef8451dec78b959c6e911a805f280482006c1ff`. 이전 6040 대비 **+13,134,588 bytes(+3.2703%)**로 PCK 증가분과 같다. PCK 186,540,900 bytes·1097항목·완전 중복 0이며 탱커 atlas·skinned 모델/상태 리소스와 결과창 이미지가 주요 증가 원인이다. ABI 3종·네이티브 라이브러리 6개의 바이트는 동일하며 제작 원본·시안·중복 원본 GLB는 APK에 포함하지 않았다.
- 공개 태그의 대상 SHA, latest/버전별 manifest 바이트 일치, 공개 자산 5개의 크기·GitHub SHA-256과 검수본 일치 및 익명 APK 접근 HTTP 200을 확인했다. 실제 기기 Google 로그인·실계정 동기화/보상 수령·설치 권한 흐름·실기기 지속 성능은 미검증이며 에뮬레이터 결과로 대체하지 않는다. 상세 근거는 로컬 `build/release-verification/apk-6041/`에 보관한다.

## 2026-10-02 Android 0.2.11 / code 6040 — 공개 완료

- APK 대상 `2b1f68fb57c41bbd603af42c05ae9b1ed9044c42`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36895240820)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6040). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6040/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지한다. build-only 검수본 5개를 그대로 공개했으며 미커밋 변경은 포함하지 않았다.
- 젬 장착·교체 모달의 잠긴 슬롯 추가 선택과 골드 아이콘, 모듈 뽑기 확인창·한글 가독성, 일시정지 중 맵 조작·포탑 선택/설치, 런 전환·보상 정산·저장 읽기·보스 상태효과 수정, 반복 계산·저장/효과 비용 개선과 우편함 분리를 포함한다. 기존 최종 UI·저장·전투 검증 근거의 관련 소스 일치를 확인하고 저장 계약 회귀를 독립 실행했다.
- API는 커밋 `3c1802ef8f12541eb4c5e030a00f1c38cd125ee7`의 정확한 서버 소스로 만든 `rune-nexus-api:3c1802ef` 이미지로 반영했다. APK 대상과의 차이는 검사 파일 1개뿐이다. 운영 환경·secret mount·DB/Caddy/DuckDNS를 보존하고 **DB 스키마 12·최소 저장 호환 세대 4**를 유지했다. migration 변경·운영 계정 조작은 없다. 보호된 DB 백업을 확보했으며 Go 테스트·vet·관련 격리 DB 통합 검사와 공개 live/ready 200·무인증 경제/우편함/랭킹 401을 확인했다. 별도 검증자가 실제 이미지와 운영 설정·공개 응답을 독립 확인했다.
- CI의 Python·콘텐츠·Godot 네이티브 회귀·계정/AppServices 검사, 서명 빌드·Android 패치 디코더 및 6037/6038/6039 차등 복원을 통과했다. 첫 실행에서 모듈 뽑기 확인창의 이전 문구를 찾던 AppServices 검사가 실패해, 승인된 분리 비용 표시의 실제 값으로 검사만 수정한 뒤 재실행했다. 게임 동작은 바꾸지 않았다.
- 격리 Android API 37 arm64 AVD의 host GPU에서 정식 6039→6040 덮어 설치와 최초 설치 시각 유지, 로비·이어하기·시스템 Home 복귀·복원된 일시정지 상태의 터치 맵 이동/포탑 선택을 확인했다. 스테이지 1·웨이브 23/40·HP 4/20·골드 2199·젬 조각 34·포탑 8개와 런·모듈·설정·진행 필드가 유지됐다. 초기 소프트웨어 GPU 환경의 이전 버전 로딩 지연은 host GPU 설정으로 복구했다. 실제 기기 Google 로그인·계정 동기화·설치 권한 흐름·실기기 성능은 미검증이며 에뮬레이터 결과로 대체하지 않는다.
- APK **401,630,618 bytes**, SHA-256 `4609781bad5d0a024c1b64cf9fd997fd49f2f9a2339a951e32a95b22679ed0f1`. 이전 6039 대비 **+26,036 bytes(+0.00648%)**로 PCK 증가분과 같다. PCK 173,406,312 bytes·1066항목·완전 중복0이며 새 스크립트와 분리한 UI/런 전환 helper가 증가 원인이다. ABI 3종·네이티브 라이브러리 6개의 바이트와 에셋 바이트는 동일하고 제작 원본·시안은 포함하지 않았다. 기존 정식 인증서와 동일한 서명을 확인했다.
- 공개 태그의 대상 SHA, latest/버전별 manifest 바이트 일치, 공개 자산 5개의 크기·GitHub SHA-256과 검수본 일치 및 익명 APK 다운로드 HTTP 200을 확인했다. 상세 CI·서버·APK 감사·Android 저장/화면·독립 검증 근거는 로컬 `build/release-verification/apk-6040/`에 보관한다.

## 2026-10-01 Android 0.2.10 / code 6039 — 공개 완료

- 대상 `dff8cd37ca56bc9995e7504c26b07f2c0998bd6f`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36803498647)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6039). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6039/rune-nexus.apk). **필수 업데이트·최소 지원 코드 6039**로 공개했다.
- 스테이지 룬 보상을 고정 ID 대신 전체 진행 순서로 계산해 챕터 전환에서도 증가하도록 통일했다. 긴 스테이지 목록은 터치·휠 스크롤이 가능하며 스크롤바를 숨겼다. 서버·DB 변경은 없으며 이전 배포의 DB 스키마 12·최소 저장 호환 세대 4를 유지한다.
- 사용자 요청에 따라 추가 로컬 검증·Android 설치·실행·검수를 생략했다. 커밋 전 확보한 관련 Godot 실행·룬 보상 및 목록 스크롤 독립 검증 근거를 재사용했다. CI에 포함된 자동 검사·서명 빌드·패치 디코더·6036/6037/6038 차등 복원은 통과했다. 이번 배포의 Android 동작·실기기 성능은 미검증이다.
- APK **401,604,582 bytes**, SHA-256 `53ef24b5c6446cb0e3acb26510dd9a02125cac91d7dce9fbfbdb036cec0ea052`. 이전 6038 대비 **+56 bytes**다. CI 감사의 PCK는 173,380,276 bytes·1052항목·완전 중복0으로 이전보다 48 bytes 증가했으며 새 에셋·네이티브 의존성은 없다.
- 공개 태그·대상 커밋, latest/버전별 manifest 바이트 일치, 최소 지원 코드 6039, 공개 APK·패치의 크기·GitHub SHA-256과 manifest 일치 및 익명 APK 다운로드 HTTP 200을 확인했다. 로컬 근거는 `build/release-verification/apk-6039/`에 보관한다.

## 2026-10-01 Android 0.2.9 / code 6038 — 공개 완료

- 대상 `0d9a8cc215e6e9859ba41b33671676255f7dad67`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36795400076)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6038). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6038/rune-nexus.apk). **필수 업데이트·최소 지원 코드 6038**로 공개했다.
- 모듈 뽑기 결과에 아이콘과 효과 요약을 표시하고 긴 효과·좁은 화면의 스크롤과 아이콘 모서리 배경을 개선했다. 이번 공개에는 고정 ID 1~25 확장 스테이지·성장 해금·SWIFT 저격 포탑·전투 효과·퀘스트 보상과 저장 처리 개선도 포함한다. 별도 모듈 아이콘 아트는 추가하지 않았고 기존 표시와 향후 에셋 연결 방식을 유지한다.
- API는 런타임 소스 `97daa37a8fcac64caaf574e3a56a1cda51e46e73`의 `rune-nexus-api:97daa37a` 이미지로 반영했다. DB는 `11→12`로 이관해 스테이지 1~25와 논리 진행 순서의 랭킹을 지원한다. 운영 환경·secret 읽기 권한·DB/Caddy/DuckDNS를 보존했다. 새 APK 공개를 확인한 뒤 **최소 저장 호환 세대 4**로 전환했다. 공개 HTTPS live/ready 200과 무인증 API 401을 확인했다.
- 운영 DB를 보호된 위치에 백업하고 격리 복원·012 적용·신규 스테이지 기록이 있을 때 down 거부를 확인했다. 기존 29개 데이터 테이블의 행·ID·달성 시각 지문은 이관 전후 동일하다. Go 테스트 216개·vet·관련 DB 통합 7개를 통과했으며 실계정 데이터·보상 지급은 조작하지 않았다.
- CI 자동 검사·서명 빌드·패치 디코더·6035/6036/6037 차등 복원을 통과했다. 첫 CI의 기존 모듈 제목 검사 불일치는 새 표시 기준으로 수정해 재검증했다. 승인 시안과 모서리 수정의 Godot 실제 화면·관련 회귀 근거는 최종 UI와 일치하며 독립 검증을 통과했다.
- 격리한 읽기 전용 Android API 37 에뮬레이터에서 공개 6037→6038 업데이트 설치·로비·이어하기를 확인했다. 스테이지 1·웨이브 23/40·HP 4/20·골드 2199·젬 조각 34·포탑 8개와 기존 런·모듈·설정·진행 필드가 유지됐고 새 진행 권한 필드만 정상 이관됐다. 실제 기기 Google 로그인·실계정 동기화·전체 25스테이지 플레이·모바일 성능은 이번 검증 범위에 포함하지 않았다.
- APK **401,604,526 bytes**, SHA-256 `75e2f5f6b94dce64836d5be17242308dfc69891a9cb4a800c78c7e4de4082565`. 이전 6037 대비 **+17,339,640 bytes(4.51%)**로 PCK 증가분과 같으며 확장 스테이지 에셋이 주원인이다. PCK 173,380,228 bytes·1052항목·완전 중복0. ABI 3종·네이티브 라이브러리 6개의 바이트가 동일하고 제작 원본·시안은 포함하지 않았다.
- 공개 태그 커밋, latest/버전별 manifest 바이트 일치, 공개 5개 파일의 크기·GitHub SHA-256과 검증 산출물 일치 및 익명 APK 다운로드 응답을 확인했다. 상세 로그·감사·저장 전후·화면 근거는 로컬 `build/release-verification/apk-6038/`에, DB 백업은 별도의 보호된 운영 보관 폴더에 유지한다.

## 2026-09-29 Android 0.2.8 / code 6037 — 공개 완료

- 대상 `d4955ab0f1434f5402d73db9746fc150ff0c8773`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36491118299)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6037). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6037/rune-nexus.apk). 선택 업데이트·최소 지원 코드 6027을 유지한다.
- 이어하기를 일시정지 상태로 열고, 누적 피해를 포탑 속성 태그 오른쪽으로 옮겨 확보한 높이를 스탯 영역에 배분했다. 공격 목표는 젬 링크 옆의 간결한 공격 아이콘으로 표시한다. 서버·DB 변경은 없다.
- 사용자 요청에 따라 최종 소스와 일치하는 기존 Godot 실행·관련 회귀·독립 검증을 재사용하고 배포 필수 검사만 수행했다. CI 자동 검사·서명 빌드·패치 디코더·6034/6035/6036 차등 복원은 통과했다. Android 설치·실행과 실기기 성능 검증은 반복하지 않았으며 이번 배포의 성능 통과로 해석하지 않는다.
- APK **384,264,886 bytes**, SHA-256 `ff231738674779a6a4b1843b7b9d5ecb9ba03764ec7bc7b06fbdb6145d6d22e3`. 이전 6036 대비 **+1,152 bytes**이며 PCK 증가분과 일치한다. PCK 156,040,588 bytes·959항목·완전 중복0. 스크립트 변경에 따른 증가이며 새 대용량 에셋·네이티브 의존성은 없다.
- 공개 태그 커밋, latest/버전별 manifest 바이트 일치, APK·패치의 공개 크기·GitHub SHA-256과 manifest 일치 및 익명 다운로드 응답을 확인했다. 로컬 근거: `build/release-verification/apk-6037/`.

## 2026-09-29 Android 0.2.7 / code 6036 — 공개 완료

- 대상 `b2ca12bc5c259ce1c2e4a82f5b8b108cca0a7083`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36448316225)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6036). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6036/rune-nexus.apk). 선택 업데이트·최소 지원 코드 6027을 유지한다.
- 첫 전투 효과 사전 준비, 일반 앱 복귀 시 현재 화면 유지, 연속 강화, 작은 포탑 스탯창, 특성·젬 보상 선택 시 레이아웃 안정화, 지속 고통 젬의 지속피해 증폭과 설명 수정을 포함했다. 서버·DB 변경은 없다.
- 사용자 요청으로 Android 설치·실행 검증과 추가 로컬 검사를 생략하고 직접 공개했다. 기존 변경별 데스크톱 실행·독립 검증 근거를 유지하며, 배포 CI의 자동 검사·서명 빌드·패치 디코더·6033/6034/6035 차등 복원은 통과했다. Android 수명주기·실기기 성능은 이번 배포에서 미검증이다.
- APK **384,263,734 bytes**, SHA-256 `2e6dd8a2d023b2e4f99090beeedbaa8574ef530da8e95f2cad57a336ad4dcaa4`. 이전 6035 대비 **+6,908 bytes**이며 PCK 증가분과 일치한다. PCK 156,039,436 bytes·959항목·완전 중복0. 효과 준비 등 스크립트 변경에 따른 증가이며 새 대용량 에셋·네이티브 의존성은 없다.
- 공개 태그의 커밋, latest/버전별 manifest 일치, APK·패치의 공개 크기·GitHub SHA-256과 manifest 일치를 확인했다. 로컬 근거: `build/release-verification/apk-6036/`.

## 2026-09-28 Android 0.2.6 / code 6035 — 공개 완료

- main 대상 `ee52e295a4fc412a3e27f302d0babcfa84de8160`을 푸시하고 [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36434707449)의 build-only 검사·서명·최근 3개 버전 패치 복원을 통과했다. 동일 산출물 5개를 [apk-6035 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6035)로 공개하고 최신 릴리스로 지정했다. [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6035/rune-nexus.apk). 선택 업데이트·최소 지원 코드 6027을 유지한다.
- 일반형/빠른형 몹·사망 모션, 우주 배경·드론 시점, 우편함·젬 수정, 전투 HUD·포탑 강화·저장/복원 최적화를 포함한다. 서버·DB·Android 호스트 변경은 없다. 기존 미커밋 문서·산출물 정리는 포함하지 않았다.
- 격리 API 37 arm64 AVD에서 정식 6031→6035 덮어 설치와 최초 설치 시각 유지, 스테이지1·웨이브2·골드148·HP17/20·젬1·기관총 복원을 확인했다. 가디언·피해/빔·배경·HUD와 게스트 우편함 안내를 확인했고 별도 Astra가 대표 화면·기존 변경 근거·패키징을 검토했다. 실계정 Google 로그인·우편 목록·실기기 성능은 미검증이다.
- APK **384,256,826 bytes**, SHA-256 `2565988bc8aa17f35849a18ed112a6020c42a8d083b47beab6f3677786a32577`. 6034 대비 **+17,307,228 bytes(+4.7165%)**이며 증가분은 PCK와 일치한다. PCK 156,032,528 bytes·957항목·완전중복0. 몹 텍스처·메시·상태 효과와 배경이 주원인이며 ABI 3종·네이티브 크기는 유지했다.
- 검수 에뮬레이터의 렉 증가 제보를 조사한 뒤, 사용자의 명시적인 배포 지시에 따라 공개했다. 해당 AVD는 Vulkan `llvmpipe` 소프트웨어 렌더링이며 CPU 약804%를 관측했다. 이전6034 약5.356FPS, 새6035 약4.168FPS를 SurfaceFlinger에서 관측했으나 전투 진행·카메라 상태가 달라 유효한 전후 비교가 아니다. 성능 회귀 여부는 미확인이고 에뮬레이터를 종료했다. 이를 실기기 성능 또는 성능 PASS로 해석하지 않는다.
- 근거는 로컬 `build/release-verification/apk-6035/`의 CI·APK 감사·해시 검사·Android 캡처와 `review/`, `performance/`에 있다. 공개 후 태그 SHA, latest/버전별 manifest와 검수 파일의 일치, 자산 5개 크기·SHA-256·익명 다운로드 응답을 확인했다(`public-verification.json`).

## 2026-09-26 경량화·전투 최적화 Android 0.2.5 / code 6034 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6034) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6034/rune-nexus.apk). 대상 `9d8d454d7167bbd8bdd6d5f3a80fbfb04a375800`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36229160750). build-only 서명 산출물을 검수한 뒤 같은 파일을 공개했다. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 서버·DB·웹 변경은 없다.
- 화염·냉각 타워와 챕터3 파이프·배기구 경량화, 전투 충돌 후보/반복 처리와 HUD 갱신 최적화, 전장 표시 책임 분리, 젬 위성·리본·색광, 로비 버튼 및 업데이트 진행·캐시 개선을 포함했다. 제작 중인 저격 SWIFT와 요청 밖 미커밋 변경은 포함하지 않았다.
- CI의 Python·콘텐츠·Godot 네이티브·계정/AppServices 검사와 서명 APK 빌드, Android 패치 디코더, 6031/6032/6033 서명 일치·차등 복원을 통과했다. 최종 게임 모델의 동일 조건 QHD 외형과 충전·방출/벽 접합은 기존 최종 검수를 재사용했다. 별도 Astra가 변경 범위·최신 업데이트 진행 Android 근거·최종 APK 패키징·Android 대표 화면을 검수했다.
- API 37 arm64 테스트 AVD에서 정식 6033 → 6034 덮어 설치와 최초 설치 시각 유지, 스테이지1·2/40 이어하기, 기존 골드148·HP17/20·젬1·기관총 복원을 확인했다. 실제 전투의 적 이동·피해·코어 빔과 일시정지 상태를 확인했다. 실제 Google 계정 로그인과 실기기 성능은 측정하지 않았다.
- APK **366,949,598 bytes**, SHA-256 `b5f716a4b3ed143b65f9547f5f4a6e7171f39143b02a1ee9342160df4745c64c`. 6033보다 **5,389,820 bytes 감소(-1.4476%)**했다. PCK 138,725,300 bytes·910항목·완전 중복0이며 ABI3종과 네이티브 라이브러리 크기를 유지했다. 감소의 주원인은 chapter3_props·magic·frost의 런타임 메시이고, 새 스크립트·젬/UI 효과를 함께 포함한 최종 크기다. design 편집 원본은 포함하지 않았다. 패치는 6031 기준136,783,101 bytes, 6032 기준136,783,111 bytes, 6033 기준136,783,115 bytes다.
- 근거: `build/release-verification/apk-6034/`의 `ci-run.json`, `ci.log`, `artifact-verification.json`, `packaging-review.json`, `ci-audit/godot-pack-audit.json`, `review/`, `public-verification.json`. 공개 태그 커밋과 latest/버전별 manifest, 자산5개의 GitHub SHA-256·크기 및 익명 다운로드 응답을 대조했다. 공개 후 전체 파일을 다시 내려받는 대신 로컬 검수 파일과 GitHub 업로드 digest를 대조했다.

## 2026-09-26 UI 개선 Android 0.2.4 / code 6033 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6033) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6033/rune-nexus.apk). 대상 `777f24be0e56c9c15cc4ee6ff75444f06d2ee7b5`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36148566717). CI의 build-only 서명 산출물을 검수한 뒤 동일 파일을 공개했다. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 서버·DB·웹 변경은 없다.
- 미배포 UI 개선을 포함했다: 강화 레벨업·룬 비용 프레임, 빨강 쌍검/금색 저울 아이콘, 제목 왼쪽 정렬과 작은 로비 버튼, 연구 스크롤·결제·중단 확인, 모듈 분해·개수 표시·연결부, 리더보드와 고정 내 순위, 모달 겹침·퇴장 중 배경 입력·크기 변동 및 앱 포커스 복귀 안정화. 최종 UI 변경은 `428f19dc`와 `777f24be`에 커밋했다. 로컬 과거 캡처 삭제·임시 생성 파일은 배포 대상에서 제외했다.
- Python 40개, Godot 네이티브 31개, 콘텐츠·계정·AppServices 검사, Android 패치 디코더, 6030/6031/6032 서명 일치와 차등 복원을 CI에서 통과했다. 별도 Astra가 현재 코드·기존 데스크톱 근거·최종 Android 대표 화면을 확인했다.
- Android API 37 읽기 전용 테스트 AVD에서 기존 정식 6031 → 6033 업데이트 설치를 완료하고 최초 설치 시각과 스테이지 1·2/40 라운드 저장 표시가 유지됨을 확인했다. 강화 전투/경제·연구·모듈 및 설정 화면을 확인했다. 설정 백그라운드 복귀는 검수 입력·캡처가 불확실해 성공으로 판정하지 않았고, 사용자의 추가 검수 중단 요청에 따라 재검사와 기존 런 재개 추가 검사를 중단했다. 실계정 Google 로그인·실기기 성능은 검증하지 않았다.
- APK 372,339,418 bytes, SHA-256 `91d0715ceec019e8e22b810c8b46081d65482a5a988064bb2befc2cf83587063`. 6032 대비 +222,016 bytes(+0.0597%)이며 실질 증가는 Godot PCK의 UI 텍스처·스크립트다. PCK 144,131,504 bytes·889항목·완전 중복 0 bytes. ABI 3종과 각 네이티브 라이브러리 크기를 유지하며 design 제작 원본은 포함하지 않았다. 차등 패치는 6030 기준 141,936,628 bytes, 6031 기준 123,083,548 bytes, 6032 기준 123,083,559 bytes다.
- 근거: `build/release-verification/apk-6033/`의 `ci-run.json`, `ci.log`, `artifact-verification.json`, `packaging-review.json`, `ci-audit/godot-pack-audit.json`, `android/`, `public-verification.json`. 공개 태그의 커밋과 latest/버전별 manifest, 업로드 5개 파일의 GitHub SHA-256·크기 및 익명 다운로드 응답을 대조했다. 검수 후 공개 파일 전체를 다시 내려받지는 않았으며 서버가 계산한 업로드 digest와 로컬 검수 파일의 hash를 비교했다.

## 2026-09-24 Google 로그인 저장소 연결 수정 Android 0.2.3 / code 6032 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6032) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6032/rune-nexus.apk). 대상 `104e191fbd47378389d3ae8962834167282bceb9`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36013367828) 검사·서명·최근 3개 버전 차등 복원·공개 완료. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 웹·API·DB 변경은 없다.
- 실제 Android에서 JNI 플러그인의 호출 가능한 메서드도 `has_method()`가 false를 반환하는 것을 재현했다. 계정 서비스가 이를 저장소 부재로 잘못 판단해 Google 인증 HTTP 요청 전에 중단한 것이 이번 로그인 실패 원인이다. 등록된 정확한 네이티브 singleton에는 해당 판정을 적용하지 않도록 수정했고, 같은 판정을 사용하던 기존 저장 경로 연결도 고쳤다. 일반 객체의 메서드 검사와 저장 형식·암호화·시작 화면·업데이트 흐름은 유지한다.
- 동일 Godot 엔진·실제 네이티브 플러그인의 격리 Android 실행에서 수정 전 `SECURE_STORAGE_UNAVAILABLE` → 수정 후 시험용 잘못된 토큰의 서버 HTTP 401 `GOOGLE_AUTH_REJECTED`를 확인했다. 합성 성공 응답의 암호화 저장·새 세션 복원·시험 레코드 삭제도 통과했다. 실제 사용자 계정·저장은 건드리지 않았다. 별도 Astra가 저장소 경계 9개, 계정·AppServices 회귀, 로그인 복귀 13개 시나리오와 Android 근거를 검토했다. 실계정 Google OAuth·서버 저장 동기화는 직접 수행하지 않았으며 사용자 확인 항목으로 남긴다.
- APK 372,117,402 bytes, SHA-256 `eb5e1049026bec7ff6360aa926fe31ff4676f73f1218eeb87453a004715ef92b`. 6031 대비 +260 bytes이며 PCK는 +256 bytes(143,909,484 bytes·877항목·완전 중복 0 bytes)다. 서비스 스크립트 수정에 따른 소폭 증가이며 새 에셋·네이티브 의존성 없이 ABI 3종을 유지한다. 6029/6030/6031 기준 차등 패치는 각각 141,721,287 / 141,721,288 / 49,482,800 bytes이며 CI에서 서명 APK로 복원 검증했다.
- 공개 태그·소스 커밋·최신/버전별 manifest 일치, 업로드 5개 파일의 GitHub SHA-256·크기와 공개 APK 응답을 확인했다. 근거는 `build/login-rootcause-20260924/`의 `root-cause-verification.json`, `android-probe-reflection-logcat.txt`, `android-probe-final-logcat.txt`, `android-probe-final-source-sha256.json`, 독립 검증 로그와 `build/release-verification/apk-6032/`의 `ci-run.json`, `public-verification.json`, `ci-audit/`에 있다. 앞선 6030의 복귀 UI 수정과 별개인 네이티브 저장소 결함을 이번에 실제 Android에서 확인·수정했다.

## 2026-09-24 시작 화면 복원 Android 0.2.2 / code 6031 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6031) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6031/rune-nexus.apk). 대상 `cb9a4b18cade64d7bb9e1369dbcda1e6fa6da8a5`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36006933404)의 서명 산출물을 Android에서 확인한 뒤 동일 파일을 공개했다. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 웹·API·DB 변경은 없다.
- Godot 기본 로고를 숨기고 기존 Flutter의 배경·로고·코어·금속 진행바를 사용하는 시작 화면을 복원했다. 경량 boot가 먼저 업데이트를 확인하고, 통과 후 본게임을 불러와 저장·계정을 복원한다. 필수/선택 업데이트, 오류 재시도, 노트 스크롤, 설치 권한 복귀 안내와 기존 로그인 복귀 처리를 유지한다.
- 관련 자동 검사·실제 데스크톱 시작 전환·독립 검토 및 최종 CI를 통과했다. 격리 Android API 37 에뮬레이터에서 기존 6029 위에 설치하고 Godot 로고 없음 → 업데이트 확인 → 게임 준비 → 로비와 기존 스테이지 1·2/40 이어하기 표시를 확인했다. SwiftShader Vulkan 환경에서 초기 준비 지연이 있었으나 정상 로비에 도달했다. 정확한 GPU 비용과 실기기 시작 성능은 미측정이며 실제 Google OAuth는 사용자 담당 미확인 항목으로 유지한다.
- APK 372,117,142 bytes, SHA-256 `538690028c9b1d7f8f7a9abf58f47fada411661782df8679b36cf2de910edb7d`. 6030 대비 +18,788 bytes이며 Godot PCK도 같은 크기만큼 증가했다(143,909,228 bytes·877항목·완전 중복 0 bytes). 시작 화면 코드 추가에 따른 증가이며 새 대용량 에셋·네이티브 의존성 없이 ABI 3종을 유지한다. 6028/6029/6030 기준 차등 패치는 각각 141,925,573 / 141,721,235 / 141,721,234 bytes이며 모두 서명 APK로 복원 검증했다.
- 공개 태그·커밋·최신/버전별 manifest 일치, 업로드 5개 파일의 SHA-256·크기와 공개 APK 응답을 확인했다. 근거는 `build/startup-restoration-20260924/independent-startup-review.json`, 같은 폴더의 로그·실제 화면과 `build/release-verification/apk-6031/`의 `ci-run.json`, `candidate-verification.json`, `public-verification.json`, `android/cold-start.mp4`, `android/lobby-final.png`, `android/result.json`에 있다.

## 2026-09-24 Google 로그인 복귀 수정 Android 0.2.1 / code 6030 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6030) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6030/rune-nexus.apk). 대상 `7292d952ac8b0ba0df0fdb0165c987d50fe76ecf`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36003482740) 검사·서명·최근 3개 버전 차등 복원·공개 완료. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 웹·API·DB 변경은 없다.
- 사용자 제보의 Google 계정 선택→앱 복귀→업데이트 창→로그인 결과가 사라지는 흐름을 실제 Godot 로비·서비스·수명주기 코드에서 재현했다. 로그인 중 실제 일시정지 후 복귀를 구분해 자동 업데이트 확인과의 충돌을 막고, 게스트 계정 화면을 다시 열어도 취소·실패 안내가 남도록 했다. 일반 복귀 확인과 서버 426 필수 업데이트는 유지한다. Android Google 인증 코드·설정·저장 형식은 변경하지 않았다.
- 콜백과 복귀의 양순서, 성공·닉네임 대기·취소·인증 실패, 일시정지 없는 콜백, 비로그인 작업 중 복귀, 필수 업데이트 등 관련 13개 시나리오와 독립 검토를 통과했다. 배포 CI도 통과했다. 사용자의 실제 Google 인증 실패 원인 및 실계정 OAuth 성공은 미확인이다. 이번 확인은 재현된 복귀 충돌·결과 누락 수정에 한정하며 실계정 성공으로 표시하지 않는다.
- APK 372,098,354 bytes, SHA-256 `8c7d835df163025b04ef6b64dc6c7e2396db9884519e97f2fc78416a42888dd4`. 6029 대비 +656 bytes이며 Godot PCK도 +656 bytes(143,890,440 bytes·871항목·완전 중복 0 bytes)다. APK 지원 ABI·네이티브 의존성·에셋 구성은 기존 배포와 같다.
- 공개 태그·커밋·latest/버전별 manifest 일치, APK와 패치 3개의 GitHub SHA-256·크기, 공개 APK 응답을 확인했다. 검증을 반복하지 않고 기존 서명·패키징·저장 근거와 최종 CI를 재사용했다. 근거는 `build/google-login-fix-20260924/`의 `login-resume-before.log`, `login-resume-after.log`, `independent-login-review.json`과 `build/release-verification/apk-6030/`의 `ci-run.json`, `public-verification.json`, `ci-audit/`에 있다.

## 2026-09-24 Godot 단독 Android 0.2.0 / code 6029 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6029) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6029/rune-nexus.apk). 대상 `1f2bcc27cf877c0727dadd99632db713eb3ec519`, [최종 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/35999656150) 성공. CI에서 검증한 동일 서명 산출물을 초안에 올린 뒤 공개·최신 지정했다. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 웹·API·DB는 배포하지 않았다.
- Flutter·Flame 실행 경로를 제거한 Godot 단독 앱이다. 기존 패키지·서명·저장 형식과 계정 보관 경로를 유지한다. 운영 API·Google client ID·업데이트 URL·빌드 식별자를 최종 APK에서 확인했다. 구현 상태는 [전환 상태](../godot_unified_app_roadmap.md)를 따른다.
- 자동 검사·독립 검토·서명 일치·최근 3개 공개 APK의 차등 복원 검사를 통과했다. 배포 검사에서 발견한 Linux int64 변환 차이, GitHub 리다이렉트 처리, 업데이트 완료 후 대기 팝업 잔류를 수정하고 해당 조건으로 재확인했다.
- 격리 Android API 37 에뮬레이터에서 기존 공개 6028의 게스트 저장을 업데이트 설치로 인계했다. 스테이지 1·웨이브 2/40·HP 17/20·골드 148·젬 조각 1·기관총 1개가 유지됐고, 새 앱의 저장→강제 종료→재실행 복원도 통과했다. 최종 APK의 업데이트 팝업 자동 종료·로비·이어하기 화면까지 확인했다. 실기기 Google 로그인·실계정 동기화는 사용자가 직접 담당하며 통과로 간주하지 않는다.
- 최종 APK **372,097,698 bytes**, SHA-256 `5b373f12278437f1e9aa99f22905ca2e8302b6f04da189b720af9269cdbe7fe9`. 이전 공개 6028의 431,317,704 bytes보다 **59,220,006 bytes(13.73%) 감소**했다. Godot PCK는 143,889,784 bytes·871항목·완전 중복 0 bytes이며 ABI 3종을 유지한다. 앱 UI·서비스 이관으로 PCK가 늘었지만 Flutter 엔진·Dart 라이브러리·중복 에셋 제거로 전체 크기는 줄었다.
- 공개 태그의 커밋, latest/버전별 manifest 바이트 일치, 업로드된 5개 파일의 GitHub SHA-256·크기와 검증 산출물 일치, 공개 APK 다운로드 응답을 확인했다. 이미 검증한 대용량 파일의 재다운로드는 반복하지 않았다. 상세 근거는 `build/release-verification/apk-6029/`의 `ci-release-run.json`, `release-candidate-verification.json`, `final-release-review.json`, `public-verification.json`, `emulator/6029-release-after-50s.png`, `emulator/6029-release-restored-battle.png`에 있다. 이전 준비 검증은 [검증 기록](../analysis/godot_android_release_20260924/README.md)을 따른다.

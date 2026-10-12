# 배포 파이프라인과 개선 제안

역할: Android APK 배포 조사 절차와 읽기 전용 요약 도구. 2026-09-24에 Godot Android 워크플로 경로를 대조했다. 2026-10-13에는 `release_report.py`의 공개 기준·후보/공개 결속·단일 CI 대기를 격리 fixture로 검사했으며, 실제 공개·기기 검증 완료를 뜻하지 않는다.
적용 범위: Godot Android APK. API·DB 변경 시에는 [API 운영 절차](self_hosted_api_deployment.md)를 추가로 따른다. 과거 웹·Flutter 통합 자동화 제안은 아래 역사 절에 구분한다.
배포 완료 상태·버전·실행 링크는 [배포 인계](deployment_status.md)에만 기록한다. 이 문서는 기존 문서를 대체하지 않는다.

## 현행 배포 경로

배포 워크플로는 [deploy-apk.yml](../.github/workflows/deploy-apk.yml) 하나다. 웹 배포 경로는 폐기했다. 수동 실행의 기본값 `publish=false`는 서명 APK·패치·`update.json`을 검증해 Actions 아티팩트로 보관하며 공개하지 않는다.

| 입력·검사 | 빌드와 결과 |
| --- | --- |
| 버전·서명·API·Google 설정 검사 → Python 콘텐츠·스크립트 검사 → Godot 네이티브 회귀 | Godot 팩과 `android-godot-only`의 `productionRelease`를 빌드하고 Godot 팩·APK 패치 디코더를 감사 |
| 최근 최대 3개 공개 APK의 서명·차등 복원 검증 | 기본 실행은 APK·패치·`update.json` 아티팩트만 보관. `publish=true`일 때만 초안을 공개·최신 release로 지정 |

입력은 `version_code`, `version_name`, `notes`, `required_update`, `publish`다. `required_update=true`이면 이번 버전을 최소 지원 버전으로 지정하며, 선택 업데이트는 기존 최소 지원 버전을 유지한다. 버전 코드는 초안을 포함한 기존 APK release보다 커야 하며, 별도 배포한 설치본도 고려한다. 서명·차등 패치·실패한 초안 처리 규칙은 [APK 배포](android_apk_distribution.md#배포-실행)를 따른다.

APK 팩은 `android:<github.sha>`를 `app_config.json`에 포함한다. Godot 4.7.2와 Java 17을 사용하며 Flutter/Dart SDK를 설치하지 않는다. API·Google·업데이트 설정은 기존 Actions vars와 서명 secrets에서 주입한다.

## 배포 때 읽고 확인할 범위

1. [배포 인계](deployment_status.md)의 마지막 확인 결과와 실제 공개 APK를 대조하고, 그 이후 변경에서 이번 배포 대상을 정한다. 문서 기록만으로 미배포 여부를 단정하지 않는다.
2. 대상 커밋, APK 버전, 릴리스 노트를 확정한다. 워크플로 실행의 `headSha`가 대상과 같은지 확인한다.
3. 변경 영향에 맞는 검증 결과를 확인하고 기본 build-only 워크플로를 실행한다. 이미 확보한 동일 커밋의 관련 근거를 활용한다.
4. 공개를 별도로 선택한 뒤 release 대상 커밋과 latest/버전별 `update.json` 일치, 실제 공개 자산의 크기·SHA-256을 확인한다.
5. 배포 인계에 구성 요소별 성공·실패, 커밋, 실행·release 링크, 검증 범위와 남은 제한을 기록한다. 실제 기기 설치·로그인 검증 여부도 구분한다.

아래는 변경 영향에 따른 수동 확인 범위다. `release_report.py plan`은 경로별 영향 후보를 요약하지만, API·DB 계약 영향과 최종 검증 범위는 작업자가 판단한다.

| 변경 범위 | 필요한 추가 확인 | 반복하지 않아도 되는 작업 |
| --- | --- | --- |
| 클라이언트 코드·UI·에셋만 변경, 서버·DB·환경 계약 동일 | Godot·APK 검증, 관련 기능·화면 검증 근거 | API 재배포, DB 백업·복원, Go·DB 통합 테스트. 클라이언트만 바뀌었다는 근거를 먼저 확보한다. |
| API 코드·서버 지급표·운영 설정 변경 | API 운영 절차와 영향받은 서버 테스트, 클라이언트 호환성·배포 순서 | 변경과 관계없는 화면의 재검증 |
| DB migration·저장 계약 변경 | 백업·복원, migration·호환성·복구 절차, 영향받은 통합 테스트 | 범위 확인 전 임의 생략 불가 |
| 문서만 변경 | 링크·내용·diff | 실행 산출물이 바뀌지 않으므로 앱 빌드·배포 |

검증 재사용은 SHA뿐 아니라 검사 종류·성공 상태·SDK·의존성·환경 조건까지 같다는 근거가 있어야 한다. 관련 파일 수정, 도구 버전 변화, 실패 또는 미해결 우려가 있으면 해당 검사를 다시 수행한다. 이전 커밋의 성공을 새 커밋 전체 검증으로 보고하지 않는다.

## 구현된 읽기 전용 요약 도구

`scripts/release_report.py`는 배포·빌드·공개 상태 변경 없이 입력을 조사한다. 상세 근거는 `--output` JSON에 기록하고 stdout은 짧게 유지한다. 확인한 항목의 PASS는 종료 코드 0, 불일치·잘못된 입력은 1, 관측 부족·통신 실패의 UNKNOWN은 2다. 서명·실제 기기·계정 검증 등 검사하지 않은 범위는 JSON의 `unverified` 또는 `limitations`에 남는다. 결과·watch 로그는 기본 ignore 대상인 `build/` 또는 요청한 로컬 출력 경로에 보관한다.

```bash
# 명시한 두 커밋 사이의 변경 경로와 영향 후보, 현재 작업 트리 dirty 상태
python3 scripts/release_report.py plan \
  --baseline <이전배포SHA> --target <대상SHA> \
  --output build/release-plan.json

# 명시한 manifest와 APK의 바이트 크기·SHA-256 확인. 입력은 로컬 경로나 HTTP(S) URL.
python3 scripts/release_report.py verify \
  --manifest <update.json경로또는URL> --apk <APK경로또는URL> \
  --output build/release-verification.json

# 실제 latest 공개 APK의 tag를 commit까지 해석하고, 명시 대상과 로컬/원격 분기를 정리
python3 scripts/release_report.py snapshot \
  --target <대상SHA> --github-repo Sejiiinn/RuneNexus \
  --output build/release-snapshot.json

# 이번 CI run 하나만 대기. 다른 호출이 같은 run을 소유하면 추가 조회 없이 busy로 종료
python3 scripts/release_report.py wait \
  --github-repo Sejiiinn/RuneNexus --run-id <runID> --expected-sha <40자리대상SHA> \
  --timeout 1800 --log build/release-watch.log --output build/release-ci.json
```

manifest에 패치가 있으면 각각 `--patch <fromVersionCode>=<경로또는URL>`를 추가한다. 명시하지 않은 패치가 있으면 실패하며, manifest 내부 URL을 자동으로 다운로드하지 않는다. `--audit-godot-pack`를 추가하면 기존 `audit_godot_pack.py`로 해당 APK의 PCK 항목·완전 중복을 같은 JSON에 기록한다. HTTP(S) 다운로드는 서버의 리다이렉트를 따른다.

`--baseline-apk <이전APK경로또는URL>`를 추가하면 이전·현재 APK 총 바이트와 증감률, ZIP 항목별 압축 전·후 크기 변화 상위 10개를 JSON으로 기록하고 stdout에 총 증감을 한 줄 표시한다. 상위 항목은 압축 후 크기 증감의 절댓값 순이다. 이전 APK가 ZIP이 아니면 실패한다. 빌드 조건·서명 일치와 이전 APK의 공개 출처는 확인하지 않으며, 크기가 같은 항목도 내용이 같다고 판정하지 않는다. ZIP·서명 메타데이터 때문에 총 파일 증감과 항목 증감 합계는 다를 수 있다.

`plan`은 커밋 사이 diff와 현재 미커밋 상태를 분리한다. 경로별 영향 후보는 API·DB 호환성 판정이 아니다. `snapshot`은 `target_commitish=main` 같은 움직이는 이름 대신 공개 tag를 commit까지 해석해 APK 기준으로 사용하며, baseline 이후 **전체 포함 커밋·변경 경로**와 명시 대상에서 제외한 로컬/원격 커밋·이유를 기록한다. 공개 기준이 대상의 조상이 아니거나 `--expected-baseline <40자리SHA>`와 다르면 완료로 처리하지 않는다.

원격 분기는 `--remote-ref`(기본 `origin/main`)의 **로컬 캐시**를 사용하며 fetch/pull/update를 실행하지 않는다. 캡처 시각·`FETCH_HEAD` 파일 시각을 함께 기록하지만, 후자는 해당 원격 ref의 갱신 시각이나 현재 GitHub HEAD를 보증하지 않는다. `--local-ref` 기본값은 `HEAD`다. 서버 기준은 APK와 분리한다. 승인된 관측 결과가 있으면 `--server-baseline <40자리SHA> --server-evidence '<관측 근거 설명>'`을 제공하며 입력 근거임을 표시한다. 없으면 서버 baseline과 전체 snapshot은 UNKNOWN이고, 확인한 APK·분기 결과는 JSON에 유지한다. 도구가 운영 서버·DB에 접근하지 않는다.

후보 검수와 공개 결과는 같은 `verify` 명령으로 연결한다.

```bash
# 이미 내려받은 build-only 후보에 기대 대상/run을 결속. --plan-report로 전체 변경 요약 보존
python3 scripts/release_report.py verify \
  --manifest <후보update.json> --apk <후보APK> \
  --expected-sha <40자리대상SHA> --expected-run-id <runID> \
  --github-repo Sejiiinn/RuneNexus --inspect-apk-build \
  --plan-report build/release-snapshot.json --output build/release-candidate.json

# 공개 후 검수한 후보와 동일한 자산·manifest인지 명시 공개 URL로 검사
python3 scripts/release_report.py verify \
  --manifest https://github.com/Sejiiinn/RuneNexus/releases/download/apk-<code>/update.json \
  --apk https://github.com/Sejiiinn/RuneNexus/releases/download/apk-<code>/rune-nexus.apk \
  --latest-manifest https://github.com/Sejiiinn/RuneNexus/releases/latest/download/update.json \
  --candidate-report build/release-candidate.json --release-tag apk-<code> \
  --expected-sha <40자리대상SHA> --expected-run-id <runID> \
  --github-repo Sejiiinn/RuneNexus --inspect-apk-build --output build/release-public.json
```

후보와 공개본 모두 manifest에 있는 각 패치를 `--patch <fromVersionCode>=<명시경로또는URL>`로 제공한다. 공개 검사에서는 자산 전체 집합·크기·SHA-256, 후보/버전/latest manifest 바이트, 공개 tag 대상·manifest 버전 code, CI run ID·head SHA·성공을 대조한다. 명시 공개 URL과 manifest가 광고하는 `apkUrl`·각 patch `url`은 release의 `browser_download_url`과 같아야 하며, 광고 URL의 누락·불일치는 FAIL이다. URL 대조 때문에 추가 다운로드하지 않는다. 로컬 바이트만 제공하면 API digest 비교까지 수행하지만 실제 공개 다운로드는 UNKNOWN이다. GitHub digest가 없거나 latest를 확인할 수 없어도 UNKNOWN이며, 최신 release가 이동했거나 다른 후보·대상·run이면 FAIL이다. 공개 전용 입력은 `--candidate-report`·`--release-tag`·`--latest-manifest`와 기대 SHA/run을 함께 제공해야 하며 불완전한 조합을 무시하지 않는다. `--inspect-apk-build`는 기존 PCK parser로 `app_config.json`의 `clientBuild=android:<대상SHA>`를 읽어 대조한다. 공급한 로컬 후보의 다운로드 출처는 호출자가 보증해야 하며 run metadata만으로 후보 파일의 출처를 증명하지 않는다.

읽기 API 대신 저장한 관측을 사용하려면 `snapshot --release-info <JSON>`, 후보 `verify --run-info <JSON>`, 공개 `verify --release-info <JSON>`을 지정한다. 관측은 `observed_at`, `github_repo`와 원래 GitHub `release`/`run` API 객체, commit까지 해석한 `tag_sha`, snapshot·공개 검사에 필요한 `latest_tag`를 담는다. 파일 입력은 live 조회가 아니며 근거 경로를 표시한다. `--github-repo`도 지정했다면 관측의 repo가 일치해야 한다. 사용하는 raw run의 `repository.full_name`·`html_url`, release의 `html_url`·자산 `browser_download_url`도 같은 repo와 run/tag 경로에 결속한다. 필요한 raw 정보가 없으면 UNKNOWN, 명시된 repo/경로/latest 충돌은 FAIL이다. `--run-info`와 `--release-info`를 동시에 제공하지 않는다. manifest 내부 URL을 따라 추가 다운로드하거나 재공개·자동 재실행하지 않는다.

`wait`는 시작과 종료 때만 `gh run view`로 확인하고 대기 중에는 `gh run watch --exit-status` 하나를 사용한다. 완료 run은 watch를 시작하지 않는다. repo/run별 OS 파일 lock을 여러 worktree에서 공유하며 중복 호출은 소유 PID·로그 경로를 반환한다. 시간 초과·Ctrl-C·SIGTERM 때 로컬 watch 프로세스 그룹을 정리하고 lock을 해제하며 원격 CI는 취소하지 않는다. 최종 status·conclusion·실패 step·artifact ID와 로그 경로를 기록한다. watch 중 같은 run을 주기적으로 별도 조회하지 않는다.

이 도구의 PASS는 기록한 기계적 항목만 뜻한다. API/DB 호환성·배포 순서·용량 증가 적절성·지원 ABI·바이너리 패키지 identity·서명·차등 복원·설치·화면 품질은 별도 근거가 필요하다. 공개 manifest의 `minimumSupportedVersionCode`와 패키지명은 metadata로 기록하며 Android 바이너리 검증으로 승격하지 않는다. 전체 배포의 성공과 실제 배포 사실은 [배포 인계](deployment_status.md)에서 따로 관리한다.

검증: `python3 -m unittest discover -s scripts -p 'test_release*.py'`는 격리된 Git 저장소·로컬 자산·모의 HTTP/gh 응답으로 잘못된 baseline·분기·관측 부족·자산/URL/대상/run 불일치·PCK build·단일 watch·중복·실패/timeout/취소를 검사한다.

## 역사: 웹·Flutter 통합 자동화 제안

아래는 2026-09-14 당시 웹과 Flutter APK가 별도 workflow였을 때의 제안이다. 웹 경로와 Flutter SDK는 현재 배포 대상이 아니며, 표의 통합 workflow·Flutter 공통 검사를 현행 작업 지시로 사용하지 않는다. 현재 후속 배포 범위는 [배포 현황](deployment_status.md)에서 관리한다.

당시 우선순위는 **공개 상태와 검사 근거 수집 확장 → 통합 workflow**였다. 아래 표는 당시 제안이며 현재 읽기 도구의 구현 범위는 위 절을 따른다. 배포 실행 통합·예약 실행은 구현하지 않았다.

| 단계 | 제안 | 줄어드는 반복 |
| --- | --- | --- |
| 1. 공개 기준·입력 수집 확장 | 마지막 실제 공개 SHA·기존 검증 근거·버전 정보를 수집해 구현된 `plan`의 입력으로 연결하고, 다음 APK 버전 후보·릴리즈 노트 초안을 준비 | 매번 여러 문서·커밋·release를 탐색하는 작업 |
| 2. 공개 상태 검사 확장 | 구현된 명시 자산 해시·용량 검사에 웹의 커밋·응답, APK release 대상 커밋·latest/버전별 manifest 일치·공개 자산 위치 수집을 연결 | 배포 후 공개 상태를 수동 대조하고 검사 입력을 다시 구성하는 작업 |
| 3. 단일 수동 진입점 | 대상 SHA·배포 구성 요소·버전·노트를 한 번 받고, 동일 SHA를 checkout하는 공통 검증 job 뒤 웹·APK 빌드를 병렬 실행 | 두 workflow 입력·추적과 Flutter 분석·전체 테스트 중복 |
| 4. 조건부 서버 경로 | 서버·DB 변경이 확인될 때만 기존 API 운영 절차에 연결하고 그 결과를 같은 요약에 포함 | 프론트 배포 때 서버 전체 절차를 다시 조사하는 작업 |

당시 제안은 APK 전용 Python·Kotlin 검사, 서명·차등 복원 검증과 각 플랫폼 빌드를 유지하고 Flutter SDK·lockfile·SHA가 같은 공통 검사만 재사용하는 것이었다. 현재 워크플로의 검증 선택 기준은 [작업 기준](../AGENTS.md#변경-대상별-검증)을 따른다.

당시 웹·APK 동시 공개가 원자적이지 않은 문제 때문에 부분 실패를 별도로 기록하도록 제안했다. 현재 APK 초안·버전 충돌과 공개 자산 불변 규칙은 [APK 배포 절차](android_apk_distribution.md#배포-실행)를 따른다.

파일 경로에 따른 범위 분류와 릴리즈 노트 생성은 보조 기능으로 둔다. 클라이언트 변경에도 API 계약 영향이 있을 수 있고 별도 설치본의 버전은 GitHub만으로 알 수 없다. 자동화는 공개 결과 검사·근거 수집을 담당하며, 실제 기기 설치와 저장 유지 검증을 대신했다고 보고하지 않는다.

# 배포 파이프라인과 개선 제안

역할: Android APK 배포 조사 절차와 읽기 전용 요약 도구. 2026-09-24에 Godot Android 워크플로 경로를 대조했다. `release_report.py` 명시 입력 검증 근거는 2026-09-14 기록이며, 실제 공개·기기 검증 완료를 뜻하지 않는다.
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

`scripts/release_report.py`는 배포·빌드·공개 상태 변경 없이 명시한 입력을 조사한다. 상세 근거는 `--output` JSON에 기록하고 stdout은 짧게 유지한다. 실패는 종료 코드 1이다.

```bash
# 명시한 두 커밋 사이의 변경 경로와 영향 후보, 현재 작업 트리 dirty 상태
python3 scripts/release_report.py plan \
  --baseline <이전배포SHA> --target <대상SHA> \
  --output build/release-plan.json

# 명시한 manifest와 APK의 바이트 크기·SHA-256 확인. 입력은 로컬 경로나 HTTP(S) URL.
python3 scripts/release_report.py verify \
  --manifest <update.json경로또는URL> --apk <APK경로또는URL> \
  --output build/release-verification.json
```

manifest에 패치가 있으면 각각 `--patch <fromVersionCode>=<경로또는URL>`를 추가한다. 명시하지 않은 패치가 있으면 실패하며, manifest 내부 URL을 자동으로 다운로드하지 않는다. `--audit-godot-pack`를 추가하면 기존 `audit_godot_pack.py`로 해당 APK의 PCK 항목·완전 중복을 같은 JSON에 기록한다. HTTP(S) 다운로드는 서버의 리다이렉트를 따른다.

`--baseline-apk <이전APK경로또는URL>`를 추가하면 이전·현재 APK 총 바이트와 증감률, ZIP 항목별 압축 전·후 크기 변화 상위 10개를 JSON으로 기록하고 stdout에 총 증감을 한 줄 표시한다. 상위 항목은 압축 후 크기 증감의 절댓값 순이다. 이전 APK가 ZIP이 아니면 실패한다. 빌드 조건·서명 일치와 이전 APK의 공개 출처는 확인하지 않으며, 크기가 같은 항목도 내용이 같다고 판정하지 않는다. ZIP·서명 메타데이터 때문에 총 파일 증감과 항목 증감 합계는 다를 수 있다.

`plan`은 커밋 사이 diff와 현재 미커밋 상태를 분리한다. 경로별 영향 후보는 API·DB 호환성 판정이 아니며, 공개·기기 설치 버전이나 CI 검증 근거를 찾지 않는다. `verify`의 PASS는 공급한 metadata와 공급한 바이트의 일치만 뜻한다. GitHub 최신 공개본 여부·대상 커밋·서명·패키지명·차등 복원·CI·설치·화면 품질은 검사하지 않는다. 용량 증가의 적절성이나 지원 ABI도 자동 판정하지 않는다. 따라서 아래의 전체 배포 전후 자동화가 완료된 것은 아니다.

검증: `python3 -m unittest discover -s scripts -p 'test_release_report.py'`는 격리된 Git 저장소·로컬 자산과 모의 HTTP 응답으로 실패 처리·범위 분리·명시 입력·PCK 연동을 검사한다.

## 역사: 웹·Flutter 통합 자동화 제안

아래는 2026-09-14 당시 웹과 Flutter APK가 별도 workflow였을 때의 제안이다. 웹 경로와 Flutter SDK는 현재 배포 대상이 아니며, 표의 통합 workflow·Flutter 공통 검사를 현행 작업 지시로 사용하지 않는다. 현재 후속 배포 범위는 [배포 현황](deployment_status.md)에서 관리한다.

당시 우선순위는 **공개 상태와 검사 근거 수집 확장 → 통합 workflow**였다. 위 요약 도구는 명시 입력 검사까지 구현했으며, 아래 표의 공개 상태 자동 조사·배포 실행 통합·예약 실행은 구현하지 않았다.

| 단계 | 제안 | 줄어드는 반복 |
| --- | --- | --- |
| 1. 공개 기준·입력 수집 확장 | 마지막 실제 공개 SHA·기존 검증 근거·버전 정보를 수집해 구현된 `plan`의 입력으로 연결하고, 다음 APK 버전 후보·릴리즈 노트 초안을 준비 | 매번 여러 문서·커밋·release를 탐색하는 작업 |
| 2. 공개 상태 검사 확장 | 구현된 명시 자산 해시·용량 검사에 웹의 커밋·응답, APK release 대상 커밋·latest/버전별 manifest 일치·공개 자산 위치 수집을 연결 | 배포 후 공개 상태를 수동 대조하고 검사 입력을 다시 구성하는 작업 |
| 3. 단일 수동 진입점 | 대상 SHA·배포 구성 요소·버전·노트를 한 번 받고, 동일 SHA를 checkout하는 공통 검증 job 뒤 웹·APK 빌드를 병렬 실행 | 두 workflow 입력·추적과 Flutter 분석·전체 테스트 중복 |
| 4. 조건부 서버 경로 | 서버·DB 변경이 확인될 때만 기존 API 운영 절차에 연결하고 그 결과를 같은 요약에 포함 | 프론트 배포 때 서버 전체 절차를 다시 조사하는 작업 |

당시 제안은 APK 전용 Python·Kotlin 검사, 서명·차등 복원 검증과 각 플랫폼 빌드를 유지하고 Flutter SDK·lockfile·SHA가 같은 공통 검사만 재사용하는 것이었다. 현재 워크플로의 검증 선택 기준은 [작업 기준](../AGENTS.md#변경-대상별-검증)을 따른다.

당시 웹·APK 동시 공개가 원자적이지 않은 문제 때문에 부분 실패를 별도로 기록하도록 제안했다. 현재 APK 초안·버전 충돌과 공개 자산 불변 규칙은 [APK 배포 절차](android_apk_distribution.md#배포-실행)를 따른다.

파일 경로에 따른 범위 분류와 릴리즈 노트 생성은 보조 기능으로 둔다. 클라이언트 변경에도 API 계약 영향이 있을 수 있고 별도 설치본의 버전은 GitHub만으로 알 수 없다. 자동화는 공개 결과 검사·근거 수집을 담당하며, 실제 기기 설치와 저장 유지 검증을 대신했다고 보고하지 않는다.

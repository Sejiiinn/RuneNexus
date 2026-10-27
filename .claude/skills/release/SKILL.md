---
name: release
description: RuneNexus 서버·DB 반영과 Android APK 공개 배포를 끝까지 수행한다. 사용자가 "배포해줘", "공개해줘", "서버 반영해줘"처럼 배포를 요청할 때 사용한다. build-only 검수에서 멈추지 않고 공개·공개 대조·배포 기록까지 완료한다.
---

# 배포

목표는 **공개까지 완료**다(사용자 지정). 검수에서 실패·이상이 나오면 공개하지 않고 보고한다. 절차의 기준 문서는 [배포 파이프라인](../../../docs/deployment_pipeline.md)·[API 운영 절차](../../../docs/self_hosted_api_deployment.md#api-반영과-db-백업)이며 이 스킬은 실행 순서만 묶는다.

## 1. 대상 확정

1. `docs/deployment_status.md`의 「현재 미배포 변경」과 실제 상태를 대조한다.
   - 공개 APK: `gh release list --limit 1`의 태그 → 커밋
   - 운영 API: `docker inspect rune-nexus-api-1 --format '{{index .Config.Labels "org.opencontainers.image.revision"}}'`, DB 스키마: `scripts/server_ops.py`의 `schema_version`
2. 서버 반영 필요 여부: 운영 revision 이후 `server/`·`godot/content/source`·`test/fixtures` 변경이 있으면 필요하다. 앱이 새 클라이언트 세대를 쓰면 서버를 먼저 반영한다.
3. 정해지지 않았으면 제안해 한 번에 확인받는다: 버전 코드(최신+1), 표시 버전(patch+1), 릴리스 노트(사용자 문장, 한 줄에 하나), 필수 업데이트 여부(기본 선택; 구버전과 저장·API가 호환되지 않을 때만 필수).
4. 로컬 커밋이 있으면 푸시한다(APK는 origin/main HEAD로 빌드된다).

## 2. 서버 (필요할 때만)

```bash
python3 scripts/server_release.py prepare <commit>            # 운영 무변경. 빌드·Go 검사·마이그레이션 리허설
python3 scripts/server_release.py rehearse-deploy <작업 폴더>  # 격리 스택에서 deploy 전 과정
python3 scripts/server_release.py deploy <작업 폴더> --confirm # 운영 API 정지(수십 초) → 반영
```

- prepare는 수 분 걸리므로 백그라운드로 실행한다. 출력의 `*_PASS`와 작업 폴더를 확인한다.
- deploy는 `.claude/settings.local.json`에 허용 규칙이 있다. 그래도 막히면 우회하지 말고 사용자 승인을 받는다.
- 실패 시 스크립트가 직전 API 복귀(마이그레이션 전) 또는 복구 안내(마이그레이션 후)를 출력한다. 그 출력을 그대로 보고한다.
- 결과: 작업 폴더의 `production-verification.json`(정지 시각·스키마·HTTP 검사).

## 3. APK build-only → 검수

```bash
python3 scripts/apk_release.py build --version-code <N> --version-name <x.y.z> --notes "<노트>" [--required-update]
```

- 약 20분. 백그라운드로 실행하고 완료 알림을 기다린다(폴링하지 않는다).
- `build/apk-release-<N>/build.json`의 APK 크기·ABI·패치 크기·PCK 감사를 직전 공개본과 비교한다. 크기가 크게 늘었으면 [용량 점검](../../../docs/android_apk_distribution.md#용량-점검)으로 원인을 밝힌다.
- Android 기기 확인은 Android에서만 드러나는 변경(저장 마이그레이션, 업데이트·패치 경로, 네이티브 연동, 터치·수명주기)이 있을 때만 한다. 외장 AVD(`/Volumes/KIOXIA_MAC/Development/Android/avd/emulator37.avd`)를 임시 `ANDROID_AVD_HOME`의 ini로 지정해 `-read-only`로 띄우고, 직전 공개 APK 설치·실행 → `build-only/rune-nexus.apk` 업데이트 설치 → 저장 파일 해시·최초 설치 시각·실행·오류 로그를 확인한다(`adb root` 가능). 끝나면 에뮬레이터를 끈다.

## 4. 공개 → 공개 대조

```bash
python3 scripts/apk_release.py publish --version-code <N>
```

- build와 같은 입력·커밋으로 `publish=true`·`promote_run_id=<build 실행>`을 실행해, 검수한 build-only 후보 파일을 다시 빌드하지 않고 공개한다(1~2분). HEAD가 바뀌었거나 build 뒤 다른 APK가 공개돼 승격이 거부되면 build부터 다시 한다.
- 공개 자산을 익명으로 받아 GitHub digest·크기, latest/버전별 `update.json`, 공개 URL 관측 검수(`public-verification.json`), build-only 후보와의 바이트 일치(`same_as_build_only_candidate`)를 대조한다.

## 5. 기록

1. 같은 구성 요소의 직전 기록을 이력으로 옮긴다: `python3 scripts/deployment_record.py archive app` (서버를 반영했으면 `archive server`도).
2. `docs/deployment_status.md`의 「현재 미배포 변경」 아래에 새 절을 쓴다. 형식은 이력의 기존 절을 따른다: 대상 커밋·CI·릴리스 링크, 포함 내용, 검사 결과, 크기·패치·직전 대비 증감과 원인, 공개 대조, 기기 확인 범위, **미검증 항목**(실제 Google 로그인·앱 내 패치 업데이트·실기기 등)과 독립 검증 수행 여부.
3. 「현재 미배포 변경」에서 배포된 항목을 지우고, 배포된 계획을 `docs/TODO.md`에서 정리하며 관련 설계 문서의 `상태:`를 갱신한다.
4. `python3 scripts/check_doc_links.py --changed` 후 기록만 커밋·푸시한다(문서만 바뀐 푸시는 검사 CI를 건너뛴다).

## 보고

서버(정지 시간·스키마·HTTP)와 앱(릴리스 링크·APK/패치 크기·직전 대비)을 표로 짧게 보고하고, 미검증 항목을 숨기지 않는다.

# 배포 상태와 세션 간 인계

배포 요청은 이 문서와 [파이프라인 지도](deployment_pipeline.md)에서 시작한다.
서버·DB·운영 설정 또는 그 계약이 바뀌는 경우 [API 운영 절차](self_hosted_api_deployment.md)를 함께 확인한다.
이 문서는 마지막 검증 이력이며 실시간 운영 상태가 아니다. 배포 대상의 실제 공개 버전·커밋과
서버 실행 이미지·DB 버전을 확인한다.

## 2026-09-13 Godot 표현 이관 테스트 APK

- [Google Drive 테스트 APK](https://drive.google.com/file/d/1AnPBmf9zwRarabn9TWqlU6yHaKPmRUan/view?usp=drivesdk) 업로드 완료. Drive 메타데이터의 이름·크기를 확인했다. 다운로드 접근 문제 후 이 APK에 한해 링크가 있는 모든 사용자의 읽기 권한(검색 노출 없음)을 적용하고 메타데이터로 확인했다.
- 사용자 기기 테스트용 로컬 release code 6022. GitHub 공개 릴리스·자동 업데이트 메타데이터는 갱신하지 않는다.
- APK: 397,227,684 bytes (378.83 MiB), SHA-256
  `862b238d383dae40d73fe62d84991357b09780f9dde0b8db4b6541a5cfec39f1`.
- 현재 공개 `apk-2002`의 실제 릴리스 APK 414,151,176 bytes 대비
  16,923,492 bytes (16.14 MiB, 4.09%) 감소. 2026-09-13 GitHub 릴리스 자산 메타데이터로 기준 크기를 확인했다.
- 직전 로컬 6015 대비 9.20 MiB 증가는 Godot PCK에 추가한 원본 폰트·표현 에셋이 주원인이다.
  arm64-v8a·armeabi-v7a·x86_64를 유지하며, 미사용 ANGLE·Flutter 3D 자산 중복·design 원본의 APK 포함은 없다.
  ABI별 압축 크기와 남은 실기기 성능 검증은 [검증 기록](../design/stage1_3d/presentation_migration/README.md)에 남겼다.
- 테스트 APK 전달이므로 차등 패치를 생성하지 않았다.

## 마지막 확인된 운영 상태

2026-09-12, Android 0.1.13 / code 2002 및 서버 선행 반영을 완료했다.

- Android 대상: `4ee3e7bf1d26e46f028800b7c8a536de42731f9c`, versionName 0.1.13 / versionCode 2002.
  로컬 본게임 검증본이 코드 2001을 사용했으므로 기존 설치를 업데이트할 수 있는 2002를 선택했다.
  [APK workflow 34618596547](https://github.com/Sejiiinn/RuneNexus/actions/runs/34618596547) 성공.
  [공개 release apk-2002](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-2002)의 태그 대상 커밋도 일치한다.
  latest와 버전별 `update.json`이 같으며 공개 APK·apk-11/12/13용 패치의 실제 크기·SHA-256이
  매니페스트와 일치한다. APK는 414,151,176 bytes, SHA-256은
  `04f522da5db602621864e5b76083c9be5a25bbfbf9da94e79f92f63182bab081`이다.
- 운영 API: 서버 소스 `54f8d038fe74a6657dd23ba7b5e43c79f2f7ed88`의 `server/`를 빌드한
  `rune-nexus-api:54f8d03`. 실행 이미지 ID는
  `sha256:7100b1d48544fee7382e5291cf3e89c12f4bc94b17dfc817b298d432b03164a0`.
  Android 대상 커밋과 서버 소스는 같다. 운영 DB migration 011 적용, 컨테이너 healthy.
- 공개 API의 live·ready HTTP 200, economy·mailbox·mailbox/summary의 무인증 요청은
  `401 ACCESS_TOKEN_INVALID`로 확인했다.
- 웹은 이번 배포 대상에서 제외했다. 마지막 배포는 0.1.12 / `a3119b499a459fee4c24a112db5a218836492dbb`,
  [workflow 34462502175](https://github.com/Sejiiinn/RuneNexus/actions/runs/34462502175)이다.
  이번 Android 배포에서 웹 파일을 새로 배포하거나 재검증하지 않았다.

## 이번 배포 변경

- Android 본게임 스테이지 1에 Godot 3D 지형·포탑·적·발사 및 착탄 효과를 연결한다.
  일반 `lib/main.dart` 진입과 기존 로그인·웨이브·건설·보상·저장 흐름을 사용한다.
- 고정·드론 시점을 부드럽게 전환하고, 실제 투영으로 건설 입력과 기존 HUD를 연결한다.
- 기관총·대포의 총구 효과와 탄체·예광 가독성을 개선한다. 한 프레임 안에 명중한 탄환도
  짧은 종료 궤적을 표시하며 피해 계산과 저장 형식은 유지한다.
- 스테이지 2 이후와 Android 이외 플랫폼은 기존 2D 전장을 유지한다.
- 직전 APK 이후 main에 들어온 로비 우편함을 포함한다. 서버에는 우편함 조회·수령 API와
  신규 테이블 4개·인덱스를 추가하는 migration 011을 먼저 적용했다.
- Godot 4.7.2 실행 파일·AAR와 공통 PCK를 배포 빌드에서 준비한다.
  별도 검수 앱의 고정 대포 배치와 디버그 패널은 본게임 배포에서 사용하지 않는다.

## 검증 범위와 복구 참고

- 서버: Go 1.26.5 단위 테스트·vet 통과. 격리된 PostgreSQL 18의 DB 통합 테스트
  31개 통과, 실패·스킵 0건.
- 운영 DB 백업을 비공개 저장소에 보관하고 별도 PostgreSQL에서 복원 후 010→011을 검증했다.
  복원 DB의 기존 25개 테이블은 적용 전후 행 수·내용 지문이 모두 같았다.
- 운영 적용은 011 migration 후 API 컨테이너만 교체했다. PostgreSQL·Caddy·DuckDNS,
  기존 세션 암호화 키를 포함한 환경값·secret mount와 운영 DB 볼륨을 보존했다.
- 본게임의 Android 에뮬레이터 진입·건설·웨이브·이어하기·시점 전환과 1·4배속 투사체 검수는
  [본게임 연결 기록](../design/stage1_3d/main_runtime/README.md)과
  [투사체 검수 기록](../design/stage1_3d/projectile_visibility/README.md)을 따른다.
- 첫 CI 34617590541은 분석·전체 테스트·Godot 팩 생성 후 CMake 3.31.4 미설치로 빌드가 중단됐다.
  배포 환경에 패키지가 요구한 CMake·NDK·Build Tools 설치를 추가해 재실행했다. 공개 릴리스는 생성되지 않았다.
- 최종 CI의 Flutter 정적 분석·전체 테스트 766개(기존 조건에 따른 11개 생략), Python APK 검사 17개,
  Android 패치 디코더 및 최근 3개 기준 APK에서의 패치 복원 검증이 통과했다.
- 공개 APK를 직접 내려받아 ZIP 무결성, 패키지·버전·3D PCK 동봉과 기존 apk-13의 서명 일치를 확인했다.
  기존 코드 2001 설치본에 `adb install -r`로 업데이트하고 Android ARM64 에뮬레이터에서
  로비→이어서 진행→Godot 3D 전장 표시를 확인했다. 골드 330·코어 20/20·6/40 웨이브와
  5웨이브 보상 선택 상태가 동일하게 복원됐다. 실제 기기의 업데이트 설치·장시간 전투·발열과
  Google 로그인·우편 수령·계정 저장 복원 E2E는 미검증이다.
- 서버 복구용 `rune-nexus-api:de7a878` 이미지를 보존했다. 011은 추가형 forward-only이며
  이번에 down migration·계정 삭제·운영 우편 발송 또는 수령은 수행하지 않았다.
- 공개 APK 파일·태그를 덮어쓰거나 versionCode를 낮추지 않는다. 수정 또는 복구 앱은
  기존 배포·설치본보다 높은 versionCode로 배포한다.

### 현재 서버 이미지로 재생성

일반 컨테이너 재시작·Docker 자동 재시작은 현재 이미지를 유지한다. API를 재생성할 때는
이번 배포의 이미지 override를 포함한다. 기본 Compose 두 파일만 사용하면
`rune-nexus-api:latest`가 선택되므로 배포 이미지 고정이 보장되지 않는다.

저장소 루트에서 다음 명령을 사용한다. override에는 이미지 선택만 있으며 비밀값은 없다.

```bash
docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  -f "/Users/sejin/Library/Application Support/RuneNexus/operations/mailbox-release-20260911T153453Z/api-release.override.json" \
  up -d --no-deps --no-build --wait --wait-timeout 45 api
```

## 미배포 항목

이번 Android 실기기 검증 요청 범위의 배포는 완료했다.
웹의 우편함·3D 관련 코드 반영은 이번 Android 실기기 검증 요청의 배포 범위에 포함하지 않는다.

## 기록 유지 규칙

- 배포가 필요한 코드 변경에는 필요한 migration·환경 설정·선행 조건을 함께 기록한다.
- 배포 후 구성 요소별 커밋, workflow/release, 검증 결과와 한계를 갱신하고 미배포 항목을 정리한다.
- 실패·부분 완료는 구성 요소별로 기록한다. 과거 대화나 로컬 작업 기록만으로 완료를 판단하지 않는다.
- 비밀번호, 토큰, 암호화 키, DB 백업 내용은 이 문서나 커밋에 넣지 않는다.

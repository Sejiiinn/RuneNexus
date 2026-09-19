# 배포 상태와 세션 간 인계

배포 요청은 이 문서와 [파이프라인 지도](deployment_pipeline.md)에서 시작한다.
서버·DB·운영 설정 또는 그 계약이 바뀌는 경우 [API 운영 절차](self_hosted_api_deployment.md)를 함께 확인한다.
이 문서는 마지막 검증 이력이며 실시간 운영 상태가 아니다. 배포 대상의 실제 공개 버전·커밋과
서버 실행 이미지·DB 버전을 확인한다.


## 2026-09-20 성장 조정·필수 업데이트 APK 0.1.18 / code 6027, 웹·API 배포

- 대상 `f7ca3d47897c2e3613aa5c914c0d6631c9bca522`. [APK workflow](https://github.com/Sejiiinn/RuneNexus/actions/runs/35461936191)·[웹 workflow](https://github.com/Sejiiinn/RuneNexus/actions/runs/35461937928) 성공, [공개 release](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6027) 대상 커밋 일치. 공개 웹의 주요 파일 HTTP 200과 빌드 SHA·운영 API 주소를 확인했다.
- 강화 상한 확장·기초 화력 비용 지수 1.06, 치명 집중/긴급 매각 연구 이관 및 토벌 보상 강화 이관. 룬 공명과 나머지 기존 연구는 유지한다. 수치는 [현행 밸런스](gameplay_balance_reference.md)를 따른다. 기존 레벨은 성장 버전 1로 자동 이전하며 비용 차액 환급은 없다.
- 이번 배포는 `required_update=true`, 공개 `minimumSupportedVersionCode=6027`. 선택 업데이트는 기존 최소 버전을 유지한다. 새 앱은 시작·복귀 시 확인하고 필수 업데이트 설치 취소 및 확인 실패 시 게임 진입을 차단한다. 이미 배포된 구앱의 오프라인 실행 자체를 소급 차단할 수는 없다.
- API는 `rune-nexus-api:f7ca3d4`, 이미지 `sha256:f1653fa27c1093be711855d635dafe9c64bafb8374a20197cacd45e1c5db7085`. 호환 하한 2로 서버 선반영 후 APK·웹 공개를 확인하고 `MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION=3`으로 올렸다. 실행 환경값·Docker healthy·공개 HTTPS readiness 정상 확인. 구세대 writer/저장/경제 변경을 거절하며 이전된 계정의 성장 버전 회귀도 방어한다.
- DB 스키마 변경은 없다. 운영 백업 345,934 bytes의 격리 PostgreSQL 복원과 통합 검사를 완료하고 임시 DB 컨테이너·네트워크를 제거했다. 백업·이미지 override·배포 로그는 비공개 `~/Library/Application Support/RuneNexus/operations/growth-release-20260919T183021Z/`에 보관한다. 후속 API 재시작에는 해당 `api-release.override.json`을 base/production Compose에 함께 적용해야 한다. 이전 이미지·백업은 보존했다.
- 로컬 Flutter 전체 902개 통과·12개 skip, analyze 문제 없음, Python APK 검사 24개 통과. Go 전체 test/vet와 격리 PostgreSQL 통합 검사 통과. CI 분석·전체 검사·서명·최근 3개 APK 차등 복원도 통과했다.
- Android 일반 앱 debug 6027에서 강화·경제·연구 메뉴를 실제 확인했다. 기초 화력 100/체력 30/토벌 40/긴급 매각 5/치명 집중 10과 레벨당 2%p 표시 정상, 대상 메뉴 잘림·겹침 없음. 검수 전후 저장 파일 97개 SHA-256 동일. 캡처·검증 근거는 `build/growth-validation/`. 초기 로비의 기존 14px 하단 overflow는 이번 메뉴 변경 범위 밖이며, 공개 release APK의 실기기 설치·로그인을 검증한 것은 아니다.
- 공개 APK 431,317,688 bytes, SHA-256 `1ea465ad36cf9d6ae445819cdd72646922cee0f60cef7604ee7ac9ad294dcd84`. 6026 대비 +163,856 bytes (+0.04%): libapp.so arm64/x86_64 각 +65,536, armeabi-v7a +32,768, Godot PCK +16 bytes. ABI 3종 유지, design 제작 파일·Flutter 원본 GLB 포함 없음.
- Godot PCK 105,955,316 bytes·275항목·완전 중복 0 bytes. APK·6024/6025/6026 패치의 실제 다운로드 크기·SHA-256 모두 일치, latest와 버전별 update.json 바이트 일치 및 필수 하한 6027 확인. 6026 패치 97,325,997 bytes. 공개 검증·CI audit·웹 확인 근거: `build/release-verification/apk-6027/`.

## 2026-09-19 본게임 APK 0.1.17 / code 6026 배포

- 대상 `af4572a1f233e66519b66f2f3b89600220fb3121`. [workflow](https://github.com/Sejiiinn/RuneNexus/actions/runs/35427499439) 성공, [공개 release](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6026) 대상 커밋 일치. Android만 배포했으며 웹·서버·DB는 변경하지 않았다.
- 탄환·선택 표시 이관, 화염 MultiMesh, 작은 고정/드론 전환 버튼과 직전 공개 이후 커밋된 변경 포함. 로컬 검사는 반복하지 않았고 CI 필수 검사·서명 빌드·패치 디코더·차등 복원 절차가 통과했다.
- 공개 APK 431,153,832 bytes, SHA-256 `54cd114d037fe37bb84e47d6760c272ce2ea034d3fc979f85889b6b4d4d4b12e`. 6025 대비 +15,138,296 bytes (+3.64%). ZIP 증가 대부분은 Godot PCK +15,089,144 bytes, armeabi-v7a libapp.so +49,152 bytes. ABI 3종 유지, design/ 제작 파일 포함 없음.
- PCK 105,955,300 bytes·275항목·완전 중복 0 bytes. 공개 APK·6023/6024/6025 패치의 실제 다운로드 크기·SHA-256 확인 PASS. latest와 버전별 update.json 바이트 일치. 6025 패치는 111,340,276 bytes.
- 근거: `build/release-verification/apk-6026/`의 release.json·verification.json·audit와 공개 파일. 배포 APK의 실기기 설치/로그인은 별도 수행하지 않았다. 기존 로컬 Android UI 검증과 에뮬레이터 FPS 측정을 실기기 성능 통과로 간주하지 않는다.

## 2026-09-15 본게임 APK 0.1.16 / code 6025 배포

- 대상 커밋: `7d29895c8c15439a5a35b96eeff0911840798779`. [APK workflow 34907234097](https://github.com/Sejiiinn/RuneNexus/actions/runs/34907234097) 전체 성공. [공개 release apk-6025](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6025)의 태그 커밋도 일치한다.
- 화염 포탑 승인 3D 모델·상부 불꽃·포구·발사체, 적 공통 GPU 화상, 6024 이후 커밋된 공통 서리·얼음 결정 및 대포 폭발 파편·불티 GPU 운동 최적화를 포함한다.
- 3D 경로의 기존 2D 화염·냉각 명중 표시와 2D 화상 중복 표시를 제거했다. 피해·지속시간·저장 계약은 유지한다.
- 사거리 원은 선택 포탑만, 설치 패널 활성 중 기존 전체 포탑을 표시한다. 설치 미리보기·업그레이드·보상 우선순위는 유지하고 Godot 투영 좌표를 캐시한다.
- 종료된 화염 입자의 GPU 요청을 중단한다. `ranchu` / `sdk_gphone64_arm64` 에뮬레이터에만 임시 Skia 호환 처리를 적용하며 실기기는 Flutter 기본 렌더러를 유지한다. Flutter 업그레이드 때 deprecated opt-out 지원을 재검증해야 한다.
- 로컬 전체 Flutter 검사 833개 통과·11개 skip, 변경된 Godot 팩 준비 Python 검사 통과. CI 분석·전체 Flutter 테스트·Python APK 검사·서명 빌드·Android 패치 디코더·기존 세 버전의 서명 일치와 차등 복원 검증도 통과했다.
- 실제 공개 APK: **416,015,536 bytes (396.74 MiB)**, SHA-256 `43f13a3cf061acb64ef745d55db15a7242004bba28b53e2752b1ea9d1847f948`. 이전 공개 6024의 411,353,104 bytes 대비 **4,662,432 bytes (4.45 MiB, 1.13%) 증가**했다. 주로 새 화염 포탑 메시·공유 텍스처 및 화상·서리 에셋이다.
- arm64-v8a·armeabi-v7a·x86_64를 유지한다. Godot PCK **90,866,156 bytes·246항목·완전 중복 0 bytes**. Flutter 원본 GLB·design 제작 파일과 미사용 코어 실험 shader가 공개 팩에 없는 것을 확인했다. 배포 전 로컬 팩에만 있던 미사용 shader는 clean checkout 빌드에서 제외됐다.
- 차등 패치: **6024 → 6025는 99,812,259 bytes (95.19 MiB)**, 6023 → 6025는 100,514,191 bytes, 2002 → 6025는 100,674,772 bytes. 공개 APK·세 패치·update.json을 직접 다운로드해 실제 크기와 SHA-256을 대조했다. latest와 버전별 update.json의 바이트 일치 및 실제 공개 6024/6025 APK 서명 인증서 일치도 확인했다.
- 검증 원본: `build/release-verification/apk-6025/`의 release·verification·signature JSON, 다운로드 자산과 CI 팩 audit. 공개 후 확인은 다운로드 무결성·서명·메타데이터이며 사용자 기기 설치·로그인 검증을 대신하지 않는다.
- 앞선 Android 일반 본게임에서 화염 발사·화상·서리·시점 전환·앱 복귀를 확인했으며 Godot 수명·정지·재사용·사거리 캐시 검사를 통과했다. 1배속 60초 에뮬레이터 재측정은 화염 전투 갱신 23.01회/초, Flutter raster 평균 24.92ms로 **60 FPS 목표 미달**이다. 실기기 지속 성능은 미검증이다.
- 이번 배포는 Android 본게임만 대상이다. 서버·DB·웹 배포, Flame 전체 제거·Godot 전투 이관은 포함하지 않는다. 제작 원본·검증용 앱·미사용 실험 파일은 이번 코드 커밋에 일괄 추가하지 않았다.

## 2026-09-14 본게임 APK 0.1.15 / code 6024 배포

- 대상 커밋: `244648bacb79593e211f5e202f4ba55ff07656cb`.
  [APK workflow 34764359633](https://github.com/Sejiiinn/RuneNexus/actions/runs/34764359633) 전체 성공.
  [공개 release apk-6024](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6024)의 태그 커밋도 일치한다.
- 스테이지 2~10 3D 전장·챕터 2 환경, 둥근 대포 포탄, 전장 로딩·시점 전환, 그래픽 설정과 렌더링 최적화를 포함한다.
  분석·전체 Flutter 테스트·Python APK 검사 23개·Android 패치 디코더·최근 세 공개 APK 서명 일치와 패치 복원을 통과했다.
- 최초 실행 34763078973은 위젯 테스트 실패로 종료되어 공개되지 않았다. 네이티브 연결을 제공하지 않는 공통/2D 테스트의 플랫폼 fixture와 그래픽 설정 로드 기대값을 수정한 뒤 전체 검사를 다시 통과했다.
- 실제 공개 APK: **411,353,104 bytes (392.30 MiB)**, SHA-256
  `b69113beeb2aba7b69d055053be0e1d769e603bca3e0f0e0094488d0393599a7`.
  이전 공개 6023의 384,821,388 bytes 대비 **26,531,716 bytes (25.30 MiB, 6.89%) 증가**했다.
  배포 전 발견한 과대 로컬 APK 479,597,500 bytes에서는 **68,244,396 bytes (65.08 MiB) 감소**했다.
- CPU 3종을 유지했다. ZIP 압축 후 네이티브 크기는 arm64-v8a 92,823,440 / armeabi-v7a 94,085,636 / x86_64 97,284,016 bytes다.
  Flutter 에셋 38,972,335 bytes, Godot PCK **86,203,724 bytes·217항목·완전 중복 0 bytes**다.
  Flutter 원본 GLB·design 제작 원본·미사용 ANGLE가 공개 APK에 없는 것도 확인했다.
- GLB 텍스처를 무손실 공유하고 이전 빌드 자산을 정리했으며, 기존 포탄 체적 데이터를 원본 바이트로 복원되는 gzip으로 압축했다.
  남은 증가는 주로 스테이지별 지형·환경과 최적화 타일 scene 리소스다. [원인·품질·실행 검증](analysis/godot_packaging_20260913/README.md)을 따른다.
- 차등 패치: **6023 → 6024는 96,210,679 bytes (91.75 MiB)**, 2002 → 6024는 96,369,800 bytes,
  13 → 6024는 172,473,082 bytes다. 공개 APK·세 패치·update.json을 직접 다운로드하여 실제 크기와 모든 SHA-256을 릴리스 및 메타데이터와 대조했다.
  latest와 버전별 update.json의 바이트가 일치하며, 공개 6023/6024 APK를 직접 검사해 서명 인증서가 같은 것도 확인했다.
- Android 에뮬레이터에서 일반 앱의 1장·2장 재질, 고정/드론 시점과 대포 설치·전투를 확인했다. 사용자 실기기의 설치·로그인·지속 성능은 별도 확인이 필요하다.
- 이번 배포는 기존 CPU 3종을 지원하는 Android 본게임 업데이트이며 웹·서버·DB 배포와 엔진 전체 이관은 포함하지 않는다.

## 2026-09-13 본게임 APK 0.1.14 / code 6023 배포

- 대상 커밋: `84e73936d83b1f3d311e3410459d3338a351bcb1`.
  [APK workflow 34739180467](https://github.com/Sejiiinn/RuneNexus/actions/runs/34739180467) 전체 성공.
  [공개 release apk-6023](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6023)의 태그 커밋도 일치한다.
- 본게임 패키지 `com.example.rune_nexus`와 기존 서명을 유지한 업데이트다.
  분석·전체 Flutter 테스트·Python 검사·Android 패치 디코더·기존 세 공개 APK와의 서명 일치 및 패치 복원 검증을 통과했다.
- 실제 공개 APK는 384,821,388 bytes (367.00 MiB), SHA-256
  `3ceca36394f15b56dea8bc045ccc6ea3d9482e1caf0685f62505ba3e38abdff6`.
  이전 공개 2002의 414,151,176 bytes 대비 29,329,788 bytes (27.97 MiB, 7.08%) 감소했다.
- ZIP 압축 후 네이티브 크기는 arm64-v8a 92,692,368 / armeabi-v7a 93,954,564 / x86_64 97,218,480 bytes로 세 ABI를 유지한다.
  Godot PCK는 59,999,688 bytes. 신규 폰트·상태 표시·효과 모듈이 포함되며,
  제거한 ANGLE, Flutter GLB 중복, design 제작 원본은 공개 APK에 없다.
- 차등 패치: 2002 → 6023은 60,555,784 bytes, 13 → 6023은 137,370,986 bytes,
  12 → 6023은 147,377,144 bytes. 공개 APK와 세 패치를 직접 다운로드해 모든 크기·SHA-256을 확인했다.
  latest와 버전별 `update.json`의 실제 바이트도 일치한다.
- 기능·화면 검증은 [표현 이관 검증 기록](../design/stage1_3d/presentation_migration/README.md)을 따른다.
  공개 6023의 사용자 실기기 설치·로그인·장시간 성능은 아직 확인하지 않았다.
- 이번 요청은 Android 본게임 배포이며 웹·서버·DB는 배포하지 않았다.

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

위 6025 항목의 Android 공개 배포는 완료했다. 로컬에 남은 제작 원본·검증 도구·문서 정리는 본게임 미배포 기능과 구분한다. 웹·서버·DB는 이번 배포 범위에 포함하지 않는다. Flame 제거·전투 전체 Godot 이관은 미구현이며 배포만 남은 상태가 아니다.

## 기록 유지 규칙

- 배포가 필요한 코드 변경에는 필요한 migration·환경 설정·선행 조건을 함께 기록한다.
- 배포 후 구성 요소별 커밋, workflow/release, 검증 결과와 한계를 갱신하고 미배포 항목을 정리한다.
- 실패·부분 완료는 구성 요소별로 기록한다. 과거 대화나 로컬 작업 기록만으로 완료를 판단하지 않는다.
- 비밀번호, 토큰, 암호화 키, DB 백업 내용은 이 문서나 커밋에 넣지 않는다.

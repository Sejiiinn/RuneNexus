# 배포 상태와 세션 간 인계

배포 요청을 처리할 때 이 문서와 [운영 배포 절차](self_hosted_api_deployment.md)를 먼저 확인한다.
이 문서는 마지막으로 검증한 이력이며 실시간 운영 상태가 아니다. 배포 직전 실제 DB 버전,
실행 중인 API 이미지, 공개 웹 커밋, 최신 APK release를 다시 확인한다.

## 마지막 확인된 운영 상태

2026-09-10, 0.1.11 배포 완료 기준:

- 배포 커밋: `de7a8785420ead9e5644b44f4951cbf95971b970`.
- API: `rune-nexus-api:de7a878`, 이미지 revision label 일치. 운영 DB migration 010 유지.
  컨테이너 healthy, 외부 HTTPS health/live·health/ready 정상.
- 웹 workflow: [34422435689](https://github.com/Sejiiinn/RuneNexus/actions/runs/34422435689) 성공.
  [공개 웹](https://sejiiinn.github.io/RuneNexus/)의 index·bootstrap·main.dart.js HTTP 200,
  JS의 배포 커밋·운영 API 주소 및 중화기 젬 이미지 해시 일치 확인.
- Android workflow: [34422437252](https://github.com/Sejiiinn/RuneNexus/actions/runs/34422437252) 성공.
  최신 공개 release는 [apk-12](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-12),
  versionCode 12, versionName 0.1.11.
- 공개 latest/update.json과 apk-12/update.json이 동일하다. 전체 APK 및 apk-9·10·11용
  패치의 공개 파일 크기·SHA-256이 매니페스트 및 GitHub 자산 메타데이터와 일치한다.
  APK 크기는 89,983,024 bytes, SHA-256은 `c590ae601fd7dfabbde4ae45f4c4db2ce97af1186c4fb3e2bb4f3e5191d022c3`이다.
- 배포 전 DB 백업의 pg_restore 목록 검사와 별도 PostgreSQL 18 전체 복원 완료.
  백업과 비밀 환경값은 Git에 넣지 않는다.

## 이번 배포 변경

- 일일·주간 개별 임무와 출석 다이아 보상 2배. 일일 전체 완료는 다이아 40 + 모듈권 1개,
  주간 전체 완료는 다이아 100 + 모듈권 4개. 기존 수령 이력·영수증을 유지하며 소급 지급하지 않는다.
- 앱 복귀 시 리더보드 저장 권한 경합 수정.
- 젬 보상 카드 설명의 가독성·높이·상단 정렬 개선, 중화기 젬을 네 기둥 원석 아이콘으로 교체.
- 핀치 확대·축소 방향 수정. 범위 피해가 있는 경우에만 효과 범위 스탯 표시.
- 저장 동기화·젬 장착·임무 보상 규칙 통합. 전투 피해 실행, 적 렌더링, 카메라·드래그,
  보상 젬 선택의 책임 분리.
- API 지급표를 먼저 교체한 뒤 웹·APK를 배포했다. DB migration·환경값·저장 형식 변경 없음.
  API 환경값과 인증 영수증 암호화 키의 동일성을 교체 전후 확인했다.

## 검증 범위와 복구 참고

- 웹·APK CI의 Flutter 정적 분석·전체 테스트 통과.
- Go 1.26.5 전체 단위 테스트·go vet 통과. 격리 PostgreSQL 18에 001~010 마이그레이션 후
  전체 DB 통합 테스트 통과. 운영 백업도 별도 DB에 실제 복원했다.
- APK CI에서 기존 서명 동일성과 Android 패치 디코더, 최근 3개 버전용 차등 패치의
  Python·Kotlin 복원 검증 및 임시 서명 파일 정리를 통과했다.
- 보상 지급량·중복 수령 방지·저장 복원·UI 표시는 관련 테스트로 확인했다.
  Mac 잠금으로 실제 앱 화면 확인은 제한됐고 보상 화면 테스트 렌더에도 폰트 한계가 있었다.
  운영 계정의 실제 기기 로그인·보상 수령·APK 설치 검증은 포함하지 않았다.
- 이전 API 이미지 `rune-nexus-api:4e8eb9b`를 유지한다. API 롤백과 DB down은 별개이며
  이번 배포에는 DB down이 필요하지 않다. 롤백 시 구 클라이언트의 보상 표시와 서버 지급량
  차이를 함께 확인한다. 이미 발급한 영수증의 지급량은 유지된다.

## 미배포 항목

이번 요청 범위의 미배포 코드 변경 없음. 배포 기록 문서 커밋은 실행 산출물을 바꾸지 않는다.

## 기록 유지 규칙

- 배포가 필요한 코드 변경에는 필요한 migration·환경 설정·선행 조건을 이 문서에 함께 기록한다.
- 배포 후 검증된 커밋, DB 버전, workflow/release, 검증 결과를 갱신하고 미배포 항목을 정리한다.
- 실패·부분 완료는 구성 요소별로 기록한다. 과거 대화나 로컬 작업 기록만으로 완료를 판단하지 않는다.
- 비밀번호, 토큰, 암호화 키, DB 백업 내용은 이 문서나 커밋에 넣지 않는다.

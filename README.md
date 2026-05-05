# Rune Nexus

Flutter + Flame 기반 모바일 로그라이트 타워 디펜스 데모입니다.

## 현재 범위

- 모바일 세로 화면 기준 Flutter + Flame 게임
- 8 x 10 고정 Grid 맵과 고정 경로 적 이동
- 스테이지 1~5 선택 화면
  - 현재는 스테이지 1만 기본 해금
  - 스테이지 클리어 시 다음 스테이지 해금
  - 스테이지별 최고 라운드/클리어 기록 표시
- 50라운드 데모 웨이브
- 포탑 3종
  - 기관총: 빠른 단일 물리 공격
  - 대포: 느린 범위 물리 공격
  - 화염: 마법 피해와 짧은 화상 지속피해
- 적 4종
  - 일반
  - 빠름
  - 탱커
  - 보스
- 젬 보상과 포탑 링크 시스템
  - 라운드 보상 젬 선택
  - 포탑별 젬 장착/해제
  - 2링크/3링크 확장
  - 공격속도, 사거리, 물리/마법 피해, 경량/중화기, 지속피해, 폭발, 연쇄 젬
- 전투 중 포탑 설치/레벨업/링크 확장
  - 젬 장착/해제는 준비 단계에서만 가능
- 로컬 저장과 복구
  - 진행 중 라운드의 포탑, 적 HP/이동 상태, 스폰 큐 저장
  - 급작스러운 종료 후 재실행 시 복구 대기 오버레이 표시
  - 투사체는 저장 대상에서 제외
- 룬 기반 영구 업그레이드 기초
  - 시작 골드 증가
  - 넥서스 체력 증가
- 한국어/영어 문구 구조
- Flutter Web 데모 빌드 검증

## 실행

```bash
flutter pub get
flutter run
```

웹 데모 빌드:

```bash
flutter build web --pwa-strategy=none
```

로컬 정적 서버 예시:

```bash
python -m http.server 54546 --bind 127.0.0.1 -d build/web
```

Flutter Web은 서비스 워커 캐시 때문에 변경 사항이 바로 보이지 않을 수 있습니다. 개발 중에는 `--pwa-strategy=none` 빌드를 사용하거나 브라우저 캐시/서비스 워커를 갱신해야 합니다.

## 검증

현재 작업 기준으로 아래 명령이 통과합니다.

```bash
flutter analyze
flutter test
flutter build web --pwa-strategy=none
```

## 주요 문서

- [구현 현황](docs/implementation_status.md)
- [데모 앱 작업 계획서](docs/demo_mvp_work_plan.md)

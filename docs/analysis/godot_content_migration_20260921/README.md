# 실제 콘텐츠·전투 설정 이관

역할: 2026-09-21 독립 Godot 콘텐츠 설정 경로의 구현·검증 기록. 기준은 `da51957` 이후 이번 작업 트리이며 커밋·푸시·배포하지 않았다. 2단계 일부 완료이며 전체 런·성장·Flutter 제거 완료가 아니다.

## 바뀐 책임

- `godot/content/content_catalog.gd`가 실제 스테이지 지도·경로·웨이브·적 구성·포탑 기본값을 읽고 전투 설정을 조립한다. 기존 전투 런타임과 스탯 계산기를 그대로 사용한다.
- 기본 `--session`에서 실제 편성을 시작하고 다음 웨이브로 진행한다. 개발 UI에 포탑 종류·검증 웨이브 선택을 추가했다. 건설은 무료 개발 조작이며 경제 지급·구매 처리가 아니다.
- 좌표는 기본 1타일, 원본 48px 대비 `boardDistanceScale=1/48`이다. 이동 속도와 이미 환산한 반경·표시 크기·연쇄 사거리를 구분한다. 스폰 지연은 원본 WaveSpawner 순서와 포탈 대기×배속을 적용한다.
- 차선·시각 위상·다이아 보유량은 추출된 규칙으로 만들어 명시 입력으로 전달한다. 같은 seed의 Dart/Godot 난수열 일치를 요구하지 않으며 비교는 같은 명시 값으로 한다.
- 성장·장착은 기존 statInput의 레벨·젬·특성·모듈 효과·보정 배율을 입력받는다. 구매·장착 가능 여부·저장 모델에서 해당 값을 결정하는 앱 도메인은 아직 Dart에 있다. 공격 코어 기본값은 미선택이며 선택·라운드별 설정은 후속 범위다.

## 단일 원본·생성 경로

원본은 Dart `lib/data/definitions/`, 공유 spawn 규칙 및 기존 컴포넌트/스포너다. [추출기](../../../tool/content/README.md)가 `godot/content/game_content.json`과 비교용 `test/fixtures/game_content_cases.json`을 생성한다. 양쪽 수동 편집은 하지 않는다. 전체 생성물 일치 검사가 원본 변경 후 재생성 누락을 잡는다.

Godot 실행은 Dart/Flutter 프로세스를 요구하지 않는다. 준비 스크립트의 맵 검증 자료도 생성 JSON을 읽도록 바꿔 Dart 소스 정규식 추출을 제거했다. **콘텐츠 재생성·Dart 대조 검사에는 Flutter/Dart SDK가 아직 필요하다.** 기존 앱 전체의 Flutter 빌드·배포 의존성은 제거하지 않았다.

## 검증

- 전체 15 스테이지·600 웨이브·11,083 스폰·적 8종·포탑 6종의 정의/순서/지연/타입을 Dart 생성 결과와 대조했다. 적 128구성(4스테이지×2라운드×2좌표 스케일×8종)과 기본/성장 포탑 12구성은 실제 Dart 컴포넌트 결과를 비교 기준으로 사용한다.
- `verify_content_catalog.gd`: 전체 설정과 기존 성장 fixture, 챕터 대표 마지막 웨이브의 모든 적·3종 보스·경로 도착·코어 피해·웨이브 종료·화살포탑 공격을 검증했다. 정확한 검사 건수는 `content-catalog.log`의 PASS를 따른다. 모든 도착을 관찰하는 검사만 코어 최대 HP를 명시적으로 높이며 적 수치는 그대로다.
- `test/godot_content_export_test.dart` 및 기존 `native_wave_game_test.dart`, `native_combat_game_test.dart`: 10개 통과. `flutter analyze`: 문제 없음.
- 저장 codec·Godot native regression·포탑 stat 검사는 338개 통과했다. 기존 독립 fixture 세션 검사와 **서로 다른 write/read 프로세스**의 저장 재시작도 통과했다.
- `scripts/test_prepare_godot_project.py`: 1개 통과. Dart 소스/SDK 없는 임시 프로젝트에서 생성 콘텐츠를 준비한다.
- `verify_content_session.gd`: 기본 실제 콘텐츠 진입, 챕터별 6종 건설/공격, 실제 편성·보스, 중복 시작 방지, 정지/4배속, 저장 거절과 기존 슬롯·이벤트 보존을 검사했다. headless와 실제 Metal 실행을 확인했다.

## 실제 화면

Godot 4.7.2, macOS Apple M4, Metal Forward Mobile, 880×760 독립 앱에서 스테이지 1/6/11의 실제 전장·6종 포탑과 5/10/15 최종 웨이브의 보스/편성/이동을 확인했다. 승인 전장·포탑·적 자산은 수정하지 않았다. 개발 UI 문구를 짧게 정리하고 줄바꿈을 적용했다. 화면은 `build/godot/captures/content-stage-{1,6,11}.png`, `content-boss-stage-{5,10,15}.png`에 있다.

이는 독립 실행 경로의 시각 확인이다. Android 본게임은 새 로더를 사용하도록 전환하지 않았으므로 APK 설치·HUD·실기기 성능 검증 완료로 보고하지 않는다.

## 저장과 남은 범위

실제 콘텐츠 세션의 저장/로드는 ERR_UNAVAILABLE로 **ACK·파일 쓰기·장면 변경 전에 거절**한다. 경제 이벤트는 아직 소비하지 않아 현재 scene epoch에 보존하며 스테이지 변경/종료 때 검증 런과 함께 버린다. 본게임 경제나 보상 권위를 이전하지 않았다.

기존 고정 설정은 명시적 `--session --session-fixture` 또는 회귀 스크립트에서만 사용한다. 기존 v1/v2, 타입 검사, checkpoint 제한과 별도 프로세스 재시작을 보존했다. 저장 지원 제한을 없애거나 새 콘텐츠를 잘못 복원하지 않는다.

다음은 런·성장 명령(건설 비용/강화/판매/젬/특성/일반 성장), 설정 재구성을 포함한 본게임 저장 연결과 기존 설치 디렉터리 인계다. 그 뒤 Flutter HUD·보상·결과 및 계정·로비·패키징을 이관한다. 브라우저 다중 탭/Web Locks, Windows 파일 교체와 Android 실제 업그레이드 검증도 남아 있다.

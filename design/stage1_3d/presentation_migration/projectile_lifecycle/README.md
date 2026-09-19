# 공통 탄환 표시 이벤트와 재사용

확인: 2026-09-19. 대상: Android Godot 탄환 표시와 Flame 2D 잔상. 배포·전투 판정·저장 형식 변경 없음.

## 변경과 유지한 계약

- `ProjectileComponent`는 3D 투영이 활성인 동안 2D 잔상 좌표 복사·목록 갱신을 생략한다. 3D 전환 때 이전 잔상은 비우고 2D 복귀 때 현재 위치부터 다시 쌓는다. 실제 이동·충돌·피해·체인 판정은 Flame에 남는다.
- `nativeProjectileEvents` 지원 확인 뒤 공통 탄환은 발사·종료 이벤트로 전달한다. 매 프레임 탄환 DTO와 좌표 배열 생성을 생략하며, Godot은 초기 위치·방향·속도와 공용 전투 시계로 표시 좌표를 계산한다. 적용 확인 전 재전송, 재연결의 생존 탄환 재등록, 강제 제거와 장면 초기화를 처리한다. 미지원 경로는 기존 전체 스냅샷을 유지한다.
- 저격·냉기의 일반 탄환 노드도 종류별 풀에 반환한다. 기존 기관총·대포·화염 풀과 공용 메시·재질은 유지한다. 현재 전투 정의에서 저격·냉기는 즉발 공격이므로 일반 탄환 입력의 재사용 검증과 실제 해당 포탑 공격을 구분한다.
- 기존 총구 연결·체인 원점·명중 좌표·기관총/대포/화염 종료 잔여 표시를 유지한다. 카메라 이동은 탄환 전투 시계를 진행시키지 않는다.

## 검증

- Flame 잔상 6종의 2D → 3D → 2D 전환 및 이동 보존, 기존 선분 충돌·최대거리·체인 테스트: 11개 PASS.
- 탄환 이벤트/기존 프레임/충돌 관련 테스트 19개와 적체 복구 추가 후 탄환 표시 테스트 12개 PASS. 두 실행에는 중복된 탄환 검사가 포함된다. [관련 로그](projectile-tests.log), [추가 검사](projectile-tests-final.log).
- Godot 표시 뷰·수명 테스트 17개 PASS. 미지원·오류의 2D 복귀 포함. [로그](view-lifecycle-tests.log).
- Godot `verify_projectiles.gd`, `verify_presentation_protocol.gd` PASS. 이동·정지·남은 거리·종료·중복·세대 교체·오래된 이벤트·취소와 저격/냉기 풀 재사용을 확인했다. [탄환](projectile-godot-final.log), [프로토콜](projectile-protocol.log). headless dummy renderer에서는 MultiMesh GPU readback을 제공하지 않아 숨김·초기화 상태를 검사했다.
- 최종 `flutter analyze`와 Android release APK 빌드/업데이트 설치 PASS. 기존 검수 앱의 저장을 보존하려고 같은 로컬 버전 코드 2008로 설치했다. [분석](analyze-final.log), [빌드](android-build.log), [입력 해시](inputs.json).
- Android 17 ARM64 에뮬레이터(`emulator-5554`, 1080×2424), Godot 4.7.2, 일반 `lib/main.dart` 본게임 스테이지 1 저장 진입. 1배속 기관총·화염·대포 동시 사격과 착탄, 4배속/드론 전환 및 웨이브 종료 후 잔류 없음 확인. [1배속 사격](video-check-2.png), [종료/드론](combat-4x-drone.png), [전투 영상](combat.mp4). 4배속에서도 실제 사격과 착탄을 확인했고([화면](video-4x-2.png), [영상](combat-4x.mp4)), 백그라운드 복귀 후 20웨이브 보상 정지 화면과 탄환 정리를 확인했다([복귀](resumed.png)). 검수 후 보상 선택 상태를 유지했다. 새 실행의 Android 로그에서 Godot 스크립트·표시 오류와 앱 fatal 예외가 발견되지 않았다. 녹화는 시각 확인용이며 FPS 성능 측정 자료가 아니다.

## 성능 해석

줄어드는 작업은 Flame 잔상 좌표 할당, 탄환별 반복 DTO/직렬화·전달, 저격·냉기 표시 노드 생성/해제다. Godot의 탄환 위치 갱신과 GPU 그리기는 남는다. 에뮬레이터 확인은 실기기의 전체 FPS·p95/p99·발열 개선을 증명하지 않으며 해당 성능은 미측정이다.

후속 요청으로 기존 60초 통합 FPS 측정을 재실행했다. 에뮬레이터 대포 44.06 / 화염 31.47 Flutter 갱신/초. 과거 기록 대비 변화와 계측 범위·한계는 [FPS 측정 기록](../../../../docs/analysis/projectile_fps_20260919/README.md)을 따른다.

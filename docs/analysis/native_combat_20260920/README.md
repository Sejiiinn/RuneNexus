# Android 3D 실제 전투 이관 검증

2026-09-20. 실제 전투 소유권을 Godot에 연결한 첫 묶음이다. Flame 전체 제거나 모든 조합의 완전 동등성·실기기 성능 통과 기록은 아니다.

## 구현과 자동 검사

- `godot/combat/native_combat_runtime.gd`: 적·포탑·탄환·번개 지연·명중·상태·처치의 전투 생산자. 기존 순수 스탯/공격 계산을 실제 발사에 사용한다.
- `lib/game/game_native_combat.dart`: 순서 보장 명령과 ACK, 앱 상태 미러·보상 반영·확정 저장·재진입. 같은 전투의 Flame 컴포넌트 갱신을 차단한다.
- `GodotBridge.kt`: 화면 최신 프레임 슬롯과 독립된 전투 명령 슬롯. 응답 번호는 `ackSequence`, 오래된 세대와 중복 명령은 거절한다.
- Flutter 전체 1,268개 통과·12개 건너뜀([로그](flutter-test.log)). 재진입 후속 수정은 준비 상태/진행 중 웨이브 복원 등을 포함한 관련 7개 통과([로그](reentry-test.log)). 최종 분석 지적 없음([로그](analyze.log)).
- Godot 적 상태 45개 검사 통과. 포탑 설정 273개 실행 검사와 정확 피해·발사 간격·조준·광역 저항·치명타·번개 충전/연쇄 지연·죽은 대상·처치 한 번·중복 명령·dt 보존·native 모델/라벨 검사를 통과했다. 설정 273개는 피해 발생 여부의 실행 검사이며 전체 프레임 단위 Dart 동등성 검사가 아니다.

Godot 재현:

```sh
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path godot --script verify_native_enemy_state.gd
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path godot --script verify_native_combat_runtime.gd
```

## Android 본게임

Android 17 ARM64 에뮬레이터 `emulator-5554`, 1080×2424, Godot 4.7.2, Vulkan/mobile, Flutter debug, 일반 `lib/main.dart`, 로컬 검수용 debug panel. 업데이트 URL·계정 API define 없이 로컬 저장으로 검사했다. 에셋·재질·셰이더는 이번에 수정하지 않았다.

| 항목 | 결과와 근거 |
| --- | --- |
| 기존 저장 복원·실제 전투 인수 | PASS. 기존 스테이지 1/23웨이브·포탑 배치를 복원, `NATIVE_COMBAT_ACTIVE` ACK 확인 |
| 이동·사격·피해·상태·웨이브 전환 | PASS. 기관총·대포·화염, 적 내구도·화상, 23→24→25→26 전환과 골드·파편 지급 확인. [전투](combat.mp4), [4배속](combat-4x.mp4) |
| 보상·정지·배속·카메라 | PASS. 25웨이브 젬 보상에서 파편 선택, 메뉴를 연 동안 적 위치 유지, 1×/4×, 두 시점에서 모델·피해 숫자·화상 표시 확인. [카메라](combat-camera.png), [정지](pause.png) |
| 앱 백그라운드·프로세스 재시작 | PASS. OS 홈→복귀에서 전투 세션 유지. 종료 후 기존 저장 복원 화면에서 정지·재개 확인 |
| 메뉴 이탈·준비 상태 재진입 | 초기 FAIL 후 수정 PASS. 이전 epoch를 재사용해 모델이 사라지는 결함을 수정. 확정 저장 복원→새 epoch bootstrap ACK 후 기존 포탑·재화 유지. [재진입](reentry.png) |
| 진행 중 웨이브 재진입 | PASS. 26웨이브 적·포탑을 복원하고 기존 저장 재개 화면에서 정지. [복원](wave-restored.png), [재개 전투](combat-final.mp4) |

최종 로그의 `SUSPENDED → RESTORED → ACTIVE(seq=1)` 두 차례는 준비 상태와 진행 중 웨이브의 실제 메뉴 왕복이다. 최종 APK에서 전투 스크립트 오류·ACK timeout은 발견하지 않았다. 에뮬레이터 Vulkan swapchain semaphore 진단은 발생하므로 엔진/드라이버 무결성이나 실기기 안정성까지 통과했다고 해석하지 않는다. 로비 debug panel의 기존 하단 overflow도 이번 전투 판정 검증과 별도다.

최종 재개 후 26→27웨이브 전환 및 코어 HP 4→3 반영도 확인했다([최종 화면](final-game.png)). 검수 종료 후 앱을 정지하고 사전 백업의 저장·앱 파일 97개를 복원했으며 SHA-256 97/97 일치를 확인했다. 새 APK는 로컬 에뮬레이터에 설치된 상태다.

## 패키징과 한계

최종 로컬 debug APK 562,373,954바이트, PCK 105,997,488바이트. [팩 감사](apk.json): 283개 항목, 완전 중복 페이로드 0바이트, `design/` 원본 미포함. ABI는 기존 Gradle 의존성 결과인 arm64-v8a/armeabi-v7a/x86_64이며 이번에 배포 구성을 바꾸지 않았다. 로컬의 기존 release APK 내 PCK 105,955,364바이트 대비 증가 42,124바이트는 계산/전투 스크립트 추가다. debug와 release의 전체 APK 크기는 빌드 모드가 달라 개선 비교에 사용하지 않는다. 공개 배포·커밋·푸시는 하지 않았다.

웨이브/코어 주기·보상/경제·앱 UI·기존 저장 모델과 2D 지원 경로, Flame 의존성은 남아 있다. 저장 JSON과 native→앱 상태 미러 비용도 남는다. 전체 프레임 동등성, 모든 특성/젬 조합의 실제 Android 화면, 실기기 FPS·p95/p99·메모리·발열은 미측정이다.

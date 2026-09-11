# Android 투사체 가독성

현행 Godot 기관총·대포 투사체 표시 기준. 2026-09-12.

이전 표시에서는 작고 짧은 탄체·예광만 현재 위치에 그렸다. 빠른 근접 탄환이 한 번의 전투 갱신에서 명중하면 `isRemoving`으로 표시 입력에서 제외되어 3D 화면에 한 번도 나타나지 않았다.

현재 표시는 기관총의 황동 탄환과 밝은 예광, 대포의 큰 금속 포탄과 주황 예광을 사용한다. 실제 비행 원점·소유 포탑·발사 순번을 전달하여 총구에 연결하며, 연쇄 탄환은 연쇄가 시작된 위치를 사용한다. 종료된 탄환의 경로는 표시 시계 기준 140ms 동안 소멸한다. 탄체는 명중 즉시 숨기고 지나간 궤적만 남긴다. 근접 사격의 충돌 원 표면이 포신 안에 들어오면 실제 피격 몸체 중심까지 경로를 연결한다. 피해 계산에 쓰는 충돌 위치는 별도로 그대로 보존한다.

`ProjectileComponent`의 이동·충돌·피해·즉시 제거를 유지한다. `RuneNexusGame`의 종료 표시 목록은 3D 스테이지 1의 기관총·대포에만 적용하며, 실제 시간 140ms와 최대 192개로 제한한다. 전투 초기화 때 비우고 저장 데이터에는 넣지 않는다. 기존 ThreeJS 화면에는 종료 탄환을 추가하지 않으며 Godot 표시 입력에서만 합친다. Godot 모델 풀은 유형당 64개를 상한으로 재사용하고 전장 초기화 때 해제한다.

구현은 `godot/effects/ballistic_projectile.gd`, `projectile_tracer.gdshader`와 기존 전장 프레임 직렬화에 있다. 기존 3D 탄체·탄두의 크기와 재질을 조정한 것이며 별도 이미지 아틀라스는 사용하지 않는다.

검증은 Dart 투사체 수명·충돌·표시 입력 검사, `godot/verify_projectiles.gd`, `verify_runtime.gd`와 실제 Android APK 화면에서 수행한다. 녹화 파일의 프레임 간격은 게임 성능 측정으로 사용하지 않는다.

2026-09-12 검증 결과: 관련 Dart 테스트 23개와 정적 분석이 통과했다. Godot 투사체 검사는 실제 Metal Mobile 렌더러에서 실패 0건이며, 런타임 장면 검사도 통과했다. 동일한 PCK를 사용하는 본게임·검수용 Android APK를 빌드하여 Android API 37 에뮬레이터에서 1·4배속과 고정·드론 시점을 확인했다. 본게임 4배속에서는 근접 명중 후 남는 예광이 보이며, 대포 검수에서는 비행 중 금속 포탄과 예광이 보인다. 대포 영상의 첫 구간은 투사체를 가리지 않도록 폭발 볼륨을 끈 상태이며 이후 다시 켰다.

- [본게임 녹화](https://drive.google.com/file/d/1xU8BxSV0jY5tge-GxSoUntQkw_0UoVvb/view) · [대포 검수 녹화](https://drive.google.com/file/d/1RUaJ-JU8PjXpkY6T4TrK4cf0aMAKON1M/view)
- 원본 녹화·메타데이터·검사 로그: [`runtime/`](runtime/)
- 대표 실제 화면: [`runtime/android-main-4x.png`](runtime/android-main-4x.png)

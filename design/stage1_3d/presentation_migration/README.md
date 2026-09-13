# Godot 전장 표시 통합 검증

2026-09-13. Android 본게임 `lib/main.dart`의 스테이지 1 표시 통합 기록이다. [현행 책임·계약](../../../docs/godot_presentation_migration_plan.md)을 따른다. 전투 계산·저장 스키마·Flutter HUD를 변경하지 않았다. 배포·커밋은 수행하지 않았다.

## 확인한 구현

- `labels`: 체력·장갑·보호막, 상태 아이콘, 다이아 표식, 코어 쿨다운.
- `selection`: 현재/예상 사거리, 건설·포탈·코어 선택, 포탑 오라·젬 고리·조준선, 보상 대상 강조. 보상 때만 실제 대상 메시를 공유하는 독립 실루엣 패스를 사용하며 종료 시 비운다.
- `effects`: 피해 숫자·다이아 획득·사망·젬 장착·비blast 착탄·번개 충전/연쇄·코어 빔·균열. 코어 파괴 흔들림은 같은 카메라 기준 world 변환에 적용한다.
- 장면 세대·화면 세대·실제 적용 sequence를 확인한 뒤 해당 Flame 그림을 숨긴다. 짧은 효과는 생성 시 기록하고 256개/종료 후 최대 2초 큐에 보관한다. 전투나 재화 지급을 다시 실행하지 않는다.

## 검증

- Flutter 전체 테스트 **790개 통과, 기존 조건 11개 생략**. 이후 실제 게임의 내구도·상태·선택 자료 수집과 저장 불변성 검사 1개를 추가했고 해당 파일 3개가 통과했다.
- `flutter analyze` 통과, 일반 웹 빌드 통과. Python Godot 준비 검사 1개 통과.
- Godot 표시 계약·객체 라벨·선택·효과·포탑 배지·카메라·탄환 검사 통과. 네이티브 자원 계약 검사 6,560항목 통과.
- 에뮬레이터의 Android 본게임에서 고정/드론, 포탑 선택·사거리, 대포 6문 고체력 표적의 1×/4×, 체력 바와 피해 숫자를 확인했다. 6021 본게임에서 보상 실루엣과 교체 표식·클립, 젬 장착 효과를 직접 확인했다. 6022는 디버그 패널 없는 일반 release APK로 설치했다. 실제 7웨이브 4×에서 피해 숫자·사망 효과·코어 쿨다운과 라운드 종료를 확인했고, 백그라운드 복귀 후 과거 효과 재생 없이 전장·카메라 조작이 유지됐다.
- 실제 지원하지 않는 `shieldBoss` 모델 오류를 발생시켜 2D 전장·보호막/체력 표시와 기존 조작 복귀를 확인했다. 이 모델 미지원은 기존 Godot 모델 범위의 제약이며 이번에 다른 외형의 모델로 대체하지 않았다. [폴백 화면](verification/fallback-unsupported-enemy.png).

## 발견하여 수정한 결함

- Android의 소수 logical viewport가 Godot JSON에서 반올림되어 정상 응답이 거절됨: 세대 검사를 유지하고 1e-6 미만 오차만 허용.
- 사망 파편의 billboard 전환과 피해 문자의 이동 축 변경: 기존 지면 투영과 화면 정면 글자 구분을 복원.
- 젬 효과 합성·선 끝 형태·가변 글꼴 굵기 누락: 원래 합성 방식과 w900 적용 복원.
- 대상 AABB를 밝히는 방식이 주변 지형까지 사각형으로 드러남: [거절한 화면](verification/reward-mask-rejected.png)을 채택하지 않고 실제 메시 실루엣 마스크로 교체.

## 실제 화면

- [최종 일반 APK 4배속 전투](verification/final-wave-4x.png): 6022의 실제 웨이브, 굵은 피해 숫자·적 체력·사망 효과·코어 쿨다운.
- [백그라운드 복귀·드론 시점](verification/final-resume.png): 종료한 웨이브의 효과가 다시 나타나지 않고 8라운드 준비 상태 유지.

- [포탑 선택·사거리](verification/selection-cannon.png): 고정 시점과 기존 상세 패널.
- [4배속·드론 시점](verification/barrage-4x-drone.png): 대포 6문과 고체력 표적 3기(디버그 시나리오).
- [보상 대상 실루엣](verification/reward-silhouette.png): 포탑만 밝게 남기고 주변 지형은 어둡게 유지. 가운데 포탑의 교체 표식도 확인.
- [젬 장착 효과](verification/gem-equip.png): [Android 녹화](verification/gem-equip.mp4)의 1.2초 프레임. 기존 지면 기울기·고리·중심 보석·불티를 유지.

## APK 점검

최종 일반 APK **6022**는 **397,227,684바이트(378.83MiB)**다. 이전 로컬 6015 APK 387,581,280바이트보다 **9,646,404바이트(9.20MiB, 2.49%) 증가**했다. 공개 배포 APK와의 비교는 아니며 외부 배포는 하지 않았다. [ZIP 검사 결과·SHA-256](verification/apk-audit.json).

증가의 대부분은 표시 글꼴·상태 이미지·사망 실루엣을 포함한 PCK(63,005,340→72,405,984바이트)다. 특히 한국어 글꼴은 기존 Flutter UI용과 Godot 표시용 로딩 경로가 분리되어 양쪽에 들어간다. 원본 글리프 범위를 보존했다. 네이티브 라이브러리의 ABI별 총크기는 arm64-v8a 92,692,552바이트, armeabi-v7a 93,954,748바이트, x86_64 97,218,664바이트다. 세 ABI를 유지했고 ANGLE·Flutter 측 3D 에셋 중복·design 원본 포함은 없다. 양쪽 글꼴 OFL 고지도 PCK에 포함된 것을 확인했다.

## 자원과 재생성

화상·감속 이미지는 기존 [상태 이미지](../battlefield_labels/README.md), 사망 실루엣은 기존 `drawEnemyShape`를 그대로 내보냈다. `tool/export_battlefield_label_sprites.dart`와 `tool/export_battlefield_death_silhouettes.dart`를 프로젝트 Flutter test 명령으로 실행하면 재생성된다. 매 프레임 이미지 전송은 없다.

숫자는 `assets/images/stage1_3d/ui/Roboto-VF.ttf`, 한글 fallback은 기존 `assets/fonts/NotoSansKR-VF.ttf`를 사용한다. PCK에는 각 런타임이 읽는 자원과 Roboto/NotoSansKR OFL 고지를 포함한다. Noto 고지 출처는 [Google Fonts 공식 저장소](https://github.com/google/fonts/blob/main/ofl/notosanskr/OFL.txt)다.

## 범위·남은 검증

연결된 기기는 Android ARM64 에뮬레이터다. 기준 모바일 실기기의 지속 전투 p95/p99·메모리·발열 후 성능 저하는 **미검증**이며 성능 수용 완료로 취급하지 않는다. 모든 효과·모든 상태 조합의 Android 캡처를 망라한 검수는 아니며, 원본 대조·계약 검사와 실제 대표 화면을 구분한다. 거절된 코어 재질 실험의 채택 여부는 이 표시 통합의 검증 대상이 아니다.

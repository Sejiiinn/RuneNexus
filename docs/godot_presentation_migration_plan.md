# Godot 전장 표시 통합 구현과 검증

역할: Android 본게임 스테이지 1의 **현행 표시 소유권·이관 구현·남은 검증**. 갱신: 2026-09-13. 최초 후속 제안을 바탕으로 `labels`·`selection`·`effects` 세 묶음을 구현하고 공용 Godot 런타임에 연결했다. 구현 상태와 시각·성능 검증 상태는 구분한다. 최종 APK·검사 수치·실제 캡처는 [표시 이관 검증 기록](../design/stage1_3d/presentation_migration/README.md)을 따른다.

## 현행 책임

Godot은 전장 모델과 전장에 붙는 정보·선택·효과를 같은 카메라로 표시한다. Flutter는 로비·HUD·패널·보상 카드·교체 UI와 화면 전체 피격 경고를 유지한다. Dart/Flame은 전투 갱신·타깃 선택·피해 판정·웨이브·경제·저장·효과 진행도를 계속 결정한다. 저장 스키마와 전투 규칙은 변경하지 않았다. Flame 컴포넌트 생성·갱신을 제거한 작업이 아니다.

Godot이 해당 묶음을 실제 적용했다고 응답한 경우에만 대응하는 Flame 그림을 생략한다. 미지원 묶음은 기존 표시를 유지하며 오류·화면 종료에는 소유권과 투영을 해제한다. 다른 스테이지·플랫폼과 2D 오류 복귀 경로는 유지한다.

| 표시 | 현행 표시 소유권 |
| --- | --- |
| 지형·포탈·코어·포탑·적 본체·건설 미리보기 | 기존 [Godot 장면](../godot/main.gd). 원본 형태·재질은 이 이관의 변경 대상이 아님 |
| 탄환·예광·기관총 포구·대포 입체 폭발 | 기존 [Godot 효과](../godot/effects/ballistic_projectile.gd)와 [입체 폭발](../godot/effects/godot_impact.gd). 종료 탄환의 140ms 표시 보존 유지 |
| 포탑 레벨 배지 | 기존 [Godot 배지](../godot/ui/turret_level_labels.gd). `nativeTurretLevels` 적용 확인 후 Flame 배지 생략; 고정 받침 하단 기준과 공용 배지 원본 유지 |
| 적 체력·장갑·보호막, 상태·균열·다이아 보유 표식, 코어 쿨다운 | `labels`: [Dart 표시 입력](../lib/game/game_battlefield_labels.dart) → [Godot 라벨](../godot/ui/battlefield_labels.gd). 내구도와 상태·활성·색·진행도는 Dart가 전달 |
| 사거리·레벨업 예상 범위·포탑 선택·레벨 오라·젬 고리·즉시 조준선 | `selection`: [Dart 표시 입력](../lib/game/game_battlefield_selection.dart) → [Godot 선택 표시](../godot/ui/battlefield_selection.gd). 중심 광역 공격의 실제 반경과 예상 반경을 Dart에서 계산 |
| 건설칸·건설 사거리·포탈/코어 선택·젬 보상 대상 강조와 dim | `selection`. Godot이 보상 중에만 대상 포탑의 메시를 공유하는 실루엣 마스크를 렌더해 모델만 밝게 유지하고 금색 테두리·교체 표식을 그림. 지형·전투 장면을 복제하지 않으며 보상 종료 시 마스크 렌더를 중지·해제. Flutter 보상 패널은 유지하며 전달된 viewport 밖으로 강조가 나오지 않도록 클립 |
| 피해 숫자·약점/저항 구별·다이아 획득·비blast 착탄·사망 파편·젬 장착 | `effects`: [Dart 표시 입력](../lib/game/game_battlefield_effects.dart) → [Godot 효과](../godot/ui/battlefield_effects.gd). 수치·보상 지급·사망 처리는 Dart에 유지 |
| 번개 충전·연쇄 선·코어 빔·균열 파동 | `effects`. 시작/끝·종류·현재 진행도를 전달; 연쇄 타깃과 명중은 기존 로직이 결정 |
| 코어 파괴 전장 흔들림 | `effects` 입력의 변위로 Godot `world`를 이동하고 해당 묶음 적용 시 기존 Canvas 흔들림 생략. 정보·선택도 같은 world 변환을 투영 |
| 피격 화면 경고·HUD·건설/상세/보상 패널·버튼·입력 차단 | 기존 Flutter/Flame 유지 |
| 일반 2D 그림·입력 | 다른 스테이지·플랫폼과 오류 복귀용으로 유지 |

[SequentialLightningChainComponent](../lib/game/components/sequential_lightning_chain_component.dart)는 지연·다음 타깃·명중을 수행하므로 유지한다. Projectile/Enemy/Turret도 그림의 소유권만 구분한다.

## 적용 확인과 수명 계약

[프레임 직렬화](../lib/game/rendering/stage1_3d/godot_battlefield_frame.dart)는 기존 모델 자료와 명시적 DTO인 `presentation.labels`·`presentation.selection`·`presentation.effects`를 전달한다. Godot의 모듈 registry는 자원 초기화·입력·요청 상태를 확인하고 실제 표시한 묶음만 `appliedGroups`로 반환한다. Kotlin `submitFrame` 완료나 엔진 ready만으로 Flame 표시를 숨기지 않는다.

[반환 검증](../lib/game/rendering/stage1_3d/battlefield_presentation_state.dart)은 표시 버전 2, `sceneEpoch`, `viewportRevision`, viewport 크기와 적용 sequence를 확인한다. 오래된 장면·리사이즈 전 응답·역행 또는 미제출 sequence·잘못된 투영은 거절한다. Godot JSON 직렬화의 소수 반올림에 한해 크기 차이 `1e-6` 미만을 허용하며, 실제 리사이즈는 revision과 크기로 계속 구분한다. 같은 적용 sequence의 새 카메라 투영은 허용한다.

장면 초기화는 Kotlin의 우선 reset 처리를 유지한다. 새 epoch·리셋·화면 소유권 변경 때 라벨·선택·효과·전송 대기 자료와 투영을 정리하고, 이전 view의 지연 응답·dispose가 새 view 상태를 덮지 않도록 한다. 표시 DTO에는 저장 객체를 넣지 않는다.

## 프레임 생략과 짧은 효과

브리지가 최신 프레임으로 합칠 때 한 simulation tick 안에 생성·종료된 효과를 놓치지 않도록 생성 시점에 자료를 등록한다. [효과 큐](../lib/game/rendering/stage1_3d/battlefield_effect_queue.dart)는 최대 **256개**, 종료 뒤 미확인 자료는 배속·정지와 독립적인 시각 기준 최대 **2초** 보존한다.

- 살아 있는 효과는 최신 age와 좌표로 갱신한다. 늦거나 반복된 자료로 진행도를 되감지 않고, 종료 샘플로 마지막으로 그릴 수 있는 샘플을 덮지 않는다.
- 실제 전송 프레임에 포함한 ID의 최초 sequence를 기록한다. Godot의 누적 적용 sequence 확인을 받은 종료 효과는 제거한다. 브리지에서 생략한 프레임 뒤에도 대기 자료가 최신 프레임에 함께 실린다.
- 적용 확인이 없더라도 종료 효과는 2초 뒤 만료한다. 용량을 넘으면 오래된 종료 자료를 먼저 제거하고, 모두 살아 있으면 오래된 항목부터 상한을 유지한다. 무제한 전달 보장이나 과거 효과 일괄 재생을 하지 않는다.
- 큐는 전투 진행도를 스스로 증가시키거나 종료 효과를 새로 시작하지 않는다. 전투 정지·배속·코어 파괴 감속은 기존 컴포넌트의 age/progress를 따른다. 자료 보존 때문에 피해·재화 지급을 다시 실행하지 않는다.

## 카메라·입력·합성

고정↔드론의 0.7초 cubic ease-out과 전환 중 재입력은 기존 Godot 카메라를 유지한다. 전투 정지·배속과 독립적으로 움직인다. 카메라 tween 갱신 때 redraw를 예약하고 `RenderingServer.frame_pre_draw`에서도 현재 카메라와 world 변환으로 위치를 확인한다. 선택의 선 두께·배율과 보상 클립은 논리 타일 크기·실제 viewport 배율을 반영한다.

Flutter는 Godot이 반환한 같은 장면·viewport의 투영을 건설/선택 입력과 보상 패널 anchor에 계속 사용한다. Godot에 중복 터치 판정을 추가하지 않는다. Flutter의 전장 dim은 `selection` 적용 확인 뒤 생략하여 Godot 대상 모델 강조를 가리지 않는다. HUD와 화면 전체 피격 경고는 기존 합성 경로에 남는다.

`frame.time`의 기존 `_spaceTime`은 배속 독립이며 1200초마다 순환한다. 이를 모든 효과의 전투 시계로 사용하지 않는다. 효과는 전달된 age/progress, 선택 고리는 해당 컴포넌트의 phase를 사용한다.

## 단계별 구현 상태와 검증

| 단계 | 구현 상태 | 확인 범위와 남은 검증 |
| --- | --- | --- |
| 1. 계약·소유권 | 구현·런타임 연결 | DTO·소수 viewport·장면 세대·적용 확인·지연 응답·리사이즈·지원 철회·리셋 회귀 검사. 저장 불변성과 타일 입력 검사 유지 |
| 2. 객체 부착 정보 | `labels` 구현·연결 | Godot 라벨·카메라 검사 및 Android 실제 3D 전장의 라벨 확인. 작은 화면의 중첩 상태·모든 내구도 조합 확인 범위는 최종 검증 기록 참고 |
| 3. 선택·보상 대상 | `selection` 구현·연결 | Dart DTO 검사, Godot 카메라·실제 메시 실루엣·교체 표식·viewport 검사. OpenGL 실제 픽셀 검사에서 모델 밖 지형과 clip 밖 dim 유지·카메라 이동·마스크 수명 확인. Android 선택 표시 확인; 설치/철거/취소/젬 교체의 최종 확인 범위는 검증 기록 참고 |
| 4. 숫자·짧은 이벤트 | `effects`와 유한 큐 구현·연결 | 단일 tick 효과·최신 age·적용 확인·만료·상한·초기화 검사. 최종 숫자 글꼴 반영 APK의 1×/4×·정지·복귀 화면 확인은 검증 기록에 남김 |
| 5. 잔여 전투 효과·흔들림 | `effects`와 world 변환 구현·연결 | 효과 종류·카메라·초기화 검사, 기존 연쇄/코어/착탄 회귀 검사. 전체 효과별 Android 시각 확인 범위는 검증 기록 참고 |
| 6. Canvas 중복 제거·성능 | 세 묶음 적용 확인에 따른 그림 생략 구현, 2D 상태 갱신 유지 | Android 대포 6문 표시까지 확인. **연결된 기준 실기기가 없어 4배속 지속 전투 p95/p99·지연·메모리·발열 후 저하 성능은 미검증** |

Android 6018~6022에서 실제 3D 전장·라벨·선택·대포 6문 표시와 보상 실루엣·젬 장착을 확인했다. 최종 일반 APK는 6022다. 이는 모든 효과 조합의 Android 검수나 모바일 실기기 성능 통과를 뜻하지 않는다. 검사 총수·최종 APK 크기·최종 캡처는 [검증 기록](../design/stage1_3d/presentation_migration/README.md)에서 관리한다.

## 후속 범위와 완료 기준

[DESIGNS.md](../DESIGNS.md)의 기존 형태·정보·색·재질과 실제 게임 크기 검증 기준을 따른다. 이번 표시 통합은 거절된 코어 재질 실험을 채택하는 작업이 아니다. 최종 시각 확인은 [인앱 검증](../.agents/in_app_test_guide.md)의 Android 본게임 경로로 진행하며 테스트 렌더와 실제 앱 캡처를 구분한다.

Flame 컴포넌트 생성 자체를 없애거나 전투 코어를 재구성하는 작업은 후속 범위다. JSON 전송이 병목인지도 실측 후 판단한다. 기준 실기기의 profile/release 4배속 다중 착탄·지속 전투를 측정하기 전에는 성능 완료로 표시하지 않는다.

엔진 자원 변경의 APK 점검은 [용량 기준](android_apk_distribution.md#용량-점검)을 따른다. 이 작업에서 배포·커밋은 요청되지 않았다. 일반 빌드와 시각 확인을 외부 배포 승인으로 해석하지 않는다.

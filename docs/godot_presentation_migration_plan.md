# Godot 전장 표시 통합 구현과 검증

역할: Android 본게임 공용 Godot 전장의 **현행 표시 소유권·이관 구현·남은 검증**. 갱신: 2026-09-19(탄환 이벤트·선택 상태 전송·고리 계산). 최초 후속 제안을 바탕으로 `labels`·`selection`·`effects` 세 묶음을 구현하고 공용 Godot 런타임에 연결했다. 구현 상태와 시각·성능 검증 상태는 구분한다. 최초 스테이지 1 이관의 최종 APK·검사 수치·실제 캡처는 [표시 이관 검증 기록](../design/stage1_3d/presentation_migration/README.md)을 따른다. 이후 스테이지 2~5 확장은 [1장 전장 검증](../design/chapter1_3d/README.md)을 따른다.

## 최종 이관 방향

2026-09-19 사용자 결정: 표시뿐 아니라 전투 판정 등 Flame이 담당하는 모든 기능을 Godot으로 단계적으로 이관하고 최종적으로 Flame 의존성을 제거한다. 아래의 Flame 전투 유지·2D fallback은 현재 구현과 진행 중인 이관 단계의 경계이며 최종 구조의 제약이 아니다. 후속 개선은 Flame의 책임·중복 상태·엔진 간 전달을 줄이고 최종 제거에 기여하는 순서로 선택한다. 단계별로 기존 판정·타이밍·저장/API 호환성과 실제 게임 동작을 검증한다. 이번 결정은 최종 방향의 기록이며 전체 이관 구현 완료를 의미하지 않는다. Flutter 앱 UI의 최종 존치 범위는 Flame 제거와 별도로 구분한다. 후속 전투 구현은 [이관 단위·의존 순서·검증 경계](godot_combat_migration_boundaries.md)를 따른다.

## 현행 책임

2026-09-20 전투 연결 변경: 지원되는 Android 3D 전장은 전투 초기 상태의 인수 응답 뒤 적 이동·상태·피해, 포탑 타깃·발사, 탄환·번개 연쇄 판정을 Godot이 담당한다. 아래 표시 이관 당시의 Dart 판정 설명은 2D 및 전투 인수 전 경로에 해당한다. 실제 전투 모드에서는 적·포탑·탄환 표시와 적 내구도 라벨도 Godot 상태로 생성하며 해당 Flame 갱신은 중지한다. 웨이브·코어 스킬 타이머·보상·경제·앱 UI는 Dart에 남는다. 명령/응답·저장 경계와 검증 범위는 [전투 이관 세 번째 묶음](godot_combat_migration_boundaries.md#세-번째-묶음--android-3d-실제-전투-소유권)을 따른다. 전투 인수 후 오류는 전투를 정지시키며, 표시 fallback만으로 Flame 전투를 재가동하지 않는다.

Godot은 전장 모델과 전장에 붙는 정보·선택·효과를 같은 카메라로 표시한다. Flutter는 로비·HUD·패널·보상 카드·교체 UI와 화면 전체 피격 경고를 유지한다. Dart/Flame은 전투 갱신·타깃 선택·피해 판정·웨이브·경제·저장과 공용 전투 시계를 결정한다. 피해 숫자·사망 파편·젬 장착과 착탄 효과·대포 blast·코어 빔·균열 파동·번개 연쇄선은 지원 확인된 Godot 경로에서 생성 이벤트로 전달하고 Godot이 운동·수명을 관리한다. 그 밖의 효과 진행도는 기존 Flame 컴포넌트가 결정한다. 저장 스키마와 전투 규칙은 변경하지 않았다. 3종의 후속 이관 범위와 검증은 [수명 이관 기록](../design/stage1_3d/presentation_migration/native_lifecycle/README.md)을 따른다.

Godot이 해당 묶음을 실제 적용했다고 응답한 경우에만 대응하는 Flame 그림을 생략한다. 미지원 묶음은 기존 표시를 유지하며 오류·화면 종료에는 소유권과 투영을 해제한다. 다른 스테이지·플랫폼과 2D 오류 복귀 경로는 유지한다.

| 표시 | 현행 표시 소유권 |
| --- | --- |
| 지형·포탈·코어·포탑·적 본체·건설 미리보기 | 기존 [Godot 장면](../godot/main.gd). 원본 형태·재질은 이 이관의 변경 대상이 아님 |
| 탄환·예광·기관총 포구·대포 입체 폭발 | 공통 탄환은 지원 확인 뒤 발사·종료 이벤트와 공용 전투 시계로 표시. 기존 [Godot 효과](../godot/effects/ballistic_projectile.gd)와 [입체 폭발](../godot/effects/godot_impact.gd), 종료 탄환의 140ms 잔여 표시 유지. [검증](../design/stage1_3d/presentation_migration/projectile_lifecycle/README.md) |
| 포탑 레벨 배지 | 기존 [Godot 배지](../godot/ui/turret_level_labels.gd). `nativeTurretLevels` 적용 확인 후 Flame 배지 생략; 고정 받침 하단 기준과 공용 배지 원본 유지 |
| 적 체력·장갑·보호막, 상태·균열·다이아 보유 표식, 코어 쿨다운 | `labels`: [Dart 표시 입력](../lib/game/game_battlefield_labels.dart) → [Godot 라벨](../godot/ui/battlefield_labels.gd). 내구도와 상태·활성·색·진행도는 Dart가 전달 |
| 사거리·레벨업 예상 범위·포탑 선택·레벨 오라·젬 고리·즉시 조준선 | `selection`: [Dart 표시 입력](../lib/game/game_battlefield_selection.dart) → [Godot 선택 표시](../godot/ui/battlefield_selection.gd). 중심 광역 공격의 실제 반경과 예상 반경을 Dart에서 계산 |
| 건설칸·건설 사거리·포탈/코어 선택·젬 보상 대상 강조와 dim | `selection`. Godot이 보상 중에만 대상 포탑의 메시를 공유하는 실루엣 마스크를 렌더해 모델만 밝게 유지하고 금색 테두리·교체 표식을 그림. 지형·전투 장면을 복제하지 않으며 보상 종료 시 마스크 렌더를 중지·해제. Flutter 보상 패널은 유지하며 전달된 viewport 밖으로 강조가 나오지 않도록 클립 |
| 피해 숫자·약점/저항 구별·다이아 획득·비blast 착탄·사망 파편·젬 장착 | `effects`: [Dart 표시 입력](../lib/game/game_battlefield_effects.dart) → [Godot 효과](../godot/ui/battlefield_effects.gd). 수치·보상 지급·사망 처리는 Dart에 유지 |
| 번개 충전 | `effects`. 지원 확인 후 생성 이벤트·기존 포탑 좌표와 조준각으로 Godot이 표시; 발사 타이머·취소 판정은 Dart가 유지 |
| 번개 연쇄선·코어 빔·균열 파동 | `effects`. 지원 확인 후 생성 이벤트와 논리 대상 좌표로 Godot이 추적·수명을 관리; 연쇄 타깃과 명중은 기존 로직이 결정 |
| 코어 파괴 전장 흔들림 | `effects` 입력의 변위로 Godot `world`를 이동하고 해당 묶음 적용 시 기존 Canvas 흔들림 생략. 정보·선택도 같은 world 변환을 투영 |
| 피격 화면 경고·HUD·건설/상세/보상 패널·버튼·입력 차단 | 기존 Flutter/Flame 유지 |
| 일반 2D 그림·입력 | 다른 스테이지·플랫폼과 오류 복귀용으로 유지 |

[SequentialLightningChainComponent](../lib/game/components/sequential_lightning_chain_component.dart)는 지연·다음 타깃·명중을 수행하므로 유지한다. Projectile/Enemy/Turret도 그림의 소유권만 구분한다.

## 적용 확인과 수명 계약

[프레임 직렬화](../lib/game/rendering/stage1_3d/godot_battlefield_frame.dart)는 기존 모델 자료와 명시적 DTO인 `presentation.labels`·`presentation.selection`·`presentation.effects`를 전달한다. Godot의 모듈 registry는 자원 초기화·입력·요청 상태를 확인하고 실제 표시한 묶음만 `appliedGroups`로 반환한다. Kotlin `submitFrame` 완료나 엔진 ready만으로 Flame 표시를 숨기지 않는다.

[반환 검증](../lib/game/rendering/stage1_3d/battlefield_presentation_state.dart)은 표시 버전 2, `sceneEpoch`, `viewportRevision`, viewport 크기와 적용 sequence를 확인한다. 오래된 장면·리사이즈 전 응답·역행 또는 미제출 sequence·잘못된 투영은 거절한다. Godot JSON 직렬화의 소수 반올림에 한해 크기 차이 `1e-6` 미만을 허용하며, 실제 리사이즈는 revision과 크기로 계속 구분한다. 같은 적용 sequence의 새 카메라 투영은 허용한다.

장면 초기화는 Kotlin의 우선 reset 처리를 유지한다. 새 epoch·리셋·화면 소유권 변경 때 라벨·선택·효과·전송 대기 자료와 투영을 정리하고, 이전 view의 지연 응답·dispose가 새 view 상태를 덮지 않도록 한다. 표시 DTO에는 저장 객체를 넣지 않는다.

## 정적 맵 전송

Android 본게임은 타일 배열·크기·테마를 캐시하고 `mapRevision`을 전달한다. 해당 revision의 실제 Godot 적용 응답을 받기 전에는 모든 프레임에 전체 맵을 포함해 최신 프레임 병합에도 유실되지 않게 한다. 확인 뒤에는 전체 맵을 생략한다. 같은 객체의 타일 변경도 값 비교로 감지한다.

새 장면·맵 변경 때 다시 전달하며, Godot 캐시가 없거나 revision이 다르면 `mapRequired`로 복구를 요청한다. 이 응답은 표시 완료·투영·효과 ACK로 처리하지 않는다. 기존 전체 맵 입력과 stateless 직렬화 호출도 유지한다. [측정·검증 기록](../design/stage1_3d/presentation_migration/map_transport/README.md)의 전송량·인코딩 비용은 전체 FPS 개선율과 구분한다.

## 선택 상태와 고리 계산

`nativeSelectionAnimation` 지원과 `selection` 실제 적용 확인 뒤 선택·사거리·레벨·장착 젬·건설/보상 대상 상태를 revision으로 전송한다. 같은 revision의 실제 적용 ACK 전까지 전체 상태를 재전송하며, 확인 뒤에는 공용 시계·시각 시간과 현재 조준 입력만 전달한다. 선택·레벨·젬·범위·viewport·대상 변화에는 새 revision을 보낸다. Godot 캐시가 없으면 선택 적용을 인정하지 않아 전체 상태를 다시 받는다. 새 장면·지원 철회에는 전송 캐시를 초기화한다.

Godot이 고리 phase와 레벨 오라 단계를 계산하고, 지원 중에는 Flame의 고리 phase 누적을 생략한다. 최초 전환·2D 복귀·새 포탑 생성의 위상 연속성을 유지한다. 전투 타깃·사거리 스탯·즉시 조준 진행도는 여전히 Flame이 결정하며 DTO 상태 수집과 변경 비교도 남는다. 전체 프레임 전송이나 Flame 전투 갱신을 제거한 작업은 아니다. 구현·Android 검증은 [선택 이관 기록](../design/stage1_3d/presentation_migration/selection_native/README.md)을 따른다.

## 생성 이벤트로 이관한 효과

피해 숫자·사망 파편·젬 장착은 `nativeEffectEvents` 지원과 `effects` 실제 적용을 확인한 뒤 생성 이벤트로 전달한다. 이 경로에서는 해당 Flame 컴포넌트를 트리에 등록하지 않는다. Godot이 생성 입력과 공용 전투 시계로 나이·운동·종료를 계산하며, 실제 적용 sequence 확인 뒤 생성 입력의 반복 전송을 중단한다. 이미지 전용 피해 숫자와 미지원 2D 경로는 기존 컴포넌트를 유지한다.

공용 시계는 정지·보상·로딩 때 멈추고 배속·코어 파괴 감속을 따른다. 카메라 시간으로 효과를 진행시키지 않는다. 피해 숫자 낙하의 기존 프레임별 적분을 보존하기 위해 누적 dt²도 함께 사용한다. 2D 오류 복귀는 살아 있는 효과를 현재 나이에서 복원하고, 전투/장면 정리 때는 이전 효과를 취소한다. 이벤트 보관과 수신 중복 억제는 유한하게 관리한다. 구체적 검사와 Android 확인 범위는 [수명 이관 기록](../design/stage1_3d/presentation_migration/native_lifecycle/README.md)을 따른다.

착탄의 `spark`·`sniperBlast`·`flame`·`frost`·`lightning`·`lightningBlast`는 별도 `nativeImpactEffectEvents` 지원까지 확인한 뒤 같은 이벤트 경로를 사용한다. 기존 엔진 응답에 이 지원 값이 없으면 최신 age 스냅샷 경로를 유지한다. 화염·냉기의 기존 2D 착탄 억제와 3D 효과는 유지하며 대포 `blast`는 아래 별도 생성 이벤트 계약으로 기존 3D 표시 경로에 연결한다. [착탄 수명 이관 검증](../design/stage1_3d/presentation_migration/impact_lifecycle/README.md).

대포 `blast`는 `nativeBlastEffectEvents` 지원 확인 뒤 생성 위치·반경·개별 수명과 공용 전투 시계로 진행한다. 실제 적용 ACK까지 생성 이벤트를 반복하며, Godot이 기존 3D 폭발 렌더러에 progress를 공급한다. 기존 파편 GPU 운동·체적 효과·광원·풀은 유지한다. 구형 런타임과 기존 미리보기의 `impacts` 입력도 유지한다. [대포 폭발 수명 이관 검증](../design/stage1_3d/presentation_migration/blast_lifecycle/README.md).

코어 빔·균열 파동은 별도 `nativeLinkedEffectEvents` 지원 확인 뒤 생성 이벤트의 대상 ID와 공용 시계로 표시한다. 연결 대상인 적만 기존 enemy 배열에 논리 좌표를 추가하며, 시각 흔들림 좌표를 사용하지 않는다. 빔은 마지막 수신 생존 위치를 유지하고 균열은 사라진 대상의 연결선을 제거한다. 피해·낙인 판정과 기존 그리기 함수는 유지한다. 미지원 경로는 기존 스냅샷을 사용하고 지원 철회 때 살아 있는 효과를 현재 나이·보드 좌표로 복원한다. [검증 기록](../design/stage1_3d/presentation_migration/core_effect_lifecycle/README.md).

번개 연쇄선은 별도 `nativeChainEffectEvents` 지원 확인 뒤 초기 두 끝점·대상 ID·원래 픽셀 기준 seed를 전달한다. Godot이 기존 지그재그 6점 수식을 재현하며 양쪽 대상이 사라지면 각 마지막 위치를 독립적으로 유지한다. Flame의 효과 update·6점 스냅샷 생성·반복 전송을 생략하지만, `SequentialLightningChainComponent`의 다음 대상 선택·명중 지연·피해와 번개 충전의 발사 시점은 유지한다. [검증 기록](../design/stage1_3d/presentation_migration/chain_lifecycle/README.md).

번개 충전은 별도 `nativeChargeEffectEvents` 지원 확인 후 표시만 생성 이벤트로 전달한다. 기존 포탑 프레임의 위치·조준각과 생성 시 포구 반경을 이용해 Godot이 위치와 진행도를 계산한다. Flame 컴포넌트는 실제 발사 타이머로 유지하며 정상 완료는 표시 시계로 종료하고, 비활성·강제 제거는 이벤트 세대로 취소를 전달한다. 이미 만료된 충전은 뒤늦게 재생하지 않는다. 지원 철회 때 같은 컴포넌트의 표시만 복귀하므로 발사 콜백을 중복 실행하지 않는다. [검증 기록](../design/stage1_3d/presentation_migration/charge_lifecycle/README.md).

## 프레임 생략과 짧은 효과

아래 최신 age 스냅샷 큐는 이벤트로 이관하지 않은 나머지 효과에 계속 적용한다.

브리지가 최신 프레임으로 합칠 때 한 simulation tick 안에 생성·종료된 효과를 놓치지 않도록 생성 시점에 자료를 등록한다. [효과 큐](../lib/game/rendering/stage1_3d/battlefield_effect_queue.dart)는 최대 **256개**, 종료 뒤 미확인 자료는 배속·정지와 독립적인 시각 기준 최대 **2초** 보존한다.

- 살아 있는 효과는 최신 age와 좌표로 갱신한다. 늦거나 반복된 자료로 진행도를 되감지 않고, 종료 샘플로 마지막으로 그릴 수 있는 샘플을 덮지 않는다.
- 실제 전송 프레임에 포함한 ID의 최초 sequence를 기록한다. Godot의 누적 적용 sequence 확인을 받은 종료 효과는 제거한다. 브리지에서 생략한 프레임 뒤에도 대기 자료가 최신 프레임에 함께 실린다.
- 적용 확인이 없더라도 종료 효과는 2초 뒤 만료한다. 용량을 넘으면 오래된 종료 자료를 먼저 제거하고, 모두 살아 있으면 오래된 항목부터 상한을 유지한다. 무제한 전달 보장이나 과거 효과 일괄 재생을 하지 않는다.
- 큐는 전투 진행도를 스스로 증가시키거나 종료 효과를 새로 시작하지 않는다. 전투 정지·배속·코어 파괴 감속은 기존 컴포넌트의 age/progress를 따른다. 자료 보존 때문에 피해·재화 지급을 다시 실행하지 않는다.

## 카메라·입력·합성

고정↔드론의 0.7초 cubic ease-out과 전환 중 재입력은 기존 Godot 카메라를 유지한다. 전투 정지·배속과 독립적으로 움직인다. 카메라 tween 갱신 때 redraw를 예약하고 `RenderingServer.frame_pre_draw`에서도 현재 카메라와 world 변환으로 위치를 확인한다. 선택의 선 두께·배율과 보상 클립은 논리 타일 크기·실제 viewport 배율을 반영한다.

Flutter는 Godot이 반환한 같은 장면·viewport의 투영을 건설/선택 입력과 보상 패널 anchor에 계속 사용한다. Godot에 중복 터치 판정을 추가하지 않는다. Flutter의 전장 dim은 `selection` 적용 확인 뒤 생략하여 Godot 대상 모델 강조를 가리지 않는다. HUD와 화면 전체 피격 경고는 기존 합성 경로에 남는다.

`frame.time`의 기존 `_spaceTime`은 배속 독립이며 1200초마다 순환한다. 이를 모든 효과의 전투 시계로 사용하지 않는다. 이벤트로 이관한 효과는 실제 컴포넌트 dt를 누적한 별도 시계와 생성 시각으로 나이를 계산한다. 그 밖의 효과는 전달된 age/progress를 사용한다. 선택 고리는 `nativeSelectionAnimation` 지원과 실제 selection 적용 확인 뒤 초기 phase 원점과 공용 전투 시계로 Godot이 계산하며, 미지원 경로는 기존 컴포넌트 phase를 사용한다.

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

다이아 획득·번개 충전·연쇄·코어 등 남은 효과의 Flame 갱신 제거와 전투 코어 재구성은 후속 범위다. JSON 전송이 병목인지도 실측 후 판단한다. 기준 실기기의 profile/release 4배속 다중 착탄·지속 전투를 측정하기 전에는 성능 완료로 표시하지 않는다.

엔진 자원 변경의 APK 점검은 [용량 기준](android_apk_distribution.md#용량-점검)을 따른다. 이 작업에서 배포·커밋은 요청되지 않았다. 일반 빌드와 시각 확인을 외부 배포 승인으로 해석하지 않는다.

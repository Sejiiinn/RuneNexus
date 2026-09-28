# 표시 경로 성능 후보 감사

2026-09-28. 읽기 전용 소스 조사와 격리 headless probe. 구현 파일 변경·APK·실제 편집기 변경 없음. A34 주 병목이나 전체 FPS 개선을 확정하는 결과가 아니다.

## 1. 리그 애니메이션을 같은 시각에 두 번 적용 — 가장 확실한 낭비

- `godot/presentation/guardian_preview.gd:130`의 `player.seek(phase * seconds, true)` 직후 `:131`에서 `player.advance(0.0)`을 호출한다. 사망 리그도 `:219~220`, 초기화도 `:94~95`에서 동일하다.
- 활성 전투의 표시 frame마다 살아 있는 normal/fast 전체와 남은 사망 리그 전체에 적용한다. 같은 거리/사망 나이인 반복 frame을 건너뛰는 guard도 없다.
- 원본 GLB JSON: normal 14 joints / 42 animation channels, fast 24 / 72, normal_death 18 / 55, fast_death 24 / 72. GLB channel 수이며 실제 Godot Node 수로 해석하지 않는다.
- **격리 Godot 4.7.2 확인:** 한 value track의 setter 계측에서 `seek(t,true)`는 1회 적용, 직후 `advance(0)`까지는 2회 적용. 같은 t로 다시 수행해도 2회. `presentation_probe.gd`, `presentation-probe.log`.
- 실제 42/72개 rig 채널의 두 번 평가 횟수를 직접 계측한 것은 아니다. 해당 리그도 같은 API 조합을 사용하므로 전체 pose의 중복 평가가 있을 것으로 추론하며, 직접 확인한 사실은 별도 1-track probe의 setter 1→2회다.
- 기존 최적화: 수동 전투 시계·이동거리 기반 위상과 PackedScene 로딩 재사용은 이미 적용됐다. 자동 재생으로 바꾸거나 애니메이션 품질을 줄이는 제안이 아니다.
- 안전한 방향: 단일 pose 평가만 수행하는 형태를 비교하고 실제 rig의 모든 bone pose·상태 skin·회전·사망 fade가 같은지 확인한다. pose phase가 같으면 애니메이션 평가만 생략하고 회전/표시 변화는 유지할 수 있다. 정지·배속·되감기·초기 RESET 상태 보존 필수.

## 2. 살아 있는 모든 효과의 정적 데이터까지 매 frame 깊은 복사/정규화

- `godot/combat/native_combat_runtime.gd:955~980`: `visual_effects`의 모든 dictionary를 `duplicate(true)` 하고 age/offset/연결점만 변경한다. 그 뒤 `godot/ui/app_presentation.gd:20~23,30~44`에서 같은 effect의 tileSize/scale/radius 등을 다시 48 단위로 정규화한다.
- main의 `:400~412`를 통해 활성 전투 표시 frame마다 실행한다. 비용은 동시 살아 있는 effect 수와 nested points/targetIds 크기에 비례한다. native `visual_effects`는 `:450~451`에서 수명으로 제거되며, Canvas journal `_events`의 256 제한과는 다른 배열이다.
- **현재 비용 참고:** CPU headless에서 다른 actor 없이 damage effect 0/64/256/1024개를 넣고 실제 decorate+normalize를 실행했다. 5 trial × 150회 중앙값 각각 **0.0099 / 0.145 / 1.150 / 4.900 ms**. trial 편차가 크며 합성 부하다. 이 동시 개수가 실제 A34 전투에서 발생하는지는 미측정이고 개선 전후 비교도 아니다.
- 기존 최적화: main의 owned snapshot/얕은 frame 복사, effects 순열·surface pool·draw key·redraw 캐시는 이미 있다. 그것을 다시 구현하자는 제안이 아니다. 여기 남은 것은 producer 쪽 per-effect 깊은 복사/변환이다.
- 안전한 방향: 효과 생성 때 불변 표시 필드와 단위를 준비하고 frame에서는 나이/offset/추적 endpoint만 갱신하는 내부 경로. public snapshot 격리·expired 이벤트 처리·legacy 입력·연쇄와 광선의 동적 연결점을 보존해야 한다. 공개 snapshot의 mutable dictionary를 그대로 공유하는 변경은 피한다.

## 3. 일반/빠른 적의 spawn/death마다 별도 리그 instantiate/free

- 살아 있는 리그는 `guardian_preview.gd:70~97,100~112`에서 root와 GLB instance 및 AnimationPlayer 초기화. 사망마다 `:195`에서 또 다른 death PackedScene을 instantiate한다. 살아 있던 root는 `battlefield_units.gd:351~355`에서 free, corpse는 `guardian_preview.gd:210~217`에서 0.55/0.6초 후 free한다.
- 사망이 몰리는 frame에는 kill 수만큼 리그 생성·트리 연결·player 검색/초기화가 일어나고, 기존 몸체 삭제가 같은 갱신에 겹친다. pool은 이 actor/death 경로에 없다. 비용은 frame당 spawn/kill 수와 각 rig 복잡도에 비례한다. 실제 시간은 측정하지 않았다.
- 기존 최적화: PackedScene/mesh/재질 리소스 로딩 재사용, skinned status의 오프라인 merged mesh, shared 재질·GPU 상태효과는 이미 있다. 투사체/impact와 Canvas label/effect는 pool을 사용한다. 리소스 파일을 매 사망 다시 읽는다는 뜻은 아니다.
- 안전한 방향: normal/fast의 living/death instance를 종류별 제한된 pool로 재사용한다. animation seek·floor offset·회전·scale·개체별 burn/frost material override·죽음 opacity·instance shader parameter·등록 dictionary를 정확히 reset해야 한다. 필요 이상 사전 대량 생성 대신 실제 peak와 용량 상한을 정한다.

## 제외한 항목

지형 triangle/LOD 재조사, main standalone_playing 전용 deep copy를 실제앱 병목으로 오인하는 것, 이미 적용된 라벨 pool/dirty redraw/투영 cache, 포탑 level badge pose cache, Canvas effect 정렬 cache, 포구/투사체 pool, 불/냉기 공유 shader·MultiMesh, enemy lane 경로 binary search cache는 재제안하지 않는다.

판단: 1번은 반복 적용 자체를 확인한 좁은 개선 후보다. 2번은 현재 CPU 비용을 합성 조건에서 확인했으나 실제 동시 effect 개수 측정이 필요하다. 3번은 대량 사망 순간의 할당 후보이며 실부하 계측이 필요하다. 모두 UI 외형·전투 시간·원본 rig 표현을 유지하는 방향으로만 검토한다.

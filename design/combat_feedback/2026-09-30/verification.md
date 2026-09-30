# 전투 피드백 적용 확인

확인: 2026-09-30. 기준: [DESIGNS.md](../../../DESIGNS.md). 요청한 다이아 보상 식별·획득 연출과 중앙 일시정지 표시를 변경했다.

Godot 4.7.2 stable / Apple M4 Metal Forward Mobile / 440×900 / MovieMaker 30fps. 별도 저장 디렉터리에서 실제 main + app_lifecycle + NativeCombatRuntime을 실행했다. 영상은 성능 측정 자료가 아니다.

- [다이아 영상](diamond.mp4): 1배속 보상 3 몹과 4배속 보상 1 몹을 실제 기관총 포탑으로 처치. +3, +1 및 pendingEconomyDiamonds 합계 4 확인. 표식과 획득 아이콘의 팝·반짝임·상승·페이드를 확인했다.
- [일시정지 영상](pause.mp4): 실제 시작 → 일시정지 → 재개 버튼 실행. 정지 중 native clock 3.6 유지, 화면 중앙 점멸, 재개 시 표시 제거 확인.
- 관련 자동 검사: HUD·모달 전이, 실제 다이아 처치/경제 수치·배속/정지/재전송/세대, labels/effects/cache, native combat/event batch/presentation 통과. 다이아 회귀를 정식 실행기에도 등록하고 실행했다.
- 별도 검증자: 실제 영상의 다이아 표식·+3/+1·4배속 가독성·소멸, 중앙 일시정지 점멸·재개 전이 및 관련 격리 검사를 독립 확인하여 PASS. 발견한 결함 없음.
- 보상 단계에서는 기존 전투 시계 계약에 따라 VFX가 정지하고 장면 전환 시 제거된다.
- Android 실기기 검증과 배포는 이번 작업에 포함하지 않았다.

최종 시각 입력 SHA-256 (소스; 게임 에셋은 기존 생성 프로젝트 import 경로 사용):

- godot/combat/native_combat_runtime.gd: 5161bf6cd760d51185e507588e164174fb6b145f1876e440770ccdb8837dad1c
- godot/main.gd: 055e740e0d9948a1afa0624f3026298504c329a90f0a1bff38374407c2aa6414
- godot/ui/battlefield_effects.gd: 9c9aeb7e0677947e9492bc9940f758b0b439cab73bcf3fdc72edb5139f786904
- godot/ui/battlefield_labels.gd: 0ce8ea1d89d5e29aef6218cb21b0002730cb47805106cb557c9cbdcd98864599
- godot/ui/battle_hud.gd: 7ef264c88a69997e5f292a32037a553653be698335b6c14d835d6c64eec199f0
- godot/ui/pause_indicator.gd: 71eb8376dee9a583bb9e5b27addea6602e4f1fad2af75744f8e01a192b983a22

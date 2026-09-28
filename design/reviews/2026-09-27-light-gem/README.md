# 경량화기 증폭 장착 제한

> 원시 로그·일회성 검사·측정 덤프는 로컬 기록으로 Git 추적에서 제외했다. 본문의 요약 결과와 유지되는 회귀 테스트는 보존하며, 아래 로컬 기록은 새 체크아웃에 포함되지 않는다.

2026-09-27. 기관총만 경량화기 증폭을 장착하도록 콘텐츠 호환 목록을 수정했다. 명령·기존 저장 반환 계약은 [런 명령 기준](../../../godot/app/run_commands_README.md)을 따른다.

- 실제 Godot HUD fixture / Godot 4.7.2 Metal Mobile / 440×880, 사용자 저장 없음.
- [비경량 포탑 장착 비활성](cannon-equip-blocked.png), [보상 전용 표기](reward-card.png), [보상 대상 차단](reward-target-blocked.png).
- UI 검사 (`ui.log`, 로컬 기록): 6종 중 기관총 허용/5종 차단, 재클릭 상태 보존, 보상 표기/대상 차단 PASS.
- 보상 회귀 (`rewards.log`, 로컬 기록): 보상 장착·교체·획득 젬 줄바꿈 검사 PASS.
- 도메인 검사 `build/godot/light-gem-contract-tests/`: 런 명령 4,900 checks 실패 0, 저장 복원 실패 0, 콘텐츠 검사 PASS. 독립 검사에서 6종 동시 기존 장착 중 비경량 5개 반환·기관총 유지·재저장 후 중복 반환 없음 확인.
- 독립 코드/화면/저장 검증 PASS. APK 빌드·설치·배포는 수행하지 않았다.

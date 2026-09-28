# 공통 우주 배경

2026-09-28. 승인 원본은 [25도 비교 이미지의 B안](chapter1-space-25deg-comparison.png), 현행 외형 계약은 [DESIGNS.md](../../../DESIGNS.md)에서 관리한다.

게임용 [배경 이미지](../../../assets/images/backgrounds/combat_space_nebula.png)는 내장 ImageGen으로 제작했다. [제작 원본](combat-space-nebula-source.png)과 [생성 프롬프트](production-prompt.txt)를 보관한다. 앞선 숲·유적 비교는 미채택 탐색 시안이다.

## 현행 적용

공통 Canvas 배경과 원본 이미지 한 장을 공유한다. 외곽 성운만 챕터별 색감으로 바꾸며 중앙의 어두운 우주와 별의 차가운 흰빛은 보호한다. 성운과 별의 위치를 고정하고, 밝은 별 일부만 서로 다른 7~14초 주기로 최대 22% 감광한다. 기존 챕터별 반사 Sky·조명 및 카메라는 유지한다. 에셋 준비와 PCK 입력 해시에 배경을 포함했다.

## 챕터별 성운 색 검증

2026-09-28 후속 승인에 따라 원본 이미지를 공유하며 성운 색만 변경했다. 1장은 청록·푸른빛, 2장은 남보라·자주빛, 3장은 어두운 적갈색·구릿빛이다. 지형의 실제 theme를 따라 전환하며 3장에서 1장으로 돌아오면 1장 색으로 복원한다.

- Godot 4.7.2, macOS Metal Mobile, 440×900 실제 화면: [1장](chapter-palettes/chapter1-drone25.png), [2장](chapter-palettes/chapter2-drone25.png), [3장](chapter-palettes/chapter3-drone25.png), [3→1 복귀](chapter-palettes/chapter1-return-from3.png).
- 동일 반짝임 위상으로 팔레트를 비교해 밝은 별 162픽셀과 중앙 126,000픽셀의 색 변화가 없음을 확인했다. 제작용 셰이더와 같은 uniform으로 촬영한 3초 시간차에서 밝은 별 19픽셀만 변화했다.
- [실행 로그](chapter-palettes/visual.log)와 [최종 소스·화면 해시·검증 조건](chapter-palettes/runtime-inputs.json)에 근거를 보관한다. 기존 이미지·반짝임·카메라·조명·HUD는 유지한다.
- 별도 Astra 검증자가 최종 해시와 실제 화면·픽셀을 독립 확인해 PASS. 부모도 챕터별 실제 화면과 최종 3장 화면을 직접 확인했다. Android 실기기는 미검증이다.

## 최초 공통색 적용 검증

아래는 챕터별 색감 변경 전의 검증 기록이다. 최초 배경 연결·로비·시점·패키징 확인 근거로 보존한다.

- Godot 4.7.2, macOS Metal Mobile, 440×900 실제 렌더: [1장 25도](implementation/chapter1-drone25.png), [2장](implementation/chapter2-drone25.png), [3장](implementation/chapter3-drone25.png), [고정 시점](implementation/chapter1-fixed.png), [25도 복귀](implementation/chapter1-drone25-return.png), [로비 보존](implementation/lobby-preserved.png) 확인.
- [3초 전](implementation/background-time0.png)·[3초 후](implementation/background-time3.png) 캡처의 396,000픽셀 중 밝은 별의 19픽셀만 변화했다. 나머지 배경 좌표·성운은 동일하다.
- 관련 에셋 준비 검사 3개와 패키징 입력 해시 검사를 통과했다. [실행 로그](implementation/visual.log), [입력 해시·환경·검사 근거](implementation/runtime-inputs.json).
- 별도 Astra 검증자가 승인 원본·실제 화면·코드·시간차 픽셀을 독립 대조해 PASS. 부모도 최종 1장·3장 실제 화면을 직접 확인했다.

저장은 검수 전용 경로로 격리했다. Android 기기 검증·APK/PCK 빌드·배포는 수행하지 않았다.

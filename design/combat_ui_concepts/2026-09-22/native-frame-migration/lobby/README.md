# 로비 네이티브 프레임 전환 검증

2026-09-22. 범위: `godot/ui/lobby_frame.gd`, 강화·연구·포탑 모듈·퀘스트 소비 화면. [디자인 기준](../../../../../DESIGNS.md)을 유지한다.

`StyleBox`의 수동 9분할 `_draw`를 실제 `StyleBoxTexture`로 변경했다. 기존 원본 PNG 픽셀을 재샘플링하지 않고 캐시한 `ImageTexture`의 논리 크기만 1/4(전투 primary는 1/3)로 지정한다. 원본 텍스처 RID를 수정하지 않으며, 원본·배율 조합별 복사본 하나를 모든 상태가 공유한다. 텍스처 메모리 복사본은 추가되며 성능 향상을 별도 실측한 결과는 아니다. 콘텐츠 여백과 코너 여백, 색상 modulation, 전체 이미지 stretch, 누락 에셋의 단색 fallback을 유지한다. growth/collection 소비자 수정은 필요하지 않았다.

## 실행·결과

- Godot 4.7.2 공식, macOS Apple M4, OpenGL Compatibility, 논리·캡처 크기 320×900 / 440×900.
- 격리 프로젝트 `build/godot/frame-lobby-review`, 별도 `RuneNexus-frame-lobby-review` user directory. 사용자 저장을 읽거나 수정하지 않았다. 준비된 에셋과 import cache를 사용했고 공유 프로젝트를 import하지 않았다.
- 실제 Lobby Control 화면에 고정 테스트 progression을 주입했다. `before-*.png`와 `after-*.png`는 같은 렌더러/해상도/상태의 전후 앱 화면이며 시안이 아니다.
- `growth-test.log`: 320/440 레이아웃·연구 시작/취소 확인·세부 상태 갱신 PASS.
- `collection-test.log`: 모듈 필터/장착/해제·퀘스트 기간/보상/시계보호·320/440 PASS.
- `frame-test.log`: native 타입·원본 이미지 데이터 동일·원본 크기 불변·캐시 공유·독립 콘텐츠 최소크기·primary scale3·stretch/누락 fallback PASS.
- 대표 화면을 직접 확인했다. 금속 코너·어두운 청록 표면·콘텐츠 배치가 보존된다. 퀘스트 전후는 픽셀 완전 일치. 나머지는 엔진 9패치의 샘플링에서 일부 픽셀만 최대 1~4/255 차이가 있다. 따라서 모든 픽셀이 100% 같다는 판정은 하지 않는다. 구체 수치는 `pixel-comparison.log`, `inventory-comparison.log`에 보존했다.

## 제한

320px 보유 모듈 화면의 ‘보유 1개’가 세로로 줄바꿈되는 현상은 변경 전 캡처에도 같다. 이번 외형 보존 전환에서 레이아웃을 재설계하지 않았다. Android·모바일 렌더러 검증은 수행하지 않았다. 전투 primary의 실제 최종 화면은 HUD 담당 검증 범위다.

# 젬 링크 홈 에셋

- 원본: `socket_states_source.png` — 승인된 금속·룬 소켓 방향을 바탕으로 ImageGen 생성.
- 편집 원본: `socket_states.xcf` — GIMP에서 배경 제거, 내부 재질과 하이라이트 보존.
- 투명 중간본: `socket_states_alpha.png`.
- 최종: `assets/images/ui/components/gem_socket_{empty,selected,locked}.png` — 256×256 RGBA PNG, 인게임 한 줄 6개 기준의 반응형 크기로 표시.
- GIMP 크롭: 각 상태 (24 / 524 / 1024, 252), 480×480 → cubic 256×256.
- 일반·선택·잠금은 정적 상태이며 애니메이션 프레임이 아닙니다. 장착 젬 아이콘은 기존 GemIcon을 중앙에 겹칩니다.
- 표시 개수는 현재 연구로 해금된 최대 홈 수(기본 3개, 링크 확장 연구 후 4개)를 따르며, 아직 구매하지 않은 홈은 잠금 상태로 표시합니다. 6개 고정 표시는 하지 않습니다.
- `hud-widget-preview.png`는 360×800 위젯 테스트 렌더입니다. 테스트 환경의 일부 기본 글꼴이 사각형으로 표시되어 텍스트 외관 검증용 최종 캡처로 사용하지 않습니다. 인앱 브라우저는 기존 게임 탭 및 Mac 잠금으로 최종 확인이 제한되었습니다.

## 연결부 에셋

- 생성: 내장 ImageGen, 소켓 이미지를 재질 참고로 사용. 프롬프트: `link_prompt.txt`.
- 원본: `link_states_source.png`, GIMP 편집 원본: `link_states.xcf`, 투명 중간본: `link_states_alpha.png`.
- 최종: `assets/images/ui/components/gem_link_locked.png`, `gem_link_active.png` — 각 320×72 RGBA PNG.
- 금속 연결부를 소켓 뒤에 겹쳐 표시하며 열린 홈 사이만 청록색 점등 에셋을 사용합니다. 정적 상태 2종이며 애니메이션은 없습니다.
- 최신 위젯 렌더: `hud-link-assets-preview.png` (테스트 환경의 일부 글꼴 표시 제한은 위와 동일).

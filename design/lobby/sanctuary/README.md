# 로비 제단 배경

- 승인 시안: `approved_concept.png`
- 게임 배경: `assets/images/lobby_sanctuary_background.png` (853 × 1844, 불투명 PNG)
- 제작: 내장 ImageGen, 승인 시안의 UI와 룬 장치를 제거한 배경 편집
- 룬 장치: 기존 `lobby_rune_pedestal.png`를 별도 렌더링. 배경에는 석조 제단만 포함.
- 배치: 화면 폭에 비례해 배경과 장치를 함께 배치. 제단 접점은 배경 높이의 41.7%, 진행 패널은 50% 아래.
- 저장 및 전투 재개 흐름은 기존 로직 유지.

## 최종 생성 프롬프트

Use case: precise-object-edit. Extract clean game background from this approved Rune Nexus lobby concept. Single opaque portrait PNG, same 852x1846 aspect ratio and IDENTICAL camera, architecture, scale and positioning. REMOVE ALL UI: top Rune Nexus logo, gear/settings text, all central stage/round panels and continue buttons, events leaderboard strip, primary stage button, bottom navigation icons and words and separators. Also REMOVE the central metal gyroscopic rune/crystal machine and its SMALL METAL BASE completely, but KEEP the large circular STONE ALTAR and all stone steps at the exact same location. Fill removed regions naturally with continuous sanctuary stone surfaces. Preserve the low large stone altar at x center, its top surface centered around y=750 of1846 (~40.6% height), bottom step around y=900 (~49%). Preserve the alcove walls and cyan lights. Empty altar top, dim soft contact-light pool, NO remaining machine parts or crystal in foreground. Back wall circular architecture stays. Darken and simplify floor texture below y=950, low contrast dark navy to support separately rendered UI. No text, letters, logos, icons, buttons, panels, frames, dividers, interface, watermark. This is a production BACKGROUND ONLY; keep composition registration absolutely unchanged.

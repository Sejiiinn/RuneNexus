# 받침에 고정된 로비 룬 장치

- 용도: 로비 중앙 장치가 바닥에 놓인 장면 표현
- 표시 크기: 180~200 logical px
- 프레임 수: 1 (정적)
- 출력 형식: 투명 RGBA PNG
- 제작 방식: 내장 ImageGen, 필요 시 GIMP MCP 후처리
- 기존 `lobby_rune_device.png` 보존
- 최종 파일: `assets/images/lobby_rune_pedestal.png`, 512×512, 실제 알파 채널 확인
- GIMP MCP: 흰 배경 선택 후 투명화, 중앙 에너지 광원 보존, 512 정사각 축소
- 원본: `rune_pedestal_generated.png`, 편집본: `rune_pedestal.xcf`
- 200px 정적 미리보기에서 받침/지지대의 연결과 투명 여백 확인

## 프롬프트

Use case: precise-object-edit
Asset type: Rune Nexus game lobby integrated static centerpiece sprite, square canvas, one frame, intended for 180–200 logical px display.
Input 1 is the rune gyroscope to preserve. Input 2 is the actual game screenshot for style and lighting reference only. Output ONLY the isolated centerpiece asset, never a screenshot or UI.
Change the device so it is PHYSICALLY SUPPORTED, NOT FLOATING: mount this exact silver/dark-steel interlocking rune gyroscope with its cyan diamond core onto a LOW dark charcoal stone and gunmetal oval plinth. A small sturdy bracket/axle must visibly connect the lower ring to the pedestal, with absolutely no air gap between device, bracket and pedestal. The device is stationary and grounded. Preserve ring shape, metal material, cyan inscriptions and camera perspective from input 1.
The low elliptical base is approximately 1.3 times the device width, only 10–15 percent of the total asset height. It has a restrained beveled metal edge, a few tiny cyan rune marks, and a soft compact contact shadow touching its bottom edge. No giant platform, no stairway, no building, no added surrounding floor or environment. Charcoal stone and subdued metal reflect the dark cathedral screenshot. Preserve elegance and quiet moody scale.
Composition: centered full integrated object, fits within 85 percent of canvas, 3/4 frontal perspective. A production-ready genuinely transparent RGBA PNG with actual zero-alpha empty background. DO NOT RENDER A CHECKERBOARD. If actual transparency cannot be output, use a perfectly uniform PURE WHITE (#FFFFFF) background with absolutely no pattern or vignette; do not paint a checkerboard under any circumstances. No text, UI, logos, sparkles or magical cloud around the silhouette.

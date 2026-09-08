# 메인 로비 룬 장치

- 용도: 로비 중앙의 작은 장식용 정적 에셋
- 최종 표시 크기: 약 130~180 logical px
- 프레임 수: 1, 애니메이션 없음
- 출력: 투명 PNG
- 제작: 내장 ImageGen, 합의한 메인 로비 시안을 참조
- 최종 파일: `assets/images/lobby_rune_device.png`, 512×512 RGBA PNG
- 후처리: GIMP MCP에서 흰 체크 배경 투명화, 중앙 광원 보존, 크롭 및 축소. 바닥 빛은 흰 잔상을 피하기 위해 제외.
- 원본: `rune_device_generated.png`, 편집본: `rune_device.xcf`
- 검증: 실제 알파 채널 확인, 180px 미리보기 확인. 정적 1프레임으로 프레임 순서/반복 재생 해당 없음.

## 생성 프롬프트

Use case: background-extraction
Asset type: single static transparent PNG game sprite for Rune Nexus main lobby, square 1024x1024, one frame, shown at 130–180 logical pixels.
Input image: approved lobby mockup, edit target.
Primary request: Extract and reproduce ONLY the small silver/dark steel and cyan rune gyroscope device near the lower center of the reference, including its compact cyan luminous floor rune immediately beneath it. Preserve its design: three interlocking slim rune-engraved metal rings, tiny bright cyan diamond energy core, floating just above a subtle elliptical blue magical floor glow. Preserve the same front three-quarter view, sober detailed dark fantasy game asset rendering, silver metal highlights and restrained cyan illumination. The gyroscope must remain compact and elegant, not an architectural nexus or building.
Composition: isolated centered device plus small floor rune occupying approximately 75 percent of the square canvas height; enough clear margins for the entire glow. True transparent alpha background outside the subject and its gentle glow. Soft semitransparent glow edges.
Remove ALL environment, stone floor, cathedral walls, UI, text, logos, buttons, menus, icons. No black or colored background, no checkerboard baked into image, no border. Do not add large platforms, extra machines or architecture. Output only this one clean transparent production asset.

# 로비 전용 버튼 제작

제작 도구: 기본 내장 ImageGen. 신규 이미지 에셋이며 문구·아이콘은 게임에서 합성합니다.

## Primary

Create ONLY ONE flat game UI primary action BUTTON blank background sprite. Actual transparent alpha outside. Compact clipped-corner rectangular metal frame, very long horizontal ratio 5.357:1 (900x168 final target). Straight simple double-edge frame dark silver with subtle cool cyan inset, dark teal matte center. Minimal, disciplined, restrained design matching dark fantasy ruined sanctuary. The silver corner bevels must be extremely small, less than 8% of height. Exactly uniform straight top and bottom edges across their entire length. NO central ornament, NO center bump, NO jewels, NO diamond, NO flourishes, NO symbols, NO runes, NO text, NO icons, NO backdrop, NO shadows outside. Interior empty and low contrast. The primary center can be subtly brighter navy-teal than secondary buttons. Nine-slice-ready crisp orthographic front-on surface, no perspective. Single button nearly tightly framed, PNG transparent background.

## Secondary

Use case: ui-mockup. Asset type: ONE production secondary game button PNG on genuine transparent alpha background. Isolated front-facing button only, no screenshot. Rune Nexus dark fantasy industrial sanctuary style: restrained worn dark silver thin beveled clipped-corner frame, opaque deep navy matte inset, very slight teal edge accent. Create compact horizontal rectangle ratio 2.5:1, intended final size 360x144 pixels representing 120x48 logical. Uniform empty dark center for two-word runtime text, NO text or icons or glyphs. Edge details all within outer 8% of height, perfectly straight edges suitable for nine-slice resizing, small bevelled corner pieces. Top-down flat orthographic UI asset, no perspective. Quiet low contrast secondary action. No gold, jewels, elaborate decorations, glow clouds, oversized protrusions, symbols. Frame nearly tight cropped with genuine transparent alpha immediately outside clipped corners. No baked checkerboard, no cast shadow outside. One button only.

## 출력

- primary_generated.png / secondary_generated.png: ImageGen 원본
- 최종 버튼: assets/images/lobby_primary_button.png (900×168), assets/images/lobby_secondary_button.png (360×144)
- GIMP에서 프레임 외부 투명 여백 자르기 및 최종 크기로 조정.
- Flutter scale: 3. 모서리를 보존하는 9-slice 적용.
- 권장 centerSlice (논리 좌표): primary `Rect.fromLTRB(12, 14, 288, 42)`, secondary `Rect.fromLTRB(10, 11, 110, 37)`.
- 원본 crop (x, y, width, height): primary `(11, 171, 2185, 332)`, secondary `(66, 86, 1851, 595)`.
- 두 최종 이미지 RGBA, 좌상단 alpha=0 검증. Primary alpha 범위 0~255, secondary 0~254.

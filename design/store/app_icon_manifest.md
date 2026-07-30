# Rune Nexus 앱 아이콘 내보내기 기록

## 기준 자산

- 정체성 참조: `assets/images/rune_nexus_logo.png`
- 아이콘 마스터: `rune_nexus_app_icon_master.png` (`1254x1254`, RGB PNG)
- Google Play 아이콘: `rune_nexus_play_icon_512.png` (`512x512`, RGB PNG)

## 시각 기준

- 메인 메뉴 타이틀 왼쪽의 청색 넥서스 결정체와 4개 금속 프레임 유지
- 작은 크기에서도 읽히는 중앙 대칭 실루엣
- Android 적응형 아이콘 마스크를 위한 중앙 안전 여백
- 텍스트, 숫자, 워터마크, 모서리 마스크 미포함
- 적응형 아이콘 XML 배경색: `#06142A`
- 적응형 래스터 가장자리 패딩색: `#00040A`

## Android 내보내기

| 밀도 | 일반 아이콘 | 적응형 레이어 |
| --- | ---: | ---: |
| mdpi | 48x48 | 108x108 |
| hdpi | 72x72 | 162x162 |
| xhdpi | 96x96 | 216x216 |
| xxhdpi | 144x144 | 324x324 |
| xxxhdpi | 192x192 | 432x432 |

적응형 레이어는 극단적인 원형·스쿼클 마스크에서도 금속 프레임이 잘리지 않도록
마스터를 약 90%로 축소한 뒤 원본 가장자리와 이어지는 색으로 패딩했다.

## 생성 프롬프트

```text
Use case: logo-brand
Asset type: Google Play and Android launcher icon master, square 1:1
Input image: the supplied Rune Nexus title logo is the identity reference and edit target
Primary request: isolate the existing emblem located to the LEFT of the words “RUNE NEXUS” — the cyan faceted nexus crystal surrounded by four silver mechanical brackets — and turn that emblem into a polished square app icon. Remove the wordmark completely.
Preserve exactly: recognizable crystal silhouette, four-bracket arrangement, silver/graphite metal materials, cyan energy strips, icy cyan-white highlights, sci-fi tower-defense identity.
Composition: emblem centered, front-facing, large but with generous Android adaptive-icon safe margin; all four brackets fully visible; no edge clipping.
Backdrop: deep navy-black square background with a restrained radial cyan glow and very subtle hex/circuit texture; background stays visually quiet and high contrast.
Style: crisp premium mobile game icon, clean faceted geometry, strong silhouette readable at 48px, controlled glow, not photorealistic.
Constraints: no words, no letters, no numbers, no watermark, no extra symbols, no circle badge, no rounded-corner mask baked into the image, no device frame. Keep important content within the central 66% safe zone.
```

생성 경로는 Codex 내장 ImageGen이며, Android·Play 규격별 축소본은 같은 마스터에서
결정적으로 내보냈다.

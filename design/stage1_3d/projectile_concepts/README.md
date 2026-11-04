# 대포 비행 포탄 개선 후보

2026-09-13. 사용자 요청: 현재 포탄이 흔적처럼 보이는 느낌을 개선할 후보 이미지. Built-in ImageGen으로 제작한 **형태·재질 비교용 확대 시안**이다. 게임 크기 검증이나 구현 결과가 아니며, 게임 코드·에셋은 바꾸지 않았다. 이미지 속 성벽·배경 포탑·문양은 배경 표현으로, 추가 구현 요구가 아니다.

- [A — 중량 금속탄](01-heavy-shell.png): 둥근 강철 탄두·황동 띠·짧은 주황 꼬리. 최초 비교에서 제안했던 금속탄 방향.
- [B — 달궈진 철구](02-heated-cannonball.png): 단조 철구·짧은 화염·잿빛 연기. 둥근 실루엣과 열감을 강조한다.
- [C — 룬 장갑탄](03-runic-shell.png): 각진 금속 탄체·청동 후미·청록 룬 홈. 판타지 정체성을 강조한다.

사용자가 둥근 형태를 선호하여 [둥근 철구 후속 시안](04-round-ironball.md)을 제작했다. 구현은 아직 진행하지 않았다.

## 프롬프트 구성

공통: stylized-concept, high quality 3D game projectile VFX concept for RuneNexus isometric tower defense. A single opaque heavy physical projectile in flight from lower-left to upper-right, body silhouette primary and sharp, trail shorter than body. Elevated three-quarter camera, weathered pale tan cobblestone and moss green platform tiles, restrained PBR materials, soft daylight and detached shadow. Square closeup for material and silhouette review. No explosion, no long luminous streak, no UI, no text, no collage, no watermark.

A: Matte graphite steel short ogive/rounded nose, substantial cylindrical dark iron body, one broad worn brass driving band close to base, visible bevels and warm top highlights. Compact amber tail flash behind base and 3–5 separated sparks. No cartridge case, rocket fins, engine exhaust plume or excessive bloom. Body occupies about 45 percent image width.

B: Heavy forged near-spherical iron cannonball with hammer facets. Opaque charcoal skin covers 80 percent, a few thin orange-red hot seams and restrained orange patch at rear. Short torn orange flame, compact ash-gray smoke wisps, sparse embers. Not an energy orb or fireball. Tail at most one ball diameter. Ball occupies about 35 percent image width.

C: Short chunky rune-forged artillery shell with six broad beveled gunmetal armor faces, blunt pyramidal/ogive nose, thick antiqued bronze rear collar, two narrow recessed cyan/teal rune channels. Most of shell remains opaque metal, no crystal or glowing outline, no fins. Short fragmented turquoise wisp and tiny brass sparks behind base. Body occupies about 40 percent image width.

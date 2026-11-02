# 업적 훈장 11종 (2026-11-02)

업적 팝업 「훈장」 탭의 챕터 1~3 × 노말·하드 컬렉션 훈장 6종과 누적 업적 5단계 훈장 5종. 규칙은 [스테이지 난이도 설계](../../../docs/stage_difficulty_design.md)를 따른다.

- 도구: ImageGen(Codex `gpt-6.1-sol`), 투명 배경 1254px. 참고 이미지 `assets/images/lobby_challenge_icon.png`.
- 게임 적용본: `assets/images/challenge_medals/medal_ch{1,2,3}_{normal,hard}.png`, `medal_{attendance,clear_waves,kill_bosses,kill_enemies,module_draws}.png`(`sips -Z 256` 축소).
- 누적 훈장은 `medal_ch1_normal.png`을 참고 이미지로 써서 같은 재질에 둥근 금·청동 메달, 월계 테, 청록 리본으로 컬렉션 훈장과 구분했다.
- 구분: 일반은 은색 별·남색 리본, 하드는 건메탈·금 테두리·진홍 리본. 보석은 챕터 1 청록, 2 자수정, 3 호박.

## 프롬프트

공통:

> Single game achievement medal icon for a dark sci-fi fantasy tower defense mobile game (rune crystals, steel-blue metal UI, bronze accents). Front view, centered, the medal fills about 85% of the canvas: a short folded ribbon at the top, a faceted metal star-shaped medal body with an inset glowing crystal gem in the center, crisp painterly-realistic rendering with soft rim light, consistent with the attached reference icon's materials. Transparent background, no text, no numbers, no letters, no frame, no shadow plate, no extra objects.

변형(공통 뒤에 덧붙임):

| 파일 | 변형 문구 |
| --- | --- |
| `medal_ch1_normal` | Polished silver-steel star body, deep navy ribbon with a thin cyan stripe, cyan-teal glowing crystal gem. |
| `medal_ch1_hard` | Darker gunmetal body and warm bronze-gold edges, crimson ribbon with a thin gold stripe, cyan-teal gem with a faint red outer glow. Slightly more ornate spikes. |
| `medal_ch2_normal` | Polished silver-steel star body, deep navy ribbon with a thin violet stripe, violet-amethyst glowing crystal gem. |
| `medal_ch2_hard` | Darker gunmetal star body with warm bronze-gold edges, crimson ribbon with a thin gold stripe, violet-amethyst gem with a faint red outer glow. Slightly more ornate spikes. |
| `medal_ch3_normal` | Polished silver-steel star body, deep navy ribbon with a thin amber stripe, molten amber-orange glowing crystal gem. |
| `medal_ch3_hard` | Darker gunmetal star body with warm bronze-gold edges, crimson ribbon with a thin gold stripe, molten amber-orange gem with a faint red outer glow. Slightly more ornate spikes. |

## 누적 훈장 프롬프트

공통:

> Single game achievement medal icon for a dark sci-fi fantasy tower defense mobile game (rune crystals, steel-blue metal UI, bronze accents), part of the same medal set as the attached reference medal but a distinct LIFETIME ACHIEVEMENT series. Front view, centered, the medal fills about 85% of the canvas: a short folded deep teal ribbon with a thin gold stripe at the top, a round polished warm-gold and bronze medallion framed by a faceted laurel ring, with a raised emblem in the center that glows softly. Crisp painterly-realistic rendering with soft rim light, same materials and lighting as the reference. Transparent background, no text, no numbers, no letters, no frame, no shadow plate, no extra objects.

| 파일 | 문양 문구 |
| --- | --- |
| `medal_attendance` | Emblem: a rising sun over a small rune calendar tablet, glowing cyan. |
| `medal_clear_waves` | Emblem: three stacked cresting waves, glowing cyan. |
| `medal_kill_bosses` | Emblem: a horned demon skull crowned with spikes, glowing crimson eyes. |
| `medal_kill_enemies` | Emblem: a sharp targeting crosshair reticle over crossed blades, glowing amber. |
| `medal_module_draws` | Emblem: a faceted mechanical module chip with gear teeth and a glowing violet core. |

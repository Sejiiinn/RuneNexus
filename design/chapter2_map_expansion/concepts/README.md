# 챕터 2 신규 5맵 Blender 시안

역할: [맵 좌표 원본](../maps.json)에 대응하는 편집 가능한 3D 배치 시안. 게임 적용용 내보내기가 아닌 설계 산출물이다. 2026-09-30 제작, Blender 5.2 / Cycles / AgX / 1200×1440 / 24샘플 / 25도 고정 시점 / 프레임 17.

| 표시 | 최종 렌더 | 보행 · 전송 |
| --- | --- | --- |
| 2-6 갈라진 순례길 | [chapter-2-6.png](chapter-2-6.png) | 21칸 · 없음 |
| 2-7 맞은편 파수대 | [chapter-2-7.png](chapter-2-7.png) | 6+15칸 · 청색 |
| 2-8 수정의 귀환로 | [chapter-2-8.png](chapter-2-8.png) | 5+18칸 · 주황 |
| 2-9 세 겹의 회랑 | [chapter-2-9.png](chapter-2-9.png) | 25칸 · 없음 |
| 2-10 균열의 세 문턱 | [chapter-2-10.png](chapter-2-10.png) | 6+6+9칸 · 청색+주황 |

[5맵 비교판](five-map-comparison.png), [5개 씬 원본](chapter2-five-map-concepts.blend). 원본은 씬별 길·건설 타일·지층·소품·포탈·조명·카메라를 개별 객체로 유지하고 외부 이미지·글꼴을 pack한다. 포탈의 승인된 실제 3D 면·금속 테두리·입출구 효과를 유지하며 사진 평면으로 대체하지 않았다. 비교판만 최종 렌더를 나란히 배치한다.

## 재사용한 자산

- [챕터 2 타일](../../chapter2_3d/tiles/chapter2-tiles.blend): 길·건설 상면과 층진 석재 측면.
- [챕터 2 소품](../../chapter2_3d/stage6/props/stage6-props.blend): 룬 기둥 1곳, 청록·보라 수정 2곳, 공허 균열 1곳. 비플레이 외곽의 연결 암반에 배치한다.
- [기존 지층 제작 함수](../../chapter2_3d/stage6/terrain/build_geology.py): 파단 암반·UV·절벽 파편. 연결된 플레이 덩어리별 넓은 공유 절벽 몸체를 만들고 내부 빈칸·전송 공백을 비운다.
- [공용 생성 포탈·코어](../../stage1_3d/portal_core_concepts/production/rune-landmarks.blend): 개별 모델 원본을 보존한다. 생성 포탈의 렌더 복사본에는 [기존 Godot 소용돌이 정적 번역](../../chapter1_map_expansion/concepts/portal_preview.py)을 적용한다.
- [승인된 청색·주황 전송 포탈](../../teleport_device_concepts/2026-09-30/production/teleport-four-variants.blend): 실제 IN/OUT 모델·애니메이션·절제된 광학 효과를 복사한다. 기존 챕터 2 호스트 타일의 상면만 실제 boolean 개구부로 뚫고 석재 측면은 유지한다.
- 우주 배경은 기존 `assets/images/backgrounds/combat_space_nebula.png`를 사용한다.

외곽 파편은 통행·건설칸과 포탈 공백에 놓지 않는다. 원래 타일·소품·포탈 원본과 게임 GLB는 수정하지 않았다. [승인 시각 기준](../../../DESIGNS.md)을 따른다.

## 재현

열려 있는 Blender와 미저장 작업을 보존하고 독립 background로 실행한다. `--regenerate`는 이 폴더의 시안 원본만 명시적으로 다시 만든다. 수동 편집을 유지해 렌더하려면 `--render-only`를 쓴다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/chapter2_map_expansion/concepts/build_concepts.py -- --regenerate
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/chapter2_map_expansion/concepts/build_concepts.py -- --render-only
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/chapter2_map_expansion/concepts/build_comparison.py
```

[제작 스크립트](build_concepts.py)는 좌표 JSON을 읽고 이 폴더의 PNG·pack된 Blender 원본만 쓴다. [비교판 제작 스크립트](build_comparison.py)는 렌더 PNG를 후처리 없이 배치한다. 상세 실행 로그·배치 기록은 추적 제외된 `build/chapter2-expansion-design/`에 로컬 보관한다.

실제 게임의 전투 난이도·포탑 투자·40라운드 플레이와 Android 외형은 확인하지 않았다.

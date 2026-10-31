# 대포 착탄 플립북 폭발

게임 대포 착탄의 제작 원본이다. Blender Mantaflow 화염·연기를 게임 시점(약 63°)에서 렌더한 64칸 시트를 화면과 평행한 카드로 재생하고, Godot에서 입체 파편·잉걸불·불 잔재·그을음 자국·섬광 빛을 더한다. 방향은 PoE2풍 사실 표현이며 레퍼런스는 품질만 참고한다. 역할·1.1초 길이·카메라는 기존 대포 폭발을 따른다.

## 게임 연결

| 대상 | 위치 |
| --- | --- |
| 런타임 | [flipbook_impact.gd](../../../godot/effects/flipbook_impact.gd), 셰이더 `godot/effects/cannon_flipbook_*.gdshader` |
| 섬광 빛 | [battlefield_projectiles.gd](../../../godot/presentation/battlefield_projectiles.gd)의 대포 빛 분기 |
| 게임용 시트 | [cannon_explosion_sheet.png](../../../assets/images/stage1_3d/effects/cannon_explosion_sheet.png) (2048², 8×8칸, 60fps) |
| 패키징 | [준비 스크립트](../../../scripts/prepare_godot_project.py): 고품질 VRAM 압축(모바일 ASTC, 약 5.6MB)과 밉맵 |
| 검사 | `verify_impact_motion.gd`(외부 시계 계약), `verify_blast_lifecycle.gd`, `verify_camera.gd`, `verify_effect_preparation.gd`, `verify_stage_effect_cache.gd` |

- 크기는 폭발 반경에 비례한다. 화구·진한 먼지(시트 알파 0.25 이상의 90%)가 0.15~0.45초에 폭발 반경과 같도록 `REFERENCE_RADIUS`를 정했다. 끝의 옅은 먼지는 반경의 약 1.2배까지 남는다. 시뮬레이션을 다시 구우면 다시 잰다.
- 모든 운동은 절대 나이(진행률 × 1.1초)로 다시 계산해 정지·배속·되감기·풀 재사용에서 같은 화면을 낸다.
- 카드는 깊이 검사 없이 그린다. 착탄 바로 옆 포탑·적 위에 폭발이 겹쳐 보인다.
- 섬광 빛은 착탄 프레임에 절반 밝기로 켜져 0.03초에 최대가 되고 0.25초까지 꺼진다. 반경은 폭발 반경의 약 1.7배다. 카드 자체는 빛을 받지 않고(명암을 렌더에 구움) 파편은 실제 조명을 받는다.

## 다시 만들기

Blender 5.2, Cycles Metal 기준이다. 베이크 캐시는 크기가 커서 저장소 밖에 둔다.

1. 시뮬레이션·렌더: `Blender -b --python build_sim.py -- --cache <캐시 폴더> --out <렌더 폴더>`. 베이크 뒤 `cannon_explosion_sim.blend`를 이 폴더에 저장한다.
2. 재질만 바꿀 때: `Blender -b --python render_frames.py -- --out <렌더 폴더> [--frames 6,10] [--glow 1:30,...]`. 저장된 .blend를 열어 `build_sim.domain_material`을 다시 적용한다.
3. 시트 묶기: `python pack_sheet.py <렌더 폴더> <시트.png> --first 1`. 결과를 게임용 시트 위치에 두고, 미리보기에는 같은 파일을 `godot_preview/cannon_explosion_sheet.png`로 복사한다(복사본은 추적하지 않는다).

[godot_preview](godot_preview/)는 같은 카드·입자를 고정 카메라에서 보는 단독 프로젝트다(`Godot --path godot_preview --fixed-fps 60 -- --capture=<폴더>`). 게임 셰이더가 기준이며, 미리보기 셰이더와 `main.gd`의 수치는 게임 쪽과 같게 유지한다.

## 검수 기록

- `review/cannon_explosion_current_vs_final.mp4`: 고정 카메라에서 기존 체적 폭발과 플립북 비교(크기 조정 전 판).
- `review/cannon_battle_final.mp4`: 1스테이지 대포 5개 실제 전투 녹화. 기존 폭발과 교체 후 최종본(압축 시트) 비교. 크기는 이전 판(반경의 1.3배)에서 0.77배로 줄여 맞췄고, 무손실 시트와 압축 시트의 화면 차이는 평균 0.2~0.3/255 수준이었다. 중간 판 영상은 로컬에만 둔다.
- 별도 검수 에이전트가 PoE2 레퍼런스와 네 차례 비교했다(4→6→7→7.5/10). 레퍼런스 영상과 그것을 담은 비교본은 저작물이라 저장소에 넣지 않는다.
- Android 실기기 성능과 4배속 다중 착탄은 아직 측정하지 않았다.

이전 체적 폭발(`godot_impact.gd`, 체적 캐시)은 이 폭발로 교체했으며 제작 기록은 [기존 착탄 폴더](../../stage1_3d/cannon_impact/README.md)에 남아 있다.

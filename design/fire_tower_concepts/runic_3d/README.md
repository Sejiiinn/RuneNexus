# 룬 화염 포탑 — Blender 디자인 원본

2026-09-14. 사용자가 선택한 [14번 룬 기계형 시안](../2026-09-14/14-runic-mechanism.png)을 기준으로 제작한 독립 3D 디자인이다. 후속 이관 승인에 따라 Android Godot의 `magic.glb`와 기본 재질·파티클 효과에 연결했다. [이관 원본과 검수 기록](migration/README.md)을 참고한다.

2026-09-26에는 현행 90% 크기를 유지한 [경량 모델](optimized-game-distance/README.md)을 제작하고, S26 Ultra QHD+ 비교 후 사용자 승인에 따라 게임의 `magic.glb`에 적용했다. 고해상도 제작 원본과 불꽃 효과는 보존한다. 수치·시각 검수와 게임 적용 범위는 해당 기록을 따른다.

- 편집 원본: [runic-flame-turret.blend](runic-flame-turret.blend)
- 정면 사선 렌더: [runic-flame-turret-hero.png](runic-flame-turret-hero.png)
- 반대쪽 사선 렌더: [runic-flame-turret-rear.png](runic-flame-turret-rear.png)
- 이펙트 애니메이션: [6초 MP4](vfx/runic-flame-vfx.mp4) · [반복 GIF](vfx/runic-flame-vfx.gif) · [VFX 원본 및 구성](vfx/README.md)
- 본체 제작 코드: [build_model.py](build_model.py)
- 화염 제작 코드: [flame_components.py](flame_components.py)
- 후속 마감 실행부: [finish_scene.py](finish_scene.py) — [형태](finish_geometry.py), [금속](finish_materials.py), [화염](finish_flames.py)

## 시안 대조 후 마감

- 넓었던 상면을 줄이고 팔각 어깨와 뒤쪽 모따기를 정리했다.
- 끊기거나 들떠 보이던 룬 선을 상면부터 양쪽 어깨까지 이어지는 매립 홈으로 다시 구성했다.
- 지지대의 마름모·겹꺾쇠·볼트 중심을 맞추고 각인 폭을 조정해 가장자리 여백을 확보했다. 하단은 원형 오목 홈 안의 볼트 하나로 정리했다.
- 뒤쪽의 짧은 어깨 장식을 포신의 상면·양 측면·하면을 연속해서 감싸는 청동 고정 띠로 복원했다.
- 받침 고정구를 두꺼운 사다리꼴로 바꾸고 총구 모따기·청동 마모·얕은 단조 질감과 불꽃의 부피를 보강했다.

마감 전 파일과 렌더는 `finish/before-finish.blend`, [이전 렌더](finish/before-hero.png)에 보존했다. 원본 시안은 계속 비교 기준이며, 정지 원본과 Blender 효과 영상은 그대로 보존한다.

## 편집 구조

| 컬렉션 | 내용 |
| --- | --- |
| `01 Fixed Base` | 낮은 금속 원형 받침과 청동 고정구 |
| `02 Rotating Carriage` | 회전 받침·양쪽 청동 지지대·실제 음각 룬·회전축 |
| `03 Runic Gun Assembly` | 길쭉한 팔각 몸체·속이 있는 단일 총구·음각 발광 홈·매립 상부 분출구 |
| `04 Flame Study` | 상부와 포구의 별도 편집 가능한 입체 불꽃 메시 |
| `90 Studio` | 카메라·조명·검수용 바닥 |

좌표는 Z 위, -Y 전방이며 받침 지름은 0.86이다. `turret_root`·`turret_head`·`turret_barrel`·`muzzle`·`upper_flame_port`로 편집 부위를 구분했다. 게임 이관에서는 같은 축·계층·부착점을 보존하고 GLB 좌표계를 변환한다.

선택 시안은 Blender 내부 `REFERENCE — selected concept 14` 이미지로 패킹했다. 금속의 색 변화·거칠기·미세 요철, 화염의 색과 체적 발광은 노드로 편집한다. 불꽃은 닫힌 입체 메시 내부에 노이즈 기반 체적 발광을 적용한 형태 연구이며 유체 시뮬레이션이나 게임용 애니메이션이 아니다.

## 수정과 재생성

완성 `.blend`를 직접 열어 편집하고 별도 버전으로 저장한다. `build_model.py`는 최초 제작 과정을 보존한 함수 모음이며 수동 편집을 역으로 반영하지 않는다. `finish_scene.py`의 `apply_finish(scene)`은 해당 독립 장면에 후속 마감을 재적용하며 대상 부위의 수동 편집을 대체하므로, 반드시 사본에서 실행한다. 저장·렌더·게임 내보내기를 자동 실행하지 않는다. 게임용 내보내기는 별도 `migration/export_native.py`를 사용한다. 최초 제작 스크립트로 현행 게임 모델을 다시 만들지 않는다.

렌더는 Blender에서 촬영한 3D 모델 검수 이미지다. ImageGen 시안이나 실제 게임 화면과 구분한다.

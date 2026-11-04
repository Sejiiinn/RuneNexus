# 냉각 포탑 meshoptimizer 전후 비교

현행 게임 냉각 포탑 47,912삼각형에 `meshopt_simplifyWithAttributes`를 적용한 별도 비교본이다. 최종 후보는 **33,566삼각형, 29.9% 감소**이며 GLB는 11,371,160 → 10,336,684바이트(9.1% 감소)이다. 원본 제작 파일과 게임 `frost.glb`는 변경하지 않았다. 게임 반영·커밋·APK 빌드·FPS/GPU 측정은 수행하지 않았다.

| 항목 | 원본 → 최종 |
|---|---|
| 삼각형 | 47,912 → 33,566 |
| 메시 / 표면 / 재질 | 3 / 19 / 13 유지 |
| 내장 이미지 | 7장, 바이트 동일 |
| 상대 오차 제한 | 0.002, options 0 |
| 감량 방식 | 인덱스 선택, 정점 위치 이동 없음 |

[최종 GLB](frost-meshopt.glb), [패킹된 편집본](frost-meshopt.blend), [감량 기록](meshopt-manifest.json), [Blender 비교 조건과 재열기 기록](render-manifest.json).

## 보존과 검사

19개 재질 표면을 개별 처리했다. 정확히 일치하는 위치+UV만 임시 연결하며, 최종 정점의 위치·UV·노멀 및 다른 속성은 원본 corner tuple에서 그대로 선택한다. 실제 UV 이음, 재질 경계, 기하학적 열린 경계와 비정상 경계, 표면별 경계 좌표와 bounds를 보존한다. 이 원본에는 tangent 속성·스킨·애니메이션이 없다. 새 UV·베이크·Decimate·텍스처 수정은 없다.

6장 곡선 셔터·틈, 72개 핀·6개 베이, 4발과 오목한 창, 투명 렌즈, 청동과 서리 코팅을 보존했다. 루트/헤드/배럴/총구 노드 변환과 계층, 충전 재질 이름·PBR 값·모든 텍스처 및 sampler, 내장 이미지 바이트를 유지한다. 독립 검증은 각 surface의 원본 corner tuple subset, bounds, component·Euler·boundary·nonmanifold·zero-area와 전체 경계 좌표쌍을 대조했다.

Blender 5.2.2 Cycles CPU, 1100×1100, 48샘플, seed 0, AgX를 사용했다. 원본과 최종 GLB를 직접 가져와 같은 정투영 카메라·조명·배경으로 비교한다. 원본 [정면](before-hero.png) / [반대편](before-opposite.png), 최종 [정면](after-hero.png) / [반대편](after-opposite.png). Godot 4.7.2 Mobile/Metal fixture 전장에서 동일 카메라·조명·충전량으로 고정/드론 × 기본/2.5배의 4쌍을 직접 비교했다. [고정 확대 전](review/runtime-original-angled-detail.png) / [후](review/runtime-optimized-angled-detail.png), [드론 확대 전](review/runtime-original-drone-detail.png) / [후](review/runtime-optimized-drone-detail.png), [조건](review/runtime-conditions.json)을 보관한다. 실제 게임 렌더 코드를 사용한 격리 비교이며 정식 앱 HUD·전투 전체·Android 검수는 아니다. 이미지 리사이즈 없이 동일한 원본 기준 사각형으로 잘랐다. [독립 검증](review.md)은 최종 GLB·편집본과 두 렌더 경로를 PASS로 판정했다. 렌즈와 볼트 반사의 미세한 차이는 있지만 주요 형태·서리·틈·핀·비율의 손상은 관찰되지 않았다. 배경 Blender 프로세스는 정상 종료했고 기존 GUI 문서는 보존했다.

상대 오차 0.001의 보수 후보도 36,460삼각형(23.9% 감소)으로 생성했다. 최종 선택은 0.002 후보의 근접 Blender 렌더와 Godot 고정/드론 시점, 원거리/확대 비교의 독립 시각 검사 PASS에 따른다. 감량률을 같은 비율의 프레임 성능 개선으로 해석하지 않는다.

원본 SHA256: `7d71195e972710488c6912d68b1f3d5eb54ee38adf31f9a524788a8d1d3aee39`.

최종 GLB SHA256: `48d6fa91435b38acb49637a59189cfed85d6e093b08e2e6bb5e464ae7b7d2a88`.

## 재현

```sh
/Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 design/frost_tower_concepts/2026-09-23/meshoptimizer-preview/scripts/optimize_frost.py --source assets/images/stage1_3d/turrets/frost.glb --error .002 --output design/frost_tower_concepts/2026-09-23/meshoptimizer-preview/frost-meshopt.glb
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/frost_tower_concepts/2026-09-23/meshoptimizer-preview/scripts/render_comparison.py
```

감량 라이브러리는 `/Volumes/KIOXIA_MAC/AI-3D/apps/Blender.app/Contents/Resources/lib/libmeshoptimizer.dylib`이며 정확한 해시는 감량 기록에 저장한다. `checks/`의 시험 후보·원시 로그·독립 검사 덤프는 로컬 검증 자료이며 Git 추적에서 제외한다. 별도 외부/클라우드 백업은 만들지 않았다.

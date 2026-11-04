# 냉각 포탑 1만 삼각형 감량 시험

**11,104삼각형까지 줄인 실제 후보를 만들었지만 외형 검수는 FAIL이다.** 검수 통과한 33,566삼각형 비교본과 게임 원본 47,912삼각형은 보존했다. 실패 후보를 게임에 반영하지 않았다. 커밋·APK·FPS/GPU 측정도 수행하지 않았다.

[원본 47,912삼각형](before-hero.png) → [11,104삼각형 실제 Blender 렌더](after-11k-hero.png). 같은 1100×1100 Cycles CPU, 48샘플, 정투영 카메라·조명·배경으로 렌더했다. 손실 확인용 [GLB](frost-meshopt-11k-preview.glb)와 [7장 이미지가 패킹된 편집본](frost-meshopt-11k-preview.blend)은 후보 보관용이다.

11,104삼각형은 원본 대비 76.8% 감소다. `meshopt_simplifyWithAttributes`, options 0, 원본 정점 선택을 사용했다. 정점 위치 이동, 새 UV, 재베이크, Decimate, 절차적 재제작, 텍스처 수정은 없다. 각 기하학적 성분을 따로 감량하며 작은 부품 삭제·Euler 변경·nonmanifold 증가가 생기는 오차는 낮춰 재시도했다. 노드 계층·변환·PBR 값·13재질·7개 내장 이미지 바이트는 보존했다.

그러나 wholemesh position-only 임시 연결 뒤 원본 코너 UV·노멀을 선택해 다시 붙이는 과정에서 다음 손실이 생겼다.

- 셔터 틈·외곽, 수직 기둥·하부 링·지지발에 검은 줄과 찢어진 UV 무늬가 생겼다.
- 냉각핀의 청록 표면과 단면이 원본과 다르게 읽힌다.
- 본체 37개 삼각형의 세 코너에 공통 원본 재질 소유권이 없으며, 본체 냉각핀 재질 표면 2가 빠져 19표면에서 18표면이 되었다. 원본 충전 재질의 표면 할당이 달라졌다. 준비 완료 상태의 청록광은 보이지만 전체 충전·방출 동작 보존은 미검증이다. 원본 코너 속성 바이트가 남았다는 사실이 올바른 표면 재질·UV 연결을 뜻하지 않는다.

최종 진단 GLB는 빈 primitive와 0개 accessor를 제거해 가져오기 가능한 18표면으로 보관한다. 원본의 전체 기하학 성분 수와 bounds, Euler는 유지되었지만 재질별 형태·외형 보존을 통과하지 못했다. 패킹·재열기 검사는 3메시·11,104삼각형·7패킹 이미지·dirty false를 확인했다. [수치·실패 기록](meshopt-preview-manifest.json), [렌더·재열기 조건](candidate-render-manifest.json).

## 탐색 결과

| 경로 | 삼각형 | 결과 |
|---|---:|---|
| 기존 UV 연결·기존 경계 보호, 오차 0.008 | 31,434 | 구조 통과, 목표 미달 |
| UV 연결 유지·재질 접합 보호·대표 extrema·성분별 처리, 오차 0.3/UV·노멀 가중치 0 | 29,802 | 이번 탐색의 구조 통과 최소, 시각 미확인 |
| 재질별 position-only 임시 연결, 오차 0.03 | 22,054 | 렌즈 림의 톱니·검은 재질 이음으로 Godot/Blender 시각 FAIL |
| wholemesh position-only 임시 연결, 오차 0.008 | 20,632 | 목표 미달, 시각 미확인 |
| wholemesh position-only 임시 연결, 오차 0.03 | 12,810 | 목표 근접, 시각 미확인 |
| wholemesh position-only 임시 연결, 오차 0.1 | 11,104 | 실제 Blender/Godot 비교에서 시각 FAIL |

29,802는 이번 보호 조건과 탐색에서 얻은 값이며 모든 가능한 감량법의 수학적 하한이 아니다. UV 재구성·재베이크 같은 제작 경로 변경을 검토하려면 별도 범위 판단이 필요하며, 그런 변경만으로 형태·충전 계약 통과가 보장되지는 않는다. 기존 UV 차트와 재질 접합을 보존하면 코팅 표면과 작은 부품의 고정 정점이 많이 남는다. 그 연결을 풀면 감량 수는 줄지만 원본 코너만으로 새 면에 일관된 UV·재질을 붙이기 어려워 실제 손실이 생긴다. 이번 시험에서는 1만 내외와 승인 외형을 함께 충족하지 못했다.

최종 손실 후보 GLB SHA256: `9602b68f58d0ca2ae4d9ecdc9948a7d7f288990e27b3bfa1780c8ba25bc9c386`.

원본 SHA256: `7d71195e972710488c6912d68b1f3d5eb54ee38adf31f9a524788a8d1d3aee39`.

## 재현

```sh
/Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 design/frost_tower_concepts/2026-09-23/meshoptimizer-preview-10k/scripts/wholemesh_frost.py --error .1 --target 10000 --output design/frost_tower_concepts/2026-09-23/meshoptimizer-preview-10k/checks/frost-wholemesh-e1.glb
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/frost_tower_concepts/2026-09-23/meshoptimizer-preview-10k/scripts/render_candidates.py
```

`scripts/optimize_frost.py`는 경계 보호·대표 bounds·성분별 fallback·UV 차트 진단 후보를 만드는 재사용 도구다. `scripts/wholemesh_frost.py`는 실패 가능성을 명시한 전체 메시 시험 도구다. 원시 로그·대조용 후보·내보내기 결함 수정 이전의 invalid 파일은 `checks/`에 로컬 보관하고 추적에서 제외한다. invalid 후보는 최종 수치나 시각 판단에 사용하지 않았다. Blender background 프로세스는 정상 종료했고 기존 GUI 문서는 보존했다.

## 최종 엔진 비교

[독립 검증](review.md)은 외형 FAIL이다. [원본 고정 시점](review/original-angled-crop-native.png) / [11,104 후보 고정 시점](review/optimized-angled-crop-native.png), [원본 드론 시점](review/original-drone-crop-native.png) / [11,104 후보 드론 시점](review/optimized-drone-crop-native.png)은 동일 카메라·조명의 실제 Godot fixture 화면이다. [실행 조건](review/capture-conditions.json)의 후보 SHA는 최종 진단 GLB와 같다. 기본 화면 크기에서도 기둥과 하부 링의 검은 절개가 읽힌다. Android 및 전체 전투·충전 동작은 검증하지 않았다.

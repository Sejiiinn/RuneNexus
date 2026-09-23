# 표면 서리 실제 3D 적용

2026-09-23. [승인 시안](../frost-coated.png)의 얇은 청백색 결정성 서리를 현재 냉각 포탑에 적용했다. [이전 형상](../../production/detail-refinement/README.md)의 두꺼운 곡선판 6장·판 사이 틈·기둥 연속 구조·렌즈·냉각 베이 6개·발 4개를 유지한다.

## 실제 구현과 원본

최종 편집 원본은 [production/frost.blend](../../production/frost.blend), 게임용 원본은 [production/frost.glb](../../production/frost.glb)다. 같은 최종 GLB를 `assets/images/stage1_3d/turrets/frost.glb`로 복사하고 [HUD](../../production/hud-frost.png)도 같은 모델에서 다시 렌더했다.

Blender에서 기존 금속·청동 재질 5종에 불규칙한 작은 결정 패치, 실제 모서리 주변의 얇은 서리, 미세 표면 법선과 거칠기를 혼합했다. 넓은 금속 면과 청동 중앙은 남겼으며 충전핀·렌즈·광원은 바꾸지 않았다. 균일한 망 무늬가 되던 첫 후보는 채택하지 않았다(`iteration1-too-uniform.png`).

이 절차는 승인 이미지를 판에 붙여 모델을 대체하지 않는다. 실제 입체 표면에 부착되는 PBR 재질을 만들고 색상·접선 법선·거칠기/금속성(ORM)을 2048 공유 atlas 3장으로 베이크한다. 게임에는 베이크된 표준 PBR 재질만 전달하므로 Blender 절차적 노드나 새 실시간 입자/노드를 실행하지 않는다. 서리 영역은 비금속 재질로 반응하며 원래 금속 부분은 금속성을 유지한다. 원본 Blender에는 절차적 원재질 노드와 최종 베이크가 함께 남아 있다.

[베이크 감사](surface-bake-audit.json)는 124개 편집 부품에 UV만 추가하고 정점·면·변환을 바꾸지 않았음을 확인했다. [독립 GLB 구조 대조](geometry-comparison.json)도 전후 13개 재질의 모든 삼각형 위치 집합과 노드 변환이 같음을 확인했다. 실루엣, 판 두께·틈, 리브·발 연결은 변하지 않았다.

## 검증 근거

| 항목 | 근거 |
|---|---|
| 베이크된 서리·금속·청동 가독성 | [Blender 사선](detail-hero.png), [상단](detail-top.png) |
| 실제 게임 형태·표면 | [사선](godot/model-hero.png), [상단](godot/model-top.png), [게임 크기](godot/app-angled-selected.png) |
| 기존 충전 보존 | [충전 중](godot/detail-charging.png) |
| 기존 안개 알파 0.36 보존 | [방출 중](godot/detail-release.png) |
| 실제 건설·발사·적 감속 | [앱 결과](godot/report.json), 실패 0 |
| 기존 충전·시간·재사용 계약 | [계약 검사](contract.log), 실패 0 |
| 실제 사용하는 UV | [31개 텍스처 슬롯 검사](../../production/glb_uv_validation.json), 모두 PASS |
| 원본/게임 GLB·HUD 동일 및 런타임 소스 일치 | [해시·일치 검사](artifact-verification.json) |

Godot 4.7.2, Apple M4, Metal Forward Mobile, 660×1100 실제 `--app`에서 확인했다. 실행은 격리 프로젝트 `build/godot/frost-surface-integration` 및 저장 `RuneNexus-Frost-Surface-Integration`을 사용했다. 기존 Blender 파일·열린 장면과 Godot 편집기/local-play 및 사용자 저장은 덮어쓰지 않았다. 실제 게임 코드·충전 shader·안개 shader·전투 계산·저장 스키마를 바꾸지 않았다.

최종 GLB SHA-256: `e84d5a97650056d139fd6a61868e621042955937d0584c996416dc6cc59a8544`.

이번 하네스는 관련 스크린샷만 저장한다. `report.json`의 `video_frames`는 관찰한 프레임 수이며 별도 영상 생성 수가 아니다. 기존 정지/4배속 계약 근거를 확대해 재검사하지 않았다.

## 비용

- 삼각형 **72,752**, 런타임 메시 **3**, 표면 **19**, 내장 이미지 **7**로 모두 동일하다.
- GLB는 **7,365,020 → 12,576,616바이트**, **+5,211,596바이트(약 5.21MB)**다. 기존 금속 이미지 3장을 더 넓은 부품 영역을 담는 2048 PBR atlas 3장으로 바꾼 증가이며 이미지 개수나 메시 중복은 늘지 않았다.
- 이미지 해상도를 RGBA8로 환산하면 전체 텍스처의 기본 레벨은 **25→61MiB(+36MiB)**, 완전한 mip chain을 포함한 증가분은 약 **48MiB**다. 이는 포맷을 가정한 비교값으로 실제 GPU 할당량 측정이 아니다. 런타임 포맷·압축과 실제 GPU 시간·전체 FPS·Android 기기 성능은 이번에 측정하지 않았다.
- 게임에는 정적 PBR 텍스처만 추가 적용하고, 표면 서리를 위한 별도 메시·드로 표면·입자 처리를 만들지 않았다. APK는 만들지 않았다.

## 재현

기존 [build_frost.py](../../production/build_frost.py)와 새 [bake_surface_frost.py](../../production/bake_surface_frost.py)를 같은 Blender에서 사용한다. 후자는 실행 공간에 `prepare(ns)`와 `bake(ns)`를 제공한다.

```python
ns = {"FROST_OUTPUT_PATH": "/absolute/output/directory"}
exec(compile(open(".../production/build_frost.py").read(), "build_frost.py", "exec"), ns)
coat = {}
exec(compile(open(".../production/bake_surface_frost.py").read(), "bake_surface_frost.py", "exec"), coat)
coat["prepare"](ns)  # Blender 표면 재질: 먼저 렌더해 분포 확인 가능
coat["bake"](ns)     # 실제 표면 UV와 basecolor/normal/ORM 베이크
ns["export"]()
ns["render"]("hero")
ns["render"]("top")
```

`build_frost.py`만 실행하면 서리 적용 전의 기본 PBR 모델이 생성되므로 현재 최종 외형 재현에는 후속 베이크가 필요하다. 출력 GLB와 Blender 원본을 `production/`으로 반영한 뒤 기존 `render_hud_icon.py`와 `check_glb_uv.py`를 사용한다. 제작 전 원본은 `before/`, 최종 베이크는 이 폴더의 `textures/` 및 `production/textures/frost_surface_*.png`에 보관했다. 이전 충전·안개 시안 Blender는 역사 자료이며 현재 편집 원본과 혼동하지 않는다.

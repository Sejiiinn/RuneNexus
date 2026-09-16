# Godot 몸체 불꽃 플립북 시안

2026-09-16. 기존 화염 포탑의 상부 불꽃을 Godot 기본 GPU 입자와 빌보드로 표현한 별도 시안이다. 본게임의 효과 코드·에셋·저장·공격 동작은 변경하지 않았다.

- [Godot 실행 영상](godot-flame-preview.mp4): 약 8초, 880×760, 30fps. 고정 → 드론 → 뒤쪽 시점. Godot Movie Maker로 만든 시각 검수 영상이며 FPS 측정 자료가 아니다.
- [고정 시점](godot-fixed.png), [드론 시점](godot-drone.png), [뒤쪽 시점](godot-rear.png), [작은 표시 크기](godot-game-size.png). 뒤쪽·작은 크기 캡처는 컨트롤 크기 조정 전 화면이며 불꽃 구현은 같다.
- [미리보기 장면](preview.tscn), [미리보기 코드](preview.gd), [재사용 가능한 몸체 효과 장면](body_fire.tscn).
- [아틀라스 제작 기록](atlas/README.md), [검증 기록](verification.json).

## 구성

`GPUParticles3D` 두 개와 `StandardMaterial3D`·`ParticleProcessMaterial`만 사용한다. 사용자 정의 셰이더나 입자별 CPU 이동 계산은 없다.

| 요소 | 구성 | 최대 삼각형 |
| --- | --- | ---: |
| 몸체 불꽃 | 고정된 QuadMesh 입자 1개, 4×4 플립북, 16프레임·1초 반복 | 2 |
| 떠오르는 불티 | QuadMesh 입자 8개, GPU 이동·크기·색·알파 변화 | 16 |
| 몸체 효과 합계 | 입자 최대 9개 | 18 |

기존 상부 불꽃의 주황 외곽과 황색 중심·비대칭 상승 형태를 Blender 원본에서 렌더했다. 아틀라스는 1024×1024 RGBA이며 GIMP에서 패킹했고, `.blend`·16개 프레임·`.xcf` 원본을 `atlas/`에 보관했다. 기준 모델은 `assets/images/stage1_3d/turrets/magic.glb`, 부착점은 `upper_flame_port`다. 미리보기 준비 시 개발 전용 프로젝트에 복사한다.

기존 몸체 효과의 메시 구성상 최대 20,800개 삼각형과 비교하면 기하 처리량을 크게 줄인 구성이다. 투명 픽셀 중첩·텍스처 메모리·GPU 입자 비용은 남으며, 실제 FPS 개선은 측정하지 않았다. 포구·발사체·적 화상은 이번 시안에 포함하지 않았다.

## 실행

기존 [Godot MCP 편집 프로젝트](../../../../.agents/godot_mcp_guide.md)가 준비된 상태에서 저장소 루트에서 실행한다.

```sh
python3 design/fire_tower_concepts/runic_3d/flipbook_preview/prepare_preview.py
```

Godot 파일 재검색 후 `res://previews/runic_fire/preview.tscn`을 실행한다. 하단 버튼으로 고정·드론·뒤쪽·작은 크기·정지/재생을 선택할 수 있다. `C`는 고정/드론 전환, `Space`는 정지/재생이다. `body_fire.tscn`을 열면 두 입자 노드의 설정과 기본 재질을 직접 편집할 수 있다.

영상 재생성은 에디터 실행을 중지한 뒤 `capture_preview.py`에 FFmpeg 실행 파일 절대 경로를 전달한다. 임시 AVI는 인코딩 후 제거한다.

## 검수 범위

Godot 4.7.2 stable, macOS Apple M4, Metal / Forward Mobile에서 실제 실행했다. 불꽃 프레임 변화·불티, 세 시점의 부착과 투명 경계, 작은 표시 크기, 정지/재생을 확인했다. 정지 상태의 두 PNG가 바이트 단위로 동일하고 런타임 오류는 0개다. 아틀라스의 16개 프레임·행우선 패킹·루프 경계는 별도 제작 기록에서 확인했다.

빌보드는 카메라를 향하므로 기존 입체 메시와 시점별 입체감은 다르다. 이 결과는 데스크톱 시안 검수이며 Android 본게임·실기기 성능 검증을 대신하지 않는다.

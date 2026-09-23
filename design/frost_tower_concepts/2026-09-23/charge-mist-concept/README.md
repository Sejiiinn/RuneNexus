# 냉각핀 충전·방사 서리 안개 애니메이션 시안

[8초 동영상](preview.mp4) · [재생 페이지](preview.html) · [독립 검증](review.md)

후속 작업: [Godot 게임 적용·실제 화면](integration/README.md) · [다중 안개 성능 측정](performance/report.md). 아래 내용은 최초 시안 제작 범위의 기록이다.

승인한 냉각 포탑을 고정한 채 아래→위 청록 충전, 준비 유지, 적 접근, 입체 서리 안개 방출과 충전 초기화를 보여준다. 실제 게임 판정·저장·회전 코드·게임용 에셋은 변경하지 않았다.

## 동작

- 0–2.5초: 냉각핀 하단부터 발광이 올라간다.
- 2.5–4.65초: 준비 상태 유지. 적은 3.5초부터 접근한다.
- 4.65–5.7초: 충전 초기화와 함께 낮은 입체 안개가 방사 팽창·소멸한다. 적 표면의 청백색 변화는 냉각 반응을 보여주는 시안이다.
- 5.7–8초: 소모 후 냉각 상태. 적이 초기 위치로 돌아가 다음 루프 시작 상태와 연결된다.

반경 1.58타일은 시안용 효과 스케일이다. 노이즈로 흐린 안개 외곽의 시각 범위를 뜻하며 충돌 경계·실제 밸런스 값은 아니다. 6베이·6셔터·얼음 렌즈·4지지발과 금속 재질은 승인 GLB를 그대로 사용했다. 본체·헤드·셔터에는 회전이나 개폐 애니메이션이 없다.

## 원본과 근거

- `charge-mist.blend`: 승인 원본에서 복사한 편집 가능한 포탑, 핀 재질 충전 키프레임, 입체 안개 원형과 32개 공유 메시 애니메이션. 24fps/192프레임. 현재 열린 다른 Blender 파일은 저장하거나 덮어쓰지 않았다.
- `mist-volume.glb`: Blender에서 만든 불규칙한 폐곡면 메시. 평면·빌보드·플립북이 아니다.
- `concept.gd`, `charge.gdshader`, `mist.gdshader`: 최종 Godot 시안 동작·재질. 핀은 월드 높이로 충전 경계를 계산하고 안개는 GPU에서 외부 age/seed로 변형한다.
- `stage-036.png`: 충전 중간. `stage-066.png`: 준비. `stage-117.png`: 분출 시작. `stage-126.png`: 확산. `stage-138.png`: 소멸. `stage-168.png`: 초기화.
- `actual-scale.png`: 카메라 폭 9.5타일의 축소 표시 보조 근거. 본게임 동일 HUD·동일 카메라 캡처는 아니다.
- `frames/`: 1100×800, 24fps, 192개 실제 Godot 렌더 프레임.
- `source-integrity.json`: 보존한 승인 원본 해시. 게임 GLB SHA256 `43d87d3eae5fb3ac0867bcf4701e36df17b77570221d00f11dc08785aad26d26`.

Blender 원본은 형태·키프레임 편집용이다. 최종 투명 감쇠·노이즈·조명과 영상의 정확한 표현은 Godot shader/프로젝트가 기준이다.

## 성능 설계와 확인 범위

안개는 정적으로 준비한 **1 MultiMesh / 32 인스턴스 / 1 공유 메시·재질 / 128² 공유 노이즈**다. 원형 312정점·576삼각형, 전체 인스턴스 기준 9,984정점·18,432삼각형. CPU는 안개 인스턴스 transform을 매 프레임 순회하거나 생성·삭제하지 않는다. age 한 값과 표시 상태를 전달하며 팽창·분포·소멸은 GPU가 계산한다. idle/end에는 노드를 숨긴다. GPU 이동 범위를 포함한 AABB를 지정했다.

안개 픽셀은 노이즈 2회 읽기, 앞면만 표시하며 raymarch·실시간 체적 조명·후처리 blur를 사용하지 않는다. 충전용 무그림자 OmniLight는 1개다. 기존 냉각핀 재질 교체는 표면 draw를 추가하지 않는다. 배경 조명 2개와 지면은 시안 표시 환경이다.

Apple M4 / Godot 4.7.2 / Metal Forward Mobile / 1100×800 실제 실행의 RenderingServer 집계는 준비 **50 draw**, 확산 **51 draw**였다. 전체 장면 primitive 집계 95,709→96,301은 엔진 보고값이며 MultiMesh 인스턴스 곱을 반영한 실제 GPU 삼각형 총량으로 해석하지 않는다(`runtime-stats.json`).

이는 저비용 구조와 정상 렌더 확인이다. GPU 시간·프레임 p95·다중 포탑 중첩·Android 실기기 성능은 미측정이다. 투명 안개가 겹치면 화면 점유와 픽셀 중첩 비용이 증가한다. 데스크톱 영상으로 모바일 성능 개선을 주장하지 않는다.

## 재현

저장소 루트에서 실행한다. 테스트 프로젝트와 사용자 저장 경로는 본게임과 분리된다.

```sh
python3 design/frost_tower_concepts/2026-09-23/charge-mist-concept/prepare_preview.py
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --editor --path build/godot/frost-charge-concept --import --quit
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --path build/godot/frost-charge-concept
```

마지막 명령 뒤에 `-- --capture`를 붙이면 192프레임과 대표 이미지·통계를 재생성하고 종료한다. `concept.gd`의 OUT은 이 작업 디렉터리 절대 경로이므로 저장소 이동 시 변경한다. Blender에서 편집하려면 `charge-mist.blend`를 별도로 연다. `build_concept.py`는 승인 원본 Scene을 `Frost charge mist concept` 이름으로 append한 후 실행하는 제작 스크립트이며, `animate_blender.py`는 그 Scene에 전체 안개 키프레임을 추가한다. 이미 완성된 원본에 중복 실행하지 않는다.

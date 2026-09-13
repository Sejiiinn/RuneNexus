# 공통 얼음 결정 원본

`../export_shared_crystals.py`를 Blender background에서 실행하면 승인 시안의 생성기·난수 순서·표면 raycast를 유지하면서 공통 메시와 부착 변환만 내보낸다. 승인 원본 `.blend`와 적 원본은 수정하지 않는다.

- 게임용 `crystals.glb`: `FrostShard`, `FrostGrain` 두 단위 메시, 각각 1 surface, 텍스처 없음.
- `attachments.json`: 6종 이름의 배열에 40개 결정과 95개 작은 결정의 부착 변환을 저장한다. 종별 시각 메시·재질·텍스처는 만들지 않는다.
- `_variants`: 40개 면 색 패턴과 twist. 세 색 ID는 `_schema.face_materials` 순서다.
- 각 `transform`: Godot Y-up의 `basis.x`, `basis.y`, `basis.z`, `origin` 순서로 12개 수치. 결정의 `variant`는 `_variants` 인덱스다.
- `FrostShard`의 UV.x는 원본 polygon 번호 / 13, UV.y는 끝점만 1이다. 끝점 외에는 shader에서 `x'=cos*x+sin*z/.68`, `z'=-.68*sin*x+cos*z`를 적용한다. 끝점은 고정하고 면 법선을 다시 계산한다. 단순 Y축 회전은 타원 단면과 고정 끝점을 보존하지 못한다.
- `shared-crystals.blend`에는 40개 원형 검증용 메시도 보관한다. 이 원형들은 게임용 GLB에 포함되지 않는다.

검증 수치는 `manifest.json`에 기록한다. 6종 모두 동일한 면 색 패턴을 사용하며, 원본 배치 재구성 최대 오차는 1.89e-7이다. 단일 결정의 shader 회전 재구성은 단위 좌표에서 최대 7.51e-6 오차다. GLB의 face ID 0–12와 tip flag 0/1도 확인했다.

# 대포 착탄 입자 GPU 모션 전환

2026-09-14. 기존 CPU의 불티 56개·금속 파편 34개별 MultiMesh transform 갱신을 vertex shader로 옮겼다. seed 1404의 입자 매개변수는 공유 RGBA32F 3×90 텍스처에 한 번 담고, MultiMesh transform은 identity로 유지한다. 효과마다 별도 재질의 나이·반경·방향 uniform만 갱신한다. 체적 화염의 밀도장·광선 적분 경로는 유지한다.

## 외형·시간 계약

기존 입자 수·난수 호출 순서·메시·탄도·지연·수명·크기·회전을 보존한다. 불티는 +Z 기준 최단 회전, 파편은 전체 입자 인덱스 56~89와 XYZ Euler 회전을 사용한다. 금속 파편의 불투명 PBR 값과 Godot Mobile의 기존 스케일 후 회전 normal 경로를 따른다.

전체 시간은 외부 `progress × 1.1초`이며 셰이더 `TIME`이나 자체 프레임 진행을 사용하지 않는다. 정지·배속·되감기·풀 재사용은 전달된 progress를 그대로 반영한다. 카메라만 움직이면 나이를 바꾸지 않는다. 반경별 전체 탄도 AABB와 0.6초 이후 불티 숨김, 종료 시 전체 숨김을 유지한다.

## 회귀 검사와 측정

[검증 스크립트](../../../../godot/verify_impact_motion.gd)는 [seed fixture](../../../../test/fixtures/godot/impact_seed_1404.json)의 90개 입자 값을 GPU 데이터와 대조한다. fixture는 전환 전 실제 CPU 스크립트를 실행해 캡처했으며, 해당 baseline 파일은 HEAD `f9c0dc1`의 `godot/effects/godot_impact.gd`와 SHA-256 `8e0dc957b6d1a8568ecebad15a3a2888a0fec14f2a256ac9fcf9b86d2b7fab5c`가 같다. fixture는 배포 Godot 원본 밖에 둔다.

Godot 4.7.2 headless에서 seed 데이터·정적 버퍼 불변·시계 정지·되감기·ID와 반경 변경·풀 재사용·카메라 갱신·동시 효과 격리·그룹 가시성·AABB 계약 검사가 통과했다. 실제 GPU vertex 출력, 개별 입자의 생존 표현과 조명은 이 검사로 확인하지 않는다.

[회전 수학 검사](../../../../test/godot/impact_rotation_math.gd)는 Godot의 기존 Basis/Quaternion을 기준으로 GPU float32 식을 비교한다. 23방향·90입자의 시간격자와 생성/소멸/착지 경계에서 188,117회를 비교했다. 불티 quaternion의 길이 보정을 반영했으며 실제 불티 정점의 회전 변위 차이는 반경 1에서 최대 3.95×10⁻⁷타일이다. [실행 결과](rotation-math.log)는 CPU에서 수식을 비교한 값이며 실제 GPU readback 결과가 아니다. 기존 장면·카메라 검사와 관련 Flutter 테스트 14개도 통과했다.

프로젝트를 준비한 뒤 저장소 루트에서 실행한다. `--benchmark`와 경로를 생략하면 계약 검사만 수행한다. baseline은 위 커밋에서 추출한 전환 전 파일을 지정한다.

```sh
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot \
  --headless --path build/godot/project \
  --script res://verify_impact_motion.gd -- \
  --fixture "$PWD/test/fixtures/godot/impact_seed_1404.json" \
  --benchmark "$PWD/build/impact-gpu-baseline/godot_impact.gd"
```

이번 측정은 동일 소스와 셰이더를 복사한 독립 `build/impact-motion-check` 프로젝트에서 수행했다. 16개 효과 × 1,000회 업데이트, 워밍업 후 순서를 교대한 5회 중앙값은 기존 CPU **1,014.216ms**, 전환 후 CPU 제출 **35.035ms**로 약 **28.95배** 차이다. 이는 실제 Godot 엔진의 headless CPU 호출 부하이며, GUI 렌더·GPU 프레임 시간·Android FPS 개선 수치가 아니다.

## Android 검수

Android ARM64 에뮬레이터의 일반 `lib/main.dart` debug APK에서 메모리 저장소와 기존 대포 6문·정지 표적 3기 시험 배치를 사용했다. 1배속 다중 착탄을 정지한 뒤 나이가 유지되는 것을 확인했고, 고정/드론 시점과 4배속 재생에서 불티·회전하는 금속 파편·소멸·회색 먼지·짧은 화염을 확인했다. 최종 프로세스 로그에 스크립트·셰이더 컴파일 오류는 없었다. 시험 입력 파일은 PCK에 포함되지 않는다.

- [고정 시점의 정지 착탄](android-paused.png)
- [4배속 드론 시점의 실제 프레임](video-check-0.png), [8초 영상](android-4x.mp4)
- [검증 환경·소스 해시](verification.json), [계약 검사](contract.log), [장면 검사](runtime.log), [카메라 검사](camera.log), [Flutter 검사](flutter-tests.log)

운동 계산은 정점마다 실행되므로 CPU 갱신 감소량을 GPU 또는 전체 프레임 개선율로 해석하지 않는다. A34 실기기의 GPU 시간·FPS·지속 부하 성능은 미측정이다. 이번 변경에는 엔진·네이티브 의존성·게임 이미지 추가가 없고, 공개 배포는 수행하지 않았다.

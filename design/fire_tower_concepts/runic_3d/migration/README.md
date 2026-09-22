# 룬 화염 포탑 — Godot 이관

현재 크기·내보내기 원본은 [2026-09-22 전체 90% 축소](../scale-90/README.md)를 따른다. 아래 초기 이관 기록은 형상·재질 보존 근거다.

2026-09-14. 사용자가 승인한 포탑과 효과 방향을 Android Godot 전장에 연결했다. 기존 `magic` 포탑의 표시를 교체하며 전투 수치·피해 판정·저장 계약은 유지한다. 스테이지 11 이후와 비Android의 기존 2D 표시는 변경하지 않았다.

## 결과와 원본

- [Android 본게임 영상](android/runic-fire-main.mp4), [6문 연속 발사 검수 영상](android/runic-fire-android.mp4), [기기·APK 확인 기록](ANDROID.md)
- [Godot 근접 정면](godot-hero.png), [뒤쪽](godot-rear.png), [드론](godot-drone.png): 데스크톱 Mobile 렌더러 캡처, Android 화면과 구분한다.
- [기본 PBR 이관 원본](runic-native-export.blend), [효과 메시 원본](runic-flame-native-meshes.blend)
- [승인 Blender 원본](../runic-flame-turret.blend), [승인 효과 영상](../vfx/runic-flame-vfx.mp4)은 보존했다.
- [모델 제작·베이크·내보내기](export_native.py), [입체 불꽃 메시 내보내기](export_flame_meshes.py)

## 형상과 재질

승인 원본의 평가된 메시를 복사해 모따기와 가중 노멀을 적용했다. 같은 움직임을 갖는 부분을 부모별 세 메시로 병합했으며 재모델링·디시메이션은 하지 않았다. 원본 대비 위치 오차는 0.00000019 이하, GLB 재가져오기에서 실제 면에 쓰이는 정점 오차는 0.000000085 이하이고 삼각형 46,795개를 보존했다. UV 경계에서 정점이 분리되고 원본 CDT 계산의 미사용 정점이 빠지는 것은 외형 변화가 아니다. [형상 검사](geometry-check.json).

금속의 원래 색·거칠기·표면 노멀은 공유 1024² 텍스처 세 장에 구웠다. 색은 금속 반사율에 의해 어두워지는 Diffuse bake 대신 원래 Base Color를 Emission에 연결해 추출한다. Godot `StandardMaterial3D`가 PBR 텍스처와 금속성을 읽는다. 주황 룬은 기본 Unshaded 설정으로 강한 주광 반사에 희게 변하지 않게 했다. 조명·톤매핑 차이 때문에 Blender 렌더와 픽셀 단위로 같은 결과를 보장하지 않는다.

게임 자산은 `assets/images/stage1_3d/turrets/magic.glb`, `assets/images/stage1_3d/effects/runic_fire.glb`이며, 기존 PCK 준비 과정에서만 패키징한다. GLB의 중복 이미지는 기존 공용 텍스처 처리로 분리된다. 원형 편집은 승인 원본에서 하고, 두 export 스크립트는 별도 작업 사본에서 실행한다.

## 기본 엔진 효과

`godot/effects/runic_fire.gd`는 다음 기본 기능만 사용한다. 새 사용자 정의 셰이더나 빌보드 이미지 효과는 추가하지 않았다.

- 실제 입체 불꽃 메시와 정점 알파, 원주 UV
- `StandardMaterial3D`의 발광·알파·가산 혼합
- 공유 `NoiseTexture2D`·`FastNoiseLite`의 부드러운 알파 무늬와 UV 이동
- `GPUParticles3D`·`ParticleProcessMaterial`의 입체 화염 꼬리·불티·짧은 화구 입자

상부 불꽃과 화구는 원본 부착점을 따른다. 발사체 본체는 실제 전투 위치를 따르며, 발사 포즈로 방향을 연결하고 명중 후 본체를 숨긴다. 잔불 표시는 0.14초 보존한다. 효과 풀·메시·재질을 재사용하고, 개별 입자의 이동은 GPU가 처리한다. Blender 체적 재질을 그대로 실행한 것은 아니므로 볼륨의 부드러움과 경계 표현에는 차이가 있다.

전투 프레임의 시간만 사용하므로 정지·배속을 따른다. 입자 자동 시계를 끄고 `request_particles_process`로 실제 시간 차이만 전달한다. Godot 4.7에서 잔여 입자만 진행할 때는 방출 시간 0과 잔여 시간을 구분해 재방출을 막는다. 시간 역행·장면 초기화·풀 재사용 시 이전 불티와 발사 포즈를 제거한다.

## 검증

- 원본→병합→GLB 왕복의 형상 검사 통과.
- 화염 연결·총구·실제 탄환 위치·명중·연쇄·풀·정지·초기화 검사 통과.
- 기본 GPU 입자의 실제 Metal Mobile 화면에서 정지 중 이미지 동일, 외부 시간 진행 후 변화 확인.
- 기존 기관총·탄환 검사와 Flutter 관련 테스트 통과.
- Android 검수 범위·최종 APK·본게임 화면은 [Android 기록](ANDROID.md)에 기록한다. 에뮬레이터 결과로 실기기 지속 성능·발열을 보장하지 않는다.

## 2026-09-19 불꽃 메시 일괄 제출

포탑 상부·포구·발사체 각각의 5개 불꽃을 outer 3개/core 2개의 `MultiMeshInstance3D` 두 개로 묶었다. 원본 GLB·공유 기본 재질·2×5 변환 캐시·비균일 로컬 스케일·불꽃 수와 시간 수식·GPU 입자 및 풀 초기화는 보존했다. 변환 버퍼는 각 불꽃 그룹이 소유하고 메시·재질만 공유한다. CPU가 모든 인스턴스 변환을 전달하므로 엔진의 자동 AABB 갱신을 사용한다.

불꽃 표시 노드는 그룹당 5→2, 포탑당 상부+포구 10→4이다. 각 메시가 단일 surface인 경우 불꽃 메시 제출도 그룹당 5→2로 줄어드는 구조이며, 입자 제출·정점 수·픽셀 중첩·매 갱신의 5개 변환 업로드는 줄이지 않았다. 실제 GPU 시간 및 본게임 FPS 개선율은 미측정이다.

Mac Godot 4.7.2 Metal Mobile에서 실제 GLB를 사용해 원래 개별 Node3D 수식과 MultiMesh 변환 버퍼 동등성, 배속에 해당하는 시간 증가·정지·wrap·seek·비균일 크기·캐시 슬롯 교차·그룹 간 버퍼 독립성·부착점 방향·입자 잔류/만료·풀 재사용 검사를 통과했다. 기존 GPU 정지 픽셀/외부 시간 진행 검사도 통과했다. Headless Dummy는 MultiMesh 변환을 저장하지 않아 CPU 수학·상태만 검사하고 버퍼 검사는 SKIP으로 명시한다. 초기 로그의 `GPU buffer readback` 문구는 현재 `instance buffer`로 정정했다. GPU 실행 시간이나 GPU 메모리 직접 읽기 검사가 아니다.

입력 해시·엔진 조건·로그·데스크톱 불꽃 화면은 [검증 자료](multimesh-check/)에 보존했다. 데스크톱 화면은 주황 외곽·밝은 중심과 포구 방향을 확인한 중간 검수이며, Android 본게임 최종 외형 판정과 성능 측정을 대체하지 않는다.

통합 Android 본게임의 1×/4× 사격·고정/드론·종료/복귀 확인은 [선택 이관과 통합 검증](../../../stage1_3d/presentation_migration/selection_native/README.md)에 기록했다. 후속 [통합 FPS 재측정](../../../../docs/analysis/selection_multimesh_fps_20260919/README.md)에서 화염은 29.93 Flutter 갱신/초로 직전보다 4.9% 낮았다. 단회 과거 비교로 MultiMesh 단독 영향을 확정하지 않으며 GPU 시간은 미측정이다.

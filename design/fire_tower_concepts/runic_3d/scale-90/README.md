# 화염 포탑 전체 크기 90%

2026-09-22 사용자 요청으로 받침대 기준 전체 모델의 가로·세로·깊이를 기존 대비 90%로 축소했다. 형태·재질·골격·고정 아이콘 카메라는 유지한다.

- 현행 내보내기 원본: [runic-native-90.blend](runic-native-90.blend). 이전 승인·PBR 원본은 보존했다.
- 재현: Blender background에서 [resize.py](resize.py) 실행. 기존 PBR 원본에서 시작하며, 반복 실행해도 축소가 누적되지 않는다. 기존 전체 아이콘 render_icons.py도 변경된 GLB로 같은 결과를 만든다.
- 최종 에셋: `assets/images/stage1_3d/turrets/magic.glb`, `assets/images/ui/hud/turrets_3d/magic.png`. 다른 포탑 에셋은 변경하지 않았다.
- 상부·포구 부착 불꽃은 마커 배율을 따른다. 조준·반동·총구 위치도 모델 계층의 배율을 상속한다. 전투 수치·발사체 크기·분리 불티는 기존 계약을 유지한다.

검증: Blender 정점 23,576개에 대해 원위치×0.9와 비교해 최대 오차 1.34e-7 미만([geometry.json](geometry.json)). Godot 4.7.2 Metal Mobile에서 부착 메시 0.9 회귀 및 화염 통합 검사 통과([단위 로그](runic-fire-test.log), [통합 로그](runic-fire-integration.log)). 실제 전장 모델 배율 assert 및 정면·후면·드론 화면 확인([정면](godot-hero.png), [후면](godot-rear.png), [드론](godot-drone.png)).

기존 테스트 저장을 유지한 local-play 앱의 화염 모듈 화면에도 적용했다([실제 화면](user-live.png)). APK는 빌드하지 않았다.

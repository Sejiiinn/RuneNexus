# 시안과 실제 체적 재질 비교

`main.dart`는 실제 `Stage1Scene`을 로드하고 그 착탄 오브젝트를 승인된 Blender 검수 카메라에 놓는 개발용 진입점이다. 게임 재질을 별도로 복제하거나 이미지를 착탄 대신 그리지 않는다.

- 승인 원본: `../preview/impact-review.blend`의 `ImpactReview` 장면
- 시점: Blender (2.8, -7, 4.2) → 게임 (2.8, 4.2, 7), target 높이 0.72, orthographic 4.9
- 비교 크기: 게임 radius = 1 / 0.64, 원본과 동일한 세계 크기
- URL `?frame=8`과 `?frame=16`은 각각 progress 7/31과 15/31을 고정한다.
- 바닥과 조명은 간략화되어 있으며 비교 대상은 화염의 형태·주름·색이다. 이 화면은 실제 플레이 화면과 구분한다.
- `rejected-8.png`, `rejected-16.png`는 사용자가 거절한 이전 셰이더의 동일 시점 비교 기록이다.

검수 빌드:

```sh
scripts/in_app_server_macos.sh flutter build web --target=design/stage1_3d/cannon_impact/v2/comparison/main.dart --output=build/impact-comparison --pwa-strategy=none --no-tree-shake-icons
python3 scripts/no_cache_static_server.py --port 53012 --host 127.0.0.1 --directory build/impact-comparison
```

`capture.cjs`는 frame 8과 16의 Chrome GPU 화면을 캡처한다. 최종 플레이 영상은 `../runtime/`에서 따로 확인한다.

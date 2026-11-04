# 화상 효과 동일 APK 표시 A/B

Same APK, no recording, stage1 magic6, fixed tank3, 4x speed. Observed actual burning2. Sequential on/off/off/on, 6 windows each.

Existing compare_logs.read_records/summarize strict reconstruction. FPS pooled raw intervals; nearest-rank percentiles; CPU and Flutter end means sample-weighted; no invented pooled Flutter percentiles. Zero GPU timers treated unsupported.

| 구간 | 원시 간격 수 | FPS | 평균 ms | p95 ms | p99 ms | Render CPU ms | Flutter raster ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| stage1_burn_on_1 | 58 | 7.54 | 132.67 | 208.26 | 210.32 | 1.39 | 93.33 |
| stage1_burn_off_1 | 78 | 11.24 | 88.98 | 182.38 | 192.53 | 1.39 | 93.94 |
| stage1_burn_off_2 | 55 | 7.17 | 139.46 | 205.90 | 216.24 | 1.54 | 95.72 |
| stage1_burn_on_2 | 74 | 10.26 | 97.44 | 182.14 | 209.75 | 1.44 | 95.32 |
| pooled on | 132 | 8.86 | 112.92 | 197.37 | 209.75 | 1.42 | 94.24 |
| pooled off | 133 | 9.10 | 109.86 | 192.53 | 208.05 | 1.45 | 94.88 |

녹화 없이도 두 상태 모두 낮은 프레임률이다. 화상 표시를 끄는 것만으로 심한 끊김이 해소되지 않는다. 이 실행에서 on/off 평균 차이는 구간 간 변동보다 작아 화상의 독립 비용으로 확정할 수 없다. CPU render 값과 Flutter raster는 별도 계측 구간이므로 합산하거나 GPU 시간으로 읽으면 안 된다. GPU 타이머는 전 구간 0으로 미지원이며 비용 0을 뜻하지 않는다.

이 조건의 실제 화상 적은 2개다. 다수 화상 적에서 비용이 커지지 않는다는 결론으로 일반화할 수 없다. 완전히 동일한 결정론적 전투 재생이나 다회 무작위 교대가 아니므로 투사체/효과 시점, 시스템 부하, 시간 순서도 차이에 섞일 수 있다.

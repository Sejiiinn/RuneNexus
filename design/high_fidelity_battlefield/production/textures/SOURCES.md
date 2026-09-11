# 전장 시안 PBR 텍스처 출처

2026-09-10 Poly Haven 공식 API에서 확인 후 내려받은 2K JPG 12개. 총 27,305,809 bytes(약 26.0 MiB). 파일마다 API 제공 MD5와 실제 다운로드 해시의 일치를 검증했다. 모든 diffuse 이미지의 실제 형태·색상을 확인했다.

## 라이선스

- 원본: [Poly Haven](https://polyhaven.com/)
- 라이선스: [CC0 — 공식 설명](https://polyhaven.com/license)
- 공식 페이지는 에셋을 CC0로 제공하며 상업적 이용을 포함한 자유로운 이용을 허용한다고 명시한다. 아래 저작자 표시는 출처 추적을 위한 기록이다.
- API 원본 정보: `asset_metadata.json`; 다운로드 URL·MD5·크기: `download_manifest.json`.

## 선택 에셋

| 에셋 / 공식 페이지 | 저작자 | 원본 반복 면적 | 시안 용도 |
| --- | --- | --- | --- |
| [Monastery Stone Floor](https://polyhaven.com/a/monastery_stone_floor) | Amal Kumar | 약 1.8 × 1.8m (API dimensions 1800 × 1800) | 큰 불규칙 석판의 어두운 갈회색 바닥. 주요 건설 타일 표면·외곽 폐허 바닥 |
| [Cobblestone Floor 08](https://polyhaven.com/a/cobblestone_floor_08) | Rob Tuytel | 2 × 2m | 밝은 회색·올리브 작은 포장석. 길과 외곽 포장, 따뜻한 흙과 혼합 |
| [Castle Wall Slates](https://polyhaven.com/a/castle_wall_slates) | Rob Tuytel | 2.5 × 2.5m | 회색·올리브 돌과 밝은 줄눈. 낮은 외벽·폐허 기단 |

## Blender 적용 기준

각 에셋은 `{id}_diff_2k.jpg`, `{id}_nor_gl_2k.jpg`, `{id}_rough_2k.jpg`, `{id}_disp_2k.jpg` 구성이다.

- Diffuse는 sRGB, 나머지는 Non-Color. Normal GL은 Normal Map 노드에 연결한다.
- 물리 단위 1 Blender unit = 1m 기준으로 UV 반복 1회를 위 면적에 맞춘다. Object 좌표의 Mapping scale은 각각 대략 0.556 / 0.5 / 0.4 per meter. 평면의 UV가 전체 한 번이면 물체 길이 ÷ 원본 반복 길이를 UV scale로 사용한다.
- 위 값은 출발점이며 카메라 거리와 타일 크기에 맞춰 조절할 수 있다. 바닥에 개별 석판 모델을 추가하는 경우 diffuse의 줄눈이 과도하게 중복되지 않도록 반복 크기를 크게 잡거나 모델 표면을 crop한다.
- Normal strength 0.35–0.65부터 시작. Displacement는 우선 Bump로 0.01–0.03m 정도만 사용하고 외곽 실루엣은 모델링으로 만든다.
- 젖은 부분의 roughness만 별도 마스크로 낮추고 전체 면을 금속처럼 만들지 않는다. 벽면은 상대적으로 건조하게 유지한다.
- 주황 대포와 경쟁하지 않도록 monastery diffuse의 붉은 기운은 shader에서 약하게 줄일 수 있다. 다운로드 원본은 그대로 보관한다.

## 확보 경로

- 목록: `https://api.polyhaven.com/assets?t=textures`
- 파일: `https://api.polyhaven.com/files/{id}`
- 메타데이터: `https://api.polyhaven.com/info/{id}`
- 기본 urllib 요청은 403을 반환했으나 명시적 User-Agent `RuneNexus-art-preview/1.0`으로 정상 조회·다운로드했다.

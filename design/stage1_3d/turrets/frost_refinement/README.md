# 냉각 포탑 실제 3D 개선

2026-09-10. 기존 2D의 둥근 알/주변 구슬 형태 대신 비대칭 길쭉한 빙결 결정 네 개와 낮은 어두운 강철·석재 받침을 제작했다.

- 최종: `assets/images/stage1_3d/turrets/frost.glb`
- 원본: `frost.blend`, 재현: `build_frost.py`
- QA: `frost-steep-qa.png` — 요청한 (5,-13,27) steep 카메라의 Blender 제작 렌더이며 앱 캡처는 아니다.
- +Y up / +Z front / 바닥 Y=0 / 받침 최대 폭 .78 / 높이 .96.
- 계층: `turret_root > turret_head > turret_barrel > muzzle`. muzzle 로컬 위치 (0,.85,.12).
- opaque 표준 glTF PBR만 사용하며 transparency/transmission/refraction/필수 extension 없음.
- 얼음 basecolor·normal·roughness 512² bake 3장, 기존 환경 돌재질의 동일한 512² 세 장을 재사용하여 GLB에 내장.
- 결정마다 비대칭 크기·기울기, 면별 명암, 드문 불규칙 균열·흰 서리 ridge와 낮은 청록 냉각 seal 사용. 순백 발광 덩어리나 금색 장식 없음.
- GLB 1,628,284 bytes / mesh 17개 / triangles 1,788 / 이미지 6장.

GLB 노드 계층·축·내장 텍스처·extension 부재를 확인했고 steep 각도 QA에서 결정 네 개의 실루엣, 받침, 서리·균열 식별성을 확인했다. 첫 QA의 과밀한 균열을 한 번 줄여 최종 렌더를 확인했다. 실제 앱 조명·회전·효과는 통합 검증 대상이다.

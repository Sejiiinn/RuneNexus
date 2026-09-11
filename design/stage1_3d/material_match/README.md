# 원본 재질·면광원 실제 웹 검수

2026-09-11. `reference.jpg`는 사용자가 재첨부한 Blender 시안이다. 최신 실제 앱 화면은 `final-large.png` / `final-phone.png`(배치 전), `final-combat-large.png` / `final-combat-phone.png`(포탑·적 포함)다. Mac 잠금 상태에서 임시 Chrome 프로필로 헤드리스 실행·캡처했다. 이미지 합성이나 Blender 렌더가 아니다.

## 수정한 원인

- 원본의 UV 비정수 스케일·Geometry.Position·Object 좌표 이끼 변화가 단위 평면 베이크에서 소실됐다. 원래 위치의 길26칸·건설32칸을 스테이지 전용 2048² atlas로 평가해 칸별 석재 샘플과 색 변화를 보존했다.
- PMREM에 광원 패널을 넣는 방식은 위치별 반사를 재현하지 못했다. 원본 위치·크기의 RectAreaLight 세 개를 사용하고, 기존 렌더러에 공식 LTC 조회표를 공급했다. PMREM은 낮은 하늘 반사에만 사용한다.
- Mesh.clone은 재질 콜백을 복사하지 않았다. 실제 인스턴스 생성 시 AgX 대비 처리와 면광원 view×world 방향 보정을 설치한다. 최종 GPU shaderSource에서 모든 PBR 프래그먼트에 대비 코드와 LTC 경로가 들어갔음을 확인했다.

원본 환경의 7메시·장식·맵 메타데이터 조건은 유지한다. 실제 화면에서 서로 다른 석재·이끼 패턴, 상단의 어두운 면과 하단의 밝은 반사, 지형 모서리 음영을 확인했다. 포탑 설치·적 이동·대포 발사·처치 골드·기존 HUD도 확인했다. `final-combat-large.png`는 기본 전장 맞춤 상태이며 별도의 확대 크롭을 하지 않았다.

정적 분석, 관련 Flutter 테스트4개, 웹 빌드, diff 검사 통과. 실제 복제 재질의 콜백 유지도 테스트에 포함한다. 두 크기와 전투 실행의 HTTP/JS 오류 없음. 플랫폼 뷰 기본 크기 경고는 남았다. Blender의 면광원 그림자와 웹의 주광 그림자는 계산 방식이 다르며 픽셀 동일 결과를 의미하지 않는다. 네이티브 실기기 성능은 미검증이고 배포하지 않았다.

`verify_web.cjs`는 배치 전 화면, `verify_final_combat.cjs`는 실제 전투 검수다. `gpu-report.json`은 최종 GPU 확인이다. `before-*`, `lighting-*`, `refined-*`, `authored-*`, `area-*`, `combat/`은 이전 비교 자료로 최신 결과가 아니다. 재질 제작은 `../environment/README.md`, 면광원 자료와 라이선스는 `../lighting/README.md`를 참조한다.

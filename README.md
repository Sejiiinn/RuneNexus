# Rune Nexus

Rune Nexus는 Flutter + Flame 기반 모바일 로그라이트 타워 디펜스입니다.

플레이어는 Nexus로 향하는 적의 경로를 읽고, 제한된 골드로 포탑을 설치하며, 라운드마다 얻는 젬을 포탑 링크에 연결해 빌드를 완성합니다. 같은 포탑이라도 어떤 젬을 연결하느냐에 따라 단일 화력, 범위 피해, 지속피해, 연쇄 타격처럼 전투 역할이 달라지는 것이 핵심입니다.

## 게임 컨셉

- 한 손 세로 화면에서 빠르게 읽히는 타워 디펜스
- 라운드 단위 전투와 젬 선택을 반복하는 로그라이트 구조
- 포탑 구매, 레벨업, 링크 확장 사이의 골드 사용 선택
- 실패해도 룬을 얻고 다음 런을 강화하는 영구 성장
- 스테이지 해금과 장기 생존을 통해 다음 목표를 만드는 진행 구조

## 핵심 루프

1. 스테이지를 선택한다.
2. 경로와 다음 적 구성을 보고 포탑을 배치한다.
3. 라운드를 시작해 자동 전투를 진행한다.
4. 보상 젬을 골라 포탑 링크에 장착한다.
5. 포탑 구매, 레벨업, 링크 확장으로 빌드를 조정한다.
6. 실패 또는 클리어 후 룬을 정산하고 영구 업그레이드를 선택한다.

## 설계 방향

- 작은 화면에서도 전투 정보가 먼저 읽히도록 한다.
- 젬은 단순 수치 보너스보다 포탑 역할을 바꾸는 선택지가 되어야 한다.
- 전투 중 조작은 포탑 설치와 성장 중심으로 유지하고, 젬 관리는 준비 단계에 집중한다.
- 밸런스 수치는 실험 가능해야 하며, 현재 기준은 별도 문서로 관리한다.
- README는 게임 소개와 진입점만 담고, 구현 이력과 세부 수치는 문서로 분리한다.

## 실행

```bash
flutter pub get
flutter run
```

웹 데모 빌드:

```bash
flutter build web --pwa-strategy=none --no-tree-shake-icons
```

로컬 정적 서버 예시:

```bash
python -m http.server 54546 --bind 127.0.0.1 -d build/web
```

Flutter Web은 서비스 워커 캐시 때문에 변경 사항이 바로 보이지 않을 수 있습니다. 개발 중에는 `--pwa-strategy=none` 빌드를 사용하거나 브라우저 캐시/서비스 워커를 갱신해야 합니다. 젬처럼 데이터에서 동적으로 꺼내 쓰는 아이콘이 있으므로 웹 빌드에서는 `--no-tree-shake-icons`를 함께 사용합니다.

## 검증

```bash
flutter analyze
flutter test
flutter build web --pwa-strategy=none --no-tree-shake-icons
```

## 문서

- [구현 현황](docs/implementation_status.md)
- [게임 규칙과 밸런스 기준](docs/gameplay_balance_reference.md)
- [개발 히스토리](docs/development_history.md)
- [데모 앱 작업 계획서](docs/demo_mvp_work_plan.md)
- [다음 작업 우선순위](docs/next_work_priorities.md)

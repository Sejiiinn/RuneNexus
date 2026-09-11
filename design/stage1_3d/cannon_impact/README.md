# 초기 대포 충돌 3D VFX 제작 기록

현재 게임의 착탄은 [field_cache/bake_field.py](field_cache/bake_field.py)로 만든 시간별 3D 밀도·발광·열도 캐시와 런타임 입체 파편·불티를 사용한다. 최신 파편탄+부분 화염은 대응하는 Blender 원본이 없으며, [캐시 제작 기준](field_cache/README.md)과 [실제 화면 검수](shell_runtime/README.md)를 따른다. 전체 상태와 원본 연결은 [Blender 작업 허브](../blender_workspace/README.md)에서 확인한다.

아래는 게임에서 사용하지 않는 최초 12프레임 버전의 제작 기록이다. 이 폴더의 `cannon_impact.blend`와 [v2 화염구](v2/README.md)는 이전안으로 보존한다.

## 최초 12프레임 제작 기록

Blender Cycles의 입체 볼륨 화염과 메시 파편으로 만든 단발 이펙트입니다. 기존 2D 폭발 이미지를 재사용하지 않습니다. 구형 연기 덩어리 대신 초반 섬광, 비대칭으로 겹친 7개의 짧은 화염, 지면 먼지 능선, 빠르게 사라지는 미세 불티를 사용합니다.

- 두 PNG: 각각 1024×768 RGBA, 256×256 프레임 12개, 4열×3행.
- 0.45초 단발. 마지막 프레임 11은 완전히 투명합니다.
- 본체 pivot `(0.5, 0.18)`, 지면 정사영 pivot `(0.5, 0.5)`.
- 연기와 지면 먼지는 frame 8부터 제거되어 약 0.3초 이후 남지 않습니다.
- `cannon_impact.blend`: 편집 가능한 3D 원본, `CannonImpact3D`와 `CannonGround3D` scene.
- `build_impact.py`: 최종 형상·볼륨 셰이더·애니메이션을 재현하는 통합 제작 스크립트. 빈 Blender 파일에서 실행합니다.
- `render_frames.py`: 활성 scene을 전환하고 12개 프레임을 렌더합니다.
- `pack_frames.py`: PNG 원본을 변경하지 않고 OpenRaster 레이어 좌표를 구성합니다. GIMP MCP로 ORA를 열어 최종 PNG와 편집용 XCF를 내보냅니다.

당시 이 PNG는 투명한 입자·화염 표현용으로 제작했고, 광원 반응은 별도 런타임 PointLight가 담당하도록 구성했습니다. 현재 게임은 이 PNG를 로드하지 않습니다.

검증: 두 시트의 12개 셀 알파가 렌더 PNG와 일치합니다. 프레임 11은 알파 0이며 모든 내용이 셀 안에 들어갑니다. `body-preview-80-composited.png`와 `body-preview-32.png`로 게임 크기의 단계 변화·여백을 확인했습니다. 자세한 알파 경계는 `frame_qa.json`에 기록했습니다.

# 공용 전장 반사

`battlefield_reflection_sky.tres`: 코어·석재·금속이 공유하는 128px 하늘 반사. 내장 GradientTexture2D의 선형 HDR 밝기 띠를 PanoramaSkyMaterial에 연결한다. 이미지 파일이나 외부 의존성을 추가하지 않는다. 색 배경과 확산 환경광은 main.gd에서 별도로 유지한다.

코어는 GLB `core_crystal_facets`의 원본 StandardMaterial3D를 한 번 복제해 공유한다. 원본 RGB·정점색·노멀·PBR·발광을 유지하고 굴절/투명 혼합만 끈다. 따라서 원본 속성을 이 프리셋에 이중으로 적지 않는다. IOR·Transmission을 alpha/refraction으로 변환하지 않는다.

[화면·제약·Android 확인](../../design/stage1_3d/native_material_workflow/verification/native-reflection-20260913/README.md). 현재 표현은 반사광이 있는 불투명 결정이며 Cycles 내부 다중 굴절은 제공하지 않는다.

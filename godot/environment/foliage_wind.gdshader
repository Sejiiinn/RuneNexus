shader_type spatial;
render_mode cull_disabled;

uniform ivec2 occupied_build_tiles = ivec2(0);

void vertex() {
	// UV2: 건설칸 슬롯, 설치 시 제거할 중앙 군락 여부.
	int slot = int(UV2.x + 0.5);
	int occupied = slot < 16 ? occupied_build_tiles.x : occupied_build_tiles.y;
	if (UV2.y > 0.5 && (occupied & (1 << (slot & 15))) != 0) {
		// 군락 전체를 한 점으로 축소: 투명 패스·개체별 CPU 갱신 없음.
		VERTEX = vec3(0.0, -1.0, 0.0);
	} else {
		// UV: 뿌리 0~끝 1의 굽힘 가중치, 군락별 고정 위상.
		float weight = clamp(UV.x, 0.0, 1.0);
		float phase = UV.y;
		float breeze = sin(TIME * 0.95 + phase) * 0.72
			+ sin(TIME * 1.71 + phase * 1.37) * 0.28;
		VERTEX.xz += vec2(0.92, 0.39) * (0.022 * breeze * weight * weight);
	}
}

void fragment() {
	// 불투명 입체 잎의 양면 조명. 선형 정점색 유지, 투명 패스 없음.
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
}

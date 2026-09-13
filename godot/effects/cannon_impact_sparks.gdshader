shader_type spatial;
render_mode unshaded;
#define IMPACT_SPARK
#include "cannon_impact_motion.gdshaderinc"

void fragment() {
	ALBEDO = vec3(6.0, 1.45, 0.14);
}

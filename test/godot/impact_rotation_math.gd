extends SceneTree

## 이전 CPU seed fixture와 Godot의 Basis/Quaternion을 독립 기준으로 삼는다.
## 아래 analytic 식은 GPU float32 입력·중간값을 모사한다. GPU readback/시각 검증은 아니다.
## 23개 방향 × 90개 입자의 5ms 시간격자와 spawn/death/착지/apex 경계를 검사한다.
## 실행: Godot --headless --path <project> --script <이 파일의 절대경로> -- <fixture 절대경로>
## fixture: test/fixtures/godot/impact_seed_1404.json
## 실제 shader: godot/effects/cannon_impact_motion.gdshaderinc
## Godot 4.7 Mobile 원본 normal 경로는 instance scale→rotation이며 역전치 교정이 아니다.
var max_spark_error := 0.0
var max_fragment_error := 0.0
var max_normal_error := 0.0
var max_spark_vertex_error := 0.0
var min_pole := 2.0
var comparisons := 0
var largest_case := {}

func f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

func align_back(v: Vector3, d: Vector3) -> Vector3:
	var q := Vector3(-d.y, d.x, 0.0)
	var w: float = f32(1.0 + d.z)
	return v + f32(2.0/f32(q.dot(q)+f32(w*w))) * q.cross(q.cross(v)+w*v)

func euler_xyz(a: Vector3) -> Basis:
	var c := Vector3(cos(a.x),cos(a.y),cos(a.z))
	var s := Vector3(sin(a.x),sin(a.y),sin(a.z))
	return Basis(Vector3(c.y*c.z,c.z*s.x*s.y+c.x*s.z,-c.x*c.z*s.y+s.x*s.z),
		Vector3(-c.y*s.z,c.x*c.z-s.x*s.y*s.z,c.z*s.x+c.x*s.y*s.z),
		Vector3(s.y,-c.y*s.x,c.x*c.y))

func _initialize() -> void:
	var parameters: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	for impact_id in range(23):
		var angle: float = float(impact_id)*0.317
		for index in range(90):
			var p: Dictionary = parameters[index]
			var spark: bool = index<56
			var drag: float = 1.8 if spark else 0.75
			var gravity: float = 4.8 if spark else 5.4
			var ages: Array[float] = []
			for step in range(221):
				ages.append(float(step)*0.005)
			var floor_time: float = (p.rise+sqrt(p.rise*p.rise+4.0*gravity*(0.055-0.014)))/(2.0*gravity)
			for event in [float(p.delay), float(p.delay)+float(p.death), float(p.delay)+floor_time, float(p.delay)+float(p.rise)/(2.0*gravity)]:
				for offset in [-0.00001,0.0,0.00001]:
					ages.append(event+offset)
			for age in ages:
				var t: float = maxf(0.0,age-float(p.delay))
				var height: float = 0.055+float(p.rise)*t-gravity*t*t
				if age<float(p.delay) or t>float(p.death) or height<0.014:
					continue
				comparisons+=1
				var old_basis: Basis
				var new_basis: Basis
				var gt: float = f32(maxf(0.0,f32(age)-f32(p.delay)))
				if spark:
					var heading: float = float(p.angle)+angle
					var direction := Vector3(cos(heading)*float(p.speed)*exp(-drag*t),float(p.rise)-2.0*gravity*t,sin(heading)*float(p.speed)*exp(-drag*t)).normalized()
					var gheading: float = f32(f32(p.angle)+f32(angle))
					var decay: float = f32(exp(f32(-f32(drag)*gt)))
					var gvx: float = f32(f32(cos(gheading))*f32(p.speed))
					var gvz: float = f32(f32(sin(gheading))*f32(p.speed))
					var gdirection := Vector3(f32(gvx*decay),f32(f32(p.rise)-f32(f32(2.0*f32(gravity))*gt)),f32(gvz*decay)).normalized()
					min_pole=minf(min_pole,1.0+gdirection.z)
					old_basis=Basis(Quaternion(Vector3.BACK,direction))
					new_basis=Basis(align_back(Vector3.RIGHT,gdirection),align_back(Vector3.UP,gdirection),align_back(Vector3.BACK,gdirection))
				else:
					old_basis=Basis.from_euler(Vector3(t*float(p.spin)+float(index),t*float(p.spin)*0.73,t*float(p.spin)*1.31),EULER_ORDER_XYZ)
					var phase: float = f32(gt*f32(p.spin))
					new_basis=euler_xyz(Vector3(f32(phase+float(index)),f32(phase*f32(0.73)),f32(phase*f32(1.31))))
				var error: float = maxf(old_basis.x.distance_to(new_basis.x),maxf(old_basis.y.distance_to(new_basis.y),old_basis.z.distance_to(new_basis.z)))
				if spark:
					if error>max_spark_error:
						largest_case={"index":index,"impact_id":impact_id,"age":age}
					max_spark_error=maxf(max_spark_error,error)
					var length: float = float(p.length)*(1.0-t/float(p.death))
					for vertex in [Vector3(float(p.width),0,0),Vector3(0,float(p.width),0),Vector3(0,0,length*0.5)]:
						max_spark_vertex_error=maxf(max_spark_vertex_error,(old_basis*vertex).distance_to(new_basis*vertex))
				else:
					max_fragment_error=maxf(max_fragment_error,error)
					var normal := Vector3(0.3,0.8,0.5).normalized()
					var scale := Vector3(float(p.width),float(p.width)*float(p.stretch),float(p.width))
					max_normal_error=maxf(max_normal_error,(old_basis*(normal*scale)).normalized().distance_to((new_basis*(normal*scale)).normalized()))
	print(JSON.stringify({"comparisons":comparisons,"directions":23,"age_step_seconds":0.005,"event_samples_per_particle":12,"max_spark_basis_error":max_spark_error,"max_spark_vertex_rotation_error_radius1":max_spark_vertex_error,"max_fragment_basis_error":max_fragment_error,"max_fragment_normal_error":max_normal_error,"min_one_plus_direction_z":min_pole,"worst_spark_case":largest_case}))
	# Near -Z the rotation axis is sensitive to float32 heading quantization;
	# also bound the resulting displacement of the actual spark mesh vertices.
	quit(0 if max_spark_error<0.0002 and max_fragment_error<0.00002 and max_normal_error<0.00002 and max_spark_vertex_error<0.00001 and min_pole>0.00000025 else 1)

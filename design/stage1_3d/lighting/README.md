# 스테이지 1 면광원 자료

원본은 `../actor_refinement/stage1-actors-refined.blend`의 soft neutral sky / warm indirect sky / front fill이다. 위치·면 크기 0.5배, 출력0.25배를 적용하고 면적×π로 나눈 방사 휘도를 RectAreaLight에 전달한다. 낮은 하늘 반사는 원본 World 색×Strength다.

`RectAreaLightTexturesLib.js`는 three.js r170의 공식 LTC 데이터 원본이며 `THREE-LICENSE.txt`의 MIT 라이선스를 따른다. https://github.com/mrdoob/three.js/blob/r170/examples/jsm/lights/RectAreaLightTexturesLib.js

LTC_MAT_1/2를 64×64 RGBA의 little-endian float32 및 float16으로 직렬화한 `assets/images/stage1_3d/environment/ltc_*.bin` 네 장을 기존 three_js 면광원 셰이더에 공급한다. 원천 연구는 Eric Heitz 등의 Linearly Transformed Cosines이며 원본 JS에 출처가 포함돼 있다. 새 렌더러 패키지는 추가하지 않는다.

three_js_angle_renderer 0.0.1의 면 방향 행렬 순서를 view×world로 보정한다. 재질 onBeforeRender에서 기존 light state의 halfWidth/halfHeight만 갱신하여 설치 패키지는 수정하지 않는다. 면광원 자체 그림자는 미지원이므로 기존 주광 그림자를 유지한다.

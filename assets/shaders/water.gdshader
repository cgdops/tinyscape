shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float wave = sin(world_position.x * 2.8 + world_position.z * 1.7 + TIME * 0.55);
	float cross_wave = sin(world_position.z * 5.2 - world_position.x * 0.8 - TIME * 0.35);
	float glint = smoothstep(0.93, 1.0, wave * cross_wave);
	ALBEDO = mix(vec3(0.24, 0.49, 0.48), vec3(0.36, 0.64, 0.63), wave * 0.12 + 0.60);
	ALBEDO += vec3(0.12, 0.16, 0.12) * glint * 0.28;
	ROUGHNESS = 0.38;
	SPECULAR = 0.30;
}

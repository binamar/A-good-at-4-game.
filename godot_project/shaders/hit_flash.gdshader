shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(0.2, 0.35, 0.6, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	ALBEDO = mix(albedo_color.rgb, vec3(1.0, 0.32, 0.25), flash_amount);
	ROUGHNESS = roughness_val;
	METALLIC = 0.1;
}

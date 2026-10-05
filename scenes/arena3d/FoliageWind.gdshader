shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 leaf_tint : source_color = vec4(.7,.84,.59,1.0);
uniform float wind_time = 0.0;
varying vec3 world_point;
void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    float weight = smoothstep(.28,1.6,p.y);
    float breeze = sin(wind_time*1.15 + p.x*.45 + p.z*.3);
    float flutter = sin(wind_time*2.7 + p.x*2.4 + p.z*1.7);
    vec3 offset = vec3((breeze*.20+flutter*.045)*weight,flutter*.035*weight,breeze*.09*weight);
    VERTEX += (inverse(MODEL_MATRIX)*vec4(offset,0.0)).xyz;
    world_point = p;
}
void fragment() {
    vec4 leaf = texture(leaf_texture,UV);
    ALBEDO = leaf.rgb * leaf_tint.rgb;
    ALPHA = leaf.a;
    ALPHA_SCISSOR_THRESHOLD = .42;
    ROUGHNESS = .77;
    BACKLIGHT = leaf.rgb*.18;
}

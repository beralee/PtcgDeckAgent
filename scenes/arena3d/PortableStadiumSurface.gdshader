shader_type spatial;
render_mode unshaded;
uniform vec4 fabric_tint : source_color = vec4(0.14,0.29,0.22,1.0);
uniform sampler2D fabric : source_color, filter_linear_mipmap;
uniform sampler2D previous_art : source_color, filter_linear;
uniform sampler2D current_art : source_color, filter_linear;
uniform float previous_present = 0.0;
uniform float current_present = 0.0;
uniform float transition = 1.0;
uniform vec2 table_size = vec2(21.24,17.76);
varying vec3 table_point;
void vertex() { table_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p = table_point.xz/table_size + vec2(0.5);
    float edge = min(min(p.x,1.0-p.x),min(p.y,1.0-p.y));
    float inset = smoothstep(0.0,0.055,edge);
    // The portable felt texture is already dark green. Multiplying a second
    // dark tint crushed it to black on unshaded Android/WebGL materials.
    float weave = dot(texture(fabric,UV).rgb, vec3(0.3,0.5,0.2));
    float clearing = 1.0 - smoothstep(0.06,0.58,length((p-0.5)*vec2(1.0,0.8)));
    float sun = 1.0-smoothstep(0.03,0.16,abs(p.x+p.y*0.42-0.66));
    vec3 cloth = mix(fabric_tint.rgb*0.72,vec3(0.12,0.34,0.19),clearing);
    cloth *= 0.88+0.26*weave;
    cloth += vec3(0.13,0.14,0.055)*sun*inset;
    vec3 old_color = mix(cloth,texture(previous_art,clamp(p,vec2(0.0),vec2(1.0))).rgb,previous_present*inset*0.82);
    vec3 new_color = mix(cloth,texture(current_art,clamp(p,vec2(0.0),vec2(1.0))).rgb,current_present*inset*0.82);
    ALBEDO = mix(old_color,new_color,transition);
}

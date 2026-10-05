shader_type spatial;
uniform sampler2D fabric : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 fabric_tint : source_color;
uniform sampler2D previous_art : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D current_art : source_color, filter_linear_mipmap_anisotropic;
uniform float previous_present = 0.0;
uniform float current_present = 0.0;
uniform float transition = 1.0;
uniform vec2 table_size = vec2(38.0,17.76);
uniform float atmosphere_time = 0.0;
uniform vec3 lamp_a;
uniform vec3 lamp_b;
uniform vec4 lamp_tint : source_color = vec4(0.35,0.65,1.0,1.0);
varying vec3 table_point;
void vertex() {
    table_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
    vec2 art_uv = table_point.xz / table_size + vec2(0.5);
    float edge = min(min(art_uv.x,1.0-art_uv.x),min(art_uv.y,1.0-art_uv.y));
    float inset = smoothstep(0.0,0.055,edge);
    vec3 base = texture(fabric,UV).rgb * fabric_tint.rgb;
    vec3 old_color = texture(previous_art,clamp(art_uv,vec2(0.0),vec2(1.0))).rgb;
    vec3 new_color = texture(current_art,clamp(art_uv,vec2(0.0),vec2(1.0))).rgb;
    float active = mix(previous_present,current_present,transition);
    vec3 art = mix(old_color*previous_present,new_color*current_present,transition);
    float weight = inset * active * 0.94;
    vec3 surface = mix(base,art/max(active,0.001),weight);
    vec2 da = table_point.xz-lamp_a.xz;
    vec2 db = table_point.xz-lamp_b.xz;
    float wash = exp(-dot(da,da)/23.0)+exp(-dot(db,db)/23.0);
    // Moving illumination is composed in the same material as the original art.
    // Darken the base projection so the passing light has visible headroom.
    ALBEDO = surface * mix(1.0,0.62,weight);
    vec3 lit = surface * wash * lamp_tint.rgb;
    ROUGHNESS = mix(0.72,0.56,weight);
    METALLIC = weight*0.10;
    // The image is in the physical felt surface; real cards and props still cast shadows.
    EMISSION = art*inset*0.08 + lit*0.80*inset;
}

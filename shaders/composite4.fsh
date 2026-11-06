#version 330 compatibility
// Tonemap (ACES) e saturação. A imagem sai pronta para a tela (sRGB) em colortex0,
// e o final.fsh só faz o FXAA ou o afiador do TAA.
#include "/lib/settings.glsl"
uniform sampler2D colortex0;
in vec2 texcoord;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

vec3 aces(vec3 x) {
    const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    vec3 c = texture(colortex0, texcoord).rgb * EXPOSURE;
    // o ACES deixa as cores mais vivas; a saturação compensa (1.0 = sem mudança)
    float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = max(mix(vec3(luma), c, SATURATION), 0.0);
    c = aces(c);
    outColor = vec4(pow(c, vec3(1.0 / 2.2)), 1.0);
}

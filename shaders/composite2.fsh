#version 330 compatibility
// Bloom, passada vertical + soma na imagem. Dentro/atrás da água o brilho
// se espalha mais forte, como o azul de Cherenkov em piscinas de reator.
#include "/lib/common.glsl"
#include "/lib/blur.glsl"
uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
in vec2 texcoord;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;
void main() {
    vec3 color = texture(colortex0, texcoord).rgb;
    vec3 bloom = blur1D(colortex5, texcoord, vec2(0.0, 1.0 / viewHeight));
    float inWater = max(float(isEyeInWater == 1), step(0.5, texture(colortex4, texcoord).a));
    float boost = mix(1.0, CHERENKOV_WATER_BOOST, inWater);
    outColor = vec4(color + bloom * BLOOM_STRENGTH * boost, 1.0);
}

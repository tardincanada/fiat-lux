#version 330 compatibility
// Bloom, passada horizontal (só a luz própria: emissivos + Cherenkov)
#include "/lib/common.glsl"
#include "/lib/blur.glsl"
uniform sampler2D colortex3;
in vec2 texcoord;
/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 outBloom;
void main() {
    outBloom = vec4(blur1D(colortex3, texcoord, vec2(1.0 / viewWidth, 0.0)), 1.0);
}

#version 330 compatibility
#include "/lib/common.glsl"
uniform sampler2D gtexture;
in vec2 texcoord;
in vec4 glcolor;
flat in int isWater;
flat in int isSlime;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 shadowColor;
void main() {
    if (isWater == 1) discard;               // água não faz sombra no fundo
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < 0.1) discard;
    #ifdef SLIME_TRANSLUCENT
    // membrana do slime (textura semitransparente): sombra fraca e esverdeada, só o miolo é escuro
    if (isSlime == 1 && c.a < 0.99) {
        if (ditherNoise(gl_FragCoord.xy) >= SLIME_OPACITY) discard;
    }
    #endif
    shadowColor = vec4(mix(vec3(1.0), c.rgb, c.a), 1.0); // cor da sombra através de vidro colorido
}

// Coisas que brilham sem iluminação e desenham ANTES do deferred
// (olhos de aranha, brilho de encantamento, feixe do sinalizador).
// Vão para colortex3, que o deferred soma como luz própria.
#include "/lib/common.glsl"

#ifdef VSH
out vec2 texcoord;
out vec4 glcolor;
void main() {
    gl_Position = taaJitter((gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex)));
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
}
#endif

#ifdef FSH
uniform sampler2D gtexture;
in vec2 texcoord;
in vec4 glcolor;
/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outEmissive;
void main() {
    #ifdef PROGRAM_BASIC
    vec4 c = glcolor;
    // halos de Cherenkov que o mod desenha (cor 70,140,255): o shader já faz o brilho,
    // proporcional e sem o disco na superfície da água, então eles são descartados
    if (all(lessThan(abs(c.rgb - vec3(70.0, 140.0, 255.0) / 255.0), vec3(0.03)))) discard;
    #else
    vec4 c = texture(gtexture, texcoord) * glcolor;
    #endif
    if (c.a < 0.01) discard;
    outEmissive = vec4(toLinear(c.rgb) * 1.5, c.a);
}
#endif

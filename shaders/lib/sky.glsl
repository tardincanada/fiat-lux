#include "/lib/biome_sky.glsl"
uniform int renderStage;

#ifdef VSH
out vec4 glcolor;
out vec2 texcoord;
out vec3 viewPos;
void main() {
    gl_Position = taaJitter((gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex)));
    glcolor = gl_Color;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
}
#endif

#ifdef FSH
uniform sampler2D gtexture;
in vec4 glcolor;
in vec2 texcoord;
in vec3 viewPos;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;
void main() {
    #ifdef SKY_TEXTURED
    vec4 c = texture(gtexture, texcoord) * glcolor;   // sol e lua
    // sol e lua somem atrás das nuvens
    float cloudA = getClouds(viewPos).a;
    // e somem por completo na chuva, neve e tempestade (céu encoberto), exceto acima das nuvens
    float rainHide = clamp(rainStrength * (1.0 - aboveClouds()), 0.0, 1.0);
    outColor = vec4(toLinear(c.rgb) * 2.0, c.a * (1.0 - cloudA * 0.97) * (1.0 - rainHide));
    #else
    if (renderStage == MC_RENDER_STAGE_STARS) {
        float cloudA = getClouds(viewPos).a;
        // estrelas só depois do pôr do sol: começam no fim do crepúsculo civil (sol a -6°)
        // e ficam todas visíveis no náutico (-12°). A vanilla já as mostrava com o sol a ~22°.
        float starVis = 1.0 - smoothstep(-0.20, -0.07, sunHeight());
        outColor = vec4(toLinear(glcolor.rgb) * 1.5, glcolor.a * (1.0 - cloudA) * (1.0 - overcastAmount()) * starVis);
    } else {
        outColor = vec4(getBiomeSky(viewPos), 1.0);
    }
    #endif
}
#endif

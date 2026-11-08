#version 330 compatibility
// Ilumina tudo que é opaco: sol/lua + sombras, luz ambiente do céu, luz de tochas.
#include "/lib/lighting.glsl"

/*
const int colortex0Format = RGBA16F;  // cor (HDR, linear)
const int colortex1Format = RGBA16;   // normal
const int colortex2Format = RGBA8;    // lightmap.xy, material
const int colortex3Format = RGBA16F;  // luz própria (emissivos, Cherenkov)
const int colortex4Format = RGBA16;   // dados da água (normal, luz do céu, máscara)
const int colortex5Format = RGBA16F;  // bloom
const int colortex8Format = RGBA16F;  // chuva e neve (pré-multiplicado)
const vec4 colortex8ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const int colortex7Format = RGBA16F;  // histórico do TAA
const bool colortex7Clear = false;
const int colortex6Format = RGBA16F;  // Cherenkov que só aparece na água
const vec4 colortex6ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const int colortex9Format = RGBA16;   // gelo na frente: normal, luz do céu, máscara
const vec4 colortex9ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;

in vec2 texcoord;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec3 albedo = texture(colortex0, texcoord).rgb;
    float depth = texture(depthtex0, texcoord).r;
    vec3 emissive = texture(colortex3, texcoord).rgb;
    if (depth >= 1.0) { outColor = vec4(albedo + emissive, 1.0); return; } // céu já está em linear

    vec4 data = texture(colortex2, texcoord);
    int mat = int(data.b * 255.0 + 0.5);
    vec3 n = normalize(texture(colortex1, texcoord).rgb * 2.0 - 1.0);
    vec3 viewPos = screenToView(texcoord, depth);

    outColor = vec4(shadeSurface(toLinear(albedo), viewPos, n, data.rg, mat) + emissive, 1.0);
}

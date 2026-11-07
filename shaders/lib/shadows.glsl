#ifndef SHADOWS_GLSL
#define SHADOWS_GLSL
#include "/lib/common.glsl"

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

vec3 distortShadow(vec3 p) {
    float f = length(p.xy) * SHADOW_DISTORT + (1.0 - SHADOW_DISTORT);
    return vec3(p.xy / f, p.z * 0.5);
}

// Retorna a luz que chega (0 = sombra, 1 = sol direto; colorida através de vidro)
vec3 getShadow(vec3 feetPos, vec3 worldNormal, float skylight) {
    float dist = length(feetPos);
    vec3 fallback = vec3(smoothstep(0.75, 0.95, skylight));
    if (dist > shadowDistance) return fallback;

    // Afasta o ponto da superfície para evitar "shadow acne" (a superfície fazendo sombra nela
    // mesma). O afastamento acompanha o tamanho do texel da sombra naquele ponto: longe do
    // jogador o texel é maior (distorção), e um afastamento fixo deixava a copa das árvores
    // piscando entre luz e sombra.
    vec4 sp0 = shadowProjection * (shadowModelView * vec4(feetPos, 1.0));
    float f = length(sp0.xy) * SHADOW_DISTORT + (1.0 - SHADOW_DISTORT);
    float texelWorld = 2.0 * shadowDistance / float(shadowMapResolution) * f / (1.0 - SHADOW_DISTORT * 0.5);
    float bias = 0.03 + texelWorld * 1.5;
    vec3 offDir = worldNormal;
    // folhas e plantas não têm normal confiável: afasta na direção da luz
    if (dot(worldNormal, worldNormal) < 0.01) { offDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition); bias *= 1.5; }
    vec3 p = feetPos + offDir * bias;
    vec4 sp = shadowProjection * (shadowModelView * vec4(p, 1.0));
    sp.xyz = distortShadow(sp.xyz) * 0.5 + 0.5;
    if (any(lessThan(sp.xy, vec2(0.0))) || any(greaterThan(sp.xy, vec2(1.0)))) return fallback;

    float texel = SHADOW_SOFTNESS / float(shadowMapResolution);
    vec3 light = vec3(0.0);
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 uv = sp.xy + vec2(x, y) * texel;
            float s0 = step(sp.z, texture(shadowtex0, uv).r); // tudo, inclusive vidro
            float s1 = step(sp.z, texture(shadowtex1, uv).r); // só opacos
            vec3 tint = toLinear(texture(shadowcolor0, uv).rgb);
            light += vec3(s0) + (s1 - s0) * tint;
        }
    }
    light /= 9.0;
    float fade = smoothstep(0.85, 1.0, dist / shadowDistance);
    return mix(light, fallback, fade);
}

#endif

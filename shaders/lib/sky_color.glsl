#ifndef SKY_COLOR_GLSL
#define SKY_COLOR_GLSL
// Cor do céu por bioma e altitude (sem nuvens). Usada pelo céu, pela neblina,
// pelo reflexo da água e pela luz ambiente (as sombras pegam a cor deste céu).
#include "/lib/common.glsl"

vec3 viewToWorldDir(vec3 v) { return normalize(mat3(gbufferModelViewInverse) * v); }

// 0 = céu aberto, 1 = totalmente fechado (chuva ou bioma nublado)
float overcastAmount() {
    // acima da camada de nuvens o céu do bioma nublado fica limpo
    return clamp(max(rainStrength, biomeOvercast * OVERCAST_STRENGTH) * (1.0 - aboveClouds()), 0.0, 1.0);
}

// Cor do céu sem nuvens, em linear
vec3 getBiomeSky(vec3 viewDir) {
    vec3 vanilla = getSkyColor(viewDir);
    #ifndef BIOME_SKY
    return vanilla;
    #else
    vec3 d = viewToWorldDir(viewDir);
    vec3 sunDir = viewToWorldDir(sunPosition);
    float h = sunHeight();
    // O céu fica claro até o sol se pôr (h = 0) e escurece no crepúsculo civil
    // (sol de 0° a -6°, h ~ -0,10); antes, a vanilla já escurecia com o sol a ~11° de altura.
    float day = smoothstep(-0.13, 0.0, h);
    float vivid = skyVivid * DRY_SKY_VIBRANCE, hazy = skyHazy;
    float over = overcastAmount();

    // Normal / Vivo (azul profundo) / Nebuloso (pálido)
    vec3 zenith = vec3(0.16, 0.32, 0.75);
    zenith = mix(zenith, vec3(0.05, 0.20, 0.88), clamp(vivid, 0.0, 1.5));
    zenith = mix(zenith, vec3(0.30, 0.42, 0.64), hazy * 0.55);
    vec3 horizon = vec3(0.52, 0.63, 0.80);
    horizon = mix(horizon, vec3(0.62, 0.70, 0.86), clamp(vivid, 0.0, 1.0) * 0.5); // seco: horizonte limpo
    horizon = mix(horizon, vec3(0.70, 0.75, 0.84), hazy);                         // úmido: branco leitoso

    // altitude: ar rarefeito, zênite azul-escuro e faixa do horizonte mais fina
    float alt = altitudeFactor() * ALT_SKY_DEEPEN;
    zenith = mix(zenith, vec3(0.02, 0.07, 0.42), clamp(alt * 0.7, 0.0, 0.95));
    horizon = mix(horizon, vec3(0.66, 0.76, 0.92), clamp(alt * 0.4, 0.0, 1.0));

    float tExp = mix(mix(3.0, 4.5, clamp(vivid, 0.0, 1.0)), 1.6, hazy) * (1.0 + alt * 1.5); // névoa sobe mais no nebuloso

    // Acima da camada de nuvens: céu limpo de janela de avião. Azul intenso no alto,
    // azul claro no horizonte; quanto mais alto, mais escuro e mais fina a faixa clara.
    float ac = aboveClouds();
    float hi = smoothstep(cloudTop(), cloudTop() + HIGH_ALT_RANGE, cameraPosition.y) * HIGH_ALT_DARKEN;
    vec3 zA = mix(vec3(0.015, 0.10, 0.78), vec3(0.004, 0.018, 0.17), clamp(hi, 0.0, 1.0));
    vec3 hA = mix(vec3(0.38, 0.62, 0.96), vec3(0.18, 0.38, 0.82), clamp(hi * 0.6, 0.0, 1.0));
    zenith = mix(zenith, zA, ac);
    horizon = mix(horizon, hA, ac);
    tExp = mix(tExp, mix(4.0, 10.0, clamp(hi, 0.0, 1.0)), ac);

    float up = max(d.y, 0.0);
    float t = pow(1.0 - up, tExp);
    vec3 sky = mix(zenith, horizon, t);

    // nascer/pôr do sol e halo do sol
    float sunDot = max(dot(d, sunDir), 0.0);
    float low = (1.0 - smoothstep(0.0, 0.35, h)) * smoothstep(-0.25, 0.0, h);
    sky += vec3(1.0, 0.42, 0.14) * low * (pow(sunDot, 3.0) * 1.4 + 0.25) * pow(1.0 - up, 2.0);
    sky += vec3(1.0, 0.9, 0.75) * pow(sunDot, 48.0) * 0.6 * day * (1.0 - over); // halo some com o céu fechado

    // crepúsculo: o zênite fica azul mais fundo e escurece antes do horizonte do lado do sol
    float dusk = 1.0 - smoothstep(-0.02, 0.10, h);
    sky *= mix(1.0, mix(0.55, 1.0, pow(sunDot, 2.0) * pow(1.0 - up, 1.5)), dusk);

    // Nublado: cinza chapado
    vec3 grey = vec3(0.42, 0.45, 0.50) * (0.9 + 0.15 * up);
    sky = mix(sky, grey, over);

    // Tempestade: as nuvens de trovoada são grossas e escuras no alto; a luz entra de lado,
    // por baixo da base delas, e deixa uma faixa mais clara junto ao horizonte.
    // A luz ambiente vem deste céu, então escurece junto.
    float storm = clamp(thunderStrength * (1.0 - aboveClouds()), 0.0, 1.0) * STORM_DARKNESS;
    float band = pow(1.0 - up, 4.0);
    sky *= mix(1.0, mix(0.22, 0.85, band), storm);

    return mix(vanilla, sky * SKY_BRIGHTNESS, day);
    #endif
}

#endif

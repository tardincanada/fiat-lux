#ifndef BIOME_SKY_GLSL
#define BIOME_SKY_GLSL
// Nuvens procedurais por bioma e altitude. Os valores por bioma vêm de
// shaders.properties (uniform.float ...) e mudam suavemente ao trocar de bioma.
#include "/lib/lighting.glsl"
#include "/lib/sky_color.glsl"
#include "/lib/noise.glsl"

// Nuvens com altura real: três camadas baixas (cloudLayerHeights) e os cirros (CIRRUS_HEIGHT). Dá para subir acima delas.
// rgb = cor (linear), a = cobertura; dist = distância até a nuvem (para esconder atrás de montanhas).
// Cúmulos é o padrão; Cirros, Estratos, Poucas e Nenhuma vêm da tabela de biomas.
float cloudLayerHit(vec3 d, float height) {
    if (abs(d.y) < 1e-4) return -1.0;
    return (height - cameraPosition.y) / d.y;
}

vec4 getClouds(vec3 viewDir, out float dist) {
    dist = 1e9;
    #ifndef PROCEDURAL_CLOUDS
    return vec4(0.0);
    #else
    vec3 d = viewToWorldDir(viewDir);
    float over = overcastAmount();
    float overBiome = clamp(biomeOvercast * OVERCAST_STRENGTH, 0.0, 1.0); // estratos ficam lá embaixo mesmo acima deles
    float stratus = max(cloudStratus, max(rainStrength, overBiome)); // vista de cima a chuva continua sendo um manto
    float cirrusB = cloudCirrus * (1.0 - over);
    float time = frameTimeCounter * CLOUD_SPEED;
    vec2 cam = mod(cameraPosition.xz, 20000.0);

    // cobertura total da tabela de biomas
    float cover = CLOUD_COVERAGE;
    cover *= 1.0 - cloudFew * 0.55;
    cover *= 1.0 - cirrusB * 0.75;
    cover *= 1.0 - cloudNone;
    float deck = stratus * (1.0 - cloudNone * (1.0 - over));
    vec3 H = cloudLayerHeights();

    vec3 Lsun = viewToWorldDir(shadowLightPosition);
    float toward = pow(max(dot(d, Lsun), 0.0), 6.0);
    vec3 lit = getLightColor() * (0.32 + toward * 0.9) + getAmbientColor() * 0.75 + 0.01;
    float fromAbove = step(d.y, 0.0); // vista de cima: topo iluminado pelo sol

    // até 4 planos: 3 camadas baixas + cirros. t = distância, c = cor, a = cobertura
    float t[4]; vec3 c[4]; float al[4];
    #if CLOUD_LAYERS == 3
    // a mesma cobertura total dividida entre três camadas com desenhos diferentes:
    // juntas cobrem o céu como uma só (1 - (1 - c)^3 = cobertura total)
    float cEach = cover > 0.001 ? 1.0 - pow(1.0 - cover, 1.0 / 3.0) : 0.0;
    #else
    float cEach = cover;
    #endif
    for (int i = 0; i < 3; i++) {
        t[i] = -1.0; c[i] = vec3(0.0); al[i] = 0.0;
        #if CLOUD_LAYERS == 1
        if (i > 0) continue;
        #endif
        float h = H[i];
        float ti = cloudLayerHit(d, h);
        if (ti <= 0.0) continue;
        vec2 wp = cam + d.xz * ti;
        float n;
        if (i == 0) {        // baixa: cúmulos grandes e arredondados
            n = fbm(wp * 0.011 + vec2(time * 0.006, time * 0.002), 6);
        } else if (i == 1) { // média: altocúmulos menores, em flocos
            n = fbm(wp * 0.019 + vec2(37.1 + time * 0.008, 11.7 + time * 0.003), 5);
        } else {             // alta: faixas alongadas pelo vento (altostratos)
            vec2 q = mat2(0.94, -0.34, 0.34, 0.94) * (wp * 0.008) + vec2(71.3 + time * 0.010, 5.2);
            n = fbm(vec2(q.x * 0.6, q.y * 1.6), 5);
        }
        float cum = cEach > 0.001 ? smoothstep(1.0 - cEach, 1.0 - cEach + 0.22, n) : 0.0;
        float dens = i == 0 ? 1.0 : (i == 1 ? 0.8 : 0.6); // na chuva, as de cima são mais finas
        float strat = mix(0.72, 1.0, smoothstep(0.25, 0.75, n)) * dens;
        float a = mix(cum, strat, deck);
        a *= 1.0 - smoothstep(1800.0, 6000.0, ti);                      // some ao longe
        a *= smoothstep(2.0, 20.0, abs(cameraPosition.y - h));          // dentro da camada
        // camadas de baixo ficam mais escuras sob as de cima (mais no tempo fechado)
        float shade = i == 0 ? mix(0.92, 0.70, deck) : (i == 1 ? mix(0.97, 0.85, deck) : 1.0);
        c[i] = lit * shade * mix(mix(1.0, 0.55, a * a) * mix(1.0, 0.62, stratus), 1.15, fromAbove);
        t[i] = ti; al[i] = a;
    }

    // cirros
    t[3] = -1.0; c[3] = vec3(0.0); al[3] = 0.0;
    float tCir = cloudLayerHit(d, CIRRUS_HEIGHT);
    if (tCir > 0.0) {
        vec2 q = (cam + d.xz * tCir) * 0.0045 + vec2(time * 0.012, 0.0);
        q = mat2(0.94, -0.34, 0.34, 0.94) * q;
        float nc = fbm(vec2(q.x * 0.35, q.y * 3.0), 5);
        float cirAmt = mix(0.15, 1.0, cirrusB) * (1.0 - over) * (1.0 - cloudNone);
        float cir = smoothstep(0.55, 0.85, nc) * 0.6 * cirAmt;
        cir *= 1.0 - smoothstep(3000.0, 9000.0, tCir);
        t[3] = tCir; c[3] = lit * 1.1; al[3] = cir;
    }

    // junta da mais próxima para a mais distante
    vec3 acc = vec3(0.0); float A = 0.0;
    float last = 0.0;
    for (int k = 0; k < 4; k++) {
        int best = -1; float bt = 1e20;
        for (int j = 0; j < 4; j++) if (t[j] > last && t[j] < bt && al[j] > 0.0) { bt = t[j]; best = j; }
        if (best < 0) break;
        last = bt;
        dist = min(dist, bt);
        acc += (1.0 - A) * al[best] * c[best];
        A += (1.0 - A) * al[best];
    }
    return vec4(acc / max(A, 1e-4), A * CLOUD_OPACITY);
    #endif
}
vec4 getClouds(vec3 viewDir) { float d; return getClouds(viewDir, d); }

vec3 getFullSky(vec3 viewDir) {
    vec3 sky = getBiomeSky(viewDir);
    vec4 c = getClouds(viewDir);
    return mix(sky, c.rgb, c.a);
}

#endif

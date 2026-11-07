#version 330 compatibility
// Reflexo na água (screen-space reflections) e neblina.
#include "/lib/water.glsl"
#include "/lib/biome_sky.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D colortex8; // chuva e neve
uniform sampler2D depthtex0;
uniform sampler2D depthtex1; // profundidade sem a água (fundo)

in vec2 texcoord;
/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outEmissive;

vec3 traceReflection(vec3 viewPos, vec3 n, vec3 fallback) {
    vec3 dir = reflect(normalize(viewPos), n);
    vec3 p = viewPos + n * 0.05;
    float stepLen = 0.25 + length(viewPos) * 0.01;
    for (int i = 0; i < SSR_STEPS; i++) {
        vec3 prev = p;
        p += dir * stepLen;
        vec3 s = viewToScreen(p);
        if (s.x < 0.0 || s.x > 1.0 || s.y < 0.0 || s.y > 1.0 || s.z > 1.0) break;
        float d = texture(depthtex0, s.xy).r;
        vec3 sceneP = screenToView(s.xy, d);
        float diff = sceneP.z - p.z;       // >0: o raio passou atrás da superfície
        if (d < 1.0 && diff > 0.0 && diff < stepLen * 2.5) {
            // refinamento por busca binária
            vec3 a = prev, b = p;
            for (int j = 0; j < 5; j++) {
                vec3 m = (a + b) * 0.5;
                vec3 ms = viewToScreen(m);
                float md = screenToView(ms.xy, texture(depthtex0, ms.xy).r).z;
                if (md - m.z > 0.0) b = m; else a = m;
            }
            vec3 hs = viewToScreen(b);
            vec2 edge = smoothstep(0.0, 0.08, hs.xy) * smoothstep(0.0, 0.08, 1.0 - hs.xy);
            return mix(fallback, texture(colortex0, hs.xy).rgb, edge.x * edge.y);
        }
        stepLen *= 1.25;
    }
    return fallback;
}

// Fresnel exato para luz não polarizada; eta = n1/n2. Devolve 1 na reflexão interna total.
float fresnelDielectric(float cosI, float eta) {
    float sinT2 = eta * eta * (1.0 - cosI * cosI);
    if (sinT2 >= 1.0) return 1.0;
    float cosT = sqrt(1.0 - sinT2);
    float rs = (eta * cosI - cosT) / (eta * cosI + cosT);
    float rp = (cosI - eta * cosT) / (cosI + eta * cosT);
    return 0.5 * (rs * rs + rp * rp);
}

void main() {
    vec3 color = texture(colortex0, texcoord).rgb;
    float depth = texture(depthtex0, texcoord).r;
    vec3 viewPos = screenToView(texcoord, depth);
    vec4 water = texture(colortex4, texcoord);

    // Cherenkov "só na água" (minério de pechblenda, gerador de radioisótopo): aparece
    // quando o bloco é visto através da água ou com a câmera submersa, como no mod.
    vec3 emissive = texture(colortex3, texcoord).rgb;
    float wet = max(step(0.5, water.a), float(isEyeInWater == 1));
    vec3 wetGlow = texture(colortex6, texcoord).rgb * wet;
    color += wetGlow;
    emissive += wetGlow;

    if (water.a > 0.5 && isEyeInWater == 0) {
        vec3 n = normalize(decodeNormal(water.rg));
        vec3 V = -normalize(viewPos);
        float skyl, wcls;
        unpackWaterB(water.b, wcls, skyl);
        vec2 uvR = texcoord; // onde o fundo é lido (desviado pela refração)

        #if WATER_TYPE > 0 && defined WATER_REFRACTION
        // Refração: o fundo aparece deslocado pelas ondas, mais quanto mais fundo.
        // Só o desvio causado pela onda (onda menos superfície lisa), para a imagem não "pular".
        {
            float d1 = texture(depthtex1, texcoord).r;
            float thick = d1 < 1.0 ? min(length(screenToView(texcoord, d1) - viewPos), 8.0) : 8.0;
            vec3 I = normalize(viewPos);
            vec3 flatN = normalize(upPosition);
            vec3 rW = refract(I, n, 1.0 / 1.333), rF = refract(I, flatN, 1.0 / 1.333);
            vec2 sW = viewToScreen(viewPos + rW * thick).xy, sF = viewToScreen(viewPos + rF * thick).xy;
            vec2 cand = texcoord + (sW - sF) * REFRACTION_STRENGTH;
            // só aceita se o ponto desviado também está debaixo d'água (senão puxaria coisas de fora)
            if (all(greaterThan(cand, vec2(0.002))) && all(lessThan(cand, vec2(0.998)))
                && texture(colortex4, cand).a > 0.5 && texture(depthtex1, cand).r > depth) {
                uvR = cand;
                color = texture(colortex0, uvR).rgb + texture(colortex6, uvR).rgb * wet;
            }
        }
        #endif

        #if WATER_TYPE > 0
        // Absorção: o vermelho some primeiro, depois o verde; o fundo vira azul com a profundidade.
        // Caminho = trecho que o olhar percorre na água + profundidade vertical (luz do sol descendo).
        float depth1 = texture(depthtex1, uvR).r;
        float path = 64.0;
        if (depth1 < 1.0) {
            vec3 v1 = screenToView(uvR, depth1);
            float vertical = max(viewToFeet(viewPos).y - viewToFeet(v1).y, 0.0);
            path = length(v1 - viewPos) + vertical;
        }
        vec3 wa, ws;
        waterOptics(wcls, wa, ws);
        vec3 T = exp(-wa * WATER_ABSORPTION_SCALE * path);
        vec3 inscatter = ws * (getAmbientColor() * 0.6 + getLightColor() * 0.25) * (0.2 + 0.8 * skyl);
        color = color * T + inscatter * (1.0 - T);
        #endif

        #ifdef WATER_REFLECTIONS
        float f = fresnelSchlick(dot(n, V), 0.02);
        vec3 sky = getFullSky(reflect(-V, n)) * smoothstep(0.0, 0.6, skyl);
        vec3 refl = traceReflection(viewPos, n, sky);
        color = mix(color, refl, f);
        #endif

        // brilho do sol/lua na superfície (com sombra)
        vec3 feet = viewToFeet(viewPos);
        vec3 shadow = getShadow(feet, vec3(0.0, 1.0, 0.0), skyl);
        vec3 H = normalize(normalize(shadowLightPosition) + V);
        float spec = pow(max(dot(n, H), 0.0), 240.0) * 3.0;
        color += getLightColor() * shadow * spec;

        // chuva ou neve: água bem dessaturada e um pouco mais escura (céu cinza, luz difusa);
        // na neve, um pouco mais dessaturada ainda
        float wetK = rainStrength * (1.0 - aboveClouds());
        float wl = dot(color, vec3(0.2126, 0.7152, 0.0722));
        color = mix(color, vec3(wl), wetK * mix(0.65, 0.8, snowFall)) * (1.0 - 0.15 * wetK);
    }

    #if WATER_TYPE > 0 && defined SNELL_WINDOW
    // Vista de baixo da superfície: só se vê o lado de fora dentro do cone de ~48,6°
    // (janela de Snell, com o mundo de fora comprimido e ondulado). Fora dele há reflexão
    // interna total: a superfície vira espelho do fundo e da própria água.
    if (water.a > 0.5 && isEyeInWater == 1) {
        vec3 n = normalize(decodeNormal(water.rg));
        vec3 I = normalize(viewPos);
        if (dot(n, I) > 0.0) n = -n;                 // normal virada para a câmera
        float cosI = clamp(dot(-I, n), 0.0, 1.0);
        float F = fresnelDielectric(cosI, 1.333);    // água -> ar
        vec3 wa, ws;
        waterOpticsEye(wa, ws);
        float eyeSky = float(eyeBrightnessSmooth.y) / 240.0;
        vec3 deepC = ws * (getAmbientColor() * 0.6 + getLightColor() * 0.25) * (0.2 + 0.8 * eyeSky);
        vec3 refl = deepC;
        #ifdef WATER_REFLECTIONS
        refl = traceReflection(viewPos, n, deepC);
        #endif
        vec3 outside = vec3(0.0);
        if (F < 1.0) {
            vec3 r = refract(I, n, 1.333);
            float d1 = texture(depthtex1, texcoord).r;
            float far1 = d1 < 1.0 ? min(length(screenToView(texcoord, d1) - viewPos), 96.0) : 96.0;
            vec3 s = viewToScreen(viewPos + r * far1);
            vec3 skyR = getFullSky(r);
            if (s.z > 0.0 && all(greaterThan(s.xy, vec2(0.0))) && all(lessThan(s.xy, vec2(1.0)))) {
                vec2 e = smoothstep(0.0, 0.06, s.xy) * smoothstep(0.0, 0.06, 1.0 - s.xy);
                float onSurf = step(0.5, texture(colortex4, s.xy).a); // o que está lá precisa ser visto pela superfície
                outside = mix(skyR, texture(colortex0, s.xy).rgb, e.x * e.y * onSurf);
            } else outside = skyR;
        }
        color = mix(outside, refl, F);
    }
    #endif

    // neblina
    float dist = length(viewPos);
    if (isEyeInWater == 1) {
        #if WATER_TYPE > 0
        // submerso: a mesma absorção ao longo do olhar
        float d = depth >= 1.0 ? 96.0 : dist;
        vec3 wa, ws;
        waterOpticsEye(wa, ws);
        vec3 T = exp(-wa * WATER_ABSORPTION_SCALE * d);
        float eyeSky = float(eyeBrightnessSmooth.y) / 240.0;
        vec3 inscatter = ws * (getAmbientColor() * 0.6 + getLightColor() * 0.25) * (0.2 + 0.8 * eyeSky);
        color = color * T + inscatter * (1.0 - T);
        #else
        float f = 1.0 - exp(-dist * 0.07);
        color = mix(color, toLinear(fogColor) * 0.6, f);
        #endif
    } else if (isEyeInWater == 2) {
        color = mix(color, vec3(1.0, 0.3, 0.05), 1.0 - exp(-dist * 1.5)); // dentro da lava
    } else if (depth < 1.0) {
        // começa mais longe em ar seco (Leve), bem perto em Densa
        float altClear = 1.0 - ALT_FOG_CLEAR * altitudeFactor();
        // SKY_HAZE: 0 = sem névoa de distância (só some na borda), 1 = padrão, 1,5 = mais névoa
        float start = far * (1.0 - (1.0 - mix(0.55, 0.8, fogLight)) * SKY_HAZE);
        start = min(start, far * 0.97);
        float f = smoothstep(start, far, dist);
        float weather = max(rainStrength, overcastAmount() * 0.6);
        f = max(f, weather * (1.0 - exp(-dist * 0.01 * (1.0 + SNOW_FOG * rainStrength * snowFall))));
        f = max(f, fogDense * FOG_DENSE_STRENGTH * (1.0 - exp(-dist * 0.025)));
        f = max(f, fogHumid * FOG_HUMID_STRENGTH * (1.0 - exp(-dist * 0.006)));
        f *= altClear;
        // a névoa tende à cor do céu ATRÁS do objeto (na mesma direção do olhar), nunca a mais
        // que ela: antes usava a cor do horizonte, que é mais clara que o céu acima dele
        vec3 fogC = getBiomeSky(viewPos);
        fogC = mix(fogC, toLinear(fogColor), float(isEyeInWater != 0));
        color = mix(color, fogC, f);

        #ifdef AERIAL_PERSPECTIVE
        // Perspectiva atmosférica vista do alto: o ar fica mais denso perto do chão (dobra a cada
        // ~60 blocos de descida). Soma o ar entre o olho e o ponto; o azul se espalha mais que o
        // vermelho, então o que é escuro clareia e azula, e o que é claro amarela um pouco.
        {
            const float Hs = 86.6;                       // escala de altura (ln2 * 86.6 = 60 blocos)
            float y0 = cameraPosition.y - 63.0;
            float y1 = viewToFeet(viewPos).y + cameraPosition.y - 63.0;
            float dy = y1 - y0;
            float r0 = exp(-max(y0, 0.0) / Hs);
            float r1 = exp(-max(y1, 0.0) / Hs);
            float airPath = abs(dy) > 0.5 ? dist * (r0 - r1) * Hs / dy : dist * r0;
            float ramp = altitudeFactor();               // no chão, a neblina normal cuida do horizonte
            vec3 tau = vec3(0.0035, 0.0060, 0.0100) * AERIAL_STRENGTH * airPath * ramp;
            vec3 T = exp(-tau);
            vec3 hazeC = getBiomeSky(viewPos) * (1.0 - overcastAmount() * 0.3);
            color = color * T + hazeC * (1.0 - T);
        }
        #endif
    }

    // nuvens: na frente do céu e de montanhas mais distantes que elas
    #ifdef PROCEDURAL_CLOUDS
    if (isEyeInWater == 0) {
        float cloudDist;
        vec4 cl = getClouds(viewPos, cloudDist);
        float sceneDist = depth >= 1.0 ? 1e9 : dist;
        if (cl.a > 0.0 && cloudDist < sceneDist) {
            // a chuva e a neblina densa ficam entre o olho e a nuvem: ao longe a nuvem se
            // funde com o cinza do horizonte, como o terreno; só a base logo acima fica escura
            float weatherC = max(rainStrength, overcastAmount() * 0.6) * (1.0 - aboveClouds());
            float fc = weatherC * (1.0 - exp(-max(cloudDist - 120.0, 0.0) * 0.0025 * (1.0 + SNOW_FOG * rainStrength * snowFall)));
            fc = max(fc, fogDense * FOG_DENSE_STRENGTH * (1.0 - exp(-cloudDist * 0.004)));
            fc = max(fc, fogHumid * FOG_HUMID_STRENGTH * (1.0 - exp(-cloudDist * 0.0015)));
            vec3 cdir = mat3(gbufferModelViewInverse) * viewPos;
            cdir = normalize(vec3(cdir.x, 0.0, cdir.z) + vec3(0.0, 0.02, 0.0));
            vec3 cloudC = mix(cl.rgb, getBiomeSky(mat3(gbufferModelView) * cdir), clamp(fc, 0.0, 1.0));
            color = mix(color, cloudC, cl.a);
        }
    }
    #endif

    // chuva e neve por cima de tudo (já iluminadas; não passam pela água nem pela neblina)
    vec4 wx = texture(colortex8, texcoord);
    color = color * (1.0 - wx.a) + wx.rgb;

    outColor = vec4(color, 1.0);
    outEmissive = vec4(emissive, 1.0);
}

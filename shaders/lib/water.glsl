#ifndef WATER_GLSL
#define WATER_GLSL
#include "/lib/common.glsl"
#include "/lib/noise.glsl"

// ---------------- Ondas ----------------
// WATER_WAVE_TYPE: 0 = senoides (antigo, regular)  1 = ruído em camadas (irregular, recomendado)
//                  2 = cristas de oceano (ondas mais agudas + ruído fino)
// "fp" = tamanho de um pixel em blocos. Detalhes menores que ~2 pixels são apagados (anti-moiré).
float lodFade(float wavelength, float fp) { return 1.0 - smoothstep(wavelength * 0.25, wavelength * 0.6, fp); }

float waveHeight(vec2 p, float fp) {
    float t = frameTimeCounter * WAVE_SPEED;
    float h = 0.0;
    #if WATER_WAVE_TYPE == 0
    h += sin(dot(p, vec2( 0.8,  0.6)) * 1.1 + t * 1.3) * 0.120 * lodFade(5.7, fp);
    h += sin(dot(p, vec2(-0.5,  0.9)) * 1.7 + t * 1.7) * 0.070 * lodFade(3.7, fp);
    h += sin(dot(p, vec2( 0.3, -1.0)) * 2.9 + t * 2.3) * 0.040 * lodFade(2.2, fp);
    h += sin(dot(p, vec2(-0.9, -0.4)) * 4.3 + t * 2.9) * 0.020 * lodFade(1.5, fp);
    h += sin(dot(p, vec2( 0.6, -0.7)) * 7.1 + t * 3.7) * 0.010 * lodFade(0.9, fp);
    #else
    // duas camadas de ruído que andam em direções diferentes: o padrão nunca se repete
    float amp = 0.16, freq = 0.32;
    for (int i = 0; i < 5; i++) {
        float lambda = 1.0 / freq;
        float fade = lodFade(lambda, fp);
        vec2 q = p * freq;
        float a = cloudNoise(q + vec2(t * 0.35, t * 0.12) * (1.0 + float(i) * 0.3));
        float b = cloudNoise(q * mat2(0.6, -0.8, 0.8, 0.6) + vec2(-t * 0.22, t * 0.31) * (1.0 + float(i) * 0.3) + 31.7);
        h += (a + b - 1.0) * amp * fade;
        amp *= 0.5; freq *= 2.07;
    }
    #if WATER_WAVE_TYPE == 2
    // cristas: ondas longas com pico agudo, vindas de uma direção dominante (vento)
    float c = 0.0;
    c += exp(sin(dot(p, vec2(0.92, 0.38)) * 0.55 - t * 0.9) - 1.0) * 0.30 * lodFade(11.0, fp);
    c += exp(sin(dot(p, vec2(0.70, 0.71)) * 0.85 - t * 1.2) - 1.0) * 0.16 * lodFade(7.4, fp);
    c += exp(sin(dot(p, vec2(0.99, -0.12)) * 1.30 - t * 1.6) - 1.0) * 0.08 * lodFade(4.8, fp);
    h = h * 0.6 + c;
    #endif
    #endif
    return h;
}

// Normal das ondas em espaço de mundo. Longe, a superfície fica mais lisa (sem cintilação).
vec3 waterNormal(vec3 worldPos, float fp) {
    vec2 p = mod(worldPos.xz, 4096.0);
    const float e = 0.06;
    float h0 = waveHeight(p, fp);
    float hx = waveHeight(p + vec2(e, 0.0), fp);
    float hz = waveHeight(p + vec2(0.0, e), fp);
    vec3 n = normalize(vec3((h0 - hx) / e * WAVE_STRENGTH, 1.0, (h0 - hz) / e * WAVE_STRENGTH));
    return normalize(mix(n, vec3(0.0, 1.0, 0.0), smoothstep(0.15, 1.5, fp) * 0.7));
}

float fresnelSchlick(float cosTheta, float f0) {
    return f0 + (1.0 - f0) * pow(1.0 - clamp(cosTheta, 0.0, 1.0), 5.0);
}

// ---------------- Absorção (lei de Beer-Lambert, 1 bloco = 1 metro) ----------------
// WATER_TYPE: 0 = clássica (cor do Minecraft, sem absorção)  1 = pura/realista  2 = oceano tropical
//             3 = costeira (esverdeada)  4 = intensa (jogo)  5 = por líquido e bioma (doce/salgada/salmoura)
// cls: 0 doce, 1 salgada, 2 salmoura (ver waterClassFromId)

// cada preset: absorção (por metro) e cor espalhada
#define S1_A vec3(0.90, 0.130, 0.045)
#define S1_S vec3(0.00, 0.20, 0.24)
#define S2_A vec3(0.95, 0.170, 0.200)
#define S2_S vec3(0.03, 0.105, 0.105)
#define S3_A vec3(1.30, 0.400, 0.330)
#define S3_S vec3(0.02, 0.035, 0.060)
#define D1_A vec3(0.90, 0.350, 0.300)
#define D1_S vec3(0.05, 0.42, 0.45)
#define D2_A vec3(0.80, 0.150, 0.300)
#define D2_S vec3(0.03, 0.14, 0.08)
#define D3_A vec3(0.30, 0.500, 1.000)
#define D3_S vec3(0.12, 0.07, 0.02)
#define D4_A vec3(1.40, 1.600, 2.000)
#define D4_S vec3(0.68, 0.30, 0.07)
#if BRINE_STYLE == 2
#define B_A vec3(0.20, 0.700, 0.550)
#define B_S vec3(0.30, 0.10, 0.14)
#else
#define B_A vec3(0.35, 0.050, 0.030)
#define B_S vec3(0.05, 0.16, 0.18)
#endif

void saltWater(out vec3 a, out vec3 s) {
    a = mix(S2_A, S1_A, waterWarm); s = mix(S2_S, S1_S, waterWarm);
    a = mix(a, S3_A, waterCold);    s = mix(s, S3_S, waterCold);
}
void freshWater(out vec3 a, out vec3 s) {
    a = D2_A; s = D2_S;
    a = mix(a, D1_A, waterGlacial); s = mix(s, D1_S, waterGlacial);
    a = mix(a, D3_A, waterSwamp);   s = mix(s, D3_S, waterSwamp);
    a = mix(a, D4_A, waterMud);     s = mix(s, D4_S, waterMud);
}

// a = absorção, s = cor espalhada (o que aparece no lugar do fundo, quando é fundo demais)
void waterOptics(float cls, out vec3 a, out vec3 s) {
    #if WATER_TYPE == 1
    a = vec3(0.45, 0.065, 0.020); s = vec3(0.00, 0.10, 0.22);
    #elif WATER_TYPE == 2
    a = S1_A; s = S1_S;
    #elif WATER_TYPE == 3
    a = vec3(0.75, 0.100, 0.200); s = vec3(0.02, 0.15, 0.12);
    #elif WATER_TYPE == 4
    a = vec3(1.80, 0.260, 0.080); s = vec3(0.00, 0.09, 0.24);
    #else
    if (cls > 1.5)      { a = B_A; s = B_S; }
    else if (cls > 0.5) saltWater(a, s);
    else                freshWater(a, s);
    #endif
}

// câmera submersa: o shader não sabe em qual líquido está; usa o bioma (mar/praia = salgada)
void waterOpticsEye(out vec3 a, out vec3 s) {
    #if WATER_TYPE == 5
    vec3 fa, fs, sa, ss;
    freshWater(fa, fs); saltWater(sa, ss);
    a = mix(fa, sa, waterSea); s = mix(fs, ss, waterSea);
    #else
    waterOptics(0.0, a, s);
    #endif
}

#endif

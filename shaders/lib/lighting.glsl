#ifndef LIGHTING_GLSL
#define LIGHTING_GLSL
#include "/lib/shadows.glsl"
#include "/lib/sky_color.glsl"

uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

// Luz direta (sol de dia, lua de noite)
vec3 getLightColor() {
    float h = sunHeight();
    float day   = smoothstep(0.0, 0.12, h);
    float night = smoothstep(0.0, 0.12, -h);
    vec3 sun  = mix(vec3(1.0, 0.45, 0.2), vec3(1.0, 0.93, 0.82), smoothstep(0.05, 0.4, h)) * SUN_BRIGHTNESS;
    vec3 moon = vec3(0.35, 0.45, 0.75) * 0.12;
    // Chuva, neve e tempestade fecham o céu: sem luz direta (nem sombras nem brilho do sol/lua
    // na água), sumindo junto com a intensidade da chuva. Biomas nublados guardam 20% de sol.
    // Acima da camada de nuvens o sol volta inteiro.
    float above = aboveClouds();
    float rainW = clamp(rainStrength * (1.0 - above), 0.0, 1.0);
    float overB = clamp(biomeOvercast * OVERCAST_STRENGTH * (1.0 - above), 0.0, 1.0);
    return (sun * day + moon * night) * (1.0 - rainW) * (1.0 - overB * 0.8) * (1.0 + ALT_SUN_BOOST * altitudeFactor());
}

// Luz ambiente = a cor do céu que o observador vê (zênite + horizonte).
// Céu azul deixa a sombra azulada; céu cinza deixa a luz difusa e neutra; no pôr do sol, alaranjada.
vec3 getAmbientColor() {
    vec3 zen = getBiomeSky(normalize(upPosition));
    vec3 h1  = getBiomeSky(mat3(gbufferModelView) * normalize(vec3( 1.0, 0.15,  0.3)));
    vec3 h2  = getBiomeSky(mat3(gbufferModelView) * normalize(vec3(-1.0, 0.15, -0.3)));
    vec3 a = (zen * 0.55 + (h1 + h2) * 0.225) * AMBIENT_SKY_SCALE;
    a = max(a, vec3(0.010, 0.013, 0.026)); // piso para noites muito escuras
    return a * AMBIENT_STRENGTH;
}

// ---------------- Cor da luz de bloco ----------------
// O lightmap do Minecraft só diz QUANTA luz de bloco chega. A COR vem do mapa 3D (shadowcomp.csh):
// rgb = mistura das cores das lâmpadas próximas, a = parte monocromática (sódio de baixa pressão).
uniform int heldItemId;
uniform int heldItemId2;
#ifdef COLORED_LIGHTS_ON
uniform sampler3D floodSamplerA;
uniform sampler3D floodSamplerB;
#endif

// cor da luz de bloco num ponto (feet = posição relativa à câmera); a = quanto apaga as cores
vec4 blockLightTint(vec3 feet, vec3 worldN, out float arc) {
    vec4 tint = vec4(TORCH_R, TORCH_G, TORCH_B, 0.0);
    arc = 0.0;
    #ifdef COLORED_LIGHTS_ON
    vec3 rel = feet + fract(cameraPosition) + worldN * 0.6 + vec3(VOX_SIZE / 2);
    vec3 uv = rel / vec3(VOX_SIZE);
    if (all(greaterThan(uv, vec3(0.0))) && all(lessThan(uv, vec3(1.0)))) {
        vec4 f = (frameCounter % 2 == 0) ? texture(floodSamplerB, uv) : texture(floodSamplerA, uv);
        float m = max(f.r, max(f.g, f.b));
        // perto da borda do volume volta aos poucos para a cor padrão
        vec3 edge = min(uv, 1.0 - uv) * vec3(VOX_SIZE);
        float w = smoothstep(0.0, 0.004, m) * smoothstep(0.0, 6.0, min(edge.x, min(edge.y, edge.z)));
        if (m > 1e-6) {
            tint = mix(tint, vec4(f.rgb / m, clamp(f.a / m, 0.0, 1.0)), w);
            arc = clamp(-f.a / m, 0.0, 1.0) * w; // parte da luz que vem de arco elétrico
        }
    }
    #endif
    return tint;
}

// arco elétrico: oscila rápido e às vezes quase apaga, como uma solda
float arcFlicker() {
    float t = frameTimeCounter;
    float fast = 0.18 * sin(t * 47.0) * sin(t * 23.3 + 1.3) + 0.10 * sin(t * 91.0);
    float k = floor(t * 14.0);
    float dip = step(0.88, fract(sin(k * 91.37) * 43758.55)) * 0.55;
    return clamp(1.0 + fast - dip, 0.25, 1.4);
}

// cor da luz segurada na mão (item.properties 10200..)
vec4 handLightTint() {
    int id = heldBlockLightValue2 > heldBlockLightValue ? heldItemId2 : heldItemId;
    vec4 c = lightSourceColor(id >= ID_LIGHT_FIRST && id <= ID_LIGHT_LAST ? id : ID_EMISSIVE);
    c.a = max(c.a, 0.0);
    return c;
}

// Luz de tochas, lâmpadas, lava etc. (canal de luz de bloco do lightmap)
vec3 getBlockLight(float lmx) {
    float flicker = 1.0;
    #ifdef TORCH_FLICKER
    flicker = 1.0 + 0.04 * sin(frameTimeCounter * 7.3) * sin(frameTimeCounter * 3.1 + 1.7);
    #endif
    vec3 torch = vec3(TORCH_R, TORCH_G, TORCH_B);
    return torch * (pow(lmx, 4.0) * 2.5 + pow(lmx, 1.5) * 0.25) * BLOCKLIGHT_STRENGTH * flicker;
}


// Luz dinâmica de tocha/lanterna segurada na mão (como o lightmap: cai 1 nível por bloco)
float handLight(vec3 viewPos) {
    #ifdef HAND_LIGHT
    float level = float(max(heldBlockLightValue, heldBlockLightValue2));
    return clamp((level - length(viewPos)) / 15.0, 0.0, 1.0);
    #else
    return 0.0;
    #endif
}

// Multiplicador de luz final para um ponto
// separa a luz de bloco (blockOut, com cor) do resto; mono = quanto a luz de bloco apaga as cores
vec3 computeLightingSplit(vec3 viewPos, vec3 viewNormal, vec2 lm, int mat, out vec3 shadowOut, out vec3 blockOut, out float mono) {
    vec3 L = normalize(shadowLightPosition);
    float NdotL = (mat == MAT_FOLIAGE) ? 0.6 : max(dot(viewNormal, L), 0.0);
    vec3 feet = viewToFeet(viewPos);
    vec3 worldN = (mat == MAT_FOLIAGE) ? vec3(0.0) : mat3(gbufferModelViewInverse) * viewNormal;

    vec3 shadow = vec3(0.0);
    if (NdotL > 0.0) shadow = getShadow(feet, worldN, lm.y) * smoothstep(0.0, 0.25, lm.y);
    shadowOut = shadow;

    vec3 direct  = getLightColor() * NdotL * shadow;
    // hemisfério: faces para cima recebem o céu todo; para baixo, só luz rebatida do chão
    float skyF = (mat == MAT_FOLIAGE) ? 0.75 : 0.5 + 0.5 * worldN.y;
    vec3 bounce = getLightColor() * vec3(0.9, 0.85, 0.75) * GROUND_BOUNCE;
    vec3 ambient = (getAmbientColor() * mix(0.45, 1.0, skyF) + bounce * (1.0 - skyF))
                 * (lm.y * lm.y * 0.85 + lm.y * 0.15) + vec3(MIN_LIGHT);
    float hand = handLight(viewPos);
    float arc;
    vec4 tint = blockLightTint(feet, worldN, arc);
    if (hand > lm.x) tint = mix(tint, handLightTint(), smoothstep(0.0, 0.15, hand - lm.x));
    // getBlockLight usa a cor das tochas; troca pela cor do lugar
    vec3 torch = vec3(TORCH_R, TORCH_G, TORCH_B);
    blockOut = getBlockLight(max(lm.x, hand)) / torch * tint.rgb;
    mono = max(tint.a, 0.0) * LPS_DESATURATION;
    #ifdef ARC_FLICKER
    blockOut *= mix(1.0, arcFlicker(), arc);
    #endif
    return direct + ambient;
}

vec3 computeLighting(vec3 viewPos, vec3 viewNormal, vec2 lm, int mat, out vec3 shadowOut) {
    vec3 b; float m;
    return computeLightingSplit(viewPos, viewNormal, lm, mat, shadowOut, b, m) + b;
}

// cor final de uma superfície: sob sódio de baixa pressão a luz de bloco só mostra o brilho, não a cor
vec3 shadeSurface(vec3 albedo, vec3 viewPos, vec3 viewNormal, vec2 lm, int mat) {
    vec3 s, b; float m;
    vec3 L = computeLightingSplit(viewPos, viewNormal, lm, mat, s, b, m);
    vec3 grey = vec3(dot(albedo, vec3(0.2126, 0.7152, 0.0722)));
    return albedo * L + mix(albedo, grey, m) * b;
}

vec3 computeLighting(vec3 viewPos, vec3 viewNormal, vec2 lm, int mat) {
    vec3 s;
    return computeLighting(viewPos, viewNormal, lm, mat, s);
}

#endif

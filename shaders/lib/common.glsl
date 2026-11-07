#ifndef COMMON_GLSL
#define COMMON_GLSL
#include "/lib/settings.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform int frameCounter;
uniform float thunderStrength;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
// uniforms de bioma (shaders.properties)
uniform float skyVivid;      // céu: Vivo
uniform float skyHazy;       // céu: Nebuloso
uniform float biomeOvercast; // céu: Nublado (permanente)
uniform float cloudCirrus;   // nuvens: Cirros
uniform float cloudStratus;  // nuvens: Estratos
uniform float cloudFew;      // nuvens: Poucas
uniform float cloudNone;     // nuvens: Nenhuma
uniform float fogLight;      // neblina: Leve
uniform float fogDense;
uniform float fogHumid;      // neblina: Úmida (selva), mais leve que a Densa      // neblina: Densa
// cor da água por bioma (0..1, com transição de 20 s)
uniform float waterSea;      // bioma de mar/praia (decide a água ao redor da câmera submersa)
uniform float waterWarm;     // oceano morno -> S1
uniform float waterCold;     // oceano frio/profundo -> S3
uniform float waterGlacial;  // montanha/neve/taiga -> D1
uniform float waterSwamp;    // pântano -> D3
uniform float snowFall;      // 1 onde a precipitação é neve
uniform float waterMud;      // selva/savana/badlands -> D4

// IDs vindos de block.properties
#define ID_EMISSIVE    10000
#define ID_FOLIAGE     10001
#define ID_WATER       10002
#define ID_SALT_WATER  10003
#define ID_BRINE       10004
#define ID_LEAVES      10005   // folhas: balançam inteiras
#define ID_PLANT       10006   // plantas baixas: só a ponta balança
#define ID_TALL_LOW    10007   // planta de dois blocos, metade de baixo
#define ID_TALL_HIGH   10008   // planta de dois blocos, metade de cima
bool isFoliageId(int id) { return id == ID_FOLIAGE || (id >= ID_LEAVES && id <= ID_TALL_HIGH); }
// 10100..10199: radioativo; dezena = brilho no ar (0-9), unidade = brilho na água (0-9)
#define ID_RADIOACTIVE 10100
// 10200..10299: fontes de luz com cor própria (ver lightSourceColor)
#define ID_LIGHT_FIRST 10200
#define ID_LIGHT_LAST  10299

// Materiais gravados no G-buffer (colortex2.b)
#define MAT_DEFAULT     0
#define MAT_EMISSIVE    1
#define MAT_RADIOACTIVE 2
#define MAT_FOLIAGE     3
#define MAT_WATER       4

vec3 toLinear(vec3 c) { return pow(max(c, 0.0), vec3(2.2)); }

// Quanto de uma textura "brilha": partes claras e saturadas (fogo, lava, filamento)
// ou quase brancas. Metal cinza claro de máquina não brilha.
float emissiveMask(vec3 c) {
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float sat = (mx - mn) / max(mx, 1e-4);
    float lum = dot(c, vec3(0.299, 0.587, 0.114));
    return max(smoothstep(0.55, 0.95, mx) * smoothstep(0.25, 0.55, sat), smoothstep(0.82, 0.97, lum));
}

int idToMaterial(int id) {
    if (id == ID_EMISSIVE)    return MAT_EMISSIVE;
    if (id >= ID_LIGHT_FIRST && id <= ID_LIGHT_LAST) return MAT_EMISSIVE;
    if (id >= 10100 && id < 10200) return MAT_RADIOACTIVE;
    if (isFoliageId(id))      return MAT_FOLIAGE;
    if (id >= ID_WATER && id <= ID_BRINE) return MAT_WATER;
    return MAT_DEFAULT;
}

// classe do líquido: 0 doce, 1 salgada, 2 salmoura.
// Vai junto com a luz do céu em colortex4.b; a máscara (.a) fica sempre 1.0,
// porque o gbuffers_water mistura (blend) pelo alfa e um alfa < 1 corrompia os dados.
float waterClassFromId(int id) {
    if (id == ID_SALT_WATER) return 1.0;
    if (id == ID_BRINE)      return 2.0;
    return 0.0;
}
float packWaterB(float cls, float skyl) { return (cls + clamp(skyl, 0.0, 1.0) * 0.95) / 3.0; }
void unpackWaterB(float b, out float cls, out float skyl) {
    float v = b * 3.0;
    cls = floor(v + 0.001);
    skyl = clamp((v - cls) / 0.95, 0.0, 1.0);
}

// brilho de Cherenkov (x = no ar, y = na água), 0..1
vec2 cherenkovLevels(int id) {
    if (id < 10100 || id >= 10200) return vec2(0.0);
    int k = id - 10100;
    return vec2(float(k / 10), float(k - (k / 10) * 10)) / 9.0;
}

vec3 screenToView(vec2 uv, float depth) {
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}

vec3 viewToScreen(vec3 viewPos) {
    vec4 p = gbufferProjection * vec4(viewPos, 1.0);
    return p.xyz / p.w * 0.5 + 0.5;
}

vec3 viewToFeet(vec3 viewPos) {
    return (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
}

// Normal em 2 canais (projeção azimutal de Lambert)
vec2 encodeNormal(vec3 n) {
    float p = sqrt(max(n.z * 8.0 + 8.0, 1e-5));
    return n.xy / p + 0.5;
}
vec3 decodeNormal(vec2 enc) {
    vec2 f = enc * 4.0 - 2.0;
    float d = dot(f, f);
    float g = sqrt(max(1.0 - d / 4.0, 0.0));
    return vec3(f * g, 1.0 - d / 2.0);
}

// 0 no chão, 1 em ALT_FULL: céu mais escuro, menos neblina, sol mais forte
float altitudeFactor() { return smoothstep(ALT_START, ALT_FULL, cameraPosition.y); }
// Alturas das camadas de nuvens (baixa, média, alta). Na chuva elas se afastam:
// a de baixo desce, a do meio fica, a de cima sobe até a altura dos cirros.
vec3 cloudLayerHeights() {
    float r = rainStrength;
    // úmido (selva, pântano, cogumelos): base 16 mais baixa; seco (deserto, savana, badlands, picos): 24 mais alta
    float low = CLOUD_HEIGHT - CLOUD_RAIN_DROP * r + CLOUD_BIOME_SHIFT * (24.0 * fogLight - 16.0 * fogDense);
    #if CLOUD_LAYERS == 3
    // na chuva as camadas se afastam PARA BAIXO: o topo fica fixo (272), porque o mundo
    // só vai até Y 319 e os picos acima do topo devem ficar secos mesmo com chuva cheia
    float mid = CLOUD_HEIGHT + CLOUD_LAYER_GAP - 0.5 * CLOUD_RAIN_DROP * r;
    float top = CLOUD_HEIGHT + 2.0 * CLOUD_LAYER_GAP;
    #else
    float mid = low, top = low;
    #endif
    return vec3(low, mid, top);
}
// topo da última camada: acima dele não chove nem fica nublado
float cloudTop() { return cloudLayerHeights().z; }

// 1 quando a câmera está acima da camada de nuvens mais alta
float aboveClouds() {
    #ifdef CLEAR_ABOVE_CLOUDS
    float top = cloudTop();
    return smoothstep(top, top + 24.0, cameraPosition.y);
    #else
    return 0.0;
    #endif
}

float sunHeight() { return dot(normalize(sunPosition), normalize(upPosition)); }

// Cor do céu na direção (espaço de visão), já em linear
// (crepúsculo e noite). Não usa o fogColor do Minecraft: no pôr do sol ele muda conforme
// o jogador olha para o sol ou não, e o céu inteiro trocava de cor ao virar a câmera.
// skyColor depende só da hora, então o céu fica preso ao mundo.
vec3 getSkyColor(vec3 viewDir) {
    float upDot = dot(normalize(viewDir), normalize(upPosition));
    float t = 1.0 - exp(-max(upDot, 0.0) * 4.0);
    vec3 zen = toLinear(skyColor);
    vec3 hor = zen * 1.35 + vec3(0.004, 0.005, 0.008); // horizonte um pouco mais claro
    return mix(hor, zen, t);
}

// ---------------- Cor de cada fonte de luz ----------------
// rgb = cor da luz (máximo 1), a = quanto ela é monocromática (1 = sódio de baixa pressão: apaga as cores)
// a = -1 marca o arco elétrico (tremeluz)
vec4 lightSourceColor(int id) {
    if (id == 10200) return vec4(1.00, 0.60, 0.02, 1.0); // sódio de baixa pressão, 589 nm
    if (id == 10201) return vec4(0.86, 0.93, 1.00, 0.0); // LED branco frio (~6000 K)
    if (id == 10202) return vec4(1.00, 0.72, 0.42, 0.0); // chama de acetileno (~2700 K)
    if (id == 10203) return vec4(0.32, 1.00, 0.42, 0.0); // trítio (fósforo verde)
    if (id == 10204) return vec4(1.00, 0.78, 0.52, 0.0); // incandescente (~2900 K): lanterna de capacete
    if (id == 10205) return vec4(0.30, 0.85, 1.00, 0.0); // fogo das almas
    if (id == 10206) return vec4(0.80, 0.92, 1.00, 0.0); // lanterna do mar, vara do End, sinalizador
    if (id == 10207) return vec4(1.00, 0.14, 0.06, 0.0); // redstone
    if (id == 10208) return vec4(0.68, 0.32, 1.00, 0.0); // roxo (obsidiana chorona, ametista)
    // tipos pedidos pelo mod (lights.json, cores sugeridas em sRGB / 255)
    if (id == 10210) return vec4(1.00, 0.376, 0.125, 0.0); // ember_glow: brasa, 600-900 °C
    if (id == 10211) return vec4(1.00, 0.588, 0.235, 0.0); // furnace_glow: fornalha, 900-1500 °C
    if (id == 10212) return vec4(1.00, 0.886, 0.667, 0.0); // white_hot: acima de 1500 °C
    if (id == 10213) return vec4(0.804, 0.863, 1.00, -1.0); // electric_arc: arco elétrico (tremeluz)
    if (id == 10214) return vec4(0.353, 0.549, 1.00, 0.0); // bunsen_flame: chama azul
    if (id == 10215) return vec4(0.667, 0.431, 1.00, 0.0); // ion_beam: feixe de íons
    if (id == 10216) return vec4(0.314, 0.667, 1.00, 0.0); // cherenkov: azul Cherenkov
    if (id == 10217) return vec4(1.00, 0.804, 0.275, 0.0); // cleanroom_yellow: sala limpa
    if (id == 10218) return vec4(1.00, 0.725, 0.353, 0.0); // indicator_lamp: luzes de painel
    // 10209 = generic: cor de tocha (abaixo)
    return vec4(TORCH_R, TORCH_G, TORCH_B, 0.0);         // tochas, lava, fornos, máquinas e o resto
}

// Mapa 3D de luz colorida: volume de COLORED_LIGHT_RANGE blocos em volta da câmera (metade disso na vertical)
#define VOX_XZ COLORED_LIGHT_RANGE
#define VOX_Y  (COLORED_LIGHT_RANGE / 2)
#define VOX_SIZE ivec3(VOX_XZ, VOX_Y, VOX_XZ)
// voxel: 0 = ar, 1 = bloco sólido, 2.. = fonte de luz (2 = luz comum, 3 + n = ID 10200 + n)
#include "/lib/light_overrides.glsl"
uint voxelCodeFromId(int id) {
    if (id >= ID_RADIOACTIVE && id < ID_LIGHT_FIRST) id = radioactiveLightId(id);
    if (id >= ID_LIGHT_FIRST && id <= ID_LIGHT_LAST) return uint(3 + id - ID_LIGHT_FIRST);
    return 2u;
}
int idFromVoxelCode(uint c) { return c >= 3u ? ID_LIGHT_FIRST + int(c) - 3 : ID_EMISSIVE; }

// ---------- TAA: deslocamento sub-pixel da câmera (Halton 2,3; 8 posições) ----------
vec2 taaOffset() {
    int i = frameCounter % 8 + 1;
    vec2 h = vec2(0.0);
    float f = 0.5; for (int k = i; k > 0; k /= 2) { h.x += f * float(k % 2); f *= 0.5; }
    f = 1.0 / 3.0; for (int k = i; k > 0; k /= 3) { h.y += f * float(k % 3); f /= 3.0; }
    return (h - 0.5) * 2.0 / vec2(viewWidth, viewHeight); // em NDC
}
vec4 taaJitter(vec4 p) {
    #if AA_MODE == 2
    p.xy += taaOffset() * p.w;
    #endif
    return p;
}

// ---------- Vento nas folhas e plantas ----------
// Quanto cada vértice pode balançar (0 = preso): folhas inteiras; plantas só na ponta
// (topo da textura, v < mc_midTexCoord.v); plantas altas emendam as duas metades em 0,5.
float windAmount(int id, bool topVertex) {
    if (id == ID_LEAVES)    return 0.55;
    if (id == ID_PLANT)     return topVertex ? 1.0 : 0.0;
    if (id == ID_TALL_LOW)  return topVertex ? 0.5 : 0.0;
    if (id == ID_TALL_HIGH) return topVertex ? 1.0 : 0.5;
    return 0.0;
}
// Deslocamento em blocos (espaço do mundo). Duas partes:
//  - balanço: senoide lenta e suave, empurrada por rajadas que passam pelo terreno;
//  - tremor: soma de senoides rápidas com frequências que não se repetem, fase por vértice,
//    o que dá o movimento picado de folhas soltas.
// Na chuva e na tempestade o vento fica mais forte e o tremor mais rápido (sem saltos:
// o shader mistura um tremor calmo com um de tempestade em vez de acelerar o relógio).
vec3 windOffset(vec3 wp, float amount) {
    #ifndef WAVING_FOLIAGE
    return vec3(0.0);
    #else
    if (amount <= 0.0) return vec3(0.0);
    float t = frameTimeCounter * WIND_SPEED;
    float storm = clamp(rainStrength * 0.5 + thunderStrength, 0.0, 1.0);
    vec2 dir = normalize(vec2(1.0, 0.35));
    // rajadas: faixas largas que atravessam o terreno na direção do vento
    float gust = 0.5 + 0.5 * sin(dot(wp.xz, dir) * 0.045 - t * 0.55 + 1.7 * sin(t * 0.13));
    gust = mix(gust, 1.0, storm * 0.5);
    // balanço lento
    float swell = sin(t * 0.8 + dot(wp.xz, vec2(0.17, 0.06))) + 0.35 * sin(t * 1.9 + wp.x * 0.3);
    vec3 off = vec3(dir.x, 0.0, dir.y) * (swell * 0.5 + 0.6 * storm) * mix(0.04, 0.11, storm);
    // tremor picado (fase diferente em cada vértice)
    float ph = dot(wp, vec3(1.71, 2.33, 1.37));
    vec3 calm = vec3(sin(t * 3.1 + ph) * sin(t * 1.3 + ph * 0.7),
                     sin(t * 4.3 + ph * 1.3) * 0.5,
                     sin(t * 2.7 + ph * 0.9) * sin(t * 1.9 + ph * 1.1));
    vec3 wild = vec3(sin(t * 7.9 + ph) * sin(t * 3.3 + ph * 0.6),
                     sin(t * 9.7 + ph * 1.4) * 0.6,
                     sin(t * 6.1 + ph * 0.8) * sin(t * 4.7 + ph * 1.2));
    off += mix(calm, wild, storm) * mix(0.025, 0.07, storm) * (0.35 + 0.65 * gust);
    return off * amount * WIND_STRENGTH * (1.0 + 0.6 * rainStrength);
    #endif
}

#endif

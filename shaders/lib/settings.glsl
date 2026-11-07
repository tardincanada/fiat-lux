#ifndef SETTINGS_GLSL
#define SETTINGS_GLSL

// ---------- Sombras ----------
const int   shadowMapResolution = 2048; // [1024 2048 3072 4096]
const float shadowDistance      = 128.0; // [64.0 96.0 128.0 160.0 192.0 256.0]
const float shadowDistanceRenderMul = 1.0;
const float sunPathRotation     = -25.0; // [-40.0 -30.0 -25.0 -15.0 0.0 15.0 25.0 30.0 40.0]
#define SHADOW_DISTORT 0.85
#define SHADOW_SOFTNESS 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0]

// ---------- Iluminação ----------
#define SUN_BRIGHTNESS 3.0       // [1.5 2.0 2.5 3.0 3.5 4.0 5.0]
#define AMBIENT_STRENGTH 1.0     // [0.5 0.75 1.0 1.25 1.5 2.0]
#define AMBIENT_SKY_SCALE 2.2    // [1.0 1.5 2.0 2.2 2.6 3.0 3.5]
#define GROUND_BOUNCE 0.06       // [0.0 0.03 0.06 0.1 0.15]
#define BLOCKLIGHT_STRENGTH 1.0  // [0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define TORCH_R 1.00 // [0.60 0.70 0.80 0.90 1.00]
#define TORCH_G 0.65 // [0.30 0.40 0.50 0.55 0.60 0.65 0.70 0.80 0.90 1.00]
#define TORCH_B 0.40 // [0.10 0.15 0.20 0.25 0.30 0.40 0.50 0.70 1.00]
#define TORCH_FLICKER
#define HAND_LIGHT
#define COLORED_LIGHTS       // luz colorida no ambiente (cada lâmpada com sua cor); desligue em PCs fracos
// a luz colorida só liga se o Iris e a placa oferecerem imagens e compute shaders
#if defined COLORED_LIGHTS && defined IRIS_FEATURE_CUSTOM_IMAGES && defined IRIS_FEATURE_COMPUTE_SHADERS
#define COLORED_LIGHTS_ON
#endif
#define COLORED_LIGHT_RANGE 128 // [64 128] alcance do mapa de luz colorida, em blocos
#define ARC_FLICKER          // a luz do arco elétrico tremeluz
#define LPS_DESATURATION 1.0 // [0.0 0.25 0.5 0.75 1.0] quanto o sódio de baixa pressão apaga as cores
#define MIN_LIGHT 0.015          // [0.0 0.005 0.01 0.015 0.02 0.03 0.05]
#define EMISSIVE_STRENGTH 2.0    // [0.5 1.0 1.5 2.0 3.0 4.0]

// ---------- Água ----------
#define WATER_REFLECTIONS
#define WATER_REFRACTION
#define REFRACTION_STRENGTH 1.0  // [0.5 0.75 1.0 1.5 2.0]
#define SNELL_WINDOW
#define WAVING_FOLIAGE
#define WIND_STRENGTH 1.0   // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define WIND_SPEED 1.0      // [0.5 0.75 1.0 1.25 1.5]
#define WATER_WAVE_TYPE 1    // [0 1 2]
#define WATER_TYPE 5         // [0 1 2 3 4 5]
#define BRINE_STYLE 1        // [1 2]
#define WATER_ABSORPTION_SCALE 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define WATER_OPACITY 0.55   // [0.3 0.4 0.5 0.55 0.6 0.7 0.8]
#define WAVE_STRENGTH 1.0    // [0.0 0.25 0.5 0.75 1.0 1.5 2.0]
#define WAVE_SPEED 1.0       // [0.25 0.5 1.0 1.5 2.0]
#define SSR_STEPS 24         // [12 16 24 32 48]

// ---------- Cherenkov ----------
#define CHERENKOV_STRENGTH 0.8   // [0.2 0.4 0.6 0.8 1.0 1.5 2.0 3.0]
#define CHERENKOV_SPEED 2.0      // [0.0 0.5 1.0 2.0 3.0 5.0]
#define CHERENKOV_WATER_BOOST 1.3 // [1.0 1.15 1.3 1.5 2.0 2.5]

// ---------- Criaturas ----------
#define SLIME_TRANSLUCENT        // slime como uma célula: membrana translúcida, miolo visível
#define SLIME_OPACITY 0.30 // [0.15 0.20 0.30 0.40 0.50 0.65]  opacidade da membrana de frente (a borda é mais densa)
// mesma cor do mod (radiation.json: 70,140,255), em linear
#define CHERENKOV_COLOR vec3(0.061, 0.262, 1.0)

// ---------- Céu e nuvens por bioma ----------
#define BIOME_SKY
#define PROCEDURAL_CLOUDS
#define DRY_SKY_VIBRANCE 1.0   // [0.0 0.25 0.5 0.75 1.0 1.25 1.5]
#define SKY_BRIGHTNESS 1.0     // [0.6 0.8 1.0 1.2 1.4]
#define CLOUD_COVERAGE 0.45    // [0.15 0.25 0.35 0.45 0.55 0.65 0.75]
#define CLOUD_OPACITY 0.95     // [0.5 0.7 0.85 0.95 1.0]
#define CLOUD_SPEED 1.0        // [0.0 0.5 1.0 2.0 4.0]
#define OVERCAST_STRENGTH 0.85 // [0.0 0.25 0.5 0.7 0.85 1.0]
#define FOG_DENSE_STRENGTH 0.8 // [0.3 0.5 0.65 0.8 1.0]
#define FOG_HUMID_STRENGTH 0.5 // [0.0 0.25 0.5 0.75 1.0]  neblina da selva

// ---------- Altitude ----------
#define CLOUD_HEIGHT 192.0   // [128.0 160.0 192.0 224.0 256.0 320.0]
#define CIRRUS_HEIGHT 420.0  // [320.0 380.0 420.0 500.0 600.0]
#define CLOUD_LAYERS 3        // [1 3] camadas de nuvens baixas (1 = mais leve)
#define CLOUD_LAYER_GAP 40.0  // [24.0 32.0 40.0 56.0 72.0] distância entre as camadas, em blocos
#define CLOUD_RAIN_DROP 40.0  // [0.0 20.0 40.0 60.0] quanto a camada de baixo desce na chuva
#define CLOUD_BIOME_SHIFT 1.0 // [0.0 0.5 1.0 1.5] camada baixa mais baixa em bioma úmido, mais alta em bioma seco
#define AERIAL_PERSPECTIVE    // véu azulado sobre o terreno visto do alto
#define SKY_HAZE 1.0         // [0.0 0.25 0.5 0.75 1.0 1.25 1.5]
#define AERIAL_STRENGTH 1.0   // [0.5 0.75 1.0 1.5 2.0]
#define ALT_START 96.0       // [64.0 80.0 96.0 112.0 128.0 160.0]
#define ALT_FULL 256.0       // [160.0 192.0 224.0 256.0 320.0 384.0]
#define ALT_SKY_DEEPEN 1.0   // [0.0 0.25 0.5 0.75 1.0 1.25 1.5]
#define ALT_FOG_CLEAR 0.7    // [0.0 0.25 0.5 0.7 0.85 1.0]
#define ALT_SUN_BOOST 0.15   // [0.0 0.05 0.1 0.15 0.2 0.3]
#define RAIN_STYLE 1        // [0 1]  0 Minecraft, 1 realista
#define RAIN_OPACITY 1.0    // [0.5 0.75 1.0 1.25 1.5]
#define RAIN_SPEED 1.0      // [0.6 0.8 1.0 1.2 1.5]
#define SNOW_FOG 2.0        // [0.0 1.0 2.0 3.0 4.0]  quanto a neve fecha a visão a mais que a chuva
#define CLEAR_ABOVE_CLOUDS
#define HIGH_ALT_RANGE 128.0  // [64.0 96.0 128.0 160.0 192.0 256.0]
#define HIGH_ALT_DARKEN 1.0   // [0.0 0.25 0.5 0.75 1.0 1.25 1.5]

// ---------- Pós-processamento ----------
#define BLOOM_STRENGTH 1.0  // [0.0 0.25 0.5 0.75 1.0 1.5 2.0]
#define BLOOM_RADIUS 2.5    // [1.0 1.5 2.0 2.5 3.0 4.0]
#define EXPOSURE 1.0        // [0.6 0.8 1.0 1.2 1.4 1.6]
#define AA_MODE 2           // [0 1 2]  0 desligado, 1 FXAA, 2 TAA
#define TAA_SHARPEN 0.35    // [0.0 0.15 0.25 0.35 0.5 0.75 1.0]
#define TAA_BLEND 0.90      // [0.80 0.85 0.90 0.94]
#define SATURATION 0.80     // [0.50 0.60 0.70 0.75 0.80 0.85 0.90 1.00 1.10 1.20]

#endif

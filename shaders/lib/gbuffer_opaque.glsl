// G-buffer de objetos opacos: grava albedo/normal/lightmap/material.
// A iluminação acontece depois, em deferred.fsh.
#include "/lib/common.glsl"

uniform int currentRenderedItemId;

#ifdef VSH
in vec4 mc_Entity;
#ifdef PROGRAM_TERRAIN
in vec2 mc_midTexCoord;
#endif
out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 worldPos;
flat out int matId;
flat out vec2 cherenkov;
flat out int glowKind; // 1 = plasma do Tokamak, 2 = meteoro, 3 = foguete, 4 = escudo magnético, 5 = aniquilação
#ifdef PROGRAM_ENTITIES
uniform int entityId;
#endif
#ifdef PROGRAM_ENTITIES_TRANSLUCENT
flat out int isSlime;
out vec3 vViewPos;
#endif

void main() {
    gl_Position = taaJitter((gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex)));
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord  = clamp(lmcoord * 33.05 / 32.0 - 1.05 / 32.0, 0.0, 1.0);
    glcolor  = gl_Color;
    normal   = normalize(gl_NormalMatrix * gl_Normal);
    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    worldPos = viewToFeet(viewPos) + cameraPosition;
    #if defined PROGRAM_TERRAIN
    int id = int(mc_Entity.x + 0.5);
    #elif defined PROGRAM_ENTITIES || defined PROGRAM_HAND
    int id = currentRenderedItemId; // item.properties: itens radioativos na mão/no chão
    #else
    int id = 0;
    #endif
    #if defined PROGRAM_TERRAIN && defined WAVING_FOLIAGE
    // folhas e plantas ao vento (a mesma conta no shadow.vsh, para a sombra acompanhar)
    float wamt = windAmount(id, texcoord.y < mc_midTexCoord.y);
    if (wamt > 0.0) {
        vec3 wo = windOffset(worldPos, wamt);
        worldPos += wo;
        viewPos += mat3(gbufferModelView) * wo;
        gl_Position = taaJitter(gl_ProjectionMatrix * vec4(viewPos, 1.0));
    }
    #endif
    matId = idToMaterial(id);
    cherenkov = cherenkovLevels(id);
    glowKind = id == ID_FUSION_PLASMA ? 1 : (id == ID_SHIELD_AURORA ? 4 : (id == ID_ANNIHILATION ? 5 : 0));
    #ifdef PROGRAM_ENTITIES
    if (entityId == ID_METEOR) glowKind = 2;
    if (entityId == ID_ROCKET)  glowKind = 3;
    #endif
    #ifdef PROGRAM_ENTITIES_TRANSLUCENT
    isSlime = (entityId == ID_SLIME) ? 1 : 0;
    vViewPos = viewPos;
    #endif
}
#endif

#ifdef FSH
uniform sampler2D gtexture;
uniform vec4 entityColor;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 worldPos;
flat in int matId;
flat in vec2 cherenkov;
flat in int glowKind;
#ifdef PROGRAM_ENTITIES_TRANSLUCENT
flat in int isSlime;
in vec3 vViewPos;
#endif

/* RENDERTARGETS: 0,1,2,3,6 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outLight;
layout(location = 3) out vec4 outEmissive;
layout(location = 4) out vec4 outWetGlow;

void main() {
    vec4 albedo = texture(gtexture, texcoord) * glcolor;
    #ifdef PROGRAM_ENTITIES
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a); // flash vermelho de dano
    #endif
    if (albedo.a < 0.1) discard;
    float coverage = 1.0; // > 0 e < 1 só na membrana do slime (mistura no G-buffer)
    #if defined PROGRAM_ENTITIES_TRANSLUCENT && defined SLIME_TRANSLUCENT
    if (isSlime == 1) {
        // camada de fora do slime = membrana de uma célula: fina de frente, densa na borda
        // (como uma bolha vista de lado), deixando ver o miolo, os olhos e a boca por dentro.
        // A cor mistura com o que já está no G-buffer (o miolo); normal e lightmap ficam os
        // da membrana (blend desligado nesses buffers em shaders.properties).
        float ndv = abs(dot(normalize(normal), normalize(-vViewPos)));
        coverage = mix(SLIME_OPACITY, 0.92, pow(1.0 - ndv, 2.5));
        albedo.rgb = mix(albedo.rgb, albedo.rgb * 1.15 + vec3(0.03, 0.06, 0.02), 0.5); // membrana mais clara
    }
    #endif

    float lum = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
    vec3 emissive = vec3(0.0);
    int mat = matId;

    if (mat == MAT_EMISSIVE) {
        // só as partes claras da textura brilham (chama da tocha, miolo da lâmpada...)
        emissive = toLinear(albedo.rgb) * emissiveMask(albedo.rgb) * EMISSIVE_STRENGTH;
    }
    if (glowKind == 1) {
        // anel do Tokamak aceso: as partes rosadas/violeta da textura brilham como plasma quente
        float mx = max(albedo.r, max(albedo.g, albedo.b));
        float pink = smoothstep(0.08, 0.30, min(albedo.r, albedo.b) - albedo.g) * smoothstep(0.35, 0.8, mx);
        float pulse = 0.94 + 0.06 * sin(frameTimeCounter * 1.7 + dot(floor(worldPos + 0.001), vec3(1.3, 2.1, 1.7)));
        emissive = max(emissive, toLinear(lightSourceColor(ID_FUSION_PLASMA).rgb) * pink * pulse * EMISSIVE_STRENGTH * PLASMA_GLOW);
    }
    if (glowKind == 4) {
        // escudo magnético: o centro verde brilha como aurora, com um pulso lento (~3 s)
        float mx = max(albedo.r, max(albedo.g, albedo.b));
        float green = smoothstep(0.05, 0.25, albedo.g - max(albedo.r, albedo.b) * 0.85) * smoothstep(0.3, 0.7, mx);
        float pulse = 0.75 + 0.25 * sin(frameTimeCounter * 2.1);
        emissive = max(emissive, toLinear(lightSourceColor(ID_SHIELD_AURORA).rgb) * green * pulse * EMISSIVE_STRENGTH * EXOTIC_GLOW);
    }
    if (glowKind == 5) {
        // reator de aniquilação aceso: as partes claras brilham branco-azulado, duro e constante
        float mx = max(albedo.r, max(albedo.g, albedo.b));
        emissive = max(emissive, toLinear(lightSourceColor(ID_ANNIHILATION).rgb) * smoothstep(0.6, 0.9, mx) * EMISSIVE_STRENGTH * 1.5 * EXOTIC_GLOW);
    }
    if (glowKind == 2) {
        // meteoro: a rocha inteira em brasa branca, mais forte nas partes claras
        emissive = toLinear(lightSourceColor(ID_WHITE_HOT).rgb) * (0.6 + 0.8 * lum) * EMISSIVE_STRENGTH * METEOR_GLOW;
    }
    if (glowKind == 3) {
        // foguete: só as partes de cor de chama (laranja e amarelo saturados) brilham; a pintura não
        float mx = max(albedo.r, max(albedo.g, albedo.b));
        float mn = min(albedo.r, min(albedo.g, albedo.b));
        float sat = (mx - mn) / max(mx, 1e-4);
        // só laranja/amarelo bem claros (chama); a turbobomba pintada do motor de querosene (200,140,60) fica de fora
        float flame = smoothstep(0.88, 0.97, albedo.r) * smoothstep(0.5, 0.65, albedo.g) * smoothstep(0.45, 0.7, sat) * step(albedo.b, albedo.g);
        emissive = max(emissive, toLinear(mix(albedo.rgb, lightSourceColor(ID_FURNACE_GLOW).rgb, 0.4)) * flame * EMISSIVE_STRENGTH * ROCKET_GLOW);
    }
    vec3 wetGlow = vec3(0.0);
    if (mat == MAT_RADIOACTIVE) {
        // Cherenkov proporcional à radiação: x = intensidade no ar, y = na água (fórmula do mod)
        float phase = dot(floor(worldPos + 0.001), vec3(1.7, 3.1, 2.3));
        float pulse = 0.92 + 0.08 * sin(frameTimeCounter * CHERENKOV_SPEED * 0.5 + phase);
        vec3 glow = CHERENKOV_COLOR * CHERENKOV_STRENGTH * pulse * (0.35 + 0.65 * lum);
        emissive += glow * cherenkov.x;
        wetGlow = glow * max(cherenkov.y - cherenkov.x, 0.0); // o que a água acrescenta
        albedo.rgb = mix(albedo.rgb, albedo.rgb * vec3(0.7, 0.88, 1.15), 0.25 * max(cherenkov.x, cherenkov.y));
        mat = MAT_DEFAULT;
    }

    outAlbedo   = vec4(albedo.rgb, coverage);
    outNormal   = vec4(normalize(normal) * 0.5 + 0.5, 1.0);
    outLight    = vec4(lmcoord, float(mat) / 255.0, 1.0);
    outEmissive = vec4(emissive, coverage);
    outWetGlow  = vec4(wetGlow, coverage);
}
#endif

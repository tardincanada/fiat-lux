// Objetos desenhados depois do deferred (água, vidro, partículas, nuvens, chuva).
// São iluminados aqui mesmo e gravam cor linear (HDR) em colortex0.
#include "/lib/lighting.glsl"
#include "/lib/water.glsl"

#ifdef VSH
in vec4 mc_Entity;
out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 viewPos;
flat out int matId;
flat out float waterCls;
#ifdef PROGRAM_WEATHER
uniform sampler2D gtexture;
flat out float wRain;
#endif

void main() {
    gl_Position = taaJitter((gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex)));
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord  = clamp(lmcoord * 33.05 / 32.0 - 1.05 / 32.0, 0.0, 1.0);
    glcolor  = gl_Color;
    normal   = normalize(gl_NormalMatrix * gl_Normal);
    viewPos  = (gl_ModelViewMatrix * gl_Vertex).xyz;
    #ifdef PROGRAM_WEATHER
    // chuva x neve: cor média da textura inteira (chuva é azulada, neve é branca).
    // O Minecraft troca a textura por coluna, conforme a temperatura de cada lugar.
    vec4 acc = vec4(0.0);
    for (int y = 0; y < 32; y++) for (int x = 0; x < 8; x++) {
        vec4 s = textureLod(gtexture, vec2((float(x) + 0.5) / 8.0, (float(y) + 0.5) / 32.0), 0.0);
        acc += vec4(s.rgb * s.a, s.a);
    }
    vec3 avg = acc.rgb / max(acc.a, 1e-4);
    wRain = (acc.a > 0.0 && avg.b > avg.r * 1.12) ? 1.0 : 0.0;
    #endif
    #ifdef PROGRAM_WATER
    matId = idToMaterial(int(mc_Entity.x + 0.5));
    waterCls = waterClassFromId(int(mc_Entity.x + 0.5));
    #else
    waterCls = 0.0;
    matId = MAT_DEFAULT;
    #endif
}
#endif

#ifdef FSH
uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;
flat in int matId;
flat in float waterCls;
#ifdef PROGRAM_WEATHER
flat in float wRain;
#endif

#ifdef PROGRAM_WATER
/* RENDERTARGETS: 0,4 */
layout(location = 1) out vec4 outWater;
#elif defined PROGRAM_WEATHER
/* RENDERTARGETS: 8 */
// chuva e neve vão para uma camada própria, somada no composite DEPOIS da água e da
// neblina: assim não pegam a cor nem o reflexo da água, e o TAA sabe onde elas estão
#else
/* RENDERTARGETS: 0 */
#endif
layout(location = 0) out vec4 outColor;

void main() {
    #ifdef PROGRAM_BASIC
    vec4 albedo = glcolor;
    #else
    vec4 albedo = texture(gtexture, texcoord) * glcolor;
    #endif
    #if !(defined PROGRAM_WEATHER && RAIN_STYLE == 1)
    if (albedo.a < 0.01) discard; // a chuva realista desenha no quadrado inteiro
    #endif
    vec3 color = toLinear(albedo.rgb);

    #if defined PROGRAM_CLOUDS
        color *= getLightColor() * 0.45 + getAmbientColor() * 1.2 + 0.03;
    #elif defined PROGRAM_WEATHER
        // chuva e neve só existem abaixo da camada de nuvens mais alta
        vec3 wfeet = viewToFeet(viewPos);
        if (wfeet.y + cameraPosition.y > cloudTop()) discard;
        // o Minecraft só desenha a chuva num cilindro de ~10 blocos em volta do jogador:
        // apaga a borda do cilindro e o topo/fundo, para não aparecer faixa nem contorno
        float hr = length(wfeet.xz);
        float edge = (1.0 - smoothstep(5.0, 9.5, hr)) * (1.0 - smoothstep(5.0, 10.0, abs(wfeet.y)));
        edge *= smoothstep(0.4, 1.6, length(wfeet));                 // nada colado no rosto
        bool isRain = wRain > 0.5;
        #if RAIN_STYLE == 1
        if (isRain) {
            // traços finos e longos (gota borrada pelo movimento), queda própria a ~9 m/s
            vec3 wpos = wfeet + cameraPosition;
            vec2 toCol = normalize(wfeet.xz + vec2(1e-4));
            vec2 T = vec2(-toCol.y, toCol.x);
            vec2 cA = wpos.xz - (texcoord.x - 0.5) * T, cB = wpos.xz + (texcoord.x - 0.5) * T;
            vec2 eA = abs(fract(cA) - 0.5), eB = abs(fract(cB) - 0.5);
            vec2 col = floor(eA.x + eA.y < eB.x + eB.y ? cA : cB);   // coluna de chuva deste quadrado
            const float LANES = 7.0;
            float slant = 0.06;                                      // vento leve
            float u = texcoord.x * LANES + wpos.y * slant * LANES;
            float lane = floor(u);
            float h1 = fract(sin(dot(vec3(col, lane), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
            float h2 = fract(h1 * 157.31 + 0.37);
            float spd = 9.0 * RAIN_SPEED * mix(0.85, 1.15, h2);
            const float PERIOD = 7.0;                                // uma gota a cada 7 blocos por faixa
            float y = (wpos.y + frameTimeCounter * spd) / PERIOD + h1;
            float len = mix(0.9, 1.6, h2) / PERIOD;                  // 0,9 a 1,6 bloco de traço
            float fy = fract(y);
            float along = smoothstep(0.0, len * 0.35, fy) * (1.0 - smoothstep(len * 0.6, len, fy));
            float w = max(0.06, fwidth(u) * 0.75);                   // no mínimo ~1 pixel
            float across = 1.0 - smoothstep(w * 0.4, w, abs(fract(u) - 0.5));
            float a = along * across * step(0.25, h1 + 0.5 * h2);    // algumas faixas vazias
            if (a * edge < 0.004) discard;
            // a gota não tem cor própria: espalha a luz do céu (cinza esbranquiçado)
            color = (getAmbientColor() * 1.1 + getLightColor() * 0.12 + 0.015) * 1.4;
            albedo.a = clamp(a * edge * 0.22 * RAIN_OPACITY * glcolor.a * 2.0, 0.0, 1.0); // glcolor.a: entrada/saída da chuva
        } else {
            // flocos: pontos macios caindo devagar (~1,5 m/s), balançando de um lado para o outro
            vec3 wpos = wfeet + cameraPosition;
            const float LANES = 5.0;
            float t = frameTimeCounter;
            float laneF = texcoord.x * LANES;
            float lane = floor(laneF);
            float h0 = fract(sin(lane * 91.7 + floor(wpos.x) * 12.9898 + floor(wpos.z) * 78.233) * 43758.5453);
            float spd = 1.5 * RAIN_SPEED * mix(0.7, 1.3, h0);
            const float CELL = 1.1;                                  // um floco a cada ~1 bloco por faixa
            float yy = (wpos.y + t * spd) / CELL + h0;
            float cell = floor(yy);
            float h1 = fract(sin(dot(vec2(lane + h0 * 13.0, cell), vec2(12.9898, 78.233))) * 43758.5453);
            vec2 p = vec2(fract(laneF) - 0.5 - 0.25 * sin(t * 1.3 + h1 * 6.283 + cell), (fract(yy) - 0.5) * CELL * LANES);
            p.x -= (h1 - 0.5) * 0.4;
            float r = mix(0.035, 0.07, h1);                          // 0,7 a 1,4 cm (faixa = 1/5 de bloco)
            float px = max(fwidth(laneF), 1e-3);
            float flake = 1.0 - smoothstep(max(r - px, 0.0), max(r, px * 1.2), length(p));
            float a = flake * step(0.3, h1);
            a *= smoothstep(1.2, 3.0, length(wfeet));                // floco perto do olho vira borrão: some
            if (a * edge < 0.004) discard;
            color = getAmbientColor() * 1.6 + getLightColor() * 0.35 + 0.02;
            albedo.a = clamp(a * edge * 0.85 * RAIN_OPACITY * glcolor.a * 2.0, 0.0, 1.0);
        }
        #else
        {
            color *= getLightColor() * 0.15 + getAmbientColor() + 0.02;
            albedo.a *= edge;
            if (albedo.a < 0.01) discard;
        }
        #endif
    #elif defined PROGRAM_BASIC
        // linhas/contorno de seleção: sem iluminação
    #else
        vec3 n = normalize(normal);
        if (!gl_FrontFacing) n = -n;
        #ifdef PROGRAM_WATER
        vec4 waterData = vec4(0.0);
        if (matId == MAT_WATER) {
            vec3 geomWorld = mat3(gbufferModelViewInverse) * n;
            vec3 feet = viewToFeet(viewPos);
            if (abs(geomWorld.y) > 0.5) {
                float fp = length(fwidth(feet.xz)); // blocos por pixel (anti-moiré)
                vec3 wn = waterNormal(feet + cameraPosition, fp);
                wn.y *= sign(geomWorld.y);
                n = normalize(mat3(gbufferModelView) * wn);
            }
            #if WATER_TYPE == 0
            // clássica: cor da textura do Minecraft, semitransparente
            color = toLinear(albedo.rgb) * 0.8 * computeLighting(viewPos, n, lmcoord, MAT_DEFAULT);
            albedo.a = WATER_OPACITY;
            #else
            // a cor vem da absorção no composite: aqui a superfície é transparente
            color = vec3(0.0);
            albedo.a = 0.0;
            #endif
            waterData = vec4(encodeNormal(n), packWaterB(waterCls, lmcoord.y), 1.0);
        } else
        #endif
        {
            int lmat = MAT_FOLIAGE; // partículas/vidro: luz difusa sem normal confiável
            #if defined PROGRAM_TEXTURED && RAIN_STYLE == 1
            // respingo da chuva (textura azul do Minecraft): vira gotículas claras e discretas
            if (albedo.b > 0.45 && albedo.b > albedo.r * 1.5 && albedo.b > albedo.g * 1.25) {
                color = vec3(dot(color, vec3(0.2126, 0.7152, 0.0722)) * 0.4 + 0.55);
                albedo.a *= 0.35;
            }
            #endif
            #ifdef PROGRAM_WATER
            lmat = MAT_DEFAULT;
            #endif
            color = shadeSurface(color, viewPos, n, lmcoord, lmat);
        }
        #ifdef PROGRAM_WATER
        outWater = waterData;
        #endif
    #endif

    outColor = vec4(color, albedo.a);
}
#endif

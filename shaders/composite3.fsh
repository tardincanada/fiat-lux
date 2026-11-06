#version 330 compatibility
// TAA: junta a imagem deste quadro com o histórico reprojetado.
// A câmera se desloca menos de um pixel a cada quadro (taaJitter), então a
// média ao longo do tempo suaviza bordas, folhas, grades e linhas finas.
#include "/lib/common.glsl"
uniform sampler2D colortex0;
uniform sampler2D colortex7;
uniform sampler2D colortex8; // chuva e neve: pouca memória, senão deixam rastro
uniform sampler2D depthtex0;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
in vec2 texcoord;
/* RENDERTARGETS: 0,7 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outHistory;

// cores HDR comprimidas para a média não ser dominada por pontos muito claros
vec3 compressHdr(vec3 c) { return c / (1.0 + dot(c, vec3(0.2126, 0.7152, 0.0722))); }
vec3 expandHdr(vec3 c)   { return c / max(1.0 - dot(c, vec3(0.2126, 0.7152, 0.0722)), 1e-4); }
vec3 toYCoCg(vec3 c) { return vec3(0.25*c.r + 0.5*c.g + 0.25*c.b, 0.5*c.r - 0.5*c.b, -0.25*c.r + 0.5*c.g - 0.25*c.b); }
vec3 fromYCoCg(vec3 c) { return vec3(c.x + c.y - c.z, c.x + c.z, c.x - c.y - c.z); }

vec2 reproject(vec2 uv, float depth) {
    if (depth < 0.56) return uv; // mão do jogador: anda junto com a câmera
    vec4 v = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    v /= v.w;
    vec3 rel = (gbufferModelViewInverse * vec4(v.xyz, 1.0)).xyz;
    vec3 prevRel;
    if (depth >= 1.0) prevRel = (gbufferModelViewInverse * vec4(normalize(v.xyz), 0.0)).xyz; // céu: só gira
    else prevRel = rel + cameraPosition - previousCameraPosition;
    vec4 p = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(prevRel, depth >= 1.0 ? 0.0 : 1.0));
    return p.xy / p.w * 0.5 + 0.5;
}

void main() {
    vec3 cur = texture(colortex0, texcoord).rgb;
    #if AA_MODE == 2
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    // vizinhança 3x3: limites de cor aceitáveis para o histórico
    vec3 m1 = vec3(0.0), m2 = vec3(0.0), mn = vec3(1e9), mx = vec3(-1e9);
    float closest = 1.0;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        vec2 o = vec2(x, y) * px;
        vec3 c = toYCoCg(compressHdr(texture(colortex0, texcoord + o).rgb));
        m1 += c; m2 += c * c; mn = min(mn, c); mx = max(mx, c);
        closest = min(closest, texture(depthtex0, texcoord + o).r);
    }
    m1 /= 9.0;
    vec3 sigma = sqrt(max(m2 / 9.0 - m1 * m1, 0.0));
    vec3 lo = max(mn, m1 - 1.25 * sigma), hi = min(mx, m1 + 1.25 * sigma);

    vec2 prevUV = reproject(texcoord, closest); // ponto mais próximo: bordas não deixam rastro
    vec3 c0 = toYCoCg(compressHdr(cur));
    vec3 res = c0;
    if (all(greaterThanEqual(prevUV, vec2(0.0))) && all(lessThanEqual(prevUV, vec2(1.0)))) {
        vec3 hist = toYCoCg(compressHdr(texture(colortex7, prevUV).rgb));
        hist = clamp(hist, lo, hi);
        float motion = length((prevUV - texcoord) / px);
        float w = TAA_BLEND * mix(1.0, 0.85, clamp(motion / 8.0, 0.0, 1.0));
        w *= 1.0 - 0.85 * clamp(texture(colortex8, texcoord).a * 4.0, 0.0, 1.0);
        res = mix(c0, hist, w);
    }
    cur = max(expandHdr(fromYCoCg(res)), 0.0);
    #endif
    outColor = vec4(cur, 1.0);
    outHistory = vec4(cur, 1.0);
}

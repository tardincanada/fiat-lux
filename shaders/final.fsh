#version 330 compatibility
// Saída na tela: FXAA (AA_MODE 1), afiador leve depois do TAA (AA_MODE 2) ou nada.
#include "/lib/settings.glsl"
uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;
in vec2 texcoord;
layout(location = 0) out vec4 outColor;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 tap(vec2 uv) { return texture(colortex0, uv).rgb; }

#if AA_MODE == 1
// FXAA (versão compacta do 3.11 "qualidade"): acha a borda, mede até onde ela
// vai e mistura com o pixel do outro lado na proporção certa.
vec3 fxaa(vec2 uv, vec2 px) {
    vec3 rgbM = tap(uv);
    float lM = lum(rgbM);
    float lN = lum(tap(uv + vec2(0, px.y))), lS = lum(tap(uv - vec2(0, px.y)));
    float lE = lum(tap(uv + vec2(px.x, 0))), lW = lum(tap(uv - vec2(px.x, 0)));
    float lMin = min(lM, min(min(lN, lS), min(lE, lW)));
    float lMax = max(lM, max(max(lN, lS), max(lE, lW)));
    float range = lMax - lMin;
    if (range < max(0.0312, lMax * 0.125)) return rgbM;

    float lNE = lum(tap(uv + px)), lSW = lum(tap(uv - px));
    float lNW = lum(tap(uv + vec2(-px.x, px.y))), lSE = lum(tap(uv + vec2(px.x, -px.y)));
    float edgeH = abs(lNW + lNE - 2.0 * lN) + 2.0 * abs(lW + lE - 2.0 * lM) + abs(lSW + lSE - 2.0 * lS);
    float edgeV = abs(lNW + lSW - 2.0 * lW) + 2.0 * abs(lN + lS - 2.0 * lM) + abs(lNE + lSE - 2.0 * lE);
    bool horz = edgeH >= edgeV;

    float l1 = horz ? lS : lW, l2 = horz ? lN : lE;
    float g1 = abs(l1 - lM), g2 = abs(l2 - lM);
    float stp = horz ? px.y : px.x;
    float lLocal;
    if (g1 >= g2) { stp = -stp; lLocal = 0.5 * (l1 + lM); } else lLocal = 0.5 * (l2 + lM);
    float gScaled = 0.25 * max(g1, g2);

    vec2 cur = uv; if (horz) cur.y += 0.5 * stp; else cur.x += 0.5 * stp;
    vec2 off = horz ? vec2(px.x, 0) : vec2(0, px.y);
    vec2 p1 = cur - off, p2 = cur + off;
    float e1 = lum(tap(p1)) - lLocal, e2 = lum(tap(p2)) - lLocal;
    bool r1 = abs(e1) >= gScaled, r2 = abs(e2) >= gScaled;
    const float Q[10] = float[](1.0, 1.0, 1.0, 1.5, 2.0, 2.0, 2.0, 2.0, 4.0, 8.0);
    for (int i = 0; i < 10 && !(r1 && r2); i++) {
        if (!r1) { p1 -= off * Q[i]; e1 = lum(tap(p1)) - lLocal; r1 = abs(e1) >= gScaled; }
        if (!r2) { p2 += off * Q[i]; e2 = lum(tap(p2)) - lLocal; r2 = abs(e2) >= gScaled; }
    }
    float d1 = horz ? uv.x - p1.x : uv.y - p1.y;
    float d2 = horz ? p2.x - uv.x : p2.y - uv.y;
    bool near1 = d1 < d2;
    float dMin = min(d1, d2);
    bool lMSmaller = lM - lLocal < 0.0;
    bool good = ((near1 ? e1 : e2) < 0.0) != lMSmaller;
    float pixOff = good ? -dMin / (d1 + d2) + 0.5 : 0.0;

    float lAvg = (2.0 * (lN + lS + lE + lW) + lNE + lNW + lSE + lSW) / 12.0;
    float sub = clamp(abs(lAvg - lM) / range, 0.0, 1.0);
    sub = (-2.0 * sub + 3.0) * sub * sub;
    pixOff = max(pixOff, sub * sub * 0.75);

    vec2 fuv = uv; if (horz) fuv.y += pixOff * stp; else fuv.x += pixOff * stp;
    return tap(fuv);
}
#endif

void main() {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    #if AA_MODE == 1
    vec3 c = fxaa(texcoord, px);
    #elif AA_MODE == 2
    // afiador adaptativo: devolve a nitidez que a média do TAA tira, sem halo
    vec3 m = tap(texcoord);
    vec3 n = tap(texcoord + vec2(0, px.y)), s = tap(texcoord - vec2(0, px.y));
    vec3 e = tap(texcoord + vec2(px.x, 0)), w = tap(texcoord - vec2(px.x, 0));
    vec3 mn = min(m, min(min(n, s), min(e, w))), mx = max(m, max(max(n, s), max(e, w)));
    vec3 amp = sqrt(clamp(min(mn, 1.0 - mx) / max(mx, 1e-4), 0.0, 1.0));
    vec3 k = -amp * (TAA_SHARPEN * 0.2);
    vec3 c = clamp((m + (n + s + e + w) * k) / (1.0 + 4.0 * k), mn, mx);
    #else
    vec3 c = tap(texcoord);
    #endif
    outColor = vec4(c, 1.0);
}

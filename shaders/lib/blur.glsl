// Desfoque gaussiano em duas escalas (estreita + larga): o halo cai suavemente, sem borda.
vec3 blur1D(sampler2D tex, vec2 uv, vec2 dir) {
    vec3 a = vec3(0.0), b = vec3(0.0);
    float wa = 0.0;
    for (int i = -12; i <= 12; i++) {
        float w = exp(-float(i * i) / 50.0);
        a += texture(tex, uv + dir * float(i) * BLOOM_RADIUS).rgb * w;
        b += texture(tex, uv + dir * float(i) * BLOOM_RADIUS * 4.0).rgb * w;
        wa += w;
    }
    return (a * 0.6 + b * 0.4) / wa;
}

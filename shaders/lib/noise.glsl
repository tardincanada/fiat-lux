#ifndef NOISE_GLSL
#define NOISE_GLSL
float cloudHash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float cloudNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = cloudHash(i), b = cloudHash(i + vec2(1, 0));
    float c = cloudHash(i + vec2(0, 1)), d = cloudHash(i + vec2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p, int octaves) {
    const mat2 rot = mat2(0.8, -0.6, 0.6, 0.8);
    float s = 0.0, a = 0.5;
    for (int i = 0; i < octaves; i++) {
        s += a * cloudNoise(p);
        p = rot * p * 2.03 + 17.1;
        a *= 0.5;
    }
    return s / (1.0 - pow(0.5, float(octaves)));
}

#endif

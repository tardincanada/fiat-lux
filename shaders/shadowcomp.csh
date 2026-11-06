#version 430 compatibility
// Espalha a cor das lâmpadas pelo mapa 3D (um passo por quadro, alternando dois volumes).
// Só a COR vem daqui; a intensidade continua sendo a do lightmap do Minecraft.
#include "/lib/common.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
// o Iris lê workGroups como texto: precisa ser número literal, sem conta
#if COLORED_LIGHT_RANGE == 64
const ivec3 workGroups = ivec3(8, 4, 8);
#else
const ivec3 workGroups = ivec3(16, 8, 16);
#endif

uniform vec3 previousCameraPosition;
layout(r32ui) uniform readonly uimage3D voxelImg;
layout(rgba16f) uniform image3D floodImgA;
layout(rgba16f) uniform image3D floodImgB;

vec4 prevAt(ivec3 p) {
    if (any(lessThan(p, ivec3(0))) || any(greaterThanEqual(p, VOX_SIZE))) return vec4(0.0);
    return (frameCounter % 2 == 0) ? imageLoad(floodImgA, p) : imageLoad(floodImgB, p);
}

void main() {
    ivec3 p = ivec3(gl_GlobalInvocationID);
    // a grade acompanha a câmera em blocos inteiros: lê o quadro anterior no mesmo lugar do mundo
    ivec3 shift = ivec3(floor(cameraPosition)) - ivec3(floor(previousCameraPosition));
    uint code = imageLoad(voxelImg, p).r;

    vec4 outv = vec4(0.0);
    if (code >= 2u) {
        outv = lightSourceColor(idFromVoxelCode(code));
        outv.a *= max(outv.r, max(outv.g, outv.b));
    } else if (code == 0u) {
        ivec3 q = p + shift;
        vec4 s = prevAt(q + ivec3(1, 0, 0)) + prevAt(q - ivec3(1, 0, 0))
               + prevAt(q + ivec3(0, 1, 0)) + prevAt(q - ivec3(0, 1, 0))
               + prevAt(q + ivec3(0, 0, 1)) + prevAt(q - ivec3(0, 0, 1));
        outv = s / 6.0 * 0.995;
    }
    if (frameCounter % 2 == 0) imageStore(floodImgB, p, outv);
    else                       imageStore(floodImgA, p, outv);
}

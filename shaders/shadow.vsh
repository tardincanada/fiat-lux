#version 330 compatibility
#if defined IRIS_FEATURE_CUSTOM_IMAGES && defined IRIS_FEATURE_COMPUTE_SHADERS
#extension GL_ARB_shader_image_load_store : require
#endif
#include "/lib/shadows.glsl"
in vec4 mc_Entity;
in vec2 mc_midTexCoord;
uniform mat4 shadowModelViewInverse;
out vec2 texcoord;
out vec4 glcolor;
flat out int isWater;
uniform int entityId;
flat out int isSlime;

#ifdef COLORED_LIGHTS_ON
// Mapa 3D de blocos em volta da câmera, refeito a cada quadro (limpo pelo Iris antes da sombra).
// O espalhamento da cor fica no shadowcomp.csh.
in vec4 at_midBlock;          // centro do bloco (xyz * 64) e nível de luz que ele emite (w)
uniform int renderStage;
layout(r32ui) uniform uimage3D voxelImg;
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    int id = int(mc_Entity.x + 0.5);
    vec4 sView = gl_ModelViewMatrix * gl_Vertex;
    #ifdef WAVING_FOLIAGE
    float wamt = windAmount(id, texcoord.y < mc_midTexCoord.y);
    if (wamt > 0.0) {
        vec3 wfeet = mat3(shadowModelViewInverse) * sView.xyz + shadowModelViewInverse[3].xyz;
        sView.xyz += mat3(gl_ModelViewMatrix) * windOffset(wfeet + cameraPosition, wamt);
    }
    #endif
    gl_Position = gl_ProjectionMatrix * sView;
    gl_Position.xyz = distortShadow(gl_Position.xyz);
    isWater = (id >= ID_WATER && id <= ID_BRINE) ? 1 : 0;
    isSlime = (entityId == ID_SLIME) ? 1 : 0;

    #ifdef COLORED_LIGHTS_ON
    bool terrain = renderStage == MC_RENDER_STAGE_TERRAIN_SOLID || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT
                || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED || renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT;
    if (terrain && gl_VertexID % 4 == 0) {
        vec3 shadowView = (gl_ModelViewMatrix * gl_Vertex).xyz;
        vec3 feet = mat3(shadowModelViewInverse) * shadowView + shadowModelViewInverse[3].xyz;
        vec3 center = feet + at_midBlock.xyz / 64.0 + fract(cameraPosition);
        ivec3 v = ivec3(floor(center)) + VOX_SIZE / 2;
        if (all(greaterThanEqual(v, ivec3(0))) && all(lessThan(v, VOX_SIZE))) {
            uint code = 0u;
            bool emits = at_midBlock.w > 0.5 || (id >= ID_LIGHT_FIRST && id <= ID_LIGHT_LAST);
            if (emits) code = voxelCodeFromId(id);
            else if (renderStage == MC_RENDER_STAGE_TERRAIN_SOLID && !isFoliageId(id)) code = 1u;
            if (code > 0u) imageAtomicMax(voxelImg, v, code);
        }
    }
    #endif
}

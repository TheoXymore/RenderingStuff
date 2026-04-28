#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Binding 0 : color buffer
layout(rgba16f, set = 0, binding = 0) uniform image2D color_buffer;

// Binding 1 : wrinting buffer (temporary)
layout(rgba16f, set = 0, binding = 1) uniform image2D writing_buffer;

layout(push_constant) uniform PushConstants {
    mat4 inv_proj_mat;
    vec4 raster_size;
    float fisheye_strength;
    int mode;
} parameters;

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 img_size = imageSize(color_buffer);

    if (parameters.mode == 0) {
        if (pixel_coords.x >= img_size.x || pixel_coords.y >= img_size.y) return;

        // 1. Normaliser en [-1, 1], centré
        vec2 uv = (vec2(pixel_coords) + 0.5) / vec2(img_size) * 2.0 - 1.0;

        // 2. Corriger le ratio pour que le cercle soit rond
        float aspect = float(img_size.x) / float(img_size.y);
        uv.x *= aspect;

        // 3. Distorsion fisheye
        float r = length(uv);
        vec2 uv_distorted;

        if (r < 0.0001) {
            uv_distorted = uv; // centre : pas de distorsion
        } else {
            // atan compresse les grands rayons → effet fisheye
            float r_new = atan(r * parameters.fisheye_strength);
            uv_distorted = uv * (r / r_new);
        }

        // 4. Défaire la correction d'aspect
        uv_distorted.x /= aspect;

        // 5. Revenir en coordonnées pixel [0, img_size]
        vec2 src_uv = (uv_distorted + 1.0) * 0.5;
        ivec2 src_coords = ivec2(src_uv * vec2(img_size));

        // 6. Hors écran → noir (ou une couleur de bord)
        if (src_coords.x < 0 || src_coords.x >= img_size.x ||
            src_coords.y < 0 || src_coords.y >= img_size.y) {
            imageStore(writing_buffer, pixel_coords, vec4(0.0, 0.0, 0.0, 1.0));
            return;
        }

        // 7. Lire la couleur source et écrire en sortie
        vec4 color = imageLoad(color_buffer, src_coords);
        imageStore(writing_buffer, pixel_coords, color);

    }
    else if (parameters.mode == 1){
        vec4 color = imageLoad(writing_buffer, pixel_coords);
        imageStore(color_buffer,pixel_coords,color);
    }
}
#[compute]
#version 450 

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

// Binding 0 : color
layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

// Binding 1 : depth
layout(set = 0, binding = 1) uniform sampler2D depth_texture;

// Binding 2 : normal
layout(set = 0, binding = 2) uniform sampler2D normal_texture;


layout(push_constant) uniform PushConstants {
    mat4 inv_proj_mat;      
    vec2 raster_size;   
} parameters;



void main(){
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv_normalized = uv / parameters.raster_size;

    float raw_depth = texture(depth_texture, uv_normalized).r*3;

    imageStore(color_image,uv,vec4(raw_depth,raw_depth,raw_depth,1.0 )) ;
}
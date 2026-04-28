#[compute]
#version 450 

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

// Binding 0 : color
layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

// Binding 1 : depth
layout(set = 0, binding = 1) uniform sampler2D depth_texture;

// Binding 2 : normal
layout(set = 0, binding = 2) uniform sampler2D normal_texture;

// Binding 3 : writing buffer
layout(rgba16f, set = 0, binding = 3) uniform image2D writing_buffer;



layout(push_constant) uniform PushConstants {
    mat4 inv_proj_mat;      
    vec4 raster_size;
    int mode;
} parameters;

void main(){
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    ivec2 image_size = imageSize(color_image);

    // writing in the buffer
    if (parameters.mode == 0) {
        ivec2 uv_source = (uv * 4) % image_size;
        vec4 color = imageLoad(color_image, uv_source);
        imageStore(writing_buffer,uv,color) ;
    }

    // copying from the buffer to the image
    else if (parameters.mode == 1){
        vec4 color = imageLoad(writing_buffer, uv);
        imageStore(color_image,uv,color);
    }


    
}
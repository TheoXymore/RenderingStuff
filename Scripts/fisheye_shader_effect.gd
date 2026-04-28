@tool
extends CompositorEffect
class_name FisheyeShaderEffect


var shader_file : RDShaderFile = load("res://Shaders/fisheye.glsl")
@export var fisheye_strength:float = 2.0
		
var render:RenderingDevice = RenderingServer.get_rendering_device()
var shader: RID
var pipeline: RID
	

func _init() -> void:
	var shader_spirv = shader_file.get_spirv()
	shader = render.shader_create_from_spirv(shader_spirv)
	pipeline = render.compute_pipeline_create(shader)
	needs_normal_roughness = true

	
func _render_callback(effect_callback_type: int, render_data: RenderData) -> void:
	
	if not pipeline.is_valid():
		return
		
	# Access every rendering buffer used during processing
	var render_scene_buffers:RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	# The size of the image that will be given to the gpu
	var size = render_scene_buffers.get_internal_size()
	
	# Access the color layer buffer
	var color_layer_uniform = RDUniform.new()
	color_layer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	color_layer_uniform.binding = 0
	color_layer_uniform.add_id(render_scene_buffers.get_color_layer(0))
	
	# Creation of a writing buffer 
	var format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT #wtf
	var usage = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	
	var writing_buffer_rid = render_scene_buffers.create_texture(
		"fisheye_effect",
		"writing_buffer",
		format,
		usage,
		RenderingDevice.TEXTURE_SAMPLES_1,
		size,
		1,1,false,false
	)
	
	var writing_buffer_uniform = RDUniform.new()
	writing_buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	writing_buffer_uniform.binding = 1
	writing_buffer_uniform.add_id(writing_buffer_rid)
	
	# Setup the bindings = the datas given to the compute shader
	var bindings:Array[RDUniform] = [
		color_layer_uniform,
		writing_buffer_uniform
	]
	
	# How many process will be created ?
	var groups = Vector3i(size.x,size.y,1)
	# The way to give the data to the gpu
	var uniform_set = render.uniform_set_create(bindings,shader,0)
	
	# Setup a list of computations that the GPU will execute
	var compute_list = render.compute_list_begin()
	
	render.compute_list_bind_compute_pipeline(compute_list,pipeline)
	render.compute_list_bind_uniform_set(compute_list,uniform_set,0)
	# First step : writing in the buffer
	var push_constant_0 = get_push_constants(render_data,size,0)
	render.compute_list_set_push_constant(compute_list,push_constant_0,push_constant_0.size())
	render.compute_list_dispatch(compute_list,groups.x,groups.y,groups.z)
	
	# barrier
	render.compute_list_add_barrier(compute_list)

	# Second step : copying in the color buffer
	var push_constant_1 = get_push_constants(render_data,size,1)
	render.compute_list_set_push_constant(compute_list,push_constant_1,push_constant_1.size())
	render.compute_list_dispatch(compute_list,groups.x,groups.y,groups.z)
	
	render.compute_list_end()
	
	render.free_rid(uniform_set)
	
	
	
func get_push_constants(render_data: RenderData, size: Vector2i, mode : int)-> PackedByteArray:
	# matrix (64 bytes)
	var inv_proj_mat = render_data.get_render_scene_data().get_cam_projection().inverse()
	var inv_proj_mat_array = PackedVector4Array([
		inv_proj_mat.x,inv_proj_mat.y,inv_proj_mat.z,inv_proj_mat.w
	])
	
	# size (16 bytes)
	var raster_size = PackedFloat32Array([size.x,size.y,0.0,0.0])
	
	# float + int + padding → 16 bytes (encodage manuel)
	var last_block = PackedByteArray()
	last_block.resize(16)
	last_block.encode_float(0, fisheye_strength)
	last_block.encode_s32(4, mode)
	
	var bytes = inv_proj_mat_array.to_byte_array()
	bytes.append_array(raster_size.to_byte_array())
	bytes.append_array(last_block)
	
	return bytes
	
	
	
	
	
	
	

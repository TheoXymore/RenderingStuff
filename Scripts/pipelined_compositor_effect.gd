@tool
extends CompositorEffect
class_name PipelinedCompositorEffect

@export var shader_file : RDShaderFile:
	set(value):
		shader_file = value
		update_shader()
		
@export var steps : Array[CompositionStep]:
	set(value):
		#Disconnect all the signals of the old array
		for step in steps :
			if step.updated.is_connected(update_step):
				step.updated.disconnect(update_step)
				
		#Update the array
		steps = value
		
		#Connect every signal of the new array
		for step in steps:
			step.updated.connect(update_step)			
		
var rd:RenderingDevice = RenderingServer.get_rendering_device()
var shader: RID
var shaders:Array[RID]
var pipeline: RID

var depth_sampler: RID
var normal_sampler: RID

func update_step(step:CompositionStep)->void:
	pass
		
func update_shader()->void:	
	if not rd : 
		return
		
	if not shader_file:
		if pipeline :
			rd.free_rid(pipeline)
		pipeline = RID()
		return
		
	#clean the old shader
	if shader.is_valid() :
		rd.free_rid(shader)
		shader = RID()


	var shader_spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

func _init() -> void:
	update_shader()
	
	depth_sampler = rd.sampler_create(RDSamplerState.new())
	normal_sampler = rd.sampler_create(RDSamplerState.new())
	
	needs_normal_roughness = true
	
	
func _render_callback(effect_callback_type: int, render_data: RenderData) -> void:
	
	if not pipeline.is_valid():
		return
		
	# Access every rendering buffer used during processing
	var render_scene_buffers:RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	# The size of the image that will be given to the gpu
	var size = render_scene_buffers.get_internal_size()
	
	var inv_proj_mat = render_data.get_render_scene_data().get_cam_projection().inverse()
	var inv_proj_mat_array = PackedVector4Array([
		inv_proj_mat.x,inv_proj_mat.y,inv_proj_mat.z,inv_proj_mat.w
	])
	var raster_size = PackedFloat32Array([size.x,size.y,0.0,0.0])
	var push_constant = inv_proj_mat_array.to_byte_array()
	push_constant.append_array(raster_size.to_byte_array())
		
	# Access the color layer buffer
	var color_layer_uniform = RDUniform.new()
	color_layer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	color_layer_uniform.binding = 0
	color_layer_uniform.add_id(render_scene_buffers.get_color_layer(0))
	
	# Access the Depth layer buffer
	var depth_layer_uniform = RDUniform.new()
	depth_layer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	depth_layer_uniform.binding = 1
	depth_layer_uniform.add_id(depth_sampler)
	depth_layer_uniform.add_id(render_scene_buffers.get_depth_layer(0))
	
	# Access the Normal layer buffer
	var normal_layer_uniform = RDUniform.new()
	normal_layer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	normal_layer_uniform.binding = 2
	normal_layer_uniform.add_id(normal_sampler)
	normal_layer_uniform.add_id(render_scene_buffers.get_texture(
		"forward_clustered", "normal_roughness"
	))
	
	# Setup the bindings = the datas given to the compute shader
	var bindings:Array[RDUniform] = [
		color_layer_uniform,
		depth_layer_uniform,
		normal_layer_uniform
	]
	
	# How many process will be created ?
	var groups = Vector3i(size.x,size.y,1)
	# The way to give the data to the gpu
	var uniform_set = rd.uniform_set_create(bindings,shader,0)
	
	# Setup a list of computations that the GPU will execute
	var compute_list = rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(compute_list,pipeline)
	rd.compute_list_bind_uniform_set(compute_list,uniform_set,0)
	rd.compute_list_set_push_constant(compute_list,push_constant,push_constant.size())
	rd.compute_list_dispatch(compute_list,groups.x,groups.y,groups.z)
	rd.compute_list_end()
	
	rd.free_rid(uniform_set)
	
	
	
	
	
	
	
	

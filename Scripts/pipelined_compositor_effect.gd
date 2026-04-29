@tool
extends CompositorEffect
class_name PipelinedCompositorEffect
		
@export var steps : Array[CompositionStep]:
	set(value):
		#Disconnect all the signals of the old array
		for step in steps :
			if step != null and step.is_valid and step.updated.is_connected(update_step):
				step.updated.disconnect(update_step)
				
		#Update the array
		steps = value
		
		#Connect every signal of the new array
		for step in steps:
			if step != null and step.is_valid:
				step.updated.connect(update_step)	
		
var rd:RenderingDevice
var pipeline: RID


var depth_sampler: RID
var normal_sampler: RID

func update_step(step:CompositionStep)->void:
	#If no RenderingDevice : abort mission
	if not rd : 
		return 
	
	#If there is not a single valid shader, we clear the pipeline
	if steps.all(func(x):!x.is_valid):
		if pipeline :
			rd.free_rid(step.pipeline)
		step.pipeline = RID()
		return
		
	#clean the old shader
	if step.shader.is_valid() :
		rd.free_rid(step.shader)
		step.shader = RID()
		
	var shader_spirv = step.shader_file.get_spirv()
	step.shader = rd.shader_create_from_spirv(shader_spirv)
	step.pipeline = rd.compute_pipeline_create(step.shader)

func _init() -> void:
	
	for step in steps:
		update_step(step)
	
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	needs_normal_roughness = true
	rd = RenderingServer.get_rendering_device()
	
	depth_sampler = rd.sampler_create(RDSamplerState.new())
	normal_sampler = rd.sampler_create(RDSamplerState.new())
	
	
	
func _render_callback(effect_callback_type: int, render_data: RenderData) -> void:
	if not pipeline.is_valid():
		print("Aie aie aie")
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
	
	var color_rid = render_scene_buffers.get_color_layer(0)
	
	var ping_rid = get_buffer(render_scene_buffers,"ping_buffer",size)
	var pong_rid = get_buffer(render_scene_buffers,"pong_buffer",size)
	
	var current_input_rid = color_rid
	var current_output_rid = ping_rid
	
	# Access the Depth layer buffer
	var depth_layer_uniform = RDUniform.new()
	depth_layer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	depth_layer_uniform.binding = 2
	depth_layer_uniform.add_id(depth_sampler)
	depth_layer_uniform.add_id(render_scene_buffers.get_depth_layer(0))
	
	# Access the Normal layer buffer
	var normal_layer_uniform = RDUniform.new()
	normal_layer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	normal_layer_uniform.binding = 3
	normal_layer_uniform.add_id(normal_sampler)
	normal_layer_uniform.add_id(render_scene_buffers.get_texture(
		"forward_clustered", "normal_roughness"
	))
	
	# How many process will be created ?
	var groups = Vector3i(size.x,size.y,1)

	# Setup a list of computations that the GPU will execute
	var compute_list = rd.compute_list_begin()
	var uniform_sets:Array[RID]
	
	for step_index in range(steps.size()):
		
		var input_uniform = RDUniform.new()
		input_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		input_uniform.binding = 0
		input_uniform.add_id(current_input_rid)
		
		var output_uniform = RDUniform.new()
		output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		output_uniform.binding = 1
		output_uniform.add_id(current_output_rid)
		
		var bindings: Array[RDUniform] = [
			input_uniform,
			output_uniform,
			depth_layer_uniform,
			normal_layer_uniform
		]
		
		var uset = rd.uniform_set_create(bindings,steps[step_index].shader,0)
		uniform_sets.append(uset)
	
		rd.compute_list_bind_compute_pipeline(compute_list,steps[step_index].pipeline)
		rd.compute_list_bind_uniform_set(compute_list,uniform_sets[step_index],step_index)
		rd.compute_list_set_push_constant(compute_list,push_constant,push_constant.size())
		rd.compute_list_dispatch(compute_list,groups.x,groups.y,groups.z)
		
		rd.compute_list_add_barrier(compute_list)
		
		current_input_rid = current_output_rid
		
		if current_input_rid == ping_rid :
			current_output_rid = pong_rid
		else :
			current_output_rid = ping_rid
		
	rd.compute_list_end()
	
	rd.texture_copy(current_input_rid, render_scene_buffers.get_color_layer(0), Vector3(0,0,0), Vector3(0,0,0), Vector3(size.x, size.y, 1), 0, 0, 0, 0)
	
	for uniform_set in uniform_sets:
		rd.free_rid(uniform_set)
	
func get_buffer(render_scene_buffers,buffer_name,size)->RID:
	var buffer_rid = render_scene_buffers.get_texture("pipeline_compositor",buffer_name,size)
	if not buffer_rid.is_valid():
		# Creation of a writing buffer 
		var format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		var usage = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	
		buffer_rid = render_scene_buffers.create_texture(
		"pipeline_compositor",
		buffer_name,
		format,
		usage,
		RenderingDevice.TEXTURE_SAMPLES_1,
		size,
		1,1,false,false
	)
	return buffer_rid
	
	
	
	
	
	
	

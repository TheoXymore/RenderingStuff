extends Resource
class_name CompositionStep

signal updated

@export var shader_file: RDShaderFile:
	set(value):
		shader_file = value
		updated.emit(self)
		
var shader: RID

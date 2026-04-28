@tool
extends Resource
class_name CompositionStep

signal updated

@export var shader_file: RDShaderFile:
	set(value):
		shader_file = value
		is_valid = !(shader_file == null)
		updated.emit(self)
		
var shader : RID
var pipeline : RID
var is_valid :bool = false

func update()->void:
	pass

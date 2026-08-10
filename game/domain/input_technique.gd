class_name InputTechniqueContract
extends RefCounted

enum Value { TONE, DING, SLAP }

static func count() -> int:
	return Value.size()

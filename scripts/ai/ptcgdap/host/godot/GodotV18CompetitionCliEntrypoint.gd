extends SceneTree

## Development/editor host for the scene-owned competition entrypoint.
## Exported Linux Server builds start the .tscn directly and do not rely on
## export-template support for the --script option.

const CompetitionEntrypointScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/GodotV18CompetitionEntrypoint.gd"
)


func _init() -> void:
	call_deferred("_start")


func _start() -> void:
	root.add_child(CompetitionEntrypointScript.new())

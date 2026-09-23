"""Create an isolated Godot project from the approved frost concept."""

from pathlib import Path
import shutil

SOURCE = Path(__file__).resolve().parent.parent
ROOT = SOURCE.parents[3]
TARGET = ROOT / "build/godot/frost-charge-benchmark"
TARGET.mkdir(parents=True, exist_ok=True)

for name in ("concept.gd", "charge.gdshader", "mist.gdshader", "mist-volume.glb"):
    shutil.copy2(SOURCE / name, TARGET / name)
shutil.copy2(ROOT / "assets/images/stage1_3d/turrets/frost.glb", TARGET / "frost.glb")
shutil.copy2(ROOT / "assets/images/stage1_3d/enemies/normal.glb", TARGET / "enemy.glb")
shutil.copy2(Path(__file__).parent / "benchmark.gd", TARGET / "benchmark.gd")
shutil.copy2(SOURCE / "main.tscn", TARGET / "concept.tscn")
(TARGET / "main.tscn").write_text(
    '[gd_scene load_steps=2 format=3]\n'
    '[ext_resource type="Script" path="res://benchmark.gd" id="1"]\n'
    '[node name="FrostBenchmark" type="Node3D"]\n'
    'script=ExtResource("1")\n'
)
(TARGET / "project.godot").write_text(
    'config_version=5\n'
    '[application]\n'
    'config/name="Frost charge benchmark"\n'
    'run/main_scene="res://main.tscn"\n'
    'config/use_custom_user_dir=true\n'
    'config/custom_user_dir_name="RuneNexus-frost-charge-benchmark"\n'
    '[display]\n'
    'window/size/viewport_width=1100\n'
    'window/size/viewport_height=800\n'
    '[rendering]\n'
    'renderer/rendering_method="mobile"\n'
    'textures/default_filters/use_nearest_mipmap_filter=false\n'
)
print(TARGET)

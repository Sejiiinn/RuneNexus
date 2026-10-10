"""Materialize the immutable authored source after the game asset is replaced."""
from pathlib import Path
import hashlib
import subprocess
OUT = Path(__file__).resolve().parents[1]
ROOT = OUT.parents[3]
SOURCE_REVISION = "d83e73f32ee59112505b7e00c9222c4b774b0ef8"
SOURCE_PATH = "assets/images/stage1_3d/turrets/frost.glb"
SOURCE_SHA256 = "7d71195e972710488c6912d68b1f3d5eb54ee38adf31f9a524788a8d1d3aee39"
def materialize_original():
    target = OUT / "checks/source/frost-original-47912.glb"
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == SOURCE_SHA256:
        return target
    result = subprocess.run(["git", "-C", str(ROOT), "show", f"{SOURCE_REVISION}:{SOURCE_PATH}"], capture_output=True)
    if result.returncode:
        raise RuntimeError("Original Git revision is required; fetch its history before reproducing frost")
    assert hashlib.sha256(result.stdout).hexdigest() == SOURCE_SHA256, "Original source hash differs"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(result.stdout)
    return target
if __name__ == "__main__":
    print(materialize_original())

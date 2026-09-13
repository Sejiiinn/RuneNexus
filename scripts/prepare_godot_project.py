#!/usr/bin/env python3
"""공용 Godot 소스와 기존 스테이지 1 자산을 빌드 디렉터리에 준비한다."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import struct


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "godot"
PROJECT = ROOT / "build/godot/project"
ASSETS = PROJECT / "assets"
SOURCE_ASSETS = ROOT / "assets/images/stage1_3d"
TURRET_TYPES = ("arrow", "cannon", "magic", "frost", "sniper", "lightning")
ENEMY_TYPES = ("normal", "armored", "shielded", "fast", "tank", "boss")


def prepare() -> Path:
    if not (SOURCE / "project.godot").is_file():
        raise RuntimeError("루트 godot/ 공용 프로젝트를 찾을 수 없습니다.")
    required = [SOURCE_ASSETS / "environment" / name for name in ("terrain.glb", "dressing.glb")]
    required += [SOURCE_ASSETS / "turrets" / f"{name}.glb" for name in TURRET_TYPES]
    required += [SOURCE_ASSETS / "enemies" / f"{name}.glb" for name in ENEMY_TYPES]
    required += [SOURCE_ASSETS / "effects" / name
                 for name in ("machinegun_muzzle.glb", "machinegun_muzzle_noise.bin")]
    for path in required:
        if not path.is_file():
            raise RuntimeError(f"필수 3D 자산 누락: {path.relative_to(ROOT)}")

    shutil.copytree(SOURCE, PROJECT, dirs_exist_ok=True, ignore=shutil.ignore_patterns(".godot"))
    # 삭제된 검수·런타임 스크립트가 이전 빌드에 남지 않도록 소스 파일만 동기화.
    for suffix in ("*.gd", "*.gdshader", "*.tscn"):
        for path in PROJECT.rglob(suffix):
            relative = path.relative_to(PROJECT)
            if relative.parts[0] not in (".godot", "assets") and not (SOURCE / relative).exists():
                path.unlink()
    ASSETS.mkdir(parents=True, exist_ok=True)
    for source in sorted(SOURCE_ASSETS.rglob("*.glb")):
        target = ASSETS / source.relative_to(SOURCE_ASSETS)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    ui_target = ASSETS / "ui"
    ui_target.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE_ASSETS / "ui/turret_levels.png", ui_target / "turret_levels.png")
    for filename in ("muzzle_flash.png", "gun_smoke.png"):
        target = ASSETS / "effects" / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SOURCE_ASSETS / "effects" / filename, target)
    for filename in ("cannon_field.json", "cannon_field.bin", "machinegun_muzzle_noise.bin"):
        shutil.copy2(SOURCE_ASSETS / "effects" / filename, ASSETS / filename)

    # 같은 빌드의 GLB에서 추출: Godot importer의 extras 보존 여부에 의존하지 않음.
    glb = (ASSETS / "environment/terrain.glb").read_bytes()
    magic, version, total_length = struct.unpack_from("<III", glb)
    json_length, chunk_type = struct.unpack_from("<II", glb, 12)
    if magic != 0x46546C67 or version != 2 or total_length != len(glb) or chunk_type != 0x4E4F534A:
        raise RuntimeError("스테이지 1 지형 GLB의 헤더 형식이 맞지 않습니다.")
    document = json.loads(glb[20:20 + json_length])
    authored = next(node for node in document["nodes"] if node.get("name") == "stage1_environment")["extras"]
    (ASSETS / "terrain_manifest.json").write_text(json.dumps(authored, ensure_ascii=False) + "\n")
    columns, rows = authored["columns"], authored["rows"]
    tiles = authored["tileTypes"]
    path = [(index % columns + .5, index // columns + .5) for index, tile in enumerate(tiles) if tile == "path"]
    targets = sorted(path, key=lambda point: (point[0] - columns / 2) ** 2 + (point[1] - rows / 2) ** 2)[:3]
    build = [(index % columns + .5, index // columns + .5) for index, tile in enumerate(tiles) if tile == "build"]
    build.sort(key=lambda point: (point[0] - targets[0][0]) ** 2 + (point[1] - targets[0][1]) ** 2)
    # 단독 네이티브 검수만 사용. Android 본게임은 Flutter의 실제 전투 프레임을 받음.
    frame = {
        "seq": 0, "time": 0,
        "map": {"columns": columns, "rows": rows, "tiles": tiles},
        "turrets": [[index, x, z, 0, 0, 0, "cannon", 1] for index, (x, z) in enumerate(build[:6])],
        "enemies": [[index + 10, x, z, 0, 0, 1.25, 0, "tank", False, False, False, False]
                    for index, (x, z) in enumerate(targets)],
        "projectiles": [], "impacts": [], "buildPreview": None,
    }
    (ASSETS / "preview_frame.json").write_text(json.dumps(frame) + "\n")
    (PROJECT.parent / "android-assets").mkdir(parents=True, exist_ok=True)
    return PROJECT


if __name__ == "__main__":
    print(prepare())

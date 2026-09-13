#!/usr/bin/env python3
"""공용 Godot 소스와 기존 스테이지 1 자산을 빌드 디렉터리에 준비한다."""
from __future__ import annotations

import json
from pathlib import Path
import re
import shutil
import struct


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "godot"
PROJECT = ROOT / "build/godot/project"
ASSETS = PROJECT / "assets"
SOURCE_ASSETS = ROOT / "assets/images/stage1_3d"
TURRET_TYPES = ("arrow", "cannon", "magic", "frost", "sniper", "lightning")
ENEMY_TYPES = ("normal", "armored", "shielded", "fast", "tank", "boss")
# Godot 4.7 GLTFDocument는 ImporterMesh 이름에 원본 glTF scene 이름을 앞붙인다.
FOLIAGE_IMPORT_ID = "Dressing Export (temporary)_stage1_dressing_foliage"


def _preserve_foliage_geometry() -> None:
    # 실제 식생의 잎과 투영 차폐를 유지한다. 같은 GLB의 바위 LOD는 그대로 둔다.
    path = ASSETS / "environment/dressing.glb.import"
    contents = path.read_text() if path.exists() else '[remap]\n\nimporter="scene"\n\n[params]\n'
    match = re.search(r"^_subresources=", contents, flags=re.MULTILINE)
    if match:
        start = match.end()
        while contents[start].isspace():
            start += 1
        # 현재 Godot sidecar의 기본 Dictionary는 JSON 호환 값이다.
        # 읽지 못하는 확장 값은 덮어쓰지 않고 준비를 중단한다.
        subresources, length = json.JSONDecoder().raw_decode(contents[start:])
    else:
        subresources = {}
    meshes = subresources.setdefault("meshes", {})
    # 이전 준비에서 쓴 GLB 원명은 실제 import_id가 아니므로 우리 무효 옵션만 제거한다.
    legacy = meshes.get("stage1_dressing_foliage")
    if legacy == {"generate/lods": 2}:
        del meshes["stage1_dressing_foliage"]
    mesh_options = meshes.setdefault(FOLIAGE_IMPORT_ID, {})
    # Godot ResourceImporterScene: generate/lods = Default(0), Enable(1), Disable(2).
    mesh_options["generate/lods"] = 2
    value = json.dumps(subresources, ensure_ascii=False, indent=2)
    if match:
        contents = contents[:start] + value + contents[start + length:]
    elif "[params]" in contents:
        contents = contents.replace("[params]", "[params]\n\n_subresources=" + value, 1)
    else:
        contents += "\n[params]\n\n_subresources=" + value + "\n"
    path.write_text(contents)


def _remove_retired_fern_shadow() -> None:
    # 기존 빌드의 source/import와 이 에셋에 속하는 캐시만 제거한다.
    for name in ("fern_shadow.glb", "fern_shadow.glb.import"):
        (ASSETS / "environment" / name).unlink(missing_ok=True)
    for path in (PROJECT / ".godot/imported").glob("fern_shadow.glb-*"):
        if path.is_file():
            path.unlink()
    for name in ("fern_shadow.gdshader.uid", "fern_shadow_outline.gdshaderinc.uid"):
        (PROJECT / "environment" / name).unlink(missing_ok=True)


def prepare() -> Path:
    if not (SOURCE / "project.godot").is_file():
        raise RuntimeError("루트 godot/ 공용 프로젝트를 찾을 수 없습니다.")
    required = [SOURCE_ASSETS / "environment" / name for name in ("terrain.glb", "dressing.glb", "landmarks.glb")]
    required += [SOURCE_ASSETS / "turrets" / f"{name}.glb" for name in TURRET_TYPES]
    required += [SOURCE_ASSETS / "enemies" / f"{name}.glb" for name in ENEMY_TYPES]
    required += [SOURCE_ASSETS / "effects" / name
                 for name in ("machinegun_muzzle.glb", "machinegun_muzzle_noise.bin")]
    for path in required:
        if not path.is_file():
            raise RuntimeError(f"필수 3D 자산 누락: {path.relative_to(ROOT)}")

    shutil.copytree(SOURCE, PROJECT, dirs_exist_ok=True, ignore=shutil.ignore_patterns(".godot"))
    # 삭제된 스크립트·장면·재질 프리셋이 이전 빌드에 남지 않도록 소스만 동기화.
    for suffix in ("*.gd", "*.gdshader", "*.gdshaderinc", "*.tscn", "*.tres"):
        for path in PROJECT.rglob(suffix):
            relative = path.relative_to(PROJECT)
            if relative.parts[0] not in (".godot", "assets") and not (SOURCE / relative).exists():
                path.unlink()
    ASSETS.mkdir(parents=True, exist_ok=True)
    _remove_retired_fern_shadow()
    for source in sorted(SOURCE_ASSETS.rglob("*.glb")):
        # 과거 생성기를 실행해 파일이 다시 생겨도 폐기한 외피는 패키징하지 않는다.
        if source.relative_to(SOURCE_ASSETS) == Path("environment/fern_shadow.glb"):
            continue
        target = ASSETS / source.relative_to(SOURCE_ASSETS)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    ui_target = ASSETS / "ui"
    ui_target.mkdir(parents=True, exist_ok=True)
    for source in sorted((SOURCE_ASSETS / "ui").rglob("*")):
        if source.is_file() and source.suffix in (".png", ".ttf", ".txt"):
            target = ui_target / source.relative_to(SOURCE_ASSETS / "ui")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    shutil.copy2(ROOT / "assets/images/diamond_currency.png", ui_target / "diamond_currency.png")
    shutil.copy2(ROOT / "assets/fonts/NotoSansKR-VF.ttf", ui_target / "NotoSansKR-VF.ttf")
    _preserve_foliage_geometry()
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

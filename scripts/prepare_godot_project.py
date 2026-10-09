#!/usr/bin/env python3
"""공용 Godot 소스와 기존 스테이지 1 자산을 빌드 디렉터리에 준비한다."""
from __future__ import annotations

import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct

from prepare_shared_gltf_textures import externalize_textures
from content_compiler import check_generated
from content_runtime_format import load_compiled_content
from compile_progression import compile_progression


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "godot"
PROJECT = ROOT / "build/godot/project"
ASSETS = PROJECT / "assets"
SOURCE_ASSETS = ROOT / "assets/images/stage1_3d"
TURRET_TYPES = ("arrow", "cannon", "magic", "frost", "sniper", "lightning")
ENEMY_TYPES = ("normal", "armored", "shielded", "fast", "tank", "boss")
# Godot 4.7 GLTFDocument는 ImporterMesh 이름에 원본 glTF scene 이름을 앞붙인다.
FOLIAGE_IMPORT_ID = "Dressing Export (temporary)_stage1_dressing_foliage"


def app_config() -> dict[str, str]:
    values = {
        "apiBaseUrl": os.environ.get("RUNE_NEXUS_API_BASE_URL", ""),
        "googleClientId": os.environ.get("GOOGLE_WEB_CLIENT_ID", ""),
        "updateManifestUrl": os.environ.get("RUNE_NEXUS_UPDATE_MANIFEST_URL", ""),
        "clientBuild": os.environ.get("RUNE_NEXUS_CLIENT_BUILD", ""),
    }
    if os.environ.get("RUNE_NEXUS_REQUIRE_PRODUCTION_CONFIG") == "true":
        if any(not value.strip() for value in values.values()):
            raise RuntimeError("Production Godot app configuration is incomplete")
        if not values["apiBaseUrl"].startswith("https://") or not values["updateManifestUrl"].startswith("https://"):
            raise RuntimeError("Production API and update URLs must use HTTPS")
    return values


def _prepare_battlefield_verification() -> None:
    """생성된 콘텐츠의 맵으로 검증 입력을 준비한다. Dart SDK/소스는 읽지 않는다."""
    content = load_compiled_content(SOURCE / "content/game_content.json")
    frames = []
    chapter_frames = {"chapterOne": [], "chapterTwoRift": [], "chapterThreeForge": []}
    for stage in content["stages"]:
        definition = stage["map"]
        theme = definition["tileTheme"]
        columns, rows = definition["columns"], definition["rows"]
        tiles = definition["tiles"]
        path = [(x + .5, y + .5) for x, y in definition["path"]]
        if len(tiles) != columns * rows or not path:
            raise RuntimeError(f"3D 검사 맵 구조가 맞지 않습니다: {stage['id']}")
        build = [(index % columns + .5, index // columns + .5)
                 for index, tile in enumerate(tiles) if tile == "build"]
        enemy_types = ENEMY_TYPES + (
            ("shieldBoss",) if theme == "chapterTwoRift" else
            ("forgeBoss",) if theme == "chapterThreeForge" else ()
        )
        frame = {
            "seq": 0, "time": 0,
            "map": {"columns": columns, "rows": rows, "tiles": tiles, "theme": theme,
                    "teleportPairs": definition.get("teleportPairs", [])},
            "turrets": [[index, *build[index % len(build)], 0, 0, 0, kind, 1]
                        for index, kind in enumerate(TURRET_TYPES)],
            "enemies": [[index + 10, *path[index % len(path)], 0, 0, 1, 0, kind]
                        for index, kind in enumerate(enemy_types)],
            "projectiles": [], "impacts": [], "buildPreview": None,
            "verificationPath": path,
        }
        frames.append(frame)
        chapter_frames[theme].append(frame)
    for name, theme in (("one", "chapterOne"), ("two", "chapterTwoRift"), ("three", "chapterThreeForge")):
        (PROJECT.parent / f"chapter_{name}_frames.json").write_text(json.dumps(chapter_frames[theme]) + "\n")



def _prepare_tank_imports() -> None:
    # Preserve the approved 24fps contact/hold keys. Godot optimizer otherwise
    # shifts source bounds and introduces drift in the stationary rubble hold.
    for name in ("tank", "tank_death"):
        (ASSETS / "enemies" / f"{name}.glb.import").write_text(
            '[remap]\nimporter="scene"\ntype="PackedScene"\n\n'
            '[params]\nanimation/fps=24\n'
            '_subresources={"nodes":{"PATH:AnimationPlayer":{"optimizer/enabled":false}}}\n'
        )


def _prepare_boss_imports() -> None:
    """Keep accepted boss contact keys and material-friendly mobile compression."""
    boss = ASSETS / "enemies/boss.glb"
    boss.with_suffix(".glb.import").write_text(
        '[remap]\nimporter="scene"\ntype="PackedScene"\n\n'
        '[params]\nanimation/fps=60\n'
    )
    _prepare_compressed_model_textures(boss)


def _prepare_compressed_model_textures(model: Path, size_limit: int = 0) -> None:
    """Import shared PBR maps with an optional cap; never resize source images."""
    raw = model.read_bytes()
    json_size = struct.unpack_from("<I", raw, 12)[0]
    document = json.loads(raw[20:20 + json_size])
    for image in document.get("images", []):
        texture = (model.parent / image["uri"]).resolve()
        # externalize_textures owns path validation and content-hash sharing.
        texture.relative_to((ASSETS / "shared_textures").resolve())
        texture.with_suffix(texture.suffix + ".import").write_text(
            '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
            '[params]\ncompress/mode=2\ncompress/high_quality=true\n'
            'compress/normal_map=2\nmipmaps/generate=true\ndetect_3d/compress_to=0\n'
            + (f'process/size_limit={size_limit}\n' if size_limit else '')
        )


# Explicit authored families, resolved through staged content-hash references.
# Keep albedo/emission limits from the accepted 1K terrain/tile policy.
_ENVIRONMENT_MODELS = ("terrain", "chapter2_tiles", "chapter2_props",
                       "chapter3_tiles", "chapter3_props")
_ENVIRONMENT_512_NAMES = {
    "terrain": frozenset({
        "C1_natural_rock_faces_normal",
        "C1_natural_rock_faces_cavity-C1_natural_rock_faces_roughness",
        "C1_mossy_PBR_stone_normal",
        "C1_mossy_PBR_stone_cavity-C1_mossy_PBR_stone_roughness",
        "C1_worn_earth_cobbles_normal",
        "C1_worn_earth_cobbles_cavity-C1_worn_earth_cobbles_roughness",
    }),
    "chapter2_tiles": frozenset({"chapter2_build_normal", "chapter2_path_normal",
                                 "chapter2_side_normal"}),
    "chapter2_props": frozenset({"chapter2_build_normal", "chapter2_side_normal"}),
    "chapter3_props": frozenset({"chapter3-normal", "Chapter3 metallic-Chapter3 roughness"}),
}


def _prepare_environment_texture_imports() -> None:
    """Resolve approved family policies once per shared image, independent of order."""
    policies = {}
    for name in _ENVIRONMENT_MODELS:
        model = ASSETS / "environment" / (name + ".glb")
        raw = model.read_bytes()
        size = struct.unpack_from("<I", raw, 12)[0]
        for image in json.loads(raw[20:20 + size]).get("images", []):
            texture = (model.parent / image["uri"]).resolve()
            texture.relative_to((ASSETS / "shared_textures").resolve())
            limit = 1024 if name in ("terrain", "chapter3_tiles") else 0
            if image.get("name") in _ENVIRONMENT_512_NAMES.get(name, ()):
                limit = 512
            previous = policies.get(texture, 0)
            policies[texture] = min(previous, limit) if previous and limit else previous or limit
    for texture, limit in policies.items():
        texture.with_suffix(texture.suffix + ".import").write_text(
            '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
            '[params]\ncompress/mode=2\ncompress/high_quality=true\n'
            'compress/normal_map=2\nmipmaps/generate=true\ndetect_3d/compress_to=0\n'
            + (f'process/size_limit={limit}\n' if limit else '')
        )


_CORE_FRAME_NAMES = frozenset(
    f"core_passive_tree/node_frame_{size}_a{state}_v1.png"
    for size in ("small", "medium", "large") for state in ("", "_active")
) | {"core_passive_tree/center_socket_v1.png", "core_passive_tree/selection_ring_v1.png"}
_GEM_NAMES = frozenset({
    "damageAmplifier", "attackSpeed", "armorPiercing", "damageOverTime", "chain",
    "elementalDamage", "range", "criticalChance", "aimSpeed", "lightWeapon",
    "heavyWeapon", "multipleProjectiles", "explosion", "physicalDamage",
})


def _app_texture_size_limit(relative: str) -> int:
    if relative in _CORE_FRAME_NAMES:
        return 512
    if relative in {"ui/hud/icons/home_button.png", "turret_modules/icons/unique_backglow.png"}:
        return 256
    if relative in {f"gems/{name}.png" for name in _GEM_NAMES}:
        return 256
    return 0


def _prepare_hud_texture_limit(texture: Path, size_limit: int = 256) -> None:
    """Keep original artwork; only the imported UI image is capped; never use VRAM compression."""
    texture.with_suffix(texture.suffix + ".import").write_text(
        '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
        '[params]\ncompress/mode=0\ncompress/normal_map=2\n'
        'mipmaps/generate=false\ndetect_3d/compress_to=0\n'
        f'process/size_limit={size_limit}\n'
    )


def _preserve_foliage_geometry(filename: str = "dressing.glb") -> None:
    # 실제 식생의 잎과 투영 차폐를 유지한다. 같은 GLB의 바위 LOD는 그대로 둔다.
    path = ASSETS / "environment" / (filename + ".import")
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


def _environment_stage_ids(theme: str, minimum: int = 1) -> list[int]:
    content = load_compiled_content(SOURCE / "content/game_content.json")
    return [int(stage["id"]) for stage in content["stages"]
            if int(stage["id"]) >= minimum and stage["map"]["tileTheme"] == theme]


def _prepare_dressing_manifests() -> None:
    manifests = []
    for stage in _environment_stage_ids("chapterOne", 2):
        resource = f"environment/dressing_stage{stage}.glb"
        glb = (ASSETS / resource).read_bytes()
        document = json.loads(glb[20:20 + struct.unpack_from("<I", glb, 12)[0]])
        root = next((node for node in document["nodes"]
                     if node.get("name") == "stage1_dressing"), {})
        extras = root.get("extras", {})
        columns, rows = extras.get("columns", 0), extras.get("rows", 0)
        tiles = extras.get("tileTypes", [])
        if columns <= 0 or rows <= 0 or len(tiles) != columns * rows or tiles.count("build") > 32:
            raise RuntimeError(f"스테이지 {stage} 환경 GLB의 맵·건설칸 계약이 맞지 않습니다.")
        manifests.append({"columns": columns, "rows": rows, "tileTypes": tiles,
                          "resource": "res://assets/" + resource})
    (ASSETS / "dressing_manifests.json").write_text(json.dumps(manifests) + "\n")


def _prepare_chapter_environment_manifests() -> None:
    manifests = []
    for stage in _environment_stage_ids("chapterTwoRift"):
        glb = (ASSETS / f"environment/chapter2_stage{stage}_geology.glb").read_bytes()
        document = json.loads(glb[20:20 + struct.unpack_from("<I", glb, 12)[0]])
        root = next((node for node in document["nodes"]
                     if node.get("name") == f"stage{stage}_geology"), {})
        extras = root.get("extras", {})
        columns, rows = extras.get("columns", 0), extras.get("rows", 0)
        tiles = extras.get("tileTypes", [])
        if columns <= 0 or rows <= 0 or len(tiles) != columns * rows:
            raise RuntimeError(f"스테이지 {stage} 절벽 GLB의 맵 계약이 맞지 않습니다.")
        manifest = {"stage": stage, "columns": columns, "rows": rows, "tileTypes": tiles}
        for key in ("cameraPointsGodot", "accentLights"):
            if key in extras:
                manifest[key] = extras[key]
        manifests.append(manifest)
        (ASSETS / f"chapter2_stage{stage}_manifest.json").write_text(json.dumps(manifest) + "\n")
    (ASSETS / "chapter2_environment_manifests.json").write_text(json.dumps(manifests) + "\n")


def _remove_retired_fern_shadow() -> None:
    # 기존 빌드의 source/import와 이 에셋에 속하는 캐시만 제거한다.
    for name in ("fern_shadow.glb", "fern_shadow.glb.import"):
        (ASSETS / "environment" / name).unlink(missing_ok=True)
    for path in (PROJECT / ".godot/imported").glob("fern_shadow.glb-*"):
        if path.is_file():
            path.unlink()
    for name in ("fern_shadow.gdshader.uid", "fern_shadow_outline.gdshaderinc.uid"):
        (PROJECT / "environment" / name).unlink(missing_ok=True)


def _prepare_app_ui() -> None:
    manifest = SOURCE / "ui/assets.json"
    if not manifest.is_file():
        return
    for relative in json.loads(manifest.read_text()):
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts:
            raise RuntimeError(f"잘못된 Godot UI 자산 경로: {relative}")
        source = ROOT / "assets/images" / path
        target = ASSETS / "app" / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        limit = _app_texture_size_limit(relative)
        if limit:
            _prepare_hud_texture_limit(target, limit)


def _prepare_combat_background() -> None:
    # Generated offline. Never bake or convert the field at app/stage startup.
    source = ROOT / "assets/images/backgrounds/combat_space_nebula.png"
    mask = source.with_name("combat_space_nearby.res")
    metadata = json.loads(mask.with_suffix(".json").read_text())
    for key, path in (("source_sha256", source), ("mask_sha256", mask),
                      ("generator_sha256", ROOT / "scripts/generate_combat_space_mask.gd")):
        if metadata.get(key) != hashlib.sha256(path.read_bytes()).hexdigest():
            raise RuntimeError("Stale combat space luminance field; run scripts/generate_combat_space_mask.gd")
    target = ASSETS / "backgrounds" / source.name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    shutil.copy2(mask, target.with_name(mask.name))
    target.with_suffix(".png.import").write_text(
        '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
        '[params]\ncompress/mode=0\ncompress/normal_map=2\n'
        'mipmaps/generate=false\ndetect_3d/compress_to=0\n'
    )


def prepare() -> Path:
    # Check before any asset staging or copy: stale/manual output cannot enter a build.
    check_generated(ROOT)
    compile_progression(ROOT, check=True)
    if not (SOURCE / "project.godot").is_file():
        raise RuntimeError("루트 godot/ 공용 프로젝트를 찾을 수 없습니다.")
    required = [SOURCE_ASSETS / "environment" / name for name in ("terrain.glb", "dressing.glb", "landmarks.glb")]
    required += [SOURCE_ASSETS / "environment" / f"dressing_stage{stage}.glb" for stage in range(2, 6)]
    required += [SOURCE_ASSETS / "environment" / name for name in ("chapter2_tiles.glb", "chapter2_tiles_optimized.glb", "chapter2_props.glb", "chapter3_tiles.glb", "chapter3_props.glb")]
    required += [SOURCE_ASSETS / "environment" / f"chapter2_stage{stage}_{kind}.glb"
                 for stage in _environment_stage_ids("chapterTwoRift") for kind in ("geology", "props")]
    if any(stage >= 21 for stage in _environment_stage_ids("chapterTwoRift")):
        required += [SOURCE_ASSETS / "environment/chapter2_tiles_expansion.glb"]
    required += [SOURCE_ASSETS / "projectiles" / "cannonball.glb"]
    required += [SOURCE_ASSETS / "effects" / name for name in ("placement_dust.glb", "placement_dust.json")]
    required += [SOURCE_ASSETS / "turrets" / f"{name}.glb" for name in TURRET_TYPES]
    required += [SOURCE_ASSETS / "enemies" / f"{name}.glb" for name in ENEMY_TYPES]
    required += [SOURCE_ASSETS / "enemies" / name for name in ("normal_death.glb", "fast_death.glb", "tank_death.glb", "normal_status_burn.res", "normal_status_frost_shards.res", "normal_status_frost_grains.res", "fast_status_burn.res", "fast_status_frost_shards.res", "fast_status_frost_grains.res")]
    required += [SOURCE_ASSETS / "enemies" / f"{enemy}_status_{kind}.res"
                 for enemy in ("tank", "boss") for kind in ("burn", "frost_shards", "frost_grains")]
    required += [SOURCE_ASSETS / "effects" / "enemy_frost" / name
                 for name in ("crystals.glb", "attachments.json", "rime_mask.bin", "grain.png")]
    required += [SOURCE_ASSETS / "effects" / name
                 for name in ("machinegun_muzzle.glb", "machinegun_muzzle_noise.bin")]
    for path in required:
        if not path.is_file():
            raise RuntimeError(f"필수 3D 자산 누락: {path.relative_to(ROOT)}")

    def ignore_authoring(path, names):
        return [name for name in names if name == ".godot" or
                (name == "source" and Path(path) == SOURCE / "content")]
    # The staged project contains runtime data only; remove old authoring copies.
    authoring = PROJECT / "content/source"
    if authoring.exists():
        shutil.rmtree(authoring)
    shutil.copytree(SOURCE, PROJECT, dirs_exist_ok=True, ignore=ignore_authoring)
    (PROJECT / "app_config.json").write_text(json.dumps(app_config()) + "\n")
    # 삭제된 스크립트·장면·재질 프리셋이 이전 빌드에 남지 않도록 소스만 동기화.
    for suffix in ("*.gd", "*.gdshader", "*.gdshaderinc", "*.tscn", "*.tres"):
        for path in PROJECT.rglob(suffix):
            relative = path.relative_to(PROJECT)
            if relative.parts[0] not in (".godot", "assets") and not (SOURCE / relative).exists():
                path.unlink()
    # 이 폴더는 빌드 전용이다. 이전 GLB에서 추출된 PNG·import 설정을 남기면
    # all_resources export가 사용하지 않는 텍스처까지 다시 포함한다.
    if ASSETS.exists():
        shutil.rmtree(ASSETS)
    ASSETS.mkdir(parents=True, exist_ok=True)
    _remove_retired_fern_shadow()
    for source in sorted(SOURCE_ASSETS.rglob("*.glb")):
        # 과거 생성기를 실행해 파일이 다시 생겨도 폐기한 외피는 패키징하지 않는다.
        if source.relative_to(SOURCE_ASSETS) == Path("environment/fern_shadow.glb"):
            continue
        # Earlier per-kind baked frost overlays are archival assets, never runtime.
        if source.parent.name == "enemy_frost" and source.name != "crystals.glb":
            continue
        target = ASSETS / source.relative_to(SOURCE_ASSETS)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    for source in sorted((SOURCE_ASSETS / "enemies").glob("*_status_*.res")):
        shutil.copy2(source, ASSETS / "enemies" / source.name)
    shutil.copy2(SOURCE_ASSETS / "effects/placement_dust.json", ASSETS / "effects/placement_dust.json")
    texture_manifest = externalize_textures(ASSETS)
    _prepare_tank_imports()
    (PROJECT.parent / "shared_texture_manifest.json").write_text(
        json.dumps(texture_manifest, ensure_ascii=False, indent=2) + "\n"
    )
    # 공개본의 무손실·mipmap 계약을 명시한다. 편집기에서 3D를 열었는지에
    # 따라 자동으로 VRAM 압축으로 바뀌던 로컬/CI 차이를 방지한다.
    for texture in (ASSETS / "shared_textures").iterdir():
        if texture.suffix not in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        texture.with_suffix(texture.suffix + ".import").write_text(
            '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
            '[params]\ncompress/mode=0\ncompress/normal_map=2\n'
            'mipmaps/generate=true\ndetect_3d/compress_to=0\n'
        )
    core_mask = ASSETS / "effects/boss_core_mask.png"
    shutil.copy2(SOURCE_ASSETS / "effects/boss_core_mask.png", core_mask)
    core_mask.with_suffix(".png.import").write_text(
        '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
        '[params]\ncompress/mode=0\ncompress/normal_map=2\n'
        'mipmaps/generate=false\ndetect_3d/compress_to=0\n'
    )
    # Actor PBR maps use the accepted boss ASTC/BPTC policy. Live/death maps
    # remain content-hash shared. Special VFX retain their existing policies. Cap only the costly fast/tank/frost runtime atlases;
    # smaller maps are not upscaled, and source images/geometry/UVs stay intact.
    _prepare_boss_imports()
    for name in ENEMY_TYPES + ("normal_death", "fast_death", "tank_death"):
        if name != "boss":  # Already handled with its animation import policy.
            limit = 1024 if name in ("fast", "fast_death", "tank", "tank_death") else 0
            _prepare_compressed_model_textures(ASSETS / "enemies" / f"{name}.glb", limit)
    for name in TURRET_TYPES:
        _prepare_compressed_model_textures(ASSETS / "turrets" / f"{name}.glb",
                                           1024 if name == "frost" else 0)
    _prepare_environment_texture_imports()
    ui_target = ASSETS / "ui"
    ui_target.mkdir(parents=True, exist_ok=True)
    for source in sorted((SOURCE_ASSETS / "ui").rglob("*")):
        if source.is_file() and source.suffix in (".png", ".ttf", ".txt"):
            if source.relative_to(SOURCE_ASSETS / "ui").as_posix() == "labels/diamond_currency.png":
                continue
            target = ui_target / source.relative_to(SOURCE_ASSETS / "ui")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    shutil.copy2(ROOT / "assets/images/diamond_currency.png", ui_target / "diamond_currency.png")
    _prepare_hud_texture_limit(ui_target / "diamond_currency.png")
    shutil.copy2(ROOT / "assets/fonts/NotoSansKR-VF.ttf", ui_target / "NotoSansKR-VF.ttf")
    for name in ("MaterialIcons-Regular.otf", "MaterialIcons_LICENSE.txt"):
        shutil.copy2(ROOT / "assets/fonts" / name, ui_target / name)
    _prepare_app_ui()
    _prepare_combat_background()
    _preserve_foliage_geometry()
    for stage in _environment_stage_ids("chapterOne", 2):
        _preserve_foliage_geometry(f"dressing_stage{stage}.glb")
    _prepare_dressing_manifests()
    _prepare_chapter_environment_manifests()
    for filename in ("muzzle_flash.png", "gun_smoke.png"):
        target = ASSETS / "effects" / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SOURCE_ASSETS / "effects" / filename, target)
    for filename in ("cannon_field.json", "machinegun_muzzle_noise.bin"):
        shutil.copy2(SOURCE_ASSETS / "effects" / filename, ASSETS / filename)
    frost_source = SOURCE_ASSETS / "effects/enemy_frost"
    shutil.copy2(frost_source / "attachments.json", ASSETS / "enemy_frost.json")
    (ASSETS / "enemy_frost_mask.bin.gz").write_bytes(
        gzip.compress((frost_source / "rime_mask.bin").read_bytes(), compresslevel=9, mtime=0)
    )
    frost_grain = ASSETS / "effects/enemy_frost/grain.png"
    shutil.copy2(frost_source / "grain.png", frost_grain)
    frost_grain.with_suffix(".png.import").write_text(
        '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
        '[params]\ncompress/mode=0\ncompress/normal_map=2\n'
        'mipmaps/generate=true\ndetect_3d/compress_to=0\n'
    )
    burn_source = SOURCE_ASSETS / "effects/enemy_burn"
    burn_target = ASSETS / "effects/enemy_burn"
    burn_target.mkdir(parents=True, exist_ok=True)
    for filename in ("attachments.json", "flame_atlas.png"):
        shutil.copy2(burn_source / filename, burn_target / filename)
    # Small padded flipbook: lossless RGB, no mip chain bleeding between frames.
    (burn_target / "flame_atlas.png.import").write_text(
        '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
        '[params]\ncompress/mode=0\ncompress/normal_map=2\n'
        'mipmaps/generate=false\ndetect_3d/compress_to=0\n'
    )
    field_bytes = (SOURCE_ASSETS / "effects/cannon_field.bin").read_bytes()
    (ASSETS / "cannon_field.bin.gz").write_bytes(
        gzip.compress(field_bytes, compresslevel=9, mtime=0)
    )

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
    # 네이티브 3D 검수 입력. 정식 앱의 전투 상태는 Godot 세션에서 생성한다.
    frame = {
        "seq": 0, "time": 0,
        "map": {"columns": columns, "rows": rows, "tiles": tiles},
        "turrets": [[index, x, z, 0, 0, 0, "cannon", 1] for index, (x, z) in enumerate(build[:6])],
        "enemies": [[index + 10, x, z, 0, 0, 1.25, 0, "tank", False, False, False, False]
                    for index, (x, z) in enumerate(targets)],
        "projectiles": [], "impacts": [], "buildPreview": None,
    }
    (ASSETS / "preview_frame.json").write_text(json.dumps(frame) + "\n")
    _prepare_battlefield_verification()
    (PROJECT.parent / "android-assets").mkdir(parents=True, exist_ok=True)
    return PROJECT


if __name__ == "__main__":
    print(prepare())

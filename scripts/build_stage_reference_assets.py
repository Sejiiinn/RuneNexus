from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageOps


STAGE_CROP = (31, 153, 820, 1719)


def texture_patch(
    image: Image.Image,
    destination: tuple[int, int, int, int],
    source: tuple[int, int, int, int],
) -> None:
    width = destination[2] - destination[0]
    height = destination[3] - destination[1]
    patch = image.crop(source).resize((width, height), Image.Resampling.LANCZOS)
    image.paste(patch, destination[:2])


def edge_mask(size: tuple[int, int], thickness: int) -> Image.Image:
    width, height = size
    outer = Image.new("L", size, 255)
    inner = Image.new("L", (width - thickness * 2, height - thickness * 2), 255)
    outer.paste(0, (thickness, thickness), inner)
    return outer


def masked_asset(image: Image.Image, mask: Image.Image) -> Image.Image:
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    result.paste(image, (0, 0), mask)
    return result


def polygon_asset(image: Image.Image, points: list[tuple[int, int]]) -> Image.Image:
    from PIL import ImageDraw

    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return masked_asset(image, mask)


def difference_asset(original: Image.Image, patched: Image.Image) -> Image.Image:
    difference = ImageChops.difference(original.convert("RGB"), patched.convert("RGB"))
    grayscale = ImageOps.grayscale(difference)
    mask = grayscale.point(lambda value: 255 if value > 8 else 0)
    mask = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(0.7))
    return masked_asset(original, mask)


def main() -> None:
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: build_stage_reference_assets.py "
            "<clean-master> <base-master> <repo> <source-master>"
        )

    clean_master_path = Path(sys.argv[1])
    base_master_path = Path(sys.argv[2])
    repo = Path(sys.argv[3])
    source_master_path = Path(sys.argv[4])
    runtime_dir = repo / "assets/images/ui/stage_reference"
    design_dir = repo / "design/mockups"
    runtime_dir.mkdir(parents=True, exist_ok=True)
    design_dir.mkdir(parents=True, exist_ok=True)

    source_master = Image.open(source_master_path).convert("RGBA")
    clean_master = Image.open(clean_master_path).convert("RGBA")
    base_master = Image.open(base_master_path).convert("RGBA")
    if clean_master.size != base_master.size:
        raise ValueError(
            f"master size mismatch: clean={clean_master.size}, base={base_master.size}"
        )
    source_master.save(design_dir / "stage_ui_reference.png", optimize=True)
    clean_master.save(design_dir / "stage_ui_reference_clean.png", optimize=True)
    base_master.save(design_dir / "stage_ui_reference_base.png", optimize=True)
    stage = clean_master.crop(STAGE_CROP)
    base_stage = base_master.crop(STAGE_CROP)

    # 외곽 셸: 내부 질감과 프레임을 독립 레이어로 분리.
    shell_fill = stage.crop((24, 1175, 764, 1548)).resize(
        stage.size,
        Image.Resampling.LANCZOS,
    )
    shell_fill.save(runtime_dir / "stage_shell_fill.png", optimize=True)
    shell_frame = masked_asset(stage, edge_mask(stage.size, 25))
    shell_frame.save(runtime_dir / "stage_shell_frame.png", optimize=True)

    stage.crop((31, 28, 278, 119)).save(
        runtime_dir / "chapter_tab_idle.png", optimize=True
    )
    stage.crop((531, 28, 764, 119)).save(
        runtime_dir / "chapter_tab_selected.png", optimize=True
    )

    banner_frame_source = stage.crop((35, 135, 759, 269))
    banner_frame = masked_asset(
        banner_frame_source,
        edge_mask(banner_frame_source.size, 7),
    )
    banner_frame.save(runtime_dir / "chapter_banner_frame.png", optimize=True)

    bridge = stage.crop((338, 280, 452, 316))
    bridge = polygon_asset(
        bridge,
        [(0, 10), (20, 0), (94, 0), (114, 10), (94, 36), (20, 36)],
    )
    bridge.save(runtime_dir / "chapter_bridge.png", optimize=True)

    active_original = stage.crop((24, 282, 764, 648))
    active_base = base_stage.crop((24, 282, 764, 648))
    active_base.save(runtime_dir / "active_stage_panel.png", optimize=True)

    # 제거 전후 차이를 안정적으로 얻기 위한 국소 소켓 패치.
    socket_mask_base = active_original.copy()
    texture_patch(socket_mask_base, (0, 15, 145, 165), (180, 45, 520, 165))
    right_border = ImageOps.mirror(active_original.crop((700, 0, 740, 180)))
    socket_mask_base.paste(right_border, (0, 0))
    socket_original = active_original.crop((0, 14, 145, 164))
    socket_patched = socket_mask_base.crop((0, 14, 145, 164))
    difference_asset(socket_original, socket_patched).save(
        runtime_dir / "stage_number_socket.png", optimize=True
    )

    stat_strip = stage.crop((56, 431, 738, 512))
    stat_strip = polygon_asset(
        stat_strip,
        [(10, 0), (672, 0), (682, 10), (682, 71), (672, 81), (10, 81), (0, 71), (0, 10)],
    )
    stat_strip.save(runtime_dir / "stage_stat_strip.png", optimize=True)

    continue_button = stage.crop((57, 527, 735, 611))
    continue_button = polygon_asset(
        continue_button,
        [(10, 0), (668, 0), (678, 10), (678, 74), (668, 84), (10, 84), (0, 74), (0, 10)],
    )
    continue_button.save(runtime_dir / "continue_button_idle.png", optimize=True)

    row_original = stage.crop((24, 658, 764, 781))
    row_base = base_stage.crop((24, 658, 764, 781))
    row_base.save(runtime_dir / "locked_stage_row.png", optimize=True)
    plate_mask_base = row_original.copy()
    texture_patch(plate_mask_base, (18, 18, 132, 108), (170, 18, 500, 108))
    plate_original = row_original.crop((18, 18, 132, 108))
    plate_patched = plate_mask_base.crop((18, 18, 132, 108))
    difference_asset(plate_original, plate_patched).save(
        runtime_dir / "stage_number_plate.png", optimize=True
    )

    outputs = sorted(path.name for path in runtime_dir.glob("*.png"))
    manifest = {
        "source_reference": "design/mockups/stage_ui_reference.png",
        "clean_reference": "design/mockups/stage_ui_reference_clean.png",
        "base_reference": "design/mockups/stage_ui_reference_base.png",
        "stage_crop": STAGE_CROP,
        "reference_canvas": [stage.width, stage.height],
        "composition": "independent_layers",
        "outputs": outputs,
        "generation": (
            "Built-in ImageGen precise-object-edit removed only dynamic content. "
            "A second precise-object-edit removed detachable component layers. "
            "This script deterministically extracts the shell, tab states, banner frame, bridge, "
            "active panel base, socket, stat strip, button, locked row base and number plate."
        ),
    }
    (design_dir / "stage_ui_reference_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

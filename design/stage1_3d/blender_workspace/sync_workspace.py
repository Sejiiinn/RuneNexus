"""독립 Blender 프로세스에서 현행 원본 탐색용 허브 생성."""
import json
from pathlib import Path
import shutil

import bpy

if not bpy.app.background:
    raise RuntimeError("열린 작업 보존을 위해 별도 --background 프로세스에서 실행하세요.")

HERE = Path(__file__).resolve().parent
BASE = HERE.parent
TARGET = HERE / "rune-nexus-stage1.blend"
catalog = json.loads((HERE / "catalog.json").read_text())

# 원본 누락은 기존 허브를 건드리기 전에 중단.
for item in catalog["sources"]:
    assert (BASE / item["file"]).is_file(), item["file"]
for key in ("preview", "movie", "reference"):
    assert (BASE / catalog[key]).is_file(), catalog[key]

user_notes = {}
if TARGET.exists():
    shutil.copy2(TARGET, HERE / "rune-nexus-stage1.previous.blend")
    with bpy.data.libraries.load(str(TARGET), link=False) as (src, dst):
        dst.texts = [name for name in src.texts if name.startswith("USER_")]
    user_notes = {text.name: text.as_string() for text in dst.texts}

bpy.ops.wm.read_factory_settings(use_empty=True)
home = bpy.context.scene
home.name = "00 Start - Current Sources"
home["purpose"] = "현행 원본 탐색 허브. 실제 편집은 연결된 원본 파일에서 수행."
for item in catalog["sources"]:
    with bpy.data.libraries.load(str(BASE / item["file"]), link=True) as (src, dst):
        assert item["scene"] in src.scenes, item
        dst.scenes = [item["scene"]]
    source = dst.scenes[0]
    scene = bpy.data.scenes.new(item["name"])
    scene["source"] = "//../" + item["file"]
    scene["game_output"] = ("assets/images/stage1_3d/" + item["output"]
                            if item.get("output") else "미적용 — 독립 에셋 검수 단계")
    group = bpy.data.collections.new(item["name"] + " - Linked Source")
    scene.collection.children.link(group)
    for obj in source.objects:
        root = obj
        while root.parent:
            root = root.parent
        if item.get("roots") and root.name not in item["roots"] and obj.type not in {"LIGHT", "CAMERA"}:
            continue
        group.objects.link(obj)
    if source.camera and source.camera.name in scene.objects:
        scene.camera = source.camera
    scene.world = source.world
    scene.frame_start, scene.frame_end = source.frame_start, source.frame_end
    bpy.data.scenes.remove(source)

def add_text(name, body):
    text = bpy.data.texts.new(name)
    text.write(body)
    text.cursor_set(0)
    return text

start = add_text("00_시작", (HERE / "README.md").read_text())
add_text("01_현행원본", json.dumps(catalog, ensure_ascii=False, indent=2))
add_text("02_효과_베이크_절차", (BASE / "cannon_impact/field_cache/README.md").read_text())
add_text("03_포탑_내보내기_절차", (BASE / "turrets/README.md").read_text())
add_text("05_환경장식_제작_절차", (BASE / "environment_dressing/README.md").read_text())
add_text("06_식물_독립원본", (BASE / "environment_dressing/plant_library/README.md").read_text())
add_text("07_추가환경_독립원본", (BASE / "environment_dressing/companion_library/README.md").read_text())
add_text("04_확인기록", "자동 생성 기준 요약 — 직접 편집하지 않습니다.\n게임 적용 여부와 최신 검증은 USER_작업메모에 기록하고 허브를 저장하세요.\n\n2026-09-11: 현행 연결 원본과 실제 게임 v5 캡처/영상 등록.\n이전 v2 폭발은 역사 자료로 제외. 모바일 실기기 성능 수용 검증은 별도 미완료.\n원본/게임 자산을 변경하지 않는 허브 생성.\n")
for name, body in user_notes.items():
    add_text(name, body)
if not user_notes:
    add_text("USER_작업메모", "이 Text의 사용자 메모는 허브 재생성 시 보존됩니다.\n")

preview = bpy.data.images.load(str(BASE / catalog["preview"]))
preview.name = "CURRENT - Game v5 Screenshot (not Blender render)"
preview.pack()
reference = bpy.data.images.load(str(BASE / catalog["reference"]))
reference.name = "REFERENCE - Approved Fragmentation Concept"
reference.pack()
reference.use_fake_user = True
movie = bpy.data.movieclips.load(str(BASE / catalog["movie"]))
movie.name = "CURRENT - Actual Game v5 Two Views"
movie.use_fake_user = True
movie_image = bpy.data.images.load(str(BASE / catalog["movie"]))
movie_image.name = "MOVIE - Actual Game v5 Two Views"
movie_image.use_fake_user = True

# 기존 기본 워크스페이스 활용, 별도 애드온·자동 실행 핸들러 없음.
layout = bpy.data.workspaces.get("Layout")
layout.name = "00 Start"
main = max(layout.screens[0].areas, key=lambda a: a.width * a.height)
main.type = "TEXT_EDITOR"
main.spaces.active.text = start
main.spaces.active.show_word_wrap = True
main.spaces.active.font_size = 16
main.spaces.active.top = 0
modeling = bpy.data.workspaces.get("Modeling")
modeling.name = "01 Models"
for model_area in modeling.screens[0].areas:
    if model_area.type == "VIEW_3D":
        model_area.spaces.active.region_3d.view_distance = 16
rendering = bpy.data.workspaces.get("Rendering")
rendering.name = "02 Game Preview"
bpy.context.window.workspace = rendering
area = max(rendering.screens[0].areas, key=lambda a: a.width * a.height)
area.type = "IMAGE_EDITOR"
area.spaces.active.image = preview
area.spaces.active.image_user.frame_duration = movie.frame_duration
area.spaces.active.image_user.use_auto_refresh = True
home.frame_start = 1
home.frame_end = movie.frame_duration
home.render.fps = 30
bpy.context.window.workspace = layout
bpy.context.window.scene = bpy.data.scenes["01 Terrain"]
for library in bpy.data.libraries:
    library.filepath = bpy.path.relpath(library.filepath, start=str(HERE))
movie.filepath = bpy.path.relpath(movie.filepath, start=str(HERE))
movie_image.filepath = movie.filepath
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
print("HUB_READY", str(TARGET), "scenes", len(bpy.data.scenes))

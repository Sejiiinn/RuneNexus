"""Share embedded images in staged GLBs without changing model or BIN data.

Only call this on the generated Godot assets directory, never the source assets.
Texture import policy and cleanup of previous Godot imports belong to the caller.
"""
from __future__ import annotations

from collections import defaultdict
import hashlib
import json
import os
from pathlib import Path
import struct
from urllib.parse import unquote, urlsplit


_GLB_MAGIC = 0x46546C67
_JSON_CHUNK = 0x4E4F534A
_BIN_CHUNK = 0x004E4942
_MIME_EXTENSIONS = {"image/png": ".png", "image/jpeg": ".jpg"}
_NORMAL_ROLES = {"normalTexture", "clearcoatNormalTexture"}


def _read_glb(path: Path) -> tuple[dict, bytes, bytes | None]:
    raw = path.read_bytes()
    if len(raw) < 20:
        raise ValueError(f"{path}: truncated GLB header")
    magic, version, length = struct.unpack_from("<III", raw)
    if magic != _GLB_MAGIC or version != 2 or length != len(raw):
        raise ValueError(f"{path}: invalid GLB 2.0 header or length")
    offset, document, binary, tail = 12, None, None, b""
    while offset < len(raw):
        if offset + 8 > len(raw):
            raise ValueError(f"{path}: truncated GLB chunk header")
        size, kind = struct.unpack_from("<II", raw, offset)
        end = offset + 8 + size
        if size % 4 or end > len(raw):
            raise ValueError(f"{path}: invalid GLB chunk length")
        if offset == 12:
            if kind != _JSON_CHUNK:
                raise ValueError(f"{path}: first GLB chunk is not JSON")
            document = json.loads(raw[offset + 8:end])
            if not isinstance(document, dict):
                raise ValueError(f"{path}: GLB JSON must be an object")
            tail = raw[end:]
        elif kind == _JSON_CHUNK:
            raise ValueError(f"{path}: duplicate GLB JSON chunk")
        elif kind == _BIN_CHUNK:
            if binary is not None:
                raise ValueError(f"{path}: duplicate GLB BIN chunk")
            binary = raw[offset + 8:end]
        offset = end
    return document, tail, binary


def _texture_roles(document: dict) -> dict[int, set[str]]:
    """Include standard material texture fields and extension texture fields."""
    textures = document.get("textures", [])
    roles = defaultdict(set)

    def visit(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key.endswith("Texture") and isinstance(child, dict) and "index" in child:
                    index = child["index"]
                    if type(index) is not int or not 0 <= index < len(textures):
                        raise ValueError(f"invalid texture index for {key}: {index!r}")
                    texture = textures[index]
                    source = texture.get("source")
                    if source is not None:
                        roles[source].add(key)
                    for extension in texture.get("extensions", {}).values():
                        if isinstance(extension, dict) and "source" in extension:
                            roles[extension["source"]].add(key)
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    visit(document.get("materials", []))
    return roles


def _image_extension(payload: bytes, mime: str | None, label: str) -> str:
    if payload.startswith(b"\x89PNG\r\n\x1a\n"):
        detected = "image/png"
    elif payload.startswith(b"\xff\xd8\xff"):
        detected = "image/jpeg"
    else:
        raise ValueError(f"{label}: unsupported embedded/external image format")
    if mime is not None and mime != detected:
        raise ValueError(f"{label}: MIME {mime!r} does not match {detected} payload")
    return _MIME_EXTENSIONS[detected]


def _embedded_payload(document: dict, image: dict, binary: bytes | None, label: str) -> bytes:
    index = image["bufferView"]
    views = document.get("bufferViews", [])
    if type(index) is not int or not 0 <= index < len(views):
        raise ValueError(f"{label}: invalid image bufferView")
    view = views[index]
    if view.get("buffer") != 0 or binary is None:
        raise ValueError(f"{label}: embedded image must use GLB BIN buffer 0")
    buffers = document.get("buffers", [])
    if not buffers or "uri" in buffers[0]:
        raise ValueError(f"{label}: image buffer is not the embedded GLB buffer")
    offset, size = view.get("byteOffset", 0), view.get("byteLength")
    buffer_size = buffers[0].get("byteLength")
    if (type(offset) is not int or type(size) is not int or type(buffer_size) is not int
            or offset < 0 or size <= 0 or offset + size > min(len(binary), buffer_size)):
        raise ValueError(f"{label}: image bufferView exceeds BIN bounds")
    return binary[offset:offset + size]


def _external_path(uri: str, glb: Path, assets: Path, label: str) -> Path:
    if not isinstance(uri, str) or not uri:
        raise ValueError(f"{label}: image URI must be a nonempty relative file path")
    parsed = urlsplit(uri)
    decoded = unquote(parsed.path)
    if (parsed.scheme or parsed.netloc or parsed.query or parsed.fragment
            or not decoded or decoded.startswith(("/", "\\")) or "\\" in decoded
            or "\x00" in decoded):
        raise ValueError(f"{label}: unsupported/non-relative image URI {uri!r}")
    target = (glb.parent / decoded).resolve()
    try:
        target.relative_to(assets)
    except ValueError as error:
        raise ValueError(f"{label}: image URI escapes staged assets: {uri!r}") from error
    if not target.is_file():
        raise ValueError(f"{label}: external image is missing: {uri!r}")
    return target


def externalize_textures(assets: Path) -> dict:
    """Replace staged embedded images with hash-named shared PNG/JPEG references.

    Existing relative image URIs remain byte-for-byte unchanged after validation.
    All inputs are validated before any write. Returned byte savings describe
    duplicate source-image payloads, not a measured PCK or APK size reduction.
    BIN chunks retain the now-unused image bytes to preserve every binary offset.
    """
    assets = Path(assets).resolve()
    if not assets.is_dir():
        raise ValueError(f"staged assets directory does not exist: {assets}")
    writes, shared, mappings = [], {}, []
    payloads, shared_roles = {}, defaultdict(set)
    embedded_bytes = embedded_count = 0
    embedded_hashes = set()
    paths = sorted(assets.rglob("*.glb"))
    for glb in paths:
        if not glb.resolve().is_relative_to(assets):
            raise ValueError(f"GLB escapes staged assets through symlink: {glb}")
        document, tail, binary = _read_glb(glb)
        roles = _texture_roles(document)
        images = document.get("images", [])
        if not isinstance(images, list):
            raise ValueError(f"{glb}: images must be an array")
        changed = False
        for index, image in enumerate(images):
            label = f"{glb}: image {index}"
            if not isinstance(image, dict) or ("bufferView" in image) == ("uri" in image):
                raise ValueError(f"{label}: expected exactly one of bufferView/uri")
            embedded = "bufferView" in image
            if embedded:
                if image.get("mimeType") not in _MIME_EXTENSIONS:
                    raise ValueError(f"{label}: embedded image requires PNG/JPEG MIME")
                payload = _embedded_payload(document, image, binary, label)
                extension = _image_extension(payload, image["mimeType"], label)
                digest = hashlib.sha256(payload).hexdigest()
                target = assets / "shared_textures" / (digest + extension)
                if target.exists() and target.read_bytes() != payload:
                    raise ValueError(f"{label}: shared image content does not match its hash path")
                shared[target] = payload
                embedded_count += 1
                embedded_bytes += len(payload)
                embedded_hashes.add(digest)
                del image["bufferView"]
                del image["mimeType"]
                image["uri"] = Path(os.path.relpath(target, glb.parent)).as_posix()
                changed = True
            else:
                target = _external_path(image["uri"], glb, assets, label)
                payload = target.read_bytes()
                extension = _image_extension(payload, image.get("mimeType"), label)
                if target.suffix.lower() not in ({".jpg", ".jpeg"} if extension == ".jpg" else {".png"}):
                    raise ValueError(f"{label}: external image extension does not match its payload")
                digest = hashlib.sha256(payload).hexdigest()
            payloads[digest] = len(payload)
            relative_target = target.relative_to(assets).as_posix()
            shared_roles[relative_target].update(roles[index])
            mappings.append({
                "glb": glb.relative_to(assets).as_posix(), "image_index": index,
                "name": image.get("name"), "roles": sorted(roles[index]),
                "source": "embedded" if embedded else "external",
                "sha256": digest, "bytes": len(payload),
                "uri": image["uri"], "texture": relative_target,
            })
        if changed:
            encoded = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode()
            encoded += b" " * (-len(encoded) % 4)
            header = struct.pack("<IIIII", _GLB_MAGIC, 2, 20 + len(encoded) + len(tail),
                                 len(encoded), _JSON_CHUNK)
            writes.append((glb, header + encoded + tail))
    collisions = [path for path, roles in shared_roles.items()
                  if roles & _NORMAL_ROLES and roles - _NORMAL_ROLES]
    if collisions:
        raise ValueError("normal and non-normal roles would share an image import: " + ", ".join(collisions))
    for target, payload in shared.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            target.write_bytes(payload)
    for target, raw in writes:
        target.write_bytes(raw)
    return {
        "glb_count": len(paths), "rewritten_glb_count": len(writes),
        "image_reference_count": len(mappings), "embedded_image_count": embedded_count,
        "unique_image_count": len(payloads), "shared_texture_count": len({
            image["texture"] for image in mappings if image["texture"].startswith("shared_textures/")
        }),
        "embedded_payload_bytes": embedded_bytes,
        "unique_embedded_payload_bytes": sum(payloads[digest] for digest in embedded_hashes),
        "deduplicated_embedded_bytes": embedded_bytes - sum(payloads[digest] for digest in embedded_hashes),
        "normal_role_collisions": collisions, "images": mappings,
        "note": "Source payload savings only; BIN is unchanged and APK/PCK savings require an exported-pack audit.",
    }

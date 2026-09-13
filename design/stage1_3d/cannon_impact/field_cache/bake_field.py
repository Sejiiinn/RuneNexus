#!/usr/bin/env python3
"""기존 GLSL의 canonical 3D 폭발장을 생성하고 RGBA8 brick 저장 규격 검증."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OUTPUT = ROOT / 'assets/images/stage1_3d/effects'
GRID = 48
BRICKS = np.array([4, 4, 2])
LOW = np.array([-2.35, 0.0, -2.35])
HIGH = np.array([2.35, 2.9, 2.35])
TIMES = np.array([0, .008, .018, .028, .04, .055, .075, .10, .12, .15,
                  .18, .21, .24, .27, .30, .34, .38, .42, .46, .50,
                  .55, .60, .65, .70, .75, .80, .85, .90, .95, 1, 1.05, 1.1])
DENSITY_SCALE = 64.0
EMISSION_SCALE = 32.0
# GLSL mat3 생성자의 열 우선 순서를 명시적으로 전치한 행렬.
TURN = np.array([[0.0, -.8, -.6], [.8, .36, -.48], [.6, -.48, .64]])
AXES = np.array([[1, .32, .12], [.68, .68, .73], [.12, .40, 1],
                 [-.49, .77, .81], [-.96, .27, .30], [-.84, .55, -.43],
                 [-.22, .36, -.98], [.37, .92, -.76], [.86, .24, -.64],
                 [.14, 1, .18]])
AXES /= np.linalg.norm(AXES, axis=1)[:, None]


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def noise3(p, noise):
    base = np.floor(p).astype(np.int64)
    f = p - base
    f = f * f * f * (f * (f * 6 - 15) + 10)
    result = np.zeros(p.shape[:-1])
    # R8 repeat texture의 삼선형 필터. 원본 Dart 배열은 x가 가장 빠른 축.
    for z in (0, 1):
        for y in (0, 1):
            for x in (0, 1):
                idx = (base + [x, y, z]) % 32
                weight = np.prod(np.where([x, y, z], f, 1 - f), axis=-1)
                result += noise[idx[..., 2], idx[..., 1], idx[..., 0]] * weight
    return result


def field(p, age, noise):
    """procedural_source.dart.txt의 field, uAngle=0, flash 항 제외."""
    grow = 1 - np.exp(-age * 10)
    reach = .12 + 2.10 * grow
    age_fade = 1 - smoothstep(.48, 1.1, age)
    appear = smoothstep(0, .018, age)
    flow = p * 3.1 + [0, -age * 1.6, 0]
    warp = np.stack([noise3(flow, noise), noise3(flow + [11, 3, 7], noise),
                     noise3(flow + [4, 17, 2], noise)], axis=-1) - .5
    q = p + warp * (.055 + .16 * grow)
    fold_p = q * 8 + [0, -age * 2.8, 0]
    grain = (noise3(fold_p, noise) * .58
             + noise3((fold_p @ TURN.T) * 2.13 + 7.1, noise) * .28
             + noise3((fold_p @ TURN.T) * 4.37 + 19.3, noise) * .14)
    jets = np.zeros(p.shape[:-1])
    outer_jets = jets.copy()
    fire_jets = jets.copy()
    disperse = smoothstep(.18, .68, age)
    relative = q - [0, .045, 0]
    for j, axis in enumerate(AXES):
        length_scale = .83 + .17 * ((j * .618 + .31) % 1)
        along = np.sum(relative * axis, axis=-1)
        t = along / (reach * length_scale)
        radial = relative - along[..., None] * axis
        width = (.085 + .34 * np.clip(t, 0, 1)) * (.38 + .62 * grow)
        lobes = .76 + .31 * np.sin(t * 17 + j * 2.1)
        smoke_t = t / (.85 if j < 9 else 1)
        tip = smoothstep(.36, .98, smoke_t)
        taper = 1 - .78 * tip
        smoke_jet = np.maximum(0, 1 - np.linalg.norm(radial, axis=-1) / (width * taper))
        smoke_jet *= smoothstep(-.06, .05, t)
        if j < 9:
            scattered = radial + warp * (disperse * (.45 + .80 * np.clip(t, 0, 1)))[..., None]
            diffuse_width = width * taper * (1 + .45 * disperse)
            smoke_jet = np.maximum(0, 1 - np.linalg.norm(scattered, axis=-1) / diffuse_width)
            smoke_jet = np.maximum(0, smoke_jet - disperse * (.12 + grain * .48))
            smoke_jet *= smoothstep(-.06, .05, t)
        smoke_jet = np.maximum(0, smoke_jet - tip * (.12 + grain * .42))
        smoke_jet *= 1 - smoothstep(.68, 1, smoke_t)
        if j < 9:
            outer_jets = np.maximum(outer_jets, smoke_jet)
        else:
            jets = np.maximum(jets, smoke_jet)
        if age < .30 and j in (0, 3, 5, 8):
            flame_jet = np.maximum(0, 1 - np.linalg.norm(radial, axis=-1) / (width * lobes * 1.32))
            flame_jet *= smoothstep(-.06, .05, t) * (1 - smoothstep(.84, 1, t))
            fire_jets = np.maximum(fire_jets, flame_jet * (1 - smoothstep(.462, 1.144, along)))
    core_width = .14 + .46 * grow
    core_height = .21 + .64 * grow
    core_pos = q - [-.05, .21 + .24 * grow + age * .12, .025]
    core = np.maximum(0, 1 - np.linalg.norm(core_pos / [core_width, core_height, core_width * .88], axis=-1))
    dirt = np.maximum(0, jets + (grain - .5) * .72) * smoothstep(0, .13, jets)
    outer_dirt = np.maximum(0, outer_jets + (grain - .5) * .72)
    outer_dirt *= smoothstep(0, .13, outer_jets) * (1 - .96 * disperse)
    dirt = np.maximum(dirt, outer_dirt)
    smoke = np.maximum(0, core + (grain - .5) * .50) * smoothstep(0, .10, core)
    density = (dirt * 18 + smoke * 18) * age_fade * appear
    fire_life = (1 - smoothstep(.12, .30, age)) * appear
    heat = np.clip((grain - .30) * 3.3, 0, 1)
    burning = np.clip(fire_jets * fire_life * 2.6, 0, 1)
    density *= 1 - burning * .82
    emission = fire_jets * heat ** 1.8 * 24 * fire_life
    return np.stack([density, emission, heat], axis=-1)


def encode(values):
    assert np.isfinite(values).all() and (values >= 0).all()
    assert (values <= [DENSITY_SCALE, EMISSION_SCALE, 1]).all(), '필드 인코딩 범위 초과'
    # 양의 값에서 GLSL round와 동일한 최근접 반올림.
    density = np.floor(values[..., 0] / DENSITY_SCALE * 65535 + .5).astype(np.uint16)
    result = np.empty((*values.shape[:-1], 4), dtype=np.uint8)
    result[..., 0] = density >> 8
    result[..., 1] = density & 255
    result[..., 2] = np.floor(values[..., 1] / EMISSION_SCALE * 255 + .5)
    result[..., 3] = np.floor(values[..., 2] * 255 + .5)
    return result


def decode(values):
    v = values.astype(np.float64)
    return np.stack([(v[..., 0] * 256 + v[..., 1]) * (DENSITY_SCALE / 65535),
                     v[..., 2] * (EMISSION_SCALE / 255), v[..., 3] / 255], axis=-1)


def sample_frame(atlas, frame, points):
    # 端点 grid와 texel-center clamp: 각 brick의 이웃 frame으로 보간하지 않음.
    local = np.clip((points - LOW) / (HIGH - LOW), 0, 1) * (GRID - 1)
    base = np.floor(local).astype(int)
    f = local - base
    brick = np.array([frame % 4, (frame // 4) % 4, frame // 16]) * GRID
    rgba = np.zeros((*points.shape[:-1], 4))
    for z in (0, 1):
        for y in (0, 1):
            for x in (0, 1):
                idx = np.minimum(base + [x, y, z], GRID - 1) + brick
                weight = np.prod(np.where([x, y, z], f, 1 - f), axis=-1)
                rgba += atlas[idx[..., 2], idx[..., 1], idx[..., 0]] * weight[..., None]
    return decode(rgba)


def sample(atlas, age, points):
    right = int(np.clip(np.searchsorted(TIMES, age, side='right'), 1, len(TIMES) - 1))
    left = right - 1
    blend = float(np.clip((age - TIMES[left]) / (TIMES[right] - TIMES[left]), 0, 1))
    return sample_frame(atlas, left, points) * (1 - blend) + sample_frame(atlas, right, points) * blend


def metrics(source, cached):
    error = np.abs(source - cached)
    active = (source[:, 0] >= .005) | (source[:, 1] >= .005)
    thin = (source[:, 0] >= .005) & (source[:, 0] < .1)
    return {'maxAbsoluteError': error.max(axis=0).tolist(),
            'meanAbsoluteError': error.mean(axis=0).tolist(),
            'activeSampleCount': int(active.sum()),
            'activeMeanAbsoluteError': error[active].mean(axis=0).tolist() if active.any() else [0, 0, 0],
            'thinDensitySampleCount': int(thin.sum()),
            'thinDensityBelowRenderThresholdAfterInterpolation': int((cached[thin, 0] < .005).sum())}


def main():
    noise_bytes = (HERE / 'noise32.bin').read_bytes()
    assert len(noise_bytes) == 32 ** 3
    noise = np.frombuffer(noise_bytes, dtype=np.uint8).reshape(32, 32, 32) / 255.0
    zz, yy, xx = np.meshgrid(np.linspace(LOW[2], HIGH[2], GRID),
                             np.linspace(LOW[1], HIGH[1], GRID),
                             np.linspace(LOW[0], HIGH[0], GRID), indexing='ij')
    points = np.stack([xx, yy, zz], axis=-1).reshape(-1, 3)
    atlas = np.zeros((GRID * 2, GRID * 4, GRID * 4, 4), dtype=np.uint8)
    frame_stats = []
    max_quant = np.zeros(3)
    for frame, age in enumerate(TIMES):
        values = field(points, age, noise)
        packed = encode(values)
        decoded = decode(packed)
        max_quant = np.maximum(max_quant, np.abs(values - decoded).max(axis=0))
        bx, by, bz = frame % 4, (frame // 4) % 4, frame // 16
        atlas[bz * GRID:(bz + 1) * GRID, by * GRID:(by + 1) * GRID,
              bx * GRID:(bx + 1) * GRID] = packed.reshape(GRID, GRID, GRID, 4)
        thin = (values[:, 0] >= .005) & (values[:, 0] < .1)
        frame_stats.append({'time': float(age), 'max': values.max(axis=0).tolist(),
                            'nonzeroDensity': int((values[:, 0] > 0).sum()),
                            'visibleDensity': int((values[:, 0] >= .005).sum()),
                            'thinDensity': int(thin.sum()),
                            'thinDensityEncodedZero': int((decoded[thin, 0] == 0).sum())})
        print(f'frame {frame:02d} t={age:.3f} peak={frame_stats[-1]["max"]}', flush=True)
    bound = np.array([DENSITY_SCALE / 65535, EMISSION_SCALE / 255, 1 / 255]) / 2
    assert (max_quant <= bound + 1e-12).all()
    rng = np.random.default_rng(317)
    # 원점 주변과 전장 전체를 함께 조사하여 빈 공간 평균에 편향되지 않도록 구성.
    probes = np.concatenate([rng.uniform(LOW, HIGH, (8192, 3)),
                             rng.uniform([-.9, 0, -.9], [.9, 1.4, .9], (8192, 3))])
    comparisons = {}
    for age in (.12, .55, .135, .575):
        comparisons[str(age)] = metrics(field(probes, age, noise), sample(atlas, age, probes))
    # 모든 프레임 경계에서 시간 보간이 정확한 frame을 선택하는지 검증.
    frame_error = 0.0
    for i, age in enumerate(TIMES):
        frame_error = max(frame_error, float(np.abs(sample(atlas, age, probes[:128])
                            - sample_frame(atlas, i, probes[:128])).max()))
    assert frame_error < 1e-12
    # 서로 완전히 다른 sentinel brick: 경계면·바깥 좌표에서도 다른 frame 혼입 금지.
    sentinel = np.zeros_like(atlas)
    corners = np.array([[x, y, z] for x in (LOW[0] - 1, LOW[0], HIGH[0], HIGH[0] + 1)
                        for y in (LOW[1] - 1, LOW[1], HIGH[1], HIGH[1] + 1)
                        for z in (LOW[2] - 1, LOW[2], HIGH[2], HIGH[2] + 1)])
    for i in range(32):
        bx, by, bz = i % 4, (i // 4) % 4, i // 16
        sentinel[bz * GRID:(bz + 1) * GRID, by * GRID:(by + 1) * GRID,
                 bx * GRID:(bx + 1) * GRID] = [i * 7, 255 - i * 7, i * 3, i * 5]
    for i in range(32):
        expected = decode(np.array([i * 7, 255 - i * 7, i * 3, i * 5]))
        np.testing.assert_allclose(sample_frame(sentinel, i, corners), np.broadcast_to(expected, (64, 3)), atol=1e-12)
    payload = atlas.tobytes()
    assert len(payload) == 14_155_776
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'cannon_field.bin').write_bytes(payload)
    metadata = {'version': 1, 'gridSize': GRID, 'atlasBricks': BRICKS.tolist(),
                'boundsMin': LOW.tolist(), 'boundsMax': HIGH.tolist(), 'times': TIMES.tolist(),
                'densityScale': DENSITY_SCALE, 'emissionScale': EMISSION_SCALE,
                'byteLength': len(payload), 'sha256': hashlib.sha256(payload).hexdigest(),
                'channels': {'R': 'density uint16 high byte', 'G': 'density uint16 low byte',
                             'B': 'emission unorm8 times emissionScale', 'A': 'heat unorm8'},
                'voxelOrder': 'x-fastest, then y, then z, interleaved RGBA',
                'gridSampling': 'inclusive endpoints; clamp each frame to its texel centers',
                'canonicalAngle': 0, 'flashIncluded': False}
    (OUTPUT / 'cannon_field.json').write_text(json.dumps(metadata, indent=2) + '\n')
    report = {'sourceSnapshot': 'procedural_source.dart.txt',
              'sourceSha256': hashlib.sha256((HERE / 'procedural_source.dart.txt').read_bytes()).hexdigest(),
              'noiseSha256': hashlib.sha256(noise_bytes).hexdigest(),
              'channelOrder': ['density', 'emission', 'heat'],
              'clippedVoxelCount': 0,
              'analyticalUpperBoundsWithoutFlash': [46.98, 24, 1],
              'analyticalBoundsReason': 'noise/grain in [0,1]; dirt<=1.36, smoke<=1.25; fireJets<=1; all remaining density factors in [0,1]',
              'maxQuantizationAbsoluteError': max_quant.tolist(),
              'quantizationErrorLimit': bound.tolist(),
              'frameBoundaryMaximumError': frame_error,
              'sentinelBrickIsolationChecks': 32 * 64,
              'sourceComparisons': comparisons, 'frames': frame_stats,
              'probePoints': [[0, .07, 0], [.4, .2, 0], [0, .8, 0], [1.1, .45, .1]],
              'limitations': ['Spatial/time interpolation approximates the procedural field; this is not a pixel-equivalence or mobile performance test.',
                             'Canonical whole-field rotation changes the original pre-rotation noise layout.',
                             'Tiny analytic flash excluded; restore in runtime after cache sampling.']}
    report['probes'] = {str(age): {'source': field(np.array(report['probePoints']), age, noise).tolist(),
                                'cached': sample(atlas, age, np.array(report['probePoints'])).tolist()}
                        for age in (.12, .55)}
    (HERE / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'asset': str(OUTPUT / 'cannon_field.bin'), 'byteLength': len(payload),
                      'sha256': metadata['sha256'], 'maxQuantizationError': max_quant.tolist(),
                      'sourceComparisons': comparisons}, indent=2), flush=True)


if __name__ == '__main__':
    main()

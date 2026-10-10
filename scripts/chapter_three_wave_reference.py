#!/usr/bin/env python3
"""Render the reviewable 200-wave reference from canonical source; never author here."""
import argparse
from pathlib import Path
from content_compiler import ROOT, compile_content

TARGET = Path('design/chapter3_map_expansion/waves.md')
NAMES = {'normal':'일반', 'armored':'장갑병', 'shielded':'보호막병', 'fast':'빠른 적',
         'tank':'탱커', 'forgeBoss':'파쇄자'}


def group_dispatches(wave, initial_delay):
    """Read compiler-owned chronological metadata; no event reconstruction/sort."""
    return [{'group': wave['groups'][row['groupIndex']],
             'groupId': row['groupId'], 'spawnPortalId': row['spawnPortalId'],
             'requested': row['requestedDispatch'] + initial_delay,
             'first': row['firstDispatch'] + initial_delay, 'last': row['lastDispatch'] + initial_delay,
             'spawnIndices': row['spawnIndices']}
            for row in wave['groupDispatch']]


def reference_text():
    game = compile_content()
    text = '# 챕터 3 추가 맵: 전체 200라운드\n\n'
    text += ('역할: [설계 요약](README.md)의 검토용 전체 라운드 표. '
             '수정 원본은 `godot/content/source/stages/026.json`~`030.json`이다. '
             '`python3 scripts/chapter_three_wave_reference.py`로 다시 생성하고 `--check`로 최신성을 검사한다.\n\n'
             '묶음 표기는 **실제 첫 출현초(요청초, 다를 때): 적×수량 @요청 개체간격초 →경로**다. '
             f'첫 출현과 괄호의 요청초는 모두 웨이브 시작 기준이며 기본 준비 지연 {game["defaults"]["initialDelay"]:.1f}초를 포함한다. '
             '실제 첫 출현초는 컴파일러의 groupDispatch 메타데이터를 그대로 사용하며 전역 최소 간격0.18초 정규화 결과다. 같은 요청 시각은 원본 그룹/개체 순서를 유지한다. '
             '@간격은 제작 요청값이므로 겹치는 묶음 때문에 실제 개체 간격은 달라질 수 있다. '
             '이는 1배속 기준 예약 시각이며 실행 프레임 지연·일시정지·배속에 따른 실제 벽시계 출현 시각을 측정한 값은 아니다. '
             '출현 폭은 정규화한 첫 적~마지막 적이며 클리어 시간·전투 난이도 측정이 아니다.\n\n')
    for stage in game['stages']:
        if stage['id'] not in range(26,31): continue
        labels = {r['id']:r['label'] for r in stage['map'].get('routes',[])}
        text += f"## 3-{stage['id']-20} {stage['name']} · 고정 ID{stage['id']}\n\n"
        text += '| 라운드 | 적 수 | 출현 폭 | 클리어 골드 | 출현 묶음(시작시각순) |\n| --- | --- | --- | --- | --- |\n'
        for wave in stage['waves']:
            dispatches = group_dispatches(wave, game['defaults']['initialDelay'])
            cells = []
            for dispatch in dispatches:
                group = dispatch['group']
                route = ' →'+labels[group['routeId']] if 'routeId' in group else ''
                route += ' [입구 '+dispatch['spawnPortalId']+']'
                timing = f"{dispatch['first']:.3f}s"
                if abs(dispatch['first'] - dispatch['requested']) > 1e-8:
                    timing += f"(요청{dispatch['requested']:.3f}s)"
                cells.append(f"{timing}: {NAMES[group['enemyType']]}×{group['count']} @요청{group['interval']:g}s{route}")
            queue = wave['spawnQueue']
            text += (f"| {wave['round']} | {len(queue)} | {queue[-1]['delay']-queue[0]['delay']:.3f}s | "
                     f"{wave['clearRewardGold']}G | "+'; '.join(cells)+' |\n')
        text += '\n'
    return text.rstrip()+"\n"


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    expected=reference_text();target=ROOT/TARGET
    if args.check:
        if not target.exists() or target.read_text(encoding='utf-8')!=expected:
            raise SystemExit(f'Stale wave reference: run {Path(__file__).name}')
    else:
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(expected,encoding='utf-8')
    print('PASS chapter-three wave reference: 200 rounds')


if __name__=='__main__':main()

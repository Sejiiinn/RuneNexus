#!/usr/bin/env python3
"""Compatibility command: compile all stages from editable sources only.

Use content_compiler.py --check to verify output freshness without writing.
"""
from content_compiler import ROOT, compile_content, write_generated


def materialize(game=None, root=ROOT):
    # A former generated argument is accepted for old callers, never as source.
    result = compile_content(root)
    if game is not None:
        ids = [stage['id'] for stage in game.get('stages', [])]
        if ids != [stage['id'] for stage in result['stages']]:
            raise ValueError('Input stage inventory differs from the source registry')
    return result


def apply():
    write_generated()


if __name__ == '__main__':
    apply()

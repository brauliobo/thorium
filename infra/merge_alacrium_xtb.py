#!/usr/bin/env python3
"""Splice Alacrium <translation> additions into Chromium's .xtb bundles.

For every file `src/chrome/app/resources/alacrium_additions/<basename>.add`,
find the matching `$CR_SRC_DIR/chrome/app/resources/<basename>`, and insert
the additions before the closing `</translationbundle>` tag.

Runs after `setup.sh` overlay, replacing the legacy
`other/multi-language-translate.patch`. Idempotent: additions already present
(matched by translation id) are skipped.

Invocation:
    python3 infra/merge_alacrium_xtb.py $CR_SRC_DIR
"""

import os
import re
import sys

ID_RE = re.compile(r'<translation id="([^"]+)"')


def parse_ids(text):
    return set(ID_RE.findall(text))


def merge(additions_dir, cr_src):
    dst_root = os.path.join(cr_src, 'chrome/app/resources')
    total_added = 0
    touched = 0
    skipped_missing = 0

    for name in sorted(os.listdir(additions_dir)):
        if not name.endswith('.add'):
            continue
        add_path = os.path.join(additions_dir, name)
        target = os.path.join(dst_root, name[:-4])  # drop .add
        if not os.path.exists(target):
            skipped_missing += 1
            print(f'skip (no upstream): {name[:-4]}', file=sys.stderr)
            continue

        with open(target, encoding='utf-8') as fh:
            current = fh.read()
        existing_ids = parse_ids(current)

        with open(add_path, encoding='utf-8') as fh:
            add_lines = [ln for ln in fh.read().splitlines() if ln.strip()]

        new_lines = [ln for ln in add_lines
                     if (m := ID_RE.search(ln)) and m.group(1) not in existing_ids]
        if not new_lines:
            continue

        close = '</translationbundle>'
        idx = current.rfind(close)
        if idx < 0:
            print(f'WARNING: no </translationbundle> in {target}', file=sys.stderr)
            continue
        merged = current[:idx] + '\n'.join(new_lines) + '\n' + current[idx:]
        with open(target, 'w', encoding='utf-8') as fh:
            fh.write(merged)
        total_added += len(new_lines)
        touched += 1

    print(f'merged Alacrium translations: {total_added} lines into {touched} files'
          f' ({skipped_missing} locales absent upstream)')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('usage: merge_alacrium_xtb.py <CR_SRC_DIR>', file=sys.stderr)
        sys.exit(1)
    here = os.path.dirname(os.path.abspath(__file__))
    additions = os.path.join(os.path.dirname(here), 'src/chrome/app/resources/alacrium_additions')
    merge(additions, sys.argv[1])

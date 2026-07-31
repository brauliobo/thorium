#!/usr/bin/env python3
"""Extract Alacrium-branded <translation> additions from the legacy
`other/multi-language-translate.patch` into standalone add-files, one per
upstream .xtb target, so the monolithic patch can be dropped.

Invocation (run once, output is committed):
    python3 infra/extract_alacrium_xtb.py other/multi-language-translate.patch \
        src/chrome/app/resources/alacrium_additions/

Each generated file contains only the Alacrium-added <translation> lines for
a given locale/bundle. `infra/merge_alacrium_xtb.py` splices them back into
Chromium's current .xtb files at build time.
"""

import os
import re
import sys

HUNK_RE = re.compile(r'^@@ ')
DIFF_RE = re.compile(r'^diff --git a/(\S+) b/(\S+)$')


def extract(patch_path, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    current_target = None
    in_hunk = False
    per_file = {}

    with open(patch_path, encoding='utf-8') as fh:
        for line in fh:
            m = DIFF_RE.match(line)
            if m:
                current_target = m.group(2)
                in_hunk = False
                per_file.setdefault(current_target, [])
                continue
            if HUNK_RE.match(line):
                in_hunk = True
                continue
            if not in_hunk or current_target is None:
                continue
            if line.startswith('+++'):
                continue
            if line.startswith('+'):
                body = line[1:].rstrip('\n')
                # Only keep <translation ...> lines; skip whitespace-only +s.
                if '<translation' in body:
                    per_file[current_target].append(body)

    for target, lines in per_file.items():
        if not lines:
            continue
        basename = os.path.basename(target)
        out_path = os.path.join(out_dir, basename + '.add')
        with open(out_path, 'w', encoding='utf-8') as out:
            out.write('\n'.join(lines) + '\n')
        print(f'wrote {out_path} ({len(lines)} translations)')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('usage: extract_alacrium_xtb.py <patch> <out_dir>', file=sys.stderr)
        sys.exit(1)
    extract(sys.argv[1], sys.argv[2])

#!/usr/bin/env python3
"""Extract every `new file mode` section from a unified patch and write each
as a standalone file under <out_root>/<patch path>. Used to migrate
file-creation hunks out of monolithic patches into Thorium's `src/` overlay
so they survive Chromium upstream drift.

Usage:
    python3 infra/extract_new_files_from_patch.py <patch> <out_root>
"""

import os
import re
import sys

DIFF_RE = re.compile(r'^diff --git a/(\S+) b/(\S+)$')
NEW_FILE_RE = re.compile(r'^new file mode ')
HUNK_RE = re.compile(r'^@@ -0,0 \+(\d+),(\d+) @@')


def extract(patch_path, out_root):
    with open(patch_path, encoding='utf-8', errors='replace') as fh:
        lines = fh.readlines()

    count = 0
    i = 0
    while i < len(lines):
        m = DIFF_RE.match(lines[i])
        if not m:
            i += 1
            continue
        target = m.group(2)
        # Peek forward looking for `new file mode`, stopping at the next diff.
        is_new = False
        j = i + 1
        while j < len(lines) and not DIFF_RE.match(lines[j]):
            if NEW_FILE_RE.match(lines[j]):
                is_new = True
            if HUNK_RE.match(lines[j]):
                break
            j += 1
        if not is_new:
            i = j
            continue
        # j is now the @@ -0,0 +N line (or off the end). Collect + lines.
        body = []
        while j < len(lines) and not DIFF_RE.match(lines[j]):
            if lines[j].startswith('+') and not lines[j].startswith('+++'):
                body.append(lines[j][1:])
            j += 1
        out = os.path.join(out_root, target)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, 'w', encoding='utf-8') as fh:
            fh.writelines(body)
        count += 1
        print(f'wrote {out} ({len(body)} lines)')
        i = j

    print(f'extracted {count} new files into {out_root}')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('usage: extract_new_files_from_patch.py <patch> <out_root>', file=sys.stderr)
        sys.exit(1)
    extract(sys.argv[1], sys.argv[2])

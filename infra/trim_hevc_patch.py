#!/usr/bin/env python3
"""Remove cosmetic `FFMPEG_CONFIGURATION` comment-string hunks from
add-hevc-ffmpeg-decoder-parser.patch. Those hunks add "hevc" to a purely
informational C comment and are the only ones that break every ffmpeg roll.

Writes back in place. Re-run after ffmpeg rolls if the same pattern returns.
"""

import re
import sys

HUNK_START = re.compile(r'^@@ ')
FILE_START = re.compile(r'^diff --git ')


def is_configuration_hunk(lines):
    return any('FFMPEG_CONFIGURATION' in ln for ln in lines)


def strip(path):
    with open(path, encoding='utf-8') as fh:
        src = fh.readlines()

    out = []
    i = 0
    dropped = 0
    while i < len(src):
        ln = src[i]
        if HUNK_START.match(ln):
            # collect hunk body until next @@ or diff --git
            j = i + 1
            while j < len(src) and not HUNK_START.match(src[j]) and not FILE_START.match(src[j]):
                j += 1
            hunk = src[i:j]
            if is_configuration_hunk(hunk):
                dropped += 1
            else:
                out.extend(hunk)
            i = j
        else:
            out.append(ln)
            i += 1

    with open(path, 'w', encoding='utf-8') as fh:
        fh.writelines(out)
    print(f'{path}: dropped {dropped} FFMPEG_CONFIGURATION hunks')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('usage: trim_hevc_patch.py <patch>', file=sys.stderr)
        sys.exit(1)
    strip(sys.argv[1])

#!/usr/bin/env python3
"""Remove references to components deleted upstream in M147+ from Thorium's
overlay `.gn` files: NaCl (//components/nacl, //native_client_sdk) and
PPAPI (//ppapi, enable_ppapi).

Deletes:
  - `import("//components/nacl/features.gni")` / `import("//ppapi/...")` lines.
  - `if (enable_nacl) { ... }` and `if (enable_ppapi) { ... }` blocks
    (brace-balanced).
  - Lines containing `//components/nacl`, `//native_client_sdk`, `//ppapi`
    inside dep lists (simple scan — safe because dep lists are one entry
    per line in Thorium's overlay).

Arg: one or more `.gn`/`.gni` files. Writes back in place.
"""

import re
import sys

DEAD_IMPORTS = re.compile(
    r'^\s*import\("//(components/nacl|ppapi)/[^"]+"\)\s*$'
)
DEAD_IF = re.compile(r'^(\s*)if\s*\(\s*enable_(nacl|ppapi)\s*[^)]*\)\s*\{\s*$')
DEAD_PATH = re.compile(r'"//(components/nacl|native_client_sdk|ppapi)[/":]')


def strip(path):
    with open(path, encoding='utf-8') as fh:
        src = fh.readlines()

    out = []
    i = 0
    while i < len(src):
        ln = src[i]
        if DEAD_IMPORTS.match(ln):
            i += 1
            continue
        m = DEAD_IF.match(ln)
        if m:
            # Consume a brace-balanced block starting on this line.
            depth = ln.count('{') - ln.count('}')
            j = i + 1
            while j < len(src) and depth > 0:
                depth += src[j].count('{') - src[j].count('}')
                j += 1
            # Also eat a trailing `else { ... }` if present.
            k = j
            while k < len(src) and src[k].strip() == '':
                k += 1
            if k < len(src) and re.match(r'^\s*else\s*[\{]', src[k]):
                depth = src[k].count('{') - src[k].count('}')
                k += 1
                while k < len(src) and depth > 0:
                    depth += src[k].count('{') - src[k].count('}')
                    k += 1
                j = k
            i = j
            continue
        if DEAD_PATH.search(ln):
            i += 1
            continue
        out.append(ln)
        i += 1

    with open(path, 'w', encoding='utf-8') as fh:
        fh.writelines(out)
    delta = len(src) - len(out)
    print(f'{path}: removed {delta} lines')


if __name__ == '__main__':
    for p in sys.argv[1:]:
        strip(p)

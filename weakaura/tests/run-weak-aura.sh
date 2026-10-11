#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import re
import subprocess
import zlib

alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789()'
text = Path('weak-aura-string.txt').read_text().strip()
assert text.startswith('!WA:1!')
raw = bytearray()
value = bits = 0
for char in text[6:]:
    value |= alphabet.index(char) << bits
    bits += 6
    while bits >= 8:
        raw.append(value & 255)
        value >>= 8
        bits -= 8
payload = zlib.decompress(raw, -15).decode()
assert payload.startswith('^1') and payload.endswith('^^')

def code(key):
    matches = re.findall(r'\^S' + key + r'\^S([^\^]*)', payload)
    assert len(matches) == 1
    escaped = matches[0]
    return re.sub(r'~(.)', lambda match: {
        'z': chr(30), '{': chr(127), '|': '~', '}': '^'
    }.get(match[1], chr(ord(match[1]) - 64)), escaped)

subprocess.run(['lua', 'tests/weak-aura.lua'],
    input='{trigger=' + code('custom') + ',text=' + code('customText') + '}',
    text=True, check=True)
PY
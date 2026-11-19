#!/usr/bin/env python3
import sys

if len(sys.argv) < 2:
    sys.exit(1)

with open(sys.argv[1], 'rb') as f:
    data = f.read()

zero_pad = b'\x00'
for i in range(0, len(data), 4):
    chunk = data[i:i+4].ljust(4, zero_pad)
    word = int.from_bytes(chunk, 'little')
    print(f"{word:08x}")

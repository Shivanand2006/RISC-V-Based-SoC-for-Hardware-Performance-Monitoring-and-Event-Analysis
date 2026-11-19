#!/usr/bin/env python3
"""Convert Intel HEX bytes into little-endian 32-bit $readmemh words."""

import sys


def convert(source, destination):
    memory = {}
    upper = 0
    with open(source, encoding="ascii") as stream:
        for line_number, raw in enumerate(stream, 1):
            line = raw.strip()
            if not line:
                continue
            if not line.startswith(":"):
                raise ValueError(f"line {line_number}: expected Intel HEX record")
            record = bytes.fromhex(line[1:])
            count = record[0]
            address = (record[1] << 8) | record[2]
            kind = record[3]
            data = record[4:4 + count]
            checksum = record[4 + count]
            if (sum(record) & 0xFF) != 0:
                raise ValueError(f"line {line_number}: checksum mismatch")
            if kind == 0x00:
                base = upper + address
                for offset, value in enumerate(data):
                    memory[base + offset] = value
            elif kind == 0x01:
                break
            elif kind == 0x02:
                upper = int.from_bytes(data, "big") << 4
            elif kind == 0x04:
                upper = int.from_bytes(data, "big") << 16

    if not memory:
        raise ValueError("input contains no data records")
    first = min(memory)
    last = max(memory)
    if first < 0 or last >= 256 * 1024:
        raise ValueError(f"image range 0x{first:x}..0x{last:x} exceeds 256 KiB SRAM")

    first_word = first // 4
    last_word = last // 4
    with open(destination, "w", encoding="ascii") as output:
        output.write(f"@{first_word:08X}\n")
        for word_index in range(first_word, last_word + 1):
            value = sum(memory.get(word_index * 4 + lane, 0) << (8 * lane)
                        for lane in range(4))
            output.write(f"{value:08X}\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} input.hex output.memh")
    convert(sys.argv[1], sys.argv[2])

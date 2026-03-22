#!/usr/bin/env python3
import sys
from pathlib import Path

def main() -> int:
    if len(sys.argv) != 3:
        print("usage: bin2mem.py <input.bin> <output.mem>", file=sys.stderr)
        return 1

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])

    data = src.read_bytes()
    if len(data) % 4 != 0:
        data += b"\x00" * (4 - (len(data) % 4))

    with dst.open("w", encoding="utf-8") as f:
        for i in range(0, len(data), 4):
            word = int.from_bytes(data[i:i+4], byteorder="little", signed=False)
            f.write(f"{word:08x}\n")

    return 0

if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Checks a build of the host image without the flash chip over its UART1 TCP port: the command line knows no flash
command and its help lists none, and its resource command neither lists nor takes the flash chip's pin.

usage: host-flash-off-check.py <host image>"""
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("host_smoke", os.path.join(HERE, "host-smoke.py"))
hs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hs)

COMMANDS = ("flash_erase", "flash_info", "flash_read 0 16", "flash_scan", "flash_write 0 x")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    with tempfile.TemporaryDirectory() as work:
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "flashoff.bin"))
        try:
            hs.time.sleep(2.5)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            for command in COMMANDS:
                text = hs.cli(sock, command)
                hs.check(f"build without the flash chip knows no {command.split()[0]} command",
                         "UNKNOWN COMMAND" in text, text[-120:])
            text = hs.cli(sock, "help flash_")
            hs.check("help lists no flash command there", "NO MATCHES" in text, text[-120:])
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            hs.check("dump has no flash chip pin there",
                     any(line.startswith("resource MOTOR ") for line in lines)
                     and not any("FLASH_CS" in line for line in lines if "resource" in line))
            text = hs.cli(sock, "resource FLASH_CS A01")
            hs.check("resource takes no flash chip pin there", "INVALID RESOURCE NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-flash-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Checks a build of the host image without the flash chip over its UART1 TCP port: the command line knows no flash
command and its help lists none, its settings have no flash bus setting, its resource command neither lists nor
takes the flash chip's pin, and MSP answers flash erase as unknown.

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
            hs.check("flash erase is refused as unknown there", hs.msp(sock, 72) is None)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            for command in COMMANDS:
                text = hs.cli(sock, command)
                hs.check(f"build without the flash chip knows no {command.split()[0]} command",
                         "UNKNOWN COMMAND" in text, text[-120:])
            text = hs.cli(sock, "help flash_")
            hs.check("help lists no flash command there", "NO MATCHES" in text, text[-120:])
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            names = [line.split()[1] for line in lines if line.startswith("set ") and len(line.split()) > 1]
            hs.check("dump has no flash bus setting there",
                     "blackbox_device" in names and "flash_spi_bus" not in names)
            text = hs.cli(sock, "get flash_spi_bus")
            hs.check("get finds no flash bus setting there", "INVALID NAME" in text, text[-120:])
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

#!/usr/bin/env python3
"""Checks a build of the host image without the LED strip over its UART1 TCP port: the command line knows no led,
color or mode_color command, its help lists none, its dumps have no LED sections, and its resource command neither
lists nor takes an LED strip pin.

usage: host-led-off-check.py <host image>"""
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("host_smoke", os.path.join(HERE, "host-smoke.py"))
hs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hs)


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    with tempfile.TemporaryDirectory() as work:
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "ledoff.bin"))
        try:
            hs.time.sleep(2.5)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            for word in ("led", "color", "mode_color"):
                text = hs.cli(sock, word)
                hs.check(f"build without the LED strip knows no '{word}' command", "UNKNOWN COMMAND" in text,
                         text[-120:])
            text = hs.cli(sock, "help color")
            hs.check("help lists no color command there", "NO MATCHES" in text, text[-120:])
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            hs.check("dump has no LED sections there",
                     any(line.startswith("aux ") for line in lines)
                     and not any(line.startswith(("led ", "color ", "mode_color ")) for line in lines),
                     repr([line for line in lines if line.startswith(("led", "color", "mode_color"))][:4]))
            hs.check("dump has no LED strip pin there",
                     any(line.startswith("resource MOTOR ") for line in lines)
                     and not any(line.startswith(("resource LED_STRIP ", "#resource LED_STRIP ")) for line in lines))
            text = hs.cli(sock, "resource LED_STRIP A01")
            hs.check("resource takes no LED strip pin there", "INVALID RESOURCE NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-led-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())

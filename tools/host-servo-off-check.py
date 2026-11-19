#!/usr/bin/env python3
"""Checks a build of the host image without servos over its UART1 TCP port: the command line knows no servo or
servo mixer command, its help lists neither, its dumps have no servo sections, and its resource command neither
lists nor takes a servo pin.

usage: host-servo-off-check.py <host image>"""
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
        proc, sock = hs.start(sys.argv[1], os.path.join(work, "servooff.bin"))
        try:
            hs.time.sleep(2.5)
            sock.sendall(b"#")
            hs.read_all(sock, 0.8)
            for word in ("servo", "smix", "smix reset"):
                text = hs.cli(sock, word)
                hs.check(f"build without servos knows no '{word}' command", "UNKNOWN COMMAND" in text, text[-120:])
            text = hs.cli(sock, "help servo")
            hs.check("help lists no servo command there", "NO MATCHES" in text, text[-120:])
            text = hs.cli(sock, "help mixer")
            hs.check("help still lists mixer commands there", "mmix" in text and "smix" not in text, text[-160:])
            lines = hs.cli(sock, "dump all", 4.0).splitlines()
            hs.check("dump has no servo sections there",
                     any(line.startswith("mmix ") or line == "mmix reset" for line in lines)
                     and not any(line.startswith(("servo ", "smix ", "# servo")) for line in lines),
                     repr([line for line in lines if "servo" in line][:4]))
            hs.check("dump has no servo pins there",
                     any(line.startswith("resource MOTOR ") for line in lines)
                     and not any(line.startswith(("resource SERVO ", "#resource SERVO ")) for line in lines))
            text = hs.cli(sock, "resource SERVO 1 A01")
            hs.check("resource takes no servo pin there", "INVALID RESOURCE NAME" in text, text[-120:])
            text = hs.cli(sock, "resource")
            hs.check("resource lists motor pins and no servo pin there",
                     "resource MOTOR 1 " in text and "SERVO" not in text, text[-160:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-servo-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Checks a build of the host image without the LED strip over its UART1 TCP port: the command line knows no led,
color or mode_color command, its help lists none, its dumps have no LED sections, its settings have no LED strip
setting, its resource command neither lists nor takes an LED strip pin, MSP has no LED reply, and MSP refuses
LED writes as unknown.

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
            kept = hs.msp2(sock, 0x3010, b"motor_pwm_protocol")
            hs.check("setting outside the LED strip reads by name over MSP there",
                     kept is not None and kept.startswith(b"motor_pwm_protocol = "), repr(kept))
            hs.check("LED strip setting has no name over MSP there", hs.msp2(sock, 0x3010, b"ledstrip_profile") is None)
            hs.check("motor reply still answers there", hs.msp(sock, 104) is not None)
            for command in (46, 48, 127):
                hs.check(f"MSP {command} has no LED reply there", hs.msp(sock, command) is None)
            hs.check("LED color write is refused as unknown there", hs.msp(sock, 47, bytes(64)) is None)
            hs.check("LED strip write is refused as unknown there", hs.msp(sock, 49, bytes(5)) is None)
            hs.check("LED mode color write is refused as unknown there", hs.msp(sock, 221, bytes(3)) is None)
            values = bytes([50]) + (10).to_bytes(2, "little") + (120).to_bytes(2, "little")
            hs.check("LED strip value write is refused as unknown there", hs.msp2(sock, 0x3009, values) is None)
            hs.check("LED strip values have no reply there", hs.msp2(sock, 0x3008) is None)
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
            names = [line.split()[1] for line in lines if line.startswith("set ") and len(line.split()) > 1]
            hs.check("dump has no LED strip settings there",
                     "motor_pwm_protocol" in names and not any(n.startswith("ledstrip_") for n in names),
                     repr([n for n in names if n.startswith("ledstrip_")][:4]))
            text = hs.cli(sock, "get ledstrip_profile")
            hs.check("get finds no LED strip setting there", "INVALID NAME" in text, text[-120:])
            text = hs.cli(sock, "set ledstrip_brightness = 50")
            hs.check("set refuses an LED strip setting there", "INVALID NAME" in text, text[-120:])
            text = hs.cli(sock, "resource LED_STRIP A01")
            hs.check("resource takes no LED strip pin there", "INVALID RESOURCE NAME" in text, text[-120:])
        finally:
            hs.stop(proc)
            sock.close()
    print("host-led-off-check: failures", len(hs.failures))
    return 1 if hs.failures else 0


if __name__ == "__main__":
    sys.exit(main())

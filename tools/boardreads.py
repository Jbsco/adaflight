#!/usr/bin/env python3
"""Check that the board sources name every field the MSP processor exchanges with a board.

usage: boardreads.py

The processor's Views record is what a board fills for the replies, its Effects record is what a board acts on
after a message, and its Context record is what a board reports for a request. A field of any that no source under
targets/ names is a reply or a decision that reads a default, or a write that does nothing. A field counts as
named when its path under Out_Views, Effects or Ctx appears in a target source, or when a record on that path is
assigned, renamed or passed whole. The fields in OPEN are known to have no reader, each with its reason. The check
fails on a field without a reader that OPEN does not list, and on a listed field that has gained one. Run from the
repository root.
"""
import pathlib
import re
import sys

CORE = pathlib.Path("core/src")
PROCESSOR = CORE / "adaflight-msp_processor.ads"

ALWAYS = "every board build contains it, as the default says"
FOLDED = "the processor folds it into an effect the boards read"
OPEN = {
    "Out_Views.Receiver.RC_Smoothing": ALWAYS,
    "Out_Views.Receiver.USB_HID": ALWAYS,
    "Out_Views.Hardware.DShot_Telemetry": ALWAYS,
    "Out_Views.Hardware.ESC_Sensor": ALWAYS,
    "Out_Views.Peripheral.Servo_Count": "the boards serve the default count",
    "Out_Views.Peripheral.VTX_Built": ALWAYS,
    "Out_Views.Peripheral.VTX_Table": ALWAYS,
    "Out_Views.Text.Table": ALWAYS,
    "Out_Views.Text.Build_Key.Present": "no board build has a build key",
    "Out_Views.Text.Build_Key.Value.Length": "no board build has a build key",
    "Out_Views.Text.Build_Key.Value.Data": "no board build has a build key",
    "Out_Views.Text.Release_Name.Present": "no board build has a release name",
    "Out_Views.Text.Release_Name.Value.Length": "no board build has a release name",
    "Out_Views.Text.Release_Name.Value.Data": "no board build has a release name",
    "Out_Views.OSD.OSD": ALWAYS,
    "Out_Views.OSD.Video_System_Option": ALWAYS,
    "Out_Views.OSD.Profiles": ALWAYS,
    "Out_Views.OSD.Stick_Overlay": ALWAYS,
    "Out_Views.OSD.Display_Port_Font": ALWAYS,
    "Out_Views.OSD.Frame_Buffer_OSD": ALWAYS,
    "Effects.Handled": "the caller reads the result instead",
    "Effects.Receiver.Adjustments_Reset": "the adjustment pass rebuilds its lists when the stored ranges change",
    "Effects.Peripheral.Transponder_Data": "no board has a transponder",
    "Effects.OSD.Profile": "the boards configure the OSD from the stored profile on Profile_Change",
    "Effects.OSD.Save": FOLDED,
    "Effects.OSD.Reboot": FOLDED,
    "Effects.Profile.PID_Profile": FOLDED,
    "Effects.Profile.Rate_Profile": FOLDED,
    "Effects.Profile.Battery_Profile": "the battery task reads its profile from the configuration at every pass",
    "Effects.VTX.VTX_Ready": FOLDED,
    "Effects.Board.Save": FOLDED,
    "Effects.Board.Reboot": FOLDED,
    "Effects.Board.Reply": "the processor writes the reply byte itself",
    "Effects.Board.Reply_Value": "the processor writes the reply byte itself",
    "Effects.Font.Size": "the boards write whole characters",
    "Effects.Passthrough_Mode": "not served: an ESC's serial link",
    "Ctx.Control.RX_SPI_Active": "not served: a save or a reboot from a telemetry link is not deferred",
    "Ctx.Control.MSC_Ready": "not served: no board has a mass storage mode",
}


def fields(text, type_name):
    """The components of a record type in a specification's text, as (name, type) pairs."""
    m = re.search(r"type " + re.escape(type_name) + r" is record(.*?)end record", text, re.S)
    if not m:
        return []
    found = []
    for line in m.group(1).split("\n"):
        component = re.match(r"\s+(\w+)\s*:\s*([\w.]+)", line)
        if component:
            found.append((component.group(1), component.group(2)))
    return found


def spec_of(type_ref, home):
    """The specification text a type reference names, and its bare type name."""
    if "." not in type_ref:
        return home, type_ref
    unit, name = type_ref.rsplit(".", 1)
    path = CORE / ("adaflight-" + unit.replace("Adaflight.", "").lower().replace(".", "-") + ".ads")
    return (path.read_text() if path.exists() else ""), name


def leaves(path, type_ref, home, depth=0):
    """The scalar fields under a field, each as its path of names."""
    text, name = spec_of(type_ref, home)
    components = fields(text, name) if text else []
    if not components or depth > 2:
        return [path]
    found = []
    for field, field_type in components:
        found += leaves(path + [field], field_type, text, depth + 1)
    return found


def named(targets, root, path):
    """Whether a target source names the field, or assigns, renames or passes a record on its path whole."""
    if re.search(root + r"\." + r"\.".join(path) + r"\b", targets):
        return True
    for k in range(len(path) - 1, 0, -1):
        whole = root + r"\." + r"\.".join(path[:k])
        if re.search(whole + r"\s*(:=|\)|,|;)", targets):
            return True
    return False


def main():
    if len(sys.argv) != 1 or not PROCESSOR.exists():
        raise SystemExit(__doc__)
    processor = PROCESSOR.read_text()
    targets = "\n".join(p.read_text() for p in sorted(pathlib.Path("targets").glob("*/src/*.ad[sb]")))
    without = set()
    for root, record in (("Out_Views", "Views"), ("Effects", "Effects"), ("Ctx", "Context")):
        for field, field_type in fields(processor, record):
            if (root, field) == ("Ctx", "Out_Views"):
                continue
            for path in leaves([field], field_type, processor):
                if not named(targets, root, path):
                    without.add(root + "." + ".".join(path))
    problems = [f"{name}: no board source names it" for name in sorted(without - set(OPEN))]
    problems += [f"{name}: listed as open, and a board source names it now" for name in sorted(set(OPEN) - without)]
    for line in problems:
        print("  " + line)
    if problems:
        return 1
    print("  clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())

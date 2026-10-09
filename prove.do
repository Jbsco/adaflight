#!/bin/bash
# SPARK proof gate over the core. Counts unproved checks and pragma Assume
# occurrences on every run, so a weakened claim is visible immediately.
exec >&2
if ! command -v alr >/dev/null 2>&1; then
    echo "alr (Alire) not found - skipping SPARK proofs"
    [ -n "${3:-}" ] && touch "$3"
    exit 0
fi
cd core || exit 1
# Regenerate the crate configuration so the proof runs under the development
# profile whatever a dependent crate's build left behind.
alr -n build --stop-after=generation >/dev/null 2>&1
echo "Running SPARK proofs..."
# PROVE_JOBS caps the prover parallelism on hosts that share their memory; the default
# uses every core.
# The transcript is echoed through the inherited stderr; reopening /dev/stderr would
# truncate a log the caller redirected it to.
# PROVE_SWITCHES adds switches after the project file's, so a host can trade time for
# the memory and speed it lacks.
PROVE_OUT=$(alr -n exec -- gnatprove -P adaflight_core.gpr -j"${PROVE_JOBS:-0}" ${PROVE_SWITCHES:-} --output=oneline 2>&1 | tee >(cat >&2))
EXIT_CODE=${PIPESTATUS[0]}
if [ $EXIT_CODE -ne 0 ]; then
    echo "=========================================="
    echo "SPARK proofs: gnatprove FAILED (exit $EXIT_CODE)"
    echo "  (any summary on disk is from a previous run and is not evidence)"
    echo "=========================================="
    exit $EXIT_CODE
fi
# The summary lands under the active build profile; read the path the tool printed.
SUMMARY=$(printf '%s\n' "$PROVE_OUT" | sed -n 's/^Summary logged in //p' | tail -1)
[ -z "$SUMMARY" ] && SUMMARY=obj/development/gnatprove/gnatprove.out
echo "=========================================="
if [ -f "$SUMMARY" ]; then
    TOTAL=$(awk '/^Total/ {print $2; exit}' "$SUMMARY")
    UNPROVED=$(awk '/^Total/ {print ($NF == "." ? 0 : $(NF - 1)); exit}' "$SUMMARY")
    if [ "$UNPROVED" = "0" ]; then
        echo "SPARK proofs: core 100% proved (${TOTAL:-?} checks)"
    else
        echo "SPARK proofs: $UNPROVED of ${TOTAL:-?} checks UNPROVED"
        exit 1
    fi
    ASSUMES=$(grep -h "pragma Assume" src/*.adb src/*.ads 2>/dev/null | wc -l)
    JUSTIFIED=$(grep -h "pragma Annotate (GNATprove" src/*.adb src/*.ads 2>/dev/null | wc -l)
    OFF=$(grep -l "SPARK_Mode => Off" src/*.adb 2>/dev/null | wc -l)
    echo "  ($ASSUMES pragma Assume, $JUSTIFIED justified check(s), $OFF body(ies) outside SPARK)"
else
    echo "Summary file not found: $SUMMARY"
    exit 1
fi
echo "=========================================="
[ -n "${3:-}" ] && touch "../$3"
exit 0

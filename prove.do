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
echo "Running SPARK proofs..."
alr -n exec -- gnatprove -P adaflight_core.gpr -j0 --output=oneline
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "=========================================="
    echo "SPARK proofs: gnatprove FAILED (exit $EXIT_CODE)"
    echo "  (any summary on disk is from a previous run and is not evidence)"
    echo "=========================================="
    exit $EXIT_CODE
fi
SUMMARY=obj/development/gnatprove/gnatprove.out
echo "=========================================="
if [ -f "$SUMMARY" ]; then
    TOTAL=$(awk '/^Total/ {print $2; exit}' "$SUMMARY")
    UNPROVED=$(awk '/^Total/ {print $NF; exit}' "$SUMMARY")
    [ "$UNPROVED" = "." ] && UNPROVED=0
    if [ "$UNPROVED" = "0" ]; then
        echo "SPARK proofs: core 100% proved (${TOTAL:-?} checks)"
    else
        echo "SPARK proofs: $UNPROVED of ${TOTAL:-?} checks UNPROVED"
        exit 1
    fi
    ASSUMES=$(grep -h "pragma Assume" src/*.adb src/*.ads 2>/dev/null | wc -l)
    JUSTIFIED=$(grep -h "pragma Annotate (GNATprove" src/*.adb src/*.ads 2>/dev/null | wc -l)
    echo "  ($ASSUMES pragma Assume, $JUSTIFIED justified check(s))"
else
    echo "Summary file not found: core/$SUMMARY"
    exit 1
fi
echo "=========================================="
[ -n "${3:-}" ] && touch "../$3"
exit 0

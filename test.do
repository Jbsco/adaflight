#!/bin/bash
# Vector gate: the core reproduces every recorded reference result bit for
# bit, except where a tolerance is declared in the checker.
exec >&2
if ! command -v alr >/dev/null 2>&1; then
    echo "test: alr not found - skipping vector check"
    [ -n "${3:-}" ] && touch "$3"
    exit 0
fi
cd tests || exit 1
alr -n build >/dev/null 2>&1 || { alr -n build; exit 1; }
# The checker's tables fill most of a default 8 MB stack, so it runs with a larger one where a host allows it.
ulimit -s 65536 2>/dev/null || :
./bin/vector_check vectors || exit 1
cd ../tools/dfu/tests || exit 1
alr -n build >/dev/null 2>&1 || { alr -n build; exit 1; }
./bin/dfu_check || exit 1
cd ../../msp/tests || exit 1
alr -n build >/dev/null 2>&1 || { alr -n build; exit 1; }
./bin/msp_check || exit 1
cd ../../.. || exit 1
python3 tools/boardgen-check.py tests/vectors/gyrodev.csv || exit 1
python3 tools/boardgen-check.py tests/vectors/boarddrv.csv || exit 1
python3 tools/boardgen-check.py tests/vectors/boardpins.csv || exit 1
[ -n "${3:-}" ] && touch "$3"
exit 0

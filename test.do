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
./bin/vector_check vectors || exit 1
[ -n "${3:-}" ] && touch "../$3"
exit 0

#!/bin/bash
# Style and hygiene gate: Ada style warnings from a fresh compile, markdown
# that renders in the local viewer, and no local paths or private material.
exec >&2
FAIL=0

echo "== 1/3  Ada style"
if command -v alr >/dev/null 2>&1; then
    for crate in core tests; do
        (cd "$crate" && alr -n clean >/dev/null 2>&1)
        OUT=$(cd "$crate" && alr -n build 2>&1)
        N=$(printf '%s\n' "$OUT" | grep -c '(style)\|warning:')
        if [ "$N" != "0" ]; then
            echo "  $crate: $N style warning(s):"
            printf '%s\n' "$OUT" | grep '(style)\|warning:' | sed 's/^/    /'
            FAIL=1
        else
            echo "  $crate: clean"
        fi
    done
else
    echo "  alr not found - skipped"
fi

echo "== 2/3  Markdown renders in the local viewer"
MD=$(git ls-files '*.md')
if [ -n "$MD" ] && command -v markdown >/dev/null 2>&1; then
    if python3 tools/mdlint.py $MD; then
        echo "  clean"
    else
        FAIL=1
    fi
else
    echo "  markdown renderer not found - skipped"
fi

echo "== 3/3  Content sanitization"
PATHS=$(git ls-files -z | xargs -0 grep -nE '~/|/home/[a-z]+/' 2>/dev/null \
        | grep -v '^style.do:' | grep -v '^.github/workflows/' || true)
if [ -n "$PATHS" ]; then
    echo "  local path reference(s):"
    echo "$PATHS" | sed 's/^/    /'
    FAIL=1
fi
# The settings table and its vectors keep the reference's lookup strings verbatim, and two of
# the gated names stand in them as whole upper-case strings (DESIGN.md D2); nothing else may.
VERBATIM='core/src/adaflight-settings_table.adb tests/vectors/settings.csv'
LEAK=$(git ls-files -z | xargs -0 grep -nliE 'betaflight|cleanflight|inav|ema-gnc|lasp' 2>/dev/null \
       | grep -v '^style.do$' | grep -v '^README.md$' | grep -v '^DESIGN.md$' | grep -v '^ROADMAP.md$' \
       | grep -vxF -e core/src/adaflight-settings_table.adb -e tests/vectors/settings.csv || true)
for f in $VERBATIM; do
    if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
        EXTRA=$(grep -noiE 'betaflight|cleanflight|inav|ema-gnc|lasp' "$f" | grep -vE ':(BETAFLIGHT|INAV)$' || true)
        [ -n "$EXTRA" ] && LEAK="$LEAK${LEAK:+
}$f"
    fi
done
if [ -n "$LEAK" ]; then
    echo "  reference to another project outside the README, the roadmap and the design ledger:"
    echo "$LEAK" | sed 's/^/    /'
    FAIL=1
fi
[ -z "$PATHS$LEAK" ] && echo "  clean"

echo "=========================================="
if [ "$FAIL" != "0" ]; then
    echo "style: FAILED"
    exit 1
fi
echo "style: all checks clean"
echo "=========================================="
[ -n "${3:-}" ] && touch "$3"
exit 0

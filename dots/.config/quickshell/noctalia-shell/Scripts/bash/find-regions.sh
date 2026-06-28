#!/usr/bin/env bash
# Content-region detection wrapper for the native region selector.
# Finds a Python with opencv (ximgproc / selective search), runs find_regions.py,
# and ALWAYS prints valid JSON ("[]" on any failure) so the QML parser is safe.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/find_regions.py"

# Candidate interpreters, in priority order:
#   1. dedicated noctalia venv (self-contained)
#   2. ii's existing opencv venv (env var or default path)
#   3. system python3
CANDIDATES=(
    "$HOME/.local/state/quickshell/noctalia-region-venv/bin/python"
    "${ILLOGICAL_IMPULSE_VIRTUAL_ENV/#\~/$HOME}/bin/python"
    "$HOME/.local/state/quickshell/.venv/bin/python"
    "python3"
)

PY=""
for cand in "${CANDIDATES[@]}"; do
    [ -z "$cand" ] && continue
    if command -v "$cand" >/dev/null 2>&1 || [ -x "$cand" ]; then
        if "$cand" -c "import cv2; cv2.ximgproc" >/dev/null 2>&1; then
            PY="$cand"
            break
        fi
    fi
done

if [ -z "$PY" ]; then
    echo "[]"
    exit 0
fi

out="$("$PY" "$PY_SCRIPT" "$@" 2>/dev/null)"
if [ -z "$out" ]; then
    echo "[]"
else
    echo "$out"
fi

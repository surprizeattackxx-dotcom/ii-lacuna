#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${ILLOGICAL_IMPULSE_VIRTUAL_ENV/#\~/$HOME}/bin/activate"
"$SCRIPT_DIR/text_color.py" "$@"
deactivate

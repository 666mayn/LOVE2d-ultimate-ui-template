#!/usr/bin/env bash
# Run the template with the dev sandbox enabled, from anywhere (Linux / macOS).
# Usage: sandbox/run.sh [extra love args]
set -eu

if ! command -v love >/dev/null 2>&1; then
    echo "run.sh: 'love' not found on PATH. Install LOVE 11.x (https://love2d.org)." >&2
    echo "        macOS: brew install --cask love   |  Linux: your package manager or AppImage" >&2
    exit 127
fi

# Resolve the project root (two folders above sandbox/: ultimate_ui/sandbox -> project) even when
# called via a symlink. If you moved ultimate_ui/ somewhere deeper, just run `love . --sandbox`.
src="${BASH_SOURCE[0]}"
while [ -h "$src" ]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    case "$src" in /*) ;; *) src="$dir/$src" ;; esac
done
here="$(cd -P "$(dirname "$src")" && pwd)"

exec love "$here/../.." --sandbox "$@"

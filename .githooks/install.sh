#!/bin/sh
set -eu
cd "$(git rev-parse --show-toplevel)"
command -v python3 >/dev/null 2>&1 || { echo 'Python 3 is required for the file-size hook.' >&2; exit 1; }
current=$(git config --get core.hooksPath || true)
hook_dir="$(pwd -P)/.githooks"
if [ -n "$current" ] && [ "$current" != '.githooks' ] && [ "$current" != "$hook_dir" ]; then
    echo "Existing core.hooksPath=$current; add the .githooks/pre-commit check to that hook instead of replacing it." >&2
    exit 1
fi
legacy=$(git rev-parse --git-path hooks/pre-commit)
if [ -z "$current" ] && [ -x "$legacy" ]; then
    echo "Existing $legacy; add the .githooks/pre-commit check to that hook instead of replacing it." >&2
    exit 1
fi
git config --local core.hooksPath "$hook_dir"
echo 'Installed staged file-size hook (5,000 tokens = 20,000 bytes).'

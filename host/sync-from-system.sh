#!/bin/sh
# Copy the live host config listed in files.txt into ./files/ (run after any
# host change, then review `git diff` and commit). Refuses obvious secrets.
set -eu
cd "$(dirname "$0")"
missing=0
grep -vE '^\s*(#|$)' files.txt | while read -r f; do
    case "$f" in *telegram.env|*password*|*.env) echo "refusing secret-looking path: $f" >&2; exit 1 ;; esac
    if sudo test -f "$f"; then
        mkdir -p "files$(dirname "$f")"
        sudo cat "$f" > "files$f"
    else
        echo "missing on system: $f" >&2
    fi
done
# a file must never contain a Telegram token / private key
if grep -rIlE '[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}|BEGIN [A-Z ]*PRIVATE KEY' files/ 2>/dev/null; then
    echo "SECRET DETECTED in files/ — fix before committing" >&2; exit 1
fi
echo "synced $(find files -type f | wc -l) files"

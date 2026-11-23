#!/bin/sh
# Copy /opt/stacks/site.env into a managed block at the end of every
# <stack>/.env (created 0600 if missing). Re-run after editing site.env.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
site="$root/site.env"
[ -f "$site" ] || { echo "missing $site (copy site.env.example)" >&2; exit 1; }
begin='# >>> site.env (managed by host/site-env.sh, do not edit) >>>'
end='# <<< site.env <<<'
for compose in "$root"/*/compose.yaml; do
  dir=$(dirname "$compose"); env="$dir/.env"
  [ -f "$env" ] || install -m 600 /dev/null "$env"
  tmp=$(mktemp "$dir/.env.XXXXXX")
  { awk -v b="$begin" -v e="$end" '$0==b{skip=1} !skip{print} $0==e{skip=0}' "$env"
    echo "$begin"; grep -Ev '^[[:space:]]*(#|$)' "$site" | sed 's/[[:space:]]*#.*$//'; echo "$end"; } > "$tmp"
  chmod 600 "$tmp"; mv "$tmp" "$env"
  echo "updated ${env#$root/}"
done

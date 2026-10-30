#!/bin/bash
# Checks what scripts/build.py put in dist/stage with Sidefolk's own validators (`sidefolk ext validate`, `sidefolk theme
# check`), and that
# Kit/ is still the copy of Sidefolk's extensions/Kit.
#   SIDEFOLK_APP=../sidefolk scripts/check.sh      (a checkout of ghassenbrg/sidefolk; default ../sidefolk)
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${SIDEFOLK_APP:-../sidefolk}"
[[ -d dist/stage ]] || { echo "Run scripts/build.py (or --unsigned) first." >&2; exit 1; }
[[ -f "$APP/Package.swift" ]] || { echo "No Sidefolk checkout at $APP (set SIDEFOLK_APP)." >&2; exit 1; }

swift build --package-path "$APP" --product sidefolk
CLI="$(swift build --package-path "$APP" --show-bin-path)/sidefolk"
HOME_DIR="$(mktemp -d)"
trap 'rm -rf "$HOME_DIR"' EXIT
failed=0
for manifest in dist/stage/*/sidefolk-extension.json; do
  folder="$(dirname "$manifest")"
  if SIDEFOLK_HOME="$HOME_DIR" "$CLI" ext validate --no-run "$folder" > "$HOME_DIR/out.txt" 2>&1; then
    echo "ok      $(basename "$folder")"
  else
    echo "FAILED  $(basename "$folder")"; sed 's/^/        /' "$HOME_DIR/out.txt"; failed=1
  fi
done

for theme in dist/stage/theme-*/theme.json; do
  [[ -f "$theme" ]] || continue
  folder="$(dirname "$theme")"
  if "$CLI" theme check "$folder" > "$HOME_DIR/out.txt" 2>&1; then
    echo "ok      $(basename "$folder")"
  else
    echo "FAILED  $(basename "$folder")"; sed 's/^/        /' "$HOME_DIR/out.txt"; failed=1
  fi
done

if ! diff -r Kit "$APP/extensions/Kit" > /dev/null; then
  echo "::warning title=Kit::Kit/ differs from sidefolk/extensions/Kit; copy it over unless the difference is meant."
fi
exit $failed

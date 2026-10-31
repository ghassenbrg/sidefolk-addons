#!/bin/bash
# Uploads what scripts/build.py made to the "gallery" release, where Sidefolk reads the catalog
# (https://github.com/ghassenbrg/sidefolk-addons/releases/download/gallery/catalog.zip).
#   scripts/publish.sh
# Packs go up first and the catalog last, so the catalog never names a file that isn't there yet. A pack already in
# the release with the same digest (a version build.py kept) isn't uploaded again. Packs of versions the catalog no
# longer lists are removed afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."
TAG=gallery
[[ -f dist/catalog.zip ]] || { echo "Run scripts/build.py first." >&2; exit 1; }
# Signed packs only: an ad-hoc build (--unsigned) would be refused by every copy of Sidefolk.
unzip -p dist/catalog.zip 'catalog.sidefolkaddon/Contents/_CodeSignature/CodeSignature' | wc -c | awk '{ if ($1 < 1000) { print "dist/ was built --unsigned." > "/dev/stderr"; exit 1 } }'

# A pre-release, like Sidefolk's snapshots: nothing here is an official release until the maintainer makes one.
if ! gh release view "$TAG" >/dev/null 2>&1; then
  gh release create "$TAG" --title "Add-on gallery" --prerelease \
    --notes "Sidefolk's add-on gallery: companions and extensions Sidefolk downloads on demand. Each file is signed; Sidefolk checks it before using it."
fi
have=$(gh release view "$TAG" --json assets -q '.assets[] | "\(.name) \(.digest)"')
packs=()
for pack in dist/*.zip; do
  [[ "$pack" == dist/catalog.zip ]] && continue
  grep -qx "$(basename "$pack") sha256:$(shasum -a 256 "$pack" | cut -d' ' -f1)" <<<"$have" || packs+=("$pack")
done
(( ${#packs[@]} == 0 )) || gh release upload "$TAG" "${packs[@]}" --clobber
gh release upload "$TAG" dist/catalog.zip --clobber

keep=$(cd dist && ls *.zip)
for asset in $(gh release view "$TAG" --json assets -q '.assets[].name'); do
  grep -qx "$asset" <<<"$keep" || gh release delete-asset "$TAG" "$asset" --yes
done
echo "Published $(echo "$keep" | wc -l | tr -d ' ') files to the $TAG release."

# Agent guide

The add-on gallery of Sidefolk (github.com/ghassenbrg/sidefolk, usually checked out beside this one as
`../sidefolk`). Read this repository's README, then Sidefolk's AGENTS.md and its docs/DECISIONS.md D55 and
docs/SECURITY.md T33 before changing how packs are made.

## Rules

- When committing, never add a `Co-Authored-By` trailer.
- Never publish (`scripts/publish.sh`) or push unless the maintainer asks: the release is what every copy of
  Sidefolk downloads.
- Raise an add-on's `version` (addon.json or sidefolk-extension.json) whenever its files change. A published
  version's pack is never replaced (`scripts/build.py` keeps it and stops when its files changed without a new
  version); `--rebuild` only for a new signing certificate.
- A companion's folder holds exactly its four files and addon.json; `scripts/build.py` refuses anything else.
- `Kit/` is a copy of Sidefolk's `extensions/Kit`: change it there first, then copy it here.
- An extension's words live in its `strings/<language>.json`, ten languages (Sidefolk D76): change the English, then
  every language (`../sidefolk/scripts/extension-strings.py sync|check`). Its name, tagline, description and titles are
  also in Sidefolk's `BuiltInExtensionWords` (for packs from before `strings/`): keep those word for word with the manifest.
- After a change: `swift test`, `python3 scripts/build.py --unsigned`, `scripts/check.sh`, and in Sidefolk
  `make test` (its sandbox tests run these extensions from `../sidefolk-addons`).

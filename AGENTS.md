# Agent guide

The add-on gallery of Sidefolk (github.com/ghassenbrg/sidefolk, usually checked out beside this one as
`../sidefolk`). Read this repository's README, then Sidefolk's AGENTS.md and its docs/DECISIONS.md D55 and
docs/SECURITY.md T33 before changing how packs are made.

## Rules

- When committing, never add a `Co-Authored-By` trailer.
- Never publish (`scripts/publish.sh`) or push unless the maintainer asks: the release is what every copy of
  Sidefolk downloads.
- Raise an add-on's `version` (addon.json or sidefolk-extension.json) whenever its files change.
- A companion's folder holds exactly its four files and addon.json; `scripts/build.py` refuses anything else.
- `Kit/` is a copy of Sidefolk's `extensions/Kit`: change it there first, then copy it here.
- An extension's words (name, tagline, description, tool titles) are also in Sidefolk's string catalog
  (`BuiltInExtensionWords`, translated into ten languages): change both together, or Sidefolk's test of them fails.
- After a change: `swift test`, `python3 scripts/build.py --unsigned`, `scripts/check.sh`, and in Sidefolk
  `make test` (its sandbox tests run these extensions from `../sidefolk-addons`).

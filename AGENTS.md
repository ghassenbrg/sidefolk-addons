# Agent guide

The add-on gallery of Sidefolk (github.com/ghassenbrg/sidefolk, usually checked out beside this one as
`../sidefolk`). Read this repository's README, then Sidefolk's AGENTS.md and its docs/DECISIONS.md D55 and
docs/SECURITY.md T33 before changing how packs are made.

## Rules

- When committing, never add a `Co-Authored-By` trailer.
- Never publish (`scripts/publish.sh`) or push unless the maintainer asks: the release is what every copy of
  Sidefolk downloads.
- Versions (README › Publishing): while an add-on is in snapshots, `scripts/build.py` numbers each change
  (`1.0.0-snapshot.<n>`), so leave its `version` alone; once it is released (`"released"` in addon.json), raise the
  version for the next change. A published pack is never replaced (`build.py` keeps it and stops when a released
  version's files changed); `--rebuild` only for a new signing certificate.
- A version that needs a newer Sidefolk names it in `addon.json`'s `minimum_sidefolk` (a snapshot, e.g.
  `0.1.0-snapshot.661`, Sidefolk D83): Playtime needs 661 for its puzzles, Miraya 593 for `output_mute`.
- A companion's folder holds exactly its four files and addon.json; `scripts/build.py` refuses anything else.
- `Kit/` is a copy of Sidefolk's `extensions/Kit`: change it there first, then copy it here.
- An extension's words live in its `strings/<language>.json`, ten languages (Sidefolk D76): change the English, then
  every language (`../sidefolk/scripts/extension-strings.py sync|check`). Its name, tagline, description and titles are
  also in Sidefolk's `BuiltInExtensionWords` (for packs from before `strings/`): keep those word for word with the manifest.
- After a change: `swift test`, `python3 scripts/build.py --unsigned`, `scripts/check.sh`, and in Sidefolk
  `make test` (its sandbox tests run these extensions from `../sidefolk-addons`).

## Skills

New add-ons start in Sidefolk's own skills (`../sidefolk/.claude/skills/`, mirrored in `.agents/skills/` for Codex),
which end here: `sidefolk-extension` (an extension), `sidefolk-3d-character` (a companion) and `sidefolk-theme` (a
theme: from a concept or reference images to `themes/<name>/` with `addon.json`, `theme.json` and `art/*.png`,
checked with `sidefolk theme check` and reviewed in Sidefolk's snapshots with `--theme`).

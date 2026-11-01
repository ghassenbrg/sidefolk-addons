# Sidefolk add-ons

The add-on gallery of [Sidefolk](https://github.com/ghassenbrg/sidefolk), the desktop companion for macOS:
companions, extensions and themes that Sidefolk downloads only when someone picks them, so nobody carries what they don't
use. Sidefolk shows them in its Home window's **Gallery** (Sidefolk D84); Settings › Companion and Settings › Add-ons
lead there too.

| | What | |
|---|---|---|
| **Companions** | Ember (a fox), Kiko (a young astronaut), Nimbo (a cloud), Folio (a paper wish), Iris (a camera scout), Nori (a tuxedo cat), Purl (a ragdoll), Rune (a stone golem) | 3D, a few MB each; their 2D forms are built into Sidefolk (D59) |
| **Extensions** | Git, Currency, Playtime (eleven games and four puzzles in Sidefolk's Play panel), Images, PDF Tools, QR Codes, Archives, Dev Toolbox, Feeds, and with pages in Home Your Mac, Clipboard, Keep Awake and Miraya | about 170 KB each; Playtime and Miraya more |
| **Themes** | Daylight, Night Studio, Paper Garden: colours, type, density, a few pictures (a theme dresses Sidefolk, it doesn't arrange it: D84) | 0.5–1.8 MB each |

Every add-on here names its author; Sidefolk's own carry a seal ("Made by Sidefolk", ids under `dev.sidefolk.`).
Built into the app are Mochi, Spark, the folks, and World Clock, Calculator, System Vitals and Weather.

## How Sidefolk trusts what it downloads

Each add-on is published as a pack: a bundle `<name>.sidefolkaddon/Contents/{Info.plist, Resources/…}`, signed as
a whole with Sidefolk's Developer ID (codesign seals every file), zipped. The catalog is a pack of its own. Before
using anything, Sidefolk checks the signature against the Developer ID team its own Info.plist names, the
identifier against the add-on it asked for, and the size and SHA-256 against the signed catalog. A companion is
exactly four files; an extension goes through Sidefolk's usual install preview, with its permissions, and runs in
its sandbox. Sidefolk's DECISIONS D55 and SECURITY T33 have the whole of it.

## Layout

```
companions/<name>/    addon.json, characters/<name>.js, assets/<name>.glb, portraits/<name>.png, avatars/<name>.png
themes/<name>/        addon.json, theme.json, art/*.png (Sidefolk checks it again and re-encodes the pictures)
extensions/<name>/    sidefolk-extension.json, icon.pdf, addon.json (its shelf: everyday, files, developer or fun;
                      `minimum_sidefolk`: a Sidefolk snapshot it needs, e.g. "0.1.0-snapshot.593", Sidefolk D83),
                      strings/<language>.json (its words in Sidefolk's ten languages, Sidefolk D76),
                      Sources/ (a Swift program on Kit/); optionally licenses/ (packed as is) and frameworks
                      the program links (packed as lib/<Name>.framework/<Name>, signed like the program)
Kit/                  a copy of Sidefolk's extensions/Kit (scripts/check.sh warns when they differ)
Tests/                the extensions' own logic, with canned data
scripts/              build.py (pack and sign), publish.sh (upload), check.sh (Sidefolk's validator)
```

The extensions' sandbox tests live in Sidefolk and run against a build of this repository beside it
(`../sidefolk-addons`, or `SIDEFOLK_ADDONS_REPO`).

## Working on it

```sh
swift test                                   # build the extensions and run their tests
python3 scripts/build.py --unsigned          # pack everything, ad hoc (Sidefolk refuses these)
SIDEFOLK_APP=../sidefolk scripts/check.sh    # Sidefolk's own manifest check on every extension
```

To try a build in Sidefolk before publishing it, run a debug copy of Sidefolk with `SIDEFOLK_ADDONS` set to this
repository's `dist/` (signed with `scripts/build.py`): it reads the gallery from there instead of GitHub.

Miraya (`extensions/miraya`) is the sending side of [Miraya](https://github.com/ghassenbrg/miraya)'s Mac app, MIT,
in Sidefolk's sandbox: it depends on the same pinned WebRTC (stasel/WebRTC 150.0.0), copies the Mac app's sources it
reuses with their notice (`licenses/`), and its icon is the Mac app's own (`swift scripts/miraya-icon.swift <miraya>`).
It needs Sidefolk's `screen`, `udp` and `network_purpose` (Sidefolk D69).

## Publishing

```sh
python3 scripts/build.py        # signs with the keychain's Developer ID Application (or $SIDEFOLK_SIGN_IDENTITY)
scripts/publish.sh              # uploads the new packs, then the catalog, to the "gallery" release
```

A published version is never rebuilt: `build.py` keeps the release's pack of every version already there, byte
for byte, because a copy of Sidefolk may hold a catalog naming its digest (a fresh signature changes the bytes). If
a released version's files changed (a companion, a theme, or an extension past its snapshots), the build stops and asks for a new version. A change to Kit/ alone doesn't: an extension whose own files are as published keeps its pack (Kit changes
are additions its program doesn't use); raise its version to ship it a Kit fix. `--rebuild` signs
everything anew (a new certificate); copies holding the older catalog then fetch it again when a pack doesn't match.

Every add-on is in snapshots until it's released, as Sidefolk is. Its manifest (an extension's) or `addon.json`
(a companion's or theme's) names the version it's heading for (`1.0.0`), and `build.py` publishes it as
`1.0.0-snapshot.1`, then `1.0.0-snapshot.2` the next time its files change, and so on: no need to raise anything
while it's a snapshot. A theme's packed `theme.json` carries that version too. To release it, write
`"released": "1.0.0"` in its `addon.json`; the next build publishes plain `1.0.0`, which Sidefolk ranks above all
its snapshots. From then on 1.0.0 is fixed: for the next change, raise the version (`1.1.0`), and its snapshots
begin again. 1.0.0 stays in the gallery beside them, listed first, so people who take releases only
(Sidefolk's Settings › General › Updates) keep it until 1.1.0 is released.

Once released, raise a companion's or theme's version for every change people should get. An extension is offered as **Update** when the
catalog's version is newer than the installed one (it can act for the person, so it waits for them). A companion
only draws, so Sidefolk updates it by itself: a look soon after launch and every six hours, and the one on the
desktop swaps to the new version in place. A version that needs something newer than an older copy has (an engine
feature, a new move) must say so with `minimum_sidefolk` (or a higher `engine`): copies that don't meet it skip
that version and keep the one they have.

## Adding one

- **A theme** is a folder in `themes/` (`addon.json`, `theme.json`, `art/*.png`, nothing else); Sidefolk's
  `sidefolk-theme` skill makes one from a concept or reference images and checks it.
- **A companion** needs its character in Sidefolk too (a `CompanionChoice` and a stand-in rig), so new ones start
  in Sidefolk's `sidefolk-3d-character` skill, which ends here. Community 3D companions wait for a data-only
  character format: today's character files are code, which only Sidefolk's own signature may carry.
- **An extension** is a folder like those in `extensions/`, with a manifest Sidefolk validates
  ([Sidefolk's docs/EXTENSIONS.md](https://github.com/ghassenbrg/sidefolk/blob/main/docs/EXTENSIONS.md)). Add it
  to `Package.swift` and open a pull request; ids under `dev.sidefolk.` are Sidefolk's own. A page is optional
  (people can hide it from Home's sidebar): an extension that is mostly an on/off switch puts that switch on its page's
  summary (`Summary(..., control: .toggle(...))`) with `"widget": true`, and Sidefolk shows it on Today's tile and
  beside the page in the sidebar, as Keep Awake does (Sidefolk's docs/EXTENSIONS.md › Pages).
- **Every word in ten languages** (Sidefolk D76): write what people read as `L("English", ["name": value])` and
  numbers, sizes and dates with `Format`; `../sidefolk/scripts/extension-strings.py sync extensions/<name>` writes
  `strings/en.json` from the code, and each other language's file translates `text` and the manifest's words (name,
  tagline, description, titles). `extension-strings.py check` lists what's missing; Sidefolk's `ExtensionLanguagesTests`
  wants all of it for Sidefolk's own. `build.py` packs `strings/` and puts each language's name, tagline and description
  in the catalog. Playtime's words and its games' phrases live there too (Sidefolk D79).
- **What the Kit offers** follows Sidefolk's protocol: tools, watchers, pages (gauges, charts, switches, buttons, and
  since Sidefolk D68 `choice`, `field` and `list` with pictures), palettes (items with a picture, a swatch and a
  section; `PalettePreview` for the picked item in full; list actions like `clear`), notices (`ext.on`, as
  Clipboard hears which app a copy came from), and games (boards from Sidefolk's fixed parts, played in its Play panel,
  Sidefolk D75 and D79; Playtime is the example). A picture is a file the program wrote in its own data folder
  (`Paths.data`), named relative to it: make thumbnails once and small. Change Kit/ in Sidefolk first, then copy it here.

Sidefolk is proprietary (its LICENSE); so are the add-ons here unless an `addon.json` or manifest says otherwise.

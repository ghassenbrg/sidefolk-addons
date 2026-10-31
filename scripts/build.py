#!/usr/bin/env python3
"""Builds every add-on into a signed pack, and the signed catalog, in dist/ (sidefolk's docs/DECISIONS.md, D55).

    scripts/build.py              sign with the keychain's Developer ID Application (or $SIDEFOLK_SIGN_IDENTITY)
    scripts/build.py --unsigned   ad-hoc, for checks (CI): Sidefolk refuses these packs
    scripts/build.py --rebuild    sign every pack anew, even versions already published (a new certificate)

A signed build keeps the published pack of every version already in the release, byte for byte: a copy of Sidefolk
may hold a catalog naming that pack's digest, and a pack rebuilt under the same name would no longer match it (each
signature carries its own timestamp). Each entry records a digest of the files the pack is made from (`source`);
when they changed but a released version didn't, the build stops: raise the version. An add-on not released yet
goes out as its next snapshot instead (`snapshot_version`).

dist/ then holds <name>-<version>.zip for each add-on and catalog.zip, which scripts/publish.sh uploads, and
dist/stage/<name>/ with each pack's files as Sidefolk installs them (for `sidefolk ext validate`).

A pack is a bundle, `<name>.sidefolkaddon/Contents/{Info.plist, Resources/…}`, signed as a whole (codesign seals
every file under Resources), zipped. Its identifier is the add-on's id, which Sidefolk checks against the catalog.
"""
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
CATALOG_ID = "dev.sidefolk.addons.catalog"
RELEASE = "https://github.com/ghassenbrg/sidefolk-addons/releases/download/gallery"
COMPANION_FILES = ["characters/{n}.js", "assets/{n}.glb", "portraits/{n}.png", "avatars/{n}.png"]
MINIMUM_SIDEFOLK = "0.1.0"


def minimum_sidefolk(requirement):
    """The manifest's ">=0.2" as the catalog's "0.2.0": copies of Sidefolk older than that skip the version (an
    extension using pages, say, which an older copy can't read)."""
    m = re.fullmatch(r">=\s*(\d+)(?:\.(\d+))?(?:\.(\d+))?", (requirement or "").strip())
    if not m:
        return MINIMUM_SIDEFOLK
    return ".".join(part or "0" for part in m.groups())


def run(*args, **kw):
    return subprocess.run(args, check=True, text=True, **kw)


def identity(unsigned):
    if unsigned:
        return "-"
    if os.environ.get("SIDEFOLK_SIGN_IDENTITY"):
        return os.environ["SIDEFOLK_SIGN_IDENTITY"]
    out = run("security", "find-identity", "-v", "-p", "codesigning", capture_output=True).stdout
    found = re.findall(r'"(Developer ID Application:[^"]+)"', out)
    if not found:
        sys.exit("No Developer ID Application identity in the keychain (or pass --unsigned for a check build).")
    return found[0]


def team(ident):
    m = re.search(r"\(([A-Z0-9]{10})\)$", ident)
    return m.group(1) if m else None


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def source_digest(paths, base):
    """What a pack is made from: these files' paths (relative to `base`) and contents."""
    h = hashlib.sha256()
    for path in sorted(paths, key=lambda p: str(p.relative_to(base))):
        h.update(str(path.relative_to(base)).encode() + b"\0")
        h.update(hashlib.sha256(path.read_bytes()).digest())
    return h.hexdigest()


def pairs_digest(pairs):
    """source_digest of (relative path, bytes) pairs, for files that are only in git history."""
    h = hashlib.sha256()
    for rel, data in sorted(pairs):
        h.update(rel.encode() + b"\0")
        h.update(hashlib.sha256(data).digest())
    return h.hexdigest()


def kit_versions():
    """Kit/ as it was at each commit that changed it, newest first, as (relative path, bytes) pairs."""
    revs = run("git", "log", "--format=%H", "--", "Kit", cwd=ROOT, capture_output=True).stdout.split()
    out = []
    for rev in revs:
        names = run("git", "ls-tree", "-r", "--name-only", rev, "--", "Kit", cwd=ROOT, capture_output=True).stdout.split("\n")
        files = [n for n in names if n and Path(n).name not in ("addon.json", ".DS_Store")]
        out.append([(n, subprocess.run(["git", "show", f"{rev}:{n}"], cwd=ROOT, check=True, capture_output=True).stdout) for n in files])
    return out


def built_with_earlier_kit(folder, published_source):
    """The extension's own files are as published, and only Kit/ changed since. Kit changes are additions old programs
    don't use (a new part of the protocol), so the published pack still works: keeping it spares everyone an update
    that changes nothing for them. An extension gets a Kit fix by raising its version."""
    own = [(str(p.relative_to(ROOT)), p.read_bytes()) for p in files_in(folder)]
    return any(pairs_digest(own + kit) == published_source for kit in kit_versions())


def snapshot_version(base, old, source, folder=None):
    """An add-on's version until the maintainer releases it, numbered as Sidefolk's own snapshots are:
    `1.0.0-snapshot.<n>`, the published one while its files are the same, the next one when they changed. Sidefolk
    orders them by n and offers each as an update, and the release, plain `1.0.0`, after all of them. `folder` is an
    extension's, whose pack also stays while only Kit/ changed."""
    m = re.fullmatch(rf"{re.escape(base)}-snapshot\.(\d+)", old["version"]) if old else None
    if not m:
        return f"{base}-snapshot.1"
    same = old.get("source") in (None, source) or (folder is not None and built_with_earlier_kit(folder, old["source"]))
    return old["version"] if same else f"{base}-snapshot.{int(m.group(1)) + 1}"


def files_in(folder, skip=("addon.json", ".DS_Store")):
    return [p for p in folder.rglob("*") if p.is_file() and p.name not in skip]


def published(ident, work):
    """The entries of the catalog in the release now, by id (none before the first publish)."""
    zip_path = work / "published-catalog.zip"
    try:
        urllib.request.urlretrieve(f"{RELEASE}/catalog.zip", zip_path)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return {}
        raise
    out = work / "published-catalog"
    run("ditto", "-x", "-k", str(zip_path), str(out))
    bundle = out / "catalog.sidefolkaddon"
    run("codesign", "--verify", "--deep", "--strict",
        f'-R=anchor apple generic and certificate leaf[subject.OU] = "{team(ident)}" and identifier "{CATALOG_ID}"', str(bundle))
    data = json.loads((bundle / "Contents" / "Resources" / "catalog.json").read_text())
    by_id = {}
    for a in data["addons"]:
        by_id.setdefault(a["id"], []).append(a)
    return by_id


def latest(entries):
    """An add-on's newest published release and newest snapshot (either may be None): a release stays listed beside
    the snapshots of the version after it (Sidefolk's D65), so people on Releases keep it."""
    def key(e):
        return tuple(int(n) for n in re.findall(r"\d+", e["version"]))
    releases = [e for e in entries or [] if "-" not in e["version"]]
    snapshots = [e for e in entries or [] if "-" in e["version"]]
    return max(releases, key=key, default=None), max(snapshots, key=key, default=None)


def kept_release(name, release, base, work):
    """The published release of an add-on now in snapshots of `base`, kept byte for byte and listed first, so a copy
    of Sidefolk that reads one entry per id (before D65) keeps getting the release."""
    if not release:
        return []
    if tuple(map(int, release["version"].split("."))) >= tuple(map(int, base.split("."))):
        sys.exit(f"{name}: {release['version']} is released. Raise its version for the next one's snapshots.")
    zip_path = DIST / release["file"]
    urllib.request.urlretrieve(f"{RELEASE}/{release['file']}", zip_path)
    assert zip_path.stat().st_size == release["bytes"] and sha256(zip_path) == release["sha256"], f"{name}: the published pack isn't what the catalog says"
    print(f"kept    {release['file']} (released, beside the next version's snapshots)")
    return [dict(release)]


def reuse(name, entry, stage, old, work, folder=None):
    """Takes the published pack of this version into dist/ instead of a new one, and stages its files."""
    if old.get("source") not in (None, entry["source"]):
        if folder is None or not built_with_earlier_kit(folder, old["source"]):
            sys.exit(f"{name}: its files changed since {entry['version']} was published. Raise its version.")
        # Still what the pack is made from: its own files and the Kit it was built with.
        entry["source"] = old["source"]
    zip_path = DIST / old["file"]
    urllib.request.urlretrieve(f"{RELEASE}/{old['file']}", zip_path)
    assert zip_path.stat().st_size == old["bytes"] and sha256(zip_path) == old["sha256"], f"{name}: the published pack isn't what the catalog says"
    out = work / f"published-{name}"
    run("ditto", "-x", "-k", str(zip_path), str(out))
    shutil.rmtree(stage, ignore_errors=True)
    shutil.copytree(out / f"{name}.sidefolkaddon" / "Contents" / "Resources", stage)
    entry.update(file=old["file"], bytes=old["bytes"], sha256=old["sha256"])
    print(f"kept    {old['file']} (published)")
    return entry


def sign(path, ident, runtime=False):
    args = ["codesign", "--force", "--sign", ident]
    if ident != "-":
        args.append("--timestamp")
    if runtime:
        args += ["--options", "runtime"]
    run(*args, str(path))


def pack(name, entry, payload, ident, work, file=None):
    """Wraps `payload` as a signed bundle, zips it into dist/, and fills in the entry's file, size and digest."""
    bundle = work / f"{name}.sidefolkaddon"
    shutil.rmtree(bundle, ignore_errors=True)
    (bundle / "Contents").mkdir(parents=True)
    shutil.copytree(payload, bundle / "Contents" / "Resources")
    with open(bundle / "Contents" / "Info.plist", "wb") as f:
        plistlib.dump({
            "CFBundleIdentifier": entry["id"], "CFBundleName": entry.get("name", name),
            "CFBundleShortVersionString": entry["version"], "CFBundleVersion": entry["version"],
            "CFBundlePackageType": "BNDL", "CFBundleInfoDictionaryVersion": "6.0",
        }, f)
    sign(bundle, ident)
    check = ["codesign", "--verify", "--deep", "--strict"]
    if ident != "-":
        check.append(f'-R=anchor apple generic and certificate leaf[subject.OU] = "{team(ident)}" and identifier "{entry["id"]}"')
    run(*check, str(bundle))
    file = file or f"{name}-{entry['version']}.zip"
    zip_path = DIST / file
    zip_path.unlink(missing_ok=True)
    run("ditto", "-c", "-k", "--norsrc", "--noextattr", "--noqtn", "--keepParent", str(bundle), str(zip_path))
    entry.update(file=file, bytes=zip_path.stat().st_size, sha256=sha256(zip_path))
    return entry


def companions(ident, work, previews, prior):
    entries = []
    for folder in sorted((ROOT / "companions").iterdir()):
        if not (folder / "addon.json").exists():
            continue
        name = folder.name
        entry = json.loads((folder / "addon.json").read_text())
        assert entry["kind"] == "companion" and entry["companion"] == name, f"{name}: addon.json must name this companion"
        assert entry["id"].startswith("dev.sidefolk.companions."), f"{name}: id"
        files = sorted(str(p.relative_to(folder)) for p in folder.rglob("*") if p.is_file() and p.name not in ("addon.json", ".DS_Store"))
        expected = sorted(f.format(n=name) for f in COMPANION_FILES)
        assert files == expected, f"{name}: needs exactly {expected}, has {files}"
        stage = DIST / "stage" / name
        shutil.copy(folder / "avatars" / f"{name}.png", previews / f"{name}.png")
        entry["preview"] = f"previews/{name}.png"
        entry["source"] = source_digest(files_in(folder), folder)
        release, old = latest(prior.get(entry["id"]))
        # A snapshot until addon.json says `"released": "<that version>"`; the companion records the catalog's version.
        if entry.pop("released", None) != entry["version"]:
            entries += kept_release(name, release, entry["version"], work)
            entry["version"] = snapshot_version(entry["version"], old, entry["source"])
        else:
            old = release
        if old and old["version"] == entry["version"]:
            entries.append(reuse(name, entry, stage, old, work))
            continue
        shutil.copytree(folder, stage, ignore=shutil.ignore_patterns("addon.json", ".DS_Store"))
        entries.append(pack(name, entry, stage, ident, work))
    return entries


def themes(ident, work, previews, prior):
    """Themes (Sidefolk's D58, D64): theme.json and its PNGs, nothing else. Sidefolk checks them again on install."""
    entries = []
    folder_root = ROOT / "themes"
    for folder in sorted(folder_root.iterdir()) if folder_root.exists() else []:
        if not (folder / "addon.json").exists():
            continue
        name = folder.name
        entry = json.loads((folder / "addon.json").read_text())
        theme = json.loads((folder / "theme.json").read_text())
        assert entry["kind"] == "theme" and entry["id"] == theme["id"], f"{name}: addon.json and theme.json must name the same theme"
        assert entry["id"].startswith("dev.sidefolk.theme."), f"{name}: id"
        assert entry["version"] == theme["version"], f"{name}: addon.json and theme.json must have the same version"
        files = sorted(str(p.relative_to(folder)) for p in folder.rglob("*") if p.is_file() and p.name not in ("addon.json", ".DS_Store"))
        others = [f for f in files if f != "theme.json" and not re.fullmatch(r"art/[a-z0-9-]+\.png", f)]
        assert not others, f"{name}: a theme carries theme.json and art/*.png only, not {others}"
        stage = DIST / "stage" / f"theme-{name}"
        preview = folder / "art" / "tile.png"
        if preview.exists():
            shutil.copy(preview, previews / f"theme-{name}.png")
            entry["preview"] = f"previews/theme-{name}.png"
        entry["source"] = source_digest(files_in(folder), folder)
        release, old = latest(prior.get(entry["id"]))
        if entry.pop("released", None) != entry["version"]:
            entries += kept_release(f"theme-{name}", release, entry["version"], work)
            entry["version"] = snapshot_version(entry["version"], old, entry["source"])
        else:
            old = release
        if old and old["version"] == entry["version"]:
            entries.append(reuse(f"theme-{name}", entry, stage, old, work))
            continue
        shutil.copytree(folder, stage, ignore=shutil.ignore_patterns("addon.json", ".DS_Store"))
        # The installed theme's file carries the version it ships as, which Sidefolk compares with the gallery's.
        (stage / "theme.json").write_text(json.dumps({**theme, "version": entry["version"]}, indent=2, ensure_ascii=False) + "\n")
        entries.append(pack(f"theme-{name}", entry, stage, ident, work))
    return entries


def bundle_libraries(program, binaries, stage, ident):
    """Frameworks the program links from the build (Miraya's WebRTC), copied to lib/<Name>.framework/<Name> as one
    plain file each, since Sidefolk refuses links in an extension; the program finds them by its rpath,
    @executable_path/../lib. Each is signed with the same identity, which the hardened runtime requires."""
    linked = run("otool", "-L", str(program), capture_output=True).stdout
    names = sorted(set(re.findall(r"@rpath/([A-Za-z0-9_]+)\.framework/\1\b", linked)))
    for lib in names:
        target = stage / "lib" / f"{lib}.framework" / lib
        target.parent.mkdir(parents=True)
        shutil.copyfile((binaries / f"{lib}.framework" / lib).resolve(), target)
        os.chmod(target, 0o755)
        sign(target, ident)
    return names


def extensions(ident, work, previews, unsigned, prior):
    flags = ["-c", "release"] + ([] if unsigned else ["--arch", "arm64", "--arch", "x86_64"])
    run("swift", "build", *flags, cwd=ROOT)
    binaries = Path(run("swift", "build", *flags, "--show-bin-path", cwd=ROOT, capture_output=True).stdout.strip())
    entries = []
    for folder in sorted((ROOT / "extensions").iterdir()):
        manifest_file = folder / "sidefolk-extension.json"
        if not manifest_file.exists():
            continue
        name = folder.name
        m = json.loads(manifest_file.read_text())
        assert m["id"].startswith("dev.sidefolk.") and m["run"]["command"] == f"bin/ext-{name}", f"{name}: id and run.command"
        stage = DIST / "stage" / name
        if m.get("icon"):
            suffix = Path(m["icon"]).suffix
            shutil.copy(folder / m["icon"], previews / f"{name}{suffix}")
        entry = {"id": m["id"], "kind": "extension", "name": m["name"], "tagline": m.get("tagline", ""),
                 "description": m.get("description", ""), "author": m.get("author", "Sidefolk"), "version": m["version"],
                 "license": "Proprietary", "minimum_sidefolk": minimum_sidefolk(m.get("sidefolk"))}
        # The gallery's shelf (everyday, files, developer, fun), from addon.json beside the manifest.
        extra = json.loads((folder / "addon.json").read_text()) if (folder / "addon.json").exists() else {}
        assert extra.get("category") in ("everyday", "files", "developer", "fun"), f"{name}: addon.json needs a category"
        entry["category"] = extra["category"]
        if m.get("icon"):
            entry["preview"] = f"previews/{name}{Path(m['icon']).suffix}"
        # The program is built from the extension's folder and Kit/.
        entry["source"] = source_digest(files_in(folder) + files_in(ROOT / "Kit"), ROOT)
        release, old = latest(prior.get(entry["id"]))
        # A version is a snapshot until addon.json says `"released": "<that version>"`; only a released one is held
        # to "files changed, raise the version".
        if extra.get("released") != m["version"]:
            entries += kept_release(name, release, m["version"], work)
            entry["version"] = snapshot_version(m["version"], old, entry["source"], folder)
        else:
            old = release
        if old and old["version"] == entry["version"]:
            entries.append(reuse(name, entry, stage, old, work, folder))
            continue
        (stage / "bin").mkdir(parents=True)
        # The pack's manifest carries the version it ships as, which Sidefolk compares with the gallery's.
        (stage / manifest_file.name).write_text(json.dumps({**m, "version": entry["version"]}, indent=2, ensure_ascii=False) + "\n")
        if m.get("icon"):
            shutil.copy(folder / m["icon"], stage)
        program = stage / "bin" / f"ext-{name}"
        shutil.copy(binaries / f"ext-{name}", program)
        if (folder / "licenses").is_dir():
            shutil.copytree(folder / "licenses", stage / "licenses")
        libraries = bundle_libraries(program, binaries, stage, ident)
        # The hardened runtime loads only libraries signed by the same team: an ad-hoc check build has no team, so
        # its program goes without the runtime when it carries libraries (Sidefolk refuses ad-hoc packs anyway).
        sign(program, ident, runtime=ident != "-" or not libraries)
        entries.append(pack(name, entry, stage, ident, work))
    return entries


def main():
    unsigned = "--unsigned" in sys.argv
    ident = identity(unsigned)
    shutil.rmtree(DIST, ignore_errors=True)
    work = DIST / "work"
    catalog = DIST / "catalog"
    previews = catalog / "previews"
    for d in (work, previews, DIST / "stage"):
        d.mkdir(parents=True)
    # An ad-hoc build is only checked, never published, so it makes every pack itself.
    prior = {} if unsigned or "--rebuild" in sys.argv else published(ident, work)
    addons = (companions(ident, work, previews, prior) + extensions(ident, work, previews, unsigned, prior)
              + themes(ident, work, previews, prior))
    (catalog / "catalog.json").write_text(json.dumps({"format": 1, "addons": addons}, indent=2, ensure_ascii=False) + "\n")
    count = run("git", "rev-list", "--count", "HEAD", cwd=ROOT, capture_output=True).stdout.strip() or "1"
    # A fixed name: Sidefolk always asks for catalog.zip.
    pack("catalog", {"id": CATALOG_ID, "name": "Sidefolk add-ons", "version": f"1.0.{count}"}, catalog, ident, work,
         file="catalog.zip")
    shutil.rmtree(work)
    print(f"Built {len(addons)} add-ons and the catalog in {DIST.relative_to(ROOT)}/ (signed: {ident})")


if __name__ == "__main__":
    main()

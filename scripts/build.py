#!/usr/bin/env python3
"""Builds every add-on into a signed pack, and the signed catalog, in dist/ (sidefolk's docs/DECISIONS.md, D55).

    scripts/build.py              sign with the keychain's Developer ID Application (or $SIDEFOLK_SIGN_IDENTITY)
    scripts/build.py --unsigned   ad-hoc, for checks (CI): Sidefolk refuses these packs

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
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
CATALOG_ID = "dev.sidefolk.addons.catalog"
COMPANION_FILES = ["characters/{n}.js", "assets/{n}.glb", "portraits/{n}.png", "avatars/{n}.png"]
MINIMUM_SIDEFOLK = "0.1.0"


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


def companions(ident, work, previews):
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
        shutil.copytree(folder, stage, ignore=shutil.ignore_patterns("addon.json", ".DS_Store"))
        shutil.copy(folder / "avatars" / f"{name}.png", previews / f"{name}.png")
        entry["preview"] = f"previews/{name}.png"
        entries.append(pack(name, entry, stage, ident, work))
    return entries


def extensions(ident, work, previews, unsigned):
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
        (stage / "bin").mkdir(parents=True)
        shutil.copy(manifest_file, stage)
        if m.get("icon"):
            shutil.copy(folder / m["icon"], stage)
            suffix = Path(m["icon"]).suffix
            shutil.copy(folder / m["icon"], previews / f"{name}{suffix}")
        program = stage / "bin" / f"ext-{name}"
        shutil.copy(binaries / f"ext-{name}", program)
        sign(program, ident, runtime=True)
        entry = {"id": m["id"], "kind": "extension", "name": m["name"], "tagline": m.get("tagline", ""),
                 "description": m.get("description", ""), "author": m.get("author", "Sidefolk"), "version": m["version"],
                 "license": "Proprietary", "minimum_sidefolk": MINIMUM_SIDEFOLK}
        if m.get("icon"):
            entry["preview"] = f"previews/{name}{Path(m['icon']).suffix}"
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
    addons = companions(ident, work, previews) + extensions(ident, work, previews, unsigned)
    (catalog / "catalog.json").write_text(json.dumps({"format": 1, "addons": addons}, indent=2, ensure_ascii=False) + "\n")
    count = run("git", "rev-list", "--count", "HEAD", cwd=ROOT, capture_output=True).stdout.strip() or "1"
    # A fixed name: Sidefolk always asks for catalog.zip.
    pack("catalog", {"id": CATALOG_ID, "name": "Sidefolk add-ons", "version": f"1.0.{count}"}, catalog, ident, work,
         file="catalog.zip")
    shutil.rmtree(work)
    print(f"Built {len(addons)} add-ons and the catalog in {DIST.relative_to(ROOT)}/ (signed: {ident})")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Build a signed release; optionally publish it using an authenticated gh CLI."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
REPO = "elliotcoop429-cloud/morning-canvas-releases"
ACCOUNT = "com.elliot.morningcanvas.updates"


def run(*args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--notes", required=True, type=Path)
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args()
    notes = args.notes.read_text()
    with (ROOT / "Info.plist").open("rb") as file:
        info = plistlib.load(file)
    version = info["CFBundleShortVersionString"]
    build = int(info["CFBundleVersion"])
    tag = "v" + version
    request = urllib.request.Request(
        f"https://api.github.com/repos/{REPO}/releases/latest",
        headers={"User-Agent": "MorningCanvas-Release"})
    with urllib.request.urlopen(request, timeout=30) as response:
        latest = json.load(response)
    if latest["tag_name"] == tag:
        raise SystemExit("This version is already published. Increase the version and build first.")
    previous_feed = next((a for a in latest["assets"] if a["name"] == "appcast.xml"), None)
    if previous_feed:
        with urllib.request.urlopen(previous_feed["browser_download_url"], timeout=30) as response:
            feed = ET.fromstring(response.read())
        builds = [int(node.text) for node in feed.findall(
            ".//{http://www.andymatuschak.org/xml-namespaces/sparkle}version")]
        if not builds or build <= max(builds):
            raise SystemExit("The build number must be higher than the published release.")
    if args.publish and not shutil.which("gh"):
        raise SystemExit("Publishing requires GitHub CLI (gh) signed into the release repository.")
    sparkle = Path(run("bash", str(ROOT / "tools/sparkle.sh")))
    public_key = run(str(sparkle / "bin/generate_keys"), "--account", ACCOUNT, "-p")
    if info["SUPublicEDKey"] not in public_key:
        raise SystemExit("The signing key does not match the app's trusted update key.")
    out = ROOT / "outputs/releases" / tag
    out.mkdir(parents=True, exist_ok=False)
    build_root = Path(os.environ.get("TMPDIR", "/private/tmp")) / "morning-canvas-build"
    subprocess.run(["bash", str(ROOT / "build.sh")], check=True,
                   env={**os.environ, "BUILD_ROOT": str(build_root)})
    archive = out / "Morning-Canvas.zip"
    shutil.copy2(build_root / archive.name, archive)
    (out / "Morning-Canvas.md").write_text(notes)
    subprocess.run([str(sparkle / "bin/generate_appcast"), "--account", ACCOUNT,
                    "--download-url-prefix", f"https://github.com/{REPO}/releases/download/{tag}/",
                    "--maximum-deltas", "0", "--embed-release-notes", str(out)], check=True)
    appcast = out / "appcast.xml"
    feed = ET.parse(appcast)
    enclosure = feed.find("./channel/item/enclosure")
    signature = enclosure.attrib["{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature"]
    subprocess.run([str(sparkle / "bin/sign_update"), "--account", ACCOUNT,
                    "--verify", str(archive), signature], check=True)
    subprocess.run([str(sparkle / "bin/sign_update"), "--account", ACCOUNT,
                    "--verify", str(appcast)], check=True)
    print(f"Verified release: {out}")
    if args.publish:
        # A draft keeps the public feed unchanged until both assets are uploaded.
        subprocess.run(["gh", "release", "create", tag, str(archive), str(appcast),
                        "--repo", REPO, "--draft", "--title", f"Morning Canvas {version}",
                        "--notes-file", str(out / "Morning-Canvas.md")], check=True)
        subprocess.run(["gh", "release", "edit", tag, "--repo", REPO,
                        "--draft=false", "--latest"], check=True)


if __name__ == "__main__":
    main()

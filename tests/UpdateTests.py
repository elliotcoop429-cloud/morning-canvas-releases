#!/usr/bin/env python3
"""Exercise Sparkle's real installer on isolated bundles, never the user's app."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import plistlib
import shutil
import subprocess
import tempfile
import threading
import time
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
SPARKLE = Path.home() / "Library/Caches/MorningCanvasBuild/Sparkle-2.9.6"
ACCOUNT = "com.elliot.morningcanvas.updates"
APP = Path(os.environ.get("TMPDIR", "/private/tmp")) / "morning-canvas-build/Morning Canvas.app"


def run(*args, expected=0, **kwargs):
    result = subprocess.run([str(a) for a in args], text=True, capture_output=True,
                            timeout=120, **kwargs)
    print(result.stdout + result.stderr, flush=True)
    if result.returncode != expected:
        raise AssertionError(f"{args[0]} returned {result.returncode}, expected {expected}")
    return result


def plist(path):
    with path.open("rb") as file:
        return plistlib.load(file)


def save_plist(path, info):
    with path.open("wb") as file:
        plistlib.dump(info, file)


def main():
    with tempfile.TemporaryDirectory(prefix="MorningCanvas-UpdateTest-") as temporary:
        temp = Path(temporary)
        cli_source = temp / "source"
        cli_source.mkdir()
        names = ["main.m", "SPUCommandLineDriver.m", "SPUCommandLineDriver.h",
                 "SPUCommandLineUserDriver.m", "SPUCommandLineUserDriver.h"]
        for name in names:
            urllib.request.urlretrieve(
                f"https://raw.githubusercontent.com/sparkle-project/Sparkle/2.9.6/sparkle-cli/{name}",
                cli_source / name)
        cli_app = temp / "UpdateTestDriver.app"
        executable = cli_app / "Contents/MacOS/sparkle"
        executable.parent.mkdir(parents=True)
        framework = cli_app / "Contents/Frameworks/Sparkle.framework"
        run("ditto", SPARKLE / "Sparkle.framework", framework)
        run("clang", "-fobjc-arc", "-mmacosx-version-min=14.0", "-F", SPARKLE,
            "-DSPU_OBJC_DIRECT_MEMBERS=", "-DSPU_OBJC_DIRECT=",
            "-framework", "Cocoa", "-framework", "Sparkle",
            "-Wl,-rpath,@executable_path/../Frameworks", *cli_source.glob("*.m"),
            "-o", executable)
        identifier = "com.elliot.morningcanvas.update-test." + uuid.uuid4().hex
        save_plist(cli_app / "Contents/Info.plist", {
            "CFBundleIdentifier": identifier + ".driver", "CFBundleExecutable": "sparkle",
            "CFBundleName": "Update Test Driver", "CFBundleVersion": "1",
            "CFBundlePackageType": "APPL", "LSUIElement": True,
            "NSAppTransportSecurity": {"NSAllowsLocalNetworking": True}})
        run("codesign", "--force", "--sign", "-", cli_app)
        old = temp / "installed/Morning Canvas.app"
        new = temp / "new/Morning Canvas.app"
        archives = temp / "feed"
        archives.mkdir()
        server = ThreadingHTTPServer(("127.0.0.1", 0),
            partial(SimpleHTTPRequestHandler, directory=str(archives)))
        base_url = f"http://127.0.0.1:{server.server_port}/"
        for bundle, version in [(old, "45"), (new, "46")]:
            run("ditto", APP, bundle)
            info_path = bundle / "Contents/Info.plist"
            info = plist(info_path)
            info.update(CFBundleIdentifier=identifier, CFBundleVersion=version,
                        CFBundleShortVersionString="test." + version,
                        SUFeedURL=base_url + "appcast.xml",
                        NSAppTransportSecurity={"NSAllowsLocalNetworking": True})
            save_plist(info_path, info)
            run("codesign", "--force", "--sign", "-", bundle)
        archive = archives / "Morning-Canvas.zip"
        run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", new, archive)
        run(SPARKLE / "bin/generate_appcast", "--account", ACCOUNT,
            "--maximum-deltas", "0", "--download-url-prefix", base_url, archives)
        feed = archives / "appcast.xml"
        original_feed = feed.read_bytes()
        original_archive = archive.read_bytes()
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            # A modified signed feed must be rejected before any download.
            feed.write_bytes(original_feed.replace(b"<title>", b"<title>tampered", 1))
            run(executable, old, "--probe", "--verbose", expected=1)
            assert plist(old / "Contents/Info.plist")["CFBundleVersion"] == "45"
            feed.write_bytes(original_feed)
            # A damaged archive must not replace the installed bundle.
            damaged = bytearray(original_archive)
            damaged[len(damaged) // 2] ^= 1
            archive.write_bytes(damaged)
            run(executable, old, "--check-immediately", "--verbose", expected=1)
            assert plist(old / "Contents/Info.plist")["CFBundleVersion"] == "45"
            archive.write_bytes(original_archive)
            # The installer helper exits asynchronously after rejecting an archive.
            time.sleep(3)
            run(executable, old, "--check-immediately", "--verbose")
            assert plist(old / "Contents/Info.plist")["CFBundleVersion"] == "46"
            run("codesign", "--verify", "--deep", "--strict", old)
            run(executable, old, "--probe", "--verbose", expected=4)
            print("PASS: bad feed rejected; bad archive rejected; signed update installed; current version detected.")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()
            subprocess.run(["defaults", "delete", identifier], capture_output=True)


if __name__ == "__main__":
    main()

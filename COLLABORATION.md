# Morning Canvas collaborative editing

This is the existing Morning Canvas 7.7 source, recovered from the local project
used by the task “Add morning school work popup.” The original app is preserved in its original folder. This working copy adds
collaboration configuration and a visual layout layer to the existing app.

## Design visually, like a GUI editor

Choose **Terminal → Run Task → Open Morning Canvas Studio**, then open port
**8001** from Codespaces' Ports panel. Keep this port **Private**. On a Mac, run
`python3 tools/designer.py` and open `http://127.0.0.1:8001`.

- Select a control in Explorer or click it on the canvas. Drag it to move it;
  drag the bottom-right handle to resize. Arrow keys move by one pixel, or ten
  with Shift. Snap rounds drags to four pixels.
- Properties changes position, size, visibility, label text, font size, and
  text-label colors. **＋ Text label** adds your own text. Undo/redo and
  **Reset this object** let you recover from experiments.
- **Save layout** writes `Resources/gui-layout.json` into the project. This is
  the same layout the native app reads when built. Save does not commit or push.
- **Preview** hides editing outlines; it is a sample-data preview, not the full
  running Mac app. The 18 main dashboard objects are supported. Class/content
  panels and navigation scale as groups; individual rows and dialogs still
  live in `MorningCanvas.m`. Button actions stay wired to the original app.
- Export a draft to keep a separate copy; Import loads a draft without saving.

For your friend: join the Live Share session, then open **Shared Servers →
Morning Canvas Studio (8001)**. The host can add it with **Share Server → 8001**.
No terminal needs to be shared. Either person can save a layout; saved changes
appear in the other browser after a few seconds if that browser has no unsaved
edits. If both are editing, a save conflict is blocked: export your draft,
reload the newer saved layout, and reapply your changes. There are no shared
cursors or automatic merges of simultaneous visual drags.

After designing, bring the saved source to your Mac and run `bash build.sh`.
The new app is built in the path printed by the script; your installed app is
not replaced. Linux Codespaces cannot build the native Mac app. Future
published updates may replace custom layouts unless they include this source.

The editor uses only Python's standard library and local assets. It serves
only the editor files and layout, not your project directory or private files.
It binds to loopback and uses Codespaces/Live Share access control; do not expose
its port publicly. No real Canvas data or token is needed.

Run `bash tests/run-designer.sh` for save/validation/conflict tests and, on a Mac,
native layout/action/scaling tests. Existing app tests remain available.

## Edit together in the browser

1. Open this folder in GitHub Codespaces. Microsoft Live Share is recommended
   and included in the devcontainer configuration.
2. Open `MorningCanvas.m`: it contains the native Mac GUI and app logic.
3. Click the Live Share icon, then Share. Complete sign-in if prompted.
4. Send the invitation link privately to your friend and approve their join
   request. Both of you can edit the same source files in the browser.
5. Stop the Live Share session when finished. Review changes before committing.

Use Live Share for code and the shared Studio server for visual editing.
The host remains responsible for reviewing and saving changes to GitHub.
An invitation to Live Share does not grant ongoing repository access.

## Preview and build

The complete app uses Objective-C, Cocoa/AppKit, and other macOS frameworks.
Codespaces runs Linux, so it cannot run the full native app or its GUI preview.
Use a Mac with Apple's command-line developer tools to build with `bash build.sh`
and run the app from the build path printed by that script. The build does not
replace the installed application. Run existing native tests with
`bash tests/run.sh` on a Mac.

Only the loading animation is a web page. In Codespaces, choose Terminal > Run
Task > Preview loading animation only, then open port 8000 from the Ports panel.
Keep the port private. It does not contain the main app, assignments, or grades.
Edit `LoadingScene/scene.js`, run `npm ci` and `npm run build` in `LoadingScene`,
then refresh the preview. Only share this server deliberately through Live Share.

## Credentials and personal data

Never upload the contents of `~/Library/Application Support/Morning Canvas/`.
The app stores `canvas-token` and `calendar-url` there, outside the source folder,
with owner-only permissions. These are plaintext files, not encrypted Keychain
storage. Never paste their values into chat, code, terminal commands, or commits.

The private update-signing key remains in the owner's Mac Keychain. The
`SUPublicEDKey` in `Info.plist` is a public verification key and belongs in source.
Do not regenerate the signing key or publish a release while setting up editing.
See `RELEASING.md` when intentionally releasing a new app version.

The supplied `.gitignore` excludes local credential files and build artifacts.
`.vsls.json` excludes ignored files from Live Share and blocks credential paths.
Settings require guest approval and disable automatic terminal/server sharing,
external file sharing, and guest command/debug control.

These settings do not isolate secrets from code execution: a collaborator can
edit code that reads credentials when a host runs it. Use trusted collaborators,
review changes before running them, and keep real tokens and personal data out
of the collaborative Codespace. Each person should use their own account/token
when testing privately on their Mac.

## Before saving source to GitHub

The existing `elliotcoop429-cloud/morning-canvas-releases` repository is public.
Pushing this source there would make it public. Choose whether the source belongs
there or in a separate private repository before pushing. Release downloads can
remain in the existing public repository either way.

## Review performed on 2026-09-26

- All 20 original source, resource, build, release, and test files were copied
  without changing their contents. Unrelated projects and generated app archives
  were excluded.
- The current locally stored Canvas token and calendar link were compared without
  displaying their values against these files and all three published app ZIPs;
  no matches were found. Recognizable credential patterns were also checked.
- Both private files had mode 0600 and their parent directory had mode 0700.
- The public repository's available branches/tags contained only the initial
  README commit. The local source folder had no Git history to audit.
- This was a focused source/secret-exposure review, not a full security audit.

References: [GitHub Codespaces collaboration](https://docs.github.com/en/codespaces/developing-in-a-codespace/working-collaboratively-in-a-codespace)
and [Live Share security settings](https://learn.microsoft.com/en-us/visualstudio/liveshare/reference/security).

## Visual editor verification (2026-09-27)

Native universal build and existing Loading, Media, and School tests passed.
New tests cover malformed layouts, save conflicts, restricted serving, native
coordinate conversion, text styling, preserved button actions, scaled content,
and safe fallback. Browser checks covered drag, resize, text insertion/editing,
saving, undo, removal, and reload. The original dashboard is the default layout.

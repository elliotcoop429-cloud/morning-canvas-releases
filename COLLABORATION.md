# Morning Canvas collaborative editing

This is the existing Morning Canvas 7.7 source, recovered from the local project
used by the task “Add morning school work popup.” The app source and resources
are unchanged. Collaboration configuration was added separately.

## Edit together in the browser

1. Open this folder in GitHub Codespaces. Microsoft Live Share is recommended
   and included in the devcontainer configuration.
2. Open `MorningCanvas.m`: it contains the native Mac GUI and app logic.
3. Click the Live Share icon, then Share. Complete sign-in if prompted.
4. Send the invitation link privately to your friend and approve their join
   request. Both of you can edit the same source files in the browser.
5. Stop the Live Share session when finished. Review changes before committing.

Live Share edits code; it is not a drag-and-drop visual GUI designer.
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

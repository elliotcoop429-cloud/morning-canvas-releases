# Morning Canvas Updates

Version 7.4 introduces Sparkle automatic updates. People on 7.3 or earlier must
install 7.4 manually once. Later versions check hourly, download signed updates,
and install them when the app closes. Users can change these preferences in
Morning Canvas > Software Update Settings, or choose Check for Updates.

## Publish a New Version

1. Increase both CFBundleShortVersionString and CFBundleVersion in Info.plist.
   The build number must always increase.
2. Write release notes in a Markdown file.
3. Run `python3 tools/release.py --notes RELEASE-NOTES.md --publish`.
   Publishing needs GitHub CLI (`gh`) signed into the repository owner's account.
   Without `--publish`, upload the resulting Morning-Canvas.zip and appcast.xml
   together to a new GitHub release and then publish it as the latest release.
4. Verify the published release contains both `Morning-Canvas.zip` and the
   matching signed `appcast.xml`. This is required for every release, including
   manual uploads; publishing only the ZIP is not complete.
5. Check for updates from the installed app and confirm the feed loads without
   an error. If publication or verification is blocked, report what remains
   unfinished rather than saying the update is ready.

The script builds Intel and Apple Silicon binaries, signs the archive and feed,
verifies them, and publishes both assets in a draft before making it live.
Changing source files alone does not update installed copies: a release must be
built and published. Do not edit signed files after generation.

The private update-signing key stays in the macOS login Keychain under account
com.elliot.morningcanvas.updates. Keep that key safe; do not regenerate it for
routine releases, commit it, or include it in the app. Losing it prevents updates
to existing installations. User tokens, preferences, and calendars are outside
the app bundle and are not distributed or replaced by updates.

The app itself is ad-hoc signed, not Apple Developer ID signed or notarized.
First installation may require the user's normal macOS approval. Update archive
and feed signatures are checked using the public key embedded in the app.

Sparkle: https://sparkle-project.org/documentation/

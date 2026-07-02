# devlooper-releases

Public release channel for the **Devlooper** desktop app. It holds the DMG builds and the
GitHub Releases that the app's in-app update check reads. The source lives in the private
`devlooper` repo; only release artifacts are published here (public, so client machines need
no token).

Release process: see `docs/releases.md` in the main repo. In short: bump the version in
`electron/package.json`, build the DMG, then `gh release create v<version> <dmg>` here with a
semver tag.

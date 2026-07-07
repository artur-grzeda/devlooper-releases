#!/usr/bin/env bash
# Devlooper one-line installer (macOS: Apple Silicon or Intel).
#
#   curl -fsSL https://raw.githubusercontent.com/artur-grzeda/devlooper-releases/main/install.sh | bash
#
# Detects the Mac's architecture, downloads the matching DMG from the public releases channel,
# installs Devlooper.app to /Applications, clears the Gatekeeper quarantine (the app is not yet
# Apple-signed, so this skips the "can't be opened" prompt), and launches it. No security prompts.
#
# Env: DEVLOOPER_DEST (install dir, default /Applications), DEVLOOPER_NO_LAUNCH=1 (don't open).
set -euo pipefail

REPO="artur-grzeda/devlooper-releases"
APP="Devlooper.app"
DEST="${DEVLOOPER_DEST:-/Applications}"
MNT=""

say()  { printf '\033[1;36m::\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }
cleanup() { [ -n "$MNT" ] && hdiutil detach "$MNT" -quiet >/dev/null 2>&1 || true; [ -n "${TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

[ "$(uname -s)" = "Darwin" ] || die "Devlooper is macOS-only for now."
command -v hdiutil >/dev/null 2>&1 || die "hdiutil not found (needs macOS)."

# Pick the DMG that matches this Mac: Apple Silicon -> arm64, Intel -> x64.
case "$(uname -m)" in
  arm64)  DMG_ARCH="arm64" ;;
  x86_64) DMG_ARCH="x64" ;;
  *)      die "Unsupported architecture: $(uname -m)." ;;
esac

# Fall back to ~/Applications if /Applications isn't writable (non-admin user).
if [ ! -w "$DEST" ]; then DEST="$HOME/Applications"; mkdir -p "$DEST"; fi

say "Finding the latest Devlooper release (${DMG_ARCH})…"
API="https://api.github.com/repos/${REPO}/releases/latest"
DMG_URL="$(curl -fsSL "$API" | grep -oE "\"browser_download_url\"[^,]*${DMG_ARCH}\\.dmg\"" | sed -E 's/.*"(https[^"]+)".*/\1/' | head -1)"
[ -n "$DMG_URL" ] || die "Couldn't find a ${DMG_ARCH} DMG in the latest release."

TMP="$(mktemp -d)"
say "Downloading $(basename "$DMG_URL")…"
curl -fSL --progress-bar "$DMG_URL" -o "$TMP/devlooper.dmg"

# Belt-and-suspenders: never let DEST be empty/root before an rm (guards against a cryptic
# "unbound variable" and against ever `rm -rf`-ing / or /Applications itself).
DEST="${DEST:-/Applications}"
case "$DEST" in ""|"/") die "Refusing to install into '$DEST'." ;; esac

say "Installing to $DEST…"
MNT="$(hdiutil attach "$TMP/devlooper.dmg" -nobrowse -noautoopen 2>/dev/null | grep -o '/Volumes/.*' | tail -1 || true)"
[ -n "$MNT" ] && [ -d "$MNT/$APP" ] || die "Couldn't mount the DMG or find $APP inside it."
rm -rf "$DEST/$APP"
ditto "$MNT/$APP" "$DEST/$APP"
hdiutil detach "$MNT" -quiet >/dev/null 2>&1 || true; MNT=""

[ -d "$DEST/$APP" ] || die "Install did not land at $DEST/$APP - check disk space / permissions."

say "Clearing the Gatekeeper quarantine…"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

ok "Devlooper installed → $DEST/$APP"
if [ "${DEVLOOPER_NO_LAUNCH:-}" != "1" ]; then say "Launching…"; open "$DEST/$APP" || true; fi

#!/bin/sh
# phonemirror.sh: check or rebuild the scrcpy wrapper app the `phone` skill drives.
#
# The wrapper is a tiny .app bundle (a launcher that picks the device, USB or wireless,
# and execs a bundled scrcpy with fixed arguments) so that computer use can grant it by
# bundle ID. Sources next to this script: phonemirror-launcher.sh (the logic, installed as
# Contents/Resources/launch.sh) and phonemirror-stub.c (the bundle executable, which only
# execs launch.sh; launchd won't spawn a script as a bundle executable). Its weak point is that it
# carries COPIES of Homebrew's scrcpy binary and scrcpy-server: after `brew upgrade scrcpy`
# the copy still links the old libraries, or talks to a server of another version, and
# the app dies on launch. `check` finds that; `rebuild` fixes it.
#
# Usage:
#   phonemirror.sh check      One line per step, ok or FAIL with its fix.
#                             Exit 0 = all ok, 1 = at least one FAIL.
#                             Side effects, adb only: starts the adb daemon if needed and,
#                             when no wireless device is connected, `adb connect`s a paired
#                             phone that mDNS finds. Writes no files.
#   phonemirror.sh rebuild    re-copy scrcpy + scrcpy-server from Homebrew, install the
#                             launcher, compile the stub (needs `cc`), and ad-hoc re-sign.
#                             Writes ONLY inside the bundle, and refuses while the app is
#                             running. Info.plist is kept as it is.
#
# Environment (defaults in brackets):
#   PHONEMIRROR_APP   the bundle                  [$HOME/Applications/PhoneMirror.app]
#   ADB               the adb binary              [adb on PATH]
#   SCRCPY_PREFIX     Homebrew's scrcpy prefix    [brew --prefix scrcpy]
set -u

APP="${PHONEMIRROR_APP:-$HOME/Applications/PhoneMirror.app}"
BIN="$APP/Contents/MacOS/scrcpy"
SRV="$APP/Contents/Resources/scrcpy-server"
LAUNCHER="$APP/Contents/Resources/launch.sh"
STUB="$APP/Contents/MacOS/PhoneMirror"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
LAUNCHER_SRC="$TOOLS/phonemirror-launcher.sh"
STUB_SRC="$TOOLS/phonemirror-stub.c"
ADB="${ADB:-$(command -v adb 2>/dev/null || true)}"
PREFIX="${SCRCPY_PREFIX:-$(brew --prefix scrcpy 2>/dev/null || true)}"

fails=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n        fix: %s\n' "$1" "$2"; fails=$((fails + 1)); }
ver()  { "$1" --version 2>/dev/null | head -1 | awk '{print $2}'; }
running() { pgrep -f "$BIN" >/dev/null 2>&1; }
is_wireless() { printf '%s\n' "$1" | grep -qE ':|_adb-tls-connect'; }
# adb usually auto-connects paired phones it sees over mDNS; this covers when it hasn't.
reconnect() {
  "$ADB" mdns services 2>/dev/null | awk '$2 ~ /_adb-tls-connect/ {print $3}' | while read -r addr; do
    "$ADB" connect "$addr" >/dev/null 2>&1
  done
}

do_check() {
  echo "PhoneMirror check ($APP)"

  # 1. adb sees the phone, authorised. Wireless if it can be had: reconnect over mDNS.
  if [ -z "$ADB" ]; then
    fail "adb not found" "brew install android-platform-tools"
  else
    list() { "$ADB" devices 2>/dev/null | sed '1d' | awk 'NF {print $1, $2}'; }
    lines=$(list)
    if ! printf '%s\n' "$lines" | awk '$2 == "device" {print $1}' | grep -qE ':|_adb-tls-connect'; then
      reconnect; lines=$(list)
    fi
    wifi=$(printf '%s\n' "$lines" | awk '$2 == "device" {print $1}' | grep -E ':|_adb-tls-connect' | head -1)
    usb=$(printf '%s\n' "$lines" | awk '$2 == "device" {print $1}' | grep -vE ':|_adb-tls-connect' | head -1)
    states=$(printf '%s\n' "$lines" | awk '{print $2}')
    if [ -n "$wifi" ]; then
      ok "adb sees the phone wirelessly ($wifi)${usb:+, and over USB}"
    elif [ -n "$usb" ]; then
      ok "adb sees the phone over USB only (wireless: off, other network, or not paired)"
    else
      case "$states" in
        *unauthorized*) fail "device is 'unauthorized'" "accept 'Allow USB debugging?' on the phone (tick 'Always allow'); if no prompt: Developer options -> Revoke USB debugging authorisations, re-plug" ;;
        *offline*) fail "device is 'offline'" "re-plug / toggle Wireless debugging; then: $ADB kill-server && $ADB start-server" ;;
        *) fail "adb sees no device (USB or wireless; mDNS found no paired phone)" \
"wireless: phone on the same Wi-Fi, Developer options -> Wireless debugging ON, then read out
              the 'IP address & Port' on that screen -> $ADB connect <ip:port>.
              'Pair device with pairing code' only if adb says the phone isn't paired.
              Cable: unlock the phone, data cable (not charge-only), re-plug" ;;
      esac
    fi
  fi

  # 2. The bundle exists, and its signature is intact.
  if [ ! -x "$BIN" ] || [ ! -f "$SRV" ]; then
    fail "bundle missing or incomplete: $APP" "build it (one-off, see the phone integration file)"
    return
  fi
  if codesign --verify --deep "$APP" 2>/dev/null; then ok "signature valid"
  else fail "signature invalid (macOS will refuse to open it)" "codesign --force --deep -s - \"$APP\""; fi

  # 3. The bundled scrcpy still loads its libraries and matches Homebrew's.
  bv=$(ver "$BIN")
  if [ -z "$bv" ]; then
    fail "bundled scrcpy does not start (libraries moved by a brew upgrade?)" "\"$0\" rebuild"
  elif [ -n "$PREFIX" ] && [ -x "$PREFIX/bin/scrcpy" ]; then
    hv=$(ver "$PREFIX/bin/scrcpy")
    if [ "$bv" != "$hv" ]; then
      fail "bundled scrcpy $bv, Homebrew has $hv" "\"$0\" rebuild"
    elif ! cmp -s "$SRV" "$PREFIX/share/scrcpy/scrcpy-server"; then
      fail "bundled scrcpy-server differs from Homebrew's" "\"$0\" rebuild"
    else
      ok "scrcpy $bv, matches Homebrew"
    fi
  else
    ok "scrcpy $bv (Homebrew copy not found, version not compared)"
  fi

  # 4. The bundle's launcher is the one in the repo.
  if cmp -s "$LAUNCHER" "$LAUNCHER_SRC"; then ok "launcher matches phonemirror-launcher.sh"
  else fail "launcher differs from $LAUNCHER_SRC" "quit the app, \"$0\" rebuild"; fi

  # 5. The app is running, with the arguments the skill relies on.
  if running; then
    args=$(pgrep -fl "$BIN" | head -1)
    dev=$(printf '%s\n' "$args" | sed -n 's/.* -s \([^ ]*\).*/\1/p')
    if is_wireless "$dev"; then via="wireless"; else via="USB"; fi
    case "$args" in
      *--stay-awake*) ok "PhoneMirror running ($via${dev:+, $dev}, --stay-awake)" ;;
      *) fail "PhoneMirror running without --stay-awake (screen will sleep)" "quit it, \"$0\" rebuild" ;;
    esac
  else
    fail "PhoneMirror not running" "open \"$APP\""
  fi
}

do_rebuild() {
  [ -d "$APP/Contents" ] || { echo "! no bundle at $APP: rebuild only refreshes an existing one" >&2; exit 1; }
  [ -n "$PREFIX" ] && [ -x "$PREFIX/bin/scrcpy" ] && [ -f "$PREFIX/share/scrcpy/scrcpy-server" ] \
    || { echo "! Homebrew scrcpy not found (prefix: '${PREFIX:-none}'): brew install scrcpy" >&2; exit 1; }
  [ -f "$LAUNCHER_SRC" ] && [ -f "$STUB_SRC" ] || { echo "! launcher or stub source missing in $TOOLS" >&2; exit 1; }
  command -v cc >/dev/null || { echo "! no C compiler: xcode-select --install" >&2; exit 1; }
  if running; then echo "! PhoneMirror is running: quit it first (Cmd-Q, or pkill -f \"$BIN\")" >&2; exit 1; fi

  old=$(ver "$BIN"); new=$(ver "$PREFIX/bin/scrcpy")
  cp -f "$PREFIX/bin/scrcpy" "$BIN" && chmod 755 "$BIN" \
    && cp -f "$PREFIX/share/scrcpy/scrcpy-server" "$SRV" \
    && cp -f "$LAUNCHER_SRC" "$LAUNCHER" && chmod 755 "$LAUNCHER" \
    && cc -O2 -o "$STUB" "$STUB_SRC" \
    && codesign --force --deep -s - "$APP" 2>/dev/null \
    || { echo "! copy or re-sign failed" >&2; exit 1; }
  [ "$(ver "$BIN")" = "$new" ] && codesign --verify --deep "$APP" 2>/dev/null \
    || { echo "! rebuilt bundle does not start or verify" >&2; exit 1; }
  echo "Rebuilt: scrcpy ${old:-unknown} -> $new, launcher refreshed, re-signed, verified. Open the app again."
}

case "${1:-}" in
  check)   do_check; [ "$fails" -eq 0 ] ;;
  rebuild) do_rebuild; [ "$fails" -eq 0 ] ;;
  *) echo "usage: phonemirror.sh check | rebuild" >&2; exit 64 ;;
esac

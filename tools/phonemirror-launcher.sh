#!/bin/sh
# PhoneMirror launcher: installed as Contents/Resources/launch.sh in the app bundle by
# `phonemirror.sh rebuild`. This file is the source of truth; don't edit the bundle copy.
# The bundle's executable is a compiled stub (phonemirror-stub.c) that execs this script,
# because launchd won't spawn a script directly.
#
# It picks the device, then execs the bundled scrcpy. exec keeps the PID, so the window
# still belongs to bundle local.phonemirror and keeps its computer-use grant.
#
# Device choice:
#   1. a wireless device, if adb lists one. Also when the cable is plugged in, so that
#      pulling the cable does not kill the mirror.
#   2. nothing connected: reconnect to a paired phone found over mDNS, wait once, retry.
#   3. otherwise the USB device.
#   4. none at all: show an alert saying what to do, and exit.
# scrcpy's output goes to ~/Library/Logs/PhoneMirror.log (overwritten per launch).

bin="$(cd "$(dirname "$0")/../MacOS" && pwd)/scrcpy"
ADB="${ADB:-adb}"
exec >"$HOME/Library/Logs/PhoneMirror.log" 2>&1

online()   { "$ADB" devices | awk 'NR > 1 && $2 == "device" {print $1}'; }
wireless() { online | grep -E ':|_adb-tls-connect' | head -1; }
reconnect() {
  "$ADB" mdns services | awk '$2 ~ /_adb-tls-connect/ {print $3}' | while read -r addr; do
    "$ADB" connect "$addr"
  done
}

serial=$(wireless)
if [ -z "$serial" ] && [ -z "$(online)" ]; then
  reconnect; serial=$(wireless)
  # A fresh adb server needs a moment before mDNS has seen the phone.
  [ -z "$serial" ] && { sleep 2; reconnect; serial=$(wireless); }
fi
[ -z "$serial" ] && serial=$(online | head -1)

if [ -z "$serial" ]; then
  echo "no device: $("$ADB" devices | sed 1d)"
  osascript -e 'display alert "PhoneMirror: no phone found" message "Wireless: on the phone, Developer options → Wireless debugging on (same Wi-Fi as the Mac). Or plug in the USB cable. Then open PhoneMirror again."' >/dev/null
  exit 1
fi

echo "device: $serial"
exec "$bin" -s "$serial" --window-title PhoneMirror --stay-awake "$@"

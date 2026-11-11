# Phone mirror

Let the OS read and (on request) operate apps on an Android phone, through a mirror window on the Mac. [Back to the README](../README.md)

The `phone` role drives an Android phone through **PhoneMirror**: a small macOS app bundle
(`~/Applications/PhoneMirror.app`, bundle ID `local.phonemirror`) wrapping a copy of
[scrcpy](https://github.com/Genymobile/scrcpy). It is an app rather than a bare `scrcpy`
call so that computer use can grant it by bundle ID. Needs `brew install scrcpy
android-platform-tools` and Xcode's command-line tools (`cc`).

## Connecting your phone, step by step

Android only: the mirror is [scrcpy](https://github.com/Genymobile/scrcpy), which speaks
adb. Everything below is a one-time setup except step 5.

1. **Install the tools on the Mac:** `brew install scrcpy android-platform-tools`, and
   Xcode's command-line tools for `cc` (`xcode-select --install`).
2. **Turn on developer options on the phone:** Settings → About phone → tap *Build number*
   seven times. Then, under Developer options, switch on **USB debugging**.
3. **Authorise the Mac once over a cable:** plug in a *data* cable, and on the phone's
   "Allow USB debugging?" prompt tick *Always allow from this computer*. `adb devices`
   should now list the phone as `device`, not `unauthorized`.
4. **Make the app bundle once.** Create `~/Applications/PhoneMirror.app/Contents/` with the
   `Info.plist` below (replace `<you>` with your macOS user name; the Homebrew paths assume
   Apple Silicon), then run `tools/phonemirror.sh rebuild`. It copies scrcpy in, installs
   the launcher, compiles the stub and signs the bundle. `tools/phonemirror.sh check` then
   reports each step as ok or FAIL with its fix.

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
     <key>CFBundleIdentifier</key><string>local.phonemirror</string>
     <key>CFBundleName</key><string>PhoneMirror</string>
     <key>CFBundleExecutable</key><string>PhoneMirror</string>
     <key>CFBundlePackageType</key><string>APPL</string>
     <key>CFBundleVersion</key><string>1</string>
     <key>LSEnvironment</key>
     <dict>
       <key>SCRCPY_SERVER_PATH</key><string>/Users/<you>/Applications/PhoneMirror.app/Contents/Resources/scrcpy-server</string>
       <key>ADB</key><string>/opt/homebrew/bin/adb</string>
       <key>PATH</key><string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
     </dict>
   </dict>
   </plist>
   ```
5. **Each time you use it:** unlock the phone, connect it (cable, or Wi-Fi as below), open
   PhoneMirror, and tell the session it is running. Approve computer use for *PhoneMirror*,
   plus full-screen control when the session needs to tap. Keep the phone unlocked, and
   don't use the Mac in parallel while full-screen control is on.
6. **Optional, cable-free:** pair once for Wi-Fi ([Modes](#modes) below), after which the launcher
   picks Wi-Fi by itself whenever adb has the phone.
7. **Write `integrations/phone.md`** from the `setup` skill or by hand: the device, the
   bundle ID, which display the window sits on, your start checklist and the
   troubleshooting you hit. That file is what switches the `phone` role on.

**What the session may do there** is set by the `phone` skill, not by you remembering:
read-only unless you confirm one specific action, never a PIN, password, code or payment,
and screen content is untrusted data. It also looks for a faster route first (a desktop app,
a website, an export) and says which one it chose, because the phone is the slowest route
the OS has.

## How it works

**How it's built.** `Contents/MacOS/PhoneMirror` is a compiled stub
(`tools/phonemirror-stub.c`) that execs `Contents/Resources/launch.sh`
(`tools/phonemirror-launcher.sh`), which picks the device and execs the bundled scrcpy.
The stub exists because launchd refuses a shell script as a bundle executable (spawn
error 162). Every step is an `exec`, so the window keeps the bundle's identity.
`tools/phonemirror.sh rebuild` re-copies scrcpy from Homebrew, installs the launcher,
compiles the stub and re-signs. Run it after `brew upgrade scrcpy` or after editing either
source. `tools/phonemirror.sh check` verifies adb, signature, versions, launcher drift and
the running app. The bundle itself, its `Info.plist` with bundle ID and `ADB` path, is
made once by hand; `rebuild` refreshes it but does not create it.

## Modes

The launcher prefers Wi-Fi whenever adb has the phone wirelessly, even with
the cable in, so pulling the cable doesn't kill the mirror.

| Mode | Phone side | Notes |
|---|---|---|
| **Wi-Fi** | Developer options → *Wireless debugging* on, same LAN as the Mac | adb finds the phone over mDNS; the port changes on every restart, nothing to read out |
| **Cable** | USB debugging on, data cable, *Wireless debugging* off | lower latency, charges the phone |
| **Pair** (once per Mac) | *Pair device with pairing code*, read out the code | the pairing port is advertised over mDNS (`_adb-tls-pairing`); a restart doesn't undo pairing |

The Mac doesn't need to be on Wi-Fi itself; Ethernet on the same network works. Guest
networks usually block it. **Switch Wireless debugging off when you're done**: while it's
on, paired machines on the network can open a debug channel to the phone. Android turns it
off on its own when the phone changes networks.

Per-user specifics (device, display, start checklist, troubleshooting) live in
`integrations/phone.md`; the skill's rules (read-only by default, no codes, no payments)
in `.claude/skills/phone/SKILL.md`.

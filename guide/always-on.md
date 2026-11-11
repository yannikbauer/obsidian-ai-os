# Always on: the vault from your phone

How to keep a full OS session reachable from the phone, and what still works when the
computer is off. Optional, and specific to the Claude desktop app on macOS.
[Back to the README](../README.md)

## The problem

The vault is a folder on one computer. That is what keeps it private and fast, and it is
also why a phone cannot reach it: a cloud session has no access to local files, and a
Claude project on the phone only sees the copies you uploaded (see [Advisors](advisors.md)).
So by default the OS is a desk tool.

Two settings and one small utility change that.

## The three pieces

**1. Remote Control.** The Claude desktop app can make a local session reachable from the
Claude app on your phone. That session runs on the computer, with the vault, the hooks and
every skill, so from the phone you get the whole OS, not a copy of it. Turn on the Remote
Control default in the desktop app's settings, so every session starts reachable.
The scheduled tasks in `setup/scheduled-tasks/` also switch it on as their first step, so a
digest or check-in that runs while you are out can be followed and answered from the phone.
A session may refuse the switch (unattended runs sometimes do); the task then says so in one
line rather than retrying.

**2. A computer that stays awake.** A sleeping Mac reaches nobody, and a scheduled task
that falls due while it sleeps runs only when the app next opens. A keep-awake utility
fixes that. Amphetamine (free, in the Mac
App Store) is one: start a session by hand when you leave, or let it keep the Mac awake
whenever it is on power. How you configure it is up to you. macOS's built-in
`caffeinate` does the same from a terminal, with fewer options.

**3. The scheduled tasks.** Optional runs that do their work while you are away and leave
the result in the vault: the weekday newsletter and job digests, the weekly vault health
report, the morning daily check-in (which opens a session and waits for you), and the
advisor summaries. One file each in `setup/scheduled-tasks/`; the `setup` skill installs
them. They need the machine awake and the desktop app running.

## What you get

- **On the phone, with the computer awake:** open a Remote Control session and talk to
  the OS as at the desk. Ask what the newsletter digest found, answer the morning
  check-in, run an advisor through the `advisors` skill with the whole vault behind it,
  capture a task. Writes still ask you first, and every gate still runs, because it is the
  same session on the same machine.
- **On the phone, with the computer off or asleep:** the Claude projects still work from
  their stubs and phone copies, and collect what must reach the vault in a phone inbox,
  which the next session on the computer writes in after you confirm. Less, but never
  nothing.

## What it costs

- **Power and wear.** An awake Mac draws power; on a laptop, keep it on the charger.
- **Reachability is your account's.** Whoever can open your Claude account on a phone can
  drive a session that can read your vault. Treat the account like the vault itself:
  strong password, two-factor sign-in.
- **The machine has to be on.** A shut-down computer cannot be woken from the phone. The
  stubs are the fallback for exactly that.

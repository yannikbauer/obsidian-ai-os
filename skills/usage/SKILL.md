---
name: usage
description: Report this account's Claude Code token usage — rate against session limits, which projects and sessions it goes to, and how it compares to the recorded baseline. Trigger on "/usage", "token usage", "what am I spending", "how many tokens", "am I near my limit", "usage stats", "is my usage going up".
argument-hint: "[--project NAME]"
allowed-tools: Bash
---

# Usage

Reads Claude Code's own transcripts. **Read-only** — it touches nothing but
`~/.claude/projects/**/*.jsonl`.

## The report

!`sh "${CLAUDE_PROJECT_DIR}/_AI/tools/usage.sh" $ARGUMENTS 2>&1`

## How to read it back to the user

Lead with **rate, not totals.** Session limits respond to how much is spent inside a
rolling window, so the peak 1h/5h/24h figures are the ones that bear on hitting a limit;
a lifetime total answers nothing actionable. Say which window is closest to a problem.

**Compare against the baseline.** `history/usage-baseline.md` holds dated snapshots. Read
it and say what changed — *"the 5h peak is up 40% on the first baseline"* is worth saying;
repeating a number the user can already see is not. If the current reading is materially
different, offer to append a new baseline block.

**Separate building from using.** Long agentic build sessions cost an order of magnitude
more than routine use, and they are a phase rather than a steady state. When a few sessions
dominate the total, say so plainly — a subscription decision made from a build week will
overstate the steady state.

**Three honest limits, and state them rather than papering over them:**

- **The weighted total is a workload figure, not a bill.** It applies published list ratios
  to make the buckets comparable. On a flat subscription no per-token money is being spent.
- **Nothing here records hitting a limit.** The transcripts show consumption, not
  interruption. Whether the user actually got cut off is something only they know — ask,
  do not infer it from the numbers.
- **Do not map these figures to plan tiers.** Thresholds change and guessing them produces
  confident wrong advice. Give the user their real numbers and point them at the current
  plan pages to compare.

**Scope.** Defaults to every project on the machine, because limits are account-wide and a
single project can be a fraction of the true figure. `--project <name>` narrows deliberately
— say which scope a number came from whenever it could be mistaken for the other.

## Related

- `tools/usage.sh --json` — machine-readable totals, for scripting or assertions.
- `history/usage-baseline.md` — dated snapshots, so a reading has something to compare to.
- Running the script directly costs no tokens. Prefer that when the user wants raw numbers
  rather than an interpretation; mention it if they ask for usage repeatedly.

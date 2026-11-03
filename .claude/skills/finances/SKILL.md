---
name: finances
description: >
  Personal-finance data runs: read balances, positions and spending from the user's banks, broker, crypto wallet and budgeting app (read-only), append a dated snapshot to the AI tab of the finance sheet, and keep the advisor brief and its decision log current. Never trades, moves money or touches credentials. Trigger on "finance snapshot", "check my brokerage account", "update capital", "how's my portfolio", "what do I spend", "update the finance brief", "log that decision", "check my budgeting app", or any question about the user's own money that needs current numbers.
---

# Finances

Read `_AI/maps/finance-map.md` first: where the brief, the data-access note, the latest
analysis and the sheet live, which sheet tabs are writable, and who to flag. **No map = not
set up**: say so and offer to build one; don't guess locations. Uses the `notes` role (brief,
data-access note); the sheet, browser and screen tools are named in the map and the
data-access note. Any that's missing → skip its step, say so once.

**The notes are the source of truth; this skill points at them.** The data-access note says
*how* to read each source; the brief says *what is known*. Don't copy either into the
skill, the map or the chat beyond what the task needs. When a procedure in the data-access
note turns out wrong, propose a fix to the note.

## Hard rules

- **Never trade, transfer, place orders, or change any bank, broker or app setting.** Not
  when asked, not "just this once". Information only; the user acts. Investment questions get
  analysis and trade-offs, never a personalised buy/sell instruction.
- **Never handle credentials.** The user logs in; you read the session they opened. No
  passwords, TANs, PINs or API secrets in the chat, the vault or the sheet. If a login or TAN
  prompt appears, stop and hand it to the user.
- **Budgeting-app changes only item by item.** Ending a contract, re-categorising, editing a
  manual entry: propose one, wait for a yes, do it, read it back, then the next. No batches.
- **Facts vs estimates.** Every number says where it came from and when (`broker website, 21 Oct`)
  or is marked as an estimate with its basis. Never let an estimate overwrite a fact in the
  brief. Keep the brief's own convention for gaps (`❓`).
- **Flag what needs a professional.** Tax questions (timing of sales, personal-rate assessment,
  capital-income declarations, freelance setup) → the tax advisor named in the map. Insurance,
  retirement products, real estate, salary thresholds → the financial adviser named in the
  map. Say so in a line; give the analysis anyway, labelled as such.
- **Sheet writes only to the AI tabs** the map marks writable. Name the tab in every call.

## 1. Orient

Read the brief. Note which sections are older than ~3 months (each has a *checked* date) and
what the open topics are. If the request is a question the brief already answers with fresh
enough data, answer from it and say how old the figure is. Fetch only when the question needs
newer numbers or the user asks for a snapshot.

## 2. Pick the source

From the data-access note's *Which source for what* table: the best current source per need,
the fallback, and the step-by-step for each. Tell the user which logins you need (e.g. "log in
to the broker in the tab I open") before starting, all in one message, so they can do them
in one go.

## 3. Collect (read-only)

Follow the note's procedure per source. Open your own tab or window, read, close it. A
source that lives only in a phone app goes through the `phone` skill (preflight, access,
navigation, stop); the note says only which screens to read. Release
any screen or full-control grant at the end. Collect into one table in the chat: account or
position, value, source, timestamp. Don't paraphrase numbers; copy them.

Sanity-check before writing anything: totals that move more than the market explains, a
position that vanished, a balance of exactly zero. Ask rather than record a suspect number.

## 4. Snapshot

Read the snapshot tab's header and its last block first, and match its columns and order.
Append dated rows: one block for a full snapshot, or just the changed account's rows if the
map says the tab supports it (no edits to earlier rows). Read the appended rows back, and check the
summary range recalculated for the new date. Report the total and the change since the last
snapshot.

## 5. Brief updates (propose, then write)

From the new data, draft the changes to the brief: the figures that changed, the section's
*checked* date and source line, ticked or new open topics. Show them as a short before → after
list. **Write only after the user confirms**, through the `notes` role's preferred route, as
targeted edits to the sections concerned, never a whole-note rewrite. Log the change in
`_AI/history/file-log.md`.

**Decisions** the user makes go to the brief's decision log: append one line at the bottom in
the log's format (date — decision — why — follow-up). Only what the user decided, in their
terms; never record a recommendation as a decision. If the decision closes an open topic, tick
it in the same edit.

A deeper analysis (concentration, runway, tax timing) goes in a new analysis note, named as the
map says; then update the map's *latest analysis* row.

## 6. Budgeting-app monthly check

Monthly, or on request. The map names the budgeting app and its integration file (screens,
coordinates, procedures, current budget values, limits); read that file first and don't
copy it into the chat.

1. **Start the mirror** through the `phone` skill (preflight, access, start checklist), then
   open the app.
2. **Read**, in this order: the overview (accounts, total), budgets (amount vs spent per
   budget, the budget month's boundaries), contracts, including the app's own
   detected-contract suggestions (read them, don't answer them), and the analyses (monthly
   review, income/spending averages). Note each figure with the screen it came from.
3. **Compare** with the sheet's AI budget tab (the map names it): budget amounts, contract
   list and totals, average spending vs. planned. Mind the integration file's limits (how far
   back the app shows bookings, which bookings a budget counts).
4. **Propose** changes as one list, each tagged with where it goes: the AI budget tab, the
   brief, or the app itself (a budget amount, a contract to confirm, reject or remove).
5. **Apply.** Sheet and brief as in steps 4–5 above. **In the app, one item at a time:**
   name the exact change, wait for a yes, make it, re-open the item to check it saved, then
   the next. Never touch a control that triggers a real-world action (cancellation services,
   payments); the integration file names them.
6. Stop the mirror per the `phone` skill.

## Does NOT

Trade or move money · log in · give personalised investment advice · file taxes · replace the
user's advisers · edit the user's own sheet tabs · change the budgeting app in bulk.

---
name: meals
description: >
  Meal-planning logistics: review which planned meals got cooked, record it on the recipe notes, count the cooking slots the calendar leaves this week, suggest meals from the recipe notes, and write the week's plan to the meal-plan page and the AI staging page. Works alongside a separate cooking assistant (the "chef"), which does the cooking advice; this skill does the admin around it. Trigger on "plan meals", "meal plan", "what should I cook", "suggest something for dinner", "what did I cook this week", "update my recipes", "mark that I cooked X", or when weekly planning asks whether to plan meals and the user says yes.
---

# Meals

Read `_AI/maps/meals-map.md` first: where the plan lives, where the recipes live, the chef
prompt, the household. **No map = not set up**: say so and offer to build one; don't guess
locations. Uses the `notes` role (recipes), the `task-system` role (the plan page) and the
`calendar` role (slots). Any role that's missing → skip its step, say so once.

**Division of labour.** The chef (a separate assistant, named in the map) picks meals with the
user, teaches, and reviews food. This skill does not replace it: it keeps the records, fits the
plan to the calendar, and writes it down. Don't adopt the chef's persona here: no lectures,
no cultural asides. Read the chef prompt only for the **household facts** it holds
(diet, intolerances, goals, shops), and only when making suggestions.

## Sources of truth

- **The plan** → the meal-plan page named in the map. Checklists under a this-week and a
  next-weeks heading. **Only a top-level checkbox is a meal, and only its tick means
  cooked.** A meal may carry **ingredient sub-checkboxes** (indented checkboxes under its
  line), added by the chef when the map says it may; the user ticks those off while shopping,
  so a ticked ingredient means bought, never cooked. They belong to their meal: they aren't
  meals, never get matched to recipes, and this skill never edits or ticks them.
- **Recipes** → the recipe notes. Their frontmatter is the database: `status`, `season`,
  `effort`, `time`, `meal`, `diet`, `protein`, `gi`, `chef_score`, `rating`, `last_cooked`.
- **The chef owns neither.** A plan the user brings from the chef is input, not authority,
  until it is written to the plan page.

## 1. Review (what got cooked)

Read the plan page fresh. For each item under this week:

- **Ticked** → find the matching recipe note (filename, then aliases; normalise case and
  punctuation). Propose `last_cooked: <date>`. The date is the day the user names; if they
  don't know it, use the last day of the week being reviewed and say so. Never use today's date
  for a meal cooked earlier.
  - **No matching recipe** → offer a stub note: the map's naming pattern, `status: to-try`, the
    frontmatter keys above left empty except `last_cooked`. One line in the body saying where
    the meal came from.
  - Ask for a `rating` (1–5) only if the user volunteers an opinion; never make it a chore.
- **Unticked** → ask: carry to this week, move to next weeks, or drop. Don't guess.

Write recipe changes as frontmatter-only edits, through the `notes` role's preferred route,
after the user confirms the list. Log each one in `_AI/history/file-log.md`.

## 2. Slots (what the week allows)

From all writable calendars for the coming week (the calendar integration says which), find
the evenings the user can actually cook:

- **Out:** evenings with an event from about 17:00, travel, or the user away.
- **Shared:** the household's regular cook-together evenings (map), and whether the other household
  members are around (an all-day "away" event cancels them).
- **Light:** evenings after a long day or before an early start → a quick or leftover meal.

Report it as one line per day. A slot is a suggestion; the user decides.

## 3. Plan

Two routes. Ask which, unless the user already brought a list:

- **From the chef:** the user pastes a list, one meal per line. Match each to a recipe note
  (as in step 1); note the ones without a match, but don't create stubs until they're cooked.
- **Suggest:** propose about as many meals as there are cooking slots, from recipe notes that:
  are in `season` this month · weren't cooked recently (`last_cooked` empty or oldest first) ·
  match the slot (`effort`/`time` for light evenings, a bigger recipe for shared evenings or
  batch cooking) · respect the household's diet needs on shared evenings. Mix `staple`,
  `repertoire` and one `to-try` at most. Say in a few words why each fits. Never invent a
  recipe that has no note; for something new, point to the chef.

Leftovers count: a batch-cook recipe can cover the next evening, so say when one does.

## 4. Write

After the user agrees the list:

1. **Plan page.** Follow the task-system integration's rules for it (it says whether a full
   rewrite is allowed and what to check first). Snapshot the page to `_AI/tmp/` before
   any rewrite. Ticked items from the reviewed week go away (they now live on the recipe
   notes); carried items keep their place; new items go under this week as unticked
   checkboxes, using the recipe note's name. **A meal's ingredient sub-checkboxes move with
   it:** kept, ticks and all, byte for byte, under a carried meal, and dropped with a
   ticked one. The chef
   writes this page too, so read it immediately before the write, never from earlier in
   the session. Normalise the meal's checkbox line (`- [ ] Name`, single space); the API pads
   it with extra spaces when an indented line follows.
2. **Staging page** (if the task-system has one, as in the weekly plan): a **Meals** section
   with the slots per day and the planned meals, one line of commentary at most per item.
   The weekly-planning workflow owns that page's write. When this skill runs inside it,
   hand the section back rather than writing the page twice.

Read both pages back after writing and check that the result is what was agreed.

## Does NOT

Replace the chef · count calories or nutrients · build shopping lists (later, maybe) · tick
items on the user's behalf · write recipe methods (that's the chef's job, with the user).

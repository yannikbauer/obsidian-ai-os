# Sharing and publishing

Exporting a clean copy, publishing it to a public repo, the gates on the way, and versioning. [Back to the README](../README.md)

## Sharing your copy

Two scripts, for two different jobs. Both run the same leak check; neither ever
touches your private `_AI/`.

| | `export.sh` | `publish.sh` |
|---|---|---|
| Produces | a fresh directory | a commit on the public repo |
| Git history | **new** (single commit) | **preserved** |
| Target must | not exist | already exist as a remote |
| Use for | a one-shot copy, a zip, a first push | every update after the first |

```bash
bash _AI/setup/export.sh ~/aios-export     # one-shot snapshot
bash _AI/setup/publish.sh --dry-run        # see what would change publicly
bash _AI/setup/publish.sh                  # export, diff, confirm, push
```

Both copy only the generic parts — framework, `.claude/`, tests, templates, setup,
LICENSE — via an **allowlist**, so a new personal folder is excluded by default
rather than by remembering to exclude it.

### The leak check

Every export greps the result for personal tokens. Patterns live in
`_AI/config/leak-patterns.local`, which is never exported; edit it as your identifiers
change. If anything matches, the run **aborts** rather than publishing.

Commit subjects and changelog entries are scanned too, because they go public as
**metadata** that the file scan never sees, and private subjects name people freely.
`publish.sh` runs that scan with `leak-check.sh --names`, which adds the names from your
own `maps/people-map.md` (bold names and their aliases) and the persona names in
`maps/advisors-map.md`. A hit in a subject falls back to a plain commit message; a hit in a
changelog entry aborts the release and asks for hand-written `--notes`.

Some personal tokens legitimately belong in a public repo — the copyright holder's
name in `LICENSE`, the repo URL in this README. `_AI/config/leak-allow.local` lists those
exact literals, which are stripped from a matched line before it is judged. The
exemption is per-literal, not per-pattern or per-file: your bare first name
appearing *anywhere else* in `LICENSE` still fails the check, verified by a
negative test. Keep entries as specific as possible — listing a bare first name
there would silently disable the check everywhere.

(This paragraph is why the allowlist holds `Firstname Lastname` and not
`Firstname`: prose that names you in an example would otherwise sail through.)

`publish.sh` syncs with `--delete`, so removing a file from the allowlist removes
it from the public repo too, and it **confirms before pushing** by default: the
leak check is the only barrier between this repo and a public one, and a push
cannot be taken back.

### Configuring the destination

`publish.sh` ships in the export, so it holds no personal defaults. Put yours in
`_AI/config/publish.local` (sourced as shell, never exported):

```sh
AIOS_PUBLIC_REMOTE=https://github.com/<you>/<repo>.git
AIOS_PUBLIC_GIT_NAME="Your Name"
AIOS_PUBLIC_GIT_EMAIL=<you>@users.noreply.github.com
```

The email matters more than it looks. **Commit metadata is not file content**, so
the leak check cannot see it — a plain `git commit` would stamp the address from
your `~/.gitconfig` onto every public commit, permanently and unscrubbably. The
script refuses to run without an explicit one for that reason. A
`users.noreply.github.com` address still links commits to your GitHub account.

## Automated publishing

Two workflows, split on a single principle: **verifying is automatic, publishing
is an act you take.**

Content pushed to a public repo is not retractable. The push enters GitHub's
public events stream, which third parties mirror, and a later force-push does not
remove the old commit — it stays reachable by SHA. So nothing here publishes on a
schedule or on a push.

| | `verify.yml` | `publish.yml` |
|---|---|---|
| Runs | every push to `main` | manual dispatch only, typing `publish` to confirm |
| Publishes | **never** | pushes to the public repo's `main` |
| Needs a secret | **no** — the public repo is readable anonymously | yes, `PUBLIC_REPO_TOKEN` |
| Produces | the exact public-facing diff, in the run summary and as an artifact | a public commit |

Both run the same gates first:

| Gate | Catches |
|---|---|
| `tests/run.sh` | a broken hook — they fail *open*, so breakage is otherwise silent |
| `actionlint` | a workflow that is itself broken — the thing that runs every other gate |
| `export.sh` leak check | identifiers you listed in `config/leak-patterns.local` |
| **gitleaks** | the generic classes you would not have predicted — API keys, tokens, private keys |
| `install.sh` into a scratch vault | an export that passes every check and then does not install |

### What the gates cannot catch

The scanners catch *categories*: identifiers you listed, and strings shaped like
credentials. The realistic leak for a system like this is neither. It is **personal
content drifting into a file that is nominally generic** — a client's name in a
skill example, a health detail in a workflow, a former employer's process in
`CLAUDE.md`. Those are exactly the files you edit most, and no pattern will flag
them.

Only reading the diff catches that, which is why publishing is manual and the diff
is rendered before anything leaves the repo.

### The review checklist

Whoever reviews a sync — you, or Claude in a session on your behalf — reads the
diff against these, in order:

1. **Names of real people** other than the repo owner. Friends, partners,
   colleagues, clients. Examples are the usual culprit.
2. **Employer or client specifics** — internal process, tooling, terminology,
   anything learned under an obligation.
3. **Personal circumstances** — health, money, relationships, living situation.
   Skills describing "what to do when the user is low on energy" drift here easily.
4. **Identifiers** the patterns do not know yet: a new calendar, a new account, a
   new tool's workspace ID. Anything that matches, add to `config/leak-patterns.local`.
5. **Paths that expose vault structure** beyond what `templates/` already shows.
6. **Tone** — text written *to* you rather than *for* a reader. Not a leak, but it
   reads as unfinished in a public repo.
7. **Are the README and the guides still true?** `publish.sh` lists every commit since
   the README or a guide last changed that touched skills, hooks, tools, setup, templates or `CLAUDE.md`, and will not
   push until you say the README was read against them. A list of names can be checked by a
   script (`check-coverage.sh` does); whether a sentence is still true cannot.
8. **Is it the right level of detail for a first read?** The README is an overview: each
   feature gets a paragraph and a link, and the detail lives in `guide/`.
   `check-coverage.sh` holds the mechanical half on every commit (a length budget for the
   page and for each section, every guide linked, every link resolving). The judgment half
   is the `first-reader` subagent: it gets only the repo's files, no conversation, reads the
   README as a newcomer, and reports where it got lost, what it did not need, and what was
   missing. Run it on any publish that changed the README, read its report next to the diff,
   and move detail into a guide rather than trimming it away.

Claude can do this reading and report, so a clean sync costs you a yes. It is a
good first pass at 1–5 and an unreliable judge of what *you* consider private:
whether naming a former employer's method is acceptable depends on obligations
that are not in the text. Treat a flag as a question for you, not a verdict, and
treat "clean" as "nothing mechanical found", not as permission to never look.

### Publishing

The usual path is a session: ask Claude to publish, and it runs the gates, builds
the export, diffs it against the public repo, reads the diff against the checklist
above (running `first-reader` when the README changed), reports, and pushes on your yes. Review and push stay in one operation, so
what you approved is what ships.

Without a session, run **Publish to public repo** from the Actions tab and type
`publish` to confirm. Locally, `bash _AI/setup/publish.sh` does the same with a
diffstat and a prompt.

### Versioning

Publishing syncs content. **Releasing** gives that content a name someone else can
refer to — which is the only reason a version exists here. Your own git history
already answers *what changed* for you; a fork has no access to it, so the public
repo needs an anchor of its own.

`publish.sh` therefore asks once, at the point you are already reviewing the diff:

```
Release as? [patch/minor/major/keep]
```

- **patch** — fixes and wording
- **minor** — new behaviour a plain `git pull` absorbs
- **major** — **your install needs manual action**: a renamed `.local` knob, a moved
  path, scaffolding `install.sh` cannot add on a re-run
- **keep** — publish without cutting a release

That last distinction is the one carrying real information, and it is the reason
this is SemVer rather than a date. Everything else about the scheme is convention.

Cutting a release writes `VERSION`, tags the public repo `vX.Y.Z`, and prepends an
entry to a public `CHANGELOG.md`. The entry is **generated** from your private commit
subjects since the previous tag — never hand-written, so it cannot drift from what
actually shipped — and it goes through the same leak check as the commit message,
because a commit subject is metadata that the export's file scan never sees. A hit
aborts the release rather than degrading quietly: a changelog is a permanent file,
not a message.

Two deliberate refusals. `--yes` (how CI publishes) keeps the current version, so a
machine never decides that a sync was a release. `--branch` carries no release
either — the branch is a proposal that may never merge, and a tag pointing into an
abandoned branch is a permanent claim about a version that never shipped. Re-using
an existing tag is refused outright, because unlike a commit a moved tag rewrites
what an already-cloned copy resolves to.

`CHANGELOG.md` lives only in the public repo. It accumulates there across releases,
which is why the sync excludes it from `--delete`.

### One-time setup

1. Create the public repo **with** a README:
   ```bash
   gh repo create <repo> --public --add-readme \
     --description "A personal AI OS for Obsidian, driven by Claude Code"
   ```
   `--add-readme` gives it a `main` branch immediately. A repo with no commits
   has no default branch, which makes the first diff and push fiddlier than it
   needs to be. The placeholder README is overwritten by the first sync
   (`rsync --delete`), so nothing is lost.

2. Create a **fine-grained personal access token** at
   *Settings → Developer settings → Personal access tokens → Fine-grained*:
   - Resource owner: your account
   - Repository access: **Only select repositories** → the public repo
   - Permissions: **Contents: Read and write**. That is the only one needed —
     `Metadata: Read-only` adds itself automatically and is mandatory.

   Scoping the token to the one public repo means a leaked token cannot reach
   anything private. Note the token is only used by `publish.yml`; `verify.yml`
   needs no credential at all, because it only reads a public repo.

3. Add it to the **private** repo as a secret named `PUBLIC_REPO_TOKEN`:
   ```bash
   gh secret set PUBLIC_REPO_TOKEN --repo <you>/<private-repo>
   ```
   It prompts for the value, so nothing lands in your shell history.

4. Set `PUBLIC_REPO` in the `env:` block of **both** workflows to `<you>/<repo>`.

5. Set a reminder for the token's expiry date. When it lapses, `publish.yml`
   fails at the push step — nothing publishes wrongly, it just stops — but the
   failure is easier to act on if you were expecting it.

## Licence

Apache-2.0 rather than MIT for the **patent grant**: contributors licence any patents
covering their contribution, and the licence terminates for anyone who brings a patent suit
over the work. MIT is silent on patents. Relevant enough in AI tooling to be worth the
longer file, at no cost to how freely you can use this.

Everything published before 2026-09-07 was MIT and predates the first tagged release. Those
copies remain MIT for anyone who has them: a licence change never reaches backwards. From the
first tag on, the tag says which terms a copy came under.

If you fork this, put your own destination in `_AI/config/publish.local` rather than editing
`publish.sh`.

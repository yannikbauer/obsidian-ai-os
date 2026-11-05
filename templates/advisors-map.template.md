# Advisors Map

Which advisors exist, where their prompt notes live, and what each one reads, so the
`advisors` skill can route and `tools/advisor-stub.py` can build the project stubs. This is a
**map**: personal, never exported. The pattern itself is in the skill and the README
(*Advisors*). No advisors yet? Leave the registry empty; the skill offers to add one.

**Format:** one `### <Advisor>` block per advisor under *Registry*, one `- **Key:** value`
line per field. `tools/advisor-stub.py` parses these blocks, so keep the keys as they are.
Empty fields can be left out.

- **Project:** the Claude Desktop project's name.
- **Prompt note:** the vault note that is the source of truth.
- **Read at start:** what a session reads after the prompt note, as a phrase that follows
  "read that note" (e.g. `then \`_NOTES/<Advisor> _ Memory.md\``). Goes into the stub verbatim.
- **Phone docs:** the project docs a phone chat works from, as a phrase. Goes into the stub.
- **Source extra / Files extra / Footer:** extra stub text after the source line, at the end
  of the *Files* paragraph, and as a closing paragraph before the fallback.
- **Admin skill:** the AIOS skill doing the admin.
- **Router note:** extra reading or rules for a laptop session; not in the stub.

## Hub advisor

Optional. The advisor that owns the shared findings ledger and integrates across the others,
and the plumbing behind its modes (scripts, where experiments are recorded, snapshots for the
phone). Delete this section if you don't run one.

## Privacy

Which advisors' notes are private, and whose notes stay inside their own sessions.

## Registry

### Example Advisor

- **Project:** Example Advisor
- **Prompt note:** `_NOTES/Claude Example Advisor prompt.md`
- **Read at start:** then `_NOTES/Example Advisor _ Notebook.md`
- **Phone docs:** *Notebook*
- **Admin skill:** —

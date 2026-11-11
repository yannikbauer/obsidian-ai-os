# Local models

What runs on your own machine through Ollama, why it is the privacy lane rather than the
default, and where else a local model could earn its place. Optional throughout.
[Back to the README](../README.md)

## What runs locally today

| Job | Model | Where it is set | Why local |
|---|---|---|---|
| Embeddings for [vault search](notes.md#vault-search) and the duplicate check in the health report | `bge-m3` (multilingual, 1024 dimensions, about 1.2 GB) | `config/search-index.local` (`model`) | every note gets embedded, so no note has to leave the machine for search to work |
| Descriptions for notes labelled `private` or `secret`, in the backfill and the weekly health run | a small chat model, default `qwen3.5:9b-32k` | `POLISH_LOCAL_MODEL` for `tools/frontmatter-polish/propose.py` | enforced in code: a labelled note never goes to a cloud model, whatever backend you pick |

Everything else in the OS runs on Claude. Both jobs above degrade instead of failing: without
Ollama, search is keyword-only, and a proposal for a private note waits until the next run.

## Setting it up

1. Install [Ollama](https://ollama.com) and start it (the app, or `ollama serve`).
2. Pull the models: `ollama pull bge-m3` for search, and a chat model for the privacy lane,
   for example `ollama pull qwen3.5:9b`. Gemma models (`gemma3:4b`, `gemma4:12b`) work too;
   pick by what your RAM allows.
3. **Give the chat model a larger context window.** Ollama's default context is small, and a
   long note gets silently cut. Make a variant with a Modelfile:

   ```
   FROM qwen3.5:9b
   PARAMETER num_ctx 32768
   ```

   then `ollama create qwen3.5:9b-32k -f Modelfile`. The `-32k` in the default model name is
   that variant.
4. `tools/vault-search.py status` and a test search confirm the embedder; the `setup`
   skill walks through both.

`OLLAMA_HOST` points the tools at another machine if Ollama runs elsewhere on your network.

## Why it is the privacy lane, not the default

Measured on one real backfill (843 notes, a fanless M2 MacBook Air): Haiku took about 4 s a
note, the local 9B model about 46 s, and Haiku's descriptions were better. So the split is by
sensitivity, not by cost: normal notes go to the cloud model, labelled ones stay local. A
second finding shaped the design: in the pilot, a local model given a free-text prompt still
repeated diary content it was told not to. Private notes therefore get a description built
from fixed word lists, so even the local model cannot put their content into a field that
search and other agents read.

## Where else a local model could help

Ideas, not built. Each fits the same rule: content that should not leave the machine, or many
small background jobs where a cloud bill or rate limit gets in the way.

- **Pre-sorting private transcripts**: a first-pass summary of a therapy or medical recording
  on the machine, with only the summary going further.
- **Pre-filtering mail**: classify newsletters and job alerts before the digest reads them,
  so the cloud model sees fewer threads.
- **Vault upkeep in the background**: tags, link suggestions and duplicate triage for the
  [repair layer](notes.md#vault-maintenance), run overnight without touching a usage limit.
- **A fallback harness**: if Claude is unavailable, a local model in another harness can still
  read the skills and maps, which are plain markdown. The hooks would not follow it: they are
  Claude Code's, which is what the vault-gateway idea under *Where it's going* in the README is
  about. Try it once on a copy of the vault, or the fallback stays theoretical.

**Where it does not help:** working on the OS itself, coding, and long agentic sessions with
many tool calls. Small local models lose the thread, emit tool calls as text, and run into
harness context limits; Claude stays the better and, on a subscription, cheaper tool there.

## Hardware, roughly

The model's speed depends on memory bandwidth, and how fast it reads a long prompt on GPU
compute. As a rule of thumb from published reports: 16 GB runs embeddings and a 4–9B chat
model; 32 GB runs a mid-sized model but tightly; about 48 GB is the practical floor for the
larger mixture-of-experts models with a long context. More memory buys headroom, not a
smarter model.

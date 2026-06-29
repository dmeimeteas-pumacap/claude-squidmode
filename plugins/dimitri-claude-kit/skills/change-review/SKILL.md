---
description: "Apply whenever making code edits, modifications, or additions. Governs how changes are presented inline with diffs, annotations, and interactive review options. Always active unless suppressed."
---

# Change Review Skill

## Purpose

Present code changes with enough inline detail that the reader can follow the chain of thought without switching to the IDE or clicking through a GUI diff viewer. Targets incremental and minor revisions where inline visibility has the highest value.

This skill will eventually be absorbed into a broader code-editing skill. Design decisions here should be treated as components, not final policy.

---

## Default State

**Always active.** Apply these rules to every code edit response unless suppressed.

### Suppression

| Trigger | Scope | Re-enable |
|---|---|---|
| Natural language: "just make the changes", "skip the diffs", "blast through this", "no review" | Current response only | Automatic on next message |
| Explicit: "leave diffs off until I say so", "suppress review for this session" | Rest of session | Natural language: "back to review mode", "show diffs again" |

When suppressed for the session, acknowledge it once: _"Review mode off for this session — say 'back to review mode' to re-enable."_

---

## Diff Format

Use **unified diff style** inside a `diff` code block.

### Hunk header

Every hunk must show the file name and starting line number:

```
### FileName.cs — line 42
```diff
@@ -42,4 +42,5 @@
```

### Why annotation

Above each hunk, write **one sentence for what changed and one sentence for why**. Reference broader task context when it is directly relevant — not as a default on every hunk.

```
Removed redundant `= false` initializer — bool fields default to false in C#.
Added `ILogger` field — required by the tracing calls introduced below.
```diff
- private bool _isReady = false;
+ private bool _isReady;
+ private readonly ILogger _logger;
```

### Context lines (adaptive)

| Hunk size | Context lines above/below |
|---|---|
| 1–3 changed lines | 3 lines |
| 4+ changed lines | 1 line |

---

## Thresholds

### Existing files

- **Under 15 changed lines:** show the full diff.
- **15 or more changed lines:** show the first significant hunk, then append a truncation marker:

  > `[... N more lines changed in FileName.cs — say "show full diff" to expand]`

### New files

- **Under 15 lines:** show the full file in a code block with the why annotation.
- **15 or more lines:** show a prose description only:

  > Created `FileName.cs` — [one sentence describing purpose, key members, and what it connects to].

### Deleted files

Show a deletion notice with a one-sentence description of what the file contained:

  > Deleted `FileName.cs` — [one sentence describing what it was and why it was removed].

---

## Multi-File Changes

When a task touches more than one file:

1. **Lead with a summary map** — one line per file, stating what changed and why:

   > - `ServiceRunner.cs` — added null guard on startup logger
   > - `WorkerWithLogs.cs` — threaded `CancellationToken` through to the inner loop
   > - `AppConfig.cs` — added `WorkerTimeout` property

2. **Follow with per-file diffs** in the same order, each with its own header and why annotation.

3. Any file in the summary can be expanded on request: _"expand WorkerWithLogs"_ shows the full diff for that file even if it was truncated.

---

## Pause Mode

Off by default. Activate by requesting it explicitly or when running in ask-permissions mode.

### Granularity

| Mode | Behavior |
|---|---|
| Default | Pause after each **file** is shown |
| `--hunk` flag at request time | Pause after each **hunk** within a file |

At each pause point, present the options clearly:

```
[continue] [show full] [explain] [undo]
```

- **continue** — proceed to the next file or hunk
- **show full** — expand any truncated diff before continuing
- **explain** — produce a structured explanation (see below)
- **undo** — revert this file's changes and reconsider the approach

### Explain depth

When `explain` is requested at a pause point, produce two short paragraphs:

1. **Local reasoning** — the trade-off considered, why this approach over alternatives, what would break if done differently.
2. **Broader fit** — how this change connects to the overall task, what it enables downstream, what it replaces in the architecture.

Keep each paragraph to 3–5 sentences. This is a code-review comment, not a design document.

---

## Quick Reference

| Situation | Behavior |
|---|---|
| Small edit (< 15 lines) | Full diff + why annotation |
| Large edit (≥ 15 lines) | First hunk + truncation marker |
| New small file (< 15 lines) | Full file in code block |
| New large file (≥ 15 lines) | Prose description only |
| Deleted file | Deletion notice + one-sentence description |
| Multiple files | Summary map → per-file diffs |
| Suppressed (per-response) | Make changes silently, no diff output |
| Suppressed (session) | Make changes silently, acknowledge once |
| Pause mode | Per-file pause with continue/show full/explain/undo |

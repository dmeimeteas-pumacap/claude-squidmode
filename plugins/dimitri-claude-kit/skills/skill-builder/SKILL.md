---
name: skill-builder
description: Builds or revises Claude Code skills. Use when someone wants to create a skill, automate a task, turn a workflow into a command, build a /slash command, or asks "how do I make a skill." Also trigger when someone says "build me a skill", "make a skill for X", "I want to automate Y", "create a skill that does Z", "update my skill", "revise the skill", "fix the skill", or "tweak the skill." Also trigger when someone says a skill misbehaved, did the wrong thing, missed a case, fired when it shouldn't have, or when they say "the skill needs updating", "that skill has a problem", "fix the skill based on what just happened", or similar post-invocation feedback. Always check for an existing skill before starting the interview.
---

# Skill Builder

You build and revise Claude Code skills. Before doing anything else, determine which of three modes applies: building a new skill, deliberately revising an existing one, or processing post-invocation feedback. You write files to disk — never paste SKILL.md contents in chat.

---

## Step 0 — Check for existing skill

Before asking any interview questions, do the following:

1. List the contents of `~/.claude/skills/` to see what user-built skills already exist. If that
   directory does not exist, there are no user skills yet — that is normal on a fresh/plugin
   install, not an error (it gets created on the first skill write). When `CLAUDE_PLUGIN_ROOT` is
   set, ALSO list `${CLAUDE_PLUGIN_ROOT}/skills/` — kit-shipped skills live there, and revising one
   of those means proposing the change to the kit author, not editing the plugin cache in place.
2. If the user mentioned a skill name, check whether a directory matching it (exactly or approximately) already exists in either location.
3. Also check whether a skill was just created in this session — if the user says "the skill I just made" or "the one we just built," treat that as a match.

**If a matching skill is found:**

Read the SKILL.md and present a one-line summary of what it does. Then ask: "I found an existing skill at `[its actual path]/SKILL.md` — [one-line summary]. Do you want to revise this one, or build a new skill from scratch?" (A kit-shipped skill under the plugin root is revised as a NEW user skill in `~/.claude/skills/` that overrides/extends it, or as a suggestion to the kit author — never by editing the plugin cache.)

- If **revise**: skip to Revision Mode below.
- If **new skill**: proceed to Step 1.

**If no match is found:** proceed directly to Step 1 without mentioning this check.

---

## Revision Mode

Used when the user wants to update an existing skill rather than build a new one.

1. Read the full existing SKILL.md.
2. Ask: "Which part isn't working the way you want — the trigger (when it fires), the steps (what it does), the guardrails, the gotchas, or something else?" Offer these as options with an Other/write-in.
3. For each section the user flags, ask one targeted question to understand the desired change. Examples:
   - **Trigger/description**: "What phrase or situation should fire it that currently doesn't — or what is it firing on that it shouldn't?"
   - **Steps/behavior**: "Walk me through what it does now vs. what you want it to do instead. Where does it diverge?"
   - **Guardrails**: "What did it do that it shouldn't have, or what constraint is missing?"
   - **Gotchas**: "What broke or produced bad output, and under what conditions?"
4. Apply only the sections that need changing. Do not rewrite sections the user did not flag.
5. Write the updated file to the same path. Confirm path and summarize what changed.

Do not run the full five-question interview in revision mode — it wastes time on sections that are already correct.

---

## Feedback Mode

Used when running a skill produced a wrong, incomplete, or unexpected result — and the fix belongs in the skill itself, not in the user's next prompt. The signal is reactive: something just happened that the skill should have handled differently.

Triggers include: "that skill did the wrong thing", "it missed a case", "the skill fired when it shouldn't have", "fix the skill based on what just happened", "the skill needs updating after that run", or when you observe mid-task that a skill's instructions caused a gap.

**Do not conflate with Revision Mode.** Revision Mode is deliberate and user-initiated before or outside a run. Feedback Mode is reactive — the evidence is fresh context from an actual invocation.

1. Identify the skill. If the user named it, confirm. If not, ask: "Which skill are we patching — the one that just ran, or a different one?"
2. Read the current SKILL.md in full.
3. Ask one focused question: "What did the skill do, and what should it have done instead? Be as specific as you can — exact input, what happened, what you expected."
4. Map the failure to the anatomy section most likely at fault:
   - Wrong trigger / fired unexpectedly → **description** (frontmatter)
   - Missed a case or did steps out of order → **body/steps**
   - Did something it shouldn't have → **guardrails**
   - Failed silently or broke on an edge case → **gotchas**
   - Wrong output format or destination → **body/steps** or **output section**
5. Propose the targeted patch: quote the current text, show the proposed replacement, and state why it addresses the observed failure. One section only unless the failure clearly spans two.
6. Ask: "Does this fix it, or is there more?" Apply only on confirmation.
7. Write the updated file. Confirm path and summarize the single change made.

**Rules for Feedback Mode:**
- One section per round. If the user describes multiple failures, address the most critical one first and offer to continue.
- Do not use the failure as a trigger to rewrite unrelated sections — stay surgical.
- If the failure suggests the skill is fundamentally misscoped (wrong tool for the job), say so rather than patching around it.
- After writing, add the failure case to the skill's **Gotchas** section if it isn't already there — even if the fix was in a different section. Observed failures are evidence; record them.

---

## Step 1 — Interview

Ask these questions **one at a time**. Do not move to the next question until the user has given an answer specific enough to fill the corresponding skill section. If an answer is vague, ask one targeted follow-up before moving on. Do not write the skill until all five are answered with enough specificity.

Multiple-choice options are fine and keep the flow efficient — but always include an "Other" option or a free-text write-in so the user is never trapped by the choices. If a follow-up is needed, ask it as a plain question rather than another multiple-choice.

**Q1 — The task (maps to: body/steps, gotchas)**

Ask: "Walk me through the last time you did this by hand. What did you start with — a file at a specific path, a URL, a command output, something else? What did you do to it, step by step? And what did you end up with at the end?"

A good answer names the concrete inputs, lists the steps (even roughly), and describes a concrete output. If the answer is abstract ("I process reports"), ask: "Can you give me a specific example — what file or input, what did you do to it, and what came out?"

**Q2 — The trigger (maps to: description, frontmatter controls)**

Ask: "Should this skill fire automatically when you describe a task, or will you always invoke it explicitly with a specific phrase or command? If automatic: what words or situation should cause it to run? If explicit: what exact phrase would you type to kick it off — give me the actual words you'd use."

A good answer tells you: (a) explicit vs. auto, and (b) 2–3 real trigger phrases or a clear situational trigger. If they say "when I want to run it," ask: "What would you actually type — what are the words?"

**Q3 — The output (maps to: body/steps, guardrails)**

Ask: "Where exactly should the output go, and what should it look like? For example: a new file at a specific path, an in-place edit to an existing file, a message printed in chat. If it's a file, what's the naming convention and should it overwrite existing output or always create a new one?"

A good answer gives a concrete destination (path pattern or 'in chat'), format, and overwrite behavior. If the answer is vague ("just show me the result"), ask: "Should it write anywhere to disk, or is the chat response the only output?"

**Q4 — Hard limits (maps to: guardrails)**

Ask: "What is the worst thing this skill could do if it misbehaved? Specifically: are there files or directories it must never touch? Actions that require your explicit confirmation before running? Should it only operate within a specific project or file type?"

A good answer names at least one concrete constraint. If they say "nothing comes to mind," ask: "Think about files it could accidentally overwrite or delete — is there anything off-limits?"

**Q5 — Failure modes (maps to: gotchas)**

Ask: "What is the minimum this skill needs to work at all — a specific file, a configured tool, a certain input format? What should happen if that's missing or malformed: stop and tell you, skip silently, or try to recover? Is there anything unusual about your setup it would need to account for?"

A good answer names the required preconditions and a failure behavior. If the answer is "I don't know," prompt: "If you ran it right now on a blank project with nothing set up, what would fail first?"

---

**After all five are answered**, say: "Got it — writing your skill now." Then proceed to Step 2.

---

## Step 2 — Write the SKILL.md

Produce a complete SKILL.md covering all ten anatomy parts. Write it to:

```
~/.claude/skills/[name]/SKILL.md
```

Create the directory if it doesn't exist. Confirm the path to the user when done.

### The Ten Anatomy Parts

Every skill you write must address all ten. Here's what each one is and why it matters:

---

**1. Name** (frontmatter)

Kebab-case. Two words max. This is the invoke handle — how the user calls it and how other skills reference it. Pick it carefully: renaming later means hunting every callout that references it.

```yaml
name: weekly-report
```

---

**2. Description** (frontmatter — the most important field)

Claude reads this to decide *when* to fire the skill. Not the body — the description. This is the trigger.

- Too vague → never runs
- Too greedy → fires on the wrong things
- Pack it with real trigger phrases the user actually said in the interview
- Include an explicit "use this when…" sentence
- When the skill misbehaves, tune this first — almost never the body

```yaml
description: "Turns this week's metrics CSV into a one-page report. Use when someone says 'weekly report', 'run the report', or asks to summarize this week's numbers."
```

---

**3. Gotchas** (body section)

Real failures from live runs — wrong paths, broken writes, edge cases — written down so the next run avoids the trap. Use the user's answers from question 5 of the interview. Leave a placeholder comment if the skill is brand new.

```markdown
# Gotchas
- Empty CSV on holiday weeks → skip, don't crash
- Date format varies by source — normalize before comparing
# (Fill in more after your first run)
```

---

**4. Guardrails** (body section)

Hard limits — the won't-do list. Use the user's answers from question 4. More constraints = more autonomy: when the worst case is bounded, the skill can run unattended.

```markdown
# Guardrails
- Never edit the raw metrics.csv
- Only write inside /reports/
- If input is missing, stop and tell the user — don't guess
```

---

**5. Embedded skills & callouts** (body section, if applicable)

A skill can invoke other skills by name. State is shared through files, not imports. If this skill chains into others, document which ones and what it hands off. If it's standalone, say so.

---

**6. Memory allocation** (body section, if applicable)

Templates, configs, and reference docs live beside SKILL.md and load only when the skill runs — keeping the main context lean. State passes by writing to disk, not stuffing the conversation. If this skill needs sub-files, note them here and create them.

---

**7. Frontmatter controls** (frontmatter, as needed)

Optional switches that change how Claude handles the skill:

- `disable-model-invocation: true` — run only when explicitly called; never auto-triggered by description match
- `user-invocable: true` — shows in the `/` command menu
- `argument-hint: "description"` — tells callers what override arguments to pass

Only include these if the skill needs them. Don't add them by default.

---

**8. Body / steps** (body — the actual recipe)

Numbered steps Claude follows in order once the skill fires. This is where the real "how" lives.

Rules for good steps:
- **Specific beats vague.** Bad: "Understand the context." Good: "Read the file at X and note the values in column C."
- **Verifiable.** Give Claude a way to check each step before moving on: "Confirm the output file exists before continuing."
- **Sequenced.** Order matters. Each step should produce something the next step can use.

---

**9. Sub-files, scripts & evals** (folder structure, if needed)

If the skill needs supporting files, create them alongside SKILL.md:

```
skill-name/
├── SKILL.md
├── template.md       ← output template loaded on run
├── config.json       ← tunable parameters
└── evals/
    └── evals.json    ← test cases (add after first real run)
```

For simple skills, SKILL.md alone is fine.

---

**10. Versioning & iteration** (end of body)

Tell the user how to improve the skill over time:

- When triggering misfires → edit the **description** first, not the body
- When output quality drifts → add a gotcha or tighten a step
- After 5+ real runs → add eval cases to `evals/evals.json` to verify edits don't break it
- A maintenance skill (like `ghengis-khan`) can audit the whole skill set for drift

---

## Step 3 — Confirm and offer next steps

After writing the file:

1. Confirm the path: "Skill written to `~/.claude/skills/[name]/SKILL.md`."
2. Show the user the exact phrase they can type to trigger it for the first time.
3. Offer: "Want me to run a quick test to make sure it triggers correctly?"
4. Offer: "Want me to run `/grill-me` on this design before you put it into use? It stress-tests the plan by walking every branch of the decision tree — good for catching gaps before the first real run."

---

## Rules

- **Check for existing skill first. Always.** List `~/.claude/skills/` (tolerating its absence on a fresh install) and, when `CLAUDE_PLUGIN_ROOT` is set, `${CLAUDE_PLUGIN_ROOT}/skills/`, before asking any questions.
- **Interview first for new skills. Always.** Never write a new skill before all five questions are answered.
- **Revision mode for existing skills.** Never run the full interview on a skill that already exists — only ask about the sections that need changing.
- **Write the file.** Don't paste the SKILL.md contents in chat — write it to disk and confirm the path.
- **All ten parts.** Even if some sections are short (e.g., "no sub-files needed"), address them.
- **Use the interview answers.** The description must include the user's actual trigger phrases. Guardrails come from their "never do" answer. Gotchas come from their "what could break it" answer.
- **One question at a time.** Don't front-load all five questions at once.
- **Multiple-choice is fine; always include an escape hatch.** When using options, always provide "Other" or a free-text write-in. If the user's answer doesn't map cleanly to a choice, ask one plain follow-up rather than another round of options.

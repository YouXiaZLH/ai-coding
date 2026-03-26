---
name: start
description: "First-time onboarding 鈥?asks where you are, then guides you to the right workflow. No assumptions."
argument-hint: "[no arguments]"
user-invocable: true
allowed-tools: Read, Glob, Grep, AskUserQuestion
---

# Guided Onboarding

This skill is the entry point for new users. It does NOT assume you have a game
idea, an engine preference, or any prior experience. It asks first, then routes
you to the right workflow.

---

## Workflow

### 1. Detect Project State (Silent)

Before asking anything, silently gather context so you can tailor your guidance.
Do NOT show these results unprompted 鈥?they inform your recommendations, not
the conversation opener.

Check:
- **Engine configured?** Read `.copilot/docs/technical-preferences.md`. If the
  Engine field contains `[TO BE CONFIGURED]`, the engine is not set.
- **Game concept exists?** Check for `design/gdd/game-concept.md`.
- **Source code exists?** Glob for source files in `src/` (`*.gd`, `*.cs`,
  `*.cpp`, `*.h`, `*.rs`, `*.py`, `*.js`, `*.ts`).
- **Prototypes exist?** Check for subdirectories in `prototypes/`.
- **Design docs exist?** Count markdown files in `design/gdd/`.
- **Production artifacts?** Check for files in `production/sprints/` or
  `production/milestones/`.

Store these findings internally. You will use them to validate the user's
self-assessment and to tailor follow-up recommendations.

---

### 2. Ask Where the User Is

This is the first thing the user sees. Present these 4 options clearly:

> **Welcome to GitHub Copilot Game Studios!**
>
> Before I suggest anything, I'd like to understand where you're starting from.
> Where are you at with your game idea right now?
>
> **A) No idea yet** 鈥?I don't have a game concept at all. I want to explore
> and figure out what to make.
>
> **B) Vague idea** 鈥?I have a rough theme, feeling, or genre in mind
> (e.g., "something with space" or "a cozy farming game") but nothing concrete.
>
> **C) Clear concept** 鈥?I know the core idea 鈥?genre, basic mechanics, maybe
> a pitch sentence 鈥?but haven't formalized it into documents yet.
>
> **D) Existing work** 鈥?I already have design docs, prototypes, code, or
> significant planning done. I want to organize or continue the work.

Wait for the user's answer. Do not proceed until they respond.

---

### 3. Route Based on Answer

#### If A: No idea yet

The user needs creative exploration before anything else. Engine choice,
technical setup 鈥?all of that comes later.

1. Acknowledge that starting from zero is completely fine
2. Briefly explain what `/brainstorm` does (guided ideation using professional
   frameworks 鈥?MDA, player psychology, verb-first design)
3. Recommend running `/brainstorm open` as the next step
4. Show the recommended path:
   - `/brainstorm` 鈥?discover your game concept
   - `/setup-engine` 鈥?configure the engine (brainstorm will recommend one)
   - `/map-systems` 鈥?decompose the concept into systems and plan GDD writing order
   - `/prototype` 鈥?test the core mechanic
   - `/sprint-plan` 鈥?plan the first sprint

#### If B: Vague idea

The user has a seed but needs help growing it into a concept.

1. Ask them to share their vague idea 鈥?even a few words is enough
2. Validate the idea as a starting point (don't judge or redirect)
3. Recommend running `/brainstorm [their hint]` to develop it
4. Show the recommended path:
   - `/brainstorm [hint]` 鈥?develop the idea into a full concept
   - `/setup-engine` 鈥?configure the engine
   - `/map-systems` 鈥?decompose the concept into systems and plan GDD writing order
   - `/prototype` 鈥?test the core mechanic
   - `/sprint-plan` 鈥?plan the first sprint

#### If C: Clear concept

The user knows what they want to make but hasn't documented it.

1. Ask 2-3 follow-up questions to understand their concept:
   - What's the genre and core mechanic? (one sentence)
   - Do they have an engine preference, or need help choosing?
   - What's the rough scope? (jam game, small project, large project)
2. Based on their answers, offer two paths:
   - **Formalize first**: Run `/brainstorm` to structure the concept into a
     proper game concept document with pillars, MDA analysis, and scope tiers
   - **Jump to engine setup**: If they're confident in their concept, go
     straight to `/setup-engine` and write the GDD manually afterward
3. Show the recommended path (adapted to their choice):
   - `/brainstorm` or `/setup-engine` (their pick)
   - `/design-review` 鈥?validate the concept doc
   - `/map-systems` 鈥?decompose the concept into individual systems with dependencies and priorities
   - `/design-system` 鈥?author per-system GDDs (guided, section-by-section)
   - `/architecture-decision` 鈥?make first technical decisions
   - `/sprint-plan` 鈥?plan the first sprint

#### If D: Existing work

The user has artifacts already. Figure out what exists and what's missing.

1. Share what you found in Step 1 (now it's relevant):
   - "I can see you have [X source files / Y design docs / Z prototypes]..."
   - "Your engine is [configured as X / not yet configured]..."
2. Recommend running `/project-stage-detect` for a full analysis
3. If the engine isn't configured, note that `/setup-engine` should come first
4. Show the recommended path:
   - `/project-stage-detect` 鈥?full gap analysis
   - `/setup-engine` 鈥?if not configured
   - `/design-system` 鈥?if systems index exists but GDDs are incomplete
   - `/gate-check` 鈥?validate readiness for next phase
   - `/sprint-plan` 鈥?organize the work

---

### 4. Confirm Before Proceeding

After presenting the recommended path, ask the user which step they'd like
to take first. Never auto-run the next skill.

> "Would you like to start with [recommended first step], or would you prefer
> to do something else first?"

---

### 5. Hand Off

When the user chooses their next step, let them invoke the skill themselves
or offer to run it for them. Either way, the `/start` skill's job is done
once the user has a clear next action.

---

## Edge Cases

- **User picks D but project is empty**: Gently redirect 鈥?"It looks like the
  project is a fresh template with no artifacts yet. Would Path A or B be a
  better fit?"
- **User picks A but project has code**: Mention what you found 鈥?"I noticed
  there's already code in `src/`. Did you mean to pick D (existing work)? Or
  would you like to start fresh with a new concept?"
- **User is returning (engine configured, concept exists)**: Skip onboarding
  entirely 鈥?"It looks like you're already set up! Your engine is [X] and you
  have a game concept at `design/gdd/game-concept.md`. Want to pick up where
  you left off? Try `/sprint-plan` or just tell me what you'd like to work on."
- **User doesn't fit any option**: Let them describe their situation in their
  own words and adapt. The 4 options are starting points, not a prison.

---

## Collaborative Protocol

This skill follows the collaborative design principle:

1. **Ask first** 鈥?never assume the user's state or intent
2. **Present options** 鈥?give clear paths, not mandates
3. **User decides** 鈥?they pick the direction
4. **No auto-execution** 鈥?recommend the next skill, don't run it without asking
5. **Adapt** 鈥?if the user's situation doesn't fit a template, listen and adjust


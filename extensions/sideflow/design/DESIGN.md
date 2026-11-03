# Sideflow: product and design notes

What was decided and why. The app's side is in Sidefolk's docs/DECISIONS.md (D110 to D114), docs/SECURITY.md (T43) and docs/EXTENSIONS.md.
This folder isn't packed: `scripts/build.py` takes only the manifest, icon, words, assets and program.

## What it is

Teach your companion a routine. A flow is something you could read aloud: "Every weekday at 8:30, get today's plan, write three lines
with the AI, tell me." You say it to the companion or build it here, and both see and edit one saved thing.

**For** anyone with small jobs that repeat, non-coders included. **Not** a connector hub: Sidefolk has no account store, and extensions hold no
secrets. **Not** a node canvas: a canvas makes you think about wires, and these jobs are short lists with the odd "if".

**What it reaches (the founder, 2026-11-03: "every single thing that app can do"):** every extension's tools, MCP servers and programs on a card each time, nearly all of Sidefolk's own, a whole job for the companion under the person's trust settings, other flows, and starting when something happens in the app. Reachable isn't unattended: only what the person read exactly runs by itself.

**What it leads with:** watch it practise, with nothing changed, before it may act alone; then read once what it will do. That is what
workflow apps don't have, because they don't have a Guard.

## What was considered

| Idea | Decision |
|---|---|
| Free-form node graph | No: a canvas you drag about gets messy. The tree that arranges itself is the answer the founder chose (below) |
| A paragraph with clickable chips (concept B) | The most charming, and breaks on branches and on word order in ten languages. Its idea stays as the sentence on top of the flow |
| A rail with an inspector (concept A) | Built first, and rejected by the founder on sight: "very simple, very ugly, not clear". Replaced |
| Pencil to ink, a paper page | Generated and set aside when the founder sent their reference, a tidy builder |
| A tree of cards with a panel beside it | **Chosen, by the founder (2026-11-03).** Branches read at a glance; a line in colour for the way it went, grey for the way it didn't, dashed for what would happen |
| Ribbon, tiles, the companion holding the thread (concept C) | Its warmth stays: coloured tiles, a gradient line, a result word on each step, the companion in the hero |
| "Rehearse", "routine" | "Practice run" is plainer. "Flow" stays: it is in the name, and one word is less confusing than two |
| Triggers on a drop, on reminders, on agents finishing | Later. A drop needs a file named at run time, which asks each time; the others would leak titles to an extension without a card (D111) |
| Loops, parallel steps, flows calling flows | Later: each adds a concept to read |
| Waits of days | A day at most: longer is a schedule |
| Two cards in a row, for practice and for turning on | Practice has a card only if it reads something, and turning on says what's new first |

## The states, and the words for them

- **Draft**: nothing runs. Primary: Practice run, then Turn on once it has practised.
- **Practice run**: reads what Sidefolk vouches for, for real. Changes nothing, tells nobody. Says "Would: …" for the rest. A wait doesn't hold it, and it goes on as if the first answer were given.
- **On**: runs by itself under what the person read. An edit stays a draft ("On, as before. Your changes aren't live") until Apply changes.
- **Paused**: keeps what was allowed; resuming needs no card unless it changed.
- A run's **Needs you** (a card nobody answered) and **Interrupted** (Sidefolk stopped mid-step) say what to do: "It didn't happen: try again", "It happened: carry on", "Stop here". The choice names what the person knows.

## What runs where

All product logic is in this extension. From Sidefolk it uses, as any extension can:

| Ability | Used for | Who else it serves |
|---|---|---|
| `permissions.act`, `Actions` (D110) | Every action of a flow, through Guard | Any extension that orchestrates: a backup, a focus ritual |
| Plans (D110) | Running unattended under what the person read | A nightly export, a weekly report |
| Own watches (D111) | "When something changes" | A downtime log, a change feed |
| `tools.<name>.agents` (D112) | Connected agents writing drafts | Any extension with something an agent should do |
| `steps`, `field` in place, `multiple` (D113) | The rail and the inspector | A recipe, a checklist, a pipeline; templates; weekday picks |
| Page state (D105) | Going between screens, with Back | Any page with places |
| AI help (D100) | Write-with-AI steps, drafting from words | Any |
| Background (D63) | The clock and the journal | Any |

## Execution

One program, one background loop: a tick every 30 seconds and when woken, so a Mac asleep just misses its tick. `flows.json` and one file per run, written whole and
atomically. A run keeps its own copy of the definition, a program counter over a flat list of steps with branches as jumps, and its values.

| What happens | What it does |
|---|---|
| Sidefolk stops mid-step, a read or a question | Goes again on launch |
| Sidefolk stops mid-step, one that changes things | Not repeated. Interrupted, and the person says which |
| A card nobody answered, or a no | Parks as Needs you, tells the person. Nothing happened |
| A tool fails | The step's choice: stop (default), carry on; "try again later" only for what only reads, three times, 30 s, 2 min, 10 min |
| A wait | An instant on disk, resumed whenever Sidefolk is back |
| A schedule missed by more than five minutes | Run once when back (default), or note it as missed. Never several at once |
| Set off during a run | One more waits behind it, at most |
| 30 runs in an hour | Paused, and it says why |
| A tool gone, or an extension off | "To fix" on the rail before it runs |
| The person ends the plan in Settings | Paused, asks again |

Honest limits: flows run only while Sidefolk runs and the Mac is awake, and the page says so.

## Talking to it

Tools for the companion and agents: `flow_guide`, `list_actions`, `list_templates`, `list_flows`, `get_flow`, `create_flow`, `update_flow`, `practice_flow`, `start_flow`, `pause_flow`, `resume_flow`, `run_flow`, `list_runs`, `get_run`; for the companion, `continue_run` and `delete_flow`. `create_flow` with `start` is the one-sentence route: "make it and turn it on, asking me once". No-AI sentences: `what flows do i have`, `run {flow}`, `practice {flow}`, `turn on flow {flow}`, `pause flow {flow}`, `how did {flow} go`, `open sideflow`.

## Visual identity

The thread runs blue (#4FA8F5) to violet (#7C5CFC), in the icon and on the tree. Filled buttons and what's selected run the same way, deep enough to hold white (`#2A6FE8` to `#6E4BF2`). Violet is an accent, not the page, and each use has a reason (the founder: a designer's choices, not paint):

| Where | What | Why |
|---|---|---|
| The one main action on a screen | The full gradient | Rare, so "what do I do here" has one answer |
| The line a flow took; the selected card's edge | The thread's gradient | It's the product's idea: what happened, and where you are on it |
| The selected row, a picked day or option | A soft tint with accent words | A state, not an action: it mustn't compete with the button |
| Filters, secondary buttons, cards, canvas, words | The theme's neutrals | They carry the content; so it follows light, dark and any theme |
| Done, needs you, a step's kind | Green, amber, its own tile | They mean something else, and violet never stands in for them | The icon is `design/icon/master.png` generated and masked, in `icon.pdf`; `design/icon/alternative-branch.png` is the one not chosen. Tile colours mean the kind of step and nothing about its state: the state is always a mark and a word (D78). `redesign/` is the design the founder approved, `screens/` is the real thing. `concepts/` is what was explored before it.

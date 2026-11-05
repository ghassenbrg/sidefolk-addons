# Sideflow: what's done of the founder's findings and the roadmap

The founder, 2026-11-04: phases are fine, and the session ends when everything is built, tested and released. Sources: Sidefolk `sandbox/FINDINGS-2026-11-04.md` (A1-A9) and
`docs/research/sideflow-advanced-workflow-roadmap.md`. A line is ticked when its code and tests are in; "landed" means merged and released through the coordinator.

## Landings

| Landing | Holds | State |
|---|---|---|
| Stage 1 (D180) and Phase 0 | A1-A4; plan limit, branch scope and missing values, journal before effects, reviewed revision goes live, uncertain outcomes | In the gallery |
| Editing (D181, D182) | A5, A6, A7, A9: Save, Discard, undo, keys, check, what changed; move, outline, fold, find; forms, value menu, condition builder | In the gallery, snapshot.5, app 1252 |
| Engine (D198) | Typed values, for each, choose, try, call, finish, data, AI with fields, forms, waits, queues, time zones, parallel, run inspector, Stop, held-back runs | In the gallery, snapshot.6, minimum 1252 |
| Connections (D183) | A run waits for a tool that went away; a Connections page | In the gallery, snapshot.7, app 1292 |
| Repeat until | Round and round until it holds | In the gallery, snapshot.8, minimum 1292 |
| Fields (D184) | A tool's answer can hold fields | In the gallery, snapshot.9, app 1303 |
| Jobs (D195), triggers (D196), more | How far along a step is, Stop tells it; several ways to start; batches, group, fallback, make a step its own flow, pause, run again, try again from here | One snapshot, after L1. Add-ons `team/sideflow-more-2`, app `team/sideflow-triggers-app-2`. Clean read and suite at 683e066 + 1ab089c7; main with L1 still to merge, Permissions reads that resolution |
| One approval (L2; Permissions has L1, D186-D189, T53) | Run saves and applies, one card for what's new, no asking again for what was approved | Local `team/sideflow-approval` on the stack. Passes the founder's scenario on the real engine. App tests in the session's scratch `flow-cards/l2-app-tests.patch`, to go on an app branch with the Kit. After L1 is a snapshot |

## Still to build, in order (the coordinator, for the founder, 2026-11-05)

Each its own landing, with independent reads until a clean one, a suite on a built add-ons copy, an honest not-verified list. Ask the coordinator where a piece takes a decision or a security entry.

1. Typed mapping (type, sample, Literal/Secret/Expression modes), nested object parameters and forms, preview of resolved values.
2. Parallel: lane timeouts, sibling-cancel policy, other join modes. Declared types and a version pin for called flows.
3. Saved and pinned fixtures for practice; the explained diff and patch for the AI builder; the editor's repair offers (a producer moves, an agent edit conflicts); a Permissions tab, elapsed and usage in the inspector.
4. Stable-file detection and rename handling; idempotency keys; file and artifact references; durable job handles only if a tool needs them.
5. Scale: 100-200 cards (the board draws 64), breadcrumbs and focus on a subflow, wrap in a scope, resizable panels, compact Ask card.
6. The expression language (sandboxed, with its own security note); two reference connectors; pagination and rate-limit metadata; dependency-aware templates.

Also stated and owed: the later lists in each landing's MERGE-READY, among them a write's thrown error going to "did it happen?" rather than Recover, "Next:" ignoring the flow's time zone, `{{today}}` going stale over a days-long form, Skip sending a later action an empty value.

Known gap, in plain words (the coordinator's ruling, 2026-11-05): when you ask the agent to stop a flow, it stops that run and what it started, but not the lanes beside it, and it doesn't clear the flow's waiting starts; the Stop on the flow's page does all of it. On the later list: knowing who called, so an agent acting for the person can count as the person, is a general Kit ability for a later batch and needs a decision of its own.

## First after the stack ships (the coordinator, 2026-11-05)

The first fix of the next batch, before the small gaps below (the coordinator's ruling): Stop on a flow whose file can't be read can't clear its waiting starts, so they can go ahead after someone repairs that file. It needs a damaged flows file and a deliberate repair, and what goes ahead runs under the plan the person approved.

Known small gaps accepted for now, to fix first in the next batch:
- `{{a}} {{b}}` with one null and one empty sends spaces.
- `{{a}}, {{b}}` with both null sends ",".
- A final data step's null hides earlier words as the answer.
- Nulls inside a list passed as one whole value aren't checked.
- A callee, lane or repeat with only a carried-past failure gives "", so a later `{{k}}` can write a blank (the person's own choice).

Also on the later list: `{{k}}` after a called flow or repeat that made nothing says "didn't run"; a practice's single go can stop `{{again}}`; a practice can read with a made-up value through a text step; a null field in text goes as ""; a field over 8,000 characters is clipped with no note; an off flow in an untaken branch refuses the whole run; an off grandchild fails mid-run; a page Run that fails at start gives no notice; extracting a step makes optional values required; a 500×3 loop hits the per-run limit; `runAgain` starts a paused flow; a busy `plan.check` blanks marks.

Typed mapping's later list: reading the first number in words is a judgement, not a parser, so `Pos 3 129,50 €` reads 3129.5, `,5` reads 5, `192.168.100.200` reads as one long number, `Nov 5 120 €` reads 5120, `$3.459`, `1.234 BTC` and `USD/JPY 149.253` stop though they could be read, and a bare `1.299` is 1.299 because that's what a tool writes; an entry with a comma in it reads as two in the form and goes as one; a flow an agent wrote with words for a list or number may ask each run, since the plan holds the words and the call sends the list.

## Left out on purpose

Webhooks, Keychain accounts: they need a security decision of their own. Hosted runner, collaboration, freeform DAG, arbitrary code: the roadmap keeps them out.

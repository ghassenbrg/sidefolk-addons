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

Done on `team/sideflow-lanes`: Stop on a flow whose file can't be read now clears its waiting starts the first time it can be read, through a restart.

Known small gaps accepted for now, to fix first in the next batch:
- Nulls inside a list passed as one whole value aren't checked.
- A callee, lane or repeat with only a carried-past failure gives "", so a later `{{k}}` can write a blank (the person's own choice).

Also on the later list: `{{k}}` after a called flow or repeat that made nothing says "didn't run"; a practice's single go can stop `{{again}}`; a practice can read with a made-up value through a text step; a null field in text goes as ""; a field over 8,000 characters is clipped with no note; an off flow in an untaken branch refuses the whole run; an off grandchild fails mid-run; a page Run that fails at start gives no notice; extracting a step makes optional values required; a 500×3 loop hits the per-run limit; `runAgain` starts a paused flow; a busy `plan.check` blanks marks.

Typed mapping's later list: an entry with a comma in it reads as two in the form and goes as one; a flow an agent wrote with words for a list or number may ask each run, since the plan holds the words and the call sends the list.

## How words become a number (the coordinator's ruling, 2026-11-05)

`NumberWords` is the one reader: a number written plainly (`12`, `-3`, `12.5`), and nothing else. A number a tool or a form gave as a number is compared as that number, never as words. Every route goes through it: conditions, repeat checks, filters, sums, sort, the number op, a tool's number field, a called flow's number. Someone typing into a number field gets the same shape, and is told to write it plainly. We tried reading more twice, and each final read found ordinary strings read wrong without a stop (`Ports: 80,81`, `1 GB` against `500 MB`, `Down: 5%`), so this is the safe subset.

For the release notes, in plain words: a flow that compares or adds up text like `18 °C`, `$1,299.00`, `12%`, `CPU: 12%` or `Rain at 18` now stops, says which step and which words, and tells you to take the number from a tool's field or an AI step's field. It no longer picks a number out of the words. `1.500` and `1,500` stop too, since they could be fifteen hundred.

The person hears before a real run: a step's form and the flow's page mark a step that compares or adds up words, an agent sees it in `get_flow` and `update_flow`, a practice notes it on the step and goes on, and a real stop says the words and the fix.

Later list, for the expression language: units, currencies, thousands marks, percent.

A sort takes numbers, words with no digits in them, or dates written year first, and blanks go last either way round. Anything else with digits in it stops (`Item 12`, `USD 1,500`, `Q1 2026`), since which of those read as numbers never ended, as it didn't for reading a number out of words. So does a list of numbers and words together, and a field no row has. Later list: a sort that says it's by name, so `Item 9` comes before `Item 12` on the person's word; a JSON number with more than 17 digits after the point is rounded.

Later list, values (a read, 2026-11-06): a skipped step's blank isn't sent where an action names that step itself; reached another way, through a text step's words, a lane (lanes copy values, not what each step did) or a called flow's input, it still goes as an empty answer. Carrying "this was skipped" with a value through those is for later.

Stop isn't a failure (the coordinator's ruling, 2026-11-06): a called run or a lane that ends by a Stop, whoever said it, stops what called it too, once what's beside it has ended, and so on up. A loop told to collect failures doesn't go on to its next item, and a try's recover doesn't run. An agent's stop still reaches only that run and what it started, and whatever called it: not the lanes beside it, not a flow's waiting starts.

JSON that says one key twice or has a number too big or small to hold isn't read at all: it stays words, so a step asking for a number or a field out of it stops. For the guide: JSON written inside words is read by JSON's rules, so `{"n":5e3}` through `{{s.n}}` is 5000 and `[1.000]` in a sum is 1.

Also later: the editor's mark doesn't cover a sort, whose list usually is words; a person typing `1.234` into a number field gets 1.234; a value reading more than 32 names says it reads nothing nameable, so edits to those aren't new (its rank stays outside); applying a change doesn't stop runs already under way.

## Deleting several flows and moving steps (the founder's feedback, read clean at 2980498)

The rule (D199 in the app's docs, on app branch `team/sideflow-delete-docs`): deleting flows from the selection is the page's own button and nothing else. The press carries the page's private token (`page_token`, the `page-key` file in the extension's data folder), has to come at least 0.6 seconds after the confirmation appeared, and has to name exactly the flows the confirmation listed. The `ui` tool has no plain `delete` any more. An agent, or another extension acting through a plan, goes through `delete_flow`: high risk, one flow, on a card each time.

Later list: `delete_flow` removing a picked flow makes the press ask again; a name with hidden characters; 200 or more flows may pass the 128 KB page limit; moving walks every step at 100 steps; a guarded press still logs "Changed something"; Keep from the selection; a step whose id is `start` reads ambiguously. A drag handle on a card needs the app and isn't built.

## Copy as a definition (the founder's report, reproduced on snapshot.10)

The button opened a section with a second Copy button and copied nothing itself: from Runs or Activity nothing showed at all, and with a step selected it sat low in the side panel. It now copies at once from the menu on any tab, like Copy it in words. Both copy what's on screen and say when that includes changes that aren't saved. The label says when it includes unsaved changes, because a menu shows only its label. The page carries the words on every read, so past 20,000 bytes the button says it's too long rather than risk the page not drawing. What it copies comes back through Bring one in as the same flow.

Later list: words still being typed in a field aren't in the copy until that field is left (the host hands over typing after the words were drawn; a general fix is the app's); a half-written draft can be copied and then refused on the way back in; hidden characters like a joiner inside an emoji are removed by the host as it copies, as they were before. Definitions between 20,000 and 30,000 bytes used to offer a second button and now say too long; Export is their way out.

Typed mapping's later list, from its last read: `wrote` is set before the fit check, so a refusal carried on inside a repeat says it would do this all again; `{{a}}, {{b}}` into a list sends a blank entry when b is blank; a page's mark can pass what a run refuses; a practice skips the fit check.

Parallel and called flows' later list: "a, b" written for a called flow's list input is one entry where a tool's list field would split it; after a crash a parallel only joins again once all its lanes are over; a practice run really sends an old version's AI prompt, as it does a draft's, and passes where a live run refuses; a callee edited mid-run under the old Run isn't caught (gone with L2); steps without ids are numbered by position, so inserting one refuses an identical AI step in an old version; a changed text step can feed an unchanged AI prompt in an old version; a list input over 256 KB becomes one entry of clipped JSON.

Done after a read (2026-11-06): a parallel keeps which lanes it stopped itself, so a lane anyone else stopped stops it and what called it, whatever the join, and is never a failure for carry_on or a try; a lane is out of time only when the clock stopped it, not when another stop came after its limit; a lane's limit keeps counting while its flow is paused, since what's under way goes on then.

## Left out on purpose

Webhooks, Keychain accounts: they need a security decision of their own. Hosted runner, collaboration, freeform DAG, arbitrary code: the roadmap keeps them out.

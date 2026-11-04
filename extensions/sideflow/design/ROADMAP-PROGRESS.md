# Sideflow: what's done of the founder's findings and the roadmap

The founder, 2026-11-04: phases are fine, and the session ends when everything is built, tested and released. Sources: Sidefolk `sandbox/FINDINGS-2026-11-04.md` (A1-A9) and
`docs/research/sideflow-advanced-workflow-roadmap.md`. A line is ticked when its code and tests are in; "landed" means merged and released through the coordinator.

## Landings

| Landing | Holds | State |
|---|---|---|
| Stage 1 (D180) and Phase 0 | A1-A4; plan limit, branch scope and missing values, journal before effects, reviewed revision goes live, uncertain outcomes | In the gallery |
| Editing (D181, D182) | A5, A6, A7, A9: Save, Discard, undo, keys, check, what changed; move, outline, fold, find; forms, value menu, condition builder | In the gallery, snapshot.5, app 1252 |
| Engine (D198) | Typed values, for each, choose, try, call, finish, data, AI with fields, forms, waits, queues, time zones, parallel, run inspector, Stop, held-back runs | In the gallery, snapshot.6, minimum 1252 |
| Connections (D183) | A run waits for a tool that went away; a Connections page | Held for snapshot 1292: add-ons `team/sideflow-connections-2` (d844044), `gallery-next`. App in 1292. Publishes on the coordinator's word |
| Repeat until | Round and round until it holds | Ready behind Connections: `team/sideflow-repeat-2`. No app change |
| Fields (D184) | A tool's answer can hold fields | In reads: add-ons `team/sideflow-structured-2`, app `team/sideflow-structured-app-3`. Needs its own snapshot, after Connections |
| Jobs (D195) | How far along a step is; Stop tells it | Moved, findings fixed, in reads: add-ons `team/sideflow-jobs-2`, app `team/sideflow-jobs-app-2`, stacked on fields |
| Triggers (D196) | Several ways to start a flow; an event acts once | Moved, findings fixed, in reads: add-ons `team/sideflow-triggers-2`, app `team/sideflow-triggers-app-2`, stacked on jobs |
| More | Batches, group, fallback; make a step its own flow; pause; run again; try again from here | Moved, findings fixed, in reads: add-ons `team/sideflow-more-2`, stacked on triggers. No app change |
| One approval (replaces T51 as next priority; T51's design folded in) | Run saves and applies, one card for what's new, no asking again for what was approved | Designed with Permissions: their `FLOW-APPROVAL-DESIGN.md`. Nothing built until the coordinator answers the merged note |

## Still to build, in order (the coordinator, for the founder, 2026-11-05)

Each its own landing, with independent reads until a clean one, a suite on a built add-ons copy, an honest not-verified list. Ask the coordinator where a piece takes a decision or a security entry.

1. Typed mapping (type, sample, Literal/Secret/Expression modes), nested object parameters and forms, preview of resolved values.
2. Parallel: lane timeouts, sibling-cancel policy, other join modes. Declared types and a version pin for called flows.
3. Saved and pinned fixtures for practice; the explained diff and patch for the AI builder; the editor's repair offers (a producer moves, an agent edit conflicts); a Permissions tab, elapsed and usage in the inspector.
4. Stable-file detection and rename handling; idempotency keys; file and artifact references; durable job handles only if a tool needs them.
5. Scale: 100-200 cards (the board draws 64), breadcrumbs and focus on a subflow, wrap in a scope, resizable panels, compact Ask card.
6. The expression language (sandboxed, with its own security note); two reference connectors; pagination and rate-limit metadata; dependency-aware templates.

Also stated and owed: the later lists in each landing's MERGE-READY, among them a write's thrown error going to "did it happen?" rather than Recover, "Next:" ignoring the flow's time zone, `{{today}}` going stale over a days-long form, Skip sending a later action an empty value.

## Left out on purpose

Webhooks, Keychain accounts: they need a security decision of their own. Hosted runner, collaboration, freeform DAG, arbitrary code: the roadmap keeps them out.

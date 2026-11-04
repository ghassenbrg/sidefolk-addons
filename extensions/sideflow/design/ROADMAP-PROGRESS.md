# Sideflow: what's done of the founder's findings and the roadmap

The founder, 2026-11-04: phases are fine, and the session ends when everything is built, tested and released. Sources: Sidefolk `sandbox/FINDINGS-2026-11-04.md` (A1-A9) and
`docs/research/sideflow-advanced-workflow-roadmap.md`. A line is ticked when its code and tests are in; "landed" means merged and released through the coordinator.

## Landings

| Landing | Holds | State |
|---|---|---|
| Stage 1 (D180) and Phase 0 | A1-A4; plan limit, branch scope and missing values, journal before effects, reviewed revision goes live, uncertain outcomes; flows kept through what a page saves and a file it can't read | In the gallery since snapshot 1202 |
| Editing (D181, D182) | A5, A6, A7, A9: Save, Discard, undo, keys, check, what changed; Move to, outline, fold, find; forms, value menu, condition builder; a card for anything that runs by itself | This landing |
| Engine | Typed values, for each, choose, try, call, finish, data, AI with fields, forms, waits, queues, time zones, parallel, run inspector, Stop, the watch routine, held-back runs | Built on `team/sideflow-editing-3`. Its sixth read has five must-fix findings: its own landing, its own reads |
| After the engine | Connections (D183), repeat until, fields (D184), progress and cancel (D195), several triggers and event ids (D196), batches, make a step its own flow, pause, run again | Built on `team/sideflow-more`, a read has found real problems to fix first |
| T51 | A flow calling an MCP server without a card | Founder's yes. After Permissions, with a security review |

## Left out on purpose

Webhooks and Keychain accounts: they need a security decision of their own. Durable job handles that survive a restart: no tool here needs one yet.


# CLAUDE.md — dnd-calendar

Process and engineering rules for AI agents working on this repo. Domain decisions live in [CONTEXT.md](CONTEXT.md). Read both before any non-trivial change.

## Stack (locked)

- Flutter (Android-first; iOS untested in MVP)
- Firebase: Auth (Google), Firestore. **No Firebase Storage.**
- State: Riverpod
- Models: freezed + json_serializable
- Calendar engine: pure Dart, no Flutter / Firebase imports, lives in `packages/calendar_engine/`
- Tests: unit tests on `calendar_engine` are mandatory. Widget tests are out of scope for MVP.

## Repo layout

```
dnd-calendar/
├── apps/
│   └── dnd_calendar/        # Flutter app
├── packages/
│   └── calendar_engine/     # pure Dart, unit-tested
├── CONTEXT.md
├── CLAUDE.md
└── README.md
```

## Engineering rules

- **Vertical slices, not horizontal.** Each issue crosses the whole stack to a verifiable result. Don't do "all data models, then all UI".
- **Calendar engine first, UI second.** Any feature that touches calendar math: write the engine function + unit test, then wire the UI.
- **Deep modules.** `calendar_engine` exposes a small surface (`addDays`, `weekdayAt`, `moonPhasesAt`, `daysBetween`, `formatDate`) and hides all the leap-rule and overflow logic. Don't leak rule edge cases into UI code.
- **Domain types are immutable.** All world / event / character / calendar models are freezed.
- **No premature abstraction.** Two implementations before extracting an abstraction. One test → one impl at a time.
- **No backward-compat shims.** This repo is greenfield; if a model changes, change all call sites.

## Skill routing

| Trigger | Skill |
|---|---|
| Implement single issue inline | `/implement` |
| Dispatch multiple issues to subagents in parallel | `/delegate` |
| Build feature / fix bug test-first | `/tdd` |
| Bug repro / hard debugging | `/diagnose` |
| Stress-test design before coding | `/grill-me` |
| Plan/PRD → vertical-slice issues | `/to-issues` |

GitHub issue work goes through `/implement` or `/delegate`. Raw Agent loses PR linkage.

## PR / commit rules

- Branch from `main`, one issue → one PR, body includes `Closes #NN`.
- Commits: conventional-style is fine but not enforced. `[no-issue]` tag if commit is genuinely standalone (rare).
- Merge own PRs after CI passes (no team here, no review queue).

## Definition of done (per issue)

1. Slice runs end-to-end on Android emulator.
2. If touching `calendar_engine` — unit tests added or updated, all green.
3. Firestore rules updated if data model touched.
4. CONTEXT.md updated if a domain decision changed (rule added, invariant changed, scope re-cut).
5. No new TODO comments without an issue link.

## What NOT to do

- Don't add packages that overlap with the locked stack (no BLoC alongside Riverpod, no built_value alongside freezed).
- Don't introduce a backend other than Firebase. No custom Cloud Functions in MVP unless a Firestore rule is genuinely insufficient.
- Don't generalize the calendar engine to support time-of-day, multiple parallel calendars, or complex leap rules. Those are explicitly out of scope (CONTEXT.md).
- Don't put runtime state (build %, sprint progress, current branch) into this file or CONTEXT.md. State lives in GitHub Issues / git, not in markdown.

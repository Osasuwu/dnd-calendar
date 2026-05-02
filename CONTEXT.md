# CONTEXT.md — dnd-calendar

Domain model, glossary, invariants. Locked decisions from the design session 2026-05-02. Update inline when decisions evolve. Speculative ideas → `out-of-scope.md` (separate file when needed), not here.

## Purpose

Mobile app for D&D Dungeon Masters and players. Two real use cases drive every design decision:

1. **Long campaigns** — single party, many sessions, in-world time matters (downtime, travel, festivals, recurring lore beats).
2. **Open tables** — one shared world, rotating roster of players, quests scheduled on the world calendar, players sign up per quest with one of their characters.

Secondary purpose: demonstrate that AI-assisted development (Claude Code as primary engineer) can ship a real product in a weekend.

## Glossary

- **World** — a self-contained game setting owned by one DM. Holds its own calendar config, events, members, and characters. Identified by a 6-character `joinCode`.
- **DM** — owner of a world. Configures calendar, creates events, advances the world clock. One DM per world (no co-DM in MVP).
- **Player** — any user who joined a world via `joinCode`. Can create characters in that world and register for events.
- **Character** — thin card (`name`, `class`, `level`) belonging to a (user, world) pair. Full character sheet lives outside the app. A user can have multiple characters per world.
- **Event / Quest** — a scheduled happening in the world (one date or a date range). Players register one of their characters to attend. Used interchangeably; "quest" is the user-facing word for adventuring events.
- **Registration** — `(eventId, userId, characterId)` tuple. A character can hold at most one registration whose date range overlaps any other registration of that same character.
- **Current date** — the world's "today". Set manually by DM. Drives what's "upcoming" vs "past" for everyone in the world.
- **Calendar config** — per-world ruleset: weekday count + names, months (each with name + length), year length (computed), epoch label, start year, optional leap rule, moon definitions.
- **Moon** — `(name, periodDays, offsetDays, color)`. Phase at any date is computed from `(daysSinceEpoch + offset) mod period` mapped to 8 standard phases (new → waxing crescent → first quarter → waxing gibbous → full → waning gibbous → last quarter → waning crescent).

## Invariants

1. **Characters belong to a (user, world) pair.** They never travel between worlds. Different campaign = different roster.
2. **One DM per world.** The user who created the world owns it. No transfer, no co-ownership in MVP.
3. **A character cannot be registered for two events with overlapping in-world date ranges.** Enforced client-side at registration time.
4. **Date granularity is one in-world day.** No hours, no minutes. If a DM needs intra-day ordering, they use event titles.
5. **Calendar engine is pure Dart, no Flutter or Firebase imports.** Lives in `packages/calendar_engine/`. Replacing the storage layer must not touch engine code.
6. **All world data lives under `worlds/{worldId}/...`.** Cross-world queries are not a thing in MVP. This keeps Firestore rules simple and queries scoped.

## Calendar engine — supported configurability

| Level | Capability | In MVP? |
|---|---|---|
| L1 Cosmetic | rename weekdays, months | yes |
| L2 Structural | custom days-per-week, months-per-year, days-per-month (varies per month) | yes |
| L3 Yearly | start year, epoch label, simple leap rule (`everyNYears` adds one day to a chosen month) | yes |
| L4a Moons | configurable moons with period + offset, 8-phase output | yes |
| L4b Multiple parallel calendars | — | **out** |
| L5 Time-of-day | hours, minutes | **out** |
| L6 Complex leap rules | Gregorian-style nested exceptions, Gloomhaven inserted days | **out** (emulate L6 by adding a short "month" between real months if needed) |

## Data model (Firestore)

```
users/{uid}
  # Firebase Auth managed: displayName, photoURL, email

worlds/{worldId}
  ownerUid: string
  name: string
  joinCode: string                 # 6 alphanumeric chars, unique
  calendar: {
    daysPerWeek: int
    weekdayNames: string[]
    months: [{ name: string, days: int }]
    epochName: string              # e.g. "DR", "AC"
    startYear: int
    leapRule: {
      everyNYears: int
      extraDayInMonthIndex: int    # adds 1 day to months[i].days that year
    } | null
    currentDate: { year: int, monthIndex: int, day: int }
    moons: [{ name: string, periodDays: int, offsetDays: int, color: string }]
  }
  createdAt: timestamp

worlds/{worldId}/members/{uid}
  role: "dm" | "player"
  joinedAt: timestamp

worlds/{worldId}/characters/{characterId}
  uid: string                      # owner
  name: string
  class: string
  level: int

worlds/{worldId}/events/{eventId}
  title: string
  description: string              # plain text + line breaks, no markdown
  startDate: { year, monthIndex, day }
  endDate: { year, monthIndex, day } | null
  capacity: int | null             # null = unlimited
  registrationDeadline: { year, monthIndex, day }   # default = startDate, DM can override
  status: "scheduled" | "completed" | "cancelled"
  createdByUid: string
  createdAt: timestamp

worlds/{worldId}/events/{eventId}/registrations/{uid}
  characterId: string
  registeredAt: timestamp
```

## Auth & access

- **Auth method:** Google sign-in (Firebase Auth). No anonymous, no email/password, no phone.
- **Membership:** owner is implicit DM (not in `members` subcollection — derivable from `ownerUid`). Joining via code adds entry to `members` with `role: "player"`.
- **Firestore rules (sketch):**
  - `worlds/{w}` — read: any member or owner. Write: owner only.
  - `worlds/{w}/members/{u}` — read: any member or owner. Write: self (for join) or owner (for removal — post-MVP).
  - `worlds/{w}/characters/{c}` — read: any member or owner. Write: only `uid == auth.uid` and is member.
  - `worlds/{w}/events/{e}` — read: any member or owner. Write: owner only.
  - `worlds/{w}/events/{e}/registrations/{u}` — read: any member or owner. Write: only `auth.uid == u` and is member.

## UX rules

- DM advances current date via date picker + a "+1 day" quick button. No auto-advance.
- Real-time sync via Firestore listeners. No push notifications in MVP — players see updates when the app is open; out-of-app communication stays in Discord.
- Calendar UI shows month/list views switchable. Moon phases shown as a small textual indicator (`🌒 2/8`) until icon polish lands.

## Out of scope (MVP)

Explicitly cut to fit weekend timeline. Can revisit each as a separate iteration.

- QR code for joining (text code only)
- Push notifications
- Recurring events
- File / image uploads (no Firebase Storage)
- Markdown in event description
- Locations / NPCs / lore objects
- Co-DMs, ownership transfer, removing players
- Character transfer between worlds
- Multi-day events (`endDate` field exists but UI is single-date first; revisit in S7)
- Capacity enforcement at registration time (UI shows count, but doesn't block over-registration in MVP)
- Time-of-day, hours, minutes
- Multiple parallel calendars per world
- Eclipses, moon visibility

## Build order — vertical slices

Each slice = end-to-end through the stack to a verifiable result. Order is dependency-driven, not feature-grouped.

| # | Slice | Approx |
|---|---|---|
| S0 | Flutter project + Firebase init + Google sign-in + hello world | 1h |
| S1 | World CRUD (create/list/detail), default calendar, owner-only | 3h |
| S2 | Calendar engine pure Dart package + unit tests + DM config UI | 4h |
| S3 | Events CRUD (DM side) + month/list calendar view | 3h |
| S4 | Join code + members subcollection + Firestore rules | 2h |
| S5 | Characters per (user, world) | 1.5h |
| S6 | Quest registration: pick character, overlap check, registrations list | 3h |
| S7 | Current date advancement, moon indicators, polish, empty states | 2.5h |

Total: ~20h. If running over → extend to a third day. Fidelity > speed.

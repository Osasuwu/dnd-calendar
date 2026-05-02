# dnd-calendar

Mobile app (Flutter + Firebase) for D&D campaigns with **fully customizable in-world calendars**. Built primarily for our own open-table campaign — DM configures days/weeks/months/year/leap rules + moon phases for any homebrew or published setting; players join by code, register characters for quests, see the world clock tick.

> **This is also a public experiment.** The whole project is being built in one weekend with [Claude Code](https://claude.com/claude-code) as the primary engineering partner — to demonstrate that AI agents can ship real products, not just monotonous boilerplate. Issues, PRs, and commits are intentionally public so the process is observable.

## What's in the app

- **DM:** create a world, configure its calendar (days per week, months per year, days per month, leap rule, moon cycles), name everything however you want, schedule quests/events, advance the world clock.
- **Players:** join a world by 6-char code, create thin character cards (name / class / level — full sheets stay external), browse upcoming quests, register one of your characters per quest.
- **Open-table friendly:** characters can't be double-booked across overlapping in-world dates.

Detail-level domain decisions live in [CONTEXT.md](CONTEXT.md). Process / engineering rules in [CLAUDE.md](CLAUDE.md).

## Stack

- Flutter (mobile, Android-first)
- Firebase: Auth (Google), Firestore (data + realtime sync)
- Riverpod + freezed
- Calendar engine = pure Dart package (`packages/calendar_engine/`), unit-tested independently

## Status

Work-in-progress. Build order is 8 vertical slices (S0–S7) tracked in Issues.

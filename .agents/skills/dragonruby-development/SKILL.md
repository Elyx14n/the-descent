---
name: dragonruby-development
description: Implement, debug, refactor, and test this DragonRuby game. Use for changes under mygame, gameplay-state or runtime bugs, input/rendering problems, performance investigation, and DragonRuby unit or replay testing; use design-review first when behavior or architecture is still undecided.
---

# DragonRuby Development

Deliver the smallest coherent, verified change to the game. Preserve the project's KISS/YAGNI constraints and distinguish automated correctness from game feel that needs playtesting.

## Start from repository truth

Read `AGENTS.md`, then inspect the relevant project code, tests, `PRODUCT.md`, and `CONTEXT.md`. Treat `mygame/` as project code. Resolve SDK references through `DRAGONRUBY_HOME` as described in `AGENTS.md`; engine documentation and examples live in `$DRAGONRUBY_HOME/docs/` and `$DRAGONRUBY_HOME/samples/`. Search that installation before using external material.

Do not claim planned systems are implemented. Do not edit bundled SDK code to solve a game problem.

## Choose the relevant workflow

- For implementation or refactoring, read [references/engineering.md](references/engineering.md).
- For a failure, incorrect behavior, or runtime investigation, read [references/debugging.md](references/debugging.md).
- For adding or running tests and replays, read [references/testing.md](references/testing.md).
- For work spanning multiple categories, read only the references needed.

## Shared constraints

- Make one vertical, playable change at a time.
- Prefer explicit Ruby and DragonRuby primitives over new frameworks or dependencies.
- Keep rules independent of input/rendering when doing so creates a clear test seam; do not manufacture layers without that benefit.
- Preserve hot reload and restart behavior.
- Add observability proportional to the problem: meaningful logs, debug primitives, current state, or deterministic seeds.
- Measure before performance optimization unless the code has an obvious unbounded or per-frame scaling fault.
- Keep source/licensing information for externally created assets when available.

## Verification and handoff

Run `bundle exec rubocop` from the repository root after changing Ruby files. Use the narrowest reliable behavioral checks first, then an appropriate runtime, replay, or manual check. State:

- what changed
- what automated checks passed
- what requires human playtesting
- any known limitation or intentionally deferred work

Do not report visual feel, fairness, tension, or audiovisual quality as verified solely because unit tests pass.

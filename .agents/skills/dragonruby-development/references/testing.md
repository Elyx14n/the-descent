# Testing

Use this reference when adding, changing, or running automated tests and replays.

## Ruby linting

Run the project lint check from the repository root:

```sh
bundle exec rubocop
```

Linting is a static check, not a substitute for DragonRuby tests or playtesting. The root `.rubocop.yml` defines the project lint rules and includes project-owned Ruby, including `mygame/app/main.rb`. The SDK is installed separately.

## Native DragonRuby tests

The bundled example under `$DRAGONRUBY_HOME/samples/10_advanced_debugging/03_unit_tests/` is the local source of truth for the installed test API. Tests use methods beginning with `test_` and accept `args, assert`; `focus_test_` can narrow a run during development.

From the repository root, with `DRAGONRUBY_HOME` configured as described in `README.md`, run the current collision tests:

macOS, Linux, or WSL:

```sh
bash scripts/run.sh --test tests/player_collision_test.rb
```

Native Windows (PowerShell):

```powershell
.\scripts\run.ps1 --test tests/player_collision_test.rb
```

The launchers select this repository's `mygame/` and run from the SDK directory. The `--test` filename is relative to the game directory, so use `tests/...`, without a `mygame/` prefix. Supply a test file with `--test`. The SDK's `docs/misc/faq.md` documents this path convention.

Keep project tests under `mygame/tests/`. Confirm the output names the intended file and inspect its test summary; a process exit alone does not establish that tests passed.

## What to test

Prioritize deterministic rules and regressions:

- puzzle validity and solvability invariants
- run and Witness state transitions
- observations, memory, and weighted decisions
- collision and geometry boundaries
- seeded placement or randomization
- serialization when save data exists
- the exact scenario for a fixed bug

Use input emulation or tick-level tests for integration boundaries where direct rule tests are insufficient. Avoid tests that merely duplicate rendering hashes or internal method structure.

Use recorded replays for repeatable frame/input sequences and runtime regressions. Relevant APIs include `reset_and_replay`, recording, and replay functions in `$DRAGONRUBY_HOME/docs/api/runtime.md`.

## Human verification

Manual playtesting remains necessary for controls, readability, fairness, timing, tension, audiovisual feedback, and whether a mechanic is fun. Give the tester a short scenario and observations to report instead of a vague instruction to “play around.”

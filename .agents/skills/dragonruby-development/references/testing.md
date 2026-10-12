# Testing

Use this reference when adding, changing, or running automated tests and replays.

## Ruby linting

Run the project lint check from the repository root:

```sh
bundle exec rubocop
```

Linting is a static check, not a substitute for DragonRuby tests or playtesting. The root `.rubocop.yml` defines the project lint rules and includes project-owned Ruby, including `mygame/app/main.rb`. The SDK is installed separately.

## Native DragonRuby tests

The bundled example under `$DRAGONRUBY_HOME/samples/10_advanced_debugging/03_unit_tests/` is the local source of truth for the installed test API. Put tests in named classes ending in `Tests`, with methods beginning with `test_` and accepting `args, assert`. Shared helpers belong in modules under `mygame/tests/support/`; do not require another test file just to reuse its helpers. `focus_test_` can narrow a local run; CI rejects focused tests.

From the repository root on Linux or macOS, with `DRAGONRUBY_HOME` configured as described in `README.md`, run the collision tests:

```sh
bundle exec rake test tests/player_collision_test.rb
```

Rake selects this repository's `mygame/` and runs from the SDK directory. The optional test filename is relative to the game directory, so use `tests/...`, without a `mygame/` prefix. `bundle exec rake test` runs the full suite; `bundle exec rake check` runs RuboCop followed by the suite.

Keep project tests under `mygame/tests/`. The task invokes `tests/run.rb` through `--eval` and checks its completion report: test failures, inconclusive tests, empty suites, incomplete runs, and load errors fail the task even if DragonRuby exits with status 0. Confirm the output names the intended classes and inspect the native summary. Avoid running the engine's `--test` directly for CI; its exit status is unreliable on the installed 7.21 SDK.

The full suite is `tests/all_test.rb`. Targeted room checks are `tests/tiled_deserializer_test.rb`, `tests/room_test.rb`, `tests/render_test.rb`, `tests/room_preview_test.rb`, and `tests/keybinds_test.rb`. Camera regressions remain in `tests/camera_test.rb`. Existing room fixtures read the Ritual Gate export; passing them does not validate an arbitrary new room.

On Linux, native checks can run without a window using:

```sh
bundle exec rake check HEADLESS=1
```

Linux CI enables headless mode automatically; `HEADLESS=1` selects the same offscreen video, dummy audio, and software rendering locally. This checks behavior and integration; it does not establish appearance on the user's display. macOS uses its normal display. If the SDK logs path is read-only, use the stdout summary rather than requesting write access just for logging.

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

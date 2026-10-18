# Repository Guidance

## Ownership boundaries

- `mygame/` is The Descent's project-owned DragonRuby game. Make game changes here.
- `mygame/app/main.rb` is the current entry point.
- `mygame/sprites/descent/` is the shared upload destination for project sprite assets.
- DragonRuby lives outside the repository in `DRAGONRUBY_HOME`. Its `docs/`, `samples/`, executables, fonts, images, changelogs, and license files are SDK resources. Consult them there; keep the SDK separate from project files.
- Repository `docs/`, if created for project notes or ADRs, is project-owned and distinct from SDK documentation.
- `.agents/skills/` contains project workflows for future coding sessions.

## Sources of truth

Follow [documentation guidance](docs/agents/domain.md) for document ownership, vocabulary, and decision conflicts. Inspect `mygame/` to establish what is implemented.

## Working principles

- Favor KISS, YAGNI, and the smallest playable vertical slice.
- Build one concrete mechanic before creating a framework for a category of mechanics.
- Keep work within `PRODUCT.md`'s MVP scope unless the user changes it.
- Resolve SDK references through `DRAGONRUBY_HOME` (`$DRAGONRUBY_HOME` in Bash/Zsh). Development uses Linux or macOS. Prefer that installation's `docs/` and `samples/` before external sources. If unset or inaccessible, follow `README.md` setup and report the missing reference rather than assuming a machine-specific path.
- Keep hot reload, restart, and debugging practical. Make important game state inspectable while tuning.
- Keep HD disabled (`hd=false` in game metadata). This overrides older HD-on guidance in skills and historical notes; do not re-enable HD to improve text. See [ADR-0013](docs/adr/0013-keep-hd-disabled.md). Tune UI fonts and sizes for the native 320 × 180 raster instead.
- Separate deterministic rules from DragonRuby input/output when it creates a useful test seam; do not add layers only for architectural symmetry.
- Measure before optimizing and preserve project readability for a small amateur team.

## Verification

- Use the project's `bin/` binstubs for gem commands in code, documentation, and CI. Install dependencies with `bundle install`; generate missing launchers with `bundle binstubs GEM_NAME`.
- Run `bin/rubocop` from the repository root for Ruby linting.
- Keep native DragonRuby tests for deterministic rules and regressions under `mygame/tests/`. Run `bin/rake test` or `bin/rake test tests/example_test.rb`; see the testing reference in `dragonruby-development`.
- Use replay or seeded scenarios for frame-dependent behavior.
- Use manual playtesting for controls, readability, fairness, tension, and audiovisual feedback.
- Report automated checks separately from behavior that still needs playtesting.

Use the `design-review` skill for unresolved behavior or architectural choices. Use the `dragonruby-development` skill for implementation, debugging, refactoring, and testing.

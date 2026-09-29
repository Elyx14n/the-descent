# Repository Guidance

## Ownership boundaries

- `mygame/` is The Descent's project-owned DragonRuby game. Make game changes here.
- `mygame/app/main.rb` is the current entry point.
- `mygame/sprites/descent/` is the shared upload destination for project sprite assets.
- DragonRuby lives outside the repository in `DRAGONRUBY_HOME`. Its `docs/`, `samples/`, executables, fonts, images, changelogs, and license files are SDK resources. Consult them there; keep the SDK separate from project files.
- Repository `docs/`, if created for project notes or ADRs, is project-owned and distinct from SDK documentation.
- `.agents/skills/` contains project workflows for future coding sessions.

## Sources of truth

- `PRODUCT.md` defines the intended player experience and MVP boundary.
- `CONTEXT.md` records current project status, accepted decisions, working models, open questions, and stable terminology.
- Actual files under `mygame/` define what is implemented. Never infer implementation from plans alone.
- `README.md` is the stakeholder-facing repository guide.

## Working principles

- Favor KISS, YAGNI, and the smallest playable vertical slice.
- Build one concrete mechanic before creating a framework for a category of mechanics.
- Do not design for deferred scope such as co-op, procedural maps, multiple enemies, or lore unless the user explicitly changes the MVP.
- Resolve SDK references through `DRAGONRUBY_HOME` (`$DRAGONRUBY_HOME` in Bash/Zsh; `$env:DRAGONRUBY_HOME` in PowerShell). Prefer that installation's `docs/` and `samples/` before external sources. If unset or inaccessible, follow `README.md` setup and report the missing reference rather than assuming a machine-specific path.
- Keep hot reload, restart, and debugging practical. Make important game state inspectable while tuning.
- Separate deterministic rules from DragonRuby input/output when it creates a useful test seam; do not add layers only for architectural symmetry.
- Measure before optimizing and preserve project readability for a small amateur team.

## Verification

- Run `bundle exec rubocop` from the repository root for Ruby linting.
- Keep native DragonRuby tests for deterministic rules and regressions under `mygame/tests/`. Run them with the platform launcher and a game-relative test path; see the testing reference in `dragonruby-development`.
- Use replay or seeded scenarios for frame-dependent behavior.
- Use manual playtesting for controls, readability, fairness, tension, and audiovisual feedback.
- Report automated checks separately from behavior that still needs playtesting.

Use the `design-review` skill for unresolved behavior or architectural choices. Use the `dragonruby-development` skill for implementation, debugging, refactoring, and testing.

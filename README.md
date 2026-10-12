# The Descent

The Descent is a small, top-down horror game being built with DragonRuby Game Toolkit. The player explores a monastery, deciphers a ritual lock, and evades the Witness: an enemy that uses evidence left in the world to anticipate where the player will go.

## Prerequisites

Before setting up the repository, ensure you have the following installed:

* **DragonRuby Game Toolkit SDK:** Download the Linux or macOS build matching the team's release.
* **Ruby:** Needed for launching the game and development tasks; use your preferred version manager.
* **Bundler (`gem install bundler`):** Required to manage development gems.
* **VS Code + Ruby LSP Extension (Optional):** Recommended editor setup for code completion and indexing against the DragonRuby SDK.

## First-time setup and running the game

Development uses Linux or macOS. Install the complete DragonRuby SDK for your operating system and CPU architecture **outside this repository**. Collaborators should use the same DragonRuby release.

Set `DRAGONRUBY_HOME` to the extracted SDK folder containing `dragonruby`. The SDK can live anywhere outside this repository; the paths below are examples. Replace them with your own installation path.

**macOS (Zsh):**

Persist the setting once, then load it into your current terminal:

```sh
echo 'export DRAGONRUBY_HOME="$HOME/tools/dragonruby-macos"' >> ~/.zshrc
source ~/.zshrc
```

**Linux (Bash):**

Persist the setting once, then load it into your current terminal:

```sh
echo 'export DRAGONRUBY_HOME="$HOME/tools/dragonruby-linux-amd64"' >> ~/.bashrc
source ~/.bashrc
```

If you use Zsh on Linux, use `~/.zshrc` instead of `~/.bashrc`.

From the repository root, install the development gems and launch:

```sh
bundle install
bundle exec rake run
```

Preview a specific exported map with a game-relative path:

```sh
bundle exec rake run tiled/ritual_gate.json
```

Pass extra DragonRuby flags after `--`; for example, `bundle exec rake run -- --record session.txt`. Rake locates `mygame/` relative to the repository and launches from the SDK directory. Quote individual paths containing spaces normally. The tasks read `DRAGONRUBY_HOME` directly and do not load `.env` files. SDK credentials belong outside the repository. Sprite paths remain relative to `mygame/`, such as `sprites/enemy.png`.

The SDK's `dragonruby` binary must have executable permission. If necessary, run `chmod +x "$DRAGONRUBY_HOME/dragonruby"` after extracting your SDK.

The game source starts at `mygame/app/main.rb`. DragonRuby runs this Ruby source directly and hot-reloads saved changes, so there is no compile step during normal development.

## Development checks

Use the same Rake tasks on Linux and macOS:

```sh
bundle exec rake -T                       # List tasks
bundle exec rake lint                     # RuboCop
bundle exec rake test                     # All native tests
bundle exec rake test tests/room_test.rb   # One test file
bundle exec rake check                    # Lint and all native tests
```

Running `bundle exec rake` without a task also runs `check`. Test paths are relative to `mygame/`, so use `tests/...`. Tests live in named `*Tests` classes, use DragonRuby's native assertions, and share helpers through modules under `mygame/tests/support/`. `tests/all_test.rb` loads the full suite.

For headless testing on Linux:

```sh
bundle exec rake check HEADLESS=1
```

Linux CI enables headless mode automatically. The test task runs `tests/run.rb` through DragonRuby's `--eval` mode and checks its completion report. Failed or inconclusive tests, empty suites, incomplete runs, and load errors fail the Rake command even when the engine returns exit status 0. Local `focus_test_` methods run with a warning; CI rejects focused runs. Native tests and manual playtesting remain separate checks.

### DragonRuby editor completion

Open `descent.code-workspace` in VS Code with the Ruby LSP extension installed. The `run` and `test` tasks automatically create a Git-ignored `.dragonruby-lsp` symlink to the SDK root in `DRAGONRUBY_HOME`. SDK files stay outside the repository, and each contributor's environment variable supplies their own installation path.

Ruby LSP indexes only `.dragonruby-lsp/docs/oss/**/*.rb`. API documentation is also available at `.dragonruby-lsp/docs/api/`, preserving the SDK's directory layout. Ruby LSP does not execute documentation helpers such as `DocsOrganizer.get_docsify_content`, so it will not automatically display the referenced Markdown as method documentation.

After the first launch, run **Ruby LSP: Restart** from the command palette to index the SDK definitions. If you change `DRAGONRUBY_HOME`, run either task again and restart Ruby LSP. The tasks refresh existing links, leave ordinary files and directories untouched, and warn if editor setup fails while continuing to launch.

Completion covers the Ruby definitions shipped in the SDK; Ruby LSP may still be unable to infer dynamic fields such as `args.state.some_custom_field`.

## Package a distributable build

Before packaging, fill in the release fields near the top of `mygame/metadata/game_metadata.txt`, including `devid`, `devtitle`, `gameid`, `gametitle`, and `version`. From the repository root, run with your external SDK (Linux or macOS):

```sh
game_dir="$PWD/mygame"
(cd "$DRAGONRUBY_HOME" && ./dragonruby-publish --package "$game_dir")
```

DragonRuby will create packaged platform builds in a generated build directory. See `docs/guides/deploying-to-itch.md` inside your SDK installation for deployment instructions.

## Upload game assets here

Stakeholders contributing assets should upload them to:

- `mygame/sprites/` for sprites
- `mygame/sounds/` for sounds
- `mygame/fonts/` for fonts

Keep the original/source asset and any license or provenance notes alongside the delivery when available. Keep project assets in this repository, separate from your SDK installation.

32 × 32 is the usual sprite cell size, not a strict asset requirement. The player animation sheets use 64 × 64 frames, configured in [player.rb](mygame/app/player.rb). Use each asset's actual source dimensions; see the [display and sprite-size guidance](docs/adr/0002-reference-resolution-and-ui-fonts.md) for how source dimensions, entity scale, and display scaling relate.

### Author and preview rooms in Tiled

1. Open `mygame/tiled/descent.tiled-project` in Tiled, then open `ritual_gate.tmj`.
2. Edit the room's floors, walls, doors, and props. Use the existing room and tiles as your starting point.
3. Save the map and export it as JSON into `mygame/tiled/`, using the existing export settings. For the current room, export to `ritual_gate.json`.
4. Preview the room:

   ```sh
   bundle exec rake run tiled/ritual_gate.json
   ```

Walk through the room and check that doors and obstacles behave as expected. After further edits, save and re-export to refresh the preview automatically. Press **R** to reload manually.

## Repository guide

Project-owned files:

```text
mygame/
  app/                  Game Ruby code; main.rb is the entry point
  data/                 Authored game data
  tiled/                Tiled project, source maps, and JSON exports
  fonts/                Game-specific fonts
  metadata/             DragonRuby game and platform configuration
  sounds/               Music and sound effects
  sprites/              The Descent sprite upload destination

Rakefile                Linux/macOS development tasks
lib/                    Desktop Ruby task implementation
.agents/skills/         Project-specific design and development workflows
.claude/skills          Symlink to .agents/skills for Claude Code discovery
```

## Project direction

Read [PRODUCT.md](PRODUCT.md) for scope and [CONTEXT.md](CONTEXT.md) for progress. The [documentation guide](docs/agents/domain.md) identifies where vocabulary, decisions, and research belong.

## DragonRuby help

Documentation is available under `$DRAGONRUBY_HOME/docs/` and online at [docs.dragonruby.org](https://docs.dragonruby.org).

The SDK includes examples under its `samples/` directory.

DragonRuby community Discord: [discord.dragonruby.org](https://discord.dragonruby.org).

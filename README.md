# The Descent
![alt text](<big fix.png>)

The Descent is a small, 2D top-down horror game built with DragonRuby. The player explores a monastery, deciphers riddles to find four fabled relics that unlock the Ritual Gate, whilst evading the Witness: an enemy that uses evidence left in the world to anticipate where the player will go.

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
bin/rake run
```

Preview a specific exported map with a game-relative path:

```sh
bin/rake run tiled/ritual_gate.json
```

The SDK's `dragonruby` binary must have executable permission. If necessary, run `chmod +x "$DRAGONRUBY_HOME/dragonruby"` after extracting your SDK.


## Development checks

Use the project's `bin/` commands on Linux and macOS. These binstubs select the gem versions from `Gemfile.lock`. Keep them in version control so the same commands are available in CI:

```sh
bin/rake -T                       # List tasks
bin/rake lint                     # RuboCop
bin/rake test                     # All native tests
bin/rake test tests/room_test.rb   # One test file
bin/rake check                    # Lint and all native tests
```

Running `bin/rake` without a task also runs `check`. Test paths are relative to `mygame/`, so use `tests/...`. Tests live in named `*Tests` classes, use DragonRuby's native assertions, and share helpers through modules under `mygame/tests/support/`. `tests/all_test.rb` loads the full suite.

For headless testing on Linux:

```sh
bin/rake check HEADLESS=1
```

Linux CI enables headless mode automatically. The test task runs `tests/run.rb` through DragonRuby's `--eval` mode and checks its completion report. Failed or inconclusive tests, empty suites, incomplete runs, and load errors fail the Rake command even when the engine returns exit status 0. Local `focus_test_` methods run with a warning; CI rejects focused runs. Native tests and manual playtesting remain separate checks.

### DragonRuby editor completion

Open `descent.code-workspace` in VS Code with the Ruby LSP extension installed. The `run` and `test` tasks automatically create a Git-ignored `.dragonruby-lsp` symlink to the SDK root in `DRAGONRUBY_HOME`. SDK files stay outside the repository, and each contributor's environment variable supplies their own installation path.

Ruby LSP indexes only `.dragonruby-lsp/docs/oss/**/*.rb`. API documentation is also available at `.dragonruby-lsp/docs/api/`, preserving the SDK's directory layout. Ruby LSP does not execute documentation helpers such as `DocsOrganizer.get_docsify_content`, so it will not automatically display the referenced Markdown as method documentation.

After the first launch, run **Ruby LSP: Restart** from the command palette to index the SDK definitions. If you change `DRAGONRUBY_HOME`, run either task again and restart Ruby LSP. The tasks refresh existing links, leave ordinary files and directories untouched, and warn if editor setup fails while continuing to launch.

Completion covers the Ruby definitions shipped in the SDK; Ruby LSP may still be unable to infer dynamic fields such as `args.state.some_custom_field`.

## Author and preview rooms in Tiled

Edit the source map under `mygame/tiled/` and export finite orthogonal JSON with embedded tilesets. Use game-relative image paths, bottom-left tile-object alignment, rectangle collision shapes, and these layers: Ground and Ceiling as tile layers; FloorDetails, Walls, and Props as object layers. Include exactly one point object of class Spawn. The preview polls changed exports every 30 ticks in development; R forces a rebuild. Successful reloads restore authored defaults, while invalid exports retain the last valid room and show the error.

Place Door, Light, and Pedestal tile objects on Props. Door tiles specify matching local `close_tile` and `open_tile` IDs on both variants; their active artwork and collision switch together. A Door ceiling tile directly above the base switches with it. The Ritual Gate uses `locked: true` until puzzle logic releases it.

Place lights using their animated lit tile. Set `unlit_id` to the static unlit tile's local ID in the same tileset. `enabled` defaults to true; false starts with the unlit artwork. Object properties override tile defaults. Animation frame IDs and positive millisecond durations come from Tiled; the current flames use four frames at 150 ms each (nine game ticks). The preview supplies the game tick, so toggling a light on joins the current animation frame. Keep the base collider on the placed lit tile: light collision stays fixed across animation and enabled changes.

Light `offset_x` and `offset_y` locate the emitter in source pixels from the tile's top-left, accounting for object scaling and flips. Radius, intensity, and color are retained for future illumination. Use `mounted_on` object references for wall-mounted Props; they draw and fade with their supporting wall. Pedestal offsets locate the future item anchor.

E toggles the nearest door or light within 24 world pixels, measuring doors from their closed colliders and lights from their placed sprite rectangles. Equal-distance targets follow authored object order. Locked doors and transitions overlapping the player's feet consume the press. B shows collision, fade geometry, and emitter markers. Illumination and pedestal interaction remain unimplemented.

### Generate tile occluders

The game reads prepared shapes from `mygame/data/occluders.json`; it does not calculate sprite alpha bounds while loading a room. The two-source-pixel outlines were selected after visual review. Every disconnected piece is retained, with internal holes filled. Shapes support foreground fading now and provide polygon boundaries for future lighting.

After changing atlas artwork or its crop grid, run:

```sh
bin/rake assets:occluders
bin/rake assets:test
```

Then press R in the game to rebuild the room. Missing or outdated data reports the generation command and keeps the previous valid room during reload. Map JSON is watched automatically; regenerated geometry requires R. Include the generated JSON with game changes.

Generation uses ordinary Ruby, RGeo/GEOS, and ChunkyPNG. Install GEOS development files (`sudo apt-get install libgeos-dev` on Ubuntu, or `brew install geos` on macOS) before `bundle install`. If RGeo was previously built without GEOS, run `bundle pristine rgeo` after installing GEOS. These dependencies are not loaded inside DragonRuby.

The task uses `mygame/tiled/ritual_gate.json` by default; `MAP` selects another JSON export with embedded tilesets, `TOLERANCE` overrides 2, and `OUT` overrides `mygame/data`. All cells in the referenced atlases are included, covering door/animation variants. No separate tileset export or HTML preview is needed. See [ADR-0011](docs/adr/0011-generated-tile-occluders.md) for geometry and fading semantics, and the [investigation notes](docs/notes/alpha-contour-generation.md) for earlier trials.

## Repository guide

Project-owned files:

```text
mygame/
  app/                  Game Ruby code; main.rb is the entry point
  data/                 Authored and generated game data
  tiled/                Tiled project, source maps, and JSON exports
  fonts/                Game-specific fonts
  metadata/             DragonRuby game and platform configuration
  sounds/               Music and sound effects
  sprites/              The Descent sprite upload destination

Rakefile                Linux/macOS development tasks
bin/                    Bundler-generated command launchers
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

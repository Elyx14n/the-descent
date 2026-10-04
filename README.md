# The Descent

The Descent is a small, top-down horror game being built with DragonRuby Game Toolkit. The player explores a monastery, deciphers a ritual lock, and evades the Witness: an enemy that uses evidence left in the world to anticipate where the player will go.

The current game is a movement and collision playground. Planning documents describe the intended MVP; they do not imply that all planned features are implemented.

## Prerequisites

Before setting up the repository, ensure you have the following installed:

* **DragonRuby Game Toolkit SDK:** Download the latest platform build for your OS (macOS, Linux, or Windows).
* **Ruby (v3.0+ recommended):** Needed for repository development checks (`rubocop`, `bundle`). Managed via system Ruby or a version manager like **RVM**, **rbenv**, or **asdf**.
* **Bundler (`gem install bundler`):** Required to manage development gems.
* **VS Code + Ruby LSP Extension (Optional):** Recommended editor setup for code completion and indexing against the DragonRuby SDK.

## First-time setup and running the game

Install the complete DragonRuby SDK for your operating system **outside this repository**. Use the macOS distribution on macOS, the Windows distribution in native Windows, and the appropriate Linux distribution in Linux or WSL. Collaborators should use the same DragonRuby release.

Set `DRAGONRUBY_HOME` to the extracted SDK folder containing `dragonruby` or `dragonruby.exe`. The SDK can live anywhere outside this repository; the paths below are examples. Replace them with your own installation path.

**macOS (Zsh):**

Persist the setting once, then load it into your current terminal:

```sh
echo 'export DRAGONRUBY_HOME="$HOME/tools/dragonruby-macos"' >> ~/.zshrc
source ~/.zshrc
```

Then, from the repository root, run the game:

```sh
bash scripts/run.sh
```

**Linux or WSL (Bash):**

Persist the setting once, then load it into your current terminal:

```sh
echo 'export DRAGONRUBY_HOME="$HOME/tools/dragonruby-linux-amd64"' >> ~/.bashrc
source ~/.bashrc
```

Use the Linux SDK matching your CPU architecture, including when working inside WSL. If you use Zsh on Linux, use `~/.zshrc` instead of `~/.bashrc`.

Then, from the repository root, run the game:

```sh
bash scripts/run.sh
```

**Native Windows (PowerShell):**

Persist the setting once for your Windows user:

```powershell
[Environment]::SetEnvironmentVariable('DRAGONRUBY_HOME', 'C:\tools\dragonruby-windows', 'User')
```

Close and reopen your terminal application so it picks up the setting. If using an integrated terminal, restart the editor too. Then, from the repository root, run the game:

```powershell
.\scripts\run.ps1
```

Both launchers locate `mygame/` relative to the script, run from the SDK directory, and forward additional arguments to DragonRuby. Paths containing spaces are supported. For example:

```sh
bash scripts/run.sh --test tests/player_collision_test.rb
```

Test filenames are relative to `mygame/`, so use `tests/...` rather than `mygame/tests/...`. In PowerShell, use `.\scripts\run.ps1 --test tests/player_collision_test.rb`.

The scripts read the environment variable directly; they do not load `.env` files. SDK credentials belong outside the repository. Sprite paths remain relative to `mygame/`, such as `sprites/enemy.png`.

The game source starts at `mygame/app/main.rb`. DragonRuby runs this Ruby source directly and hot-reloads saved changes, so there is no compile step during normal development.

## Development checks

Install the development gems from the repository root:

```sh
bundle install
```

Lint the project-owned Ruby files before handing off a change:

```sh
bundle exec rubocop
```

DragonRuby's native tests and manual playtesting remain separate checks; use them when a change affects deterministic rules or player-visible behavior.

Run the complete native suite with `bash scripts/run.sh --test tests/all_test.rb` (PowerShell: `.\scripts\run.ps1 --test tests/all_test.rb`).

### DragonRuby editor completion

Open `descent.code-workspace` in VS Code with the Ruby LSP extension installed. The game launchers automatically create a Git-ignored `.dragonruby-lsp` link to the SDK root in `DRAGONRUBY_HOME`. macOS/Linux/WSL use a symlink; native Windows uses a directory junction. SDK files stay outside the repository, and each contributor's environment variable supplies their own installation path.

Ruby LSP indexes only `.dragonruby-lsp/docs/oss/**/*.rb`. API documentation is also available at `.dragonruby-lsp/docs/api/`, preserving the SDK's directory layout. Ruby LSP does not execute documentation helpers such as `DocsOrganizer.get_docsify_content`, so it will not automatically display the referenced Markdown as method documentation.

After the first launch, run **Ruby LSP: Restart** from the command palette to index the SDK definitions. If you change `DRAGONRUBY_HOME`, run the launcher again and restart Ruby LSP. The launchers refresh existing links, leave ordinary files and directories untouched, and warn if editor setup fails while continuing to launch the game.

Completion covers the Ruby definitions shipped in the SDK; Ruby LSP may still be unable to infer dynamic fields such as `args.state.some_custom_field`.

## Package a distributable build

Before packaging, fill in the release fields near the top of `mygame/metadata/game_metadata.txt`, including `devid`, `devtitle`, `gameid`, `gametitle`, and `version`. From the repository root, run with your external SDK (macOS/Linux/WSL):

```sh
game_dir="$PWD/mygame"
(cd "$DRAGONRUBY_HOME" && ./dragonruby-publish --package "$game_dir")
```

On native Windows, run `dragonruby-publish.exe --package` from the SDK directory with the absolute path to this repository's `mygame` directory.

DragonRuby will create packaged platform builds in a generated build directory. See `docs/guides/deploying-to-itch.md` inside your SDK installation for deployment instructions.

## Upload game assets here

Stakeholders contributing assets should upload them to:

- `mygame/sprites/` for sprites
- `mygame/sounds/` for sounds

Keep the original/source asset and any license or provenance notes alongside the delivery when available. Keep project assets in this repository, separate from your SDK installation.

The cathedral tilesheet is `mygame/sprites/tilesheet.png` (17 × 17 cells, 32 × 32 pixels each). The [tilesheet skill](.agents/skills/tilesheet/SKILL.md) documents tile selection and DragonRuby cropping; its [tile lookup](.agents/skills/tilesheet/references/tiles.md) lists all 289 names and cells. The original `main_32x32.json` is retained as source metadata; its vendor asset paths do not match this repository.

### Try props and tune collision

[tilesheet.rb](mygame/app/tilesheet.rb) contains all 289 tile names in sheet order and computes their source rectangles. Ruby names use underscores, such as `closed_stone_coffin`. The JSON is not loaded by the game; the native catalog test compares the Ruby mapping against it.

Edit `PROP_PLACEMENTS` in [collision_playground.rb](mygame/app/collision_playground.rb) to select tiles and set their positions. Each entry uses `{ id: :closed_stone_coffin, x: 650, y: 290 }`; optional `facing` defaults to `:south` and does not change the fixed artwork.

Edit `PROP_OVERRIDES` in [prop.rb](mygame/app/prop.rb) to tune a id. Without an override, any catalog tile spawns at scale `1` with a full 32 × 32 collider. For example:

```ruby
closed_stone_coffin: { scale: 3, collider: { w: 24, h: 10 }.freeze }.freeze,
red_banner: { scale: 3, collider: nil }.freeze
```

Collider dimensions are unscaled pixels; scale applies to both art and collision. Omit `collider` for the full-cell default, or set it to `nil` for decoration. Position is the horizontal center of the cell's bottom edge, shared with the collider. These footprints are starting values for visual tuning, not measurements supplied by the atlas.

Save edits to placements, overrides, or the catalog to rebuild the playground props on hot reload. Player state and danger timers are preserved. Prop positions are rebuilt from the placements. Press **B** to toggle collision outlines: prop footprints are blue. Walk into the coffin to test blocking and through the banner to check decoration; edit the coffin's dimensions and confirm that its outline and collision update together.

## Repository guide

Project-owned files:

```text
mygame/
  app/                  Game Ruby code; main.rb is the entry point
  data/                 Authored game data
  fonts/                Game-specific fonts
  metadata/             DragonRuby game and platform configuration
  sounds/               Music and sound effects
  sprites/              The Descent sprite upload destination

scripts/                Cross-platform game launchers

PRODUCT.md              Player experience, core loop, and MVP scope
CONTEXT.md              Current decisions, working models, and open questions
AGENTS.md               Repository conventions for coding agents
CLAUDE.md               One-line @AGENTS.md import for Claude Code
.agents/skills/         Project-specific design and development workflows
.claude/skills          Symlink to .agents/skills for Claude Code discovery
```

DragonRuby executables, `.dragonruby/`, engine docs, samples, and bundled resources live in the external SDK directory selected by `DRAGONRUBY_HOME`. Do not copy the SDK into this repository.

## Project direction

Read [PRODUCT.md](PRODUCT.md) for the intended player experience and first playable scope. Read [CONTEXT.md](CONTEXT.md) for current decisions and unresolved prototype questions. The current MVP is a lean, single-player vertical slice; avoid assuming that future ideas such as co-op, procedural maps, or a larger narrative are approved.

## Shared agent workflows

Project skills live in `.agents/skills/`, including the `grilling` and `domain-modeling` dependencies of `grill-with-docs`. These are project-maintained copies; see [.agents/skills/THIRD-PARTY.md](.agents/skills/THIRD-PARTY.md) for their source, adaptations, and license.

The same skills and repository conventions are shared with every agent harness, so there is no per-tool copy to keep in sync. Codex reads `AGENTS.md` and `.agents/skills/` directly. Claude Code reads `CLAUDE.md`, a one-line `@AGENTS.md` import, and discovers skills through `.claude/skills`, a committed symlink to `.agents/skills`. Native Windows checkouts need `git config --global core.symlinks true` (or Developer Mode) before cloning for that link to resolve; without it Claude Code simply finds no project skills, and nothing else is affected.

Choose your Ruby version manager in personal editor settings; the shared workspace configures only formatting and linting.

## DragonRuby help

Documentation is available under `$DRAGONRUBY_HOME/docs/` and online at [docs.dragonruby.org](https://docs.dragonruby.org).

The SDK includes examples under its `samples/` directory.

DragonRuby community Discord: [discord.dragonruby.org](https://discord.dragonruby.org).

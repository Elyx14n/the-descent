# The Descent

The Descent is a small, top-down horror game being built with DragonRuby Game Toolkit. The player explores a monastery, deciphers a ritual lock, and evades the Witness: an enemy that uses evidence left in the world to anticipate where the player will go.

## Prerequisites

Before setting up the repository, ensure you have the following installed:

* **DragonRuby Game Toolkit SDK:** Download the latest platform build for your OS (macOS, Linux, or Windows).
* **Ruby:** Needed for repository development checks; use your preferred version manager.
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
- `mygame/fonts/` for fonts

Keep the original/source asset and any license or provenance notes alongside the delivery when available. Keep project assets in this repository, separate from your SDK installation.

32 × 32 is the usual sprite cell size, not a strict asset requirement. The player animation sheets use 64 × 64 frames, configured in [player.rb](mygame/app/player.rb). Use each asset's actual source dimensions; see the [display and sprite-size guidance](docs/adr/0002-reference-resolution-and-ui-fonts.md) for how source dimensions, entity scale, and display scaling relate.

### Author and preview rooms in Tiled

Open `mygame/tiled/descent.tiled-project` and edit `ritual_gate.tmj`. Export to `mygame/tiled/ritual_gate.json` as a **JSON map with embedded tilesets and uncompressed tile arrays**. Keep image paths relative to the map. The development preview checks the export every 30 ticks (about half a second at 60 FPS). Save and re-export to reload automatically; a successful reload resets the player to Spawn and doors to their authored states. **R** forces a rebuild, including Ruby sprite/collider configuration changes. The B collision-overlay toggle survives reloads. Invalid or incomplete exports retain the last valid room and show an error; fixing the export triggers recovery.

The first room uses finite orthogonal maps with these layers:

| Layer | Type | Purpose |
| --- | --- | --- |
| Ground | Tile | Floor and background artwork |
| FloorDetails | Object | Floor markings and rugs, above Ground and below scenery and the player |
| Walls | Object | Wall tile objects |
| Props | Object | Fixtures, door bases, pedestals, lights, and Spawn |
| Ceiling | Tile | Overhead artwork, rendered after the player |

FloorDetails render above Ground and below Walls, Props, and the player, independently of their Y positions. Walls and Props sort together with the player by their ground position. Use bottom-left tile-object alignment. Author rectangular collision shapes in the Tile Collision Editor; all shapes are imported and follow object scaling and horizontal/vertical flips. Tiles without collision shapes are decorative. Rotated objects, diagonal flips, layer offsets, infinite maps, and external tileset references are currently rejected with an error.

Walls and Props currently sort at the lowest world Y of their collision rectangles, or at the artwork's bottom edge when there is no collision. Ceiling always renders above the player and does not block movement. The player's foot collider is 8 × 2. JSON edits reload automatically; press **R** to force a rebuild after code/configuration changes.

For wall-mounted artwork on Props, set `mounted_on` to an **Object** reference to its supporting object on Walls. Leave the default empty (exported as 0) for freestanding props. The importer draws the supporting wall and its mounted props as one group at the wall's sorting position, drawing the props after the wall. Keep placing artwork and defining colliders and flame offsets normally; the reference only controls drawing. Hosts must be visible tile objects on Walls; attachments are one level deep. The two ledge candles reference objects 117 and 118. Numeric elevation offsets are no longer used.

Classes and properties:

- **Spawn:** exactly one point object, positioned where the player's feet start. It has no artwork or collider.
- **Door:** set `close_tile` and `open_tile` to the same closed/open local tile IDs on both artwork variants. Place either variant to choose the starting state. Set `locked: true` on a placed base to block E interaction; the north Ritual Gate uses this override. Missing `locked` defaults to false. A base on Props owns a Door tile immediately above it on Ceiling, when present; the upper piece follows the base's state. Author collision rectangles separately on the closed and open base tiles; the active variant supplies collision. An open variant without rectangles is passable. Ceiling pieces remain visual only. Keep static stairway artwork unclassed.
- **Light:** class the fixture tile and set `offset_x`/`offset_y` to the emitter's position in native source pixels, measured right/down from the tile's top-left. Tile properties can be overridden per placed object. Emitter positions follow scaling and flips. `enabled`, `radius`, `intensity`, and `color` are preserved for later lighting; no lighting is rendered yet.
- **Pedestal:** class the fixture tile and set `offset_x`/`offset_y` to the item placement anchor in native source pixels, measured right/down from the tile's top-left. Placed objects can override those offsets. `room.pedestals` contains the scenery entries with a world-space `item_position` that follows scaling and flips. The four pedestals will receive the four ritual items described in [PRODUCT.md](PRODUCT.md); placement and puzzle-driven unlocking are not implemented yet.

Walk with WASD, sneak with Shift, and toggle the player lamp with F. **E** toggles the nearest door within 24 world pixels; it cannot change state if that door is locked or the resulting collider would overlap the player's feet. **B** shows collision outlines and orange light emitter markers. Inspect `args.state.room_preview` for the room, player, camera, source path, diagnostic toggles, and `reload_error`. The full error remains available there when the HUD message is shortened.

#### Room preview and rendering interfaces

[RoomPreview](mygame/app/room_preview.rb) is the single-room authoring consumer called by `Main.tick`. Its default path is `tiled/ritual_gate.json`; pass another game-relative JSON path to `RoomPreview.tick(args, path: 'tiled/other_room.json')` to preview another export using the same conventions. Automatic file polling runs only in development. R still forces a reload in either mode.

This is a development preview for testing a discrete room. Its single-player state, room-sized camera bounds, and reload resets belong to that workflow. The Tiled resources, deserializer, room rules, and rendering interface can be reused by a future map consumer. Multi-room placement, shared map collision, and additional player views are not implemented; [ADR-0005](docs/adr/0005-render-data-and-room-preview.md#development-preview-and-map-reuse) records the capabilities and limits.

[TiledDeserializer](mygame/app/tiled_deserializer.rb) is a stateless module: `load(gtk, path:)` reads/parses a file, while `deserialize(data, path:)` accepts parsed JSON. Both return keyword data for `Room.new`. The deserializer knows Tiled's format; Room owns runtime door state and collision. [Keybinds](mygame/app/keybinds.rb) translates physical keys into player/preview actions, which their owners process.

[Render](mygame/app/render.rb) consumes ordinary world-space frame hashes, sorts/culls artwork, applies Camera's draw-space conversion, and submits DragonRuby outputs. Room and Player provide the data; Render reads neither object directly:

```ruby
frame = room.render_data
frame[:groups] << player.render_data
Descent::Render.draw(args, frame: frame, camera: camera)
```

The frame fields, module responsibilities, and reload behavior are recorded in [ADR-0005](docs/adr/0005-render-data-and-room-preview.md). The renderer does not mutate the frame or gameplay coordinates. Camera retains the accepted following and pixel-alignment calculations; Render owns the scene target and compositing.

#### How Tiled tile IDs are decoded

Tiled's exported **GID** (global tile ID) stores both a tile's map-wide ID and transformation flags in one 32-bit integer. The highest four bits hold flags; the remaining 28 bits hold the ID. A GID is global within one map, while properties such as `close_tile` and `open_tile` use IDs local to their tileset. See [Tiled's format documentation](https://doc.mapeditor.org/en/stable/reference/global-tile-ids/).

The importer uses these masks to separate the two:

| Constant | Meaning | Usage |
| --- | --- | --- |
| `GID_MASK = 0x0fffffff` | Keep the lower 28 ID bits; clear all four flag bits | `gid & GID_MASK` recovers the map-wide tile ID |
| `HORIZONTAL = 0x80000000` | Horizontal-flip flag | `gid.anybits?(HORIZONTAL)` tests whether to mirror left/right |
| `VERTICAL = 0x40000000` | Vertical-flip flag | `gid.anybits?(VERTICAL)` tests whether to mirror top/bottom |

`0x` denotes hexadecimal notation. `&` is bitwise AND, keeping only bits set in both operands; `anybits?` returns whether any of the specified flag bits are set. For example:

```ruby
gid = 600 | Descent::TiledDeserializer::HORIZONTAL # Bitwise OR adds the horizontal flag.
gid & Descent::TiledDeserializer::GID_MASK        # => 600
gid.anybits?(Descent::TiledDeserializer::HORIZONTAL) # => true
gid.anybits?(Descent::TiledDeserializer::VERTICAL)   # => false
```

For the current doors tileset, `firstgid` is 590, so GID 600 resolves to local tile ID 10 (`600 - 590`). The importer selects artwork using that local ID, then applies the original GID's flip flags to sprites, colliders, light emitters, and pedestal item positions. The other flag bits, `0x20000000` (diagonal flip) and `0x10000000` (hexagonal rotation), are currently rejected. No manual GID calculation is required when authoring in Tiled.

#### Rendering defaults

The confirmed rendering configuration is **HD on + pixel-art sampling (`scale_quality=3`) + camera/artwork drawing alignment**. The completed enlarged-window playtests reported no jitter or tile seams in this configuration; [ADR-0001](docs/adr/0001-viewport-sized-camera.md) records the comparison and [GLOSSARY](GLOSSARY.md#rendering) defines the rendering terms. **Restart DragonRuby** to load metadata changes. Rendering always uses the scene target, and sprite/target sampling inherits `game_metadata.txt`; there are no runtime sampling or rendering-path overrides.

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

scripts/                Cross-platform game launchers
.agents/skills/         Project-specific design and development workflows
.claude/skills          Symlink to .agents/skills for Claude Code discovery
```

## Project direction

Read [PRODUCT.md](PRODUCT.md) for scope and [CONTEXT.md](CONTEXT.md) for progress. The [documentation guide](docs/agents/domain.md) identifies where vocabulary, decisions, and research belong.

## Shared agent workflows

Project skills live in `.agents/skills/`, including the `grilling` and `domain-modeling` dependencies of `grill-with-docs`. These are project-maintained copies; see [.agents/skills/THIRD-PARTY.md](.agents/skills/THIRD-PARTY.md) for their source, adaptations, and license.

Use `$tiled-json-audit` to audit a Tiled room export before integration or after re-exporting. The [skill](.agents/skills/tiled-json-audit/SKILL.md) checks the current importer and agreed authoring conventions, reports actionable Tiled corrections, and distinguishes static findings from checks that need playtesting.

Codex reads `AGENTS.md` and `.agents/skills/`. Claude Code imports the same guidance through `CLAUDE.md` and discovers the same skills through `.claude/skills`. Native Windows checkouts need symlink support (`git config --global core.symlinks true` and permission to create symlinks, such as Developer Mode) before cloning; otherwise Claude Code will not discover project skills through that link.

Choose your Ruby version manager in personal editor settings; the shared workspace configures only formatting and linting.

## DragonRuby help

Documentation is available under `$DRAGONRUBY_HOME/docs/` and online at [docs.dragonruby.org](https://docs.dragonruby.org).

The SDK includes examples under its `samples/` directory.

DragonRuby community Discord: [discord.dragonruby.org](https://discord.dragonruby.org).

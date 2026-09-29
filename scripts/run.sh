#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DRAGONRUBY_HOME:-}" ]]; then
  echo 'Set DRAGONRUBY_HOME to your extracted macOS or Linux DragonRuby SDK directory.' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
game_dir="$repo_root/mygame"

if [[ ! -f "$game_dir/app/main.rb" ]]; then
  echo "Game entry point not found: $game_dir/app/main.rb" >&2
  exit 1
fi

if [[ ! -x "$DRAGONRUBY_HOME/dragonruby" ]]; then
  echo "DragonRuby executable not found or not executable: $DRAGONRUBY_HOME/dragonruby" >&2
  exit 1
fi

# Expose SDK-relative documentation paths; Ruby LSP indexes only docs/oss.
editor_link="$repo_root/.dragonruby-lsp"
if [[ ! -d "$DRAGONRUBY_HOME/docs/oss" ]]; then
  echo 'Warning: SDK docs/oss is missing; DragonRuby editor indexing is unavailable.' >&2
elif [[ -e "$editor_link" && ! -L "$editor_link" ]]; then
  echo "Warning: $editor_link is not a symlink; leaving it untouched." >&2
else
  editor_target="$(cd -- "$DRAGONRUBY_HOME" && pwd -P)"
  if [[ ! -L "$editor_link" ]] || [[ "$(readlink "$editor_link")" != "$editor_target" ]]; then
    if ! ln -sfn "$editor_target" "$editor_link"; then
      echo 'Warning: Could not set up DragonRuby editor indexing; continuing to launch.' >&2
    fi
  fi
fi

cd -- "$DRAGONRUBY_HOME"
exec ./dragonruby "$game_dir" "$@"

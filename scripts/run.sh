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

cd -- "$DRAGONRUBY_HOME"
exec ./dragonruby "$game_dir" "$@"

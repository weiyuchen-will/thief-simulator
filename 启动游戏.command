#!/bin/zsh
set -eu
cd "$(dirname "$0")"
if [[ -x /Users/digiantclaw/Downloads/Godot.app/Contents/MacOS/Godot ]]; then
  exec /Users/digiantclaw/Downloads/Godot.app/Contents/MacOS/Godot --path "$PWD"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"
elif command -v godot >/dev/null 2>&1; then
  exec godot --path "$PWD"
else
  print '请用 Godot 导入本目录中的 project.godot，然后按 F5（已验证 Godot 4.7.2）。'
  read -r
fi

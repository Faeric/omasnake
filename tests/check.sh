#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

omarchy plugin validate "$project_dir"
jq -e '.id == "io.github.faeric.omasnake" and .version == "1.2.0" and .entryPoints.barWidget == "BarWidget.qml"' \
  "$project_dir/manifest.json" >/dev/null

for contract in \
  'moduleName: "io.github.faeric.omasnake"' \
  'KeyboardPanel {' \
  'PanelKeyCatcher {' \
  'function advance()' \
  'function requestDirection(dx, dy)' \
  'function digitPattern(digit)' \
  'id: scoreSeparator' \
  'id: playfieldFrame' \
  'id: welcomeFrame' \
  'width: 3' \
  'id: asciiTitle' \
  'id: asciiTitleViewport' \
  'transformOrigin: Item.Center' \
  'contentWidth: gamePanel.fittedContentWidth(root.columns * root.cellSize + 64)' \
  'readonly property color popupText: Color.popups.text' \
  'readonly property color popupBorder: Color.popups.border' \
  'readonly property color popupAccent: Color.accent' \
  'id: snakePixel' \
  'model: 9' \
  'antialiasing: false' \
  'text: "ARROW KEY TO PLAY"' \
  'assets/omarchy-mark.svg'; do
  rg -Fq "$contract" "$project_dir/BarWidget.qml"
done

test -f "$project_dir/assets/omarchy-mark.svg"
test -f "$project_dir/preview.png"
test -f "$project_dir/THIRD_PARTY_NOTICES.md"
printf 'All Omasnake checks passed.\n'

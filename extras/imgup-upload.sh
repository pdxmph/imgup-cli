#!/usr/bin/env zsh -l
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title imgup (Photos or Finder)
# @raycast.mode silent
# @raycast.icon 📷
# @raycast.description Upload an image from Photos.app or Finder and copy the snippet
# @raycast.author pdxmph
# @raycast.authorURL https://raycast.com/pdxmph
#
# @raycast.argument1 { "type": "dropdown", "placeholder": "Source", "optional": false, "data": [ { "title": "Photos", "value": "photos" }, { "title": "Finder", "value": "finder" } ] }
# @raycast.argument2 { "type": "text", "placeholder": "alt text" }
# @raycast.argument3 { "type": "dropdown", "placeholder": "Format", "optional": false, "data": [ { "title": "Markdown", "value": "md" }, { "title": "Org", "value": "org" } ] }

set -euo pipefail

SOURCE=$1
ALT_TEXT=$2
FORMAT=$3

# 1) Determine IMAGE path
if [[ $SOURCE == "photos" ]]; then
  # export the selected photo to a temp directory
  EXPORT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/imgup.XXXXXX")
  osascript <<EOF
set exportPath to POSIX file "$EXPORT_DIR" as alias
tell application "Photos"
  set sel to selection
  if sel = {} then error "No photo selected."
  export sel to exportPath using originals yes
end tell
EOF
  # slight pause to ensure file appears
  sleep 1
  IMAGE="$EXPORT_DIR/$(ls -1t "$EXPORT_DIR" | head -n1)"
else
  # get the first selected file in Finder
  IMAGE=$(
    osascript <<AS
tell application "Finder"
  set sel to selection
  if sel = {} then error "No file selected."
  return POSIX path of (item 1 of sel as alias)
end tell
AS
  )
fi

# 2) Notify start
terminal-notifier -title "🤖 📦" -message "Processing …"

# 3) Run imgup CLI
SNIPPET=$(
  imgup \
    --format ${FORMAT// /} \
    --title ${ALT_TEXT// / } \
    "$IMAGE"
)

# 4) Copy result and notify
printf '%s' "$SNIPPET" | pbcopy
terminal-notifier \
  -title "Image uploaded" \
  -message "📋 Snippet ready" \
  -sound default \
  -remove com.Apple.terminal

# 5) Cleanup temp if used
if [[ $SOURCE == "photos" ]]; then
  rm -rf "$EXPORT_DIR"
fi

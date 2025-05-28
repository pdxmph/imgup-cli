#!/bin/zsh -l
# hazel_smugmug_v2.sh - Updated to use imgup-cli's metadata extraction
# Hazel "Run shell script" (Shell=/bin/zsh, Pass matched files to shell script: as arguments)

# send all output to debug log
set -euo pipefail

# ensure tools in PATH
for F in "$@"; do
    # resolve absolute path
    FILE=$(realpath "$F")
    echo "--> Processing: $FILE"

    [[ ! -f "$FILE" ]] && {
        echo "⚠️ Missing file: $FILE"
        continue
    }

    # The new imgup-cli will extract metadata automatically!
    # We just need to call it - no more manual exiftool extraction
    echo "   Uploading with automatic metadata extraction..."
    
    # call imgup CLI with metadata extraction (default behavior)
    SNIP=$(
        imgup --format org "$FILE"
    )
    echo "   snippet: $SNIP"

    # copy & notify
    printf '%s' "$SNIP" | pbcopy
    terminal-notifier -title "SmugMug Upload" -message "Snippet ready" -sound default
    echo "   snippet copied & notified"

    # archive original
    ARCHIVE="$HOME/Uploads/Uploaded"
    mkdir -p "$ARCHIVE"
    mv "$FILE" "$ARCHIVE/"
    echo "   moved to $ARCHIVE/"
done

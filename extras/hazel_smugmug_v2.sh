#!/bin/zsh -l
# Updated Hazel "Run shell script" for metadata-aware imgup
# Shell=/bin/zsh, Pass matched files to shell script: as arguments

set -euo pipefail

# Process each file
for F in "$@"; do
    # Resolve absolute path
    FILE=$(realpath "$F")
    echo "--> Processing: $FILE"

    [[ ! -f "$FILE" ]] && {
        echo "⚠️ Missing file: $FILE"
        continue
    }

    # Use imgup's new metadata extraction
    # The --verbose flag will show what metadata was extracted
    # The tool will automatically extract alt text from IPTC/XMP
    echo "   Running imgup with automatic metadata extraction..."
    
    SNIP=$(
        cd ~/code/imgup-cli
        rbenv exec bundle exec bin/imgup \
            --format org \
            --verbose \
            "$FILE"
    )
    
    # Extract just the snippet line (not the verbose output)
    SNIPPET_LINE=$(echo "$SNIP" | grep -E '^\[\[img:' | head -n1)
    
    echo "   Snippet: $SNIPPET_LINE"

    # Copy to clipboard
    printf '%s' "$SNIPPET_LINE" | pbcopy
    terminal-notifier -title "SmugMug Upload" -message "Snippet ready with metadata" -sound default
    echo "   Snippet copied & notified"

    # Archive original
    ARCHIVE="$HOME/Uploads/Uploaded"
    mkdir -p "$ARCHIVE"
    mv "$FILE" "$ARCHIVE/"
    echo "   Moved to $ARCHIVE/"
done

#!/bin/zsh -l
# Hazel “Run shell script” (Shell=/bin/zsh, Pass matched files to shell script: as arguments)

# send all output to debug log
set -euo pipefail

# ensure tools in PATH
for F in "$@"; do
    # resolve absolute path
    FILE=$(realpath "$F")
    echo "--> resolved to: $FILE"

    [[ ! -f "$FILE" ]] && {
        echo "⚠️ Missing file: $FILE"
        continue
    }

    # extract just the first non‑empty caption tag
    RAW_ALT=$(
        exiftool -s3 -IPTC:Caption-Abstract "$FILE" |
            head -n1
    )
    echo "   raw ALT from IPTC: ‘$RAW_ALT’"

    # if IPTC was empty, try XMP
    if [[ -z $RAW_ALT ]]; then
        RAW_ALT=$(exiftool -s3 -XMP-dc:description "$FILE" | head -n1)
        echo "   raw ALT from XMP: ‘$RAW_ALT’"
    fi

    # sanitize: collapse newlines/CR into spaces, trim
    ALT=$(printf '%s' "$RAW_ALT" | tr '\r\n' ' ' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    [[ -z $ALT ]] && ALT="image"
    echo "   clean ALT: ‘$ALT’"

    # call imgup CLI
    SNIP=$(
        #cd ~/code/imgup
        imgup --format org --title "${ALT}" "$FILE"
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

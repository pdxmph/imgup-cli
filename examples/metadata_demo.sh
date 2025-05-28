#!/bin/bash
# Demo script showing metadata flow through imgup-cli

echo "=== imgup-cli Metadata Demo ==="
echo
echo "This demonstrates how metadata appears in different outputs."
echo

# Sample metadata
TITLE="Golden Gate Sunset"
ALT_TEXT="The Golden Gate Bridge silhouetted against an orange sunset sky"
TAGS="bridge,sunset,sanfrancisco"

echo "Metadata values:"
echo "  Title: $TITLE"
echo "  Alt text: $ALT_TEXT"
echo "  Tags: $TAGS"
echo

# Simulated outputs
IMAGE_URL="https://photos.smugmug.com/Photos/i-ABC123/0/X3/IMG_1234-X3.jpg"

echo "=== Snippet Outputs ==="
echo
echo "HTML format:"
echo "<img src=\"$IMAGE_URL\" alt=\"$ALT_TEXT\" />"
echo
echo "Markdown format:"
echo "![$ALT_TEXT]($IMAGE_URL)"
echo
echo "Org-mode format:"
echo "[[img:$IMAGE_URL][$ALT_TEXT]]"
echo

echo "=== Social Media ==="
echo "Image description field: $ALT_TEXT"
echo "Post hashtags: #bridge #sunset #sanfrancisco"
echo

echo "=== Command Examples ==="
echo
echo "# Automatic extraction:"
echo "imgup photo.jpg"
echo
echo "# Explicit metadata:"
echo "imgup --title \"$TITLE\" --alt-text \"$ALT_TEXT\" --tags \"$TAGS\" photo.jpg"
echo
echo "# Review before upload:"
echo "imgup --review photo.jpg"

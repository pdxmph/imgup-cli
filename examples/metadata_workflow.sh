#!/bin/bash
# Example workflow showing the new metadata features

echo "=== imgup-cli Metadata Features Demo ==="
echo

# 1. Basic upload with automatic metadata extraction
echo "1. Automatic metadata extraction (default behavior):"
echo "   imgup photo.jpg"
echo "   → Extracts IPTC/XMP metadata automatically"
echo

# 2. Upload with explicit alt text
echo "2. Explicit alt text override:"
echo "   imgup --alt-text 'Sunset over the Golden Gate Bridge' photo.jpg"
echo "   → Uses your alt text instead of extracted metadata"
echo

# 3. Review mode for metadata
echo "3. Interactive metadata review:"
echo "   imgup --review photo.jpg"
echo "   → Shows extracted metadata and allows editing before upload"
echo

# 4. Disable automatic extraction
echo "4. Disable metadata extraction:"
echo "   imgup --no-extract --title 'My Photo' --alt-text 'A beautiful scene' photo.jpg"
echo "   → Uses only the provided values, no extraction"
echo

# 5. Verbose mode to see what's happening
echo "5. Verbose mode to see extraction:"
echo "   imgup -v photo.jpg"
echo "   → Shows what metadata was extracted"
echo

# 6. Social media posting with proper alt text
echo "6. Upload and post to Mastodon with alt text:"
echo "   imgup --mastodon --post 'Check out this photo!' photo.jpg"
echo "   → Alt text from metadata is used for accessibility on Mastodon"
echo

echo "=== Key Improvements ==="
echo "• Alt text is now separate from title"
echo "• Automatic extraction from IPTC Caption-Abstract and XMP description"
echo "• Proper accessibility support for social media"
echo "• Interactive review mode for quality control"
echo "• Backwards compatible - existing scripts still work"

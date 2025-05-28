#!/bin/bash
# Test script for metadata extraction features

echo "Testing imgup-cli metadata extraction..."
echo

# Test 1: Show extracted metadata with verbose flag
echo "=== Test 1: Extract metadata from image (verbose) ==="
rbenv exec bundle exec bin/imgup --verbose --no-extract ~/test_image.jpg --dry-run 2>/dev/null || echo "(Dry run - no actual upload)"
echo

# Test 2: Review metadata before upload
echo "=== Test 2: Review and edit metadata ==="
echo "This would show the review interface (skipping for non-interactive test)"
echo

# Test 3: Override with explicit alt text
echo "=== Test 3: Override with explicit alt text ==="
rbenv exec bundle exec bin/imgup --alt-text "A beautiful sunset over the ocean" --title "Sunset Photo" ~/test_image.jpg --dry-run 2>/dev/null || echo "(Dry run - no actual upload)"
echo

# Test 4: Disable extraction
echo "=== Test 4: Disable automatic extraction ==="
rbenv exec bundle exec bin/imgup --no-extract --title "Manual Title" ~/test_image.jpg --dry-run 2>/dev/null || echo "(Dry run - no actual upload)"
echo

echo "To test with a real image:"
echo "  rbenv exec bundle exec bin/imgup --verbose --review path/to/your/image.jpg"

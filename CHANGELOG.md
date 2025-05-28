# Changelog

## v0.12.0

### Breaking Changes
- **Renamed `--fedi` to `--gotosocial`** for clarity
- **`--post` no longer auto-switches backend** - it now requires either `--mastodon` or `--gotosocial`
- Improved validation: using `--post` without a social platform flag will show an error

### Bug Fixes
- Fixed FediPoster to properly handle single upload results (was causing "no implicit conversion of Symbol into Integer" error)
- Added missing flickraw dependency to gemspec

### Improvements
- Clearer separation of concerns between uploading and social posting
- More predictable behavior - no hidden backend switching
- Better error messages when `--post` is used incorrectly
- Updated README with clearer usage examples

### Migration
If you were using:
- `--fedi` → use `--gotosocial`
- `--post "text"` alone → add either `--mastodon` or `--gotosocial`

## Previous versions...

# Changelog

All notable changes to docker-builder will be documented in this file.

## [1.21.0] - 2025-10-29

### Added
- `bin/x`: `-C` option for directory change before workspace detection (#5)
  - Options can appear in any order before command
  - Added `--` to stop option parsing
  - Converted `--root` to parsed option
- `bin/docker-builder-run`: Automatic `run-hook.sh` template synchronization
  - Images can embed templates with SHA256 verification
  - Auto-updates workspace files when SHA256 mismatches
  - Opt-out via magic values: `"-"`, `"disabled"`, or `""`
  - New helpers: `safe_atomic_write()`, `get_run_hook()`, `docker_label()`
- `docker/entrypoint`: `--run-hook` option to extract embedded templates
- `docker-poky-builder`: Embedded `run-hook.sh` templates in 18.04 and 24.04

### Changed
- `docker-golang-builder`: Updated to Go 1.23.12, 1.24.9, 1.25.3
- `docker-golang-builder`: Use `GODOC_VERSION` env var for Go 1.18-1.19
- `docker-golang-builder`: Pin godoc to v0.36 for Go 1.23-1.25
- `docker-golang-builder`: Add Go bin directory to PATH in entrypoint
- `docker-poky-builder`: Add 24.04 image, rename latest to 18.04
- Alpine entrypoint: Use `su-exec` for non-TTY to fix stdin hang
- Entrypoint system: Consolidate to golden copies with make generation
- Entrypoint.d scripts: Standardize numbering (05-, 10-, 20-, 30- prefixes)

### Fixed
- Alpine images: Fix command execution hang in non-TTY mode
- `docker-builder-run`: Fix pipeline hazard with trap-protected helpers
- `bin/x`: Fix directory validation and error handling
- golang entrypoint: Fix broken GOPATH comparison
- Ubuntu VSC base: Implement full entrypoint functionality
- Ubuntu builder: Fix entrypoint pipeline exit status bug

### Documentation
- Add DESIGN.md for architecture internals
- Add CONTRIBUTING.md with guidelines
- Add comprehensive `x` script documentation
- Improve build system caching mechanics documentation
- Add Python dependency guidance
- Fix terminology: "project root" → "workspace root"
- Validate all markdown with markdownlint

## [1.20.3] - (Previous Release)

See git history for earlier changes.

# Changelog
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to docker-builder will be documented in this file.

## [Unreleased]

### Changed

- Build system: Enable registry-backed inline cache for layer
  reuse across rebuilds, even when base image digests change
- `docker-golang-builder`: Update Go 1.25 to 1.25.8 and
  Go 1.26 to 1.26.1
- `docker-golang-builder`: Make Go 1.26 the default
  - Update latest symlink from 1.25 to 1.26
  - Rebase multi image on 1.26, build 1.25 inside
- `docker`: Update ubuntu-based golang images to Go 1.26.1
- `docker`: Update Node.js from 20.x/22.x to 24.x LTS

## [1.22.0] - 2026-03-22

### Added

- Multi-architecture build support using docker buildx
  - All builds produce amd64 + arm64 manifests by default
  - Per-image architecture exclusions via `# build: !arm64`
    directive comments
  - `BUILDER` variable to select buildx builder
    (default: `multiarch-native`)
- `docker-builder-run`: Use buildx when available
  - `docker_build()` abstracts build method selection
  - Uses `--builder default` for local builds
  - Falls back to legacy `docker build` when buildx is
    not installed
  - `--iidfile` replaces double-build pattern for image
    ID capture
- `docker-golang-builder`: Add Go 1.26.0, `go1.X` directory
  symlinks, and Go 1.26.0 to multi image
- `docker-apptly-builder`: Add chromium, xvfb, and
  international fonts for headless browser automation
- `docker-ubuntu-builder`: Add python venv auto-setup
- `docker-ubuntu-vsc-nodejs-builder`: Add npm and pnpm
  entrypoint hooks
- `docker-poky-builder`: Add SYS_ADMIN capability for
  BitBake network isolation
- `docker-poky-builder`: Add MACHINE, DISTRO, TCLIBC to
  BitBake environment whitelist
- `docker-poky-builder`: Enable arm64 with conditional
  multilib
- `docker-micrologic-builder`: Install all buf cmd tools
- MIT licence file

### Changed

- `docker-builder-run`: Stop defaulting `NPM_CONFIG_PREFIX`
  to workspace root
- `10-node`: Use `~/.local/share/npm` as default
  `NPM_CONFIG_PREFIX`
- `20-node-pnpm`: Always set up `~/.local/share/pnpm`
  environment
- `docker-golang-builder`: Update Go 1.24 to 1.24.13 and
  Go 1.25 to 1.25.7
- `docker-android-builder`: Switch from OpenJDK 19 to 21
- `docker-poky-builder`: Improved `BUILDDIR` detection
  - Detects build directory from workspace-relative path
  <!-- cSpell:disable-next-line -->
  - Falls back to searching workspace for
    `*[Bb]uild*/conf/local.conf`
  - Works from any subdirectory in workspace
  - `30-poky.sh` now uses `BUILDDIR` from `run-hook.sh`
    when available
- `docker`: Harden apt usage across all ubuntu-based images
- `docker`: Apply noninteractive dist-upgrade across all
  images
- `Makefile`: Always regenerate images.mk using FORCE+cmp

### Fixed

- `gen_images_mk.sh`: Symlink targets now depend on their
  real target
  <!-- cSpell:disable-next-line -->
  - Fixes automatic retagging when underlying image is
    rebuilt
  - Example: `:latest` now properly depends on `:24.04`

### Documentation

- Document `DOCKER` and `DOCKER_BUILD_OPT` variables
- Fix build guidance and other documentation bugs

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

# Changelog
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to docker-builder will be documented in this file.

## [Unreleased]

### Added

- Local build mode for verifying a change before committing it:
  `make BUILDER= <target>` builds for the host architecture alone and
  loads the image into the local daemon untagged, recording its ID in
  the `.image-*` marker. It pushes nothing and leaves no persistent
  tag, so `docker image prune` reclaims it; run it via
  `DOCKER_ID="$(cat .image-<name>)" docker-builder-run`. The build is
  single-target —
  base images are pulled, not rebuilt. The normal mode
  (`BUILDER=multiarch-native`) is unchanged: it still pushes the
  multi-arch manifest, retags aliases, and builds bases first
- Plugin golden copies under `docker/entrypoint/plugins/` for the shared
  `/etc/entrypoint.d` scripts (`05-display`, `10-android-sdk`, `10-golang`,
  `10-node`, `10-python`, `20-node-pnpm`); the per-image copies are now
  generated and git-ignored
- `docker/entrypoint/shared.sh` golden — a shared entrypoint library
  (`err`/`die` and the `gen_profile` login-profile generator) installed
  as `/usr/local/lib/docker-builder/entrypoint.sh` and sourced by the
  generated `entrypoint.sh` and `devcontainer.sh`, replacing the copies
  each carried

### Changed

- Entrypoint generation: `gen_entrypoint.sh` discovers
  `/etc/entrypoint.d` plugin `COPY` lines and single-sources any
  plugin with a golden copy under `docker/entrypoint/plugins/`, matching
  the existing base `entrypoint.sh` mechanism
- `10-golang`: Resolve the Go toolchain root at container start
  (a pinned `GOROOT`, else `go env GOROOT`, else scanning
  `/usr/local/go` and `/opt/golang`) instead of hardcoding
  `/usr/local/go`, so one golden copy serves both the `golang` and
  `ubuntu-nodejs-golang` images
- Entrypoint: the per-invocation `cd $CURDIR` / `exec $CMD` now runs in
  the dispatch tail instead of the sourced `Z99-docker-run.sh` profile,
  so a `docker exec` login shell into a persistent container lands at
  its own CURDIR and command instead of the values frozen at container
  start
- Login-profile generation single-sourced through `gen_profile`: the
  PATH bootstrap and `/etc/entrypoint.d` plugin sourcing live in one
  place for both the entrypoint and the devcontainer init. The
  workspace bin is added both baked (survives the `su -` environment
  reset at container start) and deferred via `${WS:-}` (covers the
  devcontainer build, where WS arrives at login via containerEnv)

### Fixed

- `docker-ubuntu-cordova-builder`: Pin `corepack` (0.33.0) and `pnpm`
  (10.34.1) to the last releases supporting the image's node 18.x,
  clearing the `EBADENGINE` warnings; drop the redundant `npx@latest`
  (bundled with npm since npm 7). The full node bump is left to the
  android/cordova refresh
- `ubuntu-vsc-base`: Fix `err()`/`die()` dropping their message —
  the non-stdin branch echoed a literal `$` instead of `$*`
- Entrypoint generation: settle an unchanged copy to its golden
  copy's mtime (`touch -r`) instead of the current time, so a content
  match no longer cascades image rebuilds
- `10-android-sdk`: Build `PATH` from `ANDROID_SDK_ROOT`, not the
  never-defined `ANDROID_SDK_PATH`, which had left a bogus
  `/cmdline-tools/latest/bin` entry
- `10-golang` (`ubuntu-nodejs-golang`): Fix the never-matching
  `[ "x$GOPATH" = ... ]` guard — the `x` prefix sat on the left
  operand only, so the workspace-`GOPATH` test always failed and
  `$GOPATH/bin` was prepended to `PATH` even when `GOPATH` was the
  workspace
- Entrypoint login `PATH` no longer accumulates duplicate entries: a
  `path_prepend` helper in the generated `Z99-docker-run.sh` skips a
  prefix already present, so overlap between the base `/opt/*/bin`
  sweep and the sourced plugins (and nested `su -`/`bash -l` logins)
  stops compounding `PATH`
- Alpine non-TTY entrypoint: resolve `su-exec` to an absolute path
  before `env -i` clears `PATH`; the default search path excludes
  `/sbin`, so a bare `su-exec` failed with exit 127 on non-interactive
  sessions
- Entrypoint: assemble the whole login profile in a temporary file and
  rename it into place in one step, instead of writing
  `Z99-docker-run.sh` onto the live file in two passes — the PATH
  bootstrap and plugin output during generation, then the sudo
  `SUDO_*` block afterwards. A nested `su -`/`bash -l` during
  generation, or a concurrent login, could otherwise source a
  half-written profile
- `docker-golang-builder`: Replace the whitelist `.dockerignore` in
  each golang image directory with a `top-level.mk` exclusion, so a
  file added to the Dockerfile `COPY` set is no longer silently
  dropped from the build context

## [1.22.1] - 2026-05-22

### Added

- `docker-ubuntu-builder`: Forward gpg-agent sockets on entry
  - New `05-gnupg.sh` snippet fixes `/run/user/$UID` ownership
    when bind-mounted from the host
  - Symlinks `S.gpg-agent*` into `~/.gnupg` so tools using
    the legacy path find them
  - Covers both `docker-builder-run` (root-time chown) and
    devcontainer (login-time re-assert via passwordless sudo)

### Changed

- Build system: Enable registry-backed inline cache for layer
  reuse across rebuilds, even when base image digests change
- `docker-golang-builder`: Update Go 1.25 to 1.25.10 and
  Go 1.26 to 1.26.3
- `docker-golang-builder`: Make Go 1.26 the default
  - Update latest symlink from 1.25 to 1.26
  - Rebase multi image on 1.26, build 1.25 inside
- `docker`: Update ubuntu-based golang images to Go 1.26.3
- `docker`: Update Node.js from 20.x/22.x to 24.x LTS
- `docker-apptly-builder`: Install chromium from the xtradeb
  PPA instead of Ubuntu's snap-based package, which doesn't
  work in containers
- `docker-micrologic-builder`: Rebase on `docker-apptly-builder`
  to inherit xtradeb chromium without losing existing tooling

### Documentation

- `AGENTS.md`: Document Go and Node.js version pinning across
  the three loading mechanisms (`FROM golang:`, source build
  loop, `ENV GO_VERSION=` tarball)

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

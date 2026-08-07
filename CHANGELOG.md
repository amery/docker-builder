# Changelog
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to docker-builder will be documented in this file.

## [Unreleased]

### Added

- `entrypoint`: Grant the workspace user passwordless `sudo` through a new
  `05-sudo.sh` plugin, which writes an `/etc/sudoers.d/$USER_NAME` rule at
  container start. These images are ephemeral developer environments — one
  workspace user, no service accounts — so the grant is unconditional
  rather than gated behind a knob. The Ubuntu bases gain the `sudo` package
  to go with it: 16.04, 20.04, 22.04, 24.04 and 26.04 shipped without the
  binary, 18.04 alone having picked it up from `unminimize`. The
  `ubuntu-vsc-*` images do not take the plugin — they carry `sudo` from
  Microsoft's `devcontainers/base`.

### Changed

- Build system: Key the per-image rebuild trigger on the `images.mk`
  generator, not the generated `images.mk`. Every image rule listed the
  generated file, so any change to its content — a new Dockerfile, an
  added `COPY` — forced all images to rebuild; depending on
  `scripts/gen_images_mk.sh` instead confines a rebuild to the trees
  whose own inputs changed, while a real build-recipe change still
  rebuilds everything.

### Fixed

- `docker-poky-builder:18.04`: Drop the inherited `10-python.sh` plugin so
  `python` stays python2. The plugin prepends a venv whose `bin/python` is
  python3 — on the Ubuntu bases, which ship no unversioned `python` at all,
  that is the only `python` there is and worth having, but this image
  installs a real python2 for the pyro-era recipes and the venv shadowed it.
  Pyro predates python3 as `python`: `python3-pycairo` bundles waf 1.6.4,
  which defines its `Node` subclass inside `Context.__init__` and patches
  only `__name__`/`__module__`, so python3.5+ — resolving by `__qualname__`
  — cannot pickle the build cache, and `do_configure` dies with `Can't
  pickle local object`. The image is the only one in the family with a
  python2 to shadow, so the removal stays here rather than in the bases. An
  existing workspace also needs its stale `$TMPDIR/hosttools/python` symlink
  deleted once: BitBake creates hosttools links only when absent and never
  refreshes them.

- Build system: Keep the local (`BUILDER=`) and publish builds in separate
  sentinels. Both wrote `.image-<name>`, so a local build left the publish
  target satisfied — `make <target>` reported `Nothing to be done` while
  the registry went on serving the old image — and a publish build did the
  same to the local one. The local build now suffixes its sentinels
  `.local`, selected by `SENTINEL_SUFFIX` alongside `WANTS_TAGS`, so
  neither mode can satisfy the other's target; a third-party image's pull
  sentinel stays shared, a pull being the same operation in both modes. The
  local build handle moves with it, to `$(cat .image-<name>.local)`. Clear
  any pre-existing `.image-*` that holds an image ID rather than being
  empty: written by an older local build, it still blocks that publish.

- `entrypoint`: Prevent gpg from autostarting a local `gpg-agent` that
  would displace a forwarded host agent. A spawned agent unlinks the
  bind-mounted `/run/user/$UID/gnupg` socket to bind its own, severing the
  forward; the `05-gnupg.sh` plugin now writes `no-autostart` to
  `/etc/gnupg/common.conf`. gnupg 2.4 reads that file, so no local agent
  starts on 24.04 or 26.04; 2.2 ignores it, and the seeded
  `~/.gnupg/gpg.conf` covers the older bases instead. It also drops the
  `~/.gnupg` socket symlinks, redundant now the forwarded socket sits at
  gpg's canonical path, where a stale link could itself trip the autostart
  they were meant to avoid.
- `ubuntu` (18.04, 20.04, 22.04): Seed `no-autostart` as the initial
  `~/.gnupg` default on the bases below the `common.conf` cutoff.
  `/etc/gnupg/common.conf` is only honoured from gnupg 2.4, so the
  system-wide write above is inert on the older releases: 20.04 (2.2.19)
  and 22.04 (2.2.27) read the file and go on autostarting a local
  `gpg-agent`, where 24.04 (2.4.4) and 26.04 (2.4.8) refuse; 18.04 ships
  2.2.4 and sits below the cutoff too. Those three now build
  `/etc/skel/.gnupg/gpg.conf`, 0700 on the directory and 0600 on the file,
  so a home created from skel starts with the option in the file gnupg does
  read. That file belongs to the user, so this is an initial default and
  nothing more — a home that already exists never sees it, which makes it
  best effort rather than a substitute for a gnupg new enough to read
  `common.conf`. Not 16.04, where gnupg 1.4 treats an unknown option as
  fatal and a seeded `gpg.conf` would break gpg outright; not the images
  that honour `common.conf` either, where a seed would duplicate the
  plugin's own setting in a file the user would then have to edit as well
  to undo it.
- `entrypoint`: Remove stale `~/.gnupg/S.gpg-agent*` symlinks that older
  images left when they bridged the forwarded sockets into the legacy path.
  A persistent home carried across an image swap keeps them, and under
  `no-autostart` a dangling link no longer self-repairs while a live one can
  redirect a launched local agent onto the forwarded socket — the kidnap
  `no-autostart` prevents. The `05-gnupg.sh` plugin now clears them at login
  via an `-L` guard that takes only symlinks, never a live socket or a
  gnupg-managed redirect file.
- `ubuntu-vsc-base`: Copy the `05-gnupg.sh` plugin into the devcontainer
  base so the gpg `no-autostart` guard reaches the VS Code and `apptly`
  images. These build on Microsoft's `devcontainers/base`, not
  `docker-ubuntu-builder`, so they never inherited the plugin the Ubuntu
  bases carry, leaving a forwarded host gpg-agent open to being displaced
  by a locally autostarted one. The devcontainer flow bakes the setting at
  image build time, and every image down the chain (`ubuntu-vsc-nodejs`,
  `-golang`, `apptly`) inherits it.
- `entrypoint`: Copy `/etc/skel` directories into a new home with their own
  mode and owner. The copy walked files alone and made their parents with a
  bare `mkdir -p`, which carries neither, so a nested entry such as
  `~/.gnupg` landed in a root-owned 0755 directory — the user locked out of
  their own keyring, and gpg refusing a homedir that permissive as unsafe.
  The file itself was chowned, so nothing showed until gpg ran. Two smaller
  gaps came from the same omission: an empty skel directory never reached
  the home at all, and only the immediate parent was created, leaving the
  levels of a deeper tree root-owned. The walk now covers directories too,
  sorted so each is in place before the entries that land in it, and
  repairs one an earlier run left wrong instead of skipping it.

## [1.25.0] - 2026-07-31

### Added

- `docker`: Add Ubuntu 26.04 across all image families (`ubuntu`,
  `poky`, `ubuntu-nodejs-golang`, `ubuntu-x11`, `apptly`, and the
  `ubuntu-vsc-*` set), each built on its parent's 26.04, with the
  `latest` tags left on 24.04. `ubuntu-vsc-base` pins Microsoft's
  `devcontainers/base` as `ubuntu26.04` — the 26.04 tag drops the
  hyphen that 24.04 uses.

### Changed

- `docker-golang-builder`: Update Go 1.25 to 1.25.12 and
  Go 1.26 to 1.26.5, moving both to `alpine3.24` (Docker Hub no longer
  ships these patches on `alpine3.22`)
- `docker`: Update ubuntu-based golang images to Go 1.26.5
- `docker-builder-run`: Forward `XDG_RUNTIME_DIR` into every container so
  it matches the `/run/user/$UID` the entrypoint's `make_runtime_dir`
  creates. Unset on the host, it is dropped and the login-time default
  stands in.
- `entrypoint`: Set and export `XDG_RUNTIME_DIR` from the login profile
  itself, not only on the gpg-forwarding path, and create `/run/user/$UID`
  on Alpine images as the Ubuntu entrypoint already did — so the forwarded
  value names a directory that exists on every image, matching the host
  inside and out.

### Fixed

- `docker-nodejs-builder`: Bump the `node` base from `alpine3.20` to
  `alpine3.24`. node stopped rebuilding the `alpine3.20` variant, leaving
  it at node 24.1.0, which the current `npm@latest` refuses to install on;
  `alpine3.24` carries node 26.5 (current) and 24.18 (lts).
- `docker-ubuntu-vsc-golang-builder` and `-vsc-nodejs-golang-builder`: Add
  the missing `docker-builder.run-env.golang` label. Without it
  `docker-builder-run` neither forwarded `GOPATH` (and `GO111MODULE`,
  `GOINSECURE`, `GOPRIVATE`) nor engaged golang run-mode, unlike
  `ubuntu-nodejs-golang`.
- `docker-apptly-builder`: Move the image from `apptly/latest` to
  `apptly/24.04` with a `latest` → `24.04` symlink, matching the
  `ubuntu-vsc-*` families, so `docker-apptly-builder:24.04` becomes a
  directory-derived tag.
- `entrypoint`: Probe `setpriv` for `--securebits`, the flag the
  ambient-capability drop actually needs, not `--ambient-caps`. busybox's
  `setpriv` supports `--ambient-caps` but not `--securebits`, so the old
  probe accepted it and the drop then aborted on `--securebits` — fatal
  even for an auto-detected capability (the golang images'
  `--cap-add SYS_PTRACE`) instead of degrading with a warning.

## [1.24.2] - 2026-07-17

### Added

- `docker-builder-run`: export `RUN_VERSION_NUM`, the runtime's own
  `RUN_VERSION` folded through `ver_to_num`, as the soft companion to
  `require_run_version`. A sourced `run-hook.sh` can gate on it inline —
  `[ "${RUN_VERSION_NUM:-0}" -ge 102401 ]` — to enable a feature when the
  runtime is new enough and degrade quietly where it is not, instead of
  aborting as `require_run_version` does. A runtime too old to export it
  leaves the guard reading 0.

### Fixed

- Ubuntu entrypoint and `ubuntu-vsc-base` devcontainer init: Create the
  XDG runtime directory `/run/user/$UID`, owned by the workspace user, so
  it is usable instead of left root-owned. On a host, logind creates it
  at login; no logind runs in the container, so init stands in as the
  session manager — the entrypoint makes it at container start, and the
  devcontainer flow, which bypasses the entrypoint, bakes it at image
  build time. A `run.sh` forwarding the host gpg-agent at
  `/run/user/$UID/gnupg` had Docker fabricate that parent root-owned
  before the entrypoint ran, leaving the directory unwritable. The
  `05-gnupg.sh` plugin, which used to fix the ownership only as a side
  effect of gpg forwarding, now keeps just its gpg-specific job
  (exporting `XDG_RUNTIME_DIR` and bridging the agent sockets).
- `poky` (24.04): Locate bitbake whether it sits inside `$OEROOT`
  (the combined poky tree) or beside it. Newer poky splits bitbake
  out of oe-core, so the hardcoded `$OEROOT/bitbake` no longer
  resolves and the login profile's `PYTHONPATH`/`PATH` point at
  nothing; the `30-poky.sh` plugin now derives `BITBAKEDIR` from
  whichever location exists and routes both through it.

## [1.24.1] - 2026-07-15

### Added

- `docker-builder-run`: define `require_run_version <version>` for a sourced
  `run-hook.sh` to demand a runtime new enough for a feature it uses, e.g.
  `require_run_version 1.24.1`. It compares the requested floor against the
  runtime's own `RUN_VERSION` through the new `ver_to_num` helper, which
  folds a dotted version into `major*100000 + minor*100 + patch` — the
  encoding dev-env's `run.sh` floor already uses. A runtime too old to define
  the function aborts the hook outright, which is the intended hard stop.

### Fixed

- `ubuntu-vsc-base` (24.04): Create the home's parent directory before
  relocating `/home/vscode` into it. A home under a path absent from the
  base image — the Windows host-path-parity home at `/C/Users/<name>` —
  made the `mv` abort with "No such file or directory"; `devcontainer.sh`
  now `mkdir -p`s the parent first, mirroring the runtime entrypoint.

## [1.24.0] - 2026-07-15

### Added

- golang entrypoint: Export `GOBIN` set to `$GOPATH/bin` and prepend
  it to `PATH`, so tools that consult `GOBIN` directly agree with
  where `go install` places binaries
- entrypoint: Pass a capability added with `docker run --cap-add`
  through to the workspace user. The drop from root is a setuid
  transition, which clears it; the entrypoint now raises the requested
  capabilities into the user's ambient set — the one set that survives
  the drop — with a `setpriv --ambient-caps` prefix on the existing
  `su`/`su-exec` drop. `USER_AMBIENT_CAPS` selects what to raise: unset
  auto-detects every capability beyond Docker's default set (whatever
  `--cap-add` added), a comma list names them explicitly, and empty,
  `none` or `-` turns it off. It needs a util-linux `setpriv`
  (Ubuntu 20.04+, so `poky:24.04`); on 16.04/18.04, which never shipped
  one, an auto-detected request warns and continues while an explicit
  one is fatal. The poky images motivate it: their `run-hook.sh`
  already adds `--cap-add SYS_ADMIN` for BitBake's network isolation,
  now elevated to the workspace user automatically
- `ubuntu-vsc-golang` and `ubuntu-vsc-nodejs-golang` (24.04): Ship
  the shared `10-golang` entrypoint plugin, so their login shells set
  up the Go environment (`PATH`, `GOPATH`, `CGO_ENABLED`) like the
  `golang` and `ubuntu-nodejs-golang` images already do

### Removed

- Drop the `Acquire::http::Pipeline-Depth "0"` workaround from all
  Ubuntu base images; it is no longer needed

### Fixed

- Write the local-build `.image-*` sentinel atomically: stage the
  `--iidfile` output as `.image-*~` and rename it into place after
  buildx returns, so the sentinel can never become visible before the
  image is fully built and loaded
- golang entrypoint: Follow the workspace when resolving `GOPATH`
  under `docker-builder-run`; the profile deferred it to login time,
  where `su -` had already stripped `WS` and `GOPATH`, so it always
  fell back to `$HOME/go`
- node entrypoint: Keep the `NPM_CONFIG_PREFIX` block when the
  profile is generated at image build time (devcontainers); an
  unguarded `$WS` killed the generator under `set -u` and silently
  dropped the block
- micrologic: Install `buf`; a stray `&&` split
  `env GOBIN=… && go install`, so the binary landed under `~/go` and
  was removed by the cleanup — the image never shipped `buf`

## [1.23.0] - 2026-06-29

### Added

- `docker-builder-run`: Skip the main execution when sourced with
  `DOCKER_BUILDER_RUN_LIB` set, so the `builder_*` helpers can be
  loaded as a library and unit-tested in isolation

### Fixed

- `docker-builder-run`: On a forced build, refresh each external base
  image by name before rebuilding. `buildx build --pull` fetched the
  new base but recorded it under its digest only, leaving the local
  `repo:tag` on the old image, so the next non-forced build kept
  rebuilding from the stale base; an explicit `docker pull` now moves
  the tag onto the new image
- `docker-builder-run`: Give a file volume a file-type cache target
  (`touch`) instead of a directory, so the daemon no longer
  pre-creates the target `root`-owned and breaks the sandboxed home
- `docker-builder-run`: Restore creation of a missing volume source,
  lost once the filter began dropping paths it could not `stat`; a
  broken symlink or an un-creatable source is now skipped with a
  warning rather than aborting the run
- Entrypoint (ubuntu): Restore job control on an interactive
  `bash -il` login. util-linux `su` (20.04+) detaches the controlling
  terminal, so the shell printed "no job control in this shell" under
  `docker -t`; it now gets `--pty` to allocate a controlling pty,
  gated on a real TTY and `su` advertising the flag. On 16.04/18.04,
  where shadow `su` lacks `--pty`, a `chroot --userspec` fallback
  drops privileges without a new session so the login shell keeps the
  pty's session. Alpine was unaffected

## [1.22.2] - 2026-06-12

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
- `docker-builder-run`: Label every container with
  `docker-builder.workspace=<workspace root>`, so a running container can
  be found by its workspace (`docker ps --filter label=…`) — the basis
  for reattaching to or shutting down a workspace's container, applied to
  ephemeral `--rm` runs too
- Entrypoint persistent-container support: `entrypoint.sh -N` runs init
  (user creation, login profile) then idles as PID 1, holding the
  container open for reattach; init also generates a
  `user-exec [-r] [-C dir] [--] [command…]` accessor at
  `/usr/local/bin/user-exec` that runs the command — arguments preserved
  as a proper argv — as the workspace user under a login shell, after
  chdir'ing to `-C` (`su -` on Ubuntu; `su-exec` for commands on Alpine,
  whose busybox `su` cannot forward arguments). `-r` (sudo mode) skips
  the drop to the workspace user instead — the command runs as root
  with the user's environment: their HOME, so the login shell sources
  their profile, plus the `SUDO_*` context, with `SUDO_COMMAND`
  reflecting each invocation. The start-time one-shot and every
  `docker exec … user-exec -C "$PWD"` reattach share it, so a reattached
  session matches a fresh run. With `docker run -d --rm` the container
  idles until `docker stop` (a `SIGTERM` trap makes it prompt) and is
  then auto-removed

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
- Entrypoint sudo mode: the `SUDO_*` context moved from the generated
  `Z99-docker-run.sh` profile into `user-exec -r`. The profile is
  sourced by every login in a persistent container, so the baked block
  — frozen at container start — would leak the sudo context into plain
  reattach sessions; exported per invocation by the accessor, each
  session carries a sudo context only when it asked for one, and a
  sudo reattach works in any container, not only one started in sudo
  mode
- Login-profile generation single-sourced through `gen_profile`: the
  PATH bootstrap and `/etc/entrypoint.d` plugin sourcing live in one
  place for both the entrypoint and the devcontainer init. The
  workspace bin is added both baked (survives the `su -` environment
  reset at container start) and deferred via `${WS:-}` (covers the
  devcontainer build, where WS arrives at login via containerEnv)
- `docker-builder-run`: `-r` no longer adds `--cap-add=SYS_ADMIN` —
  container capabilities don't depend on the invoking user. Identity
  is `user-exec`'s job; a workspace that needs extra capabilities
  grants them itself, via `run-hook.sh` appending to
  `DOCKER_EXTRA_OPTS`

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
- Entrypoint: install the login profile through a temporary file
  renamed into place (`atomic_install`), instead of writing
  `Z99-docker-run.sh` onto the live file in two passes — the PATH
  bootstrap and plugin output during generation, then the sudo
  `SUDO_*` block afterwards. A nested `su -`/`bash -l` during
  generation, or a concurrent login, could otherwise source a
  half-written profile
- `docker-golang-builder`: Replace the whitelist `.dockerignore` in
  each golang image directory with a `top-level.mk` exclusion, so a
  file added to the Dockerfile `COPY` set is no longer silently
  dropped from the build context
- Build system: `gen_images_mk.sh` took only the first token after
  `COPY` as a rebuild prerequisite, so an option flag
  (`COPY --chown=u:g src …`) was recorded as a phantom prerequisite
  and the extra sources of a multi-source `COPY` were left out of the
  image's rebuild dependencies. It now skips flags and emits every
  source. No Dockerfile in the current tree uses those forms yet, so
  generated output is unchanged — this hardens the generator against
  them
- `docker-builder-run`: Fix the volume dedup in
  `builder__filter_volumes` — it compared candidates against the
  first line of the whole multi-line match instead of the entry at
  hand, so once two volumes on the same device were known, a volume
  nested under a known base leaked through as a redundant bind mount
  instead of being absorbed by its base's mount
- `docker-builder-run`: Fix `-l` — it ran at option-parse time, before
  the image was resolved, so it died on an unbound `DOCKER_ID` unless
  one was in the environment, and when it did print it fell through
  and ran a container anyway. It now resolves (or builds) the image
  first, prints its labels and stops
- `docker-builder-run`: Match paths and label keys literally instead
  of as regex patterns: the nested-volume check (`expr`), the `$HOME`
  exclusion and the `docker_label` key lookup all over-matched on
  metachars — a known base like `a.b` silently swallowed a lookalike
  `aXb/nested` mount, dropping it from the container

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

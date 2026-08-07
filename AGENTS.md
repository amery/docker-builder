# Agent Development Guide

Technical implementation details for AI agents and developers working with
the docker-builder codebase. For general usage instructions, see
[README.md][readme-file].

**IMPORTANT**: This is the foundation project for building Docker images used
by various development environments, including [amery/dev-env][dev-env].
Changes here affect all dependent projects.

## Quick Reference

- **Build System**: GNU Make with dynamic rule generation
- **Script Directory**: `scripts/` contains build automation tools
- **Image Templates**: `docker/*/Dockerfile` defines various base images
- **Runtime Scripts**: `bin/docker-builder-run` and `bin/x`
- **Base Images**: Ubuntu, Node.js, Go, Android, Poky, and combinations

## Architecture Overview

docker-builder is a sophisticated Docker image build system that:

1. **Generates Dynamic Makefiles**: Creates build rules based on discovered
   Dockerfiles
2. **Manages Image Tags**: Tracks current and obsolete image tags
3. **Provides Runtime Scripts**: `bin/docker-builder-run` and `bin/x` for
   container execution
4. **Supports Multiple Stacks**: Ubuntu, Node.js, Go, Android, X11, VS Code

For detailed architecture internals and design patterns, see
[DESIGN.md][design-file].

### Build System Components

```text
Makefile              # Main entry point
├── config.mk        # User configuration (PREFIX)
├── rules.mk         # Generated rules for file processing
├── images.mk        # Generated image build targets
└── entrypoint.mk    # Generated entrypoint.sh + plugin copy rules

scripts/
├── gen_rules_mk.sh     # Generates rules.mk from templates
├── gen_images_mk.sh    # Generates images.mk from tag directories
├── gen_tag_dirs.sh     # Discovers and lists image directories
├── gen_entrypoint.sh   # Generates entrypoint.mk from golden copies
├── get_files.sh        # Finds files matching patterns
├── get_vars.sh         # Extracts variables from templates
├── get_aliases.sh      # Retrieves image aliases
└── filter-out-tags.sh  # Filters obsolete tags for GC

docker/entrypoint/
├── ubuntu.sh        # Canonical Ubuntu/Debian entrypoint
├── alpine.sh        # Canonical Alpine entrypoint
├── shared.sh        # Shared library sourced by both (and devcontainer.sh)
└── plugins/         # Canonical /etc/entrypoint.d plugins
```

## How the Build System Works

### 1. Discovery Phase

The build system automatically discovers Dockerfiles:

```bash
# gen_tag_dirs.sh finds all directories with Dockerfiles
find docker -name Dockerfile -type f | while read f; do
    dirname "${f#docker/}"
done
```

### 2. Rule Generation

`gen_rules_mk.sh` creates make rules for template processing:

- Extracts variables from `.in` templates
- Generates pattern rules for file generation
- Sets up dependency tracking

### 3. Image Building

`gen_images_mk.sh` creates targets for each discovered image:

- Generates `.image-<name>` and `.alias-<name>` marker files
- Creates pull targets
- Handles tag aliases and latest symlinks
- Reads each image's `FROM` line to wire base dependencies. A
  third-party base is pre-pulled so it is present locally; an own-image
  base is built first so its `FROM` reference resolves from local
  storage. This base edge belongs to the normal (publish) build, so a
  family builds in dependency order; the [local build](#local-builds)
  exception drops the edge to stay single-target, letting buildx pull
  whatever base is published.

### 4. Entrypoint Generation

`gen_entrypoint.sh` manages entrypoint.sh files from golden copies:

- Scans Dockerfiles for `COPY entrypoint.sh` commands
- Detects base image type from FROM line (Alpine vs Ubuntu)
- Also discovers `COPY <name> /etc/entrypoint.d/...` lines and, for any
  with a golden copy under `docker/entrypoint/plugins/`, generates the
  per-image copy from it so the plugin is single-sourced too; plugins
  without one stay hand-maintained
- Also generates the per-image copy of the shared library
  `docker/entrypoint/shared.sh` (installed as
  `/usr/local/lib/docker-builder/entrypoint.sh`) for every image that
  copies an entrypoint, so the `err`/`die` helpers and the login-profile
  generator are single-sourced too
- Generates entrypoint.mk with dependency rules
- Copies canonical sources to image directories when they change
- Uses `cmp` to detect changes; on a content match it settles the copy
  to the golden copy's mtime (`touch -r`) so the rule does not re-fire

Golden copies at `docker/entrypoint/{ubuntu.sh,alpine.sh}` serve as the
single source of truth for all base images, `docker/entrypoint/shared.sh`
for the library they source (installed as
`/usr/local/lib/docker-builder/entrypoint.sh`), and those under
`docker/entrypoint/plugins/` for the shared `/etc/entrypoint.d` plugins.

### 5. Tag Management

The system tracks image tags across three files:

- `.tags-current`: Currently built tags
- `.tags-all`: All tags in local Docker
- `.tags-obsolete`: Tags to be garbage collected

## Build System Mechanics

Understanding the build system's caching behavior is critical for efficient
development and troubleshooting stuck builds.

### Two-Level Caching

The build system employs two independent caching layers:

#### 1. Make Layer (Marker Files)

- **Files**: `.image-*` (build) and `.alias-*` (tag) markers
- **Purpose**: Track build and alias completion separately
- **Behavior**: If marker exists and deps unchanged, skip (see
  [What Triggers a Rebuild](#what-triggers-a-rebuild))
- **Control**: Delete the marker of the image concerned, or `make clean`
  to clear the whole layer (see
  [Build Control Options](#build-control-options))

#### 2. Docker Layer (Build Cache)

- **Files**: Docker's internal layer cache
- **Purpose**: Reuse unchanged layers during docker build
- **Behavior**: Each Dockerfile instruction creates a cached layer
- **Control**: Use `FORCE=1` variable (adds `--no-cache` flag)

### Build Control Options

| Command | Make Cache | Docker Cache | Use When |
| ------- | ---------- | ------------ | -------- |
| `make <target>` | ✓ Used | ✓ Used | Normal incremental builds |
| `make FORCE=1 <target>` | ✓ Used | ✗ Bypassed | Refresh base images or upstream packages |
| `rm .image-<name>`, then `make <target>` | ✗ Bypassed, that image and its descendants | ✓ Used | One image's marker is wrong |
| `make clean`, then `make` | ✗ Bypassed, all | ✓ Used | Rebuild everything |
| `make clean`, then `make FORCE=1` | ✗ Bypassed, all | ✗ Bypassed | Complete clean rebuild from scratch |

Clearing the make layer means removing markers, not forcing targets. **Do
not use `-B`**: it treats every prerequisite as out of date, so it drags
in far more than the target named — for an image whose base is an own
image, the base is rebuilt and **pushed** too:

```text
$ make -n -B quay.io/amery/docker-poky-builder-24.04
…
docker buildx build … --push … -t quay.io/amery/docker-ubuntu-builder:24.04 …
…
docker buildx build … --push … -t quay.io/amery/docker-poky-builder:24.04 …
```

`make clean` is the honest way to rebuild everything: it removes the
markers and the generated makefiles, then leaves normal dependency
resolution to decide what is built. Mind what that costs. The makefiles
regenerate for free, but a marker only comes back by rebuilding, and in
the normal mode every rebuild pushes — so the next full `make`
re-publishes all of them, Docker's layer cache sparing the build work
but not the push. Remove one image's marker, or a family's, when that
is what you mean.

### What Triggers a Rebuild

An image's `.image-<name>` marker is remade when any of three
prerequisite tiers is newer than it — this is the whole of the
make-layer rebuild logic:

1. **The image's own inputs.** Each image rule lists its `Dockerfile`
   and every file the Dockerfile `COPY`s — the entrypoint, the shared
   library, `builder_version.sh`, and each `/etc/entrypoint.d` plugin —
   as explicit prerequisites, so editing any of them rebuilds that image
   alone. The plugin and library prerequisites are the generated
   per-image copies, so a change to a golden source under
   `docker/entrypoint/` propagates through the copy to every image that
   carries it (see [Entrypoint Generation](#4-entrypoint-generation)).

2. **The base image.** `gen_images_mk.sh` reads each `FROM` line and,
   for an own-image base, wires `.image-<image>` to depend on
   `.image-<base>`, so rebuilding a base cascades to every descendant.
   This edge belongs to the publish build only; a
   [local build](#local-builds) drops it to stay single-target. A
   third-party base (`ubuntu:24.04`, Microsoft's `devcontainers/base`)
   is a leaf — nothing local rebuilds when it moves, and `FORCE=1`
   re-pulls it.

3. **The build system.** Every image rule also depends on `BUILD_SYS` —
   `Makefile`, `config.mk`, and `scripts/gen_images_mk.sh` — so a change
   to the build recipe or global configuration rebuilds everything. It
   keys on the `images.mk` generator, not the generated `images.mk`:
   regenerating the rule set for a new Dockerfile or an added `COPY` no
   longer forces a global rebuild (that lands through tier 1, on the
   affected image), while a genuine recipe change still sweeps the whole
   tree.

Docker's layer cache then decides how much of each triggered build
actually re-runs (see [Docker Layer](#2-docker-layer-build-cache)): an
image whose base digest is unchanged is largely a cache hit even when
its marker was invalidated.

### Multi-Architecture Builds

This is the normal build mode: every build produces a
multi-architecture manifest (amd64 + arm64) and pushes it to the
registry, which requires a `multiarch-native` buildx builder with
native nodes for each architecture, and registry authentication. While
developing an image you can opt out of both with the [Local
Builds](#local-builds) exception; that exception leaves this mode
untouched.

#### Prerequisites

1. **Registry login**: `docker login quay.io`
2. **Multi-arch builder**: See
   [SSH Remote Builders](#using-ssh-remote-builders-for-native-builds)

#### Build Variables

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `BUILDER` | `multiarch-native` | Buildx builder name; empty selects [local builds](#local-builds) |
| `DOCKER` | `docker` | Docker command override |

#### Prerequisites for Cross-Platform Builds

Cross-platform builds (e.g., building arm64 on an amd64 host)
require additional setup beyond the default Docker installation.

**1. Create a multi-platform builder:**

The default Docker builder doesn't support cross-platform builds.
Create one with the `docker-container` driver:

```bash
docker buildx create --name multiarch \
    --driver docker-container \
    --driver-opt "network=host" \
    --bootstrap --use
```

**2. Install QEMU emulation (for cross-arch):**

To build for architectures other than your host
(e.g., arm64 on amd64):

```bash
docker run --privileged --rm \
    tonistiigi/binfmt --install arm64
```

After installing QEMU, recreate the builder to pick up
the new platforms:

```bash
docker buildx rm multiarch
docker buildx create --name multiarch \
    --driver docker-container \
    --driver-opt "network=host" \
    --bootstrap --use
```

**3. Verify platform support:**

```bash
docker buildx inspect --bootstrap | grep Platforms
# Should show: linux/amd64, linux/arm64, ...
```

#### Using SSH Remote Builders for Native Builds

QEMU emulation can be 8x slower than native builds. For better performance, use
a remote arm64 machine via SSH.

**1. Configure SSH on the remote arm64 host:**

Ensure passwordless SSH access works, then enable user environment in
`/etc/ssh/sshd_config`:

```text
PermitUserEnvironment yes
```

Create `~/.ssh/environment` on the remote host:

```text
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
```

Restart sshd and verify Docker is accessible:

```bash
docker -H ssh://user@arm64-host info
```

**2. Create a multi-node builder with SSH:**

```bash
# Create builder with docker-container driver
docker buildx create --name multiarch-native \
    --driver docker-container \
    --driver-opt "network=host" \
    --platform linux/amd64

# Append remote arm64 node via SSH
docker buildx create \
    --name multiarch-native --append \
    --driver-opt "network=host" \
    --platform linux/arm64 \
    ssh://user@arm64-host

# Activate and verify
docker buildx use multiarch-native
docker buildx inspect --bootstrap
```

**3. Build using native nodes:**

```bash
make quay.io/amery/docker-ubuntu-builder-24.04
```

Buildx routes each platform to the appropriate node
and merges the manifest.

#### Why `network=host`

The `docker-container` driver uses bridge networking by
default. This causes intermittent HTTP 400 errors during
`apt-get` operations, particularly `unminimize`. The root
cause is APT's HTTP pipelining interacting badly with the
bridge NAT layer.

Running the builder with `--driver-opt "network=host"`
bypasses bridge networking.

#### Per-Image Architecture Exclusions

Some Dockerfiles cannot build for all architectures
(e.g., hardcoded amd64 paths or amd64-only downloads).
These opt out with a directive comment:

```dockerfile
# build: !arm64
```

The generator computes a per-image `PLATFORM` value,
filtering out excluded architectures.

Multiple exclusions are supported:

```dockerfile
# build: !arm64 !s390x
```

### Local Builds

Local builds are the **exception** to the normal multi-architecture
push above — a development convenience for verifying a change builds
and runs before committing it. They leave the normal mode untouched.

Set an empty `BUILDER`:

```bash
make BUILDER= quay.io/amery/docker-ubuntu-builder-24.04
```

This builds for the host architecture alone and loads the image into
the local daemon with `--load`, skipping the registry entirely: no
push, no inline cache, and no alias retagging. The build is
single-target — it does **not** rebuild base images, letting buildx
pull whatever base is published. The image is loaded **untagged**; its
ID is written into the `.image-*.local` marker via `--iidfile`, which
doubles as the run handle. Pass that ID to `docker-builder-run` (a bare
`docker run` fails — the entrypoint needs the `USER_NAME`/`USER_UID`/…
environment that `docker-builder-run` sets up):

```bash
DOCKER_ID="$(cat .image-docker-ubuntu-builder-24.04.local)" docker-builder-run bash
```

Because a local build leaves no persistent tag, the image is dangling
and `docker image prune` reclaims it; dev builds stay ephemeral by
construction. Alias-only targets (e.g. `latest`) skip their retag in
this mode, since there is no tag to copy; building one still builds the
concrete version it points to.

The mode is driven by the generated `WANTS_TAGS` flag: an empty
`BUILDER` clears it, so the recipes take the `--load`/`--iidfile`
branch and drop the base-image prerequisites; any builder sets it and
the recipes push, retag, and build bases first exactly as before.

It also selects `SENTINEL_SUFFIX`, `.local` here and empty for a
publish build, so the two modes keep separate markers and neither can
satisfy the other's target. They record different things — an image ID
in the local daemon against a manifest pushed to the registry — so a
shared marker would let a local build leave the publish target looking
done. Both keep the `.image-*`/`.alias-*` prefixes, so `make clean` and
`.gitignore` cover them unchanged.

### Target Types: Version-Specific vs Aggregate

The build system generates two types of targets for each image:

#### Version-Specific Targets

Build a single image from one Dockerfile:

```bash
make quay.io/amery/docker-golang-builder-1.25    # Just golang 1.25
make quay.io/amery/docker-ubuntu-builder-24.04   # Just ubuntu 24.04
```

#### Aggregate Targets

Build all versions of an image family:

```bash
make quay.io/amery/docker-golang-builder    # ALL golang versions
# Builds: 1.18, 1.19, 1.20, 1.21, 1.22, 1.23, 1.24, 1.25, 1.26, latest, multi

make quay.io/amery/docker-ubuntu-builder    # ALL ubuntu versions
# Builds: 16.04, 18.04, 20.04, 22.04, 24.04, latest
```

#### When to Use Each

- **Version-specific**: Changed one Dockerfile, want to rebuild just that
  image
- **Aggregate**: Base image changed, need to rebuild entire image family

#### How to Identify

```text
docker/<name>/<version>/  → quay.io/amery/docker-<name>-builder-<version>
                          ↓
                          quay.io/amery/docker-<name>-builder (aggregate)
```

### Common Scenarios

#### Scenario: Changed a Dockerfile

```bash
# Changed docker/golang/1.25/Dockerfile - rebuild just that version
make quay.io/amery/docker-golang-builder-1.25
```

#### Scenario: Make thinks it's built but it hasn't

```bash
# Marker file exists but the image was deleted
rm .image-docker-ubuntu-builder-24.04
make quay.io/amery/docker-ubuntu-builder-24.04

# ... or the whole family, clearing its markers together
rm .image-docker-ubuntu-builder-*
make quay.io/amery/docker-ubuntu-builder
```

#### Scenario: Completely stuck build state

```bash
# Nuclear option: clear that family's markers, then bypass the Docker
# cache too
rm .image-docker-golang-builder-*
make FORCE=1 quay.io/amery/docker-golang-builder
```

#### Scenario: Just regenerate rules

```bash
# Added new Dockerfile, need rules.mk/images.mk regenerated
make files
```

### Marker File Lifecycle

Marker files prevent redundant builds:

```bash
# Building creates markers
make quay.io/amery/docker-ubuntu-builder-24.04
# Creates: .image-docker-ubuntu-builder-24.04
#          .alias-docker-ubuntu-builder-24.04

# Subsequent call skips build
make quay.io/amery/docker-ubuntu-builder-24.04
# Output: make: Nothing to be done for '...'

# Rebuild by removing the marker. The alias marker depends on it, so it
# follows on its own and needs no separate removal.
rm .image-docker-ubuntu-builder-24.04
make quay.io/amery/docker-ubuntu-builder-24.04
# Rebuilds and re-aliases
```

These markers are empty: they record only that the build and the retag
happened. A [local build](#local-builds) keeps a separate set, suffixed
`.local`.

### Target Name Patterns

Understanding target naming helps navigate the build system:

#### Directory Structure to Target Names

```text
docker/<name>/<version>/Dockerfile
    ↓
quay.io/amery/docker-<name>-builder             # All versions
quay.io/amery/docker-<name>-builder-<version>   # Specific
pull-docker-<name>-builder                      # Pull all
pull-docker-<name>-builder-<version>            # Pull specific
```

#### Examples

```bash
docker/ubuntu/24.04/Dockerfile
    → quay.io/amery/docker-ubuntu-builder-24.04

docker/ubuntu/latest → 24.04 (symlink)
    → quay.io/amery/docker-ubuntu-builder-latest
```

#### Symlink Handling

Symlinked version directories (e.g., `latest → 24.04`) create tagging targets,
not build targets:

```bash
# Directory structure
docker/ubuntu/24.04/Dockerfile    # Real directory with Dockerfile
docker/ubuntu/latest → 24.04      # Symlink to directory

# Generated targets
make quay.io/amery/docker-ubuntu-builder-24.04    # Builds from Dockerfile
make quay.io/amery/docker-ubuntu-builder-latest   # Tags 24.04 as :latest
```

The `latest` target does not build anything — it depends on the
real version's alias sentinel, then creates a registry-side tag:

<!-- markdownlint-disable MD010 -->

```makefile
# Generated rule for symlink
.image-docker-ubuntu-builder-latest: .alias-docker-ubuntu-builder-24.04
ifeq ($(WANTS_TAGS),1)
	$(DOCKER_TAG) -t $(PREFIX)docker-ubuntu-builder:latest \
	              $(PREFIX)docker-ubuntu-builder:24.04
endif
	touch $@

.alias-docker-ubuntu-builder-latest: .image-docker-ubuntu-builder-latest
	touch $@
```

In a [local build](#local-builds) (`WANTS_TAGS` empty) the retag is
skipped and the rule collapses to `touch $@`.

<!-- markdownlint-enable MD010 -->

### Makefile Generation

The build system generates makefiles dynamically:

#### Generation Triggers

1. **rules.mk**: Regenerates when templates change

   ```bash
   scripts/gen_rules_mk.sh > rules.mk
   ```

2. **images.mk**: Always regenerates, updates only when content changes

   ```bash
   scripts/gen_images_mk.sh > images.mk
   ```

3. **entrypoint.mk**: Regenerates when Dockerfiles change

   ```bash
   scripts/gen_entrypoint.sh > entrypoint.mk
   ```

4. **.tag-dirs**: Always checks for new directories

   ```bash
   scripts/gen_tag_dirs.sh > .tag-dirs
   ```

#### Force Regeneration

```bash
make files              # Regenerate all makefiles and entrypoint.sh
make entrypoint         # Regenerate just entrypoint.sh files
make clean              # Remove markers and generated files
```

### Debugging Build Issues

#### Check what would be built

```bash
cat .tag-dirs           # List discovered image directories
cat images.mk | grep docker-ubuntu-builder  # Find specific targets
```

#### Verify marker state

```bash
ls -la .image-* .alias-*  # List all marker files
make -n <target>        # Dry run, show what would execute
```

#### Complete rebuild

```bash
make clean              # Remove markers and generated makefiles
make FORCE=1            # Build everything from scratch
```

#### Check Docker build arguments

```bash
# Default build (multi-arch, pushed to registry)
make <target>
# Uses: docker buildx build --builder multiarch-native --push
#        --progress=plain --platform linux/amd64,linux/arm64

# With FORCE=1 (bypass Docker cache)
make FORCE=1 <target>
# Uses: docker buildx build --builder multiarch-native --push
#        --progress=plain --no-cache
#        --platform linux/amd64,linux/arm64

# Local build (single-arch, loaded untagged, not pushed)
make BUILDER= <target>
# Uses: docker buildx build --progress=plain --load
#        --iidfile .image-<name>.local~
# then renames .image-<name>.local~ into .image-<name>.local, so the
# marker only appears once the image is fully built and loaded
```

## Docker Images Provided

### Base Images

- **ubuntu/{16.04,18.04,20.04,22.04,24.04,26.04}**: Base Ubuntu images with
  builder_version.sh
- **ubuntu-x11/{20.04,22.04,24.04,26.04}**: Ubuntu with X11 forwarding support
- **ubuntu-vsc-base/{24.04,26.04}**: VS Code DevContainer base

### Development Stacks

- **golang/{1.18-1.26}**: Go development environments
- **nodejs/{lts,current}**: Node.js with pnpm support
- **ubuntu-nodejs-golang/{22.04,24.04,26.04}**: Combined Node.js + Go

### Specialized Images

- **android/11**: Android SDK development
- **ubuntu-android-studio**: Android Studio with SDK
- **poky/{18.04,24.04,26.04}**: Yocto/OE builds (latest→24.04)
- **poky-nodejs-golang/26.04**: Yocto/OE with Node.js and Go (latest→26.04)
- **apptly/{24.04,26.04}**: Apptly development base (latest→24.04)

### VS Code DevContainer Images

- **ubuntu-vsc-golang/{24.04,26.04}**: Go development in VS Code
- **ubuntu-vsc-nodejs/{24.04,26.04}**: Node.js development in VS Code
- **ubuntu-vsc-nodejs-golang/{24.04,26.04}**: Combined stack for VS Code

## The `docker-builder-run` Script

Located at `bin/docker-builder-run`, this script provides intelligent container
execution:

### `docker-builder-run` Key Features

1. **Workspace Detection**: Finds workspace root via `.repo` or `.git`
2. **Volume Management**: Intelligently mounts required directories
3. **Environment Preservation**: Passes through necessary variables
4. **Mode Detection**: Configures for Go, Node.js, or X11 as needed
5. **User Identity**: Preserves UID/GID in container
6. **Template Updates**: Automatically updates `run-hook.sh` from images

### Automatic `run-hook.sh` Updates

Some images (e.g., `docker-poky-builder`) embed `run-hook.sh` at
`/usr/local/share/docker-builder/run-hook.sh` with a
`docker-builder.run-hook.sha256` label.

`docker-builder-run` compares the label's SHA256 with
`$DOCKER_DIR/run-hook.sh` and automatically updates on mismatch.

**Warning:** Local modifications are overwritten.

**To disable autoupdate** in workspace Dockerfile:

```dockerfile
LABEL docker-builder.run-hook.sha256="-"
```

Or use: `""`, `"disabled"`

**Manual extraction** (for offline deployment):

```bash
docker run --rm IMAGE --run-hook > docker/run-hook.sh
```

### Environment Variables

- `DOCKER_DIR`: Directory containing Dockerfile to build
- `DOCKER_ID`: Pre-built image ID to use instead
- `DOCKER_BUILD_FORCE`: Force rebuild/repull
- `DOCKER_RUN_ENV`: Variables to pass through
- `DOCKER_RUN_VOLUMES`: Extra directories or files to mount
- `DOCKER_RUN_WS`: Override workspace detection
- `DOCKER_BUILD_OPT`: Extra `docker build` args (default: `--rm`)
- `DOCKER_EXTRA_OPTS`: Raw Docker flags (capabilities, devices,
  security options) — typically set in `run-hook.sh`, not `run.sh`
- `DOCKER_EXPOSE`: Ports to expose
- `USER_AMBIENT_CAPS`: Capabilities to elevate into the workspace user's
  ambient set (see [Capability Passthrough](#capability-passthrough)).
  Forwarded to the entrypoint only when set; left unset it selects
  auto-detection inside the container

Not a runtime knob: `DOCKER_BUILDER_RUN_LIB` is a testing-only switch.
With it set, sourcing the script defines its `builder_*` helpers then
stops before the main execution, so tests can call them as a library (see
[Shell Scripts](#shell-scripts)). Leave it unset for normal runs.

### `docker-builder-run` Usage Examples

```bash
# Run with automatic detection
docker-builder-run make build

# Force rebuild
DOCKER_BUILD_FORCE=true docker-builder-run

# With custom volumes
DOCKER_RUN_VOLUMES="/data" docker-builder-run

# Expose ports
docker-builder-run -p 8080 npm start
```

### Capability Passthrough

A capability added to the container with `docker run --cap-add` lands in
the effective set of the root entrypoint, but the drop from root to the
workspace user is a setuid transition, which clears it — so the user's
command never sees it. The entrypoint bridges that gap by raising the
requested capabilities into the user's **ambient** set, the one set that
survives the drop.

`USER_AMBIENT_CAPS` selects which capabilities to raise:

| Value | Behaviour |
| ----- | --------- |
| unset | Auto-detect — every capability in the bounding set beyond Docker's default set (i.e. whatever `--cap-add` added) |
| `"sys_admin,net_admin"` | Exactly those; comma-separated, the `CAP_` prefix optional |
| empty / `none` / `-` | Off — no passthrough |

A requested capability that is not in the container's bounding set is
skipped with a warning (the entrypoint raises what is grantable). The
sudo path (`USER_IS_SUDO`) stays root and already holds the container's
capabilities, so it needs none of this.

The mechanism is a `setpriv` prefix on the drop, which keeps the existing
`su`/`su-exec` login handling intact. It needs a `setpriv` that supports
`--securebits`, used to set the `no_setuid_fixup` securebit that carries
the ambient caps through the setuid drop. Ubuntu 20.04+ ships one (so
`poky:24.04`); 16.04/18.04 ship no `setpriv` at all, and busybox's
`setpriv` (the Alpine golang and nodejs images) supports `--ambient-caps`
but not `--securebits`. Where a capable `setpriv` is missing the request
degrades: an auto-detected one warns and the container continues without
it, an explicit one is fatal. This is harmless for the legacy images —
`poky:18.04` is the pyro-era stack, which predates the BitBake network
isolation that wants the capability.

The poky images are the motivating case: their `run-hook.sh` adds
`--cap-add SYS_ADMIN` for BitBake's user-namespace network isolation, and
auto-detection then elevates it to the workspace user with no further
configuration.

### GPG Agent Forwarding

A `run.sh` can forward the host's gpg-agent by bind-mounting the host's
`$XDG_RUNTIME_DIR/gnupg` into the container at the same path;
`docker-builder-run` forwards `XDG_RUNTIME_DIR` itself so host and
container agree on it. The entrypoint's `make_runtime_dir` takes ownership
of `/run/user/$UID` so the forwarded socket is usable, and on a modern
gnupg the agent socket already sits at gpg's canonical `agent-socket` path,
so gpg reaches the forwarded agent unaided.

The hazard is a local gpg-agent: a gpg operation that finds the forwarded
agent momentarily unreachable autostarts its own, which unlinks the
bind-mounted socket to bind a fresh one — severing the forward and holding
none of the host's keys. The `05-gnupg.sh` plugin writes `no-autostart` to
`/etc/gnupg/common.conf` against this. How far it reaches depends on the
release's gnupg, measured on the published images:

- **2.4** (24.04, 26.04) reads `common.conf`, so the setting holds and no
  local agent is spawned. It also blocks `gpgconf --launch gpg-agent`,
  which returns success and starts nothing — a container that wants a local
  agent has to drop the setting rather than launch around it.
- **2.2** reads `common.conf` and ignores it — measured on 20.04 (2.2.19)
  and 22.04 (2.2.27), with 18.04 (2.2.4) below the same cutoff. The option
  itself works on 2.2, but only from `~/.gnupg/gpg.conf`, so the plugin's
  write leaves these bases uncovered; the `ubuntu` images seed it into
  `/etc/skel/.gnupg/gpg.conf` instead, which a home created from skel picks
  up and an existing one never sees.
- **1.4** (16.04) has no agent at all, so there is nothing to displace, and
  it never reads `common.conf`, which makes the plugin's write inert rather
  than harmful. `no-autostart` is unknown to 1.4 and fatal in a file it does
  read, so nothing is seeded into `~/.gnupg` there.

The plugin body runs as root wherever the login profile is
generated — container start for the entrypoint flow, image build for the
devcontainer flow — so both flows carry the setting, and its stdout (which
becomes the profile) stays empty: the config is a pure root side-effect.

## The `x` Script

Located at `bin/x`, this script provides workspace-aware command
execution by automatically locating and invoking `run.sh`.

### `x` Script Key Features

1. **Workspace Detection**: Finds workspace root via `.repo` or `.git`
2. **Script Discovery**: Locates executable `run.sh` in workspace
3. **Transparent Execution**: Passes commands through to `run.sh`
4. **Fallback Mode**: Executes directly if no `run.sh` found

### Workspace Detection Algorithm

The script searches for `run.sh` using a multi-step approach:

1. **Repo Tool Workspaces**: Searches for `.repo` directory via
   brute-force parent directory traversal
2. **Git Workspace**: If no `.repo` found, tries:
   - `git rev-parse --show-superproject-working-tree` for submodules
   - `git rev-parse --show-toplevel` for regular repositories
3. **Brute Force**: If no VCS found, searches parent directories for
   executable `run.sh`

Once workspace root is found, checks for executable `run.sh` at that
location. If not found, searches parent directories iteratively.

### `x` Script Usage Examples

#### Basic Usage

```bash
# Execute command via run.sh
x make build
x go test ./...

# Works from any subdirectory
cd src/myproject
x make  # Still finds workspace root run.sh

# Find workspace root (see Workspace Detection Algorithm)
x --root

# Fallback: pass through if no run.sh
x echo "hello"
```

#### Options

**`-C <directory>`**

Changes to the specified directory before workspace detection begins. This
enables operating on workspaces without physically navigating to them.

- Requires exactly one argument (the directory path)
- Directory must exist and be accessible
- Accepts both relative and absolute paths
- Can be combined with `--root` in any order

**`--root`**

Outputs the workspace root directory path instead of executing commands.

**`--`**

Stops option parsing; remaining arguments are passed through as-is.

**Examples:**

```bash
# Run commands in a different workspace
x -C /path/to/workspace make build

# Options can be in any order
x --root -C /path/to/workspace
x -C /path/to/workspace --root

# Use -- to pass options to the command
x -C /path/to/workspace -- command --root

# Operate on multiple workspaces from a script
for ws in ~/projects/*/; do
    x -C "$ws" make test
done

# Relative paths work too
x -C ../other-workspace make build
```

**Common use cases:**

- Build automation scripts managing multiple workspaces
- CI/CD pipelines operating on different project directories
- Makefiles that need to invoke commands in sibling projects

### Integration Pattern

The `x` script is designed to work with project-specific `run.sh`
wrappers that invoke `docker-builder-run`:

```text
x command args
    ↓
run.sh command args
    ↓
docker-builder-run command args
    ↓
container execution
```

This pattern enables:

- **Script Portability**: Scripts never include `x`, work both in
  containers and via `x` from host
- **Directory Preservation**: Current directory is maintained through
  the execution chain
- **Workspace Consistency**: Always executes from correct workspace
  context

## Integration with dev-env

The `amery/dev-env` project depends on docker-builder:

1. **Base Image**: Uses `quay.io/amery/docker-apptly-builder:latest`
2. **Runtime Scripts**: Uses both `bin/docker-builder-run` and `bin/x`
3. **DevContainer**: Extends the VS Code base images

When updating docker-builder:

- Changes to `ubuntu-vsc-base` affect all VS Code environments
- Updates to `bin/docker-builder-run` or `bin/x` impact execution
- New environment variables need coordination with dev-env

## Development Workflow

### Adding a New Image

1. Create directory structure:

   ```bash
   mkdir -p docker/myimage/latest
   ```

2. Add Dockerfile:

   ```dockerfile
   FROM ubuntu:24.04
   # Your customizations
   COPY entrypoint.sh /entrypoint.sh  # If base image
   ENTRYPOINT ["/entrypoint.sh"]
   ```

   **Note:** If creating a base image (not extending an existing
   docker-builder image), include `COPY entrypoint.sh /entrypoint.sh` in
   the Dockerfile. The entrypoint.sh file will be automatically generated
   from canonical sources when you run `make files` or `make entrypoint`.

3. Run make to generate rules:

   ```bash
   make files
   ```

   This regenerates the makefiles, so the new image is discovered. The
   generated copies its Dockerfile needs — `entrypoint.sh` from the golden
   matching the `FROM` line, and each `/etc/entrypoint.d` plugin that has a
   golden copy — are written by `make entrypoint`, and by the build itself,
   which lists them as prerequisites.

4. Build the image:

   ```bash
   make
   ```

### Updating Existing Images

1. Modify the Dockerfile
2. Rebuild:

   ```bash
   make <target>
   ```

### Garbage Collection

Remove obsolete tags:

```bash
make tags-gc
```

## Build Targets Reference

### Image-Specific Targets

For each image (e.g., `poky`), the following targets
are available:

```bash
# Build and push to registry
make quay.io/amery/docker-poky-builder

# Pull from registry
make pull-docker-poky-builder
```

### Global Targets

```bash
# Build all images
make

# Pull all images
make pull

# Clean obsolete tags
make tags-gc

# Regenerate build files
make files
```

## Updating Toolchain Versions

Go and Node.js versions are pinned in multiple places using three
different mechanisms. Patch bumps must touch every relevant pin.

### Go

| Location | Mechanism | What to change |
| -------- | --------- | -------------- |
| `docker/golang/<X.Y>/Dockerfile` | Upstream `golang:X.Y.Z-alpine` base image | `FROM` tag |
| `docker/golang/multi/Dockerfile` | Builds older Go versions from source, bootstrapped from the `FROM docker-golang-builder:<latest>` image | The version strings in the `for GO_VERSION in …` loop (the current series comes via `FROM` and does not appear in the loop) |
| `docker/*-golang/*/Dockerfile` | Downloads `https://golang.org/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz` to `/opt/golang` | `ENV GO_VERSION=X.Y.Z` |

For a single-series patch bump, grep for the old version:

```bash
grep -RlE "1\.26\.[0-9]+" docker/
```

Edit every match; symlinked `latest` directories share the file with
their target version and do not need a separate edit.

### Node.js

Node.js is pinned to a NodeSource major (e.g. `24.x`) via
`ENV NODE_VERSION=` in every image that installs from NodeSource —
`ubuntu-nodejs-golang`, `ubuntu-vsc-nodejs`, `poky-nodejs-golang` and
`ubuntu-cordova`. Patch and minor releases flow in automatically on
rebuild; only major-version moves require editing these files, so list
them rather than trusting the set above to stay current:

```bash
grep -rl 'ENV NODE_VERSION' docker/
```

## Managing Python Dependencies

When building images with Python tools, special care is needed to avoid
version conflicts:

### Common Issues

1. **System vs pip packages conflict**: Ubuntu's apt packages may conflict
   with pip-installed versions
2. **API changes**: Tools may break when dependencies update (e.g.,
   protobuf removing RegisterExtension)
3. **Path issues**: Python modules installed in unexpected locations
4. **The interpreter moves with the release**: each Ubuntu carries its own
   Python — 3.12 on 24.04, 3.14 on 26.04 — so a path or a wheel that suited
   one base does not survive the next

### Solution: Virtual Environments

Give each tool a venv of its own; never install into the system
interpreter. What that venv is allowed to see is the second decision:

- **Isolated** (`python3 -m venv`) for pure-Python dependencies, which
  install anywhere.
- **Inheriting** (`python3 -m venv --system-site-packages`) where a
  dependency carries a compiled extension. A wheel is built for the
  interpreters that existed when it was published, so on a newer base it
  either has no wheel at all or installs one the running Python refuses to
  load — and pinning an older release gets the same wheel. apt's build
  always matches the interpreter beside it.

```dockerfile
# Define environment variables for paths
ENV TOOL_VERSION=1.2.3
ENV TOOL_VENV=/opt/tool-env

# Create venv and install dependencies
RUN python3 -m venv $TOOL_VENV \
    && $TOOL_VENV/bin/pip install --no-cache-dir \
        "package==1.2.3" \
        "dependency<2.0"

# Update script shebangs
RUN sed -i "1s|^#!/usr/bin/env python3|#!$TOOL_VENV/bin/python3|" \
    /usr/bin/tool-script

# Add to PATH
RUN echo "export PATH=\"$TOOL_VENV/bin:\$PATH\"" >> /etc/profile.d/tool.sh
```

Ask the interpreter where things go rather than writing the path out. A
`python3.12` inside a Dockerfile is a version pin nothing declares:

```dockerfile
RUN site_packages="$($TOOL_VENV/bin/python3 -c \
        'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
```

### Real-World Example: nanopb

nanopb needs protobuf below 5, and that is exactly where pinning stops
working: protobuf 5 and later break its extension handling, while the last
4.x on PyPI loads a upb extension a new interpreter rejects. Both pins are
dead ends, so protobuf and protoc come from apt and the venv holds nanopb
alone:

```dockerfile
ENV NANOPB_VERSION=0.4.9.1
ENV NANOPB_VENV=/opt/nanopb-env

RUN apt-get install -y --no-install-recommends \
        protobuf-compiler \
        python3-protobuf \
        python3-grpc-tools

RUN python3 -m venv --system-site-packages $NANOPB_VENV \
    && site_packages="$($NANOPB_VENV/bin/python3 -c \
        'import sysconfig; print(sysconfig.get_paths()["purelib"])')" \
    && git clone -b $NANOPB_VERSION --depth 1 \
        https://github.com/nanopb/nanopb /usr/src/nanopb \
    && cd /usr/src/nanopb \
    && cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DPython_EXECUTABLE=$NANOPB_VENV/bin/python3 \
        -Dnanopb_PYTHON_INSTDIR_OVERRIDE="$site_packages" \
        . \
    && make && make install
```

### Second Example: the clang bindings

A binding that dlopens a bare soname needs the distro's package for a
different reason. `clang.cindex` loads `libclang.so`, and Ubuntu ships only
`libclang-NN.so`, so the PyPI `clang` release imports cleanly and then
raises `LibclangError` at the first header parsed — a failure that surfaces
during a documentation build rather than at image build time.
`python3-clang` asks for the versioned name and matches the libclang built
beside it:

```dockerfile
RUN apt-get install -y --no-install-recommends python3-clang \
    && python3 -m venv --system-site-packages /opt/sphinx-env \
    && /opt/sphinx-env/bin/pip install --no-cache-dir "hawkmoth~=0.16.0"
```

## Code Quality Standards

### Shell Scripts

- Use `set -eu` for error handling
- Follow POSIX sh compatibility
- Add descriptive comments for complex logic
- Test with shellcheck before committing
- Unit-test the `builder_*` helpers by sourcing the script as a library:
  `DOCKER_BUILDER_RUN_LIB=1 . bin/docker-builder-run` defines the
  functions but skips the main execution, so a test can call them
  directly

### Dockerfiles

- Use specific base image tags (not `latest`)
- Minimize layers by combining RUN commands
- Clean up package manager caches
- Add LABEL metadata for tracking
- Use environment variables for versions and paths
- Document non-obvious decisions with comments
- Use numbered entrypoint.d scripts for environment setup:
  - `05-*.sh` - Low-level system setup (X11 display, gpg-agent)
  - `10-*.sh` - Primary feature setup (golang, node, android)
  - `20-*.sh` - Feature extensions (pnpm, additional tools)
  - `30-*.sh` - Complex/specialized setup (Yocto/OE, build systems)

### Makefiles

- Use `.PHONY` for non-file targets
- Provide descriptive target names
- Document complex rules with comments
- Test with both GNU make 3.x and 4.x

### Commit Messages

Follow the repository convention:

```text
component: action description

- Detailed change 1
- Detailed change 2
```

Examples:

- `docker-ubuntu-builder: add python venv auto-setup`
- `go: update Go 1.23 to 1.23.10`
- `docker: add tool to multiple images`

## Debugging Tips

### Build Issues

```bash
# Show generated rules
cat rules.mk images.mk

# List discovered images
cat .tag-dirs

# Bypass Docker layer cache (e.g. refresh base images)
make FORCE=1 quay.io/amery/docker-<name>-builder
```

### Runtime Issues

```bash
# Test docker-builder-run directly
DOCKER_ID=ubuntu:24.04 docker-builder-run bash

# Check detected environment
docker-builder-run -V

# Inspect image labels
docker inspect <image> | jq '.[] | .Config.Labels'

# Test tool in container
DOCKER_ID=quay.io/amery/docker-<name>-builder docker-builder-run tool --version
```

### Python Dependency Issues

Probe through the entrypoint, not around it: the venv PATH entries come
from `/etc/profile.d/*.sh`, which the entrypoint writes, so a bare
`docker run <image> <cmd>` resolves a different `python3` than real use
does — when it runs at all, which it does not, since the entrypoint needs
the variables `docker-builder-run` supplies. From a workspace, `x` also
satisfies whatever that workspace's `run-hook.sh` sets up, such as poky's
`OEROOT`:

```bash
# Check Python path in container
x python3 -c "import sys; print(sys.path)"

# Test module import
x python3 -c "import module_name"

# Check which build of a compiled package the venv resolves
x python3 -c "import google.protobuf as p; print(p.__version__, p.__file__)"

# Check whether a binding can load its shared library
x python3 -c "import clang.cindex as c; print(c.Config().lib)"

# Check pip packages
x pip list

# Outside a workspace, name the image instead
DOCKER_ID=<image> docker-builder-run python3 -c "import sys; print(sys.path)"
```

## Best Practices

1. **Version Everything**: Use specific versions for base images and tools
2. **Label Images**: Add metadata for tracking and debugging
3. **Test Locally**: Build and test before pushing
4. **Document Changes**: Update AGENTS.md, README.md, and CONTRIBUTING.md
5. **Coordinate Updates**: Notify dependent projects of breaking changes
6. **Isolate Dependencies**: Give Python tools a venv, inheriting the
   system packages only for compiled ones
7. **Pin Versions**: Specify exact or compatible version ranges, for API
   compatibility rather than to fit the interpreter
8. **Clean Builds**: Remove build artifacts in the same layer

## Security Considerations

- Never include secrets in Dockerfiles
- Use official base images when possible
- Regularly update base images for security patches
- Review generated images with `docker history`
- Scan images for vulnerabilities before pushing
- Avoid running pip with `--break-system-packages`
- Install Python packages into a virtual environment, never into the
  system interpreter

## Troubleshooting Guide

### ModuleNotFoundError in Python Tools

**Symptom**: `ModuleNotFoundError: No module named 'package'`

**Causes**:

- System and pip packages installed in different locations
- Missing Python path configuration
- Version conflicts between system and pip packages

**Solution**: Use virtual environments (see Managing Python Dependencies)

### Version Compatibility Issues

**Symptom**: `AttributeError: type object 'X' has no attribute 'Y'`

**Causes**:

- API changes in dependencies
- Incompatible version combinations

**Solution**: Pin compatible versions in requirements

### Extension Rejected by the Interpreter

**Symptom**: `TypeError: Metaclasses with custom tp_new are not supported`,
or a wheel that has no build for the running Python

**Cause**: a pip package whose compiled extension predates the base image's
interpreter. Pinning further back does not help — the older release is
built for older interpreters still.

**Solution**: install the distro's build with apt and let the venv inherit
it (see Managing Python Dependencies)

### Build Failures

**Symptom**: Docker build fails with package errors

**Checks**:

1. Verify base image is accessible
2. Check for typos in package names
3. Ensure proper cleanup after apt operations
4. Verify network connectivity for package downloads

### Image Size Issues

**Symptom**: Images are larger than expected

**Solutions**:

- Combine RUN commands to reduce layers
- Remove build dependencies after compilation
- Use `--no-install-recommends` with apt
- Clean package manager caches in the same layer

[readme-file]: ./README.md
[design-file]: ./DESIGN.md
[dev-env]: https://github.com/amery/dev-env

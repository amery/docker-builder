# Architecture and Design

Internal architecture documentation for docker-builder components. For
usage information, see [README.md](./README.md). For development
workflows, see [CONTRIBUTING.md](./CONTRIBUTING.md). For AI agents, see
[AGENTS.md](./AGENTS.md).

## docker-builder-run Architecture

### Volume System

The volume mounting system prevents conflicts through intelligent filtering:

**Deduplication strategy:**

- Groups paths by device ID using `stat`
- Filters subdirectories when parent already mounted
- Preserves symlink targets and parent directories

**Home directory handling:**

- Never mounts `$HOME` directly
- Creates persistent cache at `$WS/.docker-run-cache/home/$USER`
- Maps `$HOME` to cache inside container
- Prevents root-owned files in user directories

### Environment Variable System

**Label-driven configuration:**

Images declare required environment variables via Docker labels:

```dockerfile
LABEL docker-builder.run-env.oe="MACHINE DISTRO TCLIBC OEROOT DL_DIR BUILDDIR"
```

`docker-builder-run` reads these labels and automatically passes non-empty
variables through to the container.

### Mode Detection

Workspace type detected automatically:

- **golang**: Via `GOPATH` presence, sets up Go workspace structure
- **nodejs**: Via `NPM_CONFIG_PREFIX`, configures npm directories
- **x11**: Via `DISPLAY`, mounts X11 socket and sound device

Each mode adds appropriate volumes and configuration automatically.

### Extension Points

**`run-hook.sh`:**

- Executed on host BEFORE container starts
- Runs BEFORE volume/environment setup
- Allows workspace-specific detection (`OEROOT`, `BUILDDIR`, `DL_DIR`)
- Can modify `DOCKER_RUN_VOLUMES`, `DOCKER_RUN_ENV`, `DOCKER_EXTRA_OPTS`

**`entrypoint.d`:**

- Executed inside container during initialization
- Files sourced in alphanumeric order by numbered prefix
- Output appended to `/etc/profile.d/Z99-docker-run.sh`
- Enables image-specific environment setup

**Numbering scheme:**

- `05-*.sh` - Low-level system setup (X11, display)
- `10-*.sh` - Primary feature setup (golang, node, android)
- `20-*.sh` - Feature extensions (pnpm, additional tools)
- `30-*.sh` - Complex/specialized setup (Yocto/OE, build systems)

## Image Integration Patterns

### Minimal Wrapper Pattern

Workspace `run.sh` delegates to `docker-builder-run`:

- Sets `DOCKER_DIR` to `Dockerfile` location
- Sets `DOCKER_RUN_WS` to workspace root (skips detection)
- Delegates everything else to `docker-builder-run`
- Typically 4-6 lines total

**Benefits:**

- Automatic updates when `docker-builder-run` improves
- Consistent behavior across workspaces
- Minimal maintenance burden

### Workspace Detection Pattern (run-hook.sh)

Template copied to workspaces for environment detection:

- Searches for workspace markers (`conf/local.conf`, `oe-init-build-env`)
- Detects paths relative to workspace root
- Exports variables for `docker-builder-run`
- Requests additional volume mounts

**Key principle:** Extend `DOCKER_RUN_VOLUMES`, don't replace it.

### Environment Setup Pattern (entrypoint.d)

Image-specific initialization inside container:

- Sources workspace-specific tools (`bitbake`, OE scripts)
- Exports necessary environment variables
- Sets up PATH for tool availability
- Outputs commands to profile (not direct execution)

**Naming convention:** Use numbered prefixes to control execution order:

```dockerfile
# Low-level setup (05)
COPY 05-display.sh /etc/entrypoint.d/05-display.sh

# Primary features (10)
COPY 10-golang.sh /etc/entrypoint.d/10-golang.sh
COPY 10-node.sh /etc/entrypoint.d/10-node.sh

# Feature extensions (20)
COPY 20-node-pnpm.sh /etc/entrypoint.d/20-node-pnpm.sh

# Specialized setup (30)
COPY 30-poky.sh /etc/entrypoint.d/30-poky.sh
```

**Key principle:** Output minimal, essential setup only.

## Yocto/OE Integration

### Command Wrapper (bb.sh)

Optional convenience wrapper that transforms arguments:

- No args → interactive shell
- Explicit commands (`bitbake`, `devtool`) → pass through
- Recipe names → prepend `bitbake`

**Design rationale:**

- Separate file (not combined with `run.sh`) for clarity
- Validates `run.sh` existence
- Simple case-based transformation
- ~20 lines of focused logic

**Alternative considered:** Combined `run.sh`/`bb.sh` using basename
detection. Rejected because mixing concerns reduces clarity despite saving
lines.

### Quiet Environment Setup

Traditional oe-init-build-env produces verbose output unsuitable for scripts.
The `entrypoint.d` pattern replicates essential setup without messages.

**What we replicate:**

- BUILDDIR, OEROOT exports
- PATH setup for `bitbake`/scripts
- Modern BitBake: PYTHONPATH and BBPATH
- BB_ENV_* whitelist variable merging

**What we skip:**

- Verbose "Shell environment set up for builds" messages
- Configuration file creation (workspace already configured)
- Documentation banners
- TEMPLATECONF handling

**Result:** Commands produce only actual output, not initialization messages.

### Workspace Structure Patterns

Three common patterns supported:

**Standard Poky:**

- poky/ at workspace root
- build/ sibling to poky/
- downloads/ sibling or elsewhere

**repo-based:**

- sources/poky/ for OEROOT
- build/ at workspace root
- downloads/ often symlinked to shared location

**Custom setup-environment:**

- Custom initialization script at workspace root
- sources/poky/ for OE core
- build-machine/ for machine-specific builds

All patterns detected automatically by `run-hook.sh` search algorithm.

### BitBake Variable Evolution

**Old BitBake (pyro 2.3/morty):**

- BB_ENV_EXTRAWHITE: whitelist for environment variables

**Modern BitBake (kirkstone+):**

- BB_ENV_PASSTHROUGH_ADDITIONS: renamed from EXTRAWHITE
- PYTHONPATH required for BitBake lib
- BBPATH required for build directory

Images target appropriate BitBake versions:

- docker-poky-builder:18.04 → old BitBake
- docker-poky-builder:24.04 → modern BitBake

## Design Principles

### 1. Minimal Delegation

Prefer delegation over reimplementation. Workspace scripts should be thin
wrappers that set context and delegate to `docker-builder-run`.

**Comparison:**

- Custom implementation: 280 lines of volume/env/user logic
- Delegation pattern: 4 lines setting `DOCKER_DIR` and calling
  `docker-builder-run`

### 2. Separation of Concerns

Each component has a focused responsibility:

- `Dockerfile`: Package installation
- `run.sh`: Delegation and context
- `run-hook.sh`: Workspace detection
- `entrypoint.d`: Environment setup
- `bb.sh`: Command transformation (optional)

### 3. Leverage Existing Infrastructure

Build on docker-builder ecosystem:

- Base images provide user creation, `entrypoint` framework
- `docker-builder-run` provides mounting, environment, detection
- Extension points customize without modifying core

### 4. Extension Not Modification

Customize via hooks rather than forking:

- `run-hook.sh` for workspace-specific detection
- `entrypoint.d` for image-specific environment
- LABELs for declaring requirements
- Environment variables for configuration

## References

- [AGENTS.md](./AGENTS.md) - AI agent instructions and technical details
- [CONTRIBUTING.md](./CONTRIBUTING.md) - Contributing guidelines
- [README.md](./README.md) - User-facing documentation

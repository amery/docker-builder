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

### Build System Components

```text
Makefile              # Main entry point
├── config.mk        # User configuration (PREFIX)
├── rules.mk         # Generated rules for file processing
└── images.mk        # Generated image build targets

scripts/
├── gen_rules_mk.sh  # Generates rules.mk from templates
├── gen_images_mk.sh # Generates images.mk from tag directories
├── gen_tag_dirs.sh  # Discovers and lists image directories
├── get_files.sh     # Finds files matching patterns
├── get_vars.sh      # Extracts variables from templates
├── get_aliases.sh   # Retrieves image aliases
└── filter-out-tags.sh # Filters obsolete tags for GC
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

- Generates `.image-<name>` marker files
- Creates push/pull targets
- Handles tag aliases and latest symlinks

### 4. Tag Management

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

- **Files**: `.image-*` marker files in the build directory
- **Purpose**: Track what make has already built to avoid redundant work
- **Behavior**: If marker exists and dependencies unchanged, skip rebuild
- **Control**: Use `-B` flag or delete marker files

#### 2. Docker Layer (Build Cache)

- **Files**: Docker's internal layer cache
- **Purpose**: Reuse unchanged layers during docker build
- **Behavior**: Each Dockerfile instruction creates a cached layer
- **Control**: Use `FORCE=1` variable (adds `--no-cache` flag)

### Build Control Options

| Command | Make Cache | Docker Cache | Use When |
|---------|------------|--------------|----------|
| `make <target>` | ✓ Used | ✓ Used | Normal incremental builds |
| `make FORCE=1 <target>` | ✓ Used | ✗ Bypassed | Changed Dockerfile, want clean layer rebuild |
| `make -B <target>` | ✗ Bypassed | ✓ Used | Marker file stale, dependencies should rebuild |
| `make -B FORCE=1 <target>` | ✗ Bypassed | ✗ Bypassed | Complete clean rebuild from scratch |

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
# Builds: 1.18, 1.19, 1.20, 1.21, 1.22, 1.23, 1.24, 1.25, latest, multi

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
make FORCE=1 quay.io/amery/docker-golang-builder-1.25
```

#### Scenario: Make thinks it's built but it hasn't

```bash
# Marker file exists but image was deleted or you want to rebuild all versions
make -B quay.io/amery/docker-ubuntu-builder
```

#### Scenario: Completely stuck build state

```bash
# Nuclear option: bypass all caching
make -B FORCE=1 quay.io/amery/docker-golang-builder
```

#### Scenario: Just regenerate rules

```bash
# Added new Dockerfile, need rules.mk/images.mk regenerated
make files
```

### Marker File Lifecycle

Marker files prevent redundant builds:

```bash
# Building creates marker
make quay.io/amery/docker-ubuntu-builder-24.04
# Creates: .image-docker-ubuntu-builder-24.04

# Subsequent call skips build
make quay.io/amery/docker-ubuntu-builder-24.04
# Output: make: Nothing to be done for '...'

# Force rebuild by removing marker
rm .image-docker-ubuntu-builder-24.04
make quay.io/amery/docker-ubuntu-builder-24.04
# Rebuilds
```

### Target Name Patterns

Understanding target naming helps navigate the build system:

#### Directory Structure to Target Names

```text
docker/<name>/<version>/Dockerfile
    ↓
quay.io/amery/docker-<name>-builder                    # All versions
quay.io/amery/docker-<name>-builder-<version>          # Specific version
push-docker-<name>-builder                             # Push all versions
push-docker-<name>-builder-<version>                   # Push specific
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

The `latest` target does not build anything - it depends on the real version
being built first, then tags it:

<!-- markdownlint-disable MD010 -->

```makefile
# Generated rule for symlink
.image-docker-ubuntu-builder-latest:
	docker tag quay.io/amery/docker-ubuntu-builder:24.04 \
	           quay.io/amery/docker-ubuntu-builder:latest
	touch $@
```

<!-- markdownlint-enable MD010 -->

### Makefile Generation

The build system generates makefiles dynamically:

#### Generation Triggers

1. **rules.mk**: Regenerates when templates change

   ```bash
   scripts/gen_rules_mk.sh > rules.mk
   ```

2. **images.mk**: Regenerates when Dockerfiles are added/removed

   ```bash
   scripts/gen_images_mk.sh > images.mk
   ```

3. **.tag-dirs**: Always checks for new directories

   ```bash
   scripts/gen_tag_dirs.sh > .tag-dirs
   ```

#### Force Regeneration

```bash
make files              # Regenerate all makefiles
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
ls -la .image-*         # List all marker files
make -n <target>        # Dry run, show what would execute
```

#### Force complete rebuild

```bash
make clean              # Remove all markers
make -B FORCE=1         # Build everything from scratch
```

#### Check Docker build arguments

```bash
# With FORCE=1
make FORCE=1 <target>
# Uses: --rm --progress=plain --no-cache

# Without FORCE=1
make <target>
# Uses: --rm --progress=plain
```

## Docker Images Provided

### Base Images

- **ubuntu/{16.04,18.04,20.04,22.04,24.04}**: Base Ubuntu images with
  builder_version.sh
- **ubuntu-x11/{20.04,22.04,24.04}**: Ubuntu with X11 forwarding support
- **ubuntu-vsc-base/24.04**: VS Code DevContainer base

### Development Stacks

- **golang/{1.18-1.25}**: Go development environments
- **nodejs/{lts,current}**: Node.js with pnpm support
- **ubuntu-nodejs-golang/{22.04,24.04}**: Combined Node.js + Go

### Specialized Images

- **android/11**: Android SDK development
- **ubuntu-android-studio**: Android Studio with SDK
- **poky/latest**: Yocto Project build environment
- **micrologic/latest**: Custom micrologic environment
- **apptly/latest**: Apptly development base

### VS Code DevContainer Images

- **ubuntu-vsc-golang/24.04**: Go development in VS Code
- **ubuntu-vsc-nodejs/24.04**: Node.js development in VS Code
- **ubuntu-vsc-nodejs-golang/24.04**: Combined stack for VS Code

## The docker-builder-run Script

Located at `bin/docker-builder-run`, this script provides intelligent container
execution:

### `docker-builder-run` Key Features

1. **Workspace Detection**: Finds project root via `.repo` or `.git`
2. **Volume Management**: Intelligently mounts required directories
3. **Environment Preservation**: Passes through necessary variables
4. **Mode Detection**: Configures for Go, Node.js, or X11 as needed
5. **User Identity**: Preserves UID/GID in container

### Environment Variables

- `DOCKER_DIR`: Directory containing Dockerfile to build
- `DOCKER_ID`: Pre-built image ID to use instead
- `DOCKER_BUILD_FORCE`: Force rebuild/repull
- `DOCKER_RUN_ENV`: Variables to pass through
- `DOCKER_RUN_VOLUMES`: Extra directories to mount
- `DOCKER_RUN_WS`: Override workspace detection
- `DOCKER_EXPOSE`: Ports to expose

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

## The `x` Script

Located at `bin/x`, this script provides workspace-aware command
execution by automatically locating and invoking `run.sh`.

### `x` Script Key Features

1. **Workspace Detection**: Finds project root via `.repo` or `.git`
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

```bash
# Find workspace root
x --root

# Execute command via run.sh
x make build
x go test ./...

# Works from any subdirectory
cd src/myproject
x make  # Still finds workspace root run.sh

# Fallback: pass through if no run.sh
x echo "hello"
```

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
   ```

3. Run make to generate rules:

   ```bash
   make files
   ```

4. Build the image:

   ```bash
   make
   ```

### Updating Existing Images

1. Modify the Dockerfile
2. Force rebuild:

   ```bash
   make FORCE=1
   ```

3. Push to registry:

   ```bash
   make push
   ```

### Garbage Collection

Remove obsolete tags:

```bash
make tags-gc
```

## Build Targets Reference

### Image-Specific Targets

For each image (e.g., `micrologic`), the following targets are available:

```bash
# Build the image
make quay.io/amery/docker-micrologic-builder

# Push to registry
make push-docker-micrologic-builder

# Build and push
make quay.io/amery/docker-micrologic-builder push-docker-micrologic-builder
```

### Global Targets

```bash
# Build all images
make

# Push all images
make push

# Clean obsolete tags
make tags-gc

# Regenerate build files
make files
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

### Solution: Virtual Environments

Always use Python virtual environments for tool-specific dependencies:

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

### Real-World Example: nanopb

The nanopb tool requires specific protobuf versions:

```dockerfile
ENV NANOPB_VERSION=0.4.9.1
ENV NANOPB_VENV=/opt/nanopb-env

RUN python3 -m venv $NANOPB_VENV \
    && $NANOPB_VENV/bin/pip install --no-cache-dir \
        "protobuf<5.0" \
        "grpcio-tools<1.65" \
    && git clone -b $NANOPB_VERSION --depth 1 \
        https://github.com/nanopb/nanopb /usr/src/nanopb \
    && cd /usr/src/nanopb \
    && cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -Dnanopb_PYTHON_INSTDIR_OVERRIDE=$NANOPB_VENV/lib/python3.12/site-packages \
        . \
    && make && make install
```

## Code Quality Standards

### Shell Scripts

- Use `set -eu` for error handling
- Follow POSIX sh compatibility
- Add descriptive comments for complex logic
- Test with shellcheck before committing

### Dockerfiles

- Use specific base image tags (not `latest`)
- Minimize layers by combining RUN commands
- Clean up package manager caches
- Add LABEL metadata for tracking
- Use environment variables for versions and paths
- Document non-obvious decisions with comments

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

- `docker-micrologic-builder: add dos2unix`
- `go: update Go 1.23 to 1.23.10`
- `docker: add tool to multiple images`

## Debugging Tips

### Build Issues

```bash
# Verbose build output
make DOCKER_BUILD_OPT="--progress=plain"

# Show generated rules
cat rules.mk images.mk

# List discovered images
cat .tag-dirs

# Check specific image build
make DOCKER_BUILD_OPT="--no-cache" quay.io/amery/docker-<name>-builder
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
docker run --rm quay.io/amery/docker-<name>-builder tool --version
```

### Python Dependency Issues

```bash
# Check Python path in container
docker run --rm <image> python3 -c "import sys; print(sys.path)"

# Test module import
docker run --rm <image> python3 -c "import module_name"

# Check pip packages
docker run --rm <image> pip list

# Verify venv activation
docker run --rm <image> bash -c "source /etc/profile.d/*.sh && which python3"
```

## Best Practices

1. **Version Everything**: Use specific versions for base images and tools
2. **Label Images**: Add metadata for tracking and debugging
3. **Test Locally**: Build and test before pushing
4. **Document Changes**: Update AGENTS.md, README.md, and CONTRIBUTING.md
5. **Coordinate Updates**: Notify dependent projects of breaking changes
6. **Isolate Dependencies**: Use virtual environments for Python tools
7. **Pin Versions**: Specify exact or compatible version ranges
8. **Clean Builds**: Remove build artifacts in the same layer

## Security Considerations

- Never include secrets in Dockerfiles
- Use official base images when possible
- Regularly update base images for security patches
- Review generated images with `docker history`
- Scan images for vulnerabilities before pushing
- Avoid running pip with `--break-system-packages`
- Use virtual environments instead of system-wide Python packages

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
[dev-env]: https://github.com/amery/dev-env

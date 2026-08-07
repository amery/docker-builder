# Contributing to Docker Builder

Thank you for considering contributing to docker-builder! This document
provides guidelines and instructions for contributing to the project.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally:

   ```bash
   git clone https://github.com/YOUR-USERNAME/docker-builder
   cd docker-builder
   ```

3. Add the upstream repository:

   ```bash
   git remote add upstream https://github.com/amery/docker-builder
   ```

## Commit Message Format

Follow the existing convention for commit messages:

```text
component: action description

- Detailed change 1
- Detailed change 2

Extended explanation if needed.
```

### Examples

- `docker-ubuntu-builder: add python venv auto-setup`
- `go: update Go 1.23 to 1.23.10`
- `docker: add xxd to ubuntu and ubuntu-vsc-base 24.04 images`

### Components

Common component prefixes:

- `docker` - Changes affecting multiple Docker images
- `docker-<name>-builder` - Changes to a specific builder image
- `go` - Go-related updates
- `nodejs` - Node.js-related updates
- `ubuntu` - Ubuntu base image updates
- `scripts` - Build script modifications
- `docs` - Documentation updates

### Actions

Common action verbs:

- `add` - Adding new functionality or packages
- `update` - Updating versions or existing features
- `fix` - Bug fixes
- `remove` - Removing features or packages
- `refactor` - Code reorganization without changing functionality

## Adding a New Docker Image

1. Create the directory structure:

   ```bash
   mkdir -p docker/<name>/<version>
   ```

2. Create your Dockerfile following existing patterns:

   ```dockerfile
   FROM base-image:tag

   # Use environment variables for versions
   ENV TOOL_VERSION=1.2.3

   # Install dependencies
   RUN apt-get update && apt-get install --no-install-recommends -y \
       package1 \
       package2 \
       && apt-get clean \
       && rm -rf /var/lib/apt/lists/*

   # If base image (not extending docker-builder image)
   COPY entrypoint.sh /entrypoint.sh
   ENTRYPOINT ["/entrypoint.sh"]
   ```

   **Note:** Anything the Dockerfile copies from a golden source is
   generated for you: `entrypoint.sh` from `docker/entrypoint/ubuntu.sh` or
   `docker/entrypoint/alpine.sh` according to the FROM line, and each
   `/etc/entrypoint.d` plugin with a golden copy under
   `docker/entrypoint/plugins/`. Run `make files` to discover the image,
   then `make entrypoint` to write those copies — the build writes them
   too, listing them as prerequisites.

3. Test it locally, before publishing anything:

   ```bash
   make BUILDER= quay.io/amery/docker-<name>-builder-<version>
   DOCKER_ID="$(cat .image-docker-<name>-builder-<version>.local)" \
       docker-builder-run bash
   ```

   A local build loads the image untagged, so its ID in the `.local`
   sentinel is the handle; a bare `docker run` fails, the entrypoint
   needing the environment `docker-builder-run` sets up.

## Code Style Guidelines

### Dockerfiles

1. **Use environment variables** for versions and paths:

   ```dockerfile
   ENV TOOL_VERSION=1.2.3
   ENV TOOL_PATH=/opt/tool
   ```

2. **Minimize layers** by combining commands:

   ```dockerfile
   RUN command1 \
       && command2 \
       && cleanup
   ```

3. **Clean up in the same layer**:

   ```dockerfile
   RUN apt-get update \
       && apt-get install -y package \
       && apt-get clean \
       && rm -rf /var/lib/apt/lists/*
   ```

4. **Document non-obvious decisions**:

   ```dockerfile
   # Use virtual environment to isolate Python dependencies
   # from system packages to prevent version conflicts
   ENV TOOL_VENV=/opt/tool-env
   ```

### entrypoint.d Scripts

When adding environment-specific setup, use `/etc/entrypoint.d/` scripts:

1. **Naming convention** - Use numbered prefixes:

   - `05-*.sh` - Low-level system setup (X11, display)
   - `10-*.sh` - Primary feature setup (golang, node, android)
   - `20-*.sh` - Feature extensions (pnpm, additional tools)
   - `30-*.sh` - Complex/specialized setup (Yocto/OE, build systems)

2. **Script structure** - Output shell commands via heredoc:

   ```bash
   cat <<EOT
   export MY_VAR="value"
   export PATH="/opt/tool/bin:\$PATH"
   EOT
   ```

3. **Copy to container** - Include in Dockerfile:

   ```dockerfile
   # Feature setup
   COPY 10-mytool.sh /etc/entrypoint.d/10-mytool.sh
   ```

4. **Single-source shared plugins** - If more than one image uses the
   plugin, add it once as a golden copy under
   `docker/entrypoint/plugins/`;
   `make entrypoint` regenerates the per-image copies (which are
   git-ignored). Keep a genuinely image-specific plugin in the image
   directory, as above.

**Key principle:** Scripts are sourced during container initialization and
their output is appended to `/etc/profile.d/Z99-docker-run.sh`. They should
only output environment setup commands, not execute actions directly.

### Python Dependencies

When adding tools with Python dependencies:

1. **Always use virtual environments**:

   ```dockerfile
   ENV TOOL_VENV=/opt/tool-env
   RUN python3 -m venv $TOOL_VENV \
       && $TOOL_VENV/bin/pip install --no-cache-dir package==version
   ```

2. **Pin compatible versions**:

   ```dockerfile
   RUN $TOOL_VENV/bin/pip install --no-cache-dir \
       "protobuf<5.0" \
       "dependency>=1.0,<2.0"
   ```

3. **Update shebangs for scripts**:

   ```dockerfile
   RUN sed -i "1s|^#!/usr/bin/env python3|#!$TOOL_VENV/bin/python3|" \
       /usr/bin/script
   ```

## Testing Your Changes

### Build Prerequisites

The normal build produces a multi-architecture manifest (amd64 + arm64)
and pushes it to the registry. Before building:

1. **Registry login**: `docker login quay.io`
2. **Multi-arch builder**: A `multiarch-native` buildx builder with
   native nodes (see
   [AGENTS.md](./AGENTS.md#using-ssh-remote-builders-for-native-builds))

A local build (`make BUILDER= <target>`) needs neither: it builds for the
host architecture alone and loads the image into the local daemon
untagged, pushing nothing. Develop against that, and use the normal build
once the change is ready — see [AGENTS.md](./AGENTS.md#local-builds).

### Build Workflows

The build system uses two-level caching (Make markers + Docker layers). Here
are the most common workflows:

#### Normal Development

```bash
# First build (amd64+arm64, pushed to registry)
make quay.io/amery/docker-<name>-builder-<version>

# Make changes to Dockerfile, then rebuild
make quay.io/amery/docker-<name>-builder-<version>
```

#### Stuck Build Issues

```bash
# Make says "Nothing to be done" but you need a rebuild: remove that
# image's marker (the alias marker follows on its own)
rm .image-docker-<name>-builder-<version>
make quay.io/amery/docker-<name>-builder-<version>

# Complete clean rebuild of that family (bypasses all caching)
rm .image-docker-<name>-builder-*
make FORCE=1 quay.io/amery/docker-<name>-builder
```

Clear markers rather than forcing targets — `-B` treats every
prerequisite as out of date and rebuilds and pushes base images nobody
asked for. Keep `make clean` for when you do mean every image: it
discards the whole make layer, and each marker only returns by
rebuilding, which in the normal mode pushes.

#### Added New Dockerfiles

```bash
# Regenerate build rules to discover new images
make files

# Build the new image
make quay.io/amery/docker-<newname>-builder
```

#### Quick Reference

| Changed | Command |
| ------- | ------- |
| Modified existing Dockerfile | `make <target>` |
| Added new Dockerfile | `make files && make <target>` |
| Build seems stuck | `rm .image-<name>`, then `make <target>` |
| Complete rebuild needed | `make clean`, then `make FORCE=1` |

For detailed explanation of the build system mechanics, see
[AGENTS.md Build System Mechanics](./AGENTS.md#build-system-mechanics).

### Testing the Built Image

1. **Build the image** (using appropriate workflow above)

2. **Test basic functionality**:

   ```bash
   # Test interactive shell
   docker run --rm -it quay.io/amery/docker-<name>-builder:<version> bash

   # Test specific commands
   docker run --rm quay.io/amery/docker-<name>-builder:<version> tool --version
   ```

3. **Test with docker-builder-run**:

   ```bash
   DOCKER_ID=quay.io/amery/docker-<name>-builder:<version> \
       docker-builder-run your-command
   ```

4. **Verify no regressions** in dependent images if modifying base images

## Pull Request Process

1. **Update documentation**:
   - Update README.md if adding new images or features
   - Document any new environment variables or build options
   - Add comments in Dockerfiles for complex sections

2. **Ensure clean commits**:

   ```bash
   # Rebase on latest upstream
   git fetch upstream
   git rebase upstream/main
   
   # Squash related commits if needed
   git rebase -i upstream/main
   ```

3. **Create pull request**:
   - Use a clear, descriptive title
   - Reference any related issues
   - Describe what changes were made and why
   - Include testing steps if applicable

4. **Address review feedback**:
   - Make requested changes
   - Push updates to your branch
   - Respond to review comments

## Maintenance Tasks

### Updating Package Versions

When updating versions (e.g., Go, Node.js):

1. Update the version in the Dockerfile
2. Test the build thoroughly
3. Update any dependent images
4. Use clear commit messages:

   ```text
   go: update Go 1.23 to 1.23.11
   
   - Security updates and bug fixes
   - No breaking changes
   ```

### Deprecating Images

1. Add deprecation notice to the Dockerfile
2. Update README.md with deprecation timeline
3. Provide migration path for users

## Questions?

If you have questions about contributing:

1. Check existing issues and pull requests
2. Review the AGENTS.md file for technical details
3. Open an issue for discussion

Thank you for contributing to docker-builder!

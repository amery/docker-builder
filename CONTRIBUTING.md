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

- `docker-micrologic-builder: add dos2unix`
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

   **Note:** When creating a base image that uses `COPY entrypoint.sh`,
   the file will be automatically generated from canonical sources
   (`docker/entrypoint/ubuntu.sh` or `docker/entrypoint/alpine.sh`) based
   on the FROM line. Run `make files` to generate it.

3. Test your image locally:

   ```bash
   make quay.io/amery/docker-<name>-builder
   docker run --rm -it quay.io/amery/docker-<name>-builder:<version> bash
   ```

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

### Build Workflows

The build system uses two-level caching (Make markers + Docker layers). Here
are the most common workflows:

#### Normal Development

```bash
# First build
make quay.io/amery/docker-<name>-builder-<version>

# Make changes to Dockerfile
# Rebuild with clean Docker layers (bypasses Docker cache)
make FORCE=1 quay.io/amery/docker-<name>-builder-<version>
```

#### Stuck Build Issues

```bash
# Make says "Nothing to be done" but you need rebuild
make -B quay.io/amery/docker-<name>-builder

# Complete clean rebuild (bypasses all caching)
make -B FORCE=1 quay.io/amery/docker-<name>-builder
```

#### Added New Dockerfiles

```bash
# Regenerate build rules to discover new images
make files

# Build the new image
make quay.io/amery/docker-<newname>-builder
```

#### Quick Reference

| Changed | Command |
|---------|---------|
| Modified existing Dockerfile | `make FORCE=1 <target>` |
| Added new Dockerfile | `make files && make <target>` |
| Build seems stuck | `make -B <target>` |
| Complete rebuild needed | `make -B FORCE=1 <target>` |

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
   git rebase upstream/master
   
   # Squash related commits if needed
   git rebase -i upstream/master
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

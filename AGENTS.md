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
- **Run Script**: `bin/docker-builder-run` provides container execution wrapper
- **Base Images**: Ubuntu, Node.js, Go, Android, Poky, and combinations

## Architecture Overview

docker-builder is a sophisticated Docker image build system that:

1. **Generates Dynamic Makefiles**: Creates build rules based on discovered
   Dockerfiles
2. **Manages Image Tags**: Tracks current and obsolete image tags
3. **Provides Run Wrapper**: `bin/docker-builder-run` for consistent container
   execution
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

### Key Features

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

### Usage Examples

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

## Integration with dev-env

The `amery/dev-env` project depends on docker-builder:

1. **Base Image**: Uses `quay.io/amery/docker-apptly-builder:latest`
2. **Run Script**: Leverages `bin/docker-builder-run` for execution
3. **DevContainer**: Extends the VS Code base images

When updating docker-builder:

- Changes to `ubuntu-vsc-base` affect all VS Code environments
- Updates to `bin/docker-builder-run` impact container execution behavior
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

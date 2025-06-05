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
- **Run Script**: `docker/run.sh` provides container execution wrapper
- **Base Images**: Ubuntu, Node.js, Go, Android, Poky, and combinations

## Architecture Overview

docker-builder is a sophisticated Docker image build system that:

1. **Generates Dynamic Makefiles**: Creates build rules based on discovered
   Dockerfiles
2. **Manages Image Tags**: Tracks current and obsolete image tags
3. **Provides Run Wrapper**: `docker/run.sh` for consistent container
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

- **golang/{1.18-1.24}**: Go development environments
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

Located at `docker/run.sh`, this script provides intelligent container
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
./docker/run.sh make build

# Force rebuild
DOCKER_BUILD_FORCE=true ./docker/run.sh

# With custom volumes
DOCKER_RUN_VOLUMES="/data" ./docker/run.sh

# Expose ports
./docker/run.sh -p 8080 npm start
```

## Integration with dev-env

The `amery/dev-env` project depends on docker-builder:

1. **Base Image**: Uses `quay.io/amery/docker-apptly-builder:latest`
2. **Run Script**: Leverages docker-builder's `run.sh` for execution
3. **DevContainer**: Extends the VS Code base images

When updating docker-builder:

- Changes to `ubuntu-vsc-base` affect all VS Code environments
- Updates to `run.sh` impact container execution behavior
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

### Makefiles

- Use `.PHONY` for non-file targets
- Provide descriptive target names
- Document complex rules with comments
- Test with both GNU make 3.x and 4.x

## Debugging Tips

### Build Issues

```bash
# Verbose build output
make DOCKER_BUILD_OPT="--progress=plain"

# Show generated rules
cat rules.mk images.mk

# List discovered images
cat .tag-dirs
```

### Runtime Issues

```bash
# Test run.sh directly
DOCKER_ID=ubuntu:24.04 ./docker/run.sh bash

# Check detected environment
./docker/run.sh -V

# Inspect image labels
docker inspect <image> | jq '.[] | .Config.Labels'
```

## Best Practices

1. **Version Everything**: Use specific versions for base images
2. **Label Images**: Add metadata for tracking and debugging
3. **Test Locally**: Build and test before pushing
4. **Document Changes**: Update both AGENT.md and README.md
5. **Coordinate Updates**: Notify dependent projects of breaking changes

## Security Considerations

- Never include secrets in Dockerfiles
- Use official base images when possible
- Regularly update base images for security patches
- Review generated images with `docker history`
- Scan images for vulnerabilities before pushing

[readme-file]: ./README.md
[dev-env]: https://github.com/amery/dev-env

# docker-builder

A sophisticated Docker image build system with automatic Makefile generation
and intelligent container runtime management. Provides base images for
development environments including VS Code DevContainers.

## Features

- **Dynamic Build System**: Automatically discovers and builds Docker images
- **Smart Container Runtime**: Intelligent workspace detection and volume
  management
- **Multiple Development Stacks**: Ubuntu, Go, Node.js, Android, and more
- **VS Code Integration**: Pre-configured DevContainer base images
- **Tag Management**: Automatic tracking and garbage collection of image tags

## Quick Start

### Installation

```bash
mkdir -p ~/projects/docker
cd ~/projects/docker
git clone https://github.com/amery/docker-builder
ln -s $PWD/docker-builder/docker/run.sh ~/bin/docker-builder-run
```

### Building Images

```bash
cd docker-builder
make                    # Build all images
make golang/latest      # Build specific image
make push              # Push to registry
make tags-gc           # Clean up obsolete tags
```

### Using docker-builder-run

The `docker-builder-run` script provides intelligent container execution:

```bash
# Run command in auto-detected container
docker-builder-run make test

# Force rebuild and run
DOCKER_BUILD_FORCE=true docker-builder-run npm install

# Use specific image
DOCKER_ID=ubuntu:24.04 docker-builder-run bash
```

## Available Images

### Base Images

- **ubuntu/{16.04,18.04,20.04,22.04,24.04}** - Base Ubuntu environments
- **ubuntu-x11/{20.04,22.04,24.04}** - Ubuntu with X11 forwarding

### Development Environments

- **golang/{1.18-1.25}** - Go development environments
- **nodejs/{lts,current}** - Node.js with pnpm
- **ubuntu-nodejs-golang/{22.04,24.04}** - Combined Go + Node.js

### VS Code DevContainers

- **ubuntu-vsc-base/24.04** - Base for VS Code development
- **ubuntu-vsc-golang/24.04** - Go in VS Code
- **ubuntu-vsc-nodejs/24.04** - Node.js in VS Code
- **ubuntu-vsc-nodejs-golang/24.04** - Full stack VS Code

### Specialized

- **android/11** - Android SDK development
- **ubuntu-android-studio/latest** - Android Studio with SDK
- **poky/latest** - Yocto Project builds
- **apptly/latest** - Apptly development base

## Build System

### Make Targets

The build system provides several make targets for managing images:

#### Build Targets

- `make quay.io/amery/docker-<name>-builder` - Build a specific image
- Images are automatically tagged as both `:latest` and `:<version>`
  (e.g., `:24.04`)

#### Pushing Images

- `make push-docker-<name>-builder` - Push image to registry
- Requires authentication to quay.io registry

#### Examples

```bash
# Build the micrologic builder image
make quay.io/amery/docker-micrologic-builder

# Push the image to registry
make push-docker-micrologic-builder

# Build and push in sequence
make quay.io/amery/docker-micrologic-builder push-docker-micrologic-builder
```

## Environment Variables

### Build Configuration

| Variable             | Purpose
|----------------------|-----------------------------------------------------------
| `DOCKER_DIR`         | Directory containing Dockerfile to build
| `DOCKER_ID`          | Pre-built image ID to use instead of building
| `DOCKER_BUILD_OPT`   | Additional arguments for `docker build` (default: --rm)
| `DOCKER_BUILD_FORCE` | Force rebuild/repull of the image

### Runtime Configuration

| Variable             | Purpose
|----------------------|-----------------------------------------------------------
| `DOCKER_RUN_ENV`     | Environment variables to pass through to container
| `DOCKER_RUN_VOLUMES` | Additional directories to mount in container
| `DOCKER_RUN_WS`      | Override automatic workspace detection
| `DOCKER_EXTRA_OPTS`  | Extra options to pass to `docker run`
| `DOCKER_EXPOSE`      | Ports to expose (e.g., "8080" or "8080:8080/tcp")

## Project Structure

```text
docker-builder/
├── Makefile              # Main build orchestrator
├── config.mk            # User configuration
├── scripts/             # Build automation scripts
├── docker/              # Image definitions
│   ├── run.sh          # Container runtime wrapper
│   ├── ubuntu/         # Base Ubuntu images
│   ├── golang/         # Go development images
│   ├── nodejs/         # Node.js images
│   └── ...            # Other image types
└── LICENCE.txt         # MIT License
```

## Troubleshooting

### Python Dependencies in Docker Images

When building images that require Python packages (e.g., nanopb, sphinx):

1. **Use virtual environments** for isolated dependencies:

   ```dockerfile
   ENV TOOL_VENV=/opt/tool-env
   RUN python3 -m venv $TOOL_VENV \
       && $TOOL_VENV/bin/pip install --no-cache-dir package==version
   ```

2. **Pin compatible versions** to avoid conflicts:
   - Check tool documentation for version requirements
   - Use version constraints like `"protobuf<5.0"`
   - Test compatibility between system and pip packages

3. **Update script shebangs** to use venv Python:

   ```dockerfile
   RUN sed -i "1s|^#!/usr/bin/env python3|#!$TOOL_VENV/bin/python3|" /usr/bin/script
   ```

4. **Add venv to PATH** for runtime access:

   ```dockerfile
   RUN echo "export PATH=\"$TOOL_VENV/bin:\$PATH\"" >> /etc/profile.d/tool.sh
   ```

### Common Build Issues

- **Version Conflicts**: System packages (apt) may conflict with pip
  packages. Use virtual environments to isolate dependencies.
- **Missing Modules**: If you see "ModuleNotFoundError", ensure the Python
  path includes the installation directory.
- **API Changes**: Pin versions when tools break due to API changes
  (e.g., protobuf's RegisterExtension removal).

## Best Practices

### Dockerfile Conventions

1. **Environment Variables**
   - Define versions as ENV variables (e.g., `ENV TOOL_VERSION=1.2.3`)
   - Define paths as ENV variables (e.g., `ENV TOOL_VENV=/opt/tool-env`)
   - Use these variables consistently throughout the Dockerfile

2. **Layer Optimization**
   - Order layers from least to most frequently changing
   - Combine related RUN commands with `&&`
   - Remove build artifacts in the same layer they're created

3. **Dependency Management**
   - System packages: Use apt with `--no-install-recommends`
   - Python packages: Use virtual environments to avoid conflicts
   - Clean up: `apt-get clean`, `rm -rf /var/lib/apt/lists/*`

4. **Documentation**
   - Add comments explaining non-obvious decisions
   - Document why specific versions are pinned
   - Include usage examples in comments

## Integration with Other Projects

docker-builder serves as the foundation for various development environments:

- **[amery/dev-env][dev-env]** - VS Code
  DevContainer environment using docker-builder base images
- Custom development environments can extend any of the provided base images

## Documentation

- [AGENTS.md][agent-file] - Technical implementation details for AI agents
  and developers
- [CONTRIBUTING.md][contributing-file] - Guidelines for contributing to the project
- [LICENCE.txt][licence-file] - MIT License

## Contributing

See [CONTRIBUTING.md][contributing-file] for detailed guidelines.

## License

MIT License - see [LICENCE.txt][licence-file] for details

[dev-env]: https://github.com/amery/dev-env
[agent-file]: ./AGENTS.md
[contributing-file]: ./CONTRIBUTING.md
[licence-file]: ./LICENCE.txt

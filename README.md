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

- **golang/{1.18-1.24}** - Go development environments
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

## Integration with Other Projects

docker-builder serves as the foundation for various development environments:

- **[amery/dev-env][dev-env]** - VS Code
  DevContainer environment using docker-builder base images
- Custom development environments can extend any of the provided base images

## Documentation

- [AGENT.md][agent-file] - Technical implementation details for AI agents
  and developers
- [LICENCE.txt][licence-file] - MIT License

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add your Dockerfile in `docker/<name>/<version>/`
4. Update documentation
5. Submit a pull request

## License

MIT License - see [LICENCE.txt][licence-file] for details

[dev-env]: https://github.com/amery/dev-env
[agent-file]: ./AGENT.md
[licence-file]: ./LICENCE.txt
